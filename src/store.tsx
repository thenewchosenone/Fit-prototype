import {
  createContext,
  type Dispatch,
  type PropsWithChildren,
  useContext,
  useEffect,
  useMemo,
  useReducer
} from "react";
import { seedState } from "./data";
import { calculateSummary, makeId, workoutDuration } from "./lib";
import { nextLocalMidnight } from "./platform";
import type {
  Comment,
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
  | { type: "CREATE_POST"; post: Omit<CommunityPost, "id" | "createdAt" | "likedBy" | "savedBy"> }
  | { type: "TOGGLE_POST_LIKE"; postId: string }
  | { type: "TOGGLE_POST_SAVE"; postId: string }
  | { type: "ADD_COMMENT"; comment: Omit<Comment, "id" | "createdAt" | "authorId"> }
  | { type: "SEND_FRIEND_REQUEST"; recipientId: string }
  | { type: "RESPOND_FRIEND_REQUEST"; requestId: string; status: "Accepted" | "Declined" }
  | { type: "CANCEL_FRIEND_REQUEST"; requestId: string }
  | { type: "SEND_MESSAGE"; recipientId: string; body: string }
  | { type: "DELETE_MESSAGE"; messageId: string }
  | { type: "DELETE_MESSAGE_THREAD"; threadId: string }
  | { type: "REPORT_MESSAGE"; messageId: string; reason: MessageReportReason; note: string }
  | { type: "MARK_NOTIFICATION_READ"; notificationId: string }
  | { type: "MARK_ALL_NOTIFICATIONS_READ" }
  | { type: "RESET_DEMO" };

function cloneSeed(): TrackerState {
  return structuredClone(seedState);
}

export function loadTrackerState(storage: Pick<Storage, "getItem"> = localStorage): TrackerState {
  try {
    const raw = storage.getItem(STORAGE_KEY);
    if (!raw) return cloneSeed();
    const parsed = JSON.parse(raw) as Partial<TrackerState> & { version?: number };
    if (![2, 3].includes(parsed.version ?? 0) || !Array.isArray(parsed.plans) || !Array.isArray(parsed.exercises)) {
      return cloneSeed();
    }
    return { ...cloneSeed(), ...parsed, version: 3 };
  } catch {
    return cloneSeed();
  }
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
        kind: "Lift",
        title: `${lift.exerciseName} submitted`,
        body: lift.caption || `${lift.weight} ${lift.unit} for ${lift.reps} rep${lift.reps === 1 ? "" : "s"}.`,
        createdAt: now,
        linkedLiftId: lift.id,
        gymId: lift.gymId,
        likedBy: [],
        savedBy: []
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
      return {
        ...state,
        communityPosts: [{
          ...action.post,
          id: makeId("post"),
          createdAt: new Date().toISOString(),
          likedBy: [],
          savedBy: []
        }, ...state.communityPosts]
      };

    case "TOGGLE_POST_LIKE":
      return {
        ...state,
        communityPosts: state.communityPosts.map((post) => {
          if (post.id !== action.postId) return post;
          const liked = post.likedBy.includes(state.currentUserId);
          return { ...post, likedBy: liked ? post.likedBy.filter((id) => id !== state.currentUserId) : [...post.likedBy, state.currentUserId] };
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

    case "ADD_COMMENT":
      return {
        ...state,
        comments: [...state.comments, {
          ...action.comment,
          id: makeId("comment"),
          authorId: state.currentUserId,
          createdAt: new Date().toISOString()
        }]
      };

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

    case "RESET_DEMO":
      return cloneSeed();
  }
}

interface StoreValue {
  state: TrackerState;
  dispatch: Dispatch<TrackerAction>;
}

const TrackerContext = createContext<StoreValue | null>(null);

export function TrackerProvider({ children, initialState }: PropsWithChildren<{ initialState?: TrackerState }>) {
  const [state, dispatch] = useReducer(trackerReducer, initialState ?? loadTrackerState());

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [state]);

  const value = useMemo(() => ({ state, dispatch }), [state]);
  return <TrackerContext.Provider value={value}>{children}</TrackerContext.Provider>;
}

export function useTracker() {
  const value = useContext(TrackerContext);
  if (!value) throw new Error("useTracker must be used inside TrackerProvider");
  return value;
}
