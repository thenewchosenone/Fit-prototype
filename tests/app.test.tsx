import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HashRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import App from "../src/App";
import { leaderboardSeed, seedState } from "../src/data";
import { TrackerProvider } from "../src/store";
import type { RankingType, TrackerState } from "../src/types";

function renderApp(path = "/library", initialState: TrackerState = structuredClone(seedState)) {
  window.location.hash = `#${path}`;
  return render(
    <HashRouter>
      <TrackerProvider initialState={initialState}>
        <App />
      </TrackerProvider>
    </HashRouter>
  );
}

async function applyLeaderboardRankingType(user: ReturnType<typeof userEvent.setup>, rankingType: RankingType) {
  await user.click(screen.getByRole("button", { name: /Filters/ }));
  const dialog = screen.getByRole("dialog");
  await user.click(within(dialog).getByRole("button", { name: rankingType }));
  await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));
}

function getLeaderboardHeaderLabels(container: HTMLElement) {
  return Array.from(container.querySelectorAll(".leaderboard-table-header .leaderboard-cell.header"))
    .map((header) => header.textContent?.trim());
}

describe("LiftRank tracker UI", () => {
  it("filters the exercise library by search and equipment", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.type(screen.getByLabelText("Search exercises"), "bench");
    expect(screen.getByText("Barbell Bench Press")).toBeVisible();
    expect(screen.queryByText("Back Squat")).not.toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText("Equipment"), "Dumbbells");
    expect(screen.getByText("Dumbbell Bench Press")).toBeVisible();
    expect(screen.queryByText("Barbell Bench Press")).not.toBeInTheDocument();
  });

  it("creates a custom exercise separately from workout programming", async () => {
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

  it("shows the current lifter profile and opens it from the profile pill", async () => {
    const user = userEvent.setup();
    renderApp("/today");

    await user.click(screen.getByRole("link", { name: "Open profile" }));

    expect(screen.getByRole("heading", { name: "Robert J." })).toBeVisible();
    expect(screen.getByText("@rjrob23 · 30-34 · Advanced")).toBeVisible();
    expect(screen.getByText("Strength snapshot")).toBeVisible();
    expect(screen.getByRole("heading", { name: "About" })).toBeVisible();
    expect(screen.getByRole("link", { name: /Edit profile/ })).toHaveAttribute("href", "#/settings");
  });

  it("opens the leaderboard route and athlete detail sheet", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    expect(screen.getByRole("heading", { name: "Leaderboards" })).toBeVisible();
    await user.click(screen.getByRole("button", { name: /Evan Cole/i }));
    const dialog = screen.getByRole("dialog");
    expect(dialog).toBeVisible();
    expect(within(dialog).getByText("Current rank")).toBeVisible();
    expect(within(dialog).getAllByText("1,475")).not.toHaveLength(0);
    expect(within(dialog).getByText("Total")).toBeVisible();
  });

  it("uses total as the default main leaderboard", () => {
    const { container } = renderApp("/leaderboards");
    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    const rankLabels = Array.from(container.querySelectorAll(".leaderboard-rank-cell strong"))
      .map((rank) => rank.textContent);

    expect(within(table).getByText("Top total")).toBeVisible();
    expect(within(table).getByText("1,475 lb")).toBeVisible();
    expect(within(table).getByText("1,475 total")).toBeVisible();
    expect(screen.getByText("0 active filters")).toBeVisible();
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
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));

    expect(screen.getAllByText(/PR growth/).length).toBeGreaterThan(0);
  });

  it("has enough back squat leaderboard rows to test exercise filters", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Back Squat").length).toBeGreaterThanOrEqual(5);
  });

  it("keeps leaderboard filter options scoped and keeps All first", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    const exercise = within(dialog).getByLabelText("Exercise") as HTMLSelectElement;
    const experience = within(dialog).getByLabelText("Experience") as HTMLSelectElement;
    const exerciseOptions = Array.from(exercise.options).map((option) => option.value);
    const experienceOptions = Array.from(experience.options).map((option) => option.value);

    expect(exerciseOptions[0]).toBe("All");
    expect(exerciseOptions).toContain("Back Squat");
    expect(exerciseOptions).not.toContain("Relative Total");
    expect(experienceOptions[0]).toBe("All");
  });

  it("resets dependent filters when the ranking type or scope changes", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    let dialog = screen.getByRole("dialog");
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    expect(within(dialog).getByLabelText("Exercise")).toHaveValue("All");
    expect(Array.from((within(dialog).getByLabelText("Exercise") as HTMLSelectElement).options).map((option) => option.value)).toContain("Back Squat");
    await user.selectOptions(within(dialog).getByLabelText("Exercise"), "Back Squat");
    await user.click(within(dialog).getByRole("button", { name: "My gym" }));
    expect(within(dialog).getByLabelText("Exercise")).toHaveValue("All");
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    expect(within(dialog).getByLabelText("Exercise")).toHaveValue("All");
  });

  it("searches the leaderboard across athlete, handle, gym, city, state, and exercise", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");
    const search = screen.getByLabelText("Search leaderboards");

    await user.type(search, "  @evancole  ");
    expect(screen.getByRole("button", { name: /Evan Cole/i })).toBeVisible();
    expect(screen.queryByRole("button", { name: /Mia Santos/i })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Filters \(1\)/ })).toBeVisible();
    await user.clear(search);
    expect(screen.getByRole("button", { name: "Filters" })).toBeVisible();

    await user.type(search, "winter park");
    expect(screen.getByRole("button", { name: /Sofia Martin/i })).toBeVisible();
    expect(screen.queryByRole("button", { name: /Evan Cole/i })).not.toBeInTheDocument();
  });

  it("applies my gym and my city leaderboard scopes", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    let dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Absolute" }));
    await user.click(within(dialog).getByRole("button", { name: "My gym" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));
    let table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Crunch Fitness - South Beach")).toHaveLength(3);
    expect(within(table).queryByText("Crunch Fitness - Doral")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filters/ }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "My city" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));
    table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getAllByText("Miami Beach, Florida")).not.toHaveLength(0);
    expect(within(table).queryByText("Miami, Florida")).not.toBeInTheDocument();
  });

  it("shows an empty leaderboard state without falling back to an unrelated top score", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.type(screen.getByLabelText("Search leaderboards"), "no athlete has this search");

    expect(screen.getByText("No matching rankings")).toBeVisible();
    expect(screen.getByText("No result")).toBeVisible();
    expect(screen.getByText("No matching rankings for this view")).toBeVisible();
    expect(screen.queryByText("1,475 lb")).not.toBeInTheDocument();
  });

  it("shows total context when the leaderboard is ranked by total", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Filters" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Total" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply filters" }));

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).getByText("Top total")).toBeVisible();
    expect(within(table).getByText("1,475 total")).toBeVisible();
  });

  it("lets you hide a leaderboard column", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Columns" }));
    const dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Hide Gym" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));

    const table = screen.getByRole("table", { name: "Leaderboard rankings" });
    expect(within(table).queryByText("Gym")).not.toBeInTheDocument();
  });

  it("keeps column edits as drafts until applied and can reset them", async () => {
    const user = userEvent.setup();
    const { container } = renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Columns" }));
    let dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Hide Gym" }));
    await user.click(within(dialog).getByRole("button", { name: "Close" }));
    expect(within(screen.getByRole("table", { name: "Leaderboard rankings" })).getByText("Gym")).toBeVisible();

    await user.click(screen.getByRole("button", { name: "Columns" }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Move Score up" }));
    await user.click(within(dialog).getByRole("button", { name: "Move Score up" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));
    expect(getLeaderboardHeaderLabels(container)).toEqual(["Rank", "Athlete", "Top total", "Exercise", "Gym", "Verification", "Trend"]);

    await user.click(screen.getByRole("button", { name: "Columns" }));
    dialog = screen.getByRole("dialog");
    await user.click(within(dialog).getByRole("button", { name: "Reset" }));
    await user.click(within(dialog).getByRole("button", { name: "Apply changes" }));
    expect(getLeaderboardHeaderLabels(container)).toEqual(["Rank", "Athlete", "Exercise", "Gym", "Top total", "Verification", "Trend"]);
  });

  it("does not allow every leaderboard column to be hidden", async () => {
    const user = userEvent.setup();
    renderApp("/leaderboards");

    await user.click(screen.getByRole("button", { name: "Columns" }));
    const dialog = screen.getByRole("dialog");
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
    await user.click(within(filterDialog).getByRole("button", { name: "Apply filters" }));
    await user.click(screen.getByRole("button", { name: /Marcus Bell/i }));

    const detail = screen.getByRole("dialog");
    expect(within(detail).getByRole("heading", { name: "Marcus Bell" })).toBeVisible();
    expect(within(detail).getByText("Back Squat · Absolute")).toBeVisible();
    expect(within(detail).getByText("1,390")).toBeVisible();
    expect(within(detail).getByText("Total")).toBeVisible();
    expect(within(detail).getByText("Advanced")).toBeVisible();
    await user.keyboard("{Escape}");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("keeps weight and reps blank and requires both before completion", async () => {
    const user = userEvent.setup();
    renderApp("/today");
    await user.click(screen.getByRole("button", { name: "Start workout" }));
    const weight = (await screen.findAllByLabelText("Set 1 weight"))[0];
    const reps = screen.getAllByLabelText("Set 1 reps")[0];
    const complete = screen.getAllByRole("button", { name: "Complete set 1" })[0];
    expect(weight).toHaveValue(null);
    expect(reps).toHaveValue(null);
    expect(complete).toBeDisabled();
    await user.type(weight, "225");
    await user.type(reps, "5");
    expect(complete).toBeEnabled();
  });

  it("fills only the matching field from the last workout", async () => {
    const user = userEvent.setup();
    const state = structuredClone(seedState);
    const prescription = state.prescriptions.find((item) => item.id === "p-bench")!;
    const previousLog = {
      id: "previous-bench",
      prescriptionId: prescription.id,
      setNumber: 1,
      weight: 205,
      reps: 7,
      rpe: 8,
      isWarmup: false,
      isComplete: true,
      performedAt: "2026-06-20T12:00:00.000Z"
    };
    state.completedWorkouts = [{
      id: "previous-workout",
      sessionId: "session-push",
      planId: "plan-strength",
      weekId: "week-1",
      name: "Push",
      completedAt: "2026-06-20T12:00:00.000Z",
      durationSeconds: 2400,
      completedExercises: 1,
      totalExercises: 1,
      totalSets: 1,
      totalVolume: 1435,
      bestSet: previousLog,
      setLogs: [previousLog],
      prescriptions: [prescription]
    }];
    renderApp("/workout/session-push", state);
    const lastWeight = await screen.findByRole("button", { name: "Last: 205" });
    await user.click(lastWeight);
    expect(screen.getAllByLabelText("Set 1 weight")[0]).toHaveValue(205);
    expect(screen.getAllByLabelText("Set 1 reps")[0]).toHaveValue(null);
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

  it("shows seeded community comments and supports likes", async () => {
    const user = userEvent.setup();
    renderApp("/community/post-1");
    expect(screen.getByText("Strong pull. The lockout looked decisive.")).toBeVisible();
    const likeButton = screen.getByRole("button", { name: "Like post, 2 likes" });
    await user.click(likeButton);
    expect(screen.getByRole("button", { name: "Like post, 1 likes" })).toBeVisible();
  });

  it("cancels an outgoing friend request", async () => {
    const user = userEvent.setup();
    renderApp("/friends");
    expect(screen.getByText("Nico Rivera")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByText("Nico Rivera")).not.toBeInTheDocument();
  });

  it("opens notifications and routes to their destination", async () => {
    const user = userEvent.setup();
    renderApp("/today");
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
