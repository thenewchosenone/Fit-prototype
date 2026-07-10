import Foundation

@MainActor
final class MockAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
    var isDemoMode: Bool { true }

    init(repository: DemoRepository) {
        self.repository = repository
    }

    func signInDemo() async throws -> UserProfile { repository.currentProfile }
    func signOut() async {}
}

@MainActor
final class MockProfileService: ProfileService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func currentProfile() async throws -> UserProfile { repository.currentProfile }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        repository.currentProfile = profile
        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            repository.profiles[index] = profile
        }
        return profile
    }
}

@MainActor
final class MockLiftService: LiftService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func submissions() async throws -> [LiftSubmission] { repository.lifts }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        repository.addLift(submission)
        return submission
    }
}

@MainActor
final class MockLeaderboardService: LeaderboardService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        var filtered = repository.lifts
        if let exerciseID = filters.exerciseID {
            filtered = filtered.filter { $0.exerciseID == exerciseID }
        }
        if let status = filters.verificationLevel {
            filtered = filtered.filter { $0.verificationStatus == status }
        }
        if let gymID = filters.gymID {
            filtered = filtered.filter { $0.gymID == gymID }
        }
        if let level = filters.experienceLevel {
            let ids = repository.profiles.filter { $0.experienceLevel == level }.map(\.id)
            filtered = filtered.filter { ids.contains($0.userID) }
        }
        return RankingCalculator.leaderboardEntries(
            profiles: repository.profiles,
            lifts: filtered,
            rankingType: filters.rankingType,
            verifiedOnly: verifiedOnly,
            currentUserID: repository.currentProfile.id
        )
    }
}

@MainActor
final class MockGymService: GymService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func gyms() async throws -> [Gym] { repository.gyms }
}

@MainActor
final class MockChallengeService: ChallengeService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func challenges() async throws -> [Challenge] { repository.challenges }
    func join(_ challenge: Challenge) async throws -> Challenge {
        guard let index = repository.challenges.firstIndex(where: { $0.id == challenge.id }) else { return challenge }
        repository.challenges[index].isJoined = true
        repository.challenges[index].participantCount += 1
        return repository.challenges[index]
    }
}

@MainActor
final class MockSocialService: SocialService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func feed() async throws -> [ActivityItem] { repository.activities }
}

@MainActor
final class MockVerificationService: VerificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func pendingSubmissions() async throws -> [LiftSubmission] {
        repository.lifts.filter { $0.verificationStatus == .videoSubmitted || $0.verificationStatus == .selfReported }
    }
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission {
        guard let index = repository.lifts.firstIndex(where: { $0.id == lift.id }) else { return lift }
        repository.lifts[index].verificationStatus = status
        repository.lifts[index].updatedAt = .now
        repository.notifications.insert(NotificationItem(id: UUID(), title: status == .rejected ? "Lift rejected" : "Lift approved", message: note ?? "Verification updated.", kind: status.rawValue, createdAt: .now, isRead: false), at: 0)
        return repository.lifts[index]
    }
}

struct MockMediaUploadService: MediaUploadService {
    func upload(localURL: URL?) async throws -> URL? {
        try await Task.sleep(for: .milliseconds(450))
        return localURL ?? URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov")
    }
}

@MainActor
final class MockNotificationService: NotificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func notifications() async throws -> [NotificationItem] { repository.notifications }
}
