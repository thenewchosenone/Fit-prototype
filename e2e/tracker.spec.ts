import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";

const gymCatalogMetadata = JSON.parse(readFileSync(new URL("../src/gymCatalogMetadata.json", import.meta.url), "utf8")) as { generatedAt: string };

test.beforeEach(async ({ page }) => {
  await page.goto("/#/leaderboards");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test("shows saved gyms while the full directory loads", async ({ page }) => {
  let releaseCatalog!: () => void;
  let interceptedCatalogRequests = 0;
  const catalogGate = new Promise<void>((resolve) => { releaseCatalog = resolve; });
  await page.route(/gymCatalog/, async (route) => {
    interceptedCatalogRequests += 1;
    await catalogGate;
    await route.continue();
  });
  await page.goto("/#/gyms");

  const rows = page.locator(".gym-list .object-row");
  await expect(rows).toHaveCount(9);
  await expect(page.getByRole("status")).toContainText("Showing 9 saved locations");
  await expect.poll(() => interceptedCatalogRequests).toBeGreaterThan(0);
  await page.getByLabel("Search gyms").fill("YouFit");
  await expect(page.getByRole("heading", { name: "No saved locations match yet" })).toBeVisible();
  releaseCatalog();
  await expect(page.getByText("YouFit Gyms - Weston")).toBeVisible({ timeout: 10000 });
  await page.getByRole("button", { name: "Clear filters" }).click();
  await expect(rows).toHaveCount(50);
  await expect(page.getByRole("status")).toHaveCount(0);
});

test("warns when the gym directory is more than 14 days old", async ({ page }) => {
  const generatedAt = gymCatalogMetadata.generatedAt;
  await page.clock.install({ time: new Date(Date.parse(generatedAt) + 15 * 24 * 60 * 60 * 1000) });
  await page.reload();
  await page.goto("/#/gyms");

  await expect(page.locator(".catalog-stale-warning")).toContainText("Gym directory data may be out of date");
  await expect(page.locator(".catalog-stale-warning")).toContainText(new Date(generatedAt).toLocaleDateString());
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
    ["settings", "Profile and settings"],
    ["library", "Library"],
    ["gyms", "Gyms"],
    ["community", "Strength community"],
    ["messages", "Messages"],
    ["profile", "Robert J."],
    ["onboarding", "Build your Lift Rivals profile"],
    ["library/back-squat", "Back Squat"]
  ] as const;

  for (const [route, heading] of routes) {
    await page.goto(`/#/${route}`);
    await expect(page.getByRole("heading", { name: heading, exact: true }).first()).toBeVisible();
    const accessibleControls = (await page.locator("body").ariaSnapshot()).split("\n")
      .filter((line) => /^\s*-\s+(button|link|textbox|combobox|checkbox|radio|tab)(?:\s|$)/.test(line));
    expect(accessibleControls.length, `${route} accessibility snapshot should expose interactive controls`).toBeGreaterThan(0);
    expect(
      accessibleControls.filter((line) => !/^\s*-\s+(button|link|textbox|combobox|checkbox|radio|tab)\s+"\S/.test(line)),
      `${route} should not expose unnamed interactive controls`
    ).toEqual([]);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    expect(overflow, `${route} should not overflow horizontally`).toBe(false);
    if (route === "community") {
      const selects = page.locator(".browse-groups select, .category-filter select");
      expect(await selects.count()).toBe(2);
      const presentation = await selects.evaluateAll((elements) => elements.map((element) => {
        const style = getComputedStyle(element);
        return { height: element.getBoundingClientRect().height, background: style.backgroundColor, color: style.color };
      }));
      expect(presentation.every((item) => item.height >= 44)).toBe(true);
      expect(presentation.every((item) => item.background === "rgb(13, 16, 22)" && item.color === "rgb(247, 248, 251)")).toBe(true);
    }
    if (route === "gyms") {
      const selects = page.locator(".gym-directory-toolbar .filter-field select");
      await expect(selects).toHaveCount(2);
      const presentation = await selects.evaluateAll((elements) => elements.map((element) => {
        const style = getComputedStyle(element);
        return { height: element.getBoundingClientRect().height, background: style.backgroundColor, color: style.color };
      }));
      expect(presentation.every((item) => item.height >= 44)).toBe(true);
      expect(presentation.every((item) => item.background === "rgb(13, 16, 22)" && item.color === "rgb(247, 248, 251)")).toBe(true);
    }
    if (route === "settings") {
      const choosePhoto = page.getByText("Choose photo", { exact: true });
      await expect(choosePhoto).toBeVisible();
      const photoButtonGeometry = await choosePhoto.evaluate((element) => {
        const button = element.closest("label")!;
        const card = button.closest(".profile-photo-editor")!;
        return { buttonRight: button.getBoundingClientRect().right, cardRight: card.getBoundingClientRect().right };
      });
      expect(photoButtonGeometry.buttonRight).toBeLessThanOrEqual(photoButtonGeometry.cardRight + 1);
      const notice = page.locator(".narrow-page > .catalog-inline-loading");
      const loadDirectory = notice.getByRole("button", { name: "Load full gym directory" });
      await expect(loadDirectory).toBeVisible();
      const geometry = await loadDirectory.evaluate((element) => ({
        buttonWidth: element.getBoundingClientRect().width,
        containerWidth: element.parentElement!.getBoundingClientRect().width,
        height: element.getBoundingClientRect().height
      }));
      expect(geometry.height).toBeGreaterThanOrEqual(44);
      if ((page.viewportSize()?.width ?? 0) <= 680) {
        expect(geometry.buttonWidth).toBeGreaterThanOrEqual(geometry.containerWidth - 2);
      }
    }
    if (route === "plans") {
      const removeExerciseButtons = page.locator(".exercise-preview button");
      expect(await removeExerciseButtons.count()).toBeGreaterThan(0);
      const targetSizes = await removeExerciseButtons.evaluateAll((elements) => elements.map((element) => {
        const rect = element.getBoundingClientRect();
        return { width: rect.width, height: rect.height };
      }));
      expect(targetSizes.every(({ width, height }) => width >= 44 && height >= 44)).toBe(true);
    }
    if (route === "onboarding" && (page.viewportSize()?.width ?? 0) <= 680) {
      const geometry = await page.getByRole("button", { name: "Continue" }).evaluate((button) => {
        const nav = document.querySelector(".mobile-nav")!;
        const buttonRect = button.getBoundingClientRect();
        return { buttonBottom: buttonRect.bottom, buttonHeight: buttonRect.height, navTop: nav.getBoundingClientRect().top };
      });
      expect(geometry.buttonHeight).toBeGreaterThanOrEqual(44);
      expect(geometry.buttonBottom).toBeLessThanOrEqual(geometry.navTop);
    }
  }

  const notificationBadge = page.locator(".notification-control > .icon-button > span");
  await expect(notificationBadge).toBeVisible();
  const textContrast = (element: HTMLElement) => {
    const rgb = (value: string) => value.match(/[\d.]+/g)!.slice(0, 3).map(Number).map((channel) => {
      const normalized = channel / 255;
      return normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
    });
    const [foreground, background] = [getComputedStyle(element).color, getComputedStyle(element).backgroundColor]
      .map((value) => rgb(value));
    const luminance = (channels: number[]) => 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
    const [light, dark] = [luminance(foreground), luminance(background)].sort((left, right) => right - left);
    return (light + 0.05) / (dark + 0.05);
  };
  const badgeContrast = await notificationBadge.evaluate(textContrast);
  expect(badgeContrast).toBeGreaterThanOrEqual(4.5);

  await page.goto("/#/plans");
  const selectedWeek = page.locator('.week-tabs button[aria-selected="true"]');
  await expect(selectedWeek).toBeVisible();
  expect(await selectedWeek.evaluate(textContrast)).toBeGreaterThanOrEqual(4.5);

  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test("progresses through every onboarding step with reachable mobile actions", async ({ page }) => {
  await page.goto("/#/onboarding");
  const stepHeadings = [
    "What are you training for?",
    "Choose your training preferences",
    "Select your primary gym",
    "Add optional starting lifts",
    "Choose what your demo profile shows"
  ];

  for (const [index, heading] of stepHeadings.entries()) {
    await expect(page.getByRole("heading", { name: heading })).toBeVisible();
    if (index === 2) await expect(page.getByLabel("Primary gym")).toBeVisible();
    const action = page.getByRole("button", { name: index === stepHeadings.length - 1 ? "Finish setup" : "Continue" });
    await expect(action).toBeEnabled();

    if ((page.viewportSize()?.width ?? 0) <= 680) {
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      const geometry = await action.evaluate((button) => {
        const nav = document.querySelector(".mobile-nav")!;
        const buttonRect = button.getBoundingClientRect();
        return { buttonBottom: buttonRect.bottom, buttonHeight: buttonRect.height, navTop: nav.getBoundingClientRect().top };
      });
      expect(geometry.buttonHeight).toBeGreaterThanOrEqual(44);
      expect(geometry.buttonBottom).toBeLessThanOrEqual(geometry.navTop);
    }

    await action.click();
    if (index < stepHeadings.length - 1) await page.evaluate(() => window.scrollTo(0, 0));
  }

  await expect(page.getByRole("heading", { name: "Welcome back, Robert" })).toBeVisible();
});

test("opens the restored workout tracker and keeps the library available", async ({ page }) => {
  await page.goto("/#/today");
  await expect(page.getByRole("heading", { name: "Ready to train?" })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Workout tracking" })).toBeVisible();
  await page.getByRole("button", { name: /Start workout/i }).click();
  await expect(page.getByRole("heading", { name: "Push" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Finish workout" })).toBeVisible();
  const firstExercise = page.locator(".track-exercise").first();
  await firstExercise.getByLabel("Set 1 weight").fill("185");
  await firstExercise.getByLabel("Set 1 reps").fill("8");
  await firstExercise.getByRole("button", { name: "Complete set 1" }).click();
  if ((page.viewportSize()?.width ?? 0) <= 680) {
    const geometry = await page.evaluate(() => {
      const footer = document.querySelector(".workout-footer")!.getBoundingClientRect();
      const nav = document.querySelector(".mobile-nav")!.getBoundingClientRect();
      const table = document.querySelector(".set-table")!.getBoundingClientRect();
      const firstRow = document.querySelector(".set-row")!;
      const lastCellRight = Math.max(...[...firstRow.children].map((cell) => cell.getBoundingClientRect().right));
      const complete = document.querySelector(".complete-set")!.getBoundingClientRect();
      const deleteAction = document.querySelector(".delete-set")!.getBoundingClientRect();
      return { footerBottom: footer.bottom, navTop: nav.top, tableRight: table.right, lastCellRight, completeWidth: complete.width, completeHeight: complete.height, deleteRight: deleteAction.right };
    });
    expect(geometry.footerBottom).toBeLessThanOrEqual(geometry.navTop);
    expect(geometry.lastCellRight).toBeLessThanOrEqual(geometry.tableRight + 1);
    expect(geometry.deleteRight).toBeLessThanOrEqual(geometry.tableRight + 1);
    expect(geometry.completeWidth).toBeGreaterThanOrEqual(44);
    expect(geometry.completeHeight).toBeGreaterThanOrEqual(44);
  }
  await page.getByRole("button", { name: "Finish workout" }).click();
  const finishDialog = page.getByRole("dialog");
  await expect(finishDialog.getByRole("heading", { name: "Finish Workout" })).toBeVisible();
  await finishDialog.getByRole("button", { name: "Finish with 5 incomplete" }).click();
  await expect(page).toHaveURL(/#\/progress$/);
  await expect(page.getByRole("heading", { name: "Workout history" })).toBeVisible();
  const completedWorkout = page.getByRole("link", { name: "Open Push workout details" });
  await expect(completedWorkout).toBeVisible();
  await expect(completedWorkout.locator(".history-metrics")).toContainText("1 sets");
  await expect(completedWorkout.locator(".history-metrics")).toContainText("1,480 lb");
  await completedWorkout.click();
  await expect(page.getByRole("heading", { name: "Push", exact: true })).toBeVisible();
  await expect(page.locator(".workout-detail-exercises").getByText("185 lb × 8", { exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Progress" }).click();
  await page.goto("/#/library");
  await expect(page.getByRole("heading", { name: "Library" })).toBeVisible();
  await page.getByLabel("Search exercises").fill("bench");
  await expect(page.getByText("Barbell Bench Press")).toBeVisible();
});

test("keeps the full Library searchable and keyboard reachable during deep scrolling", async ({ page }) => {
  await page.goto("/#/library");
  const cards = page.locator(".exercise-card");
  expect(await cards.count()).toBe(100);
  expect(await page.locator("body *").count()).toBeLessThan(2500);
  await page.getByRole("button", { name: "Show more exercises" }).click();
  await expect(cards).toHaveCount(200);
  await page.getByRole("button", { name: "Show more exercises" }).click();
  expect(await cards.count()).toBeGreaterThan(200);
  const lastLink = cards.last().getByRole("link");
  await page.getByLabel("Search exercises").focus();
  let reachedLastExerciseByKeyboard = false;
  for (let index = 0; index < (await cards.count()) + 40; index += 1) {
    await page.keyboard.press("Tab");
    if (await lastLink.evaluate((element) => element === document.activeElement)) {
      reachedLastExerciseByKeyboard = true;
      break;
    }
  }
  expect(reachedLastExerciseByKeyboard).toBe(true);
  await expect(lastLink).toBeVisible();
  const focusOutline = await lastLink.evaluate((element) => {
    const style = getComputedStyle(element);
    return { color: style.outlineColor, style: style.outlineStyle, width: style.outlineWidth };
  });
  expect(focusOutline).toEqual({ color: "rgb(104, 180, 255)", style: "solid", width: "3px" });
  await page.getByLabel("Search exercises").fill("barbell curl");
  await expect(page.getByText("Barbell Curl", { exact: true })).toBeVisible();
});

test("opens the leaderboard page and athlete detail", async ({ page }) => {
  await page.getByRole("link", { name: "Leaderboards" }).click();
  await expect(page.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
  const athleteRow = page.getByRole("row", { name: /Robert J\./ });
  await athleteRow.focus();
  await page.keyboard.press("Enter");
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await expect(dialog).toHaveAccessibleName(/\S+/);
  await expect(dialog.getByText("Current rank")).toBeVisible();
  await expect(dialog).toBeFocused();

  const focusable = dialog.locator('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])');
  const firstFocusable = focusable.first();
  const lastFocusable = focusable.last();
  await firstFocusable.focus();
  await page.keyboard.press("Shift+Tab");
  await expect(lastFocusable).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(firstFocusable).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(dialog).toHaveCount(0);
  await expect(athleteRow).toBeFocused();
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
  await expect(page.getByLabel("Brand")).toContainText("YouFit");
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
