import Foundation

@MainActor
protocol AuthenticationService {
    var isConfigured: Bool { get }
    var isDemoMode: Bool { get }
    func restoreSession() async throws -> AccountSession?
    func signUp(email: String, password: String) async throws -> AccountSession
    func signIn(email: String, password: String) async throws -> AccountSession
    func requestPasswordReset(email: String) async throws
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession
    func signInDemo() async throws -> UserProfile
    func signOut() async throws
}

@MainActor
protocol ProfileService {
    func currentProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func authenticatedProfile() async throws -> AuthenticatedProfile
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile
    func claimUsername(_ username: String) async throws -> String
    func profileCard(userID: UUID) async throws -> PublicProfileCard
}

@MainActor
protocol LiftService {
    func submissions() async throws -> [LiftSubmission]
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission
    func vote(liftID: UUID, vote: CommunityVote?) async throws
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws
}

@MainActor
protocol LeaderboardService {
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry]
}

@MainActor
protocol GymService {
    func gyms() async throws -> [Gym]
    func memberships() async throws -> [GymMembershipRecord]
}

@MainActor
protocol SocialService {
    func feed() async throws -> [ActivityItem]
    func block(userID: UUID) async throws
    func unblock(userID: UUID) async throws
    func blocks() async throws -> [UserBlockRecord]
}

@MainActor
protocol CommunityService {
    func communities() async throws -> [ForumCommunity]
    func posts(in destination: ForumDestination?) async throws -> [ForumPost]
    func comments(for post: ForumPost) async throws -> [ForumComment]
    func join(community: ForumCommunity, note: String) async throws -> ForumMembershipStatus?
    func leave(community: ForumCommunity) async throws
    func createPost(_ post: ForumPost) async throws -> Bool
    func addComment(to post: ForumPost, parentCommentID: UUID?, body: String) async throws -> ForumComment?
    func vote(post: ForumPost, vote: CommunityVote?) async throws
    func vote(comment: ForumComment, vote: CommunityVote?) async throws
    func toggleSaved(post: ForumPost) async throws
    func toggleWatched(post: ForumPost) async throws
    func vote(pollPost: ForumPost, optionID: UUID) async throws
    func report(targetType: ForumReportTargetType, targetID: UUID, communityID: UUID?, reason: CommunityReportReason, note: String) async throws -> Bool
    func moderate(post: ForumPost, action: ForumModerationActionKind, reason: String) async throws

    // Legacy thread methods remain available for local migration compatibility.
    func threads() async throws -> [CommunityThread]
    func replies(for thread: CommunityThread) async throws -> [CommunityThreadReply]
    func createThread(_ thread: CommunityThread) async throws -> CommunityThread
    func addReply(to thread: CommunityThread, body: String) async throws -> CommunityThreadReply?
    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) async throws
    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) async throws
    func report(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) async throws
    func moderate(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String?) async throws
}

@MainActor
protocol MessagingService {
    func createOrGetThread(with userID: UUID) async throws -> DirectMessageThread
    func threads() async throws -> [DirectMessageThread]
    func messages(for thread: DirectMessageThread) async throws -> [DirectMessage]
    func sendMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessage?
    func deleteMessage(_ message: DirectMessage) async throws
    func deleteThread(_ thread: DirectMessageThread) async throws
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws
}

@MainActor
protocol GymMembershipService {
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool
    func leave(_ gym: Gym) async throws
    func setPrimary(_ gym: Gym) async throws
}

@MainActor
protocol FriendRelationshipService {
    func relationships() async throws -> [FriendRelationshipRecord]
    func request(userID: UUID) async throws
    func respond(relationshipID: UUID, accept: Bool) async throws
    func cancel(relationshipID: UUID) async throws
    func remove(relationshipID: UUID) async throws
}

@MainActor
protocol ExerciseCatalogService {
    func activeExercises() async throws -> [CatalogExercise]
    func resolve(identifier: String) async throws -> CatalogExercise?
}

@MainActor
protocol VerificationService {
    func pendingSubmissions() async throws -> [LiftSubmission]
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission
}

@MainActor
protocol MediaUploadService {
    func upload(localURL: URL?) async throws -> URL?
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset
    func signedPlaybackURL(assetID: UUID) async throws -> URL
}

@MainActor
protocol NotificationService {
    func notifications() async throws -> [NotificationItem]
    func markRead(notificationID: UUID) async throws
    func registerDevice(_ registration: PushDeviceRegistration) async throws
    func revokeDevice(deviceID: String) async throws
}

@MainActor
protocol WorkoutSyncService {
    func plans() async throws -> [WorkoutPlanDocument]
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult
    func deletePlan(id: UUID) async throws
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot]
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws
}

@MainActor
protocol AnalyticsService {
    func track(_ event: AnalyticsEventRecord) async
}

@MainActor
protocol LegalAcceptanceService {
    func acceptances() async throws -> [LegalAcceptanceRecord]
    func accept(documents: [LegalDocument]) async throws
}

@MainActor
protocol AccountDeletionService {
    /// The server function requires a recently authenticated JWT and performs
    /// cascading cleanup plus Auth deletion atomically.
    func deleteAccount() async throws
}

// Additive defaults keep lightweight previews and focused test doubles source
// compatible while production implementations override every launch method.
extension AuthenticationService {
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
}
extension LiftService {
    func vote(liftID: UUID, vote: CommunityVote?) async throws { throw LiftRankServiceError.configurationMissing }
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws { throw LiftRankServiceError.configurationMissing }
}
extension SocialService {
    func block(userID: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func unblock(userID: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func blocks() async throws -> [UserBlockRecord] { [] }
}
extension VerificationService {
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission { throw LiftRankServiceError.configurationMissing }
}
extension MediaUploadService {
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset { throw LiftRankServiceError.configurationMissing }
    func signedPlaybackURL(assetID: UUID) async throws -> URL { throw LiftRankServiceError.configurationMissing }
}
extension NotificationService {
    func markRead(notificationID: UUID) async throws {}
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func revokeDevice(deviceID: String) async throws {}
}
