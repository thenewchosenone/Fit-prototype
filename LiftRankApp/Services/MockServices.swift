import Foundation

@MainActor
final class MockAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
    var isConfigured: Bool { true }
    var isDemoMode: Bool { true }

    init(repository: DemoRepository) {
        self.repository = repository
    }

    func restoreSession() async throws -> AccountSession? { nil }
    func signUp(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func signIn(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func requestPasswordReset(email: String) async throws {}
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func signInDemo() async throws -> UserProfile {
        repository.currentProfile = MockData.demoProfile
        return repository.currentProfile
    }
    func signOut() async throws {}
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
    func authenticatedProfile() async throws -> AuthenticatedProfile {
        let profile = repository.currentProfile
        return AuthenticatedProfile(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: "", avatarPath: profile.avatarPath, onboardingCompleted: true,
            preferredUnit: profile.preferredUnit, birthDate: nil, sexCategory: profile.sexCategory,
            heightCentimeters: profile.heightInches * 2.54,
            bodyweightPounds: profile.bodyweightPounds, city: profile.city,
            region: profile.state, countryCode: "US", cityID: profile.cityID, yearsExperience: profile.yearsExperience,
            experienceLevel: profile.experienceLevel,
            privacy: ProfilePrivacySettings(
                ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
                bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
                locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
                gymAudience: profile.hideGym ? .privateProfile : .publicProfile
            )
        )
    }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        var profile = repository.currentProfile
        profile.username = draft.username
        profile.displayName = draft.displayName
        profile.preferredUnit = draft.preferredUnit
        profile.sexCategory = draft.sexCategory ?? .open
        profile.heightInches = (draft.heightCentimeters ?? profile.heightInches * 2.54) / 2.54
        profile.bodyweightPounds = draft.bodyweightPounds ?? profile.bodyweightPounds
        profile.city = draft.city
        profile.state = draft.region
        profile.cityID = draft.cityID
        profile.yearsExperience = draft.yearsExperience ?? profile.yearsExperience
        profile.experienceLevel = draft.experienceLevel ?? profile.experienceLevel
        _ = try await updateProfile(profile)
        return try await authenticatedProfile()
    }
    func claimUsername(_ username: String) async throws -> String {
        let normalized = username.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            throw LiftRankServiceError.invalidInput("Use 3–24 lowercase letters, numbers, or underscores.")
        }
        repository.currentProfile.username = normalized
        return normalized
    }
    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        guard let profile = repository.profiles.first(where: { $0.id == userID }) else {
            throw LiftRankServiceError.server("Profile not found.")
        }
        return PublicProfileCard(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: "", avatarPath: profile.avatarPath, ageBand: profile.hideExactAge ? nil : profile.ageGroup,
            sexCategory: profile.sexCategory, city: profile.hideCity ? nil : profile.city,
            region: profile.hideCity ? nil : profile.state, countryCode: nil,
            primaryGymID: profile.hideGym ? nil : profile.primaryGymID,
            primaryGymName: profile.hideGym ? nil : profile.primaryGymName
        )
    }
    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String { avatarPath }
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? { nil }
    func removeProfileAvatar(avatarPath: String?) async throws {}
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
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {}
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {}
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
    func memberships() async throws -> [GymMembershipRecord] {
        repository.joinedGymIDs.map { gymID in
            GymMembershipRecord(
                userID: repository.currentProfile.id, gymID: gymID,
                isPrimary: gymID == repository.currentProfile.primaryGymID,
                joinedAt: .now, leftAt: nil
            )
        }
    }
}

@MainActor
final class MockSocialService: SocialService {
    private let repository: DemoRepository
    private var blockRecords: [UserBlockRecord] = []
    var shouldFailBlocksFetch = false
    init(repository: DemoRepository) { self.repository = repository }
    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return repository.profiles.filter {
            clean.isEmpty || $0.username.lowercased().contains(clean) || $0.displayName.lowercased().contains(clean)
        }.prefix(max(1, min(limit, 50))).map {
            PublicProfileCard(
                id: $0.id, username: $0.username, displayName: $0.displayName,
                bio: "", avatarPath: $0.avatarPath, ageBand: $0.hideExactAge ? nil : $0.ageGroup,
                sexCategory: $0.sexCategory, city: $0.hideCity ? nil : $0.city,
                region: $0.hideCity ? nil : $0.state, countryCode: nil,
                primaryGymID: $0.hideGym ? nil : $0.primaryGymID,
                primaryGymName: $0.hideGym ? nil : $0.primaryGymName
            )
        }
    }
    func block(userID: UUID) async throws {
        guard userID != repository.currentProfile.id,
              !blockRecords.contains(where: { $0.blockedID == userID }) else { return }
        blockRecords.append(UserBlockRecord(
            blockerID: repository.currentProfile.id,
            blockedID: userID,
            createdAt: .now
        ))
    }
    func unblock(userID: UUID) async throws {
        blockRecords.removeAll { $0.blockedID == userID }
    }
    func blocks() async throws -> [UserBlockRecord] {
        if shouldFailBlocksFetch {
            throw LiftRankServiceError.server("Blocks unavailable")
        }
        return blockRecords
    }
}

@MainActor
final class MockGymMembershipService: GymMembershipService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool {
        repository.joinGym(gym, maximumMemberships: maximumMemberships)
    }
    func leave(_ gym: Gym) async throws {
        repository.leaveGym(gym)
    }
    func setPrimary(_ gym: Gym) async throws {
        guard repository.joinedGymIDs.contains(gym.id) else {
            throw LiftRankServiceError.invalidInput("Join this gym before making it primary.")
        }
        repository.currentProfile.primaryGymID = gym.id
        repository.currentProfile.primaryGymName = gym.name
    }
}

@MainActor
final class MockExerciseCatalogService: ExerciseCatalogService {
    func activeExercises() async throws -> [CatalogExercise] {
        MockData.trainingExerciseLibrary.map {
            CatalogExercise(
                id: $0.id, displayName: $0.name, status: "active",
                rankingMovement: $0.rankingExerciseID, metadata: ["body_part": $0.bodyPart]
            )
        }
    }
    func resolve(identifier: String) async throws -> CatalogExercise? {
        try await activeExercises().first {
            $0.id == identifier || $0.displayName.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }
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
        repository.notifications.insert(NotificationItem(id: UUID(), title: status == .rejected ? "Lift rejected" : "Lift approved", message: note ?? "Verification updated.", kind: status.rawValue, createdAt: .now, isRead: false, destination: NotificationDestination(kind: .lift, targetID: lift.id)), at: 0)
        return repository.lifts[index]
    }
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission {
        guard let lift = repository.lifts.first(where: { $0.id == liftID }) else { throw LiftRankServiceError.invalidInput("Lift not found.") }
        let status: VerificationStatus = decision == .reject ? .rejected : .videoVerified
        var updated = try await updateVerification(for: lift, status: status, note: note)
        updated.moderationStatus = decision == .requestReplacement ? .replacementRequested : decision == .reject ? .rejected : .clear
        if let index = repository.lifts.firstIndex(where: { $0.id == liftID }) { repository.lifts[index] = updated }
        return updated
    }
}

struct MockMediaUploadService: MediaUploadService {
    func upload(localURL: URL?) async throws -> URL? {
        try await Task.sleep(for: .milliseconds(450))
        return localURL ?? URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov")
    }
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset {
        progress(1)
        return LiftMediaAsset(id: UUID(), ownerID: MockData.demoUserID, storagePath: localURL.path, contentType: "video/quicktime", byteCount: 0, createdAt: .now)
    }
    func signedPlaybackURL(assetID: UUID) async throws -> URL { URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov") }
}

@MainActor
final class MockNotificationService: NotificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func notifications() async throws -> [NotificationItem] { repository.notifications }
    func markRead(notificationID: UUID) async throws {
        if let index = repository.notifications.firstIndex(where: { $0.id == notificationID }) { repository.notifications[index].isRead = true }
    }
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func revokeDevice(deviceID: String) async throws {}
}

@MainActor
final class MockWorkoutSyncService: WorkoutSyncService {
    private var planDocuments: [WorkoutPlanDocument] = []
    private var snapshots: [CompletedWorkoutSnapshot] = []
    var failNextPlanDeletion = false
    func plans() async throws -> [WorkoutPlanDocument] { planDocuments }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        guard !document.isSeededDemoData else { throw LiftRankServiceError.invalidInput("Demo data cannot be synced.") }
        if let current = planDocuments.first(where: { $0.id == document.id }), current.revision != expectedRevision {
            var conflict = document
            conflict.id = UUID(); conflict.isConflictCopy = true; conflict.conflictOfRevision = expectedRevision
            planDocuments.append(conflict)
            return .conflict(server: current, localCopy: conflict)
        }
        var saved = document; saved.revision = expectedRevision + 1
        planDocuments.removeAll { $0.id == saved.id }; planDocuments.append(saved)
        return .saved(saved)
    }
    func deletePlan(id: UUID) async throws {
        if failNextPlanDeletion {
            failNextPlanDeletion = false
            throw LiftRankServiceError.invalidInput("Simulated plan deletion failure")
        }
        planDocuments.removeAll { $0.id == id }
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { snapshots.filter { since == nil || $0.completedAt > since! } }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        guard !snapshot.isSeededDemoData else { return }
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)
    }
    func deleteCompletedWorkout(id: UUID) async throws {
        snapshots.removeAll { $0.id == id }
    }
}

struct MockAnalyticsService: AnalyticsService { func track(_ event: AnalyticsEventRecord) async {} }
struct MockLegalAcceptanceService: LegalAcceptanceService {
    func acceptances() async throws -> [LegalAcceptanceRecord] { [] }
    func accept(documents: [LegalDocument]) async throws {}
}
struct MockAccountDeletionService: AccountDeletionService { func deleteAccount() async throws {} }
