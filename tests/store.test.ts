import { describe, expect, it } from "vitest";
import { seedState } from "../src/data";
import { estimatedOneRepMax, personalRecords, recommendedNextWeight } from "../src/lib";
import { computedLeaderboardEntries, plateLoadTotal, weightClassFor } from "../src/platform";
import { loadTrackerState, STORAGE_KEY, trackerReducer } from "../src/store";
import type { TrackerState } from "../src/types";

const fresh = () => structuredClone(seedState);

describe("tracker reducer", () => {
  it("creates and deletes a complete plan graph", () => {
    const created = trackerReducer(fresh(), { type: "CREATE_PLAN", name: "Hypertrophy", goal: "Grow" });
    expect(created.plans).toHaveLength(2);
    expect(created.weeks.some((week) => week.planId === created.activePlanId)).toBe(true);
    const deleted = trackerReducer(created, { type: "DELETE_PLAN", planId: created.activePlanId });
    expect(deleted.plans).toHaveLength(1);
    expect(deleted.weeks.some((week) => week.planId === created.activePlanId)).toBe(false);
  });

  it("clones week sessions and prescriptions without set logs", () => {
    const source = fresh();
    const cloned = trackerReducer(source, { type: "CLONE_WEEK", weekId: "week-1" });
    const newWeek = cloned.weeks.find((week) => week.weekNumber === 3);
    expect(newWeek).toBeTruthy();
    const newSessions = cloned.sessions.filter((session) => session.weekId === newWeek?.id);
    expect(newSessions).toHaveLength(3);
    expect(cloned.prescriptions.filter((rx) => newSessions.some((session) => session.id === rx.sessionId))).toHaveLength(6);
    expect(cloned.setLogs).toHaveLength(0);
  });

  it("cancels a freestyle workout and removes its temporary session", () => {
    let state = trackerReducer(fresh(), {
      type: "ADD_SESSION",
      weekId: "week-1",
      day: "Saturday",
      name: "Freestyle Workout",
      freestyle: true
    });
    const session = state.sessions.at(-1)!;
    state = trackerReducer(state, { type: "START_WORKOUT", sessionId: session.id });
    const cancelled = trackerReducer(state, { type: "CANCEL_WORKOUT", sessionId: session.id });
    expect(cancelled.activeWorkout).toBeNull();
    expect(cancelled.sessions.some((item) => item.id === session.id)).toBe(false);
  });

  it("finishes a workout using completed sets only", () => {
    let state = fresh();
    state = trackerReducer(state, { type: "START_WORKOUT", sessionId: "session-push" });
    state = trackerReducer(state, { type: "ENSURE_SET_LOGS", prescriptionId: "p-bench", count: 3 });
    const [first, second] = state.setLogs;
    state = trackerReducer(state, { type: "UPDATE_SET", logId: first.id, field: "weight", value: 225 });
    state = trackerReducer(state, { type: "UPDATE_SET", logId: first.id, field: "reps", value: 5 });
    state = trackerReducer(state, { type: "TOGGLE_SET", logId: first.id });
    state = trackerReducer(state, { type: "UPDATE_SET", logId: second.id, field: "weight", value: 205 });
    state = trackerReducer(state, { type: "UPDATE_SET", logId: second.id, field: "reps", value: 5 });
    const finished = trackerReducer(state, { type: "FINISH_WORKOUT", sessionId: "session-push" });
    expect(finished.completedWorkouts[0].totalSets).toBe(1);
    expect(finished.completedWorkouts[0].totalVolume).toBe(1125);
    expect(finished.completedWorkouts[0].bestSet?.weight).toBe(225);
  });
});

describe("progress calculations", () => {
  it("calculates estimated one rep max", () => {
    expect(estimatedOneRepMax(225, 5)).toBe(263);
  });

  it("returns PRs and increases next weight after all targets are hit", () => {
    const state = fresh();
    const prescription = state.prescriptions.find((item) => item.id === "p-bench")!;
    const completedAt = "2026-06-20T12:00:00.000Z";
    const setLogs = [1, 2, 3].map((setNumber) => ({
      id: `history-${setNumber}`,
      prescriptionId: prescription.id,
      setNumber,
      weight: 200,
      reps: 8,
      rpe: 8,
      isWarmup: false,
      isComplete: true,
      performedAt: completedAt
    }));
    state.completedWorkouts = [{
      id: "completed-1",
      sessionId: "session-push",
      planId: "plan-strength",
      weekId: "week-1",
      name: "Push",
      completedAt,
      durationSeconds: 3600,
      completedExercises: 1,
      totalExercises: 1,
      totalSets: 3,
      totalVolume: 4800,
      bestSet: setLogs[0],
      setLogs,
      prescriptions: [prescription]
    }];
    expect(personalRecords(state, "barbell-bench").best5?.weight).toBe(200);
    expect(recommendedNextWeight(state, prescription)).toBe(205);
  });

  it("repeats the previous weight after target reps are missed", () => {
    const state = fresh();
    const prescription = state.prescriptions.find((item) => item.id === "p-bench")!;
    const completedAt = "2026-06-20T12:00:00.000Z";
    const setLog = {
      id: "missed-set",
      prescriptionId: prescription.id,
      setNumber: 1,
      weight: 225,
      reps: 4,
      rpe: 9,
      isWarmup: false,
      isComplete: true,
      performedAt: completedAt
    };
    state.completedWorkouts = [{
      id: "missed-workout",
      sessionId: "session-push",
      planId: "plan-strength",
      weekId: "week-1",
      name: "Push",
      completedAt,
      durationSeconds: 3000,
      completedExercises: 1,
      totalExercises: 1,
      totalSets: 1,
      totalVolume: 900,
      bestSet: setLog,
      setLogs: [setLog],
      prescriptions: [prescription]
    }];
    expect(recommendedNextWeight(state, prescription)).toBe(225);
  });
});

describe("persistence", () => {
  it("recovers from invalid or old browser data", () => {
    const invalidStorage = { getItem: () => "{bad" } as Pick<Storage, "getItem">;
    expect(loadTrackerState(invalidStorage).version).toBe(3);
    const oldStorage = {
      getItem: (key: string) => key === STORAGE_KEY ? JSON.stringify({ version: 1 }) : null
    } as Pick<Storage, "getItem">;
    expect(loadTrackerState(oldStorage).plans[0].name).toBe("Strength Foundation");
  });

  it("migrates version 2 tracker data without losing workouts", () => {
    const version2 = { ...fresh(), version: 2, completedWorkouts: [{ ...fresh().completedWorkouts[0] }].filter(Boolean) };
    const storage = { getItem: () => JSON.stringify(version2) } as Pick<Storage, "getItem">;
    const migrated = loadTrackerState(storage);
    expect(migrated.version).toBe(3);
    expect(migrated.profiles.length).toBeGreaterThan(1);
    expect(migrated.plans[0].name).toBe("Strength Foundation");
  });
});

describe("platform features", () => {
  it("submits lifts only for joined gyms and delays leaderboard eligibility", () => {
    const state = fresh();
    const baseLift = {
      userId: state.currentUserId,
      exerciseId: "deadlift",
      exerciseName: "Conventional Deadlift",
      weight: 505,
      unit: "lb" as const,
      normalizedWeight: 505,
      reps: 1,
      bodyweight: 210,
      performedAt: new Date().toISOString(),
      gymId: "gym-south-beach",
      equipment: "Raw" as const,
      visibility: "Public" as const,
      verification: "Video Submitted" as const,
      caption: "New pull"
    };
    const submitted = trackerReducer(state, { type: "SUBMIT_LIFT", lift: baseLift });
    expect(submitted.liftSubmissions).toHaveLength(state.liftSubmissions.length + 1);
    expect(new Date(submitted.liftSubmissions[0].leaderboardEligibleAt).getTime()).toBeGreaterThan(Date.now());
    const rejected = trackerReducer(state, { type: "SUBMIT_LIFT", lift: { ...baseLift, gymId: "gym-doral" } });
    expect(rejected.liftSubmissions).toHaveLength(state.liftSubmissions.length);
  });

  it("enforces the three-gym limit and protects the primary gym", () => {
    let state = fresh();
    state = trackerReducer(state, { type: "JOIN_GYM", gymId: "gym-doral" });
    state = trackerReducer(state, { type: "JOIN_GYM", gymId: "gym-brandon" });
    state = trackerReducer(state, { type: "JOIN_GYM", gymId: "gym-winter-park" });
    expect(state.joinedGymIds).toHaveLength(3);
    const afterPrimaryLeave = trackerReducer(state, { type: "LEAVE_GYM", gymId: "gym-south-beach" });
    expect(afterPrimaryLeave.joinedGymIds).toContain("gym-south-beach");
  });

  it("supports community reactions, comments, friend cancellation, and message reports", () => {
    let state = fresh();
    state = trackerReducer(state, { type: "TOGGLE_POST_LIKE", postId: "post-2" });
    expect(state.communityPosts.find((post) => post.id === "post-2")?.likedBy).toContain(state.currentUserId);
    state = trackerReducer(state, { type: "ADD_COMMENT", comment: { postId: "post-2", body: "Useful angle." } });
    expect(state.comments.at(-1)?.body).toBe("Useful angle.");
    state = trackerReducer(state, { type: "CANCEL_FRIEND_REQUEST", requestId: "friend-2" });
    expect(state.friendRequests.some((request) => request.id === "friend-2")).toBe(false);
    state = trackerReducer(state, { type: "REPORT_MESSAGE", messageId: "message-1", reason: "Spam", note: "test" });
    expect(state.messages.find((message) => message.id === "message-1")?.isReported).toBe(true);
  });

  it("builds calculated totals and official weight classes", () => {
    const state = fresh();
    const entries = computedLeaderboardEntries(state, { rankingType: "Total", scope: "Global", verification: "All", exercise: "All", gym: "All", city: "All", ageGroup: "All", experienceLevel: "All", weightClass: "All", repCount: null });
    expect(entries[0].athlete).toBe("Evan Cole");
    expect(entries[0].total).toBe(1475);
    expect(weightClassFor(210, "Male")).toBe("100 kg");
    expect(weightClassFor(225, "Female")).toBe("100+ kg");
  });

  it("ships a broad unique catalog and editable plate loading", () => {
    const state = fresh();
    expect(state.exercises.length).toBeGreaterThanOrEqual(199);
    expect(new Set(state.exercises.map((exercise) => exercise.id)).size).toBe(state.exercises.length);
    expect(state.exercises.some((exercise) => exercise.searchAliases?.includes("Hammer Strength D.Y. Row"))).toBe(true);
    expect(plateLoadTotal(45, [{ weight: 45, count: 2 }, { weight: 25, count: 1 }])).toBe(275);
  });
});
