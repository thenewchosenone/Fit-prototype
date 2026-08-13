import { describe, expect, it } from "vitest";
import { seedState } from "../src/data";
import gymCatalog from "../src/gymCatalog.json";
import { loadGymCatalog } from "../src/gymCatalog";
import { estimatedOneRepMax, personalRecords, recommendedNextWeight } from "../src/lib";
import { computedLeaderboardEntries, plateLoadTotal, weightClassFor } from "../src/platform";
import { workoutProgramTemplates } from "../src/programTemplates";
import { loadTrackerState, serializeTrackerState, STORAGE_KEY, trackerReducer } from "../src/store";
import type { TrackerState } from "../src/types";

const fresh = () => structuredClone(seedState);

describe("tracker reducer", () => {
  it("joins groups and toggles or switches one vote per user", () => {
    let state = fresh();
    state = trackerReducer(state, { type: "JOIN_GROUP", groupId: "group-calisthenics" });
    expect(state.joinedGroupIds).toContain("group-calisthenics");
    state = trackerReducer(state, { type: "VOTE_POST", postId: "post-2", vote: -1 });
    expect(state.communityPosts.find((post) => post.id === "post-2")?.votes["user-robert"]).toBe(-1);
    state = trackerReducer(state, { type: "VOTE_POST", postId: "post-2", vote: 1 });
    expect(state.communityPosts.find((post) => post.id === "post-2")?.votes["user-robert"]).toBe(1);
    state = trackerReducer(state, { type: "VOTE_POST", postId: "post-2", vote: 1 });
    expect(state.communityPosts.find((post) => post.id === "post-2")?.votes["user-robert"]).toBeUndefined();
  });

  it("supports nested replies and enforces locks and group bans", () => {
    let state = trackerReducer(fresh(), { type: "ADD_COMMENT", comment: { postId: "post-2", parentCommentId: "comment-2", body: "A nested reply" } });
    expect(state.comments.at(-1)?.parentCommentId).toBe("comment-2");
    state = trackerReducer(state, { type: "MODERATE_POST", postId: "post-2", operation: "lock" });
    const count = state.comments.length;
    state = trackerReducer(state, { type: "ADD_COMMENT", comment: { postId: "post-2", body: "Blocked" } });
    expect(state.comments).toHaveLength(count);
    state = trackerReducer(state, { type: "BAN_GROUP_USER", groupId: "group-powerlifting", userId: "user-mia", reason: "Test" });
    expect(state.groupBans).toHaveLength(1);
  });
  it("creates and deletes a complete plan graph", () => {
    const created = trackerReducer(fresh(), { type: "CREATE_PLAN", name: "Hypertrophy", goal: "Grow" });
    expect(created.plans).toHaveLength(2);
    expect(created.weeks.some((week) => week.planId === created.activePlanId)).toBe(true);
    const deleted = trackerReducer(created, { type: "DELETE_PLAN", planId: created.activePlanId });
    expect(deleted.plans).toHaveLength(1);
    expect(deleted.weeks.some((week) => week.planId === created.activePlanId)).toBe(false);
  });

  it("installs immutable 12-week program templates as editable plan copies", () => {
    const source = fresh();
    const templateSnapshot = structuredClone(workoutProgramTemplates[0]);
    const missingExerciseIds = workoutProgramTemplates.flatMap((template) =>
      template.sessions.flatMap((session) =>
        session.exercises
          .flatMap((exercise) => [exercise.exerciseId, ...exercise.substitutionExerciseIds])
          .filter((exerciseId) => !source.exercises.some((exercise) => exercise.id === exerciseId))
      )
    );
    expect(missingExerciseIds).toEqual([]);

    const installed = trackerReducer(source, {
      type: "INSTALL_PROGRAM_TEMPLATE",
      template: workoutProgramTemplates[0]
    });
    const plan = installed.plans.find((item) => item.id === installed.activePlanId)!;
    const weeks = installed.weeks.filter((week) => week.planId === plan.id);
    const sessions = installed.sessions.filter((session) => weeks.some((week) => week.id === session.weekId));

    expect(plan.sourceTemplateId).toBe("full-body-foundation-12");
    expect(weeks).toHaveLength(12);
    expect(sessions).toHaveLength(36);
    expect(installed.phases.filter((phase) => phase.planId === plan.id)).toHaveLength(3);
    expect(weeks.find((week) => week.weekNumber === 4)?.title).toContain("Deload");
    expect(workoutProgramTemplates[0]).toEqual(templateSnapshot);
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
    expect(state.setLogs.filter((log) => ["p-bench", "p-ohp"].includes(log.prescriptionId))).toHaveLength(6);
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
    expect(finished.notifications[0]).toMatchObject({ kind: "Achievement", target: "/profile", title: "Achievement unlocked" });
  });

  it("keeps active-workout order, substitutions, rest, and previous-set completion local to the session", () => {
    let state = fresh();
    const bench = state.prescriptions.find((item) => item.id === "p-bench")!;
    const historicalSet = {
      id: "history-bench-1",
      prescriptionId: bench.id,
      setNumber: 1,
      weight: 205,
      reps: 8,
      rpe: 8,
      isWarmup: false,
      isComplete: true,
      performedAt: "2026-07-01T12:00:00.000Z"
    };
    state.completedWorkouts = [{
      id: "history-workout",
      sessionId: "session-push",
      planId: "plan-strength",
      weekId: "week-1",
      name: "Push",
      completedAt: "2026-07-01T12:00:00.000Z",
      durationSeconds: 2400,
      completedExercises: 1,
      totalExercises: 1,
      totalSets: 1,
      totalVolume: 1640,
      bestSet: historicalSet,
      setLogs: [historicalSet],
      prescriptions: [bench]
    }];

    state = trackerReducer(state, { type: "START_WORKOUT", sessionId: "session-push" });
    state = trackerReducer(state, { type: "MOVE_WORKOUT_EXERCISE", prescriptionId: "p-ohp", direction: "up" });
    state = trackerReducer(state, { type: "SET_WORKOUT_REST", prescriptionId: "p-bench", seconds: 90 });
    const dumbbellBench = state.exercises.find((item) => item.id === "db-bench")!;
    state = trackerReducer(state, { type: "SUBSTITUTE_WORKOUT_EXERCISE", prescriptionId: "p-bench", exercise: dumbbellBench });
    expect(state.activeWorkout?.exerciseOrder).toEqual(["p-ohp", "p-bench"]);
    expect(state.activeWorkout?.restOverrides["p-bench"]).toBe(90);
    expect(state.activeWorkout?.exerciseOverrides["p-bench"].originalExerciseName).toBe("Barbell Bench Press");

    state = trackerReducer(state, { type: "SUBSTITUTE_WORKOUT_EXERCISE", prescriptionId: "p-bench", exercise: state.exercises.find((item) => item.id === "barbell-bench")! });
    const firstSet = state.setLogs.find((item) => item.prescriptionId === "p-bench" && item.setNumber === 1)!;
    state = trackerReducer(state, { type: "AUTO_COMPLETE_SET", logId: firstSet.id });
    expect(state.setLogs.find((item) => item.id === firstSet.id)).toMatchObject({ weight: 205, reps: 8, rpe: 8, isComplete: true });

    state = trackerReducer(state, { type: "SUBSTITUTE_WORKOUT_EXERCISE", prescriptionId: "p-bench", exercise: dumbbellBench });
    const finished = trackerReducer(state, { type: "FINISH_WORKOUT", sessionId: "session-push" });
    expect(finished.prescriptions.find((item) => item.id === "p-bench")?.exerciseId).toBe("barbell-bench");
    expect(finished.completedWorkouts[0].prescriptions.map((item) => item.id)).toEqual(["p-ohp", "p-bench"]);
    expect(finished.completedWorkouts[0].prescriptions.find((item) => item.id === "p-bench")).toMatchObject({
      exerciseId: "db-bench",
      restSeconds: 90,
      order: 1
    });
    expect(finished.completedWorkouts[0].prescriptions.find((item) => item.id === "p-bench")?.notes).toContain("Substituted for Barbell Bench Press");
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
    expect(loadTrackerState(invalidStorage).version).toBe(4);
    const oldStorage = {
      getItem: (key: string) => key === STORAGE_KEY ? JSON.stringify({ version: 1 }) : null
    } as Pick<Storage, "getItem">;
    expect(loadTrackerState(oldStorage).plans[0].name).toBe("Strength Foundation");
  });

  it("migrates version 2 tracker data without losing workouts", () => {
    const version2 = { ...fresh(), version: 2, completedWorkouts: [{ ...fresh().completedWorkouts[0] }].filter(Boolean) };
    const storage = { getItem: () => JSON.stringify(version2) } as Pick<Storage, "getItem">;
    const migrated = loadTrackerState(storage);
    expect(migrated.version).toBe(4);
    expect(migrated.profiles.length).toBeGreaterThan(1);
    expect(migrated.plans[0].name).toBe("Strength Foundation");
  });

  it("migrates likes, legacy categories, comments, and profile defaults to version 4", () => {
    const legacy = fresh() as unknown as Record<string, unknown>;
    legacy.version = 3;
    legacy.communityPosts = [{ id: "legacy", authorId: "user-robert", kind: "PR", title: "Old PR", body: "Legacy", createdAt: new Date().toISOString(), likedBy: ["user-mia"], savedBy: [] }];
    legacy.comments = [{ id: "old-comment", postId: "legacy", authorId: "user-mia", body: "Nice", createdAt: new Date().toISOString() }];
    const migrated = loadTrackerState({ getItem: () => JSON.stringify(legacy) } as Pick<Storage, "getItem">);
    expect(migrated.communityPosts[0]).toMatchObject({ kind: "Personal Record", groupId: "group-general-strength", votes: { "user-mia": 1 } });
    expect(migrated.comments[0].votes).toEqual({});
    expect(migrated.profiles[0].role).toBe("Admin");
  });

  it("migrates legacy moderator verification to evidence-based video verification", () => {
    const legacy = fresh() as unknown as Record<string, unknown>;
    const lift = structuredClone(fresh().liftSubmissions[0]) as unknown as Record<string, unknown>;
    lift.verification = "Moderator Verified";
    legacy.liftSubmissions = [lift];

    const migrated = loadTrackerState({ getItem: () => JSON.stringify(legacy) } as Pick<Storage, "getItem">);

    expect(migrated.liftSubmissions[0].verification).toBe("Video Verified");
  });

  it("preserves memberships before the lazy gym catalog is hydrated", async () => {
    const stale = fresh();
    stale.gyms = stale.gyms
      .filter((gym) => gym.state === "Florida" && gym.brand === "Crunch Fitness")
      .map(({ brand: _brand, address: _address, ...gym }) => gym as never);
    stale.joinedGymIds = ["gym-south-beach", "gym-doral", "gym-no-longer-open"];
    const storage = { getItem: () => JSON.stringify(stale) } as Pick<Storage, "getItem">;

    const migrated = loadTrackerState(storage);

    expect(migrated.joinedGymIds).toEqual(["gym-south-beach", "gym-doral", "gym-no-longer-open"]);
    expect(migrated.gyms).toHaveLength(9);
    expect(migrated.gyms.every((gym) => gym.brand && gym.address)).toBe(true);
    const hydrated = trackerReducer(migrated, { type: "HYDRATE_GYM_CATALOG", gyms: await loadGymCatalog() });
    expect(hydrated.gyms.some((gym) => gym.brand === "Anytime Fitness")).toBe(true);
    expect(hydrated.gyms.some((gym) => gym.state === "California")).toBe(true);
    expect(hydrated.joinedGymIds).toEqual(["gym-south-beach", "gym-doral"]);
  });

  it("keeps an already loaded catalog when demo state is reset", async () => {
    const fullCatalog = await loadGymCatalog();
    const customized = trackerReducer({ ...fresh(), gyms: fullCatalog }, {
      type: "INSTALL_PROGRAM_TEMPLATE",
      template: workoutProgramTemplates[0]
    });
    const reset = trackerReducer(customized, { type: "RESET_DEMO" });
    expect(reset.gyms).toHaveLength(fullCatalog.length);
    expect(reset.gyms.some((gym) => gym.brand === "Anytime Fitness")).toBe(true);
    expect(reset.plans).toEqual(seedState.plans);
    expect(reset.weeks).toEqual(seedState.weeks);
  });

  it("refreshes an old exercise catalog while preserving custom exercises", () => {
    const stale = fresh();
    stale.exercises = [
      ...stale.exercises.slice(0, 28),
      { id: "custom-camber-curl", name: "Camber Curl", bodyPart: "Arms", bodyRegions: ["Arms"], secondaryMuscles: [], equipment: "Cable", movementType: "Isolation", trackingType: "Weight + Reps", searchAliases: [], isCustom: true }
    ];
    const loaded = loadTrackerState({ getItem: () => JSON.stringify(stale) } as Pick<Storage, "getItem">);
    expect(loaded.exercises.length).toBe(seedState.exercises.length + 1);
    expect(loaded.exercises.some((exercise) => exercise.id === "custom-camber-curl")).toBe(true);
  });

  it("does not persist the bundled gym catalog", () => {
    const persisted = JSON.parse(serializeTrackerState(fresh()));
    expect(persisted.gyms).toBeUndefined();
    expect(persisted.joinedGymIds).toEqual(["gym-south-beach"]);
  });
});

describe("platform features", () => {
  it("keeps structured notification destinations for every local product flow", () => {
    const kinds = new Set(fresh().notifications.map((notification) => notification.kind));
    expect([...kinds]).toEqual(expect.arrayContaining(["Ranking", "Verification", "Friend", "Message", "Forum", "Achievement", "WorkoutReminder"]));
    expect(fresh().notifications.every((notification) => notification.target.startsWith("/") && notification.title && notification.body)).toBe(true);
  });

  it("ships a validated open U.S. catalog snapshot with source metadata", () => {
    const brands = ["Crunch Fitness", "LA Fitness", "EOS Fitness", "YouFit", "Anytime Fitness", "Gold's Gym"];
    expect(Object.keys(gymCatalog.counts).sort()).toEqual([...brands].sort());
    expect(gymCatalog.sources.map((source) => source.brand).sort()).toEqual([...brands].sort());
    expect(gymCatalog.gyms.every((gym) => gym.status === "Open" && gym.countryCode === "US")).toBe(true);
    const addressKeys = gymCatalog.gyms.map((gym) => `${gym.brand}|${gym.address}|${gym.city}|${gym.state}|${gym.postalCode}`.toLowerCase().replace(/[^a-z0-9|]/g, ""));
    expect(new Set(addressKeys).size).toBe(addressKeys.length);
    expect(gymCatalog.gyms.every((gym) => !("memberCount" in gym) && !("verifiedLiftCount" in gym))).toBe(true);
  });

  it("lazy-loads unique, complete official gym records and keeps legacy metrics scoped", async () => {
    const gyms = await loadGymCatalog();
    expect(gyms.length).toBeGreaterThan(1400);
    expect(new Set(gyms.map((gym) => gym.id)).size).toBe(gyms.length);
    expect(new Set(gyms.map((gym) => gym.brand))).toEqual(new Set(["Crunch Fitness", "LA Fitness", "EOS Fitness", "YouFit", "Anytime Fitness", "Gold's Gym"]));
    expect(gyms.every((gym) => gym.brand && gym.address && gym.city && gym.state && gym.postalCode && gym.countryCode === "US" && gym.officialUrl.startsWith("https://"))).toBe(true);
    expect(gyms.find((gym) => gym.id === "gym-south-beach")?.brand).toBe("Crunch Fitness");
    expect(gyms.some((gym) => gym.name === "YouFit Gyms - Weston")).toBe(true);
    expect(gyms.find((gym) => gym.name === "YouFit Gyms - Weston")?.memberCount).toBeUndefined();
    expect(gyms.find((gym) => gym.name === "YouFit Gyms - Weston")?.verifiedLiftCount).toBeUndefined();
  });

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
