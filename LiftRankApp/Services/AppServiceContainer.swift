import Foundation
import Supabase

struct FeatureAvailability: Equatable, Sendable {
    let pushNotifications: Bool
    let advertising: Bool

    static let focusedProduction = FeatureAvailability(
        pushNotifications: true,
        advertising: false
    )

    static let internalFull = FeatureAvailability(
        pushNotifications: true,
        advertising: false
    )

    static let deferredFeaturesLaunchArgument = "-enableDeferredFeatures"

    static func resolved(
        for environment: LiftRankBackendEnvironment?,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> FeatureAvailability {
        if environment == .production { return .focusedProduction }
#if DEBUG
        let environmentOverride = processEnvironment["LIFTRANK_ENABLE_DEFERRED_FEATURES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let hasEnvironmentOverride = environmentOverride.map {
            ["1", "true", "yes"].contains($0)
        } ?? false
        if arguments.contains(deferredFeaturesLaunchArgument) || hasEnvironmentOverride {
            return .internalFull
        }
#endif
        return .focusedProduction
    }
}

@MainActor
struct AppServiceContainer {
    let features: FeatureAvailability
    let authentication: any AuthenticationService
    let profile: any ProfileService
    let locations: any LocationService
    let gyms: any GymService
    let gymMemberships: any GymMembershipService
    let exercises: any ExerciseCatalogService
    let lifts: any LiftService
    let leaderboards: any LeaderboardService
    let social: any SocialService
    let verification: any VerificationService
    let media: any MediaUploadService
    let notifications: any NotificationService
    let workoutSync: any WorkoutSyncService
    let analytics: any AnalyticsService
    let legalAcceptances: any LegalAcceptanceService
    let accountDeletion: any AccountDeletionService

    init(
        features: FeatureAvailability = .resolved(for: nil),
        authentication: any AuthenticationService,
        profile: any ProfileService,
        locations: (any LocationService)? = nil,
        gyms: any GymService,
        gymMemberships: any GymMembershipService,
        exercises: any ExerciseCatalogService,
        lifts: (any LiftService)? = nil,
        leaderboards: (any LeaderboardService)? = nil,
        social: (any SocialService)? = nil,
        verification: (any VerificationService)? = nil,
        media: (any MediaUploadService)? = nil,
        notifications: (any NotificationService)? = nil,
        workoutSync: (any WorkoutSyncService)? = nil,
        analytics: (any AnalyticsService)? = nil,
        legalAcceptances: (any LegalAcceptanceService)? = nil,
        accountDeletion: (any AccountDeletionService)? = nil
    ) {
        let unavailable = UnavailableLaunchService()
        self.features = features
        self.authentication = authentication; self.profile = profile
        self.locations = locations ?? BundledLocationService()
        self.gyms = gyms
        self.gymMemberships = gymMemberships; self.exercises = exercises
        self.lifts = lifts ?? unavailable; self.leaderboards = leaderboards ?? unavailable
        self.social = social ?? unavailable; self.verification = verification ?? unavailable
        self.media = media ?? unavailable; self.notifications = notifications ?? unavailable
        self.workoutSync = workoutSync ?? unavailable; self.analytics = analytics ?? unavailable
        self.legalAcceptances = legalAcceptances ?? unavailable
        self.accountDeletion = accountDeletion ?? unavailable
    }

    static func make(repository: DemoRepository) -> AppServiceContainer {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil {
            return .demo(repository: repository)
        }
#endif
        guard let configuration = SupabaseConfiguration.load() else {
            let unavailable = UnavailableLaunchService()
            let unavailableAccountData = UnavailableAccountDataService()
            return AppServiceContainer(
                features: .resolved(for: nil),
                authentication: UnconfiguredAuthenticationService(repository: repository),
                profile: unavailableAccountData,
                locations: BundledLocationService(),
                gyms: unavailableAccountData,
                gymMemberships: unavailableAccountData,
                exercises: unavailableAccountData
                , lifts: unavailable, leaderboards: unavailable,
                social: unavailable,
                verification: unavailable, media: unavailable, notifications: unavailable,
                workoutSync: unavailable, analytics: unavailable, legalAcceptances: unavailable, accountDeletion: unavailable
            )
        }

        let client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publicKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: SupabaseConfiguration.authCallbackURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        return AppServiceContainer(
            features: .resolved(for: configuration.environment),
            authentication: SupabaseAuthenticationService(client: client),
            profile: SupabaseProfileService(client: client),
            locations: SupabaseLocationService(client: client),
            gyms: SupabaseGymService(client: client),
            gymMemberships: SupabaseGymMembershipService(client: client),
            exercises: SupabaseExerciseCatalogService(client: client)
            , lifts: SupabaseLiftService(client: client), leaderboards: SupabaseLeaderboardService(client: client),
            social: SupabaseSocialService(client: client),
            verification: SupabaseVerificationService(client: client), media: SupabaseMediaUploadService(client: client), notifications: SupabaseNotificationService(client: client),
            workoutSync: SupabaseWorkoutSyncService(client: client), analytics: SupabaseAnalyticsService(client: client), legalAcceptances: SupabaseLegalAcceptanceService(client: client), accountDeletion: SupabaseAccountDeletionService(client: client)
        )
    }

#if DEBUG
    static func demo(repository: DemoRepository) -> AppServiceContainer {
        AppServiceContainer(
            features: .resolved(for: nil),
            authentication: MockAuthenticationService(repository: repository),
            profile: MockProfileService(repository: repository),
            locations: BundledLocationService(),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService()
            , lifts: MockLiftService(repository: repository), leaderboards: MockLeaderboardService(repository: repository),
            social: MockSocialService(repository: repository),
            verification: MockVerificationService(repository: repository), media: MockMediaUploadService(), notifications: MockNotificationService(repository: repository),
            workoutSync: MockWorkoutSyncService(), analytics: MockAnalyticsService(), legalAcceptances: MockLegalAcceptanceService(), accountDeletion: MockAccountDeletionService()
        )
    }
#endif
}

/// Production features fail explicitly when configuration is absent. This keeps
/// release builds from silently presenting local demo users or rankings.
@MainActor
final class UnavailableLaunchService: LiftService, LeaderboardService, SocialService, VerificationService, MediaUploadService, NotificationService, WorkoutSyncService, AnalyticsService, LegalAcceptanceService, AccountDeletionService {
    private var error: LiftRankServiceError { .configurationMissing }
    func submissions() async throws -> [LiftSubmission] { throw error }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission { throw error }
    func removeSubmission(id: UUID) async throws { throw error }
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws { throw error }
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws { throw error }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] { throw error }
    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] { throw error }
    func report(userID: UUID, reason: ProfileReportReason, note: String) async throws { throw error }
    func block(userID: UUID) async throws { throw error }
    func unblock(userID: UUID) async throws { throw error }
    func blocks() async throws -> [UserBlockRecord] { throw error }
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
    func deletePlan(id: UUID) async throws { throw error }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { throw error }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws { throw error }
    func track(_ event: AnalyticsEventRecord) async {}
    func acceptances() async throws -> [LegalAcceptanceRecord] { throw error }
    func accept(documents: [LegalDocument]) async throws { throw error }
    func deleteAccount() async throws { throw error }
}

/// Keeps an unconfigured build from exposing local profile, gym, or exercise
/// data through production service boundaries. Demo data is only
/// installed after an explicit switch to `AppServiceContainer.demo`.
@MainActor
final class UnavailableAccountDataService: ProfileService, GymService, GymMembershipService, ExerciseCatalogService {
    private var error: LiftRankServiceError { .configurationMissing }

    func currentProfile() async throws -> UserProfile { throw error }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile { throw error }
    func authenticatedProfile() async throws -> AuthenticatedProfile { throw error }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile { throw error }
    func claimUsername(_ username: String) async throws -> String { throw error }
    func profileCard(userID: UUID) async throws -> PublicProfileCard { throw error }
    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String { throw error }
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? { throw error }
    func removeProfileAvatar(avatarPath: String?) async throws { throw error }
    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry] { throw error }
    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws { throw error }

    func gyms() async throws -> [Gym] { throw error }
    func memberships() async throws -> [GymMembershipRecord] { throw error }
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool { throw error }
    func leave(_ gym: Gym) async throws { throw error }
    func setPrimary(_ gym: Gym) async throws { throw error }

    func activeExercises() async throws -> [CatalogExercise] { throw error }
    func resolve(identifier: String) async throws -> CatalogExercise? { throw error }
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
#if DEBUG
    func signInDemo() async throws -> UserProfile { repository.currentProfile }
#endif
    func signOut() async throws {}
}
