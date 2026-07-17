import { expect, test } from "@playwright/test";

const routes = [
  "home",
  "today",
  "plans",
  "progress",
  "workout/session-push",
  "leaderboards",
  "submit",
  "library",
  "gyms",
  "community",
  "messages",
  "profile",
  "settings",
  "onboarding"
] as const;

test("primary-route production budgets", async ({ browser }, testInfo) => {
  const report: Record<string, unknown>[] = [];
  for (const route of routes) {
    const context = await browser.newContext({ viewport: testInfo.project.use.viewport });
    const page = await context.newPage();
    await page.addInitScript(() => {
      const metrics = { lcp: 0, cls: 0, longestTask: 0 };
      Object.assign(window, { __liftrankMetrics: metrics });
      new PerformanceObserver((list) => { for (const entry of list.getEntries()) metrics.lcp = entry.startTime; }).observe({ type: "largest-contentful-paint", buffered: true });
      new PerformanceObserver((list) => { for (const entry of list.getEntries()) { const shift = entry as PerformanceEntry & { value: number; hadRecentInput: boolean }; if (!shift.hadRecentInput) metrics.cls += shift.value; } }).observe({ type: "layout-shift", buffered: true });
      new PerformanceObserver((list) => { for (const entry of list.getEntries()) metrics.longestTask = Math.max(metrics.longestTask, entry.duration); }).observe({ type: "longtask", buffered: true });
    });
    await page.goto(`/#/${route}`, { waitUntil: "networkidle" });
    await page.waitForTimeout(200);
    const metrics = await page.evaluate((routeName) => {
      const resources = performance.getEntriesByType("resource") as PerformanceResourceTiming[];
      const entryScript = resources.find((resource) => /\/assets\/index-[^/]+\.js$/.test(new URL(resource.name).pathname));
      const images = resources.filter((resource) => resource.initiatorType === "img" || /\.(?:avif|png)(?:$|\?)/.test(resource.name));
      const observed = (window as unknown as { __liftrankMetrics: { lcp: number; cls: number; longestTask: number } }).__liftrankMetrics;
      return {
        route: routeName,
        transferBytes: resources.reduce((total, resource) => total + resource.transferSize, 0),
        encodedBytes: resources.reduce((total, resource) => total + resource.encodedBodySize, 0),
        entryScriptBytes: entryScript?.encodedBodySize ?? 0,
        imageBytes: images.reduce((total, resource) => total + resource.encodedBodySize, 0),
        imageRequests: images.length,
        requests: resources.length,
        domNodes: document.getElementsByTagName("*").length,
        documentHeight: document.body.scrollHeight,
        ...observed
      };
    }, route);
    report.push(metrics);
    expect(metrics.entryScriptBytes, `${route} entry JavaScript`).toBeLessThanOrEqual(130 * 1024);
    if (route === "library") {
      const isMobile = testInfo.project.name.includes("mobile");
      expect(metrics.encodedBytes, `Library first-load transfer (${isMobile ? "mobile" : "desktop"})`).toBeLessThanOrEqual((isMobile ? 250 : 350) * 1024);
    }
    expect(metrics.lcp, `${route} LCP`).toBeLessThanOrEqual(2500);
    expect(metrics.cls, `${route} CLS`).toBeLessThanOrEqual(0.1);
    expect(metrics.longestTask, `${route} longest task`).toBeLessThanOrEqual(200);
    await context.close();
  }
  console.log(`PERFORMANCE_REPORT ${testInfo.project.name} ${JSON.stringify(report)}`);
  await testInfo.attach("performance-report", { body: JSON.stringify(report, null, 2), contentType: "application/json" });
});
