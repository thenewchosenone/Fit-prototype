import Foundation

@MainActor
protocol AuthenticationService {
    var isConfigured: Bool { get }
    var isDemoMode: Bool { get }
    func restoreSession() async throws -> AccountSession?
    func signUp(email: String, password: String) async throws -> AccountSession
    func signIn(email: String, password: String) async throws -> AccountSession
    func requestPasswordReset(email: String) async throws
    func handleAuthCallback(_ url: URL) async throws -> AccountSession
    func updatePassword(_ password: String) async throws
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession
#if DEBUG
    func signInDemo() async throws -> UserProfile
#endif
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
    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload?
    func removeProfileAvatar(avatarPath: String?) async throws
    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry]
    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws
}

struct ProfileAvatarDownload: Equatable {
    var fullImageData: Data
    var thumbnailData: Data?
}

@MainActor
protocol LocationService {
    func searchCities(countryCode: String, region: String, query: String, limit: Int) async throws -> [LocationCitySuggestion]
}

@MainActor
protocol LiftService {
    func submissions() async throws -> [LiftSubmission]
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission
    func removeSubmission(id: UUID) async throws
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws
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
    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard]
    func report(userID: UUID, reason: ProfileReportReason, note: String) async throws
    func block(userID: UUID) async throws
    func unblock(userID: UUID) async throws
    func blocks() async throws -> [UserBlockRecord]
}

@MainActor
protocol GymMembershipService {
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool
    func leave(_ gym: Gym) async throws
    func setPrimary(_ gym: Gym) async throws
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
    func deleteCompletedWorkout(id: UUID) async throws
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
    func handleAuthCallback(_ url: URL) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
    func updatePassword(_ password: String) async throws { throw LiftRankServiceError.configurationMissing }
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { throw LiftRankServiceError.configurationMissing }
}
extension LiftService {
    func removeSubmission(id: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws { throw LiftRankServiceError.configurationMissing }
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws { throw LiftRankServiceError.configurationMissing }
}
extension SocialService {
    func report(userID: UUID, reason: ProfileReportReason, note: String) async throws { throw LiftRankServiceError.configurationMissing }
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
extension WorkoutSyncService {
    func deleteCompletedWorkout(id: UUID) async throws { throw LiftRankServiceError.configurationMissing }
}
