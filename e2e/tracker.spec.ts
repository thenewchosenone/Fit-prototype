import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/#/today");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test("starts and cancels a planned workout", async ({ page }) => {
  await page.getByRole("button", { name: "Start workout" }).click();
  await expect(page.getByRole("heading", { name: "Push" })).toBeVisible();
  await expect(page.locator("article").first().getByLabel("Set 1 weight")).toHaveValue("");
  await page.getByRole("button", { name: "Cancel workout" }).click();
  await page.getByRole("button", { name: "Discard workout" }).click();
  await expect(page.getByRole("heading", { name: "Ready to train?" })).toBeVisible();
});

test("adds an exercise to a freestyle workout", async ({ page }) => {
  await page.getByRole("button", { name: /start freestyle workout/i }).click();
  await expect(page.getByRole("heading", { name: "Freestyle Workout" })).toBeVisible();
  await page.getByRole("button", { name: "Add exercise" }).click();
  await page.getByLabel("Search exercises to add").fill("Hack Squat");
  await page.locator(".picker-list button").filter({ hasText: "Hack Squat" }).first().click();
  await page.getByRole("button", { name: "Add to workout" }).click();
  await expect(page.getByRole("heading", { name: "Hack Squat" })).toBeVisible();
});

test("opens the leaderboard page and athlete detail", async ({ page }) => {
  await page.getByRole("link", { name: "Leaderboards" }).click();
  await expect(page.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
  await page.getByRole("button", { name: /Robert J\./ }).first().click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(page.getByRole("dialog").getByText("Current rank")).toBeVisible();
});

test("submits a lift and opens the local profile", async ({ page }) => {
  await page.getByRole("link", { name: "Submit" }).first().click();
  await page.getByLabel("Weight lifted").fill("505");
  await page.getByRole("button", { name: "Submit lift" }).click();
  await expect(page.getByRole("heading", { name: "Lift submitted" })).toBeVisible();
  await page.getByRole("link", { name: "View profile" }).click();
  await expect(page.getByRole("heading", { name: "Robert J." })).toBeVisible();
});

test("opens community comments and manages a pending friend request", async ({ page }) => {
  await page.getByRole("link", { name: "Community" }).first().click();
  await page.getByRole("link", { name: /585 moved clean/ }).click();
  await expect(page.getByText("Strong pull. The lockout looked decisive.")).toBeVisible();
  await page.goto("/#/friends");
  await page.getByRole("button", { name: "Cancel" }).click();
  await expect(page.getByText("No pending requests.")).toBeVisible();
});
