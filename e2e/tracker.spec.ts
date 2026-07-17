import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/#/leaderboards");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test("loads every primary route without console errors or horizontal overflow", async ({ page }) => {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));

  const routes = [
    ["home", "Welcome back, Robert"],
    ["today", "Ready to train?"],
    ["plans", "Training plans"],
    ["progress", "Progress"],
    ["leaderboards", "Leaderboards"],
    ["submit", "Submit a lift"],
    ["library", "Library"],
    ["gyms", "Gyms"],
    ["community", "Strength community"],
    ["messages", "Messages"],
    ["profile", "Robert J."],
    ["settings", "Profile and settings"],
    ["onboarding", "Build your LiftRank profile"],
    ["library/back-squat", "Back Squat"]
  ] as const;

  for (const [route, heading] of routes) {
    await page.goto(`/#/${route}`);
    await expect(page.getByRole("heading", { name: heading, exact: true }).first()).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    expect(overflow, `${route} should not overflow horizontally`).toBe(false);
  }

  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test("opens the restored workout tracker and keeps the library available", async ({ page }) => {
  await page.goto("/#/today");
  await expect(page.getByRole("heading", { name: "Ready to train?" })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Workout tracking" })).toBeVisible();
  await page.getByRole("button", { name: /Start workout/i }).click();
  await expect(page.getByRole("heading", { name: "Push" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Finish workout" })).toBeVisible();
  await page.goto("/#/library");
  await expect(page.getByRole("heading", { name: "Library" })).toBeVisible();
  await page.getByLabel("Search exercises").fill("bench");
  await expect(page.getByText("Barbell Bench Press")).toBeVisible();
});

test("keeps the full Library searchable and keyboard reachable during deep scrolling", async ({ page }) => {
  await page.goto("/#/library");
  const cards = page.locator(".exercise-card");
  expect(await cards.count()).toBeGreaterThan(200);
  const lastLink = cards.last().getByRole("link");
  await lastLink.scrollIntoViewIfNeeded();
  await expect(lastLink).toBeVisible();
  await lastLink.focus();
  await expect(lastLink).toBeFocused();
  await page.getByLabel("Search exercises").fill("barbell curl");
  await expect(page.getByText("Barbell Curl", { exact: true })).toBeVisible();
});

test("opens the leaderboard page and athlete detail", async ({ page }) => {
  await page.getByRole("link", { name: "Leaderboards" }).click();
  await expect(page.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
  await page.getByRole("row", { name: /Robert J\./ }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(page.getByRole("dialog").getByText("Current rank")).toBeVisible();
});

test("submits a lift and opens the local profile", async ({ page }) => {
  await page.goto("/#/submit");
  await page.getByLabel("Weight lifted").fill("505");
  await page.getByRole("button", { name: "Submit lift" }).click();
  await expect(page.getByRole("heading", { name: "Lift submitted" })).toBeVisible();
  await page.getByRole("link", { name: "View profile" }).click();
  await expect(page.getByRole("heading", { name: "Robert J." })).toBeVisible();
});

test("opens community comments and manages a pending friend request", async ({ page }) => {
  await page.getByRole("link", { name: "Community" }).first().click();
  await page.locator(".feed-list .feed-copy").filter({ hasText: "585 moved clean" }).click();
  await expect(page.getByText("Strong pull. The lockout looked decisive.")).toBeVisible();
  await page.goto("/#/friends");
  await page.getByRole("button", { name: "Cancel" }).click();
  await expect(page.getByText("No pending requests.")).toBeVisible();
});

test("filters gyms, sends a message, and switches profile tabs", async ({ page }) => {
  await page.goto("/#/gyms");
  await page.getByLabel("Brand").selectOption("YouFit");
  await page.getByLabel("State").selectOption("Florida");
  await page.getByLabel("Search gyms").fill("33326");
  await expect(page.getByText("YouFit Gyms - Weston")).toBeVisible();

  await page.goto("/#/messages/thread-1");
  await page.getByRole("textbox", { name: "Message" }).fill("Responsive message flow verified.");
  await page.getByRole("button", { name: "Send message" }).click();
  await expect(page.getByText("Responsive message flow verified.")).toBeVisible();

  await page.goto("/#/profile");
  await page.getByRole("button", { name: "Lifts" }).click();
  await expect(page.getByRole("heading", { name: "Lift submissions" })).toBeVisible();
  await page.getByRole("button", { name: "Achievements" }).click();
  await expect(page.getByRole("heading", { name: "Achievements" })).toBeVisible();
});
