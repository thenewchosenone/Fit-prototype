import { describe, expect, it } from "vitest";
import { achievementCatalog, deriveAchievements } from "../src/achievements";
import { seedState } from "../src/data";

describe("activity-derived achievements", () => {
  it("ships stable unique identifiers across the complete website catalog", () => {
    expect(achievementCatalog.length).toBeGreaterThanOrEqual(20);
    expect(new Set(achievementCatalog.map((item) => item.id)).size).toBe(achievementCatalog.length);
    expect(achievementCatalog.map((item) => item.id)).toEqual(expect.arrayContaining([
      "first-workout", "first-lift", "first-verified-lift", "bench-bodyweight", "squat-1-5-bodyweight",
      "deadlift-2-bodyweight", "community-first-post", "profile-complete", "global-top-10", "gym-top-10"
    ]));
  });

  it("derives unlocks and dates from eligible records instead of presentation flags", () => {
    const state = structuredClone(seedState);
    state.completedWorkouts = [];
    let achievements = deriveAchievements(state, state.currentUserId);
    expect(achievements.find((item) => item.id === "first-workout")).toMatchObject({ unlocked: false, current: 0, unlockedAt: null });

    const completedAt = "2026-07-15T12:00:00.000Z";
    const prescription = state.prescriptions[0];
    const setLog = { id: "achievement-set", prescriptionId: prescription.id, setNumber: 1, weight: 225, reps: 5, rpe: 8, isWarmup: false, isComplete: true, performedAt: completedAt };
    state.completedWorkouts = [{ id: "achievement-workout", sessionId: prescription.sessionId, planId: state.activePlanId, weekId: state.sessions.find((session) => session.id === prescription.sessionId)!.weekId, name: "Achievement workout", completedAt, durationSeconds: 1800, completedExercises: 1, totalExercises: 1, totalSets: 1, totalVolume: 1125, bestSet: setLog, setLogs: [setLog], prescriptions: [prescription] }];
    achievements = deriveAchievements(state, state.currentUserId);
    expect(achievements.find((item) => item.id === "first-workout")).toMatchObject({ unlocked: true, current: 1, unlockedAt: completedAt });
  });
});
