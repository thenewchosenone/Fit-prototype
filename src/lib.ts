import type {
  CompletedWorkoutSession,
  ExercisePrescription,
  TrackerState,
  WorkoutSetLog,
  WorkoutSummary
} from "./types";

export const makeId = (prefix = "id") =>
  `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`;

export function parseRepGoal(goal: string): { min: number; max: number } {
  const values = goal.match(/\d+/g)?.map(Number) ?? [1];
  return { min: values[0], max: values[1] ?? values[0] };
}

export function calculateSummary(
  prescriptions: ExercisePrescription[],
  setLogs: WorkoutSetLog[]
): WorkoutSummary {
  const ids = new Set(prescriptions.map((item) => item.id));
  const completed = setLogs.filter(
    (log) =>
      ids.has(log.prescriptionId) &&
      log.isComplete &&
      log.reps !== null &&
      (log.weight !== null || prescriptions.find((p) => p.id === log.prescriptionId)?.equipment === "Bodyweight")
  );
  const completedIds = new Set(completed.map((log) => log.prescriptionId));
  return {
    completedExercises: completedIds.size,
    totalExercises: prescriptions.length,
    totalSets: completed.length,
    totalVolume: completed.reduce((total, log) => total + (log.weight ?? 0) * (log.reps ?? 0), 0),
    bestSet:
      completed.reduce<WorkoutSetLog | null>((best, log) => {
        if (!best) return log;
        return (log.weight ?? 0) > (best.weight ?? 0) ? log : best;
      }, null)
  };
}

export function estimatedOneRepMax(weight: number, reps: number): number {
  return Math.round(weight * (1 + reps / 30));
}

export function exerciseHistory(state: TrackerState, exerciseId: string) {
  return state.completedWorkouts
    .flatMap((workout) =>
      workout.setLogs.map((log) => ({
        log,
        prescription: workout.prescriptions.find((item) => item.id === log.prescriptionId),
        completedAt: workout.completedAt
      }))
    )
    .filter((item) => item.prescription?.exerciseId === exerciseId && item.log.isComplete)
    .sort((a, b) => b.completedAt.localeCompare(a.completedAt));
}

export function personalRecords(state: TrackerState, exerciseId: string) {
  const history = exerciseHistory(state, exerciseId);
  const logs = history.map((item) => item.log);
  const heaviest = logs.reduce<WorkoutSetLog | null>(
    (best, log) => (!best || (log.weight ?? 0) > (best.weight ?? 0) ? log : best),
    null
  );
  const bestForReps = (target: number) =>
    logs
      .filter((log) => (log.reps ?? 0) >= target)
      .reduce<WorkoutSetLog | null>(
        (best, log) => (!best || (log.weight ?? 0) > (best.weight ?? 0) ? log : best),
        null
      );
  const estimated = logs.reduce(
    (best, log) => Math.max(best, estimatedOneRepMax(log.weight ?? 0, log.reps ?? 0)),
    0
  );
  return { heaviest, best3: bestForReps(3), best5: bestForReps(5), best10: bestForReps(10), estimated };
}

export function recommendedNextWeight(
  state: TrackerState,
  prescription: ExercisePrescription
): number | null {
  const history = exerciseHistory(state, prescription.exerciseId);
  if (!history.length) return null;
  const recentDate = history[0].completedAt;
  const recent = history.filter((item) => item.completedAt === recentDate).map((item) => item.log);
  const workSets = recent.filter((log) => !log.isWarmup);
  if (!workSets.length) return null;
  const { min } = parseRepGoal(prescription.reps);
  const allHit = workSets.length >= prescription.sets && workSets.every((log) => (log.reps ?? 0) >= min);
  const highest = Math.max(...workSets.map((log) => log.weight ?? 0));
  const lowerBody = ["Quads", "Hamstrings", "Glutes", "Full Body"].includes(prescription.bodyPart);
  return allHit ? highest + (lowerBody ? 10 : 5) : highest;
}

export function workoutDuration(active: TrackerState["activeWorkout"], now = Date.now()): number {
  if (!active) return 0;
  const end = active.pausedAt ? new Date(active.pausedAt).getTime() : now;
  return Math.max(0, Math.floor((end - new Date(active.startedAt).getTime()) / 1000) - active.pausedSeconds);
}

export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remaining = seconds % 60;
  return [hours, minutes, remaining].map((value) => String(value).padStart(2, "0")).join(":");
}

export function formatWeight(value: number): string {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 }).format(value);
}

export function weekCompletion(state: TrackerState, weekId: string): number {
  const sessions = state.sessions.filter((session) => session.weekId === weekId);
  const prescriptions = state.prescriptions.filter((item) => sessions.some((session) => session.id === item.sessionId));
  if (!prescriptions.length) return 0;
  const completeIds = new Set(
    state.setLogs.filter((log) => log.isComplete).map((log) => log.prescriptionId)
  );
  return prescriptions.filter((item) => completeIds.has(item.id)).length / prescriptions.length;
}

export function volumeByBodyPart(workouts: CompletedWorkoutSession[]): Record<string, number> {
  return workouts.reduce<Record<string, number>>((totals, workout) => {
    workout.setLogs.forEach((log) => {
      const prescription = workout.prescriptions.find((item) => item.id === log.prescriptionId);
      if (!prescription || !log.isComplete) return;
      totals[prescription.bodyPart] =
        (totals[prescription.bodyPart] ?? 0) + (log.weight ?? 0) * (log.reps ?? 0);
    });
    return totals;
  }, {});
}
