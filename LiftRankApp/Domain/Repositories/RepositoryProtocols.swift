import Combine
import Foundation

@MainActor
protocol ActiveWorkoutRepository: AnyObject {
    var activeWorkout: ActiveWorkoutState? { get }
    var workoutSetLogs: [WorkoutSetLog] { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var workoutPreferences: WorkoutPreferences { get set }

    @discardableResult
    func startWorkout(
        session: WorkoutSession,
        planID: UUID?,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem,
        at startedAt: Date
    ) -> ActiveWorkoutState?

    @discardableResult
    func startFreestyleWorkout(
        name: String,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem,
        at startedAt: Date
    ) -> ActiveWorkoutState?

    func pauseActiveWorkout(at date: Date)
    func resumeActiveWorkout(at date: Date)
    func updateActiveRestTimer(endsAt: Date?, exerciseID: UUID?)
    func discardActiveWorkout()
    func deleteCompletedWorkout(_ workout: CompletedWorkout)
    func removeExerciseFromActiveWorkout(_ exercise: WorkoutExerciseSnapshot)
    func setAutomaticRestTimerEnabledForActiveWorkout(_ enabled: Bool)
    func updateWorkoutSetLog(_ log: WorkoutSetLog)

    @discardableResult
    func addWorkoutSetLog(
        prescriptionID: UUID,
        setNumber: Int?,
        workoutID: UUID?,
        unit: UnitSystem
    ) -> WorkoutSetLog

    func deleteWorkoutSetLog(_ log: WorkoutSetLog)
    func addExercisesToActiveWorkout(_ exercises: [TrainingExerciseCatalogItem])

    @discardableResult
    func substituteActiveWorkoutExercise(
        currentExerciseID: UUID,
        substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot?

    @discardableResult
    func updateSourcePlanFromActiveWorkout() -> Bool

    @discardableResult
    func finishActiveWorkout(effort: Int, notes: String, at completedAt: Date) -> CompletedWorkout?

    @discardableResult
    func reorderActiveWorkout(exerciseIDs: [UUID]) -> Bool

    @discardableResult
    func moveActiveWorkoutExercise(_ exerciseID: UUID, direction: Int) -> Bool

    @discardableResult
    func applyWorkoutSetCompletion(
        logID: UUID,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> WorkoutSetLog?

    func persistWorkoutSnapshot()
}

@MainActor
protocol ProgramRepository: AnyObject {
    var workoutPlans: [WorkoutPlan] { get }
    var workoutPhases: [WorkoutPhase] { get }
    var workoutWeeks: [WorkoutWeek] { get }
    var workoutSessions: [WorkoutSession] { get }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get }

    func currentProgramWeek(planID: UUID, at date: Date) -> WorkoutWeek?
    func addWorkoutPlan(_ plan: WorkoutPlan)
    func updateWorkoutPlan(_ plan: WorkoutPlan)
    func duplicateWorkoutPlan(_ plan: WorkoutPlan) -> WorkoutPlan
    func deleteWorkoutPlan(_ plan: WorkoutPlan)

    @discardableResult
    func addWorkoutWeek(planID: UUID, phaseID: UUID?, title: String?) -> WorkoutWeek
    func cloneWorkoutWeek(_ week: WorkoutWeek) -> WorkoutWeek
    func deleteWorkoutWeek(_ week: WorkoutWeek)

    @discardableResult
    func addWorkoutSession(weekID: UUID, day: String, name: String) -> WorkoutSession
    func deleteWorkoutSession(_ session: WorkoutSession)
    func cancelWorkoutSession(_ session: WorkoutSession)

    @discardableResult
    func addWorkoutPrescription(_ prescription: WorkoutExercisePrescription) -> WorkoutExercisePrescription
    func deleteWorkoutPrescription(_ prescription: WorkoutExercisePrescription)

    @discardableResult
    func startWorkoutProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        preferredUnit: UnitSystem,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan

    @discardableResult
    func changeWorkoutProgramProgression(
        planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double],
        at date: Date
    ) -> Bool
}

@MainActor
protocol TrainingProgressRepository: AnyObject {
    var workoutWeeks: [WorkoutWeek] { get }
    var workoutSessions: [WorkoutSession] { get }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get }
    var workoutSetLogs: [WorkoutSetLog] { get }
    var workoutEntries: [WorkoutExerciseEntry] { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var bodyweightEntries: [BodyweightEntry] { get }
    var strainEntries: [StrainEntry] { get }
    var injuryEntries: [InjuryEntry] { get }

    func updateBodyweight(_ entry: BodyweightEntry)
    func updateStrainEntry(_ entry: StrainEntry)
    func deleteStrainEntry(_ entryID: UUID)
    func updateInjuryEntry(_ entry: InjuryEntry)
    func deleteInjuryEntry(_ entryID: UUID)
}

@MainActor
protocol ExerciseRepository: AnyObject {
    var customTrainingExercises: [TrainingExerciseCatalogItem] { get }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem)
}

@MainActor
protocol CompetitionRepository: AnyObject {
    var lifts: [LiftSubmission] { get set }
    var profiles: [UserProfile] { get }
    var currentProfile: UserProfile { get }
    var joinedGymIDs: Set<UUID> { get }
    func refreshAchievementUnlocks(now: Date)
}

@MainActor
protocol CommunityRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var activities: [ActivityItem] { get set }
    var activityComments: [ActivityComment] { get }
    var communityThreads: [CommunityThread] { get }
    var communityThreadReplies: [CommunityThreadReply] { get }
    var communityReports: [CommunityReport] { get }
    var forumCommunities: [ForumCommunity] { get set }
    var forumMemberships: [ForumMembership] { get set }
    var forumPosts: [ForumPost] { get set }
    var forumComments: [ForumComment] { get set }
    var forumJoinRequests: [ForumJoinRequest] { get }
    var forumReports: [ForumReport] { get }
    var forumModerationActions: [ForumModerationAction] { get }
    var forumNotifications: [ForumNotification] { get }

    func replaceActivityComments(for activityID: UUID, with comments: [ActivityComment])
    func appendActivityComment(_ comment: ActivityComment)
    func visibleForumCommunities(for userID: UUID?) -> [ForumCommunity]
    func forumMembership(communityID: UUID, userID: UUID?) -> ForumMembership?
    func isForumStaff(_ userID: UUID?) -> Bool
    func canReadForumCommunity(_ communityID: UUID, userID: UUID?) -> Bool
    func canContributeToForumCommunity(_ communityID: UUID, userID: UUID?) -> Bool
    func canModerateForumCommunity(_ communityID: UUID, userID: UUID?) -> Bool
    func setForumCommunityArchived(_ communityID: UUID, archived: Bool)
    func joinForumCommunity(_ communityID: UUID, note: String) -> ForumMembershipStatus?
    func leaveForumCommunity(_ communityID: UUID)
    func setForumNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID)
    func createForumPost(_ post: ForumPost) -> Bool
    func voteForumPost(_ postID: UUID, vote: CommunityVote?)
    func toggleForumPostSaved(_ postID: UUID)
    func toggleForumPostWatched(_ postID: UUID)
    func voteInForumPoll(postID: UUID, optionID: UUID)
    func addForumComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment?
    func voteForumComment(_ commentID: UUID, vote: CommunityVote?)
    func softDeleteForumPost(_ postID: UUID)
    func updateForumPost(_ post: ForumPost)
    func softDeleteForumComment(_ commentID: UUID)
    func reportForumContent(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String
    ) -> Bool
    func moderateForumPost(_ postID: UUID, action: ForumModerationActionKind, reason: String)
    func moderateForumComment(_ commentID: UUID, action: ForumModerationActionKind, reason: String)
    func resolveForumReport(_ reportID: UUID, dismiss: Bool)
    func resolveForumJoinRequest(_ requestID: UUID, approved: Bool)
    func markForumNotificationRead(_ notificationID: UUID)
}

@MainActor
protocol SocialMessagingRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var profiles: [UserProfile] { get }
    var friendRequests: [FriendRequest] { get }
    var messageThreads: [DirectMessageThread] { get set }
    var directMessages: [DirectMessage] { get set }
    var socialMessagingChanges: AnyPublisher<Void, Never> { get }

    func sendFriendRequest(to profile: UserProfile)
    func cancelFriendRequest(_ request: FriendRequest)
    func respondToFriendRequest(_ request: FriendRequest, status: FriendRequestStatus)
    func messageThread(with profile: UserProfile) -> DirectMessageThread
    func addMessage(to thread: DirectMessageThread, body: String)
    func deleteMessage(_ message: DirectMessage)
    func deleteMessageThread(_ thread: DirectMessageThread)
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String)
}

@MainActor
protocol ProfileRepository: AnyObject {
    var currentProfile: UserProfile { get set }
    var profiles: [UserProfile] { get set }
    var gyms: [Gym] { get set }
    var joinedGymIDs: Set<UUID> { get set }
    var profileChanges: AnyPublisher<Void, Never> { get }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool
    func leaveGym(_ gym: Gym)
}

@MainActor
protocol NotificationRepository: AnyObject {
    var notifications: [NotificationItem] { get set }
    var forumPosts: [ForumPost] { get }
    var communityThreads: [CommunityThread] { get }
    var notificationChanges: AnyPublisher<Void, Never> { get }
}

@MainActor
protocol WorkoutRepository: ActiveWorkoutRepository, TrainingProgressRepository {}

@MainActor
protocol WorkoutSyncRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot] { get set }
    var deletedCompletedWorkoutIDs: Set<UUID> { get set }
    var completedWorkouts: [CompletedWorkout] { get set }
    var workoutPlans: [WorkoutPlan] { get set }
    var workoutPhases: [WorkoutPhase] { get set }
    var workoutWeeks: [WorkoutWeek] { get set }
    var workoutSessions: [WorkoutSession] { get set }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get set }
    var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings] { get set }
    var workoutPlanSyncRevisions: [UUID: Int] { get set }
    var workoutPlanLastSyncedPayloads: [UUID: Data] { get set }

    func persistWorkoutSnapshot()
}

@MainActor
protocol WorkoutPRSubmissionRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission] { get }
    var workoutPreferences: WorkoutPreferences { get set }

    func upsertPendingPRSubmission(_ pending: PendingWorkoutPRSubmission)
    func linkSubmission(_ submissionID: UUID, to workoutID: UUID)
    func persistWorkoutSnapshot()
}

@MainActor
protocol AccountSocialRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var friendRequests: [FriendRequest] { get set }
    var activities: [ActivityItem] { get set }
    var forumPosts: [ForumPost] { get set }
    var forumComments: [ForumComment] { get set }
    var messageThreads: [DirectMessageThread] { get set }
}
