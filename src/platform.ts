import type {
  Gym,
  LeaderboardEntry,
  LeaderboardScope,
  LiftSubmission,
  RankingType,
  SexCategory,
  TrackerState,
  UserProfile,
  VerificationLevel
} from "./types";

export type ComputedLeaderboardFilters = {
  rankingType: RankingType;
  scope: LeaderboardScope;
  verification: "All" | VerificationLevel;
  exercise: string;
  gym: string;
  city: string;
  ageGroup: string;
  experienceLevel: string;
  weightClass: string;
  repCount: number | null;
};

export const maleWeightClasses = [52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125, 140];
export const femaleWeightClasses = [44, 48, 52, 56, 60, 65, 70, 75, 82.5, 90, 100];

export function poundsToKilograms(value: number): number {
  return value / 2.2046226218;
}

export function kilogramsToPounds(value: number): number {
  return value * 2.2046226218;
}

export function weightClassFor(bodyweightPounds: number, sex: SexCategory): string {
  const kilograms = poundsToKilograms(bodyweightPounds);
  const classes = sex === "Female" ? femaleWeightClasses : maleWeightClasses;
  const limit = classes.find((item) => kilograms <= item);
  return `${limit ?? classes.at(-1)}${limit ? "" : "+"} kg`;
}

export function currentProfile(state: TrackerState): UserProfile {
  return state.profiles.find((profile) => profile.id === state.currentUserId) ?? state.profiles[0];
}

export function gymFor(state: TrackerState, gymId: string): Gym | undefined {
  return state.gyms.find((gym) => gym.id === gymId);
}

export function formatRelativeTime(value: string, now = Date.now()): string {
  const seconds = Math.max(0, Math.floor((now - new Date(value).getTime()) / 1000));
  if (seconds < 60) return "Just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return days < 7 ? `${days}d` : new Date(value).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function nextLocalMidnight(reference = new Date()): string {
  const next = new Date(reference);
  next.setHours(24, 0, 0, 0);
  return next.toISOString();
}

function eligibleLifts(state: TrackerState, filters: ComputedLeaderboardFilters, now = Date.now()): LiftSubmission[] {
  const self = currentProfile(state);
  const selfClass = weightClassFor(self.bodyweight, self.sex);
  return state.liftSubmissions.filter((lift) => {
    const profile = state.profiles.find((item) => item.id === lift.userId);
    const gym = gymFor(state, lift.gymId);
    if (!profile || !gym || lift.visibility !== "Public" || new Date(lift.leaderboardEligibleAt).getTime() > now) return false;
    if (filters.verification !== "All" && lift.verification !== filters.verification) return false;
    if (filters.scope === "My gym" && lift.gymId !== self.primaryGymId) return false;
    if (filters.scope === "My city" && (gym.city !== self.city || gym.state !== self.state)) return false;
    if (filters.scope === "My weight class" && weightClassFor(profile.bodyweight, profile.sex) !== selfClass) return false;
    if (filters.scope === "Selected gym" && filters.gym !== "All" && gym.name !== filters.gym) return false;
    if (filters.gym !== "All" && gym.name !== filters.gym) return false;
    if (filters.city !== "All" && `${gym.city}, ${gym.state}` !== filters.city) return false;
    if (filters.ageGroup !== "All" && profile.ageGroup !== filters.ageGroup) return false;
    if (filters.experienceLevel !== "All" && profile.experienceLevel !== filters.experienceLevel) return false;
    if (filters.weightClass !== "All" && weightClassFor(profile.bodyweight, profile.sex) !== filters.weightClass) return false;
    return true;
  });
}

const bestByExercise = (lifts: LiftSubmission[]) => {
  const result = new Map<string, LiftSubmission>();
  lifts.forEach((lift) => {
    const existing = result.get(lift.exerciseId);
    if (!existing || lift.normalizedWeight > existing.normalizedWeight) result.set(lift.exerciseId, lift);
  });
  return result;
};

function entryForProfile(
  state: TrackerState,
  profile: UserProfile,
  lifts: LiftSubmission[],
  rankingType: RankingType,
  exerciseFilter: string,
  repCount: number | null
): LeaderboardEntry | null {
  const gym = gymFor(state, profile.primaryGymId) ?? gymFor(state, lifts[0]?.gymId ?? "");
  if (!gym || !lifts.length) return null;
  const best = bestByExercise(lifts);
  const squat = best.get("back-squat")?.normalizedWeight ?? 0;
  const bench = best.get("barbell-bench")?.normalizedWeight ?? 0;
  const deadlift = best.get("deadlift")?.normalizedWeight ?? 0;
  const total = squat + bench + deadlift;
  const top = [...best.values()].sort((left, right) => right.normalizedWeight - left.normalizedWeight)[0];
  const selectedCandidates = lifts.filter((lift) =>
    (exerciseFilter === "All" || lift.exerciseName === exerciseFilter) &&
    (repCount === null || lift.reps === repCount)
  );
  const selected = selectedCandidates.sort((left, right) => right.normalizedWeight - left.normalizedWeight)[0] ?? (exerciseFilter === "All" && repCount === null ? top : undefined);
  if (!selected) return null;

  let score = total;
  let exercise = "Powerlifting Total";
  if (rankingType === "Absolute") {
    score = selected.normalizedWeight;
    exercise = selected.exerciseName;
  } else if (rankingType === "Pound-for-pound") {
    score = selected.normalizedWeight / profile.bodyweight;
    exercise = selected.exerciseName;
  } else if (rankingType === "Relative total") {
    score = total / profile.bodyweight;
  } else if (rankingType === "Most improved") {
    const sameExercise = lifts.filter((lift) => lift.exerciseId === selected.exerciseId).sort((a, b) => a.performedAt.localeCompare(b.performedAt));
    const first = sameExercise[0]?.normalizedWeight ?? selected.normalizedWeight;
    score = first > 0 ? ((selected.normalizedWeight - first) / first) * 100 : 0;
    exercise = selected.exerciseName;
  }

  return {
    id: `computed-${rankingType}-${profile.id}`,
    userId: profile.id,
    rank: 0,
    rankChange: profile.id.charCodeAt(profile.id.length - 1) % 5 - 2,
    athlete: profile.displayName,
    handle: profile.handle,
    gym: gym.name,
    city: gym.city,
    state: gym.state,
    exercise,
    rankingType,
    score,
    verification: selected.verification,
    bodyweight: profile.bodyweight,
    total,
    ageGroup: profile.ageGroup,
    experienceLevel: profile.experienceLevel,
    isCurrentUser: profile.id === state.currentUserId,
    weightClass: weightClassFor(profile.bodyweight, profile.sex),
    breakdown: { squat, bench, deadlift }
  };
}

export function computedLeaderboardEntries(
  state: TrackerState,
  filters: ComputedLeaderboardFilters
): LeaderboardEntry[] {
  const lifts = eligibleLifts(state, filters);
  const userIds = [...new Set(lifts.map((lift) => lift.userId))];
  return userIds
    .map((userId) => {
      const profile = state.profiles.find((item) => item.id === userId);
      return profile ? entryForProfile(state, profile, lifts.filter((lift) => lift.userId === userId), filters.rankingType, filters.exercise, filters.repCount) : null;
    })
    .filter((entry): entry is LeaderboardEntry => Boolean(entry))
    .sort((left, right) => right.score - left.score || left.athlete.localeCompare(right.athlete))
    .map((entry, index) => ({ ...entry, rank: index + 1 }));
}

export function plateLoadTotal(barWeight: number, platesPerSide: Array<{ weight: number; count: number }>): number {
  return barWeight + platesPerSide.reduce((total, plate) => total + plate.weight * plate.count * 2, 0);
}

export function areFriends(state: TrackerState, leftId: string, rightId: string): boolean {
  return state.friendRequests.some((request) =>
    request.status === "Accepted" &&
    ((request.senderId === leftId && request.recipientId === rightId) || (request.senderId === rightId && request.recipientId === leftId))
  );
}
