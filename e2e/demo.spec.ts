import { expect, test } from "@playwright/test";

test("explains and isolates the public demo", async ({ page }) => {
  const unexpectedRequests: string[] = [];
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.origin !== "http://127.0.0.1:4174") unexpectedRequests.push(request.url());
  });
  await page.goto("/#/leaderboards");
  await expect(page.getByRole("dialog", { name: "Explore Lift Rivals" })).toBeVisible();
  await expect(page.getByText("Lift Rivals Demo", { exact: true })).toBeVisible();
  await expect(page.getByText("Changes stay in this browser.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Log out" })).toHaveCount(0);
  await page.getByRole("button", { name: "Start exploring" }).click();
  await page.reload();
  await expect(page.getByRole("dialog", { name: "Explore Lift Rivals" })).toHaveCount(0);
  expect(unexpectedRequests).toEqual([]);
});

test("redirects account routes and labels local mutations", async ({ page }) => {
  await page.goto("/#/login");
  await expect(page).toHaveURL(/#\/leaderboards$/);
  await page.getByRole("button", { name: "Start exploring" }).click();
  await page.goto("/#/submit");
  await expect(page.getByText("This submission updates only your browser-local demo rankings and profile.")).toBeVisible();
  await page.goto("/#/messages");
  await expect(page.getByText("These seeded conversations and anything you type remain only in this browser.")).toBeVisible();
  await page.goto("/#/community");
  await expect(page.getByText("Posts, comments, votes, reports, and group memberships stay in this browser.")).toBeVisible();
});

test("resets browser-local activity and restores the welcome state", async ({ page }) => {
  await page.goto("/#/submit");
  await page.getByRole("button", { name: "Start exploring" }).click();
  await page.getByLabel("Weight lifted").fill("505");
  await page.getByRole("button", { name: "Submit lift" }).click();
  await expect(page.getByRole("heading", { name: "Lift submitted" })).toBeVisible();
  await page.getByRole("button", { name: "Reset" }).click();
  await expect(page.getByRole("dialog", { name: "Reset the Lift Rivals demo?" })).toBeVisible();
  await page.getByRole("button", { name: "Reset demo data" }).click();
  await expect(page.getByRole("dialog", { name: "Explore Lift Rivals" })).toBeVisible();
  await page.getByRole("button", { name: "Start exploring" }).click();
  await expect(page.getByLabel("Weight lifted")).toHaveValue("");
});

test("serves public information, feedback, and share metadata", async ({ page }) => {
  await page.goto("/#/privacy");
  await page.getByRole("button", { name: "Start exploring" }).click();
  await expect(page.getByRole("heading", { name: "Privacy notice" })).toBeVisible();
  await page.goto("/#/terms");
  await expect(page.getByRole("heading", { name: "Demo terms" })).toBeVisible();
  await page.goto("/#/contact");
  const feedback = page.getByRole("link", { name: /Open GitHub feedback/ });
  await expect(feedback).toHaveAttribute("href", "https://github.com/thenewchosenone/Fit-prototype/issues/new");
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute("content", "https://LiftRivals-demo.pages.dev/LiftRivals-demo-card.png");
  await expect(page.locator('link[rel="icon"]')).toHaveAttribute("href", /favicon\.svg$/);
});
