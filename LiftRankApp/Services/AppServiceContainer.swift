import Foundation
import Supabase

@MainActor
struct AppServiceContainer {
    let authentication: any AuthenticationService
    let profile: any ProfileService
    let gyms: any GymService
    let gymMemberships: any GymMembershipService
    let friendships: any FriendRelationshipService
    let exercises: any ExerciseCatalogService
    let lifts: any LiftService
    let leaderboards: any LeaderboardService
    let social: any SocialService
    let communities: any CommunityService
    let messaging: any MessagingService
    let verification: any VerificationService
    let media: any MediaUploadService
    let notifications: any NotificationService
    let workoutSync: any WorkoutSyncService
    let analytics: any AnalyticsService
    let accountDeletion: any AccountDeletionService

    init(
        authentication: any AuthenticationService,
        profile: any ProfileService,
        gyms: any GymService,
        gymMemberships: any GymMembershipService,
        friendships: any FriendRelationshipService,
        exercises: any ExerciseCatalogService,
        lifts: (any LiftService)? = nil,
        leaderboards: (any LeaderboardService)? = nil,
        social: (any SocialService)? = nil,
        communities: (any CommunityService)? = nil,
        messaging: (any MessagingService)? = nil,
        verification: (any VerificationService)? = nil,
        media: (any MediaUploadService)? = nil,
        notifications: (any NotificationService)? = nil,
        workoutSync: (any WorkoutSyncService)? = nil,
        analytics: (any AnalyticsService)? = nil,
        accountDeletion: (any AccountDeletionService)? = nil
    ) {
        let unavailable = UnavailableLaunchService()
        self.authentication = authentication; self.profile = profile; self.gyms = gyms
        self.gymMemberships = gymMemberships; self.friendships = friendships; self.exercises = exercises
        self.lifts = lifts ?? unavailable; self.leaderboards = leaderboards ?? unavailable
        self.social = social ?? unavailable; self.communities = communities ?? unavailable
        self.messaging = messaging ?? UnavailableMessagingService(); self.verification = verification ?? unavailable
        self.media = media ?? unavailable; self.notifications = notifications ?? unavailable
        self.workoutSync = workoutSync ?? unavailable; self.analytics = analytics ?? unavailable
        self.accountDeletion = accountDeletion ?? unavailable
    }

    static func make(repository: DemoRepository) -> AppServiceContainer {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .demo(repository: repository)
        }
#endif
        guard let configuration = SupabaseConfiguration.load() else {
            let unavailable = UnavailableLaunchService()
            let unavailableMessaging = UnavailableMessagingService()
            return AppServiceContainer(
                authentication: UnconfiguredAuthenticationService(repository: repository),
                profile: MockProfileService(repository: repository),
                gyms: MockGymService(repository: repository),
                gymMemberships: MockGymMembershipService(repository: repository),
                friendships: MockFriendRelationshipService(repository: repository),
                exercises: MockExerciseCatalogService()
                , lifts: unavailable, leaderboards: unavailable,
                social: unavailable, communities: unavailable, messaging: unavailableMessaging,
                verification: unavailable, media: unavailable, notifications: unavailable,
                workoutSync: unavailable, analytics: unavailable, accountDeletion: unavailable
            )
        }

        let client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publicKey)
        return AppServiceContainer(
            authentication: SupabaseAuthenticationService(client: client),
            profile: SupabaseProfileService(client: client),
            gyms: SupabaseGymService(client: client),
            gymMemberships: SupabaseGymMembershipService(client: client),
            friendships: SupabaseFriendRelationshipService(client: client),
            exercises: SupabaseExerciseCatalogService(client: client)
            , lifts: SupabaseLiftService(client: client), leaderboards: SupabaseLeaderboardService(client: client),
            social: SupabaseSocialService(client: client), communities: SupabaseCommunityService(client: client), messaging: SupabaseMessagingService(client: client),
            verification: SupabaseVerificationService(client: client), media: SupabaseMediaUploadService(client: client), notifications: SupabaseNotificationService(client: client),
            workoutSync: SupabaseWorkoutSyncService(client: client), analytics: SupabaseAnalyticsService(client: client), accountDeletion: SupabaseAccountDeletionService(client: client)
        )
    }

    static func demo(repository: DemoRepository) -> AppServiceContainer {
        AppServiceContainer(
            authentication: MockAuthenticationService(repository: repository),
            profile: MockProfileService(repository: repository),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            friendships: MockFriendRelationshipService(repository: repository),
            exercises: MockExerciseCatalogService()
            , lifts: MockLiftService(repository: repository), leaderboards: MockLeaderboardService(repository: repository),
            social: MockSocialService(repository: repository), communities: MockCommunityService(repository: repository), messaging: MockMessagingService(repository: repository),
            verification: MockVerificationService(repository: repository), media: MockMediaUploadService(), notifications: MockNotificationService(repository: repository),
            workoutSync: MockWorkoutSyncService(), analytics: MockAnalyticsService(), accountDeletion: MockAccountDeletionService()
        )
    }
}

/// Production features fail explicitly when configuration is absent. This keeps
/// release builds from silently presenting seeded users, rankings, or messages.
@MainActor
final class UnavailableLaunchService: LiftService, LeaderboardService, SocialService, CommunityService, VerificationService, MediaUploadService, NotificationService, WorkoutSyncService, AnalyticsService, AccountDeletionService {
    private var error: LiftRankServiceError { .configurationMissing }
    func submissions() async throws -> [LiftSubmission] { throw error }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission { throw error }
    func vote(liftID: UUID, vote: CommunityVote?) async throws { throw error }
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws { throw error }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] { throw error }
    func feed() async throws -> [ActivityItem] { throw error }
    func block(userID: UUID) async throws { throw error }
    func unblock(userID: UUID) async throws { throw error }
    func blocks() async throws -> [UserBlockRecord] { throw error }
    func communities() async throws -> [ForumCommunity] { throw error }
    func posts(in destination: ForumDestination?) async throws -> [ForumPost] { throw error }
    func comments(for post: ForumPost) async throws -> [ForumComment] { throw error }
    func join(community: ForumCommunity, note: String) async throws -> ForumMembershipStatus? { throw error }
    func leave(community: ForumCommunity) async throws { throw error }
    func createPost(_ post: ForumPost) async throws -> Bool { throw error }
    func addComment(to post: ForumPost, parentCommentID: UUID?, body: String) async throws -> ForumComment? { throw error }
    func vote(post: ForumPost, vote: CommunityVote?) async throws { throw error }
    func vote(comment: ForumComment, vote: CommunityVote?) async throws { throw error }
    func toggleSaved(post: ForumPost) async throws { throw error }
    func toggleWatched(post: ForumPost) async throws { throw error }
    func vote(pollPost: ForumPost, optionID: UUID) async throws { throw error }
    func report(targetType: ForumReportTargetType, targetID: UUID, communityID: UUID?, reason: CommunityReportReason, note: String) async throws -> Bool { throw error }
    func moderate(post: ForumPost, action: ForumModerationActionKind, reason: String) async throws { throw error }
    func threads() async throws -> [CommunityThread] { throw error }
    func replies(for thread: CommunityThread) async throws -> [CommunityThreadReply] { throw error }
    func createThread(_ thread: CommunityThread) async throws -> CommunityThread { throw error }
    func addReply(to thread: CommunityThread, body: String) async throws -> CommunityThreadReply? { throw error }
    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) async throws { throw error }
    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) async throws { throw error }
    func report(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) async throws { throw error }
    func moderate(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String?) async throws { throw error }
    func pendingSubmissions() async throws -> [LiftSubmission] { throw error }
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission { throw error }
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission { throw error }
    func upload(localURL: URL?) async throws -> URL? { throw error }
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset { throw error }
    func signedPlaybackURL(assetID: UUID) async throws -> URL { throw error }
    func notifications() async throws -> [NotificationItem] { throw error }
    func markRead(notificationID: UUID) async throws { throw error }
    func registerDevice(_ registration: PushDeviceRegistration) async throws { throw error }
    func revokeDevice(deviceID: String) async throws { throw error }
    func plans() async throws -> [WorkoutPlanDocument] { throw error }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult { throw error }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { throw error }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws { throw error }
    func track(_ event: AnalyticsEventRecord) async {}
    func deleteAccount() async throws { throw error }
}

@MainActor
final class UnavailableMessagingService: MessagingService {
    private var error: LiftRankServiceError { .configurationMissing }
    func threads() async throws -> [DirectMessageThread] { throw error }
    func messages(for thread: DirectMessageThread) async throws -> [DirectMessage] { throw error }
    func sendMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessage? { throw error }
    func deleteMessage(_ message: DirectMessage) async throws { throw error }
    func deleteThread(_ thread: DirectMessageThread) async throws { throw error }
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws { throw error }
}

@MainActor
final class UnconfiguredAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
    var isConfigured: Bool { false }
    var isDemoMode: Bool { false }
    init(repository: DemoRepository) { self.repository = repository }
    func restoreSession() async throws -> AccountSession? { nil }
    func signUp(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func signIn(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func requestPasswordReset(email: String) async throws { throw LiftRankServiceError.configurationMissing }
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func signInDemo() async throws -> UserProfile { repository.currentProfile }
    func signOut() async throws {}
}
