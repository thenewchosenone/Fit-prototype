import { expect, test } from "@playwright/test";
import type { Page } from "@playwright/test";

type GateMode = "production" | "demo";
const gateMode = (process.env.LIFT RIVALS_RELEASE_WEB_MODE ?? "production") as GateMode;

const expectProtectedRouteRedirect = async (page: Page, path: string) => {
  await page.goto(`/#${path}`);
  await page.waitForURL((url) => url.href.includes("/#/login"));
  await expect(page.getByRole("heading", { name: "Welcome back" })).toBeVisible();
};

test.describe(`web release route smoke (${gateMode} mode)`, () => {
  test.beforeEach(async ({ page }) => {
    await page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
      document.cookie.split(";").forEach((cookie) => {
        const [name] = cookie.split("=");
        document.cookie = `${name}=; Max-Age=0`;
      });
    });
  });

  test("loads unauthenticated public pages and has no JS errors", async ({ page }) => {
    const routeErrors: string[] = [];
    page.on("pageerror", (error) => routeErrors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") routeErrors.push(message.text());
    });

    await page.goto("/#/leaderboards");
    await expect(page.getByRole("heading", { name: "Leaderboards" })).toBeVisible();

    const publicRoutes = ["/leaderboards", "/library", "/privacy", "/terms", "/contact", "/demo", "/gyms"];
    if (gateMode === "demo") {
      publicRoutes.push("/home");
    }

    for (const route of publicRoutes) {
      await page.goto(`/#${route}`);
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
      expect(overflow, `${route} should not overflow horizontally`).toBe(false);
    }

    expect(routeErrors).toEqual([]);
  });

  test("validates auth route behaviour for protected web routes", async ({ page }) => {
    if (gateMode === "demo") {
      await page.goto("/#/login");
      await expect(page).toHaveURL(/#\/leaderboards$/);
      return;
    }

    await expectProtectedRouteRedirect(page, "/today");
    await expectProtectedRouteRedirect(page, "/plans");
    await expectProtectedRouteRedirect(page, "/progress");
    await expectProtectedRouteRedirect(page, "/submit");
    await expectProtectedRouteRedirect(page, "/profile");
    await expectProtectedRouteRedirect(page, "/settings");
  });

  test("checks deferred-route redirects and shared auth redirects", async ({ page }) => {
    if (gateMode === "demo") {
      await page.goto("/#/messages");
      await expect(page).toHaveURL(/#\/home$/);
      return;
    }

    await page.goto("/#/community");
    await expect(page).toHaveURL(/#\/home$/);
    await page.goto("/#/messages");
    await expect(page).toHaveURL(/#\/home$/);
    await page.goto("/#/messages/thread-1");
    await expect(page).toHaveURL(/#\/home$/);
  });
});
