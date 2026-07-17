export type TrackingType = "Weight + Reps" | "Reps Only" | "Time";

export interface Exercise {
  id: string;
  name: string;
  bodyPart: string;
  secondaryMuscles: string[];
  equipment: string;
  movementType: string;
  trackingType: TrackingType;
  isCustom?: boolean;
  searchAliases?: string[];
  bodyRegions?: string[];
}

export interface WorkoutPlan {
  id: string;
  name: string;
  goal: string;
  notes: string;
  createdAt: string;
  isActive: boolean;
  sourceTemplateId?: string;
  sourceTemplateVersion?: number;
}

export type ProgramCategory = "General" | "Bodybuilding" | "Powerlifting";
export type ProgramLevel = "Beginner" | "Intermediate";
export type ProgramProgressionMethod = "RIR + Rep Range" | "Percentage" | "Fixed Sets + Reps";

export interface ProgramExerciseTemplate {
  exerciseId: string;
  sets: number;
  reps: string;
  restSeconds: number;
  notes?: string;
  substitutionExerciseIds: string[];
}

export interface ProgramSessionTemplate {
  day: string;
  name: string;
  exercises: ProgramExerciseTemplate[];
}

export interface WorkoutProgramTemplate {
  id: string;
  version: number;
  name: string;
  summary: string;
  category: ProgramCategory;
  level: ProgramLevel;
  durationWeeks: 12;
  daysPerWeek: number;
  progressionMethod: ProgramProgressionMethod;
  sessions: ProgramSessionTemplate[];
}

export interface WorkoutPhase {
  id: string;
  planId: string;
  name: string;
  order: number;
  goal: string;
  durationWeeks: number;
}

export interface WorkoutWeek {
  id: string;
  planId: string;
  phaseId: string;
  weekNumber: number;
  title: string;
  notes: string;
}

export interface WorkoutSession {
  id: string;
  weekId: string;
  day: string;
  name: string;
  order: number;
  notes: string;
  isFreestyle?: boolean;
}

export interface ExercisePrescription {
  id: string;
  sessionId: string;
  exerciseId: string;
  exerciseName: string;
  bodyPart: string;
  equipment: string;
  sets: number;
  reps: string;
  restSeconds: number;
  order: number;
  notes: string;
}

export interface WorkoutSetLog {
  id: string;
  prescriptionId: string;
  setNumber: number;
  weight: number | null;
  reps: number | null;
  rpe: number | null;
  isWarmup: boolean;
  isComplete: boolean;
  performedAt: string;
}

export interface ActiveWorkout {
  sessionId: string;
  startedAt: string;
  pausedAt: string | null;
  pausedSeconds: number;
  exerciseOrder: string[];
  exerciseOverrides: Record<string, ActiveWorkoutExerciseOverride>;
  restOverrides: Record<string, number>;
}

export interface ActiveWorkoutExerciseOverride {
  originalExerciseId: string;
  originalExerciseName: string;
  exerciseId: string;
  exerciseName: string;
  bodyPart: string;
  equipment: string;
  substitutedAt: string;
}

export interface WorkoutSummary {
  completedExercises: number;
  totalExercises: number;
  totalSets: number;
  totalVolume: number;
  bestSet: WorkoutSetLog | null;
}

export interface CompletedWorkoutSession extends WorkoutSummary {
  id: string;
  sessionId: string;
  planId: string;
  weekId: string;
  name: string;
  completedAt: string;
  durationSeconds: number;
  setLogs: WorkoutSetLog[];
  prescriptions: ExercisePrescription[];
}

export interface BodyweightEntry {
  id: string;
  recordedAt: string;
  weight: number;
  notes?: string;
}

export type UnitSystem = "lb" | "kg";
export type SexCategory = "Male" | "Female";
export type LiftVisibility = "Public" | "Friends" | "Private";
export type EquipmentType = "Raw" | "Wraps" | "Equipped";

export interface UserProfile {
  id: string;
  displayName: string;
  handle: string;
  ageGroup: string;
  experienceLevel: string;
  unitSystem: UnitSystem;
  sex: SexCategory;
  bodyweight: number;
  primaryGymId: string;
  city: string;
  state: string;
  bio: string;
  discipline: string;
  trainingGoal: string;
  yearsTraining: number;
  federation: string;
  preferredEquipment: EquipmentType;
  role: "Member" | "Moderator" | "Admin";
  professionalCredential?: string;
  credentialVerified: boolean;
  hideGym: boolean;
  hideLocation: boolean;
  hideAge: boolean;
}

export interface Gym {
  id: string;
  brand: string;
  name: string;
  address: string;
  city: string;
  state: string;
  postalCode: string;
  countryCode: "US";
  memberCount?: number;
  verifiedLiftCount?: number;
  officialUrl: string;
}

export interface PlateLoad {
  barWeight: number;
  platesPerSide: Array<{ weight: number; count: number }>;
}

export interface LiftSubmission {
  id: string;
  userId: string;
  exerciseId: string;
  exerciseName: string;
  weight: number;
  unit: UnitSystem;
  normalizedWeight: number;
  reps: number;
  bodyweight: number;
  performedAt: string;
  submittedAt: string;
  leaderboardEligibleAt: string;
  gymId: string;
  equipment: EquipmentType;
  visibility: LiftVisibility;
  verification: VerificationLevel;
  caption: string;
  videoUrl?: string;
  plateLoad?: PlateLoad;
}

export interface WorkoutFeedback {
  id: string;
  sessionId: string;
  effort: number;
  notes: string;
  shared: boolean;
  createdAt: string;
}

export type CommunityPostKind = "Discussion" | "Lift" | "Workout" | "PR" | "Gym" | "Question" | "Form Check" | "Program Review" | "Progress" | "Nutrition" | "Equipment" | "Personal Record";
export type CommunityVote = -1 | 1;
export type CommunityReportReason = "Dangerous advice" | "Eating-disorder content" | "Harassment" | "Misinformation" | "Spam" | "Unsafe supplements" | "Other";

export interface TrainingGroup {
  id: string;
  name: string;
  description: string;
  rules: string[];
  memberIds: string[];
  moderatorIds: string[];
}

export interface PostTrainingDetails {
  exercise?: string;
  sets?: number;
  reps?: number;
  weight?: number;
  unit?: UnitSystem;
  rpe?: number;
  feedbackRequest?: string;
  programName?: string;
  durationWeeks?: number;
  rating?: number;
}

export interface CommunityPost {
  id: string;
  authorId: string;
  kind: CommunityPostKind;
  groupId: string;
  title: string;
  body: string;
  createdAt: string;
  linkedLiftId?: string;
  linkedWorkoutId?: string;
  gymId?: string;
  likedBy: string[];
  votes: Record<string, CommunityVote>;
  savedBy: string[];
  exerciseTags: string[];
  goalTags: string[];
  mediaUrl?: string;
  mediaType?: "Image" | "Video";
  trainingDetails?: PostTrainingDetails;
  isLocked: boolean;
  removedAt?: string;
  removalReason?: string;
  warning?: string;
}

export interface Comment {
  id: string;
  postId: string;
  authorId: string;
  parentCommentId?: string;
  body: string;
  createdAt: string;
  editedAt?: string;
  deletedAt?: string;
  removedAt?: string;
  votes: Record<string, CommunityVote>;
}

export interface CommunityReport {
  id: string;
  targetType: "Post" | "Comment";
  targetId: string;
  reporterId: string;
  reason: CommunityReportReason;
  note: string;
  status: "Open" | "Resolved";
  createdAt: string;
}

export interface GroupBan {
  id: string;
  groupId: string;
  userId: string;
  moderatorId: string;
  reason: string;
  createdAt: string;
}

export type FriendRequestStatus = "Pending" | "Accepted" | "Declined";

export interface FriendRequest {
  id: string;
  senderId: string;
  recipientId: string;
  status: FriendRequestStatus;
  createdAt: string;
}

export interface MessageThread {
  id: string;
  participantIds: string[];
  createdAt: string;
  updatedAt: string;
}

export interface Message {
  id: string;
  threadId: string;
  senderId: string;
  body: string;
  createdAt: string;
  isRead: boolean;
  isReported: boolean;
}

export type MessageReportReason = "Spam" | "Offensive" | "Harassment" | "Other";

export interface MessageReport {
  id: string;
  messageId: string;
  reporterId: string;
  reason: MessageReportReason;
  note: string;
  createdAt: string;
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  kind: "Ranking" | "Lift" | "Verification" | "Friend" | "Message" | "Gym" | "Forum" | "Achievement" | "Workout" | "WorkoutReminder";
  target: string;
  createdAt: string;
  isRead: boolean;
}

export type RankingType =
  | "Absolute"
  | "Pound-for-pound"
  | "Total"
  | "Relative total"
  | "Most improved";

export type VerificationLevel =
  | "Self Reported"
  | "Video Submitted"
  | "Video Verified"
  | "Community Verified"
  | "Competition Verified";

export type LeaderboardScope = "Global" | "My gym" | "My city" | "My weight class" | "Selected gym";

export interface LeaderboardEntry {
  id: string;
  rank: number;
  rankChange: number;
  athlete: string;
  handle: string;
  gym: string;
  city: string;
  state: string;
  exercise: string;
  rankingType: RankingType;
  score: number;
  verification: VerificationLevel;
  bodyweight: number;
  total: number;
  ageGroup: string;
  experienceLevel: string;
  isCurrentUser?: boolean;
  userId?: string;
  weightClass?: string;
  breakdown?: { squat: number; bench: number; deadlift: number };
}

export interface TrackerState {
  version: 4;
  plans: WorkoutPlan[];
  phases: WorkoutPhase[];
  weeks: WorkoutWeek[];
  sessions: WorkoutSession[];
  prescriptions: ExercisePrescription[];
  setLogs: WorkoutSetLog[];
  completedWorkouts: CompletedWorkoutSession[];
  exercises: Exercise[];
  bodyweight: BodyweightEntry[];
  activePlanId: string;
  activeWorkout: ActiveWorkout | null;
  currentUserId: string;
  profiles: UserProfile[];
  gyms: Gym[];
  joinedGymIds: string[];
  liftSubmissions: LiftSubmission[];
  workoutFeedback: WorkoutFeedback[];
  communityPosts: CommunityPost[];
  comments: Comment[];
  trainingGroups: TrainingGroup[];
  joinedGroupIds: string[];
  communityReports: CommunityReport[];
  groupBans: GroupBan[];
  friendRequests: FriendRequest[];
  messageThreads: MessageThread[];
  messages: Message[];
  messageReports: MessageReport[];
  notifications: NotificationItem[];
}
