import { computedLeaderboardEntries } from "./platform";
import type { LiftSubmission, TrackerState, UserProfile } from "./types";

export interface AchievementProgress {
  id: string;
  title: string;
  description: string;
  current: number;
  target: number;
  unit: string;
  unlocked: boolean;
  unlockedAt: string | null;
}

type AchievementDefinition = Omit<AchievementProgress, "current" | "unlocked" | "unlockedAt"> & {
  evaluate: (context: AchievementContext) => { current: number; unlockedAt: string | null };
};

interface AchievementContext {
  state: TrackerState;
  profile: UserProfile;
  lifts: LiftSubmission[];
  verifiedLifts: LiftSubmission[];
  best: Record<string, number>;
  posts: TrackerState["communityPosts"];
  workoutDates: string[];
  globalRank: number | null;
  gymRank: number | null;
}

const firstDate = (values: Array<string | undefined>) => values.filter((value): value is string => Boolean(value)).sort()[0] ?? null;
const thresholdDate = (lifts: LiftSubmission[], exerciseId: string, target: number) => firstDate(lifts.filter((lift) => lift.exerciseId === exerciseId && lift.normalizedWeight >= target).map((lift) => lift.performedAt));

const countDefinition = (id: string, title: string, description: string, target: number, select: (context: AchievementContext) => string[]): AchievementDefinition => ({
  id, title, description, target, unit: target === 1 ? "activity" : "activities",
  evaluate: (context) => {
    const dates = select(context).sort();
    return { current: dates.length, unlockedAt: dates[target - 1] ?? null };
  }
});

const liftMilestone = (id: string, title: string, exerciseId: string, target: number): AchievementDefinition => ({
  id, title, description: `Record a ${target} lb ${title.toLowerCase()}.`, target, unit: "lb",
  evaluate: (context) => ({ current: context.best[exerciseId] ?? 0, unlockedAt: thresholdDate(context.lifts, exerciseId, target) })
});

export const achievementCatalog: AchievementDefinition[] = [
  countDefinition("first-workout", "First workout", "Complete your first tracked workout.", 1, (context) => context.workoutDates),
  countDefinition("workout-5", "Five workouts", "Complete five tracked workouts.", 5, (context) => context.workoutDates),
  countDefinition("workout-25", "Twenty-five workouts", "Complete twenty-five tracked workouts.", 25, (context) => context.workoutDates),
  countDefinition("first-lift", "First lift", "Submit your first lift result.", 1, (context) => context.lifts.map((lift) => lift.submittedAt)),
  countDefinition("first-verified-lift", "First verified lift", "Record a reviewed or competition result.", 1, (context) => context.verifiedLifts.map((lift) => lift.submittedAt)),
  liftMilestone("bench-135", "Bench press", "barbell-bench", 135),
  liftMilestone("bench-225", "Two-plate bench", "barbell-bench", 225),
  liftMilestone("bench-315", "Three-plate bench", "barbell-bench", 315),
  liftMilestone("squat-225", "Two-plate squat", "back-squat", 225),
  liftMilestone("squat-315", "Three-plate squat", "back-squat", 315),
  liftMilestone("squat-405", "Four-plate squat", "back-squat", 405),
  liftMilestone("deadlift-315", "Three-plate deadlift", "deadlift", 315),
  liftMilestone("deadlift-405", "Four-plate deadlift", "deadlift", 405),
  liftMilestone("deadlift-500", "500 lb deadlift", "deadlift", 500),
  { id: "bench-bodyweight", title: "Bodyweight bench", description: "Bench at least your recorded bodyweight.", target: 1, unit: "× bodyweight", evaluate: (context) => { const qualifying = context.lifts.filter((lift) => lift.exerciseId === "barbell-bench" && lift.normalizedWeight >= lift.bodyweight); return { current: Math.max(0, ...context.lifts.filter((lift) => lift.exerciseId === "barbell-bench").map((lift) => lift.normalizedWeight / lift.bodyweight)), unlockedAt: firstDate(qualifying.map((lift) => lift.performedAt)) }; } },
  { id: "squat-1-5-bodyweight", title: "1.5× bodyweight squat", description: "Squat at least one and a half times bodyweight.", target: 1.5, unit: "× bodyweight", evaluate: (context) => { const ratios = context.lifts.filter((lift) => lift.exerciseId === "back-squat").map((lift) => ({ ratio: lift.normalizedWeight / lift.bodyweight, date: lift.performedAt })); return { current: Math.max(0, ...ratios.map((item) => item.ratio)), unlockedAt: firstDate(ratios.filter((item) => item.ratio >= 1.5).map((item) => item.date)) }; } },
  { id: "deadlift-2-bodyweight", title: "2× bodyweight deadlift", description: "Deadlift at least twice bodyweight.", target: 2, unit: "× bodyweight", evaluate: (context) => { const ratios = context.lifts.filter((lift) => lift.exerciseId === "deadlift").map((lift) => ({ ratio: lift.normalizedWeight / lift.bodyweight, date: lift.performedAt })); return { current: Math.max(0, ...ratios.map((item) => item.ratio)), unlockedAt: firstDate(ratios.filter((item) => item.ratio >= 2).map((item) => item.date)) }; } },
  countDefinition("community-first-post", "Community contributor", "Publish a Training Group discussion.", 1, (context) => context.posts.map((post) => post.createdAt)),
  { id: "profile-complete", title: "Complete profile", description: "Add your goal, discipline, experience, gym, bodyweight, and bio.", target: 6, unit: "fields", evaluate: (context) => { const fields = [context.profile.trainingGoal, context.profile.discipline, context.profile.experienceLevel, context.profile.primaryGymId, context.profile.bodyweight > 0 ? "bodyweight" : "", context.profile.bio]; const current = fields.filter(Boolean).length; return { current, unlockedAt: current === 6 ? firstDate([...context.lifts.map((lift) => lift.submittedAt), ...context.posts.map((post) => post.createdAt)]) : null }; } },
  { id: "global-top-10", title: "Global top 10", description: "Reach the top ten of the demo global total ranking.", target: 10, unit: "rank", evaluate: (context) => ({ current: context.globalRank ?? 999, unlockedAt: context.globalRank && context.globalRank <= 10 ? firstDate(context.lifts.map((lift) => lift.submittedAt)) : null }) },
  { id: "gym-top-10", title: "Gym top 10", description: "Reach the top ten of your demo gym total ranking.", target: 10, unit: "rank", evaluate: (context) => ({ current: context.gymRank ?? 999, unlockedAt: context.gymRank && context.gymRank <= 10 ? firstDate(context.lifts.map((lift) => lift.submittedAt)) : null }) }
];

const totalFilters = (scope: "Global" | "Selected gym", gym = "All") => ({ rankingType: "Total" as const, scope, verification: "All" as const, exercise: "All", gym, city: "All", ageGroup: "All", experienceLevel: "All", weightClass: "All", repCount: null });

export function deriveAchievements(state: TrackerState, profileId: string): AchievementProgress[] {
  const profile = state.profiles.find((item) => item.id === profileId);
  if (!profile) return [];
  const lifts = state.liftSubmissions.filter((lift) => lift.userId === profileId);
  const verifiedLifts = lifts.filter((lift) => !["Self Reported", "Video Submitted"].includes(lift.verification));
  const best = lifts.reduce<Record<string, number>>((result, lift) => ({ ...result, [lift.exerciseId]: Math.max(result[lift.exerciseId] ?? 0, lift.normalizedWeight) }), {});
  const posts = state.communityPosts.filter((post) => post.authorId === profileId && post.kind !== "Workout");
  const globalRank = computedLeaderboardEntries(state, totalFilters("Global")).find((entry) => entry.userId === profileId)?.rank ?? null;
  const gymName = state.gyms.find((gym) => gym.id === profile.primaryGymId)?.name ?? "All";
  const gymRank = computedLeaderboardEntries(state, totalFilters("Selected gym", gymName)).find((entry) => entry.userId === profileId)?.rank ?? null;
  const context: AchievementContext = { state, profile, lifts, verifiedLifts, best, posts, workoutDates: profileId === state.currentUserId ? state.completedWorkouts.map((workout) => workout.completedAt) : [], globalRank, gymRank };
  return achievementCatalog.map((definition) => {
    const result = definition.evaluate(context);
    const unlocked = definition.unit === "rank" ? result.current <= definition.target : result.current >= definition.target;
    return { id: definition.id, title: definition.title, description: definition.description, target: definition.target, unit: definition.unit, current: result.current, unlocked, unlockedAt: unlocked ? result.unlockedAt : null };
  });
}
