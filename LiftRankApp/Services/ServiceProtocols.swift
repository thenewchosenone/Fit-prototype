import Foundation

@MainActor
protocol AuthenticationService {
    var isDemoMode: Bool { get }
    func signInDemo() async throws -> UserProfile
    func signOut() async
}

@MainActor
protocol ProfileService {
    func currentProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
}

@MainActor
protocol LiftService {
    func submissions() async throws -> [LiftSubmission]
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission
}

@MainActor
protocol LeaderboardService {
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry]
}

@MainActor
protocol GymService {
    func gyms() async throws -> [Gym]
}

@MainActor
protocol ChallengeService {
    func challenges() async throws -> [Challenge]
    func join(_ challenge: Challenge) async throws -> Challenge
}

@MainActor
protocol SocialService {
    func feed() async throws -> [ActivityItem]
}

@MainActor
protocol VerificationService {
    func pendingSubmissions() async throws -> [LiftSubmission]
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission
}

@MainActor
protocol MediaUploadService {
    func upload(localURL: URL?) async throws -> URL?
}

@MainActor
protocol NotificationService {
    func notifications() async throws -> [NotificationItem]
}
