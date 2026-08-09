import XCTest
import SwiftData
import UIKit
@testable import LiftRank

@MainActor
private final class TestSessionAuthenticationService: AuthenticationService {
    var isConfigured = true
    var isDemoMode = false
    var restoredSession: AccountSession?
    var signInSession: AccountSession
    private(set) var signOutCount = 0

    init(session: AccountSession) {
        signInSession = session
        restoredSession = session
    }

    func restoreSession() async throws -> AccountSession? { restoredSession }
    func signUp(email: String, password: String) async throws -> AccountSession { signInSession }
    func signIn(email: String, password: String) async throws -> AccountSession { signInSession }
    func requestPasswordReset(email: String) async throws {}
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { signInSession }
    func signInDemo() async throws -> UserProfile { MockData.demoProfile }
    func signOut() async throws { signOutCount += 1 }
}

@MainActor
private final class TestSessionLegalAcceptanceService: LegalAcceptanceService {
    var records: [LegalAcceptanceRecord] = []
    private(set) var acceptedDocuments: [LegalDocument] = []
    let userID: UUID

    init(userID: UUID) { self.userID = userID }

    func acceptances() async throws -> [LegalAcceptanceRecord] { records }

    func accept(documents: [LegalDocument]) async throws {
        acceptedDocuments = documents
        records = documents.map {
            LegalAcceptanceRecord(
                id: UUID(), userID: userID, documentKind: $0.kind.rawValue,
                documentVersion: $0.version, acceptedAt: .now
            )
        }
    }
}

@MainActor
private final class GatedSessionLegalAcceptanceService: LegalAcceptanceService {
    var requestStarted = false
    private var continuation: CheckedContinuation<[LegalAcceptanceRecord], Never>?

    func acceptances() async throws -> [LegalAcceptanceRecord] {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func accept(documents: [LegalDocument]) async throws {}

    func release() {
        continuation?.resume(returning: [])
        continuation = nil
    }
}

@MainActor
private final class TestAccountDeletionService: AccountDeletionService {
    private(set) var deleteCount = 0
    func deleteAccount() async throws { deleteCount += 1 }
}

@MainActor
private final class TestPushNotificationService: NotificationService {
    private(set) var registrations: [PushDeviceRegistration] = []
    private(set) var revokedDeviceIDs: [String] = []
    func notifications() async throws -> [NotificationItem] { [] }
    func markRead(notificationID: UUID) async throws {}
    func registerDevice(_ registration: PushDeviceRegistration) async throws { registrations.append(registration) }
    func revokeDevice(deviceID: String) async throws { revokedDeviceIDs.append(deviceID) }
}

@MainActor
private final class GatedNotificationService: NotificationService {
    var requestStarted = false
    var shouldFail = false
    private let notificationsToReturn: [NotificationItem]
    private var continuation: CheckedContinuation<[NotificationItem], Never>?

    init(notifications: [NotificationItem]) {
        notificationsToReturn = notifications
    }

    func notifications() async throws -> [NotificationItem] {
        requestStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        if shouldFail { throw LiftRankServiceError.server("Simulated notification refresh failure") }
        return notificationsToReturn
    }

    func release() {
        continuation?.resume(returning: notificationsToReturn)
        continuation = nil
    }

    func markRead(notificationID: UUID) async throws {}
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func revokeDevice(deviceID: String) async throws {}
}

@MainActor
private final class TestAnalyticsCaptureService: AnalyticsService {
    private(set) var events: [AnalyticsEventRecord] = []
    func track(_ event: AnalyticsEventRecord) async { events.append(event) }
}

@MainActor
final class BackendFoundationTests: XCTestCase {
    func testPrivacyAudienceMatchesServerContract() throws {
        XCTAssertEqual(PrivacyAudience(rawValue: "public"), .publicProfile)
        XCTAssertEqual(PrivacyAudience(rawValue: "friends"), .friends)
        XCTAssertEqual(PrivacyAudience(rawValue: "gym"), .gym)
        XCTAssertEqual(PrivacyAudience(rawValue: "private"), .privateProfile)
    }
    func testLiftVideoDurationPolicyAllowsThirtySecondsAndRejectsLongerClips() {
        XCTAssertTrue(LiftVideoPolicy.allows(duration: 30))
        XCTAssertFalse(LiftVideoPolicy.allows(duration: 30.001))
        XCTAssertFalse(LiftVideoPolicy.allows(duration: .infinity))
    }

    func testProductionConfigurationRejectsServiceRoleKey() {
        let serviceRoleKey = "eyJhbGciOiJub25lIn0.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature"
        let environment = [
            "LIFTRANK_SUPABASE_URL": "https://example.supabase.co",
            "LIFTRANK_SUPABASE_ANON_KEY": serviceRoleKey,
            "LIFTRANK_BACKEND_ENVIRONMENT": "production"
        ]

        XCTAssertNil(SupabaseConfiguration.load(environment: environment))
    }

    func testProductionConfigurationAcceptsAnonKey() {
        let anonKey = "eyJhbGciOiJub25lIn0.eyJyb2xlIjoiYW5vbiJ9.signature"
        let environment = [
            "LIFTRANK_SUPABASE_URL": "https://example.supabase.co",
            "LIFTRANK_SUPABASE_ANON_KEY": anonKey,
            "LIFTRANK_BACKEND_ENVIRONMENT": "production"
        ]

        XCTAssertNotNil(SupabaseConfiguration.load(environment: environment))
    }


    func testFocusedLaunchSourceDoesNotContainGymRankPlaceholders() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appRoot = repositoryRoot.appendingPathComponent("LiftRankApp")
        let fileManager = FileManager.default
        let swiftFiles = try fileManager
            .subpathsOfDirectory(atPath: appRoot.path)
            .filter { $0.hasSuffix(".swift") }

        for relativePath in swiftFiles {
            let fileURL = appRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(
                source.contains("Gym #"),
                "\(relativePath) contains a placeholder gym rank label."
            )
        }
    }

    func testLeaderboardCurrentUserBadgeDoesNotUseDemoIdentity() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let leaderboardSource = repositoryRoot
            .appendingPathComponent("LiftRankApp")
            .appendingPathComponent("Features")
            .appendingPathComponent("Leaderboard")
            .appendingPathComponent("LeaderboardRowAndFilters.swift")
        let source = try String(contentsOf: leaderboardSource, encoding: .utf8)

        XCTAssertFalse(
            source.contains("entry.profile.id == MockData.demoUserID"),
            "Leaderboard current-user badges must compare against the active profile, not the seeded demo profile."
        )
        XCTAssertTrue(
            source.contains("entry.profile.id == appState.currentProfile.id"),
            "Leaderboard current-user badges should use the logged-in profile as the source of truth."
        )
    }



    func testAuthenticatedProfilePhotoDownloadsIntoLocalCache() async throws {
        let repository = DemoRepository()
        let userID = repository.currentProfile.id
        let avatarPath = "test/\(userID.uuidString.lowercased())/avatar"
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
        let imageData = try XCTUnwrap(
            UIImage(systemName: "person.crop.circle.fill")?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
                .pngData()
        )
        let session = AccountSession(
            userID: userID,
            email: "avatar@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "avatar_lifter",
            displayName: "Avatar Lifter",
            bio: "",
            avatarPath: avatarPath,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        service.avatarDownload = ProfileAvatarDownload(fullImageData: imageData, thumbnailData: imageData)
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))

        await appState.signIn(email: "avatar@example.test", password: "password")

        XCTAssertEqual(service.downloadedAvatarPaths, [avatarPath])
        XCTAssertNotNil(LocalProfilePhotoStore.shared.thumbnail(for: avatarPath))
        await appState.cacheAuthenticatedProfilePhotoIfNeeded()
        XCTAssertEqual(service.downloadedAvatarPaths, [avatarPath])
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
    }

    func testAuthenticatedProfilePhotoDownloadDoesNotCacheAChangedAccount() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let avatarPath = "download-race/\(userID.uuidString.lowercased())/avatar"
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
        let session = AccountSession(userID: userID, email: "avatar-download-race@example.test", expiresAt: .now.addingTimeInterval(3_600))
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "avatar_download_race", displayName: "Avatar Download Race", bio: "",
            avatarPath: avatarPath, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
            yearsExperience: nil, experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session), profile: service,
            gyms: MockGymService(repository: repository), gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(), legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-download-race@example.test", password: "password")
        service.avatarDownload = ProfileAvatarDownload(fullImageData: try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill")?.pngData()), thumbnailData: nil)
        service.holdAvatarDownload = true
        let download = Task { await appState.cacheAuthenticatedProfilePhotoIfNeeded() }

        for _ in 0..<20 where !service.avatarDownloadStarted {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        repository.currentProfile.id = UUID()
        service.releaseAvatarDownload()
        await download.value

        XCTAssertNil(LocalProfilePhotoStore.shared.thumbnail(for: avatarPath))
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
    }

    func testUploadedProfilePhotoCachesReturnedServerAvatarPath() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let serverAvatarPath = "server/\(userID.uuidString.lowercased())/avatar"
        LocalProfilePhotoStore.shared.remove(avatarPath: serverAvatarPath)
        let session = AccountSession(
            userID: userID,
            email: "avatar-cache@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "avatar_cache_lifter",
            displayName: "Avatar Cache Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        service.uploadedAvatarReturnPath = serverAvatarPath
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-cache@example.test", password: "password")
        let image = try XCTUnwrap(
            UIImage(systemName: "person.crop.circle.fill")?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        )

        appState.saveProfilePhoto(image)
        for _ in 0..<120 where appState.currentProfile.avatarPath != serverAvatarPath {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(appState.currentProfile.avatarPath, serverAvatarPath)
        XCTAssertNotNil(LocalProfilePhotoStore.shared.thumbnail(for: serverAvatarPath))
        LocalProfilePhotoStore.shared.remove(avatarPath: serverAvatarPath)
    }

    func testProfileEditDoesNotContinueAvatarUploadAfterAccountChange() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(
            userID: userID,
            email: "avatar-edit-race@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "avatar_edit_race",
            displayName: "Avatar Edit Race",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        service.holdAvatarUpload = true
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-edit-race@example.test", password: "password")

        let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill"))
        let avatarPath = try LocalProfilePhotoStore.shared.save(
            image: image,
            userID: userID,
            mode: .authenticated
        )
        var editedProfile = appState.currentProfile
        editedProfile.avatarPath = avatarPath
        let save = Task {
            await appState.saveEditedProfile(
                editedProfile,
                primaryGym: nil,
                privacy: appState.authenticatedPrivacy
            )
        }

        for _ in 0..<20 where !service.avatarUploadStarted {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        repository.currentProfile.id = UUID()
        service.releaseAvatarUpload()

        let didSave = await save.value
        XCTAssertFalse(didSave)
        XCTAssertEqual(service.saveProfileCount, 0)
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
    }

    func testProfileEditDoesNotSaveAProfileAfterAccountChangeWithoutAvatarUpload() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(
            userID: userID,
            email: "profile-edit-race@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "profile_edit_race",
            displayName: "Profile Edit Race",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "profile-edit-race@example.test", password: "password")
        service.holdAuthenticatedProfile = true

        var editedProfile = appState.currentProfile
        editedProfile.displayName = "Should Not Save"
        let save = Task {
            await appState.saveEditedProfile(
                editedProfile,
                primaryGym: nil,
                privacy: appState.authenticatedPrivacy
            )
        }

        while !service.authenticatedProfileStarted {
            await Task.yield()
        }
        repository.currentProfile.id = UUID()
        service.releaseAuthenticatedProfile()

        let didSave = await save.value
        XCTAssertFalse(didSave)
        XCTAssertEqual(service.saveProfileCount, 0)
    }

    func testRemovingProfilePhotoWinsOverAnInFlightUpload() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "avatar-race@example.test", expiresAt: .now.addingTimeInterval(3_600))
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "avatar_race_lifter", displayName: "Avatar Race Lifter", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
            yearsExperience: nil, experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        service.holdAvatarUpload = true
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session), profile: service,
            gyms: MockGymService(repository: repository), gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(), legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-race@example.test", password: "password")
        let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill"))

        appState.saveProfilePhoto(image)
        for _ in 0..<20 where !service.avatarUploadStarted {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        appState.removeProfilePhoto()
        service.releaseAvatarUpload()
        for _ in 0..<20 where service.updateProfileCount < 1 {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertNil(appState.currentProfile.avatarPath)
        XCTAssertNil(service.profile.avatarPath)
    }

    func testProfilePhotoUploadDoesNotUpdateAChangedAccount() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "avatar-account-race@example.test", expiresAt: .now.addingTimeInterval(3_600))
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "avatar_account_race", displayName: "Avatar Account Race", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
            yearsExperience: nil, experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        service.holdAvatarUpload = true
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session), profile: service,
            gyms: MockGymService(repository: repository), gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(), legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-account-race@example.test", password: "password")
        let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill"))

        appState.saveProfilePhoto(image)
        for _ in 0..<20 where !service.avatarUploadStarted {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        repository.currentProfile.id = UUID()
        service.releaseAvatarUpload()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.updateProfileCount, 0)
    }

    @MainActor
    func testSigningIntoDifferentAccountClearsCachedWorkoutState() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let previousUserID = repository.currentProfile.id
        repository.completedWorkouts = [CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Previous account workout", dayLabel: "Monday", startedAt: .now,
            completedAt: .now, duration: 1_800, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )]
        repository.strainEntries = [StrainEntry(strain: 7)]
        repository.injuryEntries = [InjuryEntry(area: "Shoulder", description: "Old", intensity: 4)]
        repository.workoutPreferences.automaticallySubmitVideoBackedPRs = true
        let newUserID = UUID()
        let session = AccountSession(
            userID: newUserID, email: "new-account@example.test", expiresAt: .now.addingTimeInterval(3_600)
        )
        let profileService = TestProfileService(profile: AuthenticatedProfile(
            id: newUserID, username: "new_account", displayName: "New Account", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
            yearsExperience: nil, experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: profileService,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: newUserID)
        ))

        await appState.signIn(email: "new-account@example.test", password: "password")

        XCTAssertNotEqual(previousUserID, repository.currentProfile.id)
        XCTAssertEqual(repository.currentProfile.id, newUserID)
        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertNil(repository.activeWorkout)
        XCTAssertTrue(repository.pendingCompletedWorkoutUploads.isEmpty)
        XCTAssertTrue(repository.strainEntries.isEmpty)
        XCTAssertTrue(repository.injuryEntries.isEmpty)
        XCTAssertFalse(repository.workoutPreferences.automaticallySubmitVideoBackedPRs)
    }


#if DEBUG
#endif




    func testNotificationStoreOwnsReadStateAndTypedLeaderboardRoute() throws {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository)
        let gymID = UUID()
        let notification = NotificationItem(
            id: UUID(),
            title: "Rank changed",
            message: "You moved up.",
            kind: "Ranking",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(
                kind: .leaderboard,
                exerciseID: "deadlift",
                gymID: gymID,
                rankingType: .poundForPound
            )
        )
        store.replaceNotifications([notification])

        let route = store.open(notification)

        guard case .leaderboard(let filters) = route else {
            return XCTFail("Expected a typed leaderboard route")
        }
        XCTAssertEqual(filters.exerciseID, "deadlift")
        XCTAssertNil(filters.gymID)
        XCTAssertEqual(filters.rankingType, .poundForPound)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(try XCTUnwrap(store.notifications.first).isRead)
    }

    @MainActor
    func testLiftNotificationRoutesToTheCurrentProfileInsteadOfLiftID() throws {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository)
        let notification = NotificationItem(
            id: UUID(), title: "Lift approved", message: "Your lift was approved.", kind: "Approved",
            createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .lift, targetID: UUID())
        )
        store.replaceNotifications([notification])

        let route = store.open(notification)

        guard case .profile(let profileID) = route else {
            return XCTFail("Expected lift notification to open a profile")
        }
        XCTAssertEqual(profileID, repository.currentProfile.id)
    }

    @MainActor
    func testGymNotificationOpensTheTargetGym() throws {
        let repository = DemoRepository()
        let gym = Gym(
            id: UUID(), name: "Downtown Strength", city: "Austin", state: "Texas",
            memberCount: 0, verifiedLiftCount: 0
        )
        repository.gyms = [gym]
        let appState = AppState(repository: repository)
        let notification = NotificationItem(
            id: UUID(), title: "Gym update", message: "Your gym has a new update.", kind: "Gym",
            createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .gym, gymID: gym.id)
        )
        appState.openNotification(notification)

        XCTAssertEqual(appState.selectedGym?.id, gym.id)
        XCTAssertEqual(appState.selectedTab, 0)
    }


    func testProfileStoreOwnsAuthenticatedMappingAndProductionIsolation() {
        let repository = DemoRepository()
        let store = ProfileStore(repository: repository)
        let userID = UUID()
        let remote = AuthenticatedProfile(
            id: userID,
            username: "production_lifter",
            displayName: "Production Lifter",
            bio: "",
            avatarPath: "avatars/production.jpg",
            onboardingCompleted: true,
            preferredUnit: .kilograms,
            birthDate: nil,
            sexCategory: .female,
            heightCentimeters: 170,
            city: "Austin",
            region: "Texas",
            countryCode: "US",
            yearsExperience: 4,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings(bodyweightAudience: .privateProfile)
        )

        store.applyAuthenticatedProfile(remote, retainingDemoProfiles: false)

        XCTAssertEqual(store.currentProfile.id, userID)
        XCTAssertEqual(store.currentProfile.username, "production_lifter")
        XCTAssertEqual(store.currentProfile.avatarPath, "avatars/production.jpg")
        XCTAssertEqual(store.currentProfile.heightInches, 170 / 2.54, accuracy: 0.001)
        XCTAssertTrue(store.currentProfile.hideBodyweight)
        XCTAssertEqual(store.profiles.map(\.id), [userID])
    }

    func testProfileStoreTreatsRemoteAvatarRemovalAsAuthoritative() {
        let repository = DemoRepository()
        var local = repository.currentProfile
        local.avatarPath = "local-profile-photos/member-thumb.jpg"
        repository.currentProfile = local
        let store = ProfileStore(repository: repository)
        let userID = UUID()
        let remote = AuthenticatedProfile(
            id: userID,
            username: "production_lifter",
            displayName: "Production Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .male,
            heightCentimeters: 180,
            city: "Miami",
            region: "Florida",
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        )

        store.applyAuthenticatedProfile(remote, retainingDemoProfiles: false)

        XCTAssertNil(store.currentProfile.avatarPath)
    }

    func testProfileStorePreservesCachedProfilesWhenRefreshingSameAccount() {
        let repository = DemoRepository()
        let userID = UUID()
        var current = MockData.emptyProfile
        current.id = userID
        current.username = "current_lifter"
        let cachedProfile = MockData.demoProfile
        repository.currentProfile = current
        repository.profiles = [current, cachedProfile]
        let store = ProfileStore(repository: repository)
        let remote = AuthenticatedProfile(
            id: userID,
            username: "current_lifter",
            displayName: "Current Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        )

        store.applyAuthenticatedProfile(remote, retainingDemoProfiles: false)

        XCTAssertEqual(store.profiles.map(\.id), [userID, cachedProfile.id])
    }

    func testPendingAuthenticatedAvatarUploadRetriesDuringAccountLoad() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let avatarPath = "\(userID.uuidString.lowercased())/avatar"
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
        let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill"))
        let savedPath = try LocalProfilePhotoStore.shared.save(
            image: image,
            userID: userID,
            mode: .authenticated
        )
        XCTAssertEqual(
            LocalProfilePhotoStore.shared.pendingUploadPath(userID: userID, mode: .authenticated),
            savedPath
        )
        let session = AccountSession(
            userID: userID,
            email: "avatar-retry@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "avatar_retry", displayName: "Avatar Retry", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
            yearsExperience: nil, experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))

        await appState.signIn(email: session.email ?? "avatar-retry@example.test", password: "password")

        XCTAssertEqual(service.uploadedAvatarPaths, [savedPath])
        XCTAssertEqual(appState.currentProfile.avatarPath, savedPath)
        XCTAssertNil(LocalProfilePhotoStore.shared.pendingUploadPath(userID: userID, mode: .authenticated))
        LocalProfilePhotoStore.shared.remove(avatarPath: avatarPath)
    }

    func testProfileStoreOwnsRemoteEditedProfilePersistence() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        repository.currentProfile.id = userID
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "remote_lifter",
            displayName: "Remote Lifter",
            bio: "Keep this bio",
            avatarPath: "avatars/original.jpg",
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: Date(timeIntervalSince1970: 700_000_000),
            sexCategory: .open,
            heightCentimeters: 180,
            city: "Miami",
            region: "Florida",
            countryCode: "US",
            yearsExperience: 3,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings()
        ))
        let store = ProfileStore(repository: repository, profileService: service)
        var edited = repository.currentProfile
        edited.id = userID
        edited.username = "updated_lifter"
        edited.displayName = "Updated Lifter"
        edited.bio = "Training for my next total"
        edited.avatarPath = "avatars/updated.jpg"
        edited.preferredUnit = .kilograms
        edited.ageGroup = "30-34"
        edited.bodyweightPounds = 205
        edited.yearsExperience = 7
        edited.cityID = UUID()
        edited.city = "Miami"
        edited.state = "Florida"
        let serverCityID = UUID()
        service.saveProfileResponse = AuthenticatedProfile(
            id: userID,
            username: "updated_lifter",
            displayName: "Updated Lifter",
            bio: "Keep this bio",
            avatarPath: "avatars/server-normalized.jpg",
            onboardingCompleted: true,
            preferredUnit: .kilograms,
            birthDate: Date(timeIntervalSince1970: 700_000_000),
            sexCategory: .open,
            heightCentimeters: 180,
            bodyweightPounds: 205,
            city: "Austin",
            region: "Texas",
            countryCode: "US",
            cityID: serverCityID,
            yearsExperience: 3,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings(locationAudience: .privateProfile)
        )
        let gym = Gym(
            id: UUID(),
            name: "Downtown Strength",
            city: "Austin",
            state: "Texas",
            memberCount: 0,
            verifiedLiftCount: 0
        )
        let privacy = ProfilePrivacySettings(locationAudience: .privateProfile, friendListAudience: .gym)

        let saved = try await store.saveEditedProfile(
            edited,
            primaryGym: gym,
            privacy: privacy,
            authenticated: true
        )

        XCTAssertEqual(saved.id, userID)
        XCTAssertEqual(saved.displayName, "Updated Lifter")
        XCTAssertEqual(saved.avatarPath, "avatars/server-normalized.jpg")
        XCTAssertEqual(saved.primaryGymID, gym.id)
        XCTAssertEqual(saved.bodyweightPounds, 205)
        XCTAssertEqual(saved.cityID, serverCityID)
        XCTAssertEqual(saved.city, "Austin")
        XCTAssertEqual(saved.state, "Texas")
        let savedDraft = try XCTUnwrap(service.lastSavedProfileDraft)
        XCTAssertEqual(savedDraft.bio, "Training for my next total")
        XCTAssertEqual(
            ProfileDisplayFormatting.ageGroup(for: try XCTUnwrap(savedDraft.birthDate)),
            "30-34"
        )
        XCTAssertEqual(savedDraft.bodyweightPounds, 205)
        XCTAssertEqual(savedDraft.yearsExperience, 7)
        XCTAssertEqual(savedDraft.cityID, edited.cityID)
        XCTAssertEqual(savedDraft.city, "Miami")
        XCTAssertEqual(savedDraft.region, "Florida")
        XCTAssertEqual(savedDraft.privacy.locationAudience, .privateProfile)
        XCTAssertEqual(savedDraft.privacy.friendListAudience, .gym)
        XCTAssertEqual(store.profiles.map(\.id), [userID])
    }

    func testBodyweightLogUpdatesLocalProfileAndAuthenticatedProfileService() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "bodyweight@example.test", expiresAt: .now.addingTimeInterval(3600))
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "bodyweight_lifter",
            displayName: "Bodyweight Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            bodyweightPounds: 200,
            city: "Miami",
            region: "Florida",
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: session.email ?? "bodyweight@example.test", password: "password")

        appState.updateBodyweight(BodyweightEntry(
            id: UUID(),
            week: 1,
            targetDate: Date(timeIntervalSince1970: 1_800_000_000),
            actual: 212,
            notes: "Home log"
        ))

        let deadline = Date().addingTimeInterval(1)
        while service.updateProfileCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(appState.currentProfile.bodyweightPounds, 212)
        XCTAssertEqual(appState.bodyweightEntries.last?.actual, 212)
        XCTAssertEqual(service.profile.bodyweightPounds, 212)
        XCTAssertEqual(service.updateProfileCount, 1)
        XCTAssertEqual(service.savedBodyweightEntries.last?.actual, 212)
    }

    func testBodyweightHistorySyncFailureDoesNotSignOutAuthenticatedAccount() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let session = AccountSession(
            userID: userID,
            email: "bodyweight-sync@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "bodyweight_sync", displayName: "Bodyweight Sync", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, bodyweightPounds: 205,
            city: nil, region: nil, countryCode: "US", yearsExperience: nil,
            experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        service.bodyweightSyncError = LiftRankServiceError.server("Bodyweight history unavailable")
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))

        await appState.signIn(email: session.email ?? "bodyweight-sync@example.test", password: "password")

        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.accountSession)
        XCTAssertEqual(appState.currentProfile.bodyweightPounds, 205)
    }

    func testBodyweightHistoryDoesNotOverrideCurrentProfileWeight() {
        XCTAssertEqual(
            ProfileDataAuthority.currentBodyweight(profilePounds: 205, historyFallbackPounds: 183.2),
            205
        )
        XCTAssertEqual(
            ProfileDataAuthority.currentBodyweight(profilePounds: 0, historyFallbackPounds: 183.2),
            183.2
        )
        XCTAssertEqual(
            ProfileDataAuthority.currentBodyweight(profilePounds: 0, historyFallbackPounds: nil),
            0
        )
    }

    func testBodyweightUploadDoesNotRestoreSignedOutProfile() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let session = AccountSession(
            userID: userID,
            email: "bodyweight-race@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "bodyweight_race", displayName: "Bodyweight Race", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .open, heightCentimeters: nil, bodyweightPounds: 200,
            city: nil, region: nil, countryCode: "US", yearsExperience: nil,
            experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: session.email ?? "bodyweight-race@example.test", password: "password")
        service.holdBodyweightSave = true

        appState.updateBodyweight(BodyweightEntry(
            id: UUID(), week: 1, targetDate: .now, actual: 210, notes: "Pending"
        ))
        while !service.bodyweightSaveStarted {
            await Task.yield()
        }
        await appState.signOutAccount()
        service.releaseBodyweightSave()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(service.updateProfileCount, 0)
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertEqual(repository.currentProfile.id, MockData.emptyProfile.id)
        XCTAssertTrue(repository.bodyweightEntries.isEmpty)
    }

    func testKilogramBodyweightLogStoresPoundsAndDisplaysConsistently() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "bodyweight-kg@example.test", expiresAt: .now.addingTimeInterval(3600))
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "bodyweight_kg_lifter",
            displayName: "Bodyweight KG Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .kilograms,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            bodyweightPounds: 0,
            city: "Miami",
            region: "Florida",
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: session.email ?? "bodyweight-kg@example.test", password: "password")

        let poundsFromKilogramInput = MeasurementFormatting.convert(100, from: .kilograms, to: .pounds)
        appState.updateBodyweight(BodyweightEntry(
            id: UUID(),
            week: 1,
            targetDate: Date(timeIntervalSince1970: 1_800_000_000),
            actual: poundsFromKilogramInput,
            notes: "Progress log"
        ))

        let deadline = Date().addingTimeInterval(1)
        while service.updateProfileCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(appState.currentProfile.bodyweightPounds, poundsFromKilogramInput, accuracy: 0.001)
        XCTAssertEqual(appState.bodyweightEntries.last?.actual ?? 0, poundsFromKilogramInput, accuracy: 0.001)
        XCTAssertEqual(service.profile.bodyweightPounds ?? 0, poundsFromKilogramInput, accuracy: 0.001)
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweight(appState.currentProfile.bodyweightPounds, preferredUnit: appState.currentProfile.preferredUnit),
            "100 kg"
        )
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweightOrDash(appState.bodyweightEntries.last?.actual, preferredUnit: appState.currentProfile.preferredUnit),
            "100 kg"
        )
    }

    func testProfileStoreAllowsEditedProfileWithoutPrimaryGym() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        repository.currentProfile.id = userID
        let originalGymID = repository.currentProfile.primaryGymID
        let originalGymName = repository.currentProfile.primaryGymName
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "remote_lifter",
            displayName: "Remote Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .male,
            heightCentimeters: 180,
            city: "Miami",
            region: "Florida",
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        let store = ProfileStore(repository: repository, profileService: service)
        var edited = repository.currentProfile
        edited.id = userID
        edited.username = "updated_lifter"
        edited.displayName = "Updated Lifter"
        edited.city = "Miami"
        edited.state = "Florida"

        let saved = try await store.saveEditedProfile(
            edited,
            primaryGym: nil,
            privacy: ProfilePrivacySettings(),
            authenticated: true
        )

        XCTAssertEqual(saved.displayName, "Updated Lifter")
        XCTAssertEqual(saved.primaryGymID, originalGymID)
        XCTAssertEqual(saved.primaryGymName, originalGymName)
        XCTAssertEqual(saved.city, "Miami")
        XCTAssertEqual(saved.state, "Florida")
    }

    func testProfileStoreOwnsAuthenticatedLoadAndOnboardingSave() async throws {
        let repository = DemoRepository()
        let userID = UUID()
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID,
            username: "new_lifter",
            displayName: "New Lifter",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: false,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            city: nil,
            region: nil,
            countryCode: "US",
            yearsExperience: nil,
            experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        let store = ProfileStore(repository: repository, profileService: service)

        let loaded = try await store.fetchAuthenticatedProfile()
        store.applyAuthenticatedProfile(loaded, retainingDemoProfiles: false)
        XCTAssertEqual(loaded.id, userID)
        XCTAssertEqual(store.profiles.map(\.id), [userID])
        XCTAssertEqual(store.currentProfile.bio, loaded.bio)

        let cityID = UUID()
        let saved = try await store.saveAuthenticatedProfile(ProfileDraft(
            username: "ready_lifter",
            displayName: "Ready Lifter",
            bio: "Ready to compete",
            preferredUnit: .kilograms,
            birthDate: nil,
            sexCategory: .open,
            heightCentimeters: nil,
            cityID: cityID,
            city: "Austin",
            region: "Texas",
            countryCode: "US",
            yearsExperience: 2,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings(locationAudience: .privateProfile),
            completesOnboarding: true
        ), retainingDemoProfiles: false)

        XCTAssertTrue(saved.onboardingCompleted)
        XCTAssertEqual(store.currentProfile.username, "ready_lifter")
        XCTAssertEqual(store.currentProfile.cityID, cityID)
        XCTAssertEqual(store.currentProfile.city, "Austin")
        XCTAssertEqual(store.currentProfile.state, "Texas")
        XCTAssertEqual(service.profile.cityID, cityID)
        XCTAssertEqual(service.profile.city, "Austin")
        XCTAssertEqual(service.profile.region, "Texas")
        XCTAssertEqual(service.profile.countryCode, "US")
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: store.currentProfile.city, region: store.currentProfile.state),
            "Austin, Texas"
        )
        XCTAssertEqual(store.profiles.map(\.id), [userID])
    }

    func testAnalyticsStoreBuildsDeterministicEventsAndIgnoresMissingUser() async throws {
        let service = TestAnalyticsCaptureService()
        let eventID = UUID()
        let userID = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let store = AnalyticsStore(
            service: service,
            makeID: { eventID },
            now: { occurredAt }
        )

        await store.track(.weeklyReturn, userID: nil)
        XCTAssertTrue(service.events.isEmpty)

        await store.track(.workoutCompleted, userID: userID, properties: ["workout_id": "test-workout"])
        let event = try XCTUnwrap(service.events.first)
        XCTAssertEqual(event.id, eventID)
        XCTAssertEqual(event.userID, userID)
        XCTAssertEqual(event.name, .workoutCompleted)
        XCTAssertEqual(event.occurredAt, occurredAt)
        XCTAssertEqual(event.properties, ["workout_id": "test-workout"])
    }

    func testProfileStoreOwnsGymMembershipLimitAndPrimaryReassignment() {
        let repository = DemoRepository()
        let primary = Gym(id: UUID(), name: "Primary", city: "Miami", state: "Florida", memberCount: 10, verifiedLiftCount: 2)
        let secondary = Gym(id: UUID(), name: "Secondary", city: "Miami", state: "Florida", memberCount: 5, verifiedLiftCount: 1)
        let overflow = Gym(id: UUID(), name: "Overflow", city: "Miami", state: "Florida", memberCount: 3, verifiedLiftCount: 0)
        repository.gyms = [primary, secondary, overflow]
        repository.currentProfile.primaryGymID = primary.id
        repository.currentProfile.primaryGymName = primary.name
        repository.joinedGymIDs = [primary.id]
        let store = ProfileStore(repository: repository)

        XCTAssertTrue(store.joinGym(secondary, maximumMemberships: 2))
        XCTAssertFalse(store.joinGym(overflow, maximumMemberships: 2))
        XCTAssertEqual(store.joinedGymCount, 2)

        store.leaveGym(primary)
        XCTAssertFalse(store.isGymJoined(primary.id))
        XCTAssertEqual(store.currentProfile.primaryGymID, secondary.id)

        store.leaveGym(secondary)
        XCTAssertFalse(store.isGymJoined(secondary.id))
        XCTAssertTrue(store.canJoinAnotherGym(maximumMemberships: 2))
    }

    func testSessionStoreOwnsAccountLifecycleState() {
        let store = SessionStore()
        let session = AccountSession(
            userID: UUID(),
            email: "lifter@example.com",
            expiresAt: .now.addingTimeInterval(3_600)
        )

        XCTAssertEqual(store.status, .restoring)
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertTrue(store.beginOperation())
        XCTAssertFalse(store.beginOperation())

        store.updateSession(session)
        store.transition(to: .authenticated)
        store.endOperation()

        XCTAssertEqual(store.session, session)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testSessionStoreClearsRemoteAccountStateWithoutChangingRoute() {
        let store = SessionStore(status: .authenticated)
        store.updateOutstandingLegalDocuments(LegalDocument.current)
        store.message = "Temporary error"

        store.clearRemoteAccountState()

        XCTAssertEqual(store.status, .authenticated)
        XCTAssertNil(store.session)
        XCTAssertTrue(store.outstandingLegalDocuments.isEmpty)
        XCTAssertEqual(store.message, "Temporary error")
    }

    func testSessionStoreOwnsAuthenticationLegalAndDeletionServiceBoundaries() async throws {
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "lifter@example.com", expiresAt: .now.addingTimeInterval(3_600))
        let authentication = TestSessionAuthenticationService(session: session)
        let legal = TestSessionLegalAcceptanceService(userID: userID)
        let deletion = TestAccountDeletionService()
        let store = SessionStore(
            authenticationService: authentication,
            legalAcceptanceService: legal,
            accountDeletionService: deletion
        )

        let restored = try await store.restoreAccountSession()
        let signedIn = try await store.signIn(email: "lifter@example.com", password: "password")
        let outstanding = try await store.refreshLegalAcceptanceStatus()
        XCTAssertEqual(restored, session)
        XCTAssertEqual(signedIn, session)
        XCTAssertEqual(outstanding, LegalDocument.current)
        XCTAssertEqual(store.status, .needsLegalAcceptance)

        try await store.acceptCurrentLegalDocuments()
        XCTAssertEqual(legal.acceptedDocuments, LegalDocument.current)
        XCTAssertTrue(store.outstandingLegalDocuments.isEmpty)
        XCTAssertEqual(store.status, .authenticated)

        try await store.deleteAuthenticatedAccount()
        XCTAssertEqual(deletion.deleteCount, 1)
        XCTAssertEqual(authentication.signOutCount, 1)
        try await store.signOut()
        XCTAssertEqual(authentication.signOutCount, 2)
    }

    @MainActor
    func testSessionStoreDoesNotApplyLegalResponseAfterAccountChanges() async throws {
        let userID = UUID()
        let legal = GatedSessionLegalAcceptanceService()
        let store = SessionStore(
            status: .authenticated,
            session: AccountSession(userID: userID, email: "legal-race@example.test", expiresAt: .now),
            legalAcceptanceService: legal
        )
        let refresh = Task { try await store.refreshLegalAcceptanceStatus() }

        while !legal.requestStarted {
            await Task.yield()
        }
        store.updateSession(nil)
        store.transition(to: .signedOut)
        legal.release()

        do {
            _ = try await refresh.value
            XCTFail("Expected stale legal response to be rejected")
        } catch let error as LiftRankServiceError {
            XCTAssertEqual(error, .sessionExpired)
        }
        XCTAssertEqual(store.status, .signedOut)
        XCTAssertTrue(store.outstandingLegalDocuments.isEmpty)
    }

    func testNotificationStoreOwnsPushRegistrationAndDeviceRevocation() async throws {
        let repository = DemoRepository()
        let service = TestPushNotificationService()
        let store = NotificationStore(
            repository: repository,
            notificationService: service,
            deviceID: "test-device"
        )
        let userID = UUID()
        repository.currentProfile.id = userID

        await store.registerPushToken("token-value", userID: userID, environment: "sandbox")
        let registration = try XCTUnwrap(service.registrations.first)
        XCTAssertEqual(registration.userID, userID)
        XCTAssertEqual(registration.deviceID, "test-device")
        XCTAssertEqual(registration.token, "token-value")
        XCTAssertEqual(registration.environment, "sandbox")

        await store.registerPushToken("wrong-account-token", userID: UUID(), environment: "sandbox")
        XCTAssertEqual(service.registrations.count, 1)

        await store.revokeCurrentDevice()
        XCTAssertEqual(service.revokedDeviceIDs, ["test-device"])
    }

    @MainActor
    func testNotificationRefreshDoesNotRestorePreviousUsersResponse() async {
        let repository = DemoRepository()
        let notification = NotificationItem(
            id: UUID(), title: "Old account", message: "", kind: "Test",
            createdAt: .now, isRead: false
        )
        let service = GatedNotificationService(notifications: [notification])
        let store = NotificationStore(repository: repository, notificationService: service)
        let refresh = Task { await store.refreshProductionData() }

        while !service.requestStarted {
            await Task.yield()
        }
        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newNotification = NotificationItem(
            id: UUID(), title: "New account", message: "", kind: "Test",
            createdAt: .now, isRead: false
        )
        repository.notifications = [newNotification]
        service.release()
        await refresh.value

        XCTAssertEqual(store.notifications, [newNotification])
    }

    @MainActor
    func testNotificationRefreshFailureDoesNotClearNewUsersCache() async {
        let repository = DemoRepository()
        let oldNotification = NotificationItem(
            id: UUID(), title: "Old account", message: "", kind: "Test",
            createdAt: .now, isRead: false
        )
        repository.notifications = [oldNotification]
        let service = GatedNotificationService(notifications: [])
        service.shouldFail = true
        let store = NotificationStore(repository: repository, notificationService: service)
        let refresh = Task { await store.refreshProductionData() }

        while !service.requestStarted {
            await Task.yield()
        }
        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newNotification = NotificationItem(
            id: UUID(), title: "New account", message: "", kind: "Test",
            createdAt: .now, isRead: false
        )
        repository.notifications = [newNotification]
        service.release()
        await refresh.value

        XCTAssertEqual(store.notifications, [newNotification])
    }


    func testSupabaseConfigurationRequiresExplicitEnvironment() {
        XCTAssertNil(SupabaseConfiguration.load(environment: [
            "LIFTRANK_SUPABASE_URL": "https://example.supabase.co",
            "LIFTRANK_SUPABASE_ANON_KEY": "public-key"
        ], bundle: Bundle(for: BackendFoundationTests.self)))
    }

    func testSupabaseConfigurationSeparatesHostedAndLocalEnvironments() throws {
        let staging = try XCTUnwrap(SupabaseConfiguration.load(environment: [
            "LIFTRANK_BACKEND_ENVIRONMENT": "staging",
            "LIFTRANK_SUPABASE_URL": "https://example.supabase.co",
            "LIFTRANK_SUPABASE_ANON_KEY": "public-key"
        ]))
        XCTAssertEqual(staging.environment, .staging)

        XCTAssertNil(SupabaseConfiguration.load(environment: [
            "LIFTRANK_BACKEND_ENVIRONMENT": "local",
            "LIFTRANK_SUPABASE_URL": "https://example.supabase.co",
            "LIFTRANK_SUPABASE_ANON_KEY": "public-key"
        ]))
    }

    func testSupabaseProfileMapperDoesNotInheritSeededDemoIdentity() {
        let userID = UUID()
        let remote = AuthenticatedProfile(
            id: userID,
            username: "remote_lifter",
            displayName: "Remote Lifter",
            bio: "",
            avatarPath: "avatars/remote.jpg",
            onboardingCompleted: true,
            preferredUnit: .kilograms,
            birthDate: nil,
            sexCategory: .female,
            heightCentimeters: 170,
            city: "Austin",
            region: "Texas",
            countryCode: "US",
            cityID: userID,
            yearsExperience: 4,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings(bodyweightAudience: .privateProfile)
        )

        let profile = SupabaseProfileMapper.authenticated(remote)

        XCTAssertEqual(profile.id, userID)
        XCTAssertEqual(profile.username, "remote_lifter")
        XCTAssertEqual(profile.displayName, "Remote Lifter")
        XCTAssertEqual(profile.avatarPath, "avatars/remote.jpg")
        XCTAssertEqual(profile.bodyweightPounds, 0)
        XCTAssertEqual(profile.cityID, userID)
        XCTAssertEqual(profile.city, "Austin")
        XCTAssertEqual(profile.state, "Texas")
        XCTAssertEqual(profile.ageGroup, "Hidden")
        XCTAssertEqual(profile.primaryGymName, "No primary gym")
        XCTAssertNotEqual(profile.primaryGymID, MockData.demoProfile.primaryGymID)
        XCTAssertNotEqual(profile.username, MockData.demoProfile.username)
        XCTAssertTrue(profile.hideBodyweight)
        XCTAssertTrue(profile.hideGym)
    }

    func testLeaderboardProfileMapperUsesOnlyRemoteCardAndLiftContext() {
        let userID = UUID()
        let liftGymID = UUID()
        let card = PublicProfileCard(
            id: userID,
            username: "ranked_lifter",
            displayName: "Ranked Lifter",
            bio: "",
            avatarPath: nil,
            ageBand: nil,
            sexCategory: nil,
            city: nil,
            region: nil,
            countryCode: nil,
            primaryGymID: nil,
            primaryGymName: nil
        )

        let profile = SupabaseProfileMapper.leaderboard(
            card: card,
            bodyweightPounds: 198,
            fallbackGymID: liftGymID,
            bodyweightVisible: false
        )

        XCTAssertEqual(profile.id, userID)
        XCTAssertEqual(profile.primaryGymID, liftGymID)
        XCTAssertEqual(profile.primaryGymName, "Gym hidden")
        XCTAssertEqual(profile.bodyweightPounds, 198)
        XCTAssertEqual(profile.ageGroup, "Hidden")
        XCTAssertTrue(profile.hideBodyweight)
        XCTAssertTrue(profile.hideCity)
        XCTAssertTrue(profile.hideGym)
        XCTAssertNotEqual(profile.username, MockData.demoProfile.username)
    }

    func testUnavailableAccountDataServicesFailExplicitly() async {
        let service = UnavailableAccountDataService()

        do {
            _ = try await service.currentProfile()
            XCTFail("Expected profile access to fail without backend configuration")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .configurationMissing)
        }

        do {
            _ = try await service.gyms()
            XCTFail("Expected gym access to fail without backend configuration")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .configurationMissing)
        }

        do {
            _ = try await service.activeExercises()
            XCTFail("Expected exercise access to fail without backend configuration")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .configurationMissing)
        }
    }

    func testMissingConfigurationRoutesToConfigurationRequired() async {
        let repository = DemoRepository()
        let state = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: UnconfiguredAuthenticationService(repository: repository),
            profile: MockProfileService(repository: repository),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService()
        ))
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .configurationRequired)
    }

    func testMissingSessionRoutesToSignedOut() async {
        let state = makeState(session: nil, onboardingCompleted: false)
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .signedOut)
    }

    func testFirstTimeSessionRoutesToOnboarding() async {
        let state = makeState(session: session, onboardingCompleted: false)
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .needsOnboarding)
        XCTAssertEqual(state.currentProfile.id, session.userID)
    }

    func testCompletedSessionRoutesToApplication() async {
        let state = makeState(session: session, onboardingCompleted: true)
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .authenticated)
    }

    func testCompletedSessionRequiresCurrentLegalAcceptance() async {
        let state = makeState(session: session, onboardingCompleted: true, hasCurrentLegalAcceptance: false)
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .needsLegalAcceptance)
        XCTAssertEqual(Set(state.outstandingLegalDocuments.map(\.kind)), Set(LegalDocumentKind.allCases))
    }

    func testExpiredSessionIsRedactedAndReturnsSignedOut() async {
        let auth = TestAuthenticationService(session: nil, restoreError: LiftRankServiceError.sessionExpired)
        let state = makeState(authentication: auth, onboardingCompleted: true)
        await state.restoreAccount()
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertFalse((state.accountMessage ?? "").lowercased().contains("token"))
    }

    func testFailedAuthenticatedProfileLoadClearsRestoredSessionState() async {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "restore-failure@example.test", expiresAt: .now.addingTimeInterval(3_600))
        let profileService = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "restore_failure", displayName: "Restore Failure", bio: "", avatarPath: nil,
            onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil, sexCategory: .open,
            heightCentimeters: nil, city: nil, region: nil, countryCode: "US", yearsExperience: nil,
            experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        profileService.authenticatedProfileError = LiftRankServiceError.server("Profile unavailable")
        let state = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: profileService,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))

        await state.restoreAccount()

        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertNil(state.accountSession)
    }

    func testDelayedAuthenticatedProfileLoadCannotRestoreSignedOutAccount() async {
        let repository = DemoRepository()
        let userID = UUID()
        let restoredSession = AccountSession(
            userID: userID,
            email: "delayed-restore@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let profileService = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "delayed_restore", displayName: "Delayed Restore", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds,
            birthDate: nil, sexCategory: .open, heightCentimeters: nil, city: nil,
            region: nil, countryCode: "US", yearsExperience: nil,
            experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        profileService.holdAuthenticatedProfile = true
        let state = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: restoredSession),
            profile: profileService,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))

        let restore = Task { await state.restoreAccount() }
        while !profileService.authenticatedProfileStarted { await Task.yield() }
        await state.signOutAccount()
        profileService.releaseAuthenticatedProfile()
        await restore.value

        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertNil(state.accountSession)
        XCTAssertNotEqual(state.currentProfile.id, userID)
        XCTAssertFalse(state.profiles.contains { $0.id == userID })
    }

    func testExplicitDemoSelectionIsIsolated() async {
        let state = makeState(session: nil, onboardingCompleted: false)
        await state.restoreAccount()
        XCTAssertFalse(state.serviceContainer.lifts is MockLiftService)
        await state.enterDemoMode()
        XCTAssertEqual(state.accountStatus, .demo)
        XCTAssertTrue(state.isDemoMode)
        XCTAssertNil(state.accountSession)
        XCTAssertEqual(state.currentProfile.id, MockData.demoUserID)
        XCTAssertTrue(state.serviceContainer.lifts is MockLiftService)
        state.repository.notifications = [NotificationItem(
            id: UUID(), title: "Demo notification", message: "", kind: "Test", createdAt: .now, isRead: false
        )]
        state.repository.completedWorkouts = [CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Private demo workout", dayLabel: "Monday", startedAt: .now,
            completedAt: .now, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )]

        await state.signOutAccount()
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertFalse(state.serviceContainer.lifts is MockLiftService)
        XCTAssertTrue(state.repository.notifications.isEmpty)
        XCTAssertTrue(state.repository.completedWorkouts.isEmpty)
        XCTAssertNil(state.repository.activeWorkout)
    }

    func testMockSocialServicePersistsBlockRelationships() async throws {
        let repository = DemoRepository()
        let service = MockSocialService(repository: repository)
        let otherUserID = UUID()

        try await service.block(userID: otherUserID)
        let blockedIDs = try await service.blocks().map(\.blockedID)
        XCTAssertEqual(blockedIDs, [otherUserID])

        try await service.unblock(userID: otherUserID)
        let remainingBlocks = try await service.blocks()
        XCTAssertTrue(remainingBlocks.isEmpty)
    }

    @MainActor
    func testAccountSocialStoreDoesNotApplyPreviousUsersBlockResponse() async throws {
        let repository = DemoRepository()
        let profileStore = ProfileStore(repository: repository)
        let blockedID = UUID()
        let socialService = GatedBlockService(blockedID: blockedID)
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: MockGymService(repository: repository),
            gymMembershipService: MockGymMembershipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: socialService
        )

        let update = Task { try? await store.setBlocked(blockedID, blocked: true) }
        while !socialService.requestStarted {
            await Task.yield()
        }

        repository.currentProfile.id = UUID()
        let newGym = Gym(
            id: UUID(), name: "New account gym", city: "Miami", state: "Florida",
            memberCount: 1, verifiedLiftCount: 0
        )
        profileStore.replaceGymDirectory([newGym], memberships: [])
        socialService.release()
        await update.value

        XCTAssertTrue(store.blocks.isEmpty)
        XCTAssertEqual(profileStore.gyms, [newGym])
    }

    @MainActor
    func testAccountSocialStoreClearsPreviousUsersBlocksWhenRefreshFailsAfterAccountChange() async {
        let repository = DemoRepository()
        let profileStore = ProfileStore(repository: repository)
        let socialService = GatedFailingBlocksService()
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: MockGymService(repository: repository),
            gymMembershipService: MockGymMembershipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: socialService
        )
        await store.refreshBlocks()
        XCTAssertFalse(store.blocks.isEmpty)
        socialService.shouldGate = true

        let refresh = Task { await store.refreshBlocks() }
        while !socialService.requestStarted {
            await Task.yield()
        }

        repository.currentProfile.id = UUID()
        store.clear()
        socialService.releaseWithFailure()
        await refresh.value

        XCTAssertTrue(store.blocks.isEmpty)
    }

    @MainActor
    func testAthleteSearchDoesNotMergePreviousUsersResponse() async throws {
        let repository = DemoRepository()
        let searchResultID = UUID()
        let socialService = GatedAthleteSearchService(card: PublicProfileCard(
            id: searchResultID,
            username: "search_result",
            displayName: "Search Result",
            bio: "",
            avatarPath: nil,
            ageBand: nil,
            sexCategory: .open,
            city: nil,
            region: nil,
            countryCode: nil,
            primaryGymID: nil,
            primaryGymName: nil
        ))
        let state = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestAuthenticationService(session: AccountSession(
                userID: repository.currentProfile.id,
                email: "search@example.test",
                expiresAt: .now.addingTimeInterval(3600)
            )),
            profile: MockProfileService(repository: repository),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            social: socialService
        ))

        let search = Task { await state.searchAthletes("search") }
        while !socialService.requestStarted {
            await Task.yield()
        }

        repository.currentProfile.id = UUID()
        socialService.release()
        let results = await search.value

        XCTAssertTrue(results.isEmpty)
        XCTAssertNil(state.profileStore.profile(id: searchResultID))
    }

    @MainActor
    func testAccountSocialStorePreservesCachedBlocksWhenRefreshFails() async throws {
        let repository = DemoRepository()
        let profileStore = ProfileStore(repository: repository)
        let socialService = MockSocialService(repository: repository)
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: MockGymService(repository: repository),
            gymMembershipService: MockGymMembershipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: socialService
        )
        let blockedID = UUID()
        try await socialService.block(userID: blockedID)
        await store.refreshBlocks()
        XCTAssertTrue(store.isBlocked(blockedID))

        socialService.shouldFailBlocksFetch = true
        await store.refreshBlocks()

        XCTAssertTrue(store.isBlocked(blockedID))

        repository.currentProfile.id = UUID()
        await store.refreshBlocks()

        XCTAssertFalse(store.isBlocked(blockedID))
    }

    @MainActor
    func testAccountSocialStoreClearsPreviousUsersGymCacheBeforeRefresh() async throws {
        let repository = DemoRepository()
        let gym = Gym(id: UUID(), name: "Private Gym", city: "Austin", state: "Texas", memberCount: 1, verifiedLiftCount: 0)
        repository.gyms = [gym]
        repository.joinedGymIDs = [gym.id]
        repository.currentProfile.primaryGymID = gym.id
        repository.currentProfile.primaryGymName = gym.name
        repository.gymRequests = [GymRequest(
            id: UUID(), name: "Private request", city: "Austin", state: "Texas",
            createdBy: repository.currentProfile.id, status: "Pending", createdAt: .now
        )]
        let profileStore = ProfileStore(repository: repository)
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: FailingGymService(),
            gymMembershipService: MockGymMembershipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: MockSocialService(repository: repository)
        )

        repository.currentProfile.id = UUID()
        do {
            try await store.refreshDirectoryAndRelationships()
            XCTFail("Expected the gym refresh to fail")
        } catch { }

        XCTAssertTrue(profileStore.gyms.isEmpty)
        XCTAssertTrue(profileStore.joinedGymIDs.isEmpty)
        XCTAssertFalse(profileStore.joinedGymIDs.contains(profileStore.currentProfile.primaryGymID))
        XCTAssertTrue(profileStore.currentProfile.primaryGymName.isEmpty)
        XCTAssertTrue(store.gymMemberships.isEmpty)
        XCTAssertTrue(repository.gymRequests.isEmpty)
    }

    @MainActor
    func testProfileStoreClearsStalePrimaryGymWhenRefreshHasNoPrimary() {
        let repository = DemoRepository()
        let oldGym = Gym(
            id: UUID(), name: "Old Gym", city: "Austin", state: "Texas",
            memberCount: 1, verifiedLiftCount: 0
        )
        repository.gyms = [oldGym]
        repository.joinedGymIDs = [oldGym.id]
        repository.currentProfile.primaryGymID = oldGym.id
        repository.currentProfile.primaryGymName = oldGym.name

        let profileStore = ProfileStore(repository: repository)
        profileStore.replaceGymDirectory([oldGym], memberships: [])

        XCTAssertTrue(profileStore.joinedGymIDs.isEmpty)
        XCTAssertTrue(profileStore.currentProfile.primaryGymName.isEmpty)
        XCTAssertFalse(profileStore.isPrimaryGym(oldGym.id))
    }

    @MainActor
    func testAccountSocialStoreDoesNotApplyPreviousUsersGymResponse() async throws {
        let repository = DemoRepository()
        let oldGym = Gym(id: UUID(), name: "Old Gym", city: "Austin", state: "Texas", memberCount: 1, verifiedLiftCount: 0)
        repository.gyms = [oldGym]
        let profileStore = ProfileStore(repository: repository)
        profileStore.replaceGymDirectory([oldGym], memberships: [])
        let gymService = GatedGymService(gym: Gym(
            id: UUID(), name: "New Gym", city: "Denver", state: "Colorado", memberCount: 1, verifiedLiftCount: 0
        ))
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: gymService,
            gymMembershipService: MockGymMembershipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: MockSocialService(repository: repository)
        )
        let refresh = Task { try? await store.refreshDirectoryAndRelationships() }

        while !gymService.requestStarted {
            await Task.yield()
        }
        repository.currentProfile.id = UUID()
        let newGym = Gym(
            id: UUID(), name: "New account gym", city: "Miami", state: "Florida",
            memberCount: 1, verifiedLiftCount: 0
        )
        profileStore.replaceGymDirectory([newGym], memberships: [])
        gymService.release()
        await refresh.value

        XCTAssertEqual(profileStore.gyms, [newGym])
        XCTAssertTrue(store.gymMemberships.isEmpty)
    }

    @MainActor
    func testGymRequestPersistsInLocalWorkoutSnapshot() {
        let persistence = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        let appState = AppState(repository: repository)

        appState.requestGym(name: "  New Gym  ", city: "Austin", state: "Texas", note: "Please verify")

        XCTAssertEqual(persistence.loadSnapshot()?.gymRequests?.first?.name, "New Gym")
        XCTAssertEqual(persistence.loadSnapshot()?.gymRequests?.first?.createdBy, repository.currentProfile.id)
    }

    @MainActor
    func testSwiftDataWorkoutResetDeletesSnapshotsAndLegacyRecords() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PersistentLiftRecord.self, PersistentSettings.self,
            PersistentWorkoutRecord.self, PersistentWorkoutState.self,
            configurations: configuration
        )
        let context = container.mainContext
        context.insert(PersistentLiftRecord(
            id: UUID(), exerciseID: "barbell_bench_press", exerciseName: "Bench Press",
            weight: 225, repetitions: 5, performedAt: .now
        ))
        context.insert(PersistentSettings())
        context.insert(PersistentWorkoutRecord(
            id: UUID(), exercise: "Bench Press", workout: "Private", weight: 225,
            reps: 5, rpe: 8, performedAt: .now
        ))
        context.insert(PersistentWorkoutState(schemaVersion: WorkoutPersistenceSnapshot.currentVersion, payload: Data()))
        try context.save()

        SwiftDataWorkoutPersistenceStore(context: context).reset()

        XCTAssertTrue(try context.fetch(FetchDescriptor<PersistentWorkoutRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PersistentWorkoutState>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PersistentLiftRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PersistentSettings>()).isEmpty)
    }

    @MainActor
    func testSwiftDataWorkoutStoreMigratesLegacyJSONAndSkipsIdenticalWrites() throws {
        let bootstrap = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: bootstrap)
        let snapshot = try XCTUnwrap(bootstrap.snapshot)
        let legacyPayload = try JSONEncoder().encode(snapshot)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PersistentLiftRecord.self, PersistentSettings.self,
            PersistentWorkoutRecord.self, PersistentWorkoutState.self,
            configurations: configuration
        )
        let context = container.mainContext
        context.insert(PersistentWorkoutState(schemaVersion: snapshot.schemaVersion, payload: legacyPayload))
        try context.save()
        let store = SwiftDataWorkoutPersistenceStore(context: context)

        XCTAssertEqual(store.loadSnapshot(), snapshot)
        store.saveSnapshot(snapshot)

        let record = try XCTUnwrap(context.fetch(FetchDescriptor<PersistentWorkoutState>()).first)
        XCTAssertTrue(record.payload.starts(with: Data("bplist".utf8)))
        let firstUpdatedAt = record.updatedAt
        store.saveSnapshot(snapshot)
        XCTAssertEqual(record.updatedAt, firstUpdatedAt)
    }






    func testUsernameValidationRejectsAtSymbol() async {
        let service = MockProfileService(repository: DemoRepository())
        do {
            _ = try await service.claimUsername("@Not Valid")
            XCTFail("Expected validation failure")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .invalidInput("Use 3–24 lowercase letters, numbers, or underscores."))
        }
    }

    func testWorkoutSyncPreservesAConflictCopy() async throws {
        let service = MockWorkoutSyncService()
        let original = WorkoutPlanDocument(
            id: UUID(), ownerID: session.userID, revision: 0, name: "Strength",
            payload: Data("first".utf8), updatedAt: .now
        )
        guard case let .saved(saved) = try await service.savePlan(original, expectedRevision: 0) else {
            return XCTFail("Expected initial save")
        }
        var stale = original
        stale.payload = Data("stale edit".utf8)
        guard case let .conflict(server, localCopy) = try await service.savePlan(stale, expectedRevision: 0) else {
            return XCTFail("Expected a conflict")
        }
        XCTAssertEqual(server.revision, saved.revision)
        XCTAssertTrue(localCopy.isConflictCopy)
        XCTAssertNotEqual(localCopy.id, original.id)
    }

    @MainActor
    func testWorkoutSyncStoreOwnsCompletedUploadQueueAndIdempotentRetry() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let snapshot = CompletedWorkoutSnapshot(
            id: UUID(),
            ownerID: repository.currentProfile.id,
            payload: Data("invalid-local-payload-is-still-uploaded".utf8),
            completedAt: .now
        )

        store.enqueueCompletedWorkout(snapshot)
        store.enqueueCompletedWorkout(snapshot)
        XCTAssertEqual(store.pendingCompletedWorkoutUploads.map(\.id), [snapshot.id])

        await store.synchronizeCompletedWorkoutHistory()
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(store.pendingCompletedWorkoutUploads.isEmpty)
        let uploadedWorkoutIDs = try await service.completedWorkouts(since: nil).map(\.id)
        XCTAssertEqual(uploadedWorkoutIDs, [snapshot.id])
    }

    @MainActor
    func testWorkoutSyncStoreUpdatesAnExistingCompletedWorkoutSnapshot() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workoutID = UUID()
        let original = CompletedWorkoutSnapshot(
            id: workoutID,
            ownerID: repository.currentProfile.id,
            payload: Data("original".utf8),
            completedAt: .now
        )
        try await service.uploadCompletedWorkout(original)

        let edited = CompletedWorkoutSnapshot(
            id: workoutID,
            ownerID: repository.currentProfile.id,
            payload: Data("edited".utf8),
            completedAt: original.completedAt
        )
        store.enqueueCompletedWorkout(edited)
        await store.synchronizeCompletedWorkoutHistory()

        let remote = try await service.completedWorkouts(since: nil)
        XCTAssertEqual(remote.count, 1)
        XCTAssertEqual(try XCTUnwrap(remote.first).payload, Data("edited".utf8))
    }

    @MainActor
    func testWorkoutSyncStoreReplacesAnAlreadyQueuedCompletedWorkoutSnapshot() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workoutID = UUID()
        let original = CompletedWorkoutSnapshot(
            id: workoutID,
            ownerID: repository.currentProfile.id,
            payload: Data("original".utf8),
            completedAt: .now
        )
        let edited = CompletedWorkoutSnapshot(
            id: workoutID,
            ownerID: repository.currentProfile.id,
            payload: Data("edited".utf8),
            completedAt: original.completedAt
        )

        store.enqueueCompletedWorkout(original)
        store.enqueueCompletedWorkout(edited)

        XCTAssertEqual(store.pendingCompletedWorkoutUploads.map(\.payload), [edited.payload])
        await store.synchronizeCompletedWorkoutHistory()

        let remote = try await service.completedWorkouts(since: nil)
        XCTAssertEqual(remote.map(\.payload), [edited.payload])
    }

    @MainActor
    func testWorkoutSyncStorePreservesANewerEditQueuedDuringUpload() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = GatedCompletedWorkoutUploadService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workoutID = UUID()
        let original = CompletedWorkoutSnapshot(
            id: workoutID,
            ownerID: repository.currentProfile.id,
            payload: Data("original".utf8),
            completedAt: .now
        )
        var edited = original
        edited.payload = Data("edited".utf8)
        store.enqueueCompletedWorkout(original)

        let sync = Task { await store.synchronizeCompletedWorkoutHistory() }
        while !service.requestStarted {
            await Task.yield()
        }
        store.enqueueCompletedWorkout(edited)
        service.release()
        await sync.value

        XCTAssertEqual(repository.pendingCompletedWorkoutUploads, [edited])
    }

    @MainActor
    func testWorkoutSyncStoreAppliesRemoteEditWhenNoLocalUploadIsPending() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Original", dayLabel: "Monday", startedAt: .now.addingTimeInterval(-600),
            completedAt: .now, duration: 600, effort: 3, notes: "Local", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        repository.completedWorkouts = [workout]
        var edited = workout
        edited.name = "Remote edit"
        edited.notes = "Updated elsewhere"
        try await service.uploadCompletedWorkout(CompletedWorkoutSnapshot(
            id: edited.id,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(edited),
            completedAt: edited.completedAt
        ))

        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(repository.completedWorkouts, [edited])
    }

    @MainActor
    func testWorkoutSyncStoreClearsHistoryAndQueuesForANewAccount() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workout = CompletedWorkout(
            id: UUID(),
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            name: "Freestyle Workout",
            dayLabel: "Friday",
            startedAt: .now.addingTimeInterval(-600),
            completedAt: .now,
            duration: 600,
            effort: 3,
            notes: "Private history",
            gymID: nil,
            bodyweight: nil,
            unit: .pounds,
            exercises: [],
            sets: [],
            linkedSubmissionIDs: []
        )
        repository.completedWorkouts = [workout]
        repository.pendingCompletedWorkoutUploads = [CompletedWorkoutSnapshot(
            id: workout.id,
            ownerID: repository.currentProfile.id,
            payload: Data("old-account".utf8),
            completedAt: workout.completedAt
        )]
        repository.deletedCompletedWorkoutIDs = [workout.id]
        repository.workoutFeedback = [WorkoutFeedback(
            id: UUID(), sessionID: UUID(), completedAt: .now, effort: 4, notes: "Old account"
        )]
        repository.workoutEntries = [WorkoutExerciseEntry(
            id: UUID(), planID: UUID(), week: 1, date: .now, day: "Monday", workout: "Private",
            exercise: "Bench Press", muscleGroup: "Chest", targetSets: 3, targetReps: "5",
            sets: [], isDone: true, notes: "Old account"
        )]
        repository.workoutSetLogs = [WorkoutSetLog(
            id: UUID(), prescriptionID: UUID(), performedAt: .now, setNumber: 1,
            weight: 225, reps: 5, rpe: nil, isWarmup: false, isComplete: true,
            workoutID: nil, recordedUnit: .pounds
        )]
        let customPlan = WorkoutPlan(id: UUID(), name: "Private plan", createdAt: .now)
        repository.addWorkoutPlan(customPlan)
        repository.pendingRemoteWorkoutPlanDeletions = [customPlan.id]

        repository.currentProfile.id = UUID()
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertTrue(repository.pendingCompletedWorkoutUploads.isEmpty)
        XCTAssertTrue(repository.deletedCompletedWorkoutIDs.isEmpty)
        XCTAssertTrue(repository.workoutFeedback.isEmpty)
        XCTAssertTrue(repository.workoutEntries.isEmpty)
        XCTAssertTrue(repository.workoutSetLogs.isEmpty)
        XCTAssertFalse(repository.workoutPlans.contains { $0.id == customPlan.id })
        XCTAssertTrue(repository.pendingRemoteWorkoutPlanDeletions.isEmpty)
        let remote = try await service.completedWorkouts(since: nil)
        XCTAssertTrue(remote.isEmpty)
    }

    @MainActor
    func testWorkoutSyncStoreDoesNotDeletePreviousUsersSnapshotAfterAccountSwitch() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let snapshot = CompletedWorkoutSnapshot(
            id: UUID(), ownerID: repository.currentProfile.id, payload: Data("old-account".utf8), completedAt: .now
        )
        try await service.uploadCompletedWorkout(snapshot)
        repository.deletedCompletedWorkoutIDs = [snapshot.id]

        repository.currentProfile.id = UUID()
        await store.synchronizeDeletedCompletedWorkout(id: snapshot.id)

        let remainingSnapshots = try await service.completedWorkouts(since: nil)
        XCTAssertEqual(remainingSnapshots.map(\.id), [snapshot.id])
    }

    @MainActor
    func testWorkoutSyncStoreDoesNotApplyPreviousUsersHistoryResponse() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Old account workout", dayLabel: "Monday", startedAt: .now,
            completedAt: .now, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        let snapshot = CompletedWorkoutSnapshot(
            id: workout.id, ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(workout), completedAt: workout.completedAt
        )
        let service = GatedCompletedWorkoutSyncService(snapshots: [snapshot])
        let store = WorkoutSyncStore(repository: repository, service: service)
        let sync = Task { await store.synchronizeCompletedWorkoutHistory() }

        while !service.requestStarted {
            await Task.yield()
        }
        repository.currentProfile.id = UUID()
        service.release()
        await sync.value

        XCTAssertTrue(repository.completedWorkouts.isEmpty)
    }

    @MainActor
    func testWorkoutSyncStoreIgnoresHistoryOwnedByAnotherAccount() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Other account workout", dayLabel: "Monday", startedAt: .now,
            completedAt: .now, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        let snapshot = CompletedWorkoutSnapshot(
            id: workout.id, ownerID: UUID(),
            payload: try JSONEncoder().encode(workout), completedAt: workout.completedAt
        )
        let service = MockWorkoutSyncService()
        try await service.uploadCompletedWorkout(snapshot)
        let store = WorkoutSyncStore(repository: repository, service: service)

        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(repository.completedWorkouts.isEmpty)
    }

    @MainActor
    func testWorkoutSyncStoreDoesNotApplyPreviousUsersPlanResponse() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let plan = WorkoutPlan(id: UUID(), name: "Old account plan", createdAt: .now)
        let payload = try JSONEncoder().encode(WorkoutPlanSyncPayload(
            plan: plan, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
        ))
        let document = WorkoutPlanDocument(
            id: plan.id, ownerID: repository.currentProfile.id, revision: 1,
            name: plan.name, payload: payload, updatedAt: .now
        )
        let service = GatedWorkoutPlanSyncService(documents: [document])
        let store = WorkoutSyncStore(repository: repository, service: service)
        let sync = Task { await store.synchronizeWorkoutPlans() }

        while !service.requestStarted {
            await Task.yield()
        }
        repository.currentProfile.id = UUID()
        service.release()
        await sync.value

        XCTAssertFalse(repository.workoutPlans.contains { $0.id == plan.id })
    }

    @MainActor
    func testWorkoutSyncStoreIgnoresPlanOwnedByAnotherAccount() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let plan = WorkoutPlan(id: UUID(), name: "Other account plan", createdAt: .now)
        let payload = try JSONEncoder().encode(WorkoutPlanSyncPayload(
            plan: plan, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
        ))
        let document = WorkoutPlanDocument(
            id: plan.id, ownerID: UUID(), revision: 1, name: plan.name,
            payload: payload, updatedAt: .now
        )
        let service = MockWorkoutSyncService()
        guard case .saved(_) = try await service.savePlan(document, expectedRevision: 0) else {
            return XCTFail("Expected plan fixture to be saved")
        }
        let store = WorkoutSyncStore(repository: repository, service: service)

        await store.synchronizeWorkoutPlans()

        XCTAssertFalse(repository.workoutPlans.contains { $0.id == plan.id })
    }

    @MainActor
    func testWorkoutSyncStoreDoesNotRestoreDeletedCompletedWorkout() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workout = CompletedWorkout(
            id: UUID(),
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            name: "Freestyle Workout",
            dayLabel: "Friday",
            startedAt: .now.addingTimeInterval(-600),
            completedAt: .now,
            duration: 600,
            effort: 3,
            notes: "",
            gymID: nil,
            bodyweight: nil,
            unit: .pounds,
            exercises: [],
            sets: [],
            linkedSubmissionIDs: []
        )
        let snapshot = CompletedWorkoutSnapshot(
            id: workout.id,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(workout),
            completedAt: workout.completedAt
        )
        try await service.uploadCompletedWorkout(snapshot)

        repository.completedWorkouts = [workout]
        repository.deleteCompletedWorkout(workout)
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertFalse(repository.deletedCompletedWorkoutIDs.contains(workout.id))
    }

    @MainActor
    func testWorkoutSyncStoreAppliesServerPlanAndCreatesLabeledConflictCopy() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let plan = WorkoutPlan(
            id: UUID(),
            name: "Local Strength",
            createdAt: .now,
            goal: "Strength",
            notes: "",
            isActive: false
        )
        repository.addWorkoutPlan(plan)
        await store.synchronizeWorkoutPlans()

        let serverPlans = try await service.plans()
        var serverDocument = try XCTUnwrap(serverPlans.first { $0.id == plan.id })
        guard case let .saved(serverRevision) = try await service.savePlan(
            serverDocument,
            expectedRevision: serverDocument.revision
        ) else { return XCTFail("Expected server-side revision") }
        serverDocument = serverRevision

        var localEdit = try XCTUnwrap(repository.workoutPlans.first { $0.id == plan.id })
        localEdit.name = "Local Strength Edited"
        repository.updateWorkoutPlan(localEdit)
        await store.synchronizeWorkoutPlans()

        XCTAssertEqual(repository.workoutPlanSyncRevisions[plan.id], serverDocument.revision)
        XCTAssertTrue(repository.workoutPlans.contains { $0.id == plan.id && $0.name == "Local Strength" })
        let conflict = try XCTUnwrap(repository.workoutPlans.first { $0.name == "Local Strength Edited (Conflict copy)" })
        XCTAssertNotEqual(conflict.id, plan.id)
        XCTAssertNotNil(repository.workoutPlanSyncRevisions[conflict.id])
    }

    @MainActor
    func testWorkoutSyncRetriesFailedRemotePlanDeletion() async throws {
        let persistence = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        let service = MockWorkoutSyncService()
        let plan = WorkoutPlan(id: UUID(), name: "Remote Plan", createdAt: .now, goal: "Strength", notes: "", isActive: false)
        repository.addWorkoutPlan(plan)
        await WorkoutSyncStore(repository: repository, service: service).synchronizeWorkoutPlans()
        service.failNextPlanDeletion = true

        let store = WorkoutSyncStore(repository: repository, service: service)
        repository.deleteWorkoutPlan(plan)
        await store.deleteRemotePlan(plan.id)

        XCTAssertEqual(repository.pendingRemoteWorkoutPlanDeletions, Set([plan.id]))
        let restoredRepository = DemoRepository(workoutPersistenceStore: persistence)
        XCTAssertEqual(restoredRepository.pendingRemoteWorkoutPlanDeletions, Set([plan.id]))
        await WorkoutSyncStore(repository: restoredRepository, service: service).synchronizeWorkoutPlans()
        XCTAssertTrue(restoredRepository.pendingRemoteWorkoutPlanDeletions.isEmpty)
        let remainingPlans = try await service.plans()
        XCTAssertFalse(remainingPlans.contains { $0.id == plan.id })
    }

    @MainActor
    func testWorkoutSyncStoreDoesNotClearTheNextAccountsPlanQueueAfterAccountSwitch() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = GatedWorkoutPlanDeletionService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let previousAccountPlanID = UUID()
        let nextAccountPlanID = UUID()

        let deletion = Task { await store.deleteRemotePlan(previousAccountPlanID) }
        while !service.requestStarted {
            await Task.yield()
        }
        repository.currentProfile.id = UUID()
        repository.pendingRemoteWorkoutPlanDeletions = [nextAccountPlanID]
        service.release()
        await deletion.value

        XCTAssertEqual(repository.pendingRemoteWorkoutPlanDeletions, Set([nextAccountPlanID]))
    }

    func testCompletedWorkoutUploadIsIdempotentAndRejectsSeededData() async throws {
        let service = MockWorkoutSyncService()
        let snapshot = CompletedWorkoutSnapshot(
            id: UUID(), ownerID: session.userID, payload: Data("workout".utf8), completedAt: .now
        )
        try await service.uploadCompletedWorkout(snapshot)
        try await service.uploadCompletedWorkout(snapshot)
        let firstUpload = try await service.completedWorkouts(since: nil)
        XCTAssertEqual(firstUpload.count, 1)

        var seeded = snapshot
        seeded.id = UUID()
        seeded.isSeededDemoData = true
        try await service.uploadCompletedWorkout(seeded)
        let afterSeededUpload = try await service.completedWorkouts(since: nil)
        XCTAssertEqual(afterSeededUpload.count, 1)
    }

    private let session = AccountSession(
        userID: UUID(uuidString: "90000000-0000-0000-0000-000000000001")!,
        email: "member@example.test",
        expiresAt: .now.addingTimeInterval(3600)
    )

    private func makeState(session: AccountSession?, onboardingCompleted: Bool, hasCurrentLegalAcceptance: Bool = true) -> AppState {
        makeState(authentication: TestAuthenticationService(session: session), onboardingCompleted: onboardingCompleted, hasCurrentLegalAcceptance: hasCurrentLegalAcceptance)
    }

    private func makeState(authentication: any AuthenticationService, onboardingCompleted: Bool, hasCurrentLegalAcceptance: Bool = true) -> AppState {
        let repository = DemoRepository()
        let profile = TestProfileService(profile: AuthenticatedProfile(
            id: session.userID, username: "member_test", displayName: "Member Test", bio: "",
            avatarPath: nil, onboardingCompleted: onboardingCompleted, preferredUnit: .pounds,
            birthDate: nil, sexCategory: .open, heightCentimeters: nil, city: nil, region: nil,
            countryCode: nil, yearsExperience: nil, experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        return AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: authentication,
            profile: profile,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestLegalAcceptanceService(userID: session.userID, accepted: hasCurrentLegalAcceptance)
        ))
    }
}

@MainActor
private struct FailingGymService: GymService {
    func gyms() async throws -> [Gym] {
        throw LiftRankServiceError.server("Simulated gym refresh failure")
    }

    func memberships() async throws -> [GymMembershipRecord] {
        throw LiftRankServiceError.server("Simulated membership refresh failure")
    }
}

@MainActor
private final class GatedGymService: GymService {
    var requestStarted = false
    private let gym: Gym
    private var continuation: CheckedContinuation<[Gym], Never>?

    init(gym: Gym) {
        self.gym = gym
    }

    func gyms() async throws -> [Gym] {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func memberships() async throws -> [GymMembershipRecord] { [] }

    func release() {
        continuation?.resume(returning: [gym])
        continuation = nil
    }
}

@MainActor
private final class GatedBlockService: SocialService {
    let blockedID: UUID
    var requestStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(blockedID: UUID) {
        self.blockedID = blockedID
    }

    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] { [] }

    func block(userID: UUID) async throws {
        requestStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func unblock(userID: UUID) async throws {}

    func blocks() async throws -> [UserBlockRecord] {
        [UserBlockRecord(blockerID: UUID(), blockedID: blockedID, createdAt: .now)]
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class GatedFailingBlocksService: SocialService {
    var requestStarted = false
    var shouldGate = false
    let returnedBlocks = [UserBlockRecord(blockerID: UUID(), blockedID: UUID(), createdAt: .now)]
    private var continuation: CheckedContinuation<[UserBlockRecord], Error>?

    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] { [] }
    func block(userID: UUID) async throws {}
    func unblock(userID: UUID) async throws {}

    func blocks() async throws -> [UserBlockRecord] {
        guard shouldGate else { return returnedBlocks }
        requestStarted = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func releaseWithFailure() {
        continuation?.resume(throwing: LiftRankServiceError.server("Simulated blocks refresh failure"))
        continuation = nil
    }
}

@MainActor
private final class GatedAthleteSearchService: SocialService {
    let card: PublicProfileCard
    var requestStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(card: PublicProfileCard) {
        self.card = card
    }

    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] {
        requestStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return [card]
    }

    func block(userID: UUID) async throws {}
    func unblock(userID: UUID) async throws {}
    func blocks() async throws -> [UserBlockRecord] { [] }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class GatedCompletedWorkoutUploadService: WorkoutSyncService {
    var requestStarted = false
    private var snapshots: [CompletedWorkoutSnapshot] = []
    private var continuation: CheckedContinuation<Void, Never>?

    func plans() async throws -> [WorkoutPlanDocument] { [] }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws {}
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { snapshots }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        requestStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)
    }
    func deleteCompletedWorkout(id: UUID) async throws {}

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class GatedCompletedWorkoutSyncService: WorkoutSyncService {
    var requestStarted = false
    private let snapshotsToReturn: [CompletedWorkoutSnapshot]
    private var continuation: CheckedContinuation<[CompletedWorkoutSnapshot], Never>?

    init(snapshots: [CompletedWorkoutSnapshot]) {
        snapshotsToReturn = snapshots
    }

    func plans() async throws -> [WorkoutPlanDocument] { [] }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws {}

    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume(returning: snapshotsToReturn)
        continuation = nil
    }

    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {}
    func deleteCompletedWorkout(id: UUID) async throws {}
}

@MainActor
private final class GatedWorkoutPlanSyncService: WorkoutSyncService {
    var requestStarted = false
    private let documentsToReturn: [WorkoutPlanDocument]
    private var continuation: CheckedContinuation<[WorkoutPlanDocument], Never>?

    init(documents: [WorkoutPlanDocument]) {
        documentsToReturn = documents
    }

    func plans() async throws -> [WorkoutPlanDocument] {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume(returning: documentsToReturn)
        continuation = nil
    }

    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws {}
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { [] }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {}
    func deleteCompletedWorkout(id: UUID) async throws {}
}

@MainActor
private final class GatedWorkoutPlanDeletionService: WorkoutSyncService {
    var requestStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    func plans() async throws -> [WorkoutPlanDocument] { [] }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws {
        requestStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
    func release() {
        continuation?.resume()
        continuation = nil
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { [] }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {}
    func deleteCompletedWorkout(id: UUID) async throws {}
}

@MainActor
private struct TestLegalAcceptanceService: LegalAcceptanceService {
    let userID: UUID
    let accepted: Bool

    func acceptances() async throws -> [LegalAcceptanceRecord] {
        guard accepted else { return [] }
        return LegalDocument.current.map {
            LegalAcceptanceRecord(
                id: UUID(), userID: userID, documentKind: $0.kind.rawValue,
                documentVersion: $0.version, acceptedAt: .now
            )
        }
    }

    func accept(documents: [LegalDocument]) async throws {}
}

@MainActor
private final class TestAuthenticationService: AuthenticationService {
    var isConfigured: Bool { true }
    var isDemoMode: Bool { false }
    var session: AccountSession?
    let restoreError: Error?
    init(session: AccountSession?, restoreError: Error? = nil) {
        self.session = session
        self.restoreError = restoreError
    }
    func restoreSession() async throws -> AccountSession? {
        if let restoreError { throw restoreError }
        return session
    }
    func signUp(email: String, password: String) async throws -> AccountSession { try XCTUnwrap(session) }
    func signIn(email: String, password: String) async throws -> AccountSession { try XCTUnwrap(session) }
    func requestPasswordReset(email: String) async throws {}
    func signInDemo() async throws -> UserProfile { MockData.demoProfile }
    func signOut() async throws { session = nil }
}

@MainActor
private final class TestProfileService: ProfileService {
    var profile: AuthenticatedProfile
    var authenticatedProfileError: Error?
    var holdAuthenticatedProfile = false
    private(set) var authenticatedProfileStarted = false
    private var authenticatedProfileRelease: CheckedContinuation<Void, Never>?
    var saveProfileResponse: AuthenticatedProfile?
    private(set) var lastSavedProfileDraft: ProfileDraft?
    var avatarDownload: ProfileAvatarDownload?
    var uploadedAvatarReturnPath: String?
    private(set) var saveProfileCount = 0
    private(set) var updateProfileCount = 0
    private(set) var uploadedAvatarPaths: [String] = []
    private(set) var downloadedAvatarPaths: [String] = []
    private(set) var removedAvatarPaths: [String?] = []
    private(set) var savedBodyweightEntries: [BodyweightEntry] = []
    var bodyweightSyncError: Error?
    var holdBodyweightSave = false
    private(set) var bodyweightSaveStarted = false
    private var bodyweightSaveRelease: CheckedContinuation<Void, Never>?
    var holdAvatarUpload = false
    private(set) var avatarUploadStarted = false
    private var avatarUploadRelease: CheckedContinuation<Void, Never>?
    var holdAvatarDownload = false
    private(set) var avatarDownloadStarted = false
    private var avatarDownloadRelease: CheckedContinuation<Void, Never>?
    init(profile: AuthenticatedProfile) { self.profile = profile }
    func authenticatedProfile() async throws -> AuthenticatedProfile {
        if let authenticatedProfileError { throw authenticatedProfileError }
        if holdAuthenticatedProfile {
            authenticatedProfileStarted = true
            await withCheckedContinuation { continuation in
                authenticatedProfileRelease = continuation
            }
        }
        return profile
    }
    func releaseAuthenticatedProfile() {
        authenticatedProfileRelease?.resume()
        authenticatedProfileRelease = nil
    }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        saveProfileCount += 1
        lastSavedProfileDraft = draft
        profile.username = draft.username
        profile.displayName = draft.displayName
        profile.bio = draft.bio
        profile.preferredUnit = draft.preferredUnit
        profile.birthDate = draft.birthDate
        profile.sexCategory = draft.sexCategory
        profile.heightCentimeters = draft.heightCentimeters
        profile.bodyweightPounds = draft.bodyweightPounds
        profile.cityID = draft.cityID
        profile.city = draft.city
        profile.region = draft.region
        profile.countryCode = draft.countryCode
        profile.yearsExperience = draft.yearsExperience
        profile.experienceLevel = draft.experienceLevel
        profile.avatarPath = draft.avatarPath
        profile.privacy = draft.privacy
        profile.onboardingCompleted = draft.completesOnboarding
        if let saveProfileResponse {
            profile = saveProfileResponse
        }
        return profile
    }
    func claimUsername(_ username: String) async throws -> String { username }
    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        PublicProfileCard(id: userID, username: profile.username, displayName: profile.displayName, bio: profile.bio, avatarPath: nil, ageBand: nil, sexCategory: profile.sexCategory, city: nil, region: nil, countryCode: nil, primaryGymID: nil, primaryGymName: nil)
    }
    func currentProfile() async throws -> UserProfile { MockData.demoProfile }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        updateProfileCount += 1
        self.profile.username = profile.username
        self.profile.displayName = profile.displayName
        self.profile.avatarPath = profile.avatarPath
        self.profile.preferredUnit = profile.preferredUnit
        self.profile.sexCategory = profile.sexCategory
        self.profile.heightCentimeters = profile.heightInches * 2.54
        self.profile.bodyweightPounds = profile.bodyweightPounds
        self.profile.cityID = profile.cityID
        self.profile.city = profile.city
        self.profile.region = profile.state
        self.profile.yearsExperience = profile.yearsExperience
        self.profile.experienceLevel = profile.experienceLevel
        self.profile.privacy.bodyweightAudience = profile.hideBodyweight ? .privateProfile : .publicProfile
        return profile
    }
    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String {
        uploadedAvatarPaths.append(avatarPath)
        if holdAvatarUpload {
            avatarUploadStarted = true
            await withCheckedContinuation { continuation in
                avatarUploadRelease = continuation
            }
        }
        return uploadedAvatarReturnPath ?? avatarPath
    }
    func releaseAvatarUpload() {
        avatarUploadRelease?.resume()
        avatarUploadRelease = nil
    }
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? {
        downloadedAvatarPaths.append(avatarPath)
        if holdAvatarDownload {
            avatarDownloadStarted = true
            await withCheckedContinuation { continuation in
                avatarDownloadRelease = continuation
            }
        }
        return avatarDownload
    }
    func releaseAvatarDownload() {
        avatarDownloadRelease?.resume()
        avatarDownloadRelease = nil
    }
    func removeProfileAvatar(avatarPath: String?) async throws {
        removedAvatarPaths.append(avatarPath)
    }
    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry] {
        if let bodyweightSyncError { throw bodyweightSyncError }
        return localEntries
    }
    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws {
        if holdBodyweightSave {
            bodyweightSaveStarted = true
            await withCheckedContinuation { continuation in
                bodyweightSaveRelease = continuation
            }
        }
        savedBodyweightEntries.removeAll { $0.id == entry.id }
        savedBodyweightEntries.append(entry)
    }
    func releaseBodyweightSave() {
        bodyweightSaveRelease?.resume()
        bodyweightSaveRelease = nil
    }
}
