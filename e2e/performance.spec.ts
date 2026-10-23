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
      localStorage.setItem("liftrank-public-demo-welcome-v1", "dismissed");
      const metrics = { lcp: 0, cls: 0, longestTask: 0 };
      Object.assign(window, { __LiftRivalsMetrics: metrics });
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
      const observed = (window as unknown as { __LiftRivalsMetrics: { lcp: number; cls: number; longestTask: number } }).__LiftRivalsMetrics;
      return {
        route: routeName,
        transferBytes: resources.reduce((total, resource) => total + resource.transferSize, 0),
        encodedBytes: resources.reduce((total, resource) => total + resource.encodedBodySize, 0),
        entryScriptBytes: entryScript?.encodedBodySize ?? 0,
        imageBytes: images.reduce((total, resource) => total + resource.encodedBodySize, 0),
        imageRequests: images.length,
        requests: resources.length,
        gymCatalogLoaded: resources.some((resource) => /\/assets\/gymCatalog-[^/]+\.js$/.test(new URL(resource.name).pathname)),
        largestResources: resources
          .map((resource) => ({ path: new URL(resource.name).pathname, encodedBytes: resource.encodedBodySize }))
          .sort((left, right) => right.encodedBytes - left.encodedBytes)
          .slice(0, 12),
        domNodes: document.getElementsByTagName("*").length,
        documentHeight: document.body.scrollHeight,
        ...observed
      };
    }, route);
    report.push(metrics);
    console.log(`PERFORMANCE_ROUTE ${testInfo.project.name} ${JSON.stringify(metrics)}`);
    expect(metrics.entryScriptBytes, `${route} entry JavaScript`).toBeLessThanOrEqual(130 * 1024);
    if (route === "library") {
      const isMobile = testInfo.project.name.includes("mobile");
      expect(metrics.encodedBytes, `Library first-load transfer (${isMobile ? "mobile" : "desktop"})`).toBeLessThanOrEqual((isMobile ? 250 : 350) * 1024);
    }
    if (route === "settings" || route === "onboarding") {
      expect(metrics.gymCatalogLoaded, `${route} should defer the full gym catalog until gym selection is requested`).toBe(false);
      expect(metrics.encodedBytes, `${route} first-load transfer`).toBeLessThanOrEqual(200 * 1024);
    }
    if (route === "gyms") {
      expect(metrics.gymCatalogLoaded, "Gyms directory loads the full location catalog").toBe(true);
      expect(metrics.encodedBytes, "Gyms directory first-load transfer").toBeLessThanOrEqual(500 * 1024);
    }
    expect(metrics.lcp, `${route} LCP`).toBeLessThanOrEqual(2500);
    expect(metrics.cls, `${route} CLS`).toBeLessThanOrEqual(0.1);
    expect(metrics.longestTask, `${route} longest task`).toBeLessThanOrEqual(200);
    await context.close();
  }
  console.log(`PERFORMANCE_REPORT ${testInfo.project.name} ${JSON.stringify(report)}`);
  await testInfo.attach("performance-report", { body: JSON.stringify(report, null, 2), contentType: "application/json" });
});

test("mobile gym directory meets budgets on a constrained network", async ({ browser }, testInfo) => {
  test.skip(!testInfo.project.name.includes("mobile"), "The throttled case targets a mobile viewport only");
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.addInitScript(() => {
    const metrics = { lcp: 0, cls: 0, longestTask: 0 };
    Object.assign(window, { __LiftRivalsMetrics: metrics });
    new PerformanceObserver((list) => { for (const entry of list.getEntries()) metrics.lcp = entry.startTime; }).observe({ type: "largest-contentful-paint", buffered: true });
    new PerformanceObserver((list) => { for (const entry of list.getEntries()) { const shift = entry as PerformanceEntry & { value: number; hadRecentInput: boolean }; if (!shift.hadRecentInput) metrics.cls += shift.value; } }).observe({ type: "layout-shift", buffered: true });
    new PerformanceObserver((list) => { for (const entry of list.getEntries()) metrics.longestTask = Math.max(metrics.longestTask, entry.duration); }).observe({ type: "longtask", buffered: true });
  });

  const session = await context.newCDPSession(page);
  await session.send("Network.enable");
  await session.send("Network.emulateNetworkConditions", {
    offline: false,
    latency: 150,
    downloadThroughput: 200 * 1024,
    uploadThroughput: 75 * 1024,
    connectionType: "cellular3g"
  });
  await session.send("Emulation.setCPUThrottlingRate", { rate: 4 });
  await page.goto("/#/gyms", { waitUntil: "networkidle" });
  await page.waitForTimeout(200);
  const metrics = await page.evaluate(() =>
    (window as unknown as { __LiftRivalsMetrics: { lcp: number; cls: number; longestTask: number } }).__LiftRivalsMetrics,
  );

  console.log(`PERFORMANCE_THROTTLED_GYMS ${JSON.stringify(metrics)}`);
  expect(metrics.lcp, "mobile Gym directory LCP under throttling").toBeLessThanOrEqual(2500);
  expect(metrics.cls, "mobile Gym directory CLS under throttling").toBeLessThanOrEqual(0.1);
  expect(metrics.longestTask, "mobile Gym directory longest task under throttling").toBeLessThanOrEqual(200);
  await context.close();
});
