import {
  createContext,
  type Dispatch,
  type PropsWithChildren,
  useContext,
  useCallback,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  useState
} from "react";
import { seedState } from "./data";
import { calculateSummary, makeId, workoutDuration } from "./lib";
import { nextLocalMidnight } from "./platform";
import type {
  Comment,
  CommunityReportReason,
  CommunityVote,
  CommunityPost,
  Exercise,
  ExercisePrescription,
  LiftSubmission,
  MessageReportReason,
  TrackerState,
  UserProfile,
  WorkoutPlan,
  WorkoutSetLog
} from "./types";

export const STORAGE_KEY = "liftrank-tracker-v2";

export type TrackerAction =
  | { type: "SET_ACTIVE_PLAN"; planId: string }
  | { type: "CREATE_PLAN"; name: string; goal: string }
  | { type: "RENAME_PLAN"; planId: string; name: string }
  | { type: "DUPLICATE_PLAN"; planId: string }
  | { type: "DELETE_PLAN"; planId: string }
  | { type: "ADD_WEEK"; planId: string }
  | { type: "CLONE_WEEK"; weekId: string }
  | { type: "DELETE_WEEK"; weekId: string }
  | { type: "ADD_SESSION"; weekId: string; day: string; name: string; freestyle?: boolean }
  | { type: "DELETE_SESSION"; sessionId: string }
  | {
      type: "ADD_PRESCRIPTION";
      sessionId: string;
      exercise: Exercise;
      sets: number;
      reps: string;
      restSeconds: number;
    }
  | { type: "DELETE_PRESCRIPTION"; prescriptionId: string }
  | { type: "ADD_EXERCISE"; exercise: Exercise }
  | { type: "START_WORKOUT"; sessionId: string }
  | { type: "PAUSE_WORKOUT" }
  | { type: "RESUME_WORKOUT" }
  | { type: "CANCEL_WORKOUT"; sessionId: string }
  | { type: "ENSURE_SET_LOGS"; prescriptionId: string; count: number }
  | { type: "UPDATE_SET"; logId: string; field: "weight" | "reps" | "rpe"; value: number | null }
  | { type: "TOGGLE_SET"; logId: string }
  | { type: "ADD_SET"; prescriptionId: string }
  | { type: "DELETE_SET"; logId: string }
  | { type: "FINISH_WORKOUT"; sessionId: string }
  | { type: "ADD_BODYWEIGHT"; weight: number }
  | { type: "UPDATE_BODYWEIGHT"; entryId: string; weight: number; notes: string; recordedAt: string }
  | { type: "SAVE_WORKOUT_FEEDBACK"; sessionId: string; effort: number; notes: string; shared: boolean }
  | { type: "UPDATE_PROFILE"; profile: UserProfile }
  | { type: "JOIN_GYM"; gymId: string }
  | { type: "LEAVE_GYM"; gymId: string }
  | { type: "SUBMIT_LIFT"; lift: Omit<LiftSubmission, "id" | "submittedAt" | "leaderboardEligibleAt"> }
  | { type: "CREATE_POST"; post: Omit<CommunityPost, "id" | "createdAt" | "likedBy" | "votes" | "savedBy" | "isLocked"> }
  | { type: "JOIN_GROUP"; groupId: string }
  | { type: "LEAVE_GROUP"; groupId: string }
  | { type: "VOTE_POST"; postId: string; vote: CommunityVote }
  | { type: "VOTE_COMMENT"; commentId: string; vote: CommunityVote }
  | { type: "TOGGLE_POST_LIKE"; postId: string }
  | { type: "TOGGLE_POST_SAVE"; postId: string }
  | { type: "ADD_COMMENT"; comment: Omit<Comment, "id" | "createdAt" | "authorId" | "votes"> }
  | { type: "EDIT_COMMENT"; commentId: string; body: string }
  | { type: "DELETE_COMMENT"; commentId: string }
  | { type: "REPORT_COMMUNITY"; targetType: "Post" | "Comment"; targetId: string; reason: CommunityReportReason; note?: string }
  | { type: "MODERATE_POST"; postId: string; operation: "remove" | "restore" | "lock" | "unlock" | "warn"; reason?: string }
  | { type: "RESOLVE_COMMUNITY_REPORT"; reportId: string }
  | { type: "BAN_GROUP_USER"; groupId: string; userId: string; reason: string }
  | { type: "SEND_FRIEND_REQUEST"; recipientId: string }
  | { type: "RESPOND_FRIEND_REQUEST"; requestId: string; status: "Accepted" | "Declined" }
  | { type: "CANCEL_FRIEND_REQUEST"; requestId: string }
  | { type: "SEND_MESSAGE"; recipientId: string; body: string }
  | { type: "DELETE_MESSAGE"; messageId: string }
  | { type: "DELETE_MESSAGE_THREAD"; threadId: string }
  | { type: "REPORT_MESSAGE"; messageId: string; reason: MessageReportReason; note: string }
  | { type: "MARK_NOTIFICATION_READ"; notificationId: string }
  | { type: "MARK_ALL_NOTIFICATIONS_READ" }
  | { type: "HYDRATE_GYM_CATALOG"; gyms: TrackerState["gyms"] }
  | { type: "RESET_DEMO" };

function cloneSeed(): TrackerState {
  return structuredClone(seedState);
}

export function loadTrackerState(storage: Pick<Storage, "getItem"> = localStorage): TrackerState {
  try {
    const seed = cloneSeed();
    const raw = storage.getItem(STORAGE_KEY);
    if (!raw) return seed;
    const parsed = JSON.parse(raw) as Partial<TrackerState> & { version?: number };
    if (![2, 3, 4].includes(parsed.version ?? 0) || !Array.isArray(parsed.plans) || !Array.isArray(parsed.exercises)) {
      return seed;
    }
    const joinedGymIds = Array.isArray(parsed.joinedGymIds)
      ? parsed.joinedGymIds.slice(0, 3)
      : seed.joinedGymIds;
    const profiles = (parsed.profiles ?? seed.profiles).map((profile) => {
      const fallback = seed.profiles.find((item) => item.id === profile.id) ?? seed.profiles[0];
      return { ...fallback, ...profile };
    });
    const communityPosts = (parsed.communityPosts ?? seed.communityPosts).filter((post) => post.kind !== "Workout").map((post) => {
      const legacySearch = `${post.id} ${post.title} ${post.body} ${(post.exerciseTags ?? []).join(" ")}`.toLowerCase();
      const inferredGroupId = post.groupId && post.groupId !== "group-general-strength" ? post.groupId
        : /post-1|post-2|powerlift|squat|bench|deadlift/.test(legacySearch) ? "group-powerlifting" : post.groupId ?? "group-general-strength";
      return ({
      ...post,
      kind: post.kind === "PR" ? "Personal Record" as const : post.kind === "Lift" ? "Progress" as const : post.kind === "Gym" ? "Discussion" as const : post.kind,
      groupId: inferredGroupId,
      likedBy: post.likedBy ?? [],
      votes: post.votes ?? Object.fromEntries((post.likedBy ?? []).map((id) => [id, 1])),
      savedBy: post.savedBy ?? [], exerciseTags: post.exerciseTags ?? [], goalTags: post.goalTags ?? [], isLocked: post.isLocked ?? false
    }); });
    const comments = (parsed.comments ?? seed.comments).map((comment) => ({ ...comment, votes: comment.votes ?? {} }));
    const validGroupIds = new Set(seed.trainingGroups.map((group) => group.id));
    const bundledExerciseIds = new Set(seed.exercises.map((exercise) => exercise.id));
    const bundledExerciseNames = new Set(seed.exercises.map((exercise) => exercise.name.toLowerCase()));
    const customExercises = (parsed.exercises ?? []).filter((exercise) =>
      exercise.isCustom &&
      !bundledExerciseIds.has(exercise.id) &&
      !bundledExerciseNames.has(exercise.name.toLowerCase())
    );
    return {
      ...seed,
      ...parsed,
      version: 4,
      // Directory records ship with the app and must not be replaced by an older
      // localStorage snapshot. Membership IDs remain user-owned and are migrated above.
      gyms: seed.gyms,
      // The bundled catalog is application data. Persist only compatible
      // user-created additions instead of allowing an old catalog snapshot
      // to replace newly shipped exercises.
      exercises: [...seed.exercises, ...customExercises],
      joinedGymIds,
      profiles,
      communityPosts,
      comments,
      trainingGroups: seed.trainingGroups,
      joinedGroupIds: (parsed.joinedGroupIds ?? seed.joinedGroupIds).filter((id) => validGroupIds.has(id)),
      communityReports: parsed.communityReports ?? [],
      groupBans: parsed.groupBans ?? []
    };
  } catch {
    return cloneSeed();
  }
}

export function serializeTrackerState(state: TrackerState): string {
  const { gyms: _catalog, ...persistedState } = state;
  return JSON.stringify(persistedState);
}

function planGraph(state: TrackerState, planId: string) {
  const phases = state.phases.filter((phase) => phase.planId === planId);
  const weeks = state.weeks.filter((week) => week.planId === planId);
  const weekIds = new Set(weeks.map((week) => week.id));
  const sessions = state.sessions.filter((session) => weekIds.has(session.weekId));
  const sessionIds = new Set(sessions.map((session) => session.id));
  const prescriptions = state.prescriptions.filter((item) => sessionIds.has(item.sessionId));
  return { phases, weeks, sessions, prescriptions };
}

function removeSessionGraph(state: TrackerState, sessionId: string): TrackerState {
  const prescriptionIds = new Set(
    state.prescriptions.filter((item) => item.sessionId === sessionId).map((item) => item.id)
  );
  return {
    ...state,
    sessions: state.sessions.filter((session) => session.id !== sessionId),
    prescriptions: state.prescriptions.filter((item) => item.sessionId !== sessionId),
    setLogs: state.setLogs.filter((log) => !prescriptionIds.has(log.prescriptionId))
  };
}

export function trackerReducer(state: TrackerState, action: TrackerAction): TrackerState {
  switch (action.type) {
    case "SET_ACTIVE_PLAN":
      return {
        ...state,
        activePlanId: action.planId,
        plans: state.plans.map((plan) => ({ ...plan, isActive: plan.id === action.planId }))
      };

    case "CREATE_PLAN": {
      const planId = makeId("plan");
      const phaseId = makeId("phase");
      const weekId = makeId("week");
      const plan: WorkoutPlan = {
        id: planId,
        name: action.name.trim() || "Untitled Plan",
        goal: action.goal.trim() || "Build strength and muscle",
        notes: "",
        createdAt: new Date().toISOString(),
        isActive: true
      };
      return {
        ...state,
        activePlanId: planId,
        plans: [...state.plans.map((item) => ({ ...item, isActive: false })), plan],
        phases: [
          ...state.phases,
          { id: phaseId, planId, name: "Base Phase", order: 0, goal: plan.goal, durationWeeks: 1 }
        ],
        weeks: [
          ...state.weeks,
          { id: weekId, planId, phaseId, weekNumber: 1, title: "Week 1", notes: "" }
        ]
      };
    }

    case "RENAME_PLAN":
      return {
        ...state,
        plans: state.plans.map((plan) =>
          plan.id === action.planId ? { ...plan, name: action.name.trim() || plan.name } : plan
        )
      };

    case "DUPLICATE_PLAN": {
      const source = state.plans.find((plan) => plan.id === action.planId);
      if (!source) return state;
      const graph = planGraph(state, action.planId);
      const planId = makeId("plan");
      const phaseMap = new Map<string, string>();
      const weekMap = new Map<string, string>();
      const sessionMap = new Map<string, string>();
      const phases = graph.phases.map((phase) => {
        const id = makeId("phase");
        phaseMap.set(phase.id, id);
        return { ...phase, id, planId };
      });
      const weeks = graph.weeks.map((week) => {
        const id = makeId("week");
        weekMap.set(week.id, id);
        return { ...week, id, planId, phaseId: phaseMap.get(week.phaseId) ?? phases[0].id };
      });
      const sessions = graph.sessions.map((session) => {
        const id = makeId("session");
        sessionMap.set(session.id, id);
        return { ...session, id, weekId: weekMap.get(session.weekId) ?? weeks[0].id };
      });
      const prescriptions = graph.prescriptions.map((item) => ({
        ...item,
        id: makeId("rx"),
        sessionId: sessionMap.get(item.sessionId) ?? sessions[0].id
      }));
      return {
        ...state,
        activePlanId: planId,
        plans: [
          ...state.plans.map((plan) => ({ ...plan, isActive: false })),
          { ...source, id: planId, name: `${source.name} Copy`, createdAt: new Date().toISOString(), isActive: true }
        ],
        phases: [...state.phases, ...phases],
        weeks: [...state.weeks, ...weeks],
        sessions: [...state.sessions, ...sessions],
        prescriptions: [...state.prescriptions, ...prescriptions]
      };
    }

    case "DELETE_PLAN": {
      if (state.plans.length <= 1) return state;
      const graph = planGraph(state, action.planId);
      const phaseIds = new Set(graph.phases.map((item) => item.id));
      const weekIds = new Set(graph.weeks.map((item) => item.id));
      const sessionIds = new Set(graph.sessions.map((item) => item.id));
      const prescriptionIds = new Set(graph.prescriptions.map((item) => item.id));
      const plans = state.plans.filter((plan) => plan.id !== action.planId);
      const fallback = plans[0].id;
      return {
        ...state,
        activePlanId: state.activePlanId === action.planId ? fallback : state.activePlanId,
        plans: plans.map((plan) => ({ ...plan, isActive: plan.id === fallback })),
        phases: state.phases.filter((item) => !phaseIds.has(item.id)),
        weeks: state.weeks.filter((item) => !weekIds.has(item.id)),
        sessions: state.sessions.filter((item) => !sessionIds.has(item.id)),
        prescriptions: state.prescriptions.filter((item) => !prescriptionIds.has(item.id)),
        setLogs: state.setLogs.filter((item) => !prescriptionIds.has(item.prescriptionId))
      };
    }

    case "ADD_WEEK": {
      const weeks = state.weeks.filter((week) => week.planId === action.planId);
      const number = Math.max(0, ...weeks.map((week) => week.weekNumber)) + 1;
      const phase =
        state.phases.find((item) => item.planId === action.planId) ??
        { id: makeId("phase"), planId: action.planId, name: "Base Phase", order: 0, goal: "", durationWeeks: 1 };
      return {
        ...state,
        phases: state.phases.some((item) => item.id === phase.id) ? state.phases : [...state.phases, phase],
        weeks: [
          ...state.weeks,
          {
            id: makeId("week"),
            planId: action.planId,
            phaseId: phase.id,
            weekNumber: number,
            title: `Week ${number}`,
            notes: ""
          }
        ]
      };
    }

    case "CLONE_WEEK": {
      const source = state.weeks.find((week) => week.id === action.weekId);
      if (!source) return state;
      const number = Math.max(...state.weeks.filter((week) => week.planId === source.planId).map((week) => week.weekNumber)) + 1;
      const weekId = makeId("week");
      const sourceSessions = state.sessions.filter((session) => session.weekId === source.id);
      const sessionMap = new Map<string, string>();
      const sessions = sourceSessions.map((session) => {
        const id = makeId("session");
        sessionMap.set(session.id, id);
        return { ...session, id, weekId };
      });
      const sourceIds = new Set(sourceSessions.map((session) => session.id));
      const prescriptions = state.prescriptions
        .filter((item) => sourceIds.has(item.sessionId))
        .map((item) => ({
          ...item,
          id: makeId("rx"),
          sessionId: sessionMap.get(item.sessionId) as string
        }));
      return {
        ...state,
        weeks: [
          ...state.weeks,
          { ...source, id: weekId, weekNumber: number, title: `Week ${number}` }
        ],
        sessions: [...state.sessions, ...sessions],
        prescriptions: [...state.prescriptions, ...prescriptions]
      };
    }

    case "DELETE_WEEK": {
      const sessionIds = state.sessions.filter((session) => session.weekId === action.weekId).map((item) => item.id);
      const prescriptionIds = new Set(
        state.prescriptions.filter((item) => sessionIds.includes(item.sessionId)).map((item) => item.id)
      );
      return {
        ...state,
        weeks: state.weeks.filter((week) => week.id !== action.weekId),
        sessions: state.sessions.filter((session) => session.weekId !== action.weekId),
        prescriptions: state.prescriptions.filter((item) => !sessionIds.includes(item.sessionId)),
        setLogs: state.setLogs.filter((item) => !prescriptionIds.has(item.prescriptionId))
      };
    }

    case "ADD_SESSION":
      return {
        ...state,
        sessions: [
          ...state.sessions,
          {
            id: makeId("session"),
            weekId: action.weekId,
            day: action.day,
            name: action.name.trim() || "Workout",
            order: state.sessions.filter((session) => session.weekId === action.weekId).length,
            notes: "",
            isFreestyle: action.freestyle
          }
        ]
      };

    case "DELETE_SESSION":
      return removeSessionGraph(state, action.sessionId);

    case "ADD_PRESCRIPTION": {
      if (
        state.prescriptions.some(
          (item) => item.sessionId === action.sessionId && item.exerciseId === action.exercise.id
        )
      ) {
        return state;
      }
      const prescription: ExercisePrescription = {
        id: makeId("rx"),
        sessionId: action.sessionId,
        exerciseId: action.exercise.id,
        exerciseName: action.exercise.name,
        bodyPart: action.exercise.bodyPart,
        equipment: action.exercise.equipment,
        sets: action.sets,
        reps: action.reps,
        restSeconds: action.restSeconds,
        order: state.prescriptions.filter((item) => item.sessionId === action.sessionId).length,
        notes: ""
      };
      return { ...state, prescriptions: [...state.prescriptions, prescription] };
    }

    case "DELETE_PRESCRIPTION":
      return {
        ...state,
        prescriptions: state.prescriptions.filter((item) => item.id !== action.prescriptionId),
        setLogs: state.setLogs.filter((item) => item.prescriptionId !== action.prescriptionId)
      };

    case "ADD_EXERCISE":
      return state.exercises.some((item) => item.name.toLowerCase() === action.exercise.name.toLowerCase())
        ? state
        : { ...state, exercises: [...state.exercises, action.exercise] };

    case "START_WORKOUT":
      return {
        ...state,
        activeWorkout: {
          sessionId: action.sessionId,
          startedAt: new Date().toISOString(),
          pausedAt: null,
          pausedSeconds: 0
        }
      };

    case "PAUSE_WORKOUT":
      return state.activeWorkout && !state.activeWorkout.pausedAt
        ? { ...state, activeWorkout: { ...state.activeWorkout, pausedAt: new Date().toISOString() } }
        : state;

    case "RESUME_WORKOUT": {
      if (!state.activeWorkout?.pausedAt) return state;
      const added = Math.floor(
        (Date.now() - new Date(state.activeWorkout.pausedAt).getTime()) / 1000
      );
      return {
        ...state,
        activeWorkout: {
          ...state.activeWorkout,
          pausedAt: null,
          pausedSeconds: state.activeWorkout.pausedSeconds + added
        }
      };
    }

    case "CANCEL_WORKOUT": {
      const prescriptionIds = new Set(
        state.prescriptions.filter((item) => item.sessionId === action.sessionId).map((item) => item.id)
      );
      const session = state.sessions.find((item) => item.id === action.sessionId);
      const cleared = {
        ...state,
        activeWorkout: null,
        setLogs: state.setLogs.filter((log) => !prescriptionIds.has(log.prescriptionId))
      };
      return session?.isFreestyle ? removeSessionGraph(cleared, action.sessionId) : cleared;
    }

    case "ENSURE_SET_LOGS": {
      const existing = state.setLogs.filter((log) => log.prescriptionId === action.prescriptionId);
      if (existing.length >= action.count) return state;
      const additions = Array.from({ length: action.count - existing.length }, (_, index) => ({
        id: makeId("set"),
        prescriptionId: action.prescriptionId,
        setNumber: existing.length + index + 1,
        weight: null,
        reps: null,
        rpe: null,
        isWarmup: false,
        isComplete: false,
        performedAt: new Date().toISOString()
      }));
      return { ...state, setLogs: [...state.setLogs, ...additions] };
    }

    case "UPDATE_SET":
      return {
        ...state,
        setLogs: state.setLogs.map((log) =>
          log.id === action.logId ? { ...log, [action.field]: action.value } : log
        )
      };

    case "TOGGLE_SET":
      return {
        ...state,
        setLogs: state.setLogs.map((log) => {
          if (log.id !== action.logId) return log;
          if (!log.isComplete && (log.reps === null || log.weight === null)) return log;
          return { ...log, isComplete: !log.isComplete, performedAt: new Date().toISOString() };
        })
      };

    case "ADD_SET": {
      const count = state.setLogs.filter((log) => log.prescriptionId === action.prescriptionId).length;
      const log: WorkoutSetLog = {
        id: makeId("set"),
        prescriptionId: action.prescriptionId,
        setNumber: count + 1,
        weight: null,
        reps: null,
        rpe: null,
        isWarmup: false,
        isComplete: false,
        performedAt: new Date().toISOString()
      };
      return { ...state, setLogs: [...state.setLogs, log] };
    }

    case "DELETE_SET": {
      const target = state.setLogs.find((log) => log.id === action.logId);
      if (!target) return state;
      return {
        ...state,
        setLogs: state.setLogs
          .filter((log) => log.id !== action.logId)
          .map((log) =>
            log.prescriptionId === target.prescriptionId && log.setNumber > target.setNumber
              ? { ...log, setNumber: log.setNumber - 1 }
              : log
          )
      };
    }

    case "FINISH_WORKOUT": {
      const session = state.sessions.find((item) => item.id === action.sessionId);
      const week = session && state.weeks.find((item) => item.id === session.weekId);
      if (!session || !week) return state;
      const prescriptions = state.prescriptions.filter((item) => item.sessionId === session.id);
      const ids = new Set(prescriptions.map((item) => item.id));
      const setLogs = state.setLogs.filter((item) => ids.has(item.prescriptionId) && item.isComplete);
      const summary = calculateSummary(prescriptions, setLogs);
      const completed = {
        ...summary,
        id: makeId("completed"),
        sessionId: session.id,
        planId: week.planId,
        weekId: week.id,
        name: session.name,
        completedAt: new Date().toISOString(),
        durationSeconds: workoutDuration(state.activeWorkout),
        setLogs: structuredClone(setLogs),
        prescriptions: structuredClone(prescriptions)
      };
      return {
        ...state,
        activeWorkout: null,
        completedWorkouts: [completed, ...state.completedWorkouts]
      };
    }

    case "ADD_BODYWEIGHT":
      return {
        ...state,
        bodyweight: [
          ...state.bodyweight,
          { id: makeId("bw"), recordedAt: new Date().toISOString(), weight: action.weight }
        ]
      };

    case "UPDATE_BODYWEIGHT":
      return {
        ...state,
        bodyweight: state.bodyweight.map((entry) =>
          entry.id === action.entryId
            ? { ...entry, weight: action.weight, notes: action.notes, recordedAt: action.recordedAt }
            : entry
        )
      };

    case "SAVE_WORKOUT_FEEDBACK":
      return {
        ...state,
        workoutFeedback: [
          {
            id: makeId("feedback"),
            sessionId: action.sessionId,
            effort: action.effort,
            notes: action.notes.trim(),
            shared: action.shared,
            createdAt: new Date().toISOString()
          },
          ...state.workoutFeedback.filter((item) => item.sessionId !== action.sessionId)
        ]
      };

    case "UPDATE_PROFILE":
      return {
        ...state,
        profiles: state.profiles.map((profile) => profile.id === action.profile.id ? action.profile : profile),
        joinedGymIds: action.profile.id === state.currentUserId
          ? [action.profile.primaryGymId, ...state.joinedGymIds.filter((id) => id !== action.profile.primaryGymId)].slice(0, 3)
          : state.joinedGymIds
      };

    case "JOIN_GYM":
      if (state.joinedGymIds.includes(action.gymId) || state.joinedGymIds.length >= 3) return state;
      return { ...state, joinedGymIds: [...state.joinedGymIds, action.gymId] };

    case "LEAVE_GYM": {
      const profile = state.profiles.find((item) => item.id === state.currentUserId);
      if (!profile || profile.primaryGymId === action.gymId) return state;
      return { ...state, joinedGymIds: state.joinedGymIds.filter((id) => id !== action.gymId) };
    }

    case "SUBMIT_LIFT": {
      if (!state.joinedGymIds.includes(action.lift.gymId)) return state;
      const now = new Date().toISOString();
      const lift: LiftSubmission = {
        ...action.lift,
        id: makeId("lift"),
        submittedAt: now,
        leaderboardEligibleAt: nextLocalMidnight()
      };
      const post: CommunityPost | null = lift.visibility === "Public" ? {
        id: makeId("post"),
        authorId: state.currentUserId,
        kind: "Progress",
        groupId: "group-general-strength",
        title: `${lift.exerciseName} submitted`,
        body: lift.caption || `${lift.weight} ${lift.unit} for ${lift.reps} rep${lift.reps === 1 ? "" : "s"}.`,
        createdAt: now,
        linkedLiftId: lift.id,
        gymId: lift.gymId,
        likedBy: [],
        votes: {},
        savedBy: [],
        exerciseTags: [lift.exerciseName],
        goalTags: ["Strength"],
        trainingDetails: { exercise: lift.exerciseName, reps: lift.reps, weight: lift.weight, unit: lift.unit },
        isLocked: false
      } : null;
      return {
        ...state,
        liftSubmissions: [lift, ...state.liftSubmissions],
        communityPosts: post ? [post, ...state.communityPosts] : state.communityPosts,
        notifications: [{
          id: makeId("notification"),
          title: "Lift submitted",
          body: "Your lift will enter eligible rankings at the next daily update.",
          kind: "Lift",
          target: "/profile",
          createdAt: now,
          isRead: false
        }, ...state.notifications]
      };
    }

    case "CREATE_POST":
      if (state.groupBans.some((ban) => ban.groupId === action.post.groupId && ban.userId === state.currentUserId)) return state;
      return {
        ...state,
        communityPosts: [{
          ...action.post,
          id: makeId("post"),
          createdAt: new Date().toISOString(),
          likedBy: [],
          votes: {},
          savedBy: [],
          isLocked: false
        }, ...state.communityPosts]
      };

    case "JOIN_GROUP":
      if (!state.trainingGroups.some((group) => group.id === action.groupId) || state.joinedGroupIds.includes(action.groupId)) return state;
      return { ...state, joinedGroupIds: [...state.joinedGroupIds, action.groupId], trainingGroups: state.trainingGroups.map((group) => group.id === action.groupId ? { ...group, memberIds: [...new Set([...group.memberIds, state.currentUserId])] } : group) };

    case "LEAVE_GROUP":
      return { ...state, joinedGroupIds: state.joinedGroupIds.filter((id) => id !== action.groupId), trainingGroups: state.trainingGroups.map((group) => group.id === action.groupId ? { ...group, memberIds: group.memberIds.filter((id) => id !== state.currentUserId) } : group) };

    case "VOTE_POST":
      return { ...state, communityPosts: state.communityPosts.map((post) => {
        if (post.id !== action.postId) return post;
        const votes = { ...post.votes };
        if (votes[state.currentUserId] === action.vote) delete votes[state.currentUserId]; else votes[state.currentUserId] = action.vote;
        return { ...post, votes, likedBy: Object.entries(votes).filter(([, vote]) => vote === 1).map(([id]) => id) };
      }) };

    case "TOGGLE_POST_LIKE":
      return {
        ...state,
        communityPosts: state.communityPosts.map((post) => {
          if (post.id !== action.postId) return post;
          const votes = { ...post.votes };
          if (votes[state.currentUserId] === 1) delete votes[state.currentUserId]; else votes[state.currentUserId] = 1;
          return { ...post, votes, likedBy: Object.entries(votes).filter(([, vote]) => vote === 1).map(([id]) => id) };
        })
      };

    case "TOGGLE_POST_SAVE":
      return {
        ...state,
        communityPosts: state.communityPosts.map((post) => {
          if (post.id !== action.postId) return post;
          const saved = post.savedBy.includes(state.currentUserId);
          return { ...post, savedBy: saved ? post.savedBy.filter((id) => id !== state.currentUserId) : [...post.savedBy, state.currentUserId] };
        })
      };

    case "ADD_COMMENT": {
      const post = state.communityPosts.find((item) => item.id === action.comment.postId);
      if (!post || post.isLocked || post.removedAt || state.groupBans.some((ban) => ban.groupId === post.groupId && ban.userId === state.currentUserId)) return state;
      return {
        ...state,
        comments: [...state.comments, {
          ...action.comment,
          id: makeId("comment"),
          authorId: state.currentUserId,
          createdAt: new Date().toISOString(),
          votes: {}
        }]
      };
    }

    case "VOTE_COMMENT":
      return { ...state, comments: state.comments.map((comment) => { if (comment.id !== action.commentId) return comment; const votes = { ...comment.votes }; if (votes[state.currentUserId] === action.vote) delete votes[state.currentUserId]; else votes[state.currentUserId] = action.vote; return { ...comment, votes }; }) };

    case "EDIT_COMMENT":
      return { ...state, comments: state.comments.map((comment) => comment.id === action.commentId && comment.authorId === state.currentUserId && !comment.deletedAt ? { ...comment, body: action.body.trim(), editedAt: new Date().toISOString() } : comment) };

    case "DELETE_COMMENT":
      return { ...state, comments: state.comments.map((comment) => comment.id === action.commentId && comment.authorId === state.currentUserId ? { ...comment, body: "", deletedAt: new Date().toISOString() } : comment) };

    case "REPORT_COMMUNITY":
      if (state.communityReports.some((report) => report.reporterId === state.currentUserId && report.targetType === action.targetType && report.targetId === action.targetId && report.status === "Open")) return state;
      return { ...state, communityReports: [...state.communityReports, { id: makeId("community-report"), targetType: action.targetType, targetId: action.targetId, reporterId: state.currentUserId, reason: action.reason, note: action.note?.trim() ?? "", status: "Open", createdAt: new Date().toISOString() }] };

    case "MODERATE_POST": { const profile = state.profiles.find((item) => item.id === state.currentUserId); const post = state.communityPosts.find((item) => item.id === action.postId); const group = state.trainingGroups.find((item) => item.id === post?.groupId); if (!post || !profile || (profile.role !== "Admin" && !(profile.role === "Moderator" && group?.moderatorIds.includes(profile.id)))) return state; return { ...state, communityPosts: state.communityPosts.map((item) => item.id !== post.id ? item : action.operation === "remove" ? { ...item, removedAt: new Date().toISOString(), removalReason: action.reason ?? "Removed by a moderator" } : action.operation === "restore" ? { ...item, removedAt: undefined, removalReason: undefined } : action.operation === "lock" ? { ...item, isLocked: true } : action.operation === "unlock" ? { ...item, isLocked: false } : { ...item, warning: action.reason ?? "Moderator warning" }) }; }

    case "RESOLVE_COMMUNITY_REPORT": { const profile = state.profiles.find((item) => item.id === state.currentUserId); if (!profile || profile.role === "Member") return state; return { ...state, communityReports: state.communityReports.map((report) => report.id === action.reportId ? { ...report, status: "Resolved" } : report) }; }

    case "BAN_GROUP_USER": { const profile = state.profiles.find((item) => item.id === state.currentUserId); const group = state.trainingGroups.find((item) => item.id === action.groupId); if (!profile || profile.role === "Member" || (profile.role === "Moderator" && !group?.moderatorIds.includes(profile.id))) return state; if (state.groupBans.some((ban) => ban.groupId === action.groupId && ban.userId === action.userId)) return state; return { ...state, groupBans: [...state.groupBans, { id: makeId("ban"), groupId: action.groupId, userId: action.userId, moderatorId: state.currentUserId, reason: action.reason, createdAt: new Date().toISOString() }] }; }

    case "SEND_FRIEND_REQUEST":
      if (action.recipientId === state.currentUserId || state.friendRequests.some((request) =>
        request.status !== "Declined" &&
        ((request.senderId === state.currentUserId && request.recipientId === action.recipientId) ||
          (request.senderId === action.recipientId && request.recipientId === state.currentUserId))
      )) return state;
      return {
        ...state,
        friendRequests: [{ id: makeId("friend"), senderId: state.currentUserId, recipientId: action.recipientId, status: "Pending", createdAt: new Date().toISOString() }, ...state.friendRequests]
      };

    case "RESPOND_FRIEND_REQUEST":
      return {
        ...state,
        friendRequests: state.friendRequests.map((request) => request.id === action.requestId ? { ...request, status: action.status } : request)
      };

    case "CANCEL_FRIEND_REQUEST":
      return {
        ...state,
        friendRequests: state.friendRequests.filter((request) => !(request.id === action.requestId && request.senderId === state.currentUserId && request.status === "Pending"))
      };

    case "SEND_MESSAGE": {
      const body = action.body.trim();
      if (!body) return state;
      const existing = state.messageThreads.find((thread) =>
        thread.participantIds.includes(state.currentUserId) && thread.participantIds.includes(action.recipientId)
      );
      const threadId = existing?.id ?? makeId("thread");
      const now = new Date().toISOString();
      return {
        ...state,
        messageThreads: existing
          ? state.messageThreads.map((thread) => thread.id === threadId ? { ...thread, updatedAt: now } : thread)
          : [{ id: threadId, participantIds: [state.currentUserId, action.recipientId], createdAt: now, updatedAt: now }, ...state.messageThreads],
        messages: [...state.messages, { id: makeId("message"), threadId, senderId: state.currentUserId, body, createdAt: now, isRead: true, isReported: false }]
      };
    }

    case "DELETE_MESSAGE":
      return { ...state, messages: state.messages.filter((message) => message.id !== action.messageId) };

    case "DELETE_MESSAGE_THREAD":
      return {
        ...state,
        messageThreads: state.messageThreads.filter((thread) => thread.id !== action.threadId),
        messages: state.messages.filter((message) => message.threadId !== action.threadId)
      };

    case "REPORT_MESSAGE":
      if (!state.messages.some((message) => message.id === action.messageId)) return state;
      return {
        ...state,
        messages: state.messages.map((message) => message.id === action.messageId ? { ...message, isReported: true } : message),
        messageReports: [...state.messageReports, {
          id: makeId("report"),
          messageId: action.messageId,
          reporterId: state.currentUserId,
          reason: action.reason,
          note: action.note.trim(),
          createdAt: new Date().toISOString()
        }]
      };

    case "MARK_NOTIFICATION_READ":
      return {
        ...state,
        notifications: state.notifications.map((notification) => notification.id === action.notificationId ? { ...notification, isRead: true } : notification)
      };

    case "MARK_ALL_NOTIFICATIONS_READ":
      return { ...state, notifications: state.notifications.map((notification) => ({ ...notification, isRead: true })) };

    case "HYDRATE_GYM_CATALOG": {
      const validGymIds = new Set(action.gyms.map((gym) => gym.id));
      return {
        ...state,
        gyms: action.gyms,
        joinedGymIds: state.joinedGymIds.filter((gymId) => validGymIds.has(gymId))
      };
    }

    case "RESET_DEMO":
      return state.gyms.length > 20 ? { ...cloneSeed(), gyms: state.gyms } : cloneSeed();
  }
}

interface StoreValue {
  state: TrackerState;
  dispatch: Dispatch<TrackerAction>;
  gymCatalogStatus: "idle" | "loading" | "ready" | "error";
  gymCatalogError: string | null;
  ensureGymCatalog(): Promise<void>;
}

const TrackerContext = createContext<StoreValue | null>(null);

export function TrackerProvider({ children, initialState }: PropsWithChildren<{ initialState?: TrackerState }>) {
  const [state, dispatch] = useReducer(trackerReducer, initialState ?? loadTrackerState());
  const [gymCatalogStatus, setGymCatalogStatus] = useState<StoreValue["gymCatalogStatus"]>(state.gyms.length > 20 ? "ready" : "idle");
  const [gymCatalogError, setGymCatalogError] = useState<string | null>(null);
  const gymCatalogRequest = useRef<Promise<void> | null>(null);

  const ensureGymCatalog = useCallback(() => {
    if (gymCatalogStatus === "ready") return Promise.resolve();
    if (gymCatalogRequest.current) return gymCatalogRequest.current;
    setGymCatalogStatus("loading");
    setGymCatalogError(null);
    gymCatalogRequest.current = import("./gymCatalog")
      .then(({ loadGymCatalog }) => loadGymCatalog())
      .then((gyms) => {
        dispatch({ type: "HYDRATE_GYM_CATALOG", gyms });
        setGymCatalogStatus("ready");
      })
      .catch((error: unknown) => {
        gymCatalogRequest.current = null;
        setGymCatalogStatus("error");
        setGymCatalogError(error instanceof Error ? error.message : "Unable to load the gym directory.");
      });
    return gymCatalogRequest.current;
  }, [gymCatalogStatus]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, serializeTrackerState(state));
  }, [state]);

  const value = useMemo(() => ({ state, dispatch, gymCatalogStatus, gymCatalogError, ensureGymCatalog }), [ensureGymCatalog, gymCatalogError, gymCatalogStatus, state]);
  return <TrackerContext.Provider value={value}>{children}</TrackerContext.Provider>;
}

export function useTracker() {
  const value = useContext(TrackerContext);
  if (!value) throw new Error("useTracker must be used inside TrackerProvider");
  return value;
}
