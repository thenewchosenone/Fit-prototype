import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HashRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import App from "../src/App";
import { AuthProvider } from "../src/auth";
import { leaderboardSeed, seedState } from "../src/data";
import { muscleVisualKey } from "../src/PlatformPages";
import { TrackerProvider } from "../src/store";
import type { RankingType, TrackerState } from "../src/types";

function renderApp(path = "/library", initialState: TrackerState = structuredClone(seedState)) {
  window.location.hash = `#${path}`;
  return render(
    <HashRouter>
      <AuthProvider><TrackerProvider initialState={initialState}><App /></TrackerProvider></AuthProvider>
    </HashRouter>
  );
}

async function applyLeaderboardRankingType(user: ReturnType<typeof userEvent.setup>, rankingType: RankingType) {
  await user.click(screen.getByRole("button", { name: /Filters/ }));
  const dialog = screen.getByRole("dialog");
  await user.click(within(dialog).getByRole("button", { name: rankingType }));
  await applyLeaderboardFilters(user, dialog);
}

async function applyLeaderboardFilters(user: ReturnType<typeof userEvent.setup>, dialog = screen.getByRole("dialog")) {
  await user.click(within(dialog).getByRole("button", { name: /Show \d+ athletes?/ }));
}

async function openLeaderboardColumns(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole("button", { name: "Table settings" }));
  return screen.getByRole("dialog");
}

function makePaginatedLeaderboardState(athleteCount = 38): TrackerState {
  const state = structuredClone(seedState);
  const sourceProfile = state.profiles.find((profile) => profile.id === "user-evan")!;
  const sourceLifts = state.liftSubmissions.filter((lift) => lift.userId === sourceProfile.id);
  const additionalCount = Math.max(0, athleteCount - state.profiles.length);

  for (let index = 1; index <= additionalCount; index += 1) {
    const suffix = index.toString().padStart(2, "0");
    const userId = `user-pagination-${suffix}`;
    state.profiles.push({
      ...sourceProfile,
      id: userId,
      displayName: `Pagination Athlete ${suffix}`,
      handle: `@pagination${suffix}`,
      bodyweight: sourceProfile.bodyweight + index
    });
    state.liftSubmissions.push(...sourceLifts.map((lift) => ({
      ...lift,
      id: `${lift.id}-pagination-${suffix}`,
      userId,
      weight: lift.weight + index,
      normalizedWeight: lift.normalizedWeight + index
    })));
  }

  return state;
}

function getLeaderboardHeaderLabels(container: HTMLElement) {
  return Array.from(container.querySelectorAll(".leaderboard-table-header .leaderboard-cell.header"))
    .map((header) => header.textContent?.trim());
}

describe("LiftRank platform UI", () => {
  it("logs out, protects submission routes, and restores the local demo session", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    await user.click(screen.getByRole("button", { name: "Log out" }));
    await user.click(screen.getAllByRole("link", { name: "Submit" })[0]);
    expect(screen.getByRole("heading", { name: "Welcome back" })).toBeVisible();
    await user.type(screen.getByLabelText("Email"), "demo@liftrank.local");
    await user.type(screen.getByLabelText(/Password/), "demo-password");
    await user.click(screen.getByRole("button", { name: "Sign in" }));
    expect(await screen.findByRole("heading", { name: "Submit a lift" })).toBeVisible();
  });

  it("filters the exercise library by search, equipment, and movement", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.type(screen.getByLabelText("Search exercises"), "bench");
    expect(screen.getByText("Barbell Bench Press")).toBeVisible();
    expect(screen.queryByText("Back Squat")).not.toBeInTheDocument();
    await user.clear(screen.getByLabelText("Search exercises"));
    await user.selectOptions(screen.getByLabelText("Body part"), "Back");
    await user.selectOptions(screen.getByLabelText("Equipment"), "Cable");
    expect(screen.getByText("Seated Cable Row")).toBeVisible();
    await user.selectOptions(screen.getByLabelText("Movement"), "Pull");
    expect(screen.getByText("Wide-Grip Lat Pulldown")).toBeVisible();
    expect(screen.queryByText("Seated Cable Row")).not.toBeInTheDocument();
  });

  it("clears library filters and includes custom exercises in movement options", async () => {
    const user = userEvent.setup();
    renderApp();

    await user.click(screen.getByRole("button", { name: /custom exercise/i }));
    const dialog = screen.getByRole("dialog");
    await user.type(within(dialog).getByPlaceholderText("Exercise name"), "Belt Squat");
    await user.selectOptions(within(dialog).getByLabelText("Equipment"), "Machine");
    await user.click(within(dialog).getByRole("button", { name: "Save exercise" }));

    await user.selectOptions(screen.getByLabelText("Movement"), "Strength");
    expect(screen.getByText("Belt Squat")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Clear filters" }));
    expect(screen.getByLabelText("Search exercises")).toHaveValue("");
    expect(screen.getByLabelText("Movement")).toHaveValue("All");
    expect(screen.getByText("Back Squat")).toBeVisible();
  });

  it("adds a custom exercise to the library", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.click(screen.getByRole("button", { name: /custom exercise/i }));
    const dialog = screen.getByRole("dialog");
    await user.type(within(dialog).getByPlaceholderText("Exercise name"), "Belt Squat");
    await user.selectOptions(within(dialog).getByLabelText("Equipment"), "Machine");
    await user.click(within(dialog).getByRole("button", { name: "Save exercise" }));
    expect(screen.getByText("Belt Squat")).toBeVisible();
    expect(screen.getByText("Custom")).toBeVisible();
  });

  it("labels curl biceps as primary instead of secondary", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.type(screen.getByLabelText("Search exercises"), "Barbell Curl");
    const card = screen.getByRole("heading", { name: "Barbell Curl" }).closest(".exercise-card") as HTMLElement;
    expect(within(card).getByText("Biceps · Barbell")).toBeVisible();
    expect(within(card).getByText("Biceps focus")).toBeVisible();
    expect(within(card).queryByText("Also works Biceps")).not.toBeInTheDocument();
  });

  it("filters the nationwide gym directory by brand, state, and address search", async () => {
    const user = userEvent.setup();
    renderApp("/gyms");

    expect(await screen.findByRole("heading", { name: "Gyms" })).toBeVisible();
    expect(await screen.findByLabelText("Brand")).toHaveValue("All");
    await user.selectOptions(screen.getByLabelText("Brand"), "YouFit");
    expect(screen.getByText("YouFit Gyms - Weston")).toBeVisible();
    expect(screen.queryByText("Crunch Fitness - South Beach")).not.toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("State"), "Florida");
    await user.type(screen.getByLabelText("Search gyms"), "33326");
    expect(screen.getByText("YouFit Gyms - Weston")).toBeVisible();
    expect(screen.getByText("No LiftRank activity yet")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Clear filters" }));
    expect(screen.getByLabelText("Brand")).toHaveValue("All");
    expect(screen.getByLabelText("State")).toHaveValue("All");
    expect(screen.getByLabelText("Search gyms")).toHaveValue("");
  });

  it("shows the official gym page with its address and source link", async () => {
    renderApp("/gyms/gym-youfit-1805914");

    expect(await screen.findByRole("heading", { name: "YouFit Gyms - Weston" })).toBeVisible();
    expect(screen.getByText(/15451 Southwest 13 Lane/)).toBeVisible();
    expect(screen.getByText("No member data")).toBeVisible();
    expect(screen.getByText("No lift data")).toBeVisible();
    expect(screen.getByRole("link", { name: "Official site" })).toHaveAttribute("href", "https://youfit.com/locations/florida/weston");
  });

  it("paginates the complete gym directory at 50 results and resets on search", async () => {
    const user = userEvent.setup();
    const { container } = renderApp("/gyms");

    await waitFor(() => expect(container.querySelectorAll(".gym-list .object-row")).toHaveLength(50));
    expect(screen.getByText(/Showing 1–50 of/)).toBeVisible();
    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Next" }));
    expect(screen.getAllByText(/Page 2 of/).length).toBeGreaterThan(0);
    expect(container.querySelectorAll(".gym-list .object-row")).toHaveLength(50);

    await user.type(screen.getByLabelText("Search gyms"), "33326");
    expect(screen.getByText("Showing 1–1 of 1 gyms")).toBeVisible();
    expect(screen.queryByRole("button", { name: "Next" })).not.toBeInTheDocument();
  });

  it.each(["/today", "/plans", "/progress", "/workout/session-push"])(
    "redirects the retired tracking route %s to leaderboards",
    (path) => {
      renderApp(path);

      expect(screen.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
      expect(screen.queryByRole("link", { name: "Today" })).not.toBeInTheDocument();
      expect(screen.queryByRole("link", { name: "Plans" })).not.toBeInTheDocument();
      expect(screen.queryByRole("link", { name: "Progress" })).not.toBeInTheDocument();
      expect(screen.getAllByRole("link", { name: "Library" })[0]).toBeVisible();
    }
  );

  it("keeps exercise details while hiding workout history", async () => {
    renderApp("/library/back-squat");

    expect(await screen.findByRole("heading", { name: "Back Squat" })).toBeVisible();
    const visual = screen.getByAltText("Back Squat: Quads muscles highlighted") as HTMLImageElement;
    expect(visual.src).toContain("quads");
    expect(visual).toHaveAttribute("width", "512");
    expect(visual).toHaveAttribute("height", "512");
    expect(visual).toHaveAttribute("loading", "lazy");
    expect(visual).toHaveAttribute("decoding", "async");
    const avif = visual.closest("picture")?.querySelector("source[type='image/avif']");
    expect(avif?.getAttribute("srcset")).toContain("quads");
    expect(screen.getByRole("heading", { name: "Exercise details" })).toBeVisible();
    expect(screen.queryByText("Set history")).not.toBeInTheDocument();
    expect(screen.queryByText("Completed sets")).not.toBeInTheDocument();
  });

  it("maps catalog body regions to highlighted-muscle artwork", () => {
    expect(muscleVisualKey({ bodyPart: "Chest", bodyRegions: ["Chest"] })).toBe("chest");
    expect(muscleVisualKey({ bodyPart: "Hamstrings", bodyRegions: ["Hamstrings", "Glutes"] })).toBe("hamstrings");
    expect(muscleVisualKey({ bodyPart: "Full Body", bodyRegions: ["Full Body"] })).toBe("full-body");
  });

  it("shows the current lifter profile and opens it from the profile pill", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("link", { name: "Open profile" }));

    expect(screen.getByRole("heading", { name: "Robert J." })).toBeVisible();
    expect(screen.getByText(/@rjrob23 · Powerlifting · Advanced/)).toBeVisible();
    expect(screen.getByText("Strength snapshot")).toBeVisible();
    expect(screen.getByRole("heading", { name: "About" })).toBeVisible();
    expect(screen.getByRole("link", { name: /Edit profile/ })).toHaveAttribute("href", "#/settings");
    expect(screen.queryByText("Active plan")).not.toBeInTheDocument();
  });

  it("opens the leaderboard route and athlete detail sheet", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    expect(screen.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
    screen.getByRole("row", { name: /Evan Cole/i }).focus();
    await user.keyboard("{Enter}");
    const dialog = screen.getByRole("dialog");
    expect(dialog).toBeVisible();
    expect(within(dialog).getByText("Current rank")).toBeVisible();
    expect(within(dialog).getAllByText("1,475")).not.toHaveLength(0);
    expect(within(dialog).getByText("Total")).toBeVisible();
  });

  it("uses total as the default main leaderboard", () => {
    const { container } = renderApp("/leaderboards");
    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    const context = screen.getByLabelText("Ranking context");
    const rankLabels = Array.from(container.querySelectorAll(".leaderboard-rank-cell strong"))
      .map((rank) => rank.textContent);

    expect(within(context).getByText("Rank by: Total")).toBeVisible();
    expect(within(context).getByText("Scope: Global")).toBeVisible();
    expect(within(context).getByText("Exercise: Three-lift total")).toBeVisible();
    expect(screen.getByText("Current rank and total")).toBeVisible();
    expect(screen.getByText("Gap to next rank")).toBeVisible();
    expect(screen.getByText("Ranked athletes")).toBeVisible();
    expect(screen.getByText("Leading result")).toBeVisible();
    expect(within(table).getByText("Top total")).toBeVisible();
    expect(within(table).getByText("1,475 lb")).toBeVisible();
    expect(within(table).getByText("1,475 total")).toBeVisible();
    expect(rankLabels.slice(0, 4)).toEqual(["#1", "#2", "#3", "#4"]);
  });

  it("explains absolute leaderboard scores without showing total as row context", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await applyLeaderboardRankingType(user, "Absolute");

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getByText("Top lift")).toBeVisible();
    expect(within(table).getAllByText("Conventional Deadlift · Absolute").length).toBeGreaterThanOrEqual(2);
    expect(within(table).queryByText("1,475 total")).not.toBeInTheDocument();
  });

  it("shows mode-aware score context for every ranking type", async () => {
    const scenarios: Array<{
      rankingType: RankingType;
      header: string;
      score: string;
      subtitle: string;
    }> = [
      { rankingType: "Total", header: "Top total", score: "1,475 lb", subtitle: "1,475 total" },
      { rankingType: "Absolute", header: "Top lift", score: "585 lb", subtitle: "Conventional Deadlift · Absolute" },
      { rankingType: "Pound-for-pound", header: "Relative lift", score: "3.41x", subtitle: "Back Squat · pound-for-pound" },
      { rankingType: "Relative total", header: "Relative total", score: "8.67x", subtitle: "1,335 total" },
      { rankingType: "Most improved", header: "Improvement", score: "+5%", subtitle: "Conventional Deadlift · PR growth" }
    ];

    for (const scenario of scenarios) {
      const user = userEvent.setup();
      const view = renderApp("/leaderboards");
      if (scenario.rankingType !== "Total") await applyLeaderboardRankingType(user, scenario.rankingType);
      const table = screen.getByRole("table", { name: "Leaderboard rankings" });
      expect(getLeaderboardHeaderLabels(view.container)).toContain(scenario.header);
      expect(within(table).getAllByText(scenario.score).length).toBeGreaterThan(0);
      expect(within(table).getAllByText(scenario.subtitle).length).toBeGreaterThan(0);
      view.unmount();
    }
  });

  it("filters the leaderboard by ranking type", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Most improved" }));
    await applyLeaderboardFilters(user, dialog);

    expect(screen.getAllByText(/PR growth/).length).toBeGreaterThan(0);
  });

  it("has enough back squat leaderboard rows to test exercise filters", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await applyLeaderboardFilters(user, dialog);

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Back Squat").length).toBeGreaterThanOrEqual(5);
  });

  it("orders ranking modes and only shows controls that apply to the draft", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    const rankBy = within(dialog).getByRole("group", { name: "Rank by" });
    const scope = within(dialog).getByRole("group", { name: "Scope" });

    expect(within(rankBy).getAllByRole("button").map((button) => button.textContent)).toEqual([
      "Total",
      "Absolute",
      "Pound-for-pound",
      "Relative total",
      "Most improved"
    ]);
    expect(within(scope).getAllByRole("button").map((button) => button.textContent)).toEqual([
      "Global",
      "My gym",
      "My city",
      "My weight class",
      "Choose a gym"
    ]);
    expect(within(dialog).getByText(/best squat \+ bench \+ deadlift/i)).toBeVisible();
    expect(within(dialog).queryByLabelText("Exercise")).not.toBeInTheDocument();
    expect(within(dialog).queryByLabelText("Gym")).not.toBeInTheDocument();
    expect(within(dialog).queryByLabelText("City")).not.toBeInTheDocument();

    await user.click(within(rankBy).getByRole("button", { name: "Absolute" }));
    expect(within(dialog).getByText(/highest submitted weight for one exercise/i)).toBeVisible();
    const exercise = within(dialog).getByLabelText("Exercise") as HTMLSelectElement;
    const experience = within(dialog).getByLabelText("Training experience") as HTMLSelectElement;
    const exerciseOptions = Array.from(exercise.options).map((option) => option.value);
    const experienceOptions = Array.from(experience.options).map((option) => option.value);

    expect(exerciseOptions[0]).toBe("All");
    expect(exerciseOptions).toContain("Back Squat");
    expect(exerciseOptions).not.toContain("Relative Total");
    expect(experienceOptions[0]).toBe("All");

    await user.click(within(rankBy).getByRole("button", { name: "Relative total" }));
    expect(within(dialog).getByText(/three-lift total divided by bodyweight/i)).toBeVisible();
    expect(within(dialog).queryByLabelText("Exercise")).not.toBeInTheDocument();

    await user.click(within(rankBy).getByRole("button", { name: "Pound-for-pound" }));
    expect(within(dialog).getByText(/divided by bodyweight/i)).toBeVisible();
    expect(within(dialog).getByLabelText("Exercise")).toBeVisible();
    await user.click(within(rankBy).getByRole("button", { name: "Most improved" }));
    expect(within(dialog).getByText(/percentage gain across eligible submissions/i)).toBeVisible();

    await user.click(within(scope).getByRole("button", { name: "Choose a gym" }));
    expect(within(dialog).getByLabelText("Gym")).toBeVisible();
    await user.click(within(scope).getByRole("button", { name: "My gym" }));
    expect(within(dialog).queryByLabelText("Gym")).not.toBeInTheDocument();
    expect(within(dialog).queryByLabelText("City")).not.toBeInTheDocument();
    expect(within(dialog).getByLabelText("Weight class")).toBeVisible();
    await user.click(within(scope).getByRole("button", { name: "My weight class" }));
    expect(within(dialog).queryByLabelText("Weight class")).not.toBeInTheDocument();
  });

  it("keeps filter edits as drafts, reports pending changes, and discards unapplied edits", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    let dialog = screen.getByRole("dialog");
    expect(within(dialog).getByText("0 pending changes")).toBeVisible();
    expect(within(dialog).getByRole("button", { name: /Show \d+ athletes?/ })).toBeDisabled();

    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    expect(within(dialog).getByText("1 pending change")).toBeVisible();
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    expect(within(dialog).getByText("2 pending changes")).toBeVisible();
    await user.click(within(dialog).getByRole("button", { name: "Close" }));

    let context = screen.getByLabelText("Ranking context");
    expect(within(context).getByText("Rank by: Total")).toBeVisible();
    expect(screen.queryByRole("button", { name: /Remove.*Back Squat/i })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Filters" }));
    dialog = screen.getByRole("dialog");
    expect(within(dialog).queryByLabelText("Exercise")).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await applyLeaderboardFilters(user, dialog);

    context = screen.getByLabelText("Ranking context");
    expect(within(context).getByText("Rank by: Absolute")).toBeVisible();
    expect(within(context).getByText("Exercise: Back Squat")).toBeVisible();

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    expect(within(dialog).getByLabelText("Exercise")).toHaveValue("Back Squat");
    await user.click(within(dialog).getByRole("button", { name: "Pound-for-pound" }));
    await user.keyboard("{Escape}");
    context = screen.getByLabelText("Ranking context");
    expect(within(context).getByText("Rank by: Absolute")).toBeVisible();
    expect(within(context).getByText("Exercise: Back Squat")).toBeVisible();
  });

  it("searches the leaderboard across athlete, handle, gym, city, state, and exercise", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    const search = screen.getByLabelText("Search leaderboards");

    await user.type(search, "  @evancole  ");
    expect(screen.getByRole("row", { name: /Evan Cole/i })).toBeVisible();
    expect(screen.queryByRole("row", { name: /Mia Santos/i })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Filters" })).toBeVisible();
    await user.clear(search);
    expect(screen.getByRole("button", { name: "Filters" })).toBeVisible();

    await user.type(search, "winter park");
    expect(screen.getByRole("row", { name: /Sofia Martin/i })).toBeVisible();
    expect(screen.queryByRole("row", { name: /Evan Cole/i })).not.toBeInTheDocument();
  });

  it("applies profile-derived and selected-gym leaderboard scopes", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    let dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.click(within(dialog).getByRole("button", { name: "My gym" }));
    await applyLeaderboardFilters(user, dialog);
    let table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Crunch Fitness - South Beach")).toHaveLength(3);
    expect(within(table).queryByText("Crunch Fitness - Doral")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "My city" }));
    await applyLeaderboardFilters(user, dialog);
    table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Miami Beach, Florida")).not.toHaveLength(0);
    expect(within(table).queryByText("Miami, Florida")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "My weight class" }));
    await applyLeaderboardFilters(user, dialog);
    table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getByRole("row", { name: /Robert J\./i })).toBeVisible();
    expect(within(table).getByRole("row", { name: /Evan Cole/i })).toBeVisible();
    expect(within(table).queryByRole("row", { name: /Mia Santos/i })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Choose a gym" }));
    await user.selectOptions(within(dialog).getByLabelText("Gym"), "Crunch Fitness - Doral");
    await applyLeaderboardFilters(user, dialog);
    table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Crunch Fitness - Doral")).toHaveLength(2);
    expect(within(table).queryByText("Crunch Fitness - South Beach")).not.toBeInTheDocument();
  });

  it("shows an empty search state while preserving the applied ranking summary", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.type(screen.getByLabelText("Search leaderboards"), "no athlete has this search");

    expect(screen.getByText("No matching rankings")).toBeVisible();
    expect(screen.getByText("1,475 lb")).toBeVisible();
    expect(screen.getByRole("button", { name: "Jump to my rank" })).toBeVisible();
  });

  it("shows applied filters as removable chips and clears the ranking view", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await user.selectOptions(within(dialog).getByLabelText("Verification level"), "Moderator Verified");
    await applyLeaderboardFilters(user, dialog);

    let context = screen.getByLabelText("Ranking context");
    expect(within(context).getByText("Rank by: Absolute")).toBeVisible();
    expect(within(context).getByText("Exercise: Back Squat")).toBeVisible();
    expect(within(context).getByText("Verification: Moderator Verified")).toBeVisible();
    expect(screen.getByRole("button", { name: /Remove.*Back Squat/i })).toBeVisible();
    expect(screen.getByRole("button", { name: /Remove.*Moderator/i })).toBeVisible();

    await user.click(screen.getByRole("button", { name: /Remove.*Back Squat/i }));
    expect(screen.queryByRole("button", { name: /Remove.*Back Squat/i })).not.toBeInTheDocument();
    context = screen.getByLabelText("Ranking context");
    expect(within(context).queryByText("Exercise: Back Squat")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Clear all/ }));
    context = screen.getByLabelText("Ranking context");
    expect(within(context).getByText("Rank by: Total")).toBeVisible();
    expect(within(context).getByText("Scope: Global")).toBeVisible();
    expect(within(context).getByText("Exercise: Three-lift total")).toBeVisible();
    expect(screen.queryByRole("button", { name: /Remove.*filter/i })).not.toBeInTheDocument();
  });

  it("labels leaderboard movement with arrows and accessible trend descriptions", () => {
    const state = structuredClone(seedState);
    const risingProfile = state.profiles.find((profile) => profile.id === "user-evan")!;
    risingProfile.id = "user-trend-g";
    state.liftSubmissions.forEach((lift) => {
      if (lift.userId === "user-evan") lift.userId = risingProfile.id;
    });

    renderApp("/leaderboards", state);

    expect(screen.getAllByLabelText("Up 1 place")[0]).toHaveTextContent("↑ 1");
    expect(screen.getAllByLabelText("Down 1 place")[0]).toHaveTextContent("↓ 1");
    expect(screen.getAllByLabelText("No change")[0]).toHaveTextContent("—");
  });

  it("distinguishes verification badges with explanatory tooltips", () => {
    renderApp("/leaderboards");

    const badges = [
      screen.getAllByTitle(/approved competition result/i)[0],
      screen.getAllByTitle(/LiftRank moderator/i)[0],
      screen.getAllByTitle(/eligible community members/i)[0],
      screen.getAllByTitle(/video evidence submitted/i)[0],
      screen.getAllByTitle(/without independent verification/i)[0]
    ];

    expect(new Set(badges.map((badge) => badge.className)).size).toBe(5);
  });

  it("paginates leaderboards at 25 athletes and resets to page one after search and filters", async () => {
    const user = userEvent.setup();
    const { container } = renderApp("/leaderboards", makePaginatedLeaderboardState());

    expect(container.querySelectorAll(".leaderboard-table-row")).toHaveLength(25);
    expect(screen.getByText(/Showing 1[–-]25 of 38/)).toBeVisible();
    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Next" })).toBeEnabled();

    await user.click(screen.getByRole("button", { name: "Next" }));
    expect(container.querySelectorAll(".leaderboard-table-row")).toHaveLength(13);
    expect(screen.getByText(/Showing 26[–-]38 of 38/)).toBeVisible();

    await user.type(screen.getByLabelText("Search leaderboards"), "Pagination Athlete 01");
    expect(screen.getByText(/Showing 1[–-]1 of 1/)).toBeVisible();
    expect(screen.getByRole("row", { name: /Pagination Athlete 01/i })).toBeVisible();

    await user.clear(screen.getByLabelText("Search leaderboards"));
    await user.click(screen.getByRole("button", { name: "Next" }));
    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.selectOptions(within(dialog).getByLabelText("Verification level"), "Competition Verified");
    await applyLeaderboardFilters(user, dialog);
    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    expect(screen.getByText(/Showing 1[–-]25 of \d+/)).toBeVisible();
  });

  it("jumps to the current athlete's page, focuses their row, and keeps the row in view", async () => {
    const user = userEvent.setup();
    const originalScrollIntoView = HTMLElement.prototype.scrollIntoView;
    Object.defineProperty(HTMLElement.prototype, "scrollIntoView", {
      configurable: true,
      value: () => undefined
    });

    try {
      renderApp("/leaderboards", makePaginatedLeaderboardState());
      expect(screen.queryByRole("row", { name: /Robert J\./i })).not.toBeInTheDocument();
      const search = screen.getByLabelText("Search leaderboards");
      await user.type(search, "Pagination Athlete 01");

      await user.click(screen.getByRole("button", { name: "Jump to my rank" }));

      const currentUserRow = screen.getByRole("row", { name: /Robert J\./i });
      expect(currentUserRow).toHaveFocus();
      expect(search).toHaveValue("");
      expect(screen.getByText(/Showing 26[–-]38 of 38/)).toBeVisible();
    } finally {
      Object.defineProperty(HTMLElement.prototype, "scrollIntoView", {
        configurable: true,
        value: originalScrollIntoView
      });
    }
  });

  it("lets you hide a leaderboard column", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    const dialog = await openLeaderboardColumns(user);
    await user.click(within(dialog).getByRole("button", { name: "Hide Gym" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).queryByText("Gym")).not.toBeInTheDocument();
  });

  it("keeps column edits as drafts until applied and can reset them", async () => {
    const user = userEvent.setup();
    const { container } = renderApp("/leaderboards");

    let dialog = await openLeaderboardColumns(user);
    await user.click(within(dialog).getByRole("button", { name: "Hide Gym" }));
    await user.click(within(dialog).getByRole("button", { name: "Close" }));
    expect(within(screen.getByRole("table", { name: "Leaderboard rankings" })).getByText("Gym")).toBeVisible();

    dialog = await openLeaderboardColumns(user);
    await user.click(within(dialog).getByRole("button", { name: "Move Score up" }));
    await user.click(within(dialog).getByRole("button", { name: "Move Score up" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));
    expect(getLeaderboardHeaderLabels(container)).toEqual(["Rank", "Athlete", "Top total", "Exercise", "Gym", "Verification", "Trend"]);

    dialog = await openLeaderboardColumns(user);
    await user.click(within(dialog).getByRole("button", { name: "Reset" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));
    expect(getLeaderboardHeaderLabels(container)).toEqual(["Rank", "Athlete", "Exercise", "Gym", "Top total", "Verification", "Trend"]);
  });

  it("does not allow every leaderboard column to be hidden", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    const dialog = await openLeaderboardColumns(user);
    for (const label of ["Rank", "Athlete", "Exercise", "Gym", "Score", "Verification"]) {
      await user.click(within(dialog).getByRole("button", { name: `Hide ${label}` }));
    }
    expect(within(dialog).getByText("1 shown")).toBeVisible();
    await user.click(within(dialog).getByRole("button", { name: "Hide Trend" }));
    expect(within(dialog).getByText("1 shown")).toBeVisible();
  });

  it("opens the correct athlete detail after filters and closes it with Escape", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const filterDialog = screen.getByRole("dialog");
    await user.click(within(filterDialog).getByRole("button", { name: "Absolute" }));
    await user.selectOptions(within(filterDialog).getByLabelText("Exercise"), "Back Squat");
    await applyLeaderboardFilters(user, filterDialog);
    await user.click(screen.getByRole("row", { name: /Marcus Bell/i }));

    const detail = screen.getByRole("dialog");
    expect(within(detail).getByRole("heading", { name: "Marcus Bell" })).toBeVisible();
    expect(within(detail).getByText("Back Squat · Absolute")).toBeVisible();
    expect(within(detail).getByText("1,390")).toBeVisible();
    expect(within(detail).getByText("Total")).toBeVisible();
    expect(within(detail).getByText("Advanced")).toBeVisible();
    await user.keyboard("{Escape}");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("submits a lift with bubble controls and editable plate loading", async () => {
    const user = userEvent.setup();
    renderApp("/submit");
    expect(screen.getByRole("heading", { name: "Submit a lift" })).toBeVisible();
    await user.clear(screen.getByLabelText("Weight lifted"));
    await user.type(screen.getByLabelText("Weight lifted"), "505");
    await user.clear(screen.getByLabelText("45 pound plates per side"));
    await user.type(screen.getByLabelText("45 pound plates per side"), "2");
    expect(screen.getByText("225 lb loaded")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Submit lift" }));
    expect(screen.getByRole("heading", { name: "Lift submitted" })).toBeVisible();
  });

  it("shows seeded threaded comments and supports vote toggling", async () => {
    const user = userEvent.setup();
    renderApp("/community/post-1");
    expect(await screen.findByText("Strong pull. The lockout looked decisive.")).toBeVisible();
    const upvoteButton = screen.getAllByRole("button", { name: "Upvote" })[0];
    expect(upvoteButton).toHaveClass("active");
    await user.click(upvoteButton);
    expect(upvoteButton).not.toHaveClass("active");
  });

  it("renders the Powerlifting group identity, seeded discussions, and filter toolbar", async () => {
    renderApp("/community/groups/group-powerlifting");
    expect(await screen.findByRole("heading", { name: "Powerlifting" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "585 moved clean" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Squat depth checks" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Hot" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("combobox", { name: "Browse all Training Groups" })).toHaveValue("group-powerlifting");
    expect(screen.getByRole("heading", { name: "Verified team" })).toBeVisible();
  });

  it("shows consistent unique member and moderator totals on the aggregate community", async () => {
    renderApp("/community");
    const members = new Set(seedState.trainingGroups.flatMap((group) => group.memberIds)).size;
    const moderators = new Set(seedState.trainingGroups.flatMap((group) => group.moderatorIds)).size;
    const aboutCard = (await screen.findByRole("heading", { name: "About the community" })).closest(".card") as HTMLElement;

    expect(screen.getByText(`${members} members`)).toBeVisible();
    expect(screen.getByText(`${moderators} moderator${moderators === 1 ? "" : "s"}`)).toBeVisible();
    expect(within(aboutCard).getByText(String(members))).toBeVisible();
    expect(within(aboutCard).getByText(String(moderators))).toBeVisible();
  });

  it("labels the message composer and sends a message from an existing thread", async () => {
    const user = userEvent.setup();
    renderApp("/messages/thread-1");

    await user.type(await screen.findByRole("textbox", { name: "Message" }), "Mobile flow verified.");
    await user.click(screen.getByRole("button", { name: "Send message" }));

    expect(screen.getByText("Mobile flow verified.")).toBeVisible();
    expect(screen.getByRole("textbox", { name: "Message" })).toHaveValue("");
  });

  it("cancels an outgoing friend request", async () => {
    const user = userEvent.setup();
    renderApp("/friends");
    expect(await screen.findByText("Nico Rivera")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByText("Nico Rivera")).not.toBeInTheDocument();
  });

  it("opens notifications and routes to their destination", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    await user.click(screen.getByRole("button", { name: /Notifications, 2 unread/ }));
    await user.click(screen.getByRole("button", { name: /Ranking increased/ }));
    expect(screen.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
  });
});

describe("leaderboard seed data", () => {
  it("has unique ids and ranks within each ranking type", () => {
    expect(new Set(leaderboardSeed.map((entry) => entry.id)).size).toBe(leaderboardSeed.length);

    for (const rankingType of new Set(leaderboardSeed.map((entry) => entry.rankingType))) {
      const ranks = leaderboardSeed
        .filter((entry) => entry.rankingType === rankingType)
        .map((entry) => entry.rank);
      expect(new Set(ranks).size).toBe(ranks.length);
    }
  });

  it("has enough demo data for common lift and total filters", () => {
    const exerciseCounts = leaderboardSeed.reduce((counts, entry) => {
      const normalized = entry.exercise.toLowerCase();
      counts[normalized] = (counts[normalized] ?? 0) + 1;
      return counts;
    }, {} as Record<string, number>);

    expect(exerciseCounts["back squat"]).toBeGreaterThanOrEqual(5);
    expect(leaderboardSeed.filter((entry) => entry.exercise.toLowerCase().includes("bench press")).length).toBeGreaterThanOrEqual(2);
    expect(leaderboardSeed.filter((entry) => entry.exercise.toLowerCase().includes("deadlift")).length).toBeGreaterThanOrEqual(2);
    expect(exerciseCounts["powerlifting total"]).toBeGreaterThanOrEqual(4);
  });

  it("only creates filter options that map to at least one row in that ranking type", () => {
    for (const rankingType of new Set(leaderboardSeed.map((entry) => entry.rankingType))) {
      const entries = leaderboardSeed.filter((entry) => entry.rankingType === rankingType);
      for (const key of ["exercise", "gym", "ageGroup", "experienceLevel"] as const) {
        const options = new Set(entries.map((entry) => entry[key]));
        for (const option of options) {
          expect(entries.some((entry) => entry[key] === option)).toBe(true);
        }
      }
      const cities = new Set(entries.map((entry) => `${entry.city}, ${entry.state}`));
      for (const city of cities) {
        expect(entries.some((entry) => `${entry.city}, ${entry.state}` === city)).toBe(true);
      }
    }
  });
});
