import XCTest
import SwiftData
import UIKit
import AVFoundation
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
    var registrationError: Error?
    func notifications() async throws -> [NotificationItem] { [] }
    func markRead(notificationID: UUID) async throws {}
    func registerDevice(_ registration: PushDeviceRegistration) async throws {
        if let registrationError { throw registrationError }
        registrations.append(registration)
    }
    func revokeDevice(deviceID: String) async throws { revokedDeviceIDs.append(deviceID) }
}

@MainActor
private final class GatedNotificationService: NotificationService {
    var requestStarted = false
    var shouldFail = false
    private let notificationsToReturn: [NotificationItem]
    private var continuation: CheckedContinuation<Void, Never>?

    init(notifications: [NotificationItem]) {
        notificationsToReturn = notifications
    }

    func notifications() async throws -> [NotificationItem] {
        requestStarted = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
        }
        if shouldFail { throw LiftRankServiceError.server("Simulated notification refresh failure") }
        return notificationsToReturn
    }

    func release() {
        continuation?.resume()
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
    func testBundledCitySearchSupportsRepresentativeCountriesAndRegions() async throws {
        let service = BundledLocationService()
        let cases = [
            (country: "US", region: "Florida", query: "mi", expectedCity: "Miami"),
            (country: "US", region: "Florida", query: "cut", expectedCity: "Cutler Bay"),
            (country: "US", region: "Florida", query: "hom", expectedCity: "Homestead"),
            (country: "CA", region: "Ontario", query: "tor", expectedCity: "Toronto"),
            (country: "GB", region: "England", query: "lon", expectedCity: "London"),
            (country: "AU", region: "Victoria", query: "mel", expectedCity: "Melbourne"),
            (country: "ZA", region: "Gauteng", query: "joh", expectedCity: "Johannesburg")
        ]

        for testCase in cases {
            let results = try await service.searchCities(
                countryCode: testCase.country,
                region: testCase.region,
                query: testCase.query,
                limit: 20
            )

            XCTAssertLessThanOrEqual(results.count, 20)
            XCTAssertTrue(results.contains(where: { $0.city == testCase.expectedCity }))
            XCTAssertTrue(results.allSatisfy {
                $0.countryCode == testCase.country && $0.region == testCase.region
            })
        }
    }

    func testBundledCitySearchDoesNotLeakAcrossRegions() async throws {
        let service = BundledLocationService()
        let results = try await service.searchCities(
            countryCode: "US",
            region: "Florida",
            query: "or",
            limit: 20
        )

        XCTAssertEqual(results.map(\.city), ["Orlando"])
    }

    func testPrivacyAudienceMatchesServerContract() throws {
        XCTAssertEqual(PrivacyAudience(rawValue: "public"), .publicProfile)
        XCTAssertEqual(PrivacyAudience(rawValue: "friends"), .friends)
        XCTAssertEqual(PrivacyAudience(rawValue: "gym"), .gym)
        XCTAssertEqual(PrivacyAudience(rawValue: "private"), .privateProfile)
        let defaults = ProfilePrivacySettings()
        XCTAssertEqual(defaults.profileAudience, .publicProfile)
        XCTAssertEqual(defaults.ageBandAudience, .publicProfile)
        XCTAssertEqual(defaults.bodyweightAudience, .publicProfile)
        XCTAssertEqual(defaults.locationAudience, .publicProfile)
        XCTAssertEqual(defaults.gymAudience, .publicProfile)
        XCTAssertTrue(defaults.showLiftVideos)
    }
    func testLiftVideoDurationPolicyAllowsThirtySecondsAndRejectsLongerClips() {
        XCTAssertTrue(LiftVideoPolicy.allows(duration: 30))
        XCTAssertFalse(LiftVideoPolicy.allows(duration: 30.001))
        XCTAssertFalse(LiftVideoPolicy.allows(duration: .infinity))
    }

    func testProfileThumbnailLoadsFromDiskWithoutRenderPathIO() async throws {
        let userID = UUID()
        let store = LocalProfilePhotoStore.shared
        let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle.fill"))
        let avatarPath = try await store.save(image: image, userID: userID, mode: .demo)

        store.clearMemoryCache()
        XCTAssertNil(store.cachedThumbnail(for: avatarPath))

        let loaded = await store.loadThumbnail(for: avatarPath)

        XCTAssertNotNil(loaded)
        XCTAssertNotNil(store.cachedThumbnail(for: avatarPath))
        store.remove(avatarPath: avatarPath)
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


    func testFocusedLaunchSourceDoesNotContainGymRankPlaceholders() {
        XCTAssertEqual(CanonicalRankingPresentation.text(rank: nil), "—")
        XCTAssertEqual(CanonicalRankingPresentation.text(rank: 12), "#12")
        XCTAssertFalse(CanonicalRankingPresentation.text(rank: nil).contains("Gym #"))
    }

    func testLeaderboardCurrentUserBadgeDoesNotUseDemoIdentity() {
        let activeProfileID = UUID()

        XCTAssertTrue(LeaderboardIdentityPresentation.isCurrentUser(
            entryProfileID: activeProfileID,
            activeProfileID: activeProfileID
        ))
        XCTAssertFalse(LeaderboardIdentityPresentation.isCurrentUser(
            entryProfileID: MockData.demoUserID,
            activeProfileID: activeProfileID
        ))
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
            sexCategory: .male,
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
            sexCategory: .male, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
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
            sexCategory: .male,
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

        await appState.saveProfilePhoto(image)
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
            sexCategory: .male,
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
        let avatarPath = try await LocalProfilePhotoStore.shared.save(
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
            sexCategory: .male,
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
            sexCategory: .male, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
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

        await appState.saveProfilePhoto(image)
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
            sexCategory: .male, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
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

        await appState.saveProfilePhoto(image)
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
            sexCategory: .male, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
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




    func testGymOvertakeAndFriendNotificationDestinationsDecodeAndRoute() throws {
        let gymID = UUID()
        let payload: [String: Any] = ["kind": "leaderboard", "gymID": gymID.uuidString,
            "exerciseID": "barbell_bench_press", "rankingType": "Absolute",
            "ageGroup": "35–44", "sexCategory": "Male", "videoBackedOnly": true]
        let destination = try JSONDecoder().decode(NotificationDestination.self,
            from: JSONSerialization.data(withJSONObject: payload))
        let store = NotificationStore(repository: DemoRepository())
        guard case .leaderboard(let filters) = store.route(for: destination) else {
            return XCTFail("Expected gym ranking")
        }
        XCTAssertEqual(filters.gymID, gymID)
        XCTAssertEqual(filters.ageGroup, "35–44")
        XCTAssertEqual(filters.sexCategory, .male)
        XCTAssertEqual(filters.verificationLevel, .videoVerified)
        XCTAssertEqual(filters.rankingType, .absolute)
        XCTAssertEqual(filters.exerciseID, "barbell_bench_press")
        let friendDestination = try JSONDecoder().decode(NotificationDestination.self,
            from: Data(#"{"kind":"friendRequests"}"#.utf8))
        XCTAssertEqual(store.route(for: friendDestination), .friendRequests)
    }

    func testSuggestedRivalsCompareBestPublicLiftsAndRespectPrivacy() throws {
        let repository = DemoRepository()
        repository.seedDemoLeaderboardDataIfNeeded()
        let appState = AppState(repository: repository)
        var own = repository.currentProfile
        own.trainingFocus = nil
        own.ageGroup = "25–34"
        repository.currentProfile = own
        var close = own
        close.id = UUID()
        close.username = "close"
        close.hideExactAge = false
        var far = close
        far.id = UUID()
        far.username = "far"
        var privateProfile = close
        privateProfile.id = UUID()
        privateProfile.profileAudience = .privateProfile
        repository.profiles = [own, far, close, privateProfile]
        var base = try XCTUnwrap(repository.lifts.first)
        base.id = UUID()
        base.userID = own.id
        base.visibility = .publicLift
        base.moderationStatus = .clear
        base.normalizedWeightKilograms = 100
        var nearLift = base
        nearLift.id = UUID()
        nearLift.userID = close.id
        nearLift.normalizedWeightKilograms = 105
        var farLift = nearLift
        farLift.id = UUID()
        farLift.userID = far.id
        farLift.normalizedWeightKilograms = 160
        var oldFarLift = farLift
        oldFarLift.id = UUID()
        oldFarLift.normalizedWeightKilograms = 100
        repository.lifts = [base, nearLift, oldFarLift, farLift]

        let rivals = appState.suggestedTrainingRivals
        XCTAssertEqual(rivals.first?.profile.id, close.id)
        XCTAssertTrue(try XCTUnwrap(rivals.first).reason.contains("Similar"))
        XCTAssertFalse(rivals.contains { $0.profile.id == own.id || $0.profile.id == privateProfile.id })
        XCTAssertEqual(rivals.first { $0.profile.id == far.id }?.reason, "Same age group")

        nearLift.visibility = .privateLift
        close.hideExactAge = true
        repository.lifts = [base, nearLift]
        repository.profiles = [own, close]
        XCTAssertTrue(appState.suggestedTrainingRivals.isEmpty)
    }

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
        XCTAssertEqual(filters.gymID, gymID)
        XCTAssertEqual(filters.rankingType, .poundForPound)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(try XCTUnwrap(store.notifications.first).isRead)
    }

    func testForumReplyNotificationRoutesToExactPost() throws {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository)
        let postID = UUID()
        let notification = NotificationItem(
            id: UUID(), title: "New reply", message: "A lifter replied.", kind: "forum_reply",
            createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .forumPost, targetID: postID)
        )

        let route = store.open(notification)

        guard case .forumPost(let routedPostID, let routedCommentID) = route else {
            return XCTFail("Expected a forum-post route")
        }
        XCTAssertEqual(routedPostID, postID)
        XCTAssertNil(routedCommentID)
    }

    func testForumReplyNotificationCarriesExactCommentTarget() throws {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository)
        let postID = UUID()
        let commentID = UUID()
        let notification = NotificationItem(
            id: UUID(), title: "New reply", message: "A lifter replied.", kind: "forum_reply",
            createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .forumPost, targetID: postID, commentID: commentID)
        )

        let route = store.open(notification)

        guard case .forumPost(let routedPostID, let routedCommentID) = route else {
            return XCTFail("Expected a forum-post route")
        }
        XCTAssertEqual(routedPostID, postID)
        XCTAssertEqual(routedCommentID, commentID)
    }

    func testForumStoreVoteToggleTracksDirectionAndRejectsInvalidAction() async throws {
        let service = MockForumService(repository: DemoRepository())
        let store = ForumStore(service: service)
        let post = try await store.createPost(ForumPostDraft(
            communityID: UUID(), kind: "Discussion", title: "Vote test", body: "Body",
            tag: nil, liftID: nil
        ))

        let upvoted = try await store.toggleVote(on: post, direction: 1)
        XCTAssertEqual(upvoted.voteCount, 1)
        XCTAssertEqual(upvoted.currentUserVote, 1)

        let switched = try await store.toggleVote(on: upvoted, direction: -1)
        XCTAssertEqual(switched.voteCount, -1)
        XCTAssertEqual(switched.currentUserVote, -1)

        let cleared = try await store.toggleVote(on: switched, direction: -1)
        XCTAssertEqual(cleared.voteCount, 0)
        XCTAssertNil(cleared.currentUserVote)

        do {
            _ = try await store.toggleVote(on: cleared, direction: 0)
            XCTFail("An unsupported vote direction should be rejected")
        } catch let error as LiftRankServiceError {
            XCTAssertEqual(error, .invalidInput("Choose an upvote or downvote."))
        }
    }

    func testForumDemoMediaFixturesResolveAndPhotoPreparationNormalizesToJPEG() async throws {
        let service = MockForumService(repository: DemoRepository())
        let posts = try await service.posts(communityID: nil, limit: 20, offset: 0)
        let photo = try XCTUnwrap(posts.first { $0.title == "Photo test · Lift Rivals" }?.attachments.first)
        let video = try XCTUnwrap(posts.first { $0.title == "Video test · Workout screen" }?.attachments.first)
        XCTAssertEqual(photo.kind.rawValue, ForumAttachment.Kind.photo.rawValue)
        XCTAssertEqual(video.kind.rawValue, ForumAttachment.Kind.video.rawValue)

        let photoURL = try await service.mediaURL(for: photo)
        let videoURL = try await service.mediaURL(for: video)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path))
        XCTAssertEqual(videoURL.pathExtension.lowercased(), "mp4")
        let videoAsset = AVURLAsset(url: videoURL)
        let videoDuration = videoAsset.duration.seconds
        let audioTracks = videoAsset.tracks(withMediaType: AVMediaType.audio)
        XCTAssertEqual(videoDuration, 6, accuracy: 0.1)
        XCTAssertEqual(audioTracks.count, 0)

        let preparedPhoto = try await ForumMediaPreparation.prepare(photoURL, kind: .photo)
        defer { try? FileManager.default.removeItem(at: preparedPhoto.fileURL) }
        XCTAssertEqual(preparedPhoto.fileURL.pathExtension, "jpg")
        XCTAssertEqual(preparedPhoto.contentType, "image/jpeg")
        let preparedSize = try preparedPhoto.fileURL.resourceValues(forKeys: Set<URLResourceKey>([.fileSizeKey])).fileSize ?? 0
        XCTAssertGreaterThan(preparedSize, 0)
        XCTAssertLessThanOrEqual(preparedSize, 10 * 1_024 * 1_024)
        XCTAssertNotNil(UIImage(contentsOfFile: preparedPhoto.fileURL.path))
    }

    func testForumMediaPostRetryEditAndDeletePreserveAndCleanUpTheUpload() async throws {
        let service = MockForumService(repository: DemoRepository())
        let seedPosts = try await service.posts(communityID: nil, limit: 20, offset: 0)
        let photo = try XCTUnwrap(seedPosts.first { $0.title == "Photo test · Lift Rivals" }?.attachments.first)
        let sourceURL = try await service.mediaURL(for: photo)
        let prepared = try await ForumMediaPreparation.prepare(sourceURL, kind: .photo)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }

        let postID = UUID()
        let draft = ForumPostDraft(
            id: postID, communityID: try XCTUnwrap(seedPosts.first?.communityID), kind: "Discussion",
            title: "Media retry test", body: "Photo attachment", tag: nil, liftID: nil, media: prepared
        )
        let created = try await service.createPost(draft)
        let attachment = try XCTUnwrap(created.attachments.first)
        XCTAssertEqual(attachment.kind.rawValue, ForumAttachment.Kind.photo.rawValue)
        let uploadedURL = try await service.mediaURL(for: attachment)
        defer { try? FileManager.default.removeItem(at: uploadedURL) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: uploadedURL.path))

        try FileManager.default.removeItem(at: prepared.fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.fileURL.path))
        let retried = try await service.createPost(draft)
        XCTAssertEqual(retried.id, postID)
        XCTAssertEqual(retried.attachments, created.attachments)
        let afterRetry = try await service.posts(communityID: draft.communityID, limit: 20, offset: 0)
        let matchingPosts = afterRetry.filter { $0.id == postID }
        XCTAssertEqual(matchingPosts.count, 1)

        let edited = try await service.updatePost(postID: postID, title: "Edited media post", body: "Text changed")
        XCTAssertEqual(edited.attachments, created.attachments)
        XCTAssertTrue(FileManager.default.fileExists(atPath: uploadedURL.path))

        try await service.deletePost(postID: postID)
        let deletedThread = try await service.thread(postID: postID)
        XCTAssertNil(deletedThread)
        XCTAssertFalse(FileManager.default.fileExists(atPath: uploadedURL.path), "Deleting the post should remove its demo media copy")
    }

    func testForumPhotoPreparationRejectsAnUnreadableImage() async throws {
        let unreadable = FileManager.default.temporaryDirectory.appendingPathComponent("forum-invalid-photo-\(UUID().uuidString).txt")
        try Data("not an image".utf8).write(to: unreadable)
        defer { try? FileManager.default.removeItem(at: unreadable) }

        do {
            _ = try await ForumMediaPreparation.prepare(unreadable, kind: .photo)
            XCTFail("An unreadable photo should be rejected")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("photo could not be opened"))
        }
    }

    func testForumVideoPreparationAndPostKeepPlayableUploadedMedia() async throws {
        let service = MockForumService(repository: DemoRepository())
        let seedPosts = try await service.posts(communityID: nil, limit: 20, offset: 0)
        let videoPost = try XCTUnwrap(seedPosts.first { $0.title == "Video test · App recording" })
        let video = try XCTUnwrap(videoPost.attachments.first)
        let sourceURL = try await service.mediaURL(for: video)
        let prepared = try await ForumMediaPreparation.prepare(sourceURL, kind: .video)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }
        XCTAssertEqual(prepared.fileURL.pathExtension.lowercased(), "mp4")
        XCTAssertEqual(prepared.contentType, "video/mp4")

        let sourceAsset = AVURLAsset(url: prepared.fileURL)
        XCTAssertGreaterThan(sourceAsset.duration.seconds, 0)
        XCTAssertFalse(sourceAsset.tracks(withMediaType: AVMediaType.video).isEmpty)

        let draft = ForumPostDraft(
            id: UUID(), communityID: try XCTUnwrap(videoPost.communityID), kind: "Discussion",
            title: "Video attachment test", body: "Playable video", tag: nil, liftID: nil, media: prepared
        )
        let created = try await service.createPost(draft)
        let attachment = try XCTUnwrap(created.attachments.first)
        XCTAssertEqual(attachment.kind.rawValue, ForumAttachment.Kind.video.rawValue)
        let uploadedURL = try await service.mediaURL(for: attachment)
        defer { try? FileManager.default.removeItem(at: uploadedURL) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: uploadedURL.path))

        try FileManager.default.removeItem(at: prepared.fileURL)
        let uploadedAsset = AVURLAsset(url: uploadedURL)
        XCTAssertGreaterThan(uploadedAsset.duration.seconds, 0)
        XCTAssertFalse(uploadedAsset.tracks(withMediaType: AVMediaType.video).isEmpty)
        try await service.deletePost(postID: created.id)
    }

    func testUnknownNotificationDestinationFallsBackWithoutDroppingTheNotification() throws {
        let data = #"{"kind":"forumComment","targetID":"00000000-0000-0000-0000-000000000001"}"#.data(using: .utf8)!
        let destination = try JSONDecoder().decode(NotificationDestination.self, from: data)

        XCTAssertEqual(destination.kind, .unsupported)
        XCTAssertEqual(destination.targetID, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    }

    func testRemoteNotificationPayloadDecodesRecipientAndRoutesTypedDestination() throws {
        let recipientID = UUID()
        let postID = UUID()
        let commentID = UUID()
        let userInfo: [String: Any] = [
            "recipient_id": recipientID.uuidString,
            "destination": [
                "kind": "forumPost",
                "targetID": postID.uuidString,
                "commentID": commentID.uuidString
            ] as [String: Any]
        ]
        let destinationData = try JSONSerialization.data(withJSONObject: try XCTUnwrap(userInfo["destination"]))
        let destination = try JSONDecoder().decode(NotificationDestination.self, from: destinationData)
        let decodedRecipientID = (userInfo["recipient_id"] as? String).flatMap(UUID.init(uuidString:))

        XCTAssertEqual(decodedRecipientID, recipientID)
        XCTAssertEqual(destination.kind, .forumPost)

        let store = NotificationStore(repository: DemoRepository())
        guard case .forumPost(let routedPostID, let routedCommentID) = store.route(for: destination) else {
            return XCTFail("Expected a typed forum-post route from the push payload")
        }
        XCTAssertEqual(routedPostID, postID)
        XCTAssertEqual(routedCommentID, commentID)
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


    func testTrainingFocusSurvivesProfileSaveRefreshAndOlderCache() async throws {
        let repository = DemoRepository()
        let remoteRepository = DemoRepository()
        let service = MockProfileService(repository: remoteRepository)
        let store = ProfileStore(repository: repository, profileService: service)
        for focus in TrainingFocus.allCases {
            var edited = repository.currentProfile
            edited.trainingFocus = focus
            let saved = try await store.saveEditedProfile(
                edited, primaryGym: nil, privacy: ProfilePrivacySettings(), authenticated: true
            )
            XCTAssertEqual(saved.trainingFocus, focus)
            let refreshed = try await service.authenticatedProfile()
            XCTAssertEqual(SupabaseProfileMapper.authenticated(refreshed).trainingFocus, focus)
            var staleLocal = repository.currentProfile
            staleLocal.trainingFocus = nil
            store.saveProfile(staleLocal)
            store.applyAuthenticatedProfile(refreshed, retainingDemoProfiles: false)
            XCTAssertEqual(store.currentProfile.trainingFocus, focus)
        }
        let data = try JSONEncoder().encode(repository.currentProfile)
        var olderCache = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        olderCache.removeValue(forKey: "trainingFocus")
        let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONSerialization.data(withJSONObject: olderCache))
        XCTAssertNil(decoded.trainingFocus)
        remoteRepository.currentProfile.trainingFocus = nil
        store.applyAuthenticatedProfile(try await service.authenticatedProfile(), retainingDemoProfiles: false)
        XCTAssertNil(store.currentProfile.trainingFocus)
    }

    func testLegacyPrivacySettingsDecodeWithPrivateWorkoutStatsDefault() throws {
        let legacy = Data(#"{"profileAudience":"friends","ageBandAudience":"public","divisionAudience":"friends","bodyweightAudience":"private","locationAudience":"private","gymAudience":"public","friendListAudience":"friends","showLiftVideos":false}"#.utf8)

        let privacy = try JSONDecoder().decode(ProfilePrivacySettings.self, from: legacy)

        XCTAssertEqual(privacy.profileAudience, .friends)
        XCTAssertEqual(privacy.bodyweightAudience, .privateProfile)
        XCTAssertEqual(privacy.locationAudience, .privateProfile)
        XCTAssertFalse(privacy.showLiftVideos)
        XCTAssertNil(privacy.workoutStatsAudience)
        XCTAssertEqual(privacy.workoutStatsAudience ?? .privateProfile, .privateProfile)
    }

    func testProfileSettingsSnapshotNormalizesDefaultsAndSendsOnlyChangedFields() throws {
        let legacyPrivacy = ProfilePrivacySettings()
        let normalizedPrivacy = ProfilePrivacySettings(
            workoutStatsAudience: .privateProfile,
            shareWorkoutStartsWithFriends: false,
            sharePRsWithFriends: false
        )
        let baseline = ProfileSettingsSnapshot(
            preferredUnit: .pounds,
            trainingFocus: .powerlifting,
            privacy: legacyPrivacy
        )
        let normalized = ProfileSettingsSnapshot(
            preferredUnit: .pounds,
            trainingFocus: .powerlifting,
            privacy: normalizedPrivacy
        )
        XCTAssertEqual(baseline, normalized)

        let changedPrivacy = ProfilePrivacySettings(
            profileAudience: .friends,
            workoutStatsAudience: .privateProfile,
            shareWorkoutStartsWithFriends: false,
            sharePRsWithFriends: false
        )
        let changed = ProfileSettingsSnapshot(
            preferredUnit: .kilograms,
            trainingFocus: nil,
            privacy: changedPrivacy
        )
        let changes = changed.changes(from: baseline)

        XCTAssertEqual(Set(changes.keys), ["preferred_unit", "training_focus", "profile_audience"])
        XCTAssertEqual(changes["preferred_unit"]!, "kg")
        XCTAssertNil(changes["training_focus"]!)
        XCTAssertEqual(changes["profile_audience"]!, "friends")

        let expectedChanges = baseline.fields.filter { changes.keys.contains($0.key) }
        let encoded = try JSONEncoder().encode(["changes": changes, "expected": expectedChanges])
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: [String: Any]])
        XCTAssertTrue(payload["changes"]?["training_focus"] is NSNull)
        XCTAssertEqual(payload["expected"]?["training_focus"] as? String, TrainingFocus.powerlifting.rawValue)
    }

    @MainActor
    func testProfileStoreSavesAccountSettingsReadbackAndRejectsAccountSwitch() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let original = AuthenticatedProfile(
            id: userID,
            username: "settings_owner",
            displayName: "Settings Owner",
            bio: "",
            avatarPath: nil,
            onboardingCompleted: true,
            preferredUnit: .pounds,
            birthDate: nil,
            sexCategory: nil,
            heightCentimeters: nil,
            bodyweightPounds: nil,
            city: nil,
            region: nil,
            countryCode: nil,
            yearsExperience: nil,
            experienceLevel: nil,
            privacy: ProfilePrivacySettings(),
            trainingFocus: .powerlifting
        )
        repository.currentProfile.id = userID
        let service = TestProfileService(profile: original)
        let store = ProfileStore(repository: repository, profileService: service)
        store.applyAuthenticatedProfile(original, retainingDemoProfiles: false)

        var readback = original
        readback.preferredUnit = .kilograms
        readback.trainingFocus = nil
        readback.privacy.profileAudience = .friends
        let expected = ProfileSettingsSnapshot(
            preferredUnit: original.preferredUnit,
            trainingFocus: original.trainingFocus,
            privacy: original.privacy
        )
        let requested = ProfileSettingsSnapshot(
            preferredUnit: .kilograms,
            trainingFocus: nil,
            privacy: readback.privacy
        )
        service.saveSettingsResponse = readback

        let saved = try await store.saveSettings(requested, expected: expected)
        XCTAssertEqual(saved, readback)
        XCTAssertEqual(store.currentProfile.id, userID)
        XCTAssertEqual(store.currentProfile.preferredUnit, .kilograms)
        XCTAssertNil(store.currentProfile.trainingFocus)
        XCTAssertEqual(store.currentProfile.profileAudience, .friends)
        XCTAssertEqual(service.settingsSaveRequests.count, 1)
        XCTAssertEqual(service.settingsSaveRequests.first?.settings, requested)
        XCTAssertEqual(service.settingsSaveRequests.first?.expected, expected)

        service.holdSettingsSave = true
        let secondRequest = ProfileSettingsSnapshot(
            preferredUnit: .pounds,
            trainingFocus: nil,
            privacy: readback.privacy
        )
        let saveTask = Task {
            try await store.saveSettings(secondRequest, expected: requested)
        }
        for _ in 0..<40 where !service.settingsSaveStarted {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTAssertTrue(service.settingsSaveStarted)

        let otherUserID = UUID()
        var switchedProfile = store.currentProfile
        switchedProfile.id = otherUserID
        switchedProfile.username = "other_settings_user"
        repository.currentProfile = switchedProfile
        service.releaseSettingsSave()

        do {
            _ = try await saveTask.value
            XCTFail("A settings response for the previous account must be rejected")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .sessionExpired)
        }
        XCTAssertEqual(store.currentProfile.id, otherUserID)
        XCTAssertEqual(store.currentProfile.username, "other_settings_user")
        XCTAssertEqual(service.settingsSaveRequests.count, 2)
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
            privacy: ProfilePrivacySettings(
                bodyweightAudience: .privateProfile,
                locationAudience: .privateProfile,
                gymAudience: .privateProfile,
                showLiftVideos: false
            )
        )

        store.applyAuthenticatedProfile(remote, retainingDemoProfiles: false)

        XCTAssertEqual(store.currentProfile.id, userID)
        XCTAssertEqual(store.currentProfile.username, "production_lifter")
        XCTAssertEqual(store.currentProfile.avatarPath, "avatars/production.jpg")
        XCTAssertEqual(store.currentProfile.heightInches, 170 / 2.54, accuracy: 0.001)
        XCTAssertTrue(store.currentProfile.hideBodyweight)
        XCTAssertTrue(store.currentProfile.hideCity)
        XCTAssertTrue(store.currentProfile.hideGym)
        XCTAssertTrue(store.currentProfile.hideLiftVideos)
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
            sexCategory: .male,
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
        let savedPath = try await LocalProfilePhotoStore.shared.save(
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
            sexCategory: .male, heightCentimeters: nil, city: nil, region: nil, countryCode: "US",
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
            sexCategory: .male,
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
        edited.trainingFocus = .bodybuilding
        edited.ageGroup = "30-34"
        edited.bodyweightPounds = 205
        edited.yearsExperience = 7
        edited.cityID = UUID()
        edited.city = "Miami"
        edited.state = "Florida"
        edited.countryCode = "CA"
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
            sexCategory: .male,
            heightCentimeters: 180,
            bodyweightPounds: 205,
            city: "Austin",
            region: "Texas",
            countryCode: "US",
            cityID: serverCityID,
            yearsExperience: 3,
            experienceLevel: .intermediate,
            privacy: ProfilePrivacySettings(
                profileAudience: .privateProfile,
                locationAudience: .privateProfile,
                showLiftVideos: false
            )
        )
        let gym = Gym(
            id: UUID(),
            name: "Downtown Strength",
            city: "Austin",
            state: "Texas",
            memberCount: 0,
            verifiedLiftCount: 0
        )
        let privacy = ProfilePrivacySettings(
            divisionAudience: .friends,
            locationAudience: .privateProfile,
            friendListAudience: .gym,
            showLiftVideos: false
        )

        let saved = try await store.saveEditedProfile(
            edited,
            primaryGym: gym,
            privacy: privacy,
            authenticated: true,
            allowUsernameChange: true
        )

        XCTAssertEqual(saved.id, userID)
        XCTAssertEqual(saved.displayName, "Updated Lifter")
        XCTAssertEqual(saved.avatarPath, "avatars/server-normalized.jpg")
        XCTAssertEqual(saved.primaryGymID, gym.id)
        XCTAssertEqual(saved.bodyweightPounds, 205)
        XCTAssertEqual(saved.cityID, serverCityID)
        XCTAssertEqual(saved.city, "Austin")
        XCTAssertEqual(saved.state, "Texas")
        XCTAssertTrue(saved.hideLiftVideos)
        XCTAssertEqual(saved.profileAudience, .privateProfile)
        let savedDraft = try XCTUnwrap(service.lastSavedProfileDraft)
        XCTAssertEqual(savedDraft.bio, "Training for my next total")
        XCTAssertEqual(savedDraft.trainingFocus, .bodybuilding)
        XCTAssertEqual(savedDraft.birthDate, Date(timeIntervalSince1970: 700_000_000))
        XCTAssertEqual(savedDraft.bodyweightPounds, 205)
        XCTAssertEqual(savedDraft.yearsExperience, 7)
        XCTAssertEqual(savedDraft.cityID, edited.cityID)
        XCTAssertEqual(savedDraft.countryCode, "CA")
        XCTAssertTrue(savedDraft.updatesPrimaryGym)
        XCTAssertEqual(savedDraft.primaryGymID, gym.id)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(SaveProfileParameters(draft: savedDraft))) as? [String: Any])
        XCTAssertEqual(payload["new_show_lift_videos"] as? Bool, false)
        XCTAssertEqual(payload["new_bodyweight_audience"] as? String, privacy.bodyweightAudience.rawValue)
        XCTAssertEqual(payload["new_primary_gym_id"] as? String, gym.id.uuidString)
        XCTAssertEqual(payload["updates_primary_gym"] as? Bool, true)
        XCTAssertEqual(savedDraft.city, "Miami")
        XCTAssertEqual(savedDraft.region, "Florida")
        XCTAssertEqual(savedDraft.privacy.locationAudience, .privateProfile)
        XCTAssertEqual(savedDraft.privacy.divisionAudience, .friends)
        XCTAssertEqual(savedDraft.privacy.friendListAudience, .gym)
        XCTAssertFalse(savedDraft.privacy.showLiftVideos)
        XCTAssertEqual(store.profiles.map(\.id), [userID])
    }

    func testProfileSaveFailureRetainsLocalPrivacyAndCanRetryWithExplicitGymRemoval() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let remote = AuthenticatedProfile(
            id: repository.currentProfile.id, username: repository.currentProfile.username,
            displayName: repository.currentProfile.displayName, bio: "", avatarPath: nil,
            onboardingCompleted: true, preferredUnit: .pounds, birthDate: Date(timeIntervalSince1970: 700_000_000),
            sexCategory: .male, heightCentimeters: 180, bodyweightPounds: 200,
            city: "Miami", region: "Florida", countryCode: "US", yearsExperience: 2,
            experienceLevel: .intermediate, privacy: ProfilePrivacySettings()
        )
        let service = TestProfileService(profile: remote)
        let store = ProfileStore(repository: repository, profileService: service)
        let original = store.currentProfile
        var requested = original
        requested.preferredUnit = .kilograms
        let privacy = ProfilePrivacySettings(profileAudience: .friends, locationAudience: .gym, showLiftVideos: false)
        service.saveProfileError = LiftRankServiceError.server("Save failed")
        do {
            _ = try await store.saveEditedProfile(requested, primaryGym: nil, privacy: privacy, authenticated: true, updatePrimaryGym: true)
            XCTFail("Save failure must reach the caller")
        } catch {
            XCTAssertEqual(store.currentProfile, original)
        }
        service.saveProfileError = nil
        let saved = try await store.saveEditedProfile(requested, primaryGym: nil, privacy: privacy, authenticated: true, updatePrimaryGym: true)
        XCTAssertEqual(saved.profileAudience, .friends)
        XCTAssertTrue(saved.hideLiftVideos)
        XCTAssertTrue(saved.primaryGymName.isEmpty)
        let draft = try XCTUnwrap(service.lastSavedProfileDraft)
        XCTAssertTrue(draft.updatesPrimaryGym)
        XCTAssertNil(draft.primaryGymID)
        XCTAssertEqual(draft.birthDate, remote.birthDate)
        XCTAssertEqual(draft.privacy, privacy)
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
            sexCategory: .male,
            heightCentimeters: nil,
            bodyweightPounds: 220,
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
            actual: 211,
            notes: "Home log"
        ))

        let deadline = Date().addingTimeInterval(1)
        while service.savedBodyweightEntries.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(appState.currentProfile.bodyweightPounds, 211)
        XCTAssertEqual(appState.bodyweightEntries.last?.actual, 211)
        XCTAssertEqual(service.profile.bodyweightPounds, 211)
        XCTAssertEqual(service.updateProfileCount, 0)
        XCTAssertEqual(service.savedBodyweightEntries.last?.actual, 211)

        let savedEntry = try XCTUnwrap(service.savedBodyweightEntries.last)
        service.bodyweightDeleteError = LiftRankServiceError.server("Bodyweight delete unavailable")
        appState.deleteBodyweight(savedEntry)
        let failureDeadline = Date().addingTimeInterval(1)
        while appState.accountMessage == nil && Date() < failureDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(appState.bodyweightEntries.contains(where: { $0.id == savedEntry.id }))
        XCTAssertTrue(service.deletedBodyweightIDs.isEmpty)

        service.bodyweightDeleteError = nil
        appState.deleteBodyweight(savedEntry)
        let deleteDeadline = Date().addingTimeInterval(1)
        while service.deletedBodyweightIDs.isEmpty && Date() < deleteDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(service.deletedBodyweightIDs, [savedEntry.id])
        XCTAssertFalse(appState.bodyweightEntries.contains(where: { $0.id == savedEntry.id }))
        XCTAssertEqual(appState.currentProfile.bodyweightPounds, 0)
        XCTAssertEqual(service.profile.bodyweightPounds, 0)
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
            sexCategory: .male, heightCentimeters: nil, bodyweightPounds: 205,
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

    func testFailedAuthenticatedBodyweightCheckInDoesNotCreateLocalServerDrift() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let userID = UUID()
        let session = AccountSession(
            userID: userID,
            email: "bodyweight-write@example.test",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        let service = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "bodyweight_write", displayName: "Bodyweight Write", bio: "",
            avatarPath: nil, onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil,
            sexCategory: .male, heightCentimeters: nil, bodyweightPounds: 205,
            city: nil, region: nil, countryCode: "US", yearsExperience: nil,
            experienceLevel: .beginner, privacy: ProfilePrivacySettings()
        ))
        service.bodyweightSaveError = LiftRankServiceError.server("Bodyweight check-in unavailable")
        let appState = AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: TestSessionAuthenticationService(session: session),
            profile: service,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: session.email ?? "bodyweight-write@example.test", password: "password")

        let entry = BodyweightEntry(
            id: UUID(), week: 1, targetDate: .now, actual: 212, notes: "Should not drift"
        )
        appState.updateBodyweight(entry)

        let deadline = Date().addingTimeInterval(1)
        while appState.accountMessage == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(appState.currentProfile.bodyweightPounds, 205)
        XCTAssertFalse(appState.bodyweightEntries.contains(where: { $0.id == entry.id }))
        XCTAssertEqual(service.profile.bodyweightPounds, 205)
        XCTAssertNotNil(appState.accountMessage)
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

    func testLatestLoggedBodyweightUsesNewestDatedEntryRegardlessOfArrayOrder() {
        let older = BodyweightEntry(
            id: UUID(), week: 1, targetDate: Date(timeIntervalSince1970: 1_000), actual: 220, notes: ""
        )
        let newer = BodyweightEntry(
            id: UUID(), week: 2, targetDate: Date(timeIntervalSince1970: 2_000), actual: 211, notes: ""
        )

        XCTAssertEqual(
            ProfileDataAuthority.latestLoggedBodyweight(profilePounds: 220, entries: [newer, older]),
            211
        )
        XCTAssertEqual(
            ProfileDataAuthority.latestLoggedBodyweight(profilePounds: 220, entries: [older, BodyweightEntry(id: UUID(), week: 2, targetDate: newer.targetDate, actual: nil, notes: "")]),
            220
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
            sexCategory: .male, heightCentimeters: nil, bodyweightPounds: 200,
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
            sexCategory: .male,
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
        while service.savedBodyweightEntries.isEmpty && Date() < deadline {
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
        XCTAssertEqual(saved.username, "remote_lifter")
        XCTAssertEqual(service.usernameChangeCount, 0)
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
            sexCategory: .male,
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
        _ = try await store.changeAuthenticatedUsername("ready_lifter", retainingDemoProfiles: false)
        let saved = try await store.saveAuthenticatedProfile(ProfileDraft(
            username: "ready_lifter",
            displayName: "Ready Lifter",
            bio: "Ready to compete",
            preferredUnit: .kilograms,
            birthDate: nil,
            sexCategory: .male,
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

    func testAnalyticsConsentDefaultsOffAndIsScopedPerAccount() {
        let suiteName = "AnalyticsConsentTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstUser = UUID()
        let secondUser = UUID()

        XCTAssertFalse(AnalyticsStore.isSharingEnabled(for: firstUser, defaults: defaults))
        XCTAssertFalse(AnalyticsStore.isSharingEnabled(for: secondUser, defaults: defaults))

        defaults.set(false, forKey: AnalyticsStore.consentKey(for: firstUser))
        XCTAssertFalse(AnalyticsStore.isSharingEnabled(for: firstUser, defaults: defaults))
        defaults.set(true, forKey: AnalyticsStore.consentKey(for: firstUser))

        XCTAssertTrue(AnalyticsStore.isSharingEnabled(for: firstUser, defaults: defaults))
        XCTAssertFalse(AnalyticsStore.isSharingEnabled(for: secondUser, defaults: defaults))
    }

    func testPushSigningEnvironmentMapsOnlySupportedValues() {
        XCTAssertEqual(NotificationStore.pushEnvironment(signingEnvironment: "development"), "sandbox")
        XCTAssertEqual(NotificationStore.pushEnvironment(signingEnvironment: "production"), "production")
        XCTAssertNil(NotificationStore.pushEnvironment(signingEnvironment: nil))
        XCTAssertNil(NotificationStore.pushEnvironment(signingEnvironment: "staging"))
        XCTAssertNil(NotificationStore.pushEnvironment(signingEnvironment: ""))
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

    func testCurrentLegalDocumentsCoverImplementedDataAndTrainingRisk() {
        let documents = Dictionary(uniqueKeysWithValues: LegalDocument.current.map { document in
            (document.kind, document.sections.map(\.body).joined(separator: " ").lowercased())
        })

        XCTAssertEqual(Set(documents.keys), Set(LegalDocumentKind.allCases))
        let privacy = documents[.privacy] ?? ""
        XCTAssertTrue(privacy.contains("email"))
        XCTAssertTrue(privacy.contains("workout"))
        XCTAssertTrue(privacy.contains("photo") || privacy.contains("video"))
        XCTAssertTrue(privacy.contains("location") || privacy.contains("city"))

        let terms = documents[.terms] ?? ""
        XCTAssertTrue(terms.contains("community"))
        XCTAssertTrue(terms.contains("ranking"))

        let disclaimer = documents[.fitnessDisclaimer] ?? ""
        XCTAssertTrue(disclaimer.contains("injury"))
        XCTAssertTrue(disclaimer.contains("medical"))
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

    func testSignupConfirmationAndResendErrorsAreReported() async {
        let email = "new-lifter@example.test"
        let authentication = TestAuthenticationService(session: session)
        authentication.requiresEmailConfirmation = true
        let state = makeState(authentication: authentication, onboardingCompleted: true)

        await state.signUp(email: email, password: "valid-password-123")

        XCTAssertEqual(authentication.signUpEmails, [email])
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertEqual(state.accountMessage, "Check your email to confirm your account, then sign in.")

        authentication.resendConfirmationError = LiftRankServiceError.server("Confirmation could not be sent.")
        await state.resendConfirmationEmail(email: email)
        XCTAssertEqual(state.accountMessage, "Confirmation could not be sent.")

        authentication.resendConfirmationError = nil
        await state.resendConfirmationEmail(email: email)
        XCTAssertEqual(authentication.resentConfirmationEmails, [email, email])
        XCTAssertEqual(state.accountMessage, "A new confirmation email is on the way.")
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

        try await store.registerPushToken("token-value", userID: userID, environment: "sandbox")
        let registration = try XCTUnwrap(service.registrations.first)
        XCTAssertEqual(registration.userID, userID)
        XCTAssertEqual(registration.deviceID, "test-device")
        XCTAssertEqual(registration.token, "token-value")
        XCTAssertEqual(registration.environment, "sandbox")

        try await store.registerPushToken("wrong-account-token", userID: UUID(), environment: "sandbox")
        XCTAssertEqual(service.registrations.count, 1)

        let registrationError = LiftRankServiceError.server("Registration unavailable")
        service.registrationError = registrationError
        do {
            try await store.registerPushToken("retry-token", userID: userID, environment: "sandbox")
            XCTFail("Expected token registration failure to propagate")
        } catch let error as LiftRankServiceError {
            XCTAssertEqual(error, registrationError)
        }

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

    func testPasswordRecoveryCallbackPreservesNativePKCEAndRecoveryIntent() {
        XCTAssertEqual(
            SupabaseConfiguration.passwordRecoveryCallbackURL.absoluteString,
            "liftrank://auth-callback?type=recovery"
        )
    }

    func testRecoveryCallbackShowsPasswordFormBeforeProfileLoading() async {
        let auth = TestAuthenticationService(session: session)
        let state = makeState(authentication: auth, onboardingCompleted: true)
        let url = URL(string: "liftrank://auth-callback?type=recovery&code=test-code")!

        await state.handleAuthCallback(url)

        XCTAssertEqual(auth.callbackURLs, [url])
        XCTAssertTrue(state.showingPasswordUpdate)
        XCTAssertEqual(state.accountSession?.userID, session.userID)
        XCTAssertNotEqual(state.accountStatus, .authenticated)
        await state.updatePassword("new-password-123")
        XCTAssertEqual(auth.updatedPasswords, ["new-password-123"])
        XCTAssertFalse(state.showingPasswordUpdate)
        XCTAssertEqual(state.accountStatus, .authenticated)
    }

    func testRecoverySucceedsWhenProfileServiceIsUnavailable() async {
        let auth = TestAuthenticationService(session: session)
        let state = makeState(authentication: auth, onboardingCompleted: true,
                              profileError: LiftRankServiceError.networkUnavailable)
        await state.handleAuthCallback(URL(string: "liftrank://auth-callback?type=recovery&code=test")!)
        XCTAssertTrue(state.showingPasswordUpdate)
        XCTAssertNil(state.accountMessage)
        await state.updatePassword("new-password-123")
        XCTAssertEqual(auth.updatedPasswords, ["new-password-123"])
        XCTAssertFalse(state.showingPasswordUpdate)
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertTrue(state.accountMessage?.hasPrefix("Your password has been updated") == true)
    }

    func testRecoveryRejectsExpiredCallbackAndDoesNotUseExistingSession() async {
        let auth = TestAuthenticationService(session: session)
        auth.callbackError = LiftRankServiceError.sessionExpired
        let state = makeState(authentication: auth, onboardingCompleted: true)
        await state.restoreAccount()

        await state.handleAuthCallback(URL(string: "liftrank://auth-callback?type=recovery&code=expired")!)

        XCTAssertFalse(state.showingPasswordUpdate)
        XCTAssertNotNil(state.accountMessage)
        XCTAssertTrue(auth.updatedPasswords.isEmpty)
    }

    func testRecoveryUpdateFailureKeepsFormAndCancellationSignsOut() async {
        let auth = TestAuthenticationService(session: session)
        auth.passwordError = LiftRankServiceError.sessionExpired
        let state = makeState(authentication: auth, onboardingCompleted: true)
        await state.handleAuthCallback(URL(string: "liftrank://auth-callback?type=recovery&code=test")!)
        await state.updatePassword("short")
        XCTAssertTrue(auth.updatedPasswords.isEmpty)
        await state.updatePassword("new-password-123")
        XCTAssertTrue(state.showingPasswordUpdate)
        XCTAssertNotNil(state.accountMessage)
        await state.signOutAccount()
        XCTAssertFalse(state.showingPasswordUpdate)
        XCTAssertNil(state.accountSession)
    }

    func testOrdinaryAuthCallbackDoesNotShowPasswordForm() async {
        let state = makeState(session: session, onboardingCompleted: true)
        await state.handleAuthCallback(URL(string: "liftrank://auth-callback?code=signup")!)
        XCTAssertFalse(state.showingPasswordUpdate)
        XCTAssertEqual(state.accountStatus, .authenticated)
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
            privacy: ProfilePrivacySettings(bodyweightAudience: .privateProfile, showLiftVideos: false)
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
        XCTAssertTrue(profile.hideLiftVideos)
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
            primaryGymName: nil,
            bodyweightPounds: nil,
            bodyweightLastUpdatedAt: nil
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

    func testOnboardingStartingLiftRejectsMissingOrNonpositiveWeight() {
        XCTAssertNil(OnboardingStartingLift(exerciseID: "bench", weight: nil))
        XCTAssertNil(OnboardingStartingLift(exerciseID: "bench", weight: 0))
        XCTAssertNil(OnboardingStartingLift(exerciseID: "bench", weight: -1))
        XCTAssertEqual(
            OnboardingStartingLift(exerciseID: "bench", weight: 225),
            OnboardingStartingLift(exerciseID: "bench", weight: 225)
        )
    }

    func testOnboardingStartingLiftsSavePrivateSelfReportedRecordsAndRetryWithoutDuplicates() async throws {
        let state = makeState(session: session, onboardingCompleted: false, includesLiftService: true)
        await state.restoreAccount()
        let startingLifts = [
            OnboardingStartingLift(exerciseID: "bench", weight: 225),
            OnboardingStartingLift(exerciseID: "squat", weight: 315),
            OnboardingStartingLift(exerciseID: "deadlift", weight: 405),
            OnboardingStartingLift(exerciseID: "press", weight: 135)
        ].compactMap { $0 }

        try await state.saveOnboardingStartingLifts(
            startingLifts,
            unit: .pounds,
            bodyweightPounds: 187,
            gymID: nil
        )
        try await state.saveOnboardingStartingLifts(
            startingLifts,
            unit: .pounds,
            bodyweightPounds: 187,
            gymID: nil
        )

        let saved = state.currentUserLifts.filter { $0.caption.hasPrefix("Starting lift from onboarding:") }
        XCTAssertEqual(saved.count, 4)
        XCTAssertEqual(
            Set(saved.map(\.exerciseID)),
            Set(["barbell-bench-press", "back-squat", "conventional-deadlift", "standing-barbell-overhead-press"])
        )
        XCTAssertTrue(saved.allSatisfy { $0.visibility == .privateLift })
        XCTAssertTrue(saved.allSatisfy { $0.verificationStatus == .selfReported })
        XCTAssertTrue(saved.allSatisfy { $0.evidenceStatus == .selfReported })
        XCTAssertTrue(saved.allSatisfy { $0.moderationStatus == .clear })
        XCTAssertTrue(saved.allSatisfy { $0.repetitions == 1 && $0.isActualOneRepMax })
        XCTAssertTrue(saved.allSatisfy { $0.bodyweightAtLift == 187 })
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

    func testAccountLaunchRestoresTrainingWhilePlanSyncIsPending() async throws {
        for hasCache in [false, true] {
            let repository = DemoRepository()
            let remoteRepository = DemoRepository()
            var profile = MockData.demoProfile
            profile.id = UUID()
            remoteRepository.currentProfile = profile
            let plan = WorkoutPlan(id: UUID(), name: "Saved program", createdAt: .now)
            let payload = try JSONEncoder().encode(WorkoutPlanSyncPayload(
                plan: plan, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
            ))
            let document = WorkoutPlanDocument(
                id: plan.id, ownerID: profile.id, revision: 1,
                name: plan.name, payload: payload, updatedAt: .now
            )
            let workoutID = UUID()
            let exercise = WorkoutExerciseSnapshot(
                id: UUID(), sourcePrescriptionID: nil, exerciseID: "barbell_bench_press",
                exerciseName: "Bench Press", bodyPart: "Chest", equipment: "Barbell",
                targetSets: 1, targetReps: "5", restSeconds: 90, order: 0, notes: "", rankingExerciseID: nil
            )
            let set = WorkoutSetLog(
                id: UUID(), prescriptionID: exercise.id, performedAt: .now, setNumber: 1,
                weight: 60, reps: 5, rpe: nil, isWarmup: false, isComplete: true,
                workoutID: workoutID, recordedUnit: .kilograms, completionSource: .manual
            )
            let workout = CompletedWorkout(
                id: workoutID, source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
                name: "Saved workout", dayLabel: "Monday", startedAt: .now.addingTimeInterval(-600),
                completedAt: .now, duration: 600, effort: 3, notes: "", gymID: nil,
                bodyweight: nil, unit: .kilograms, exercises: [exercise], sets: [set], linkedSubmissionIDs: []
            )
            let snapshot = CompletedWorkoutSnapshot(
                id: workout.id, ownerID: profile.id,
                payload: try JSONEncoder().encode(workout), completedAt: workout.completedAt
            )
            if hasCache {
                repository.currentProfile = profile
                repository.workoutPlans = [plan]
                repository.workoutPlanSyncRevisions[plan.id] = 1
                repository.workoutPlanLastSyncedPayloads[plan.id] = payload
                repository.completedWorkouts = [workout]
                repository.refreshAchievementUnlocks()
            }
            let sync = GatedWorkoutPlanSyncService(documents: [document], snapshots: [snapshot])
            let legal = TestSessionLegalAcceptanceService(userID: profile.id)
            try await legal.accept(documents: LegalDocument.current)
            let state = AppState(repository: repository, serviceContainer: AppServiceContainer(
                authentication: TestSessionAuthenticationService(session: AccountSession(
                    userID: profile.id, email: "startup@example.test", expiresAt: .now.addingTimeInterval(3_600)
                )),
                profile: MockProfileService(repository: remoteRepository),
                gyms: MockGymService(repository: repository),
                gymMemberships: MockGymMembershipService(repository: repository),
                exercises: MockExerciseCatalogService(), workoutSync: sync, legalAcceptances: legal
            ))
            let restore = Task { await state.restoreAccount() }
            let deadline = Date.now.addingTimeInterval(5)
            while (!sync.requestStarted || !sync.historyRequestStarted || repository.completedWorkouts.isEmpty),
                  Date.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(state.accountStatus, .authenticated)
            XCTAssertTrue(sync.requestStarted)
            XCTAssertTrue(state.isLoadingInitialTrainingData)
            XCTAssertTrue(sync.historyRequestStarted, "History must load without waiting for plans or a foreground event")
            XCTAssertEqual(repository.completedWorkouts.map(\.id), [workout.id])
            XCTAssertTrue(repository.achievementUnlocks.contains { $0.title == "First Workout" })
            if hasCache {
                XCTAssertEqual(state.selectedWorkoutPlanID, plan.id, "Cached program must be selected before its server refresh finishes")
            }
            sync.release()
            await restore.value
            let planDeadline = Date.now.addingTimeInterval(5)
            while state.isLoadingInitialTrainingData, Date.now < planDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(state.selectedWorkoutPlanID, plan.id)
            XCTAssertEqual(state.workoutSyncStore.planSyncState, .synced)
            XCTAssertFalse(state.isLoadingInitialTrainingData)
            await state.signOutAccount()
        }
    }

    func testFailedAuthenticatedProfileLoadClearsRestoredSessionState() async {
        let repository = DemoRepository()
        let userID = UUID()
        let session = AccountSession(userID: userID, email: "restore-failure@example.test", expiresAt: .now.addingTimeInterval(3_600))
        let profileService = TestProfileService(profile: AuthenticatedProfile(
            id: userID, username: "restore_failure", displayName: "Restore Failure", bio: "", avatarPath: nil,
            onboardingCompleted: true, preferredUnit: .pounds, birthDate: nil, sexCategory: .male,
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
            birthDate: nil, sexCategory: .male, heightCentimeters: nil, city: nil,
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
            sexCategory: .male,
            city: nil,
            region: nil,
            countryCode: nil,
            primaryGymID: nil,
            primaryGymName: nil,
            bodyweightPounds: nil,
            bodyweightLastUpdatedAt: nil
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

        let newlyBlockedID = UUID()
        try await store.setBlocked(newlyBlockedID, blocked: true)
        XCTAssertTrue(store.isBlocked(newlyBlockedID), "A successful block should remain cached if the follow-up list refresh fails")

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
    func testGymRequestPersistsInLocalWorkoutSnapshot() async throws {
        let persistence = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        let appState = AppState(repository: repository)

        appState.requestGym(name: "  New Gym  ", city: "Austin", state: "Texas", note: "Please verify")
        try await Task.sleep(for: .milliseconds(1_200))

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
    func testUnreadableSwiftDataWorkoutSnapshotIsPreservedAndAbsentSnapshotInitializes() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PersistentLiftRecord.self, PersistentSettings.self,
            PersistentWorkoutRecord.self, PersistentWorkoutState.self,
            configurations: configuration
        )
        let context = container.mainContext
        let unreadablePayload = Data("unreadable workout data".utf8)
        let record = PersistentWorkoutState(
            schemaVersion: WorkoutPersistenceSnapshot.currentVersion,
            payload: unreadablePayload
        )
        context.insert(record)
        try context.save()

        let persistence = SwiftDataWorkoutPersistenceStore(context: context)
        _ = DemoRepository(workoutPersistenceStore: persistence)

        XCTAssertNotNil(persistence.loadError)
        XCTAssertEqual(try XCTUnwrap(context.fetch(FetchDescriptor<PersistentWorkoutState>()).first).payload, unreadablePayload)

        let emptyContainer = try ModelContainer(
            for: PersistentLiftRecord.self, PersistentSettings.self,
            PersistentWorkoutRecord.self, PersistentWorkoutState.self,
            configurations: configuration
        )
        let emptyContext = emptyContainer.mainContext
        let emptyPersistence = SwiftDataWorkoutPersistenceStore(context: emptyContext)
        _ = DemoRepository(workoutPersistenceStore: emptyPersistence)

        XCTAssertNil(emptyPersistence.loadError)
        XCTAssertNotNil(emptyPersistence.loadSnapshot())
        XCTAssertEqual(try emptyContext.fetch(FetchDescriptor<PersistentWorkoutState>()).count, 1)
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
        try store.saveSnapshot(snapshot)

        let record = try XCTUnwrap(context.fetch(FetchDescriptor<PersistentWorkoutState>()).first)
        XCTAssertTrue(record.payload.starts(with: Data("bplist".utf8)))
        let firstUpdatedAt = record.updatedAt
        try store.saveSnapshot(snapshot)
        XCTAssertEqual(record.updatedAt, firstUpdatedAt)
    }

    @MainActor
    func testPendingFriendActivitySharesRoundTripAndFilterBySnapshotOwner() {
        let persistence = InMemoryWorkoutPersistenceStore()
        let ownerID = UUID()
        let otherOwnerID = UUID()
        let workoutStart = PendingFriendActivityShare(ownerID: ownerID, kind: .workoutStarted, sourceID: UUID())
        let topLift = PendingFriendActivityShare(ownerID: ownerID, kind: .topLift, sourceID: UUID())
        let foreignShare = PendingFriendActivityShare(ownerID: otherOwnerID, kind: .workoutStarted, sourceID: UUID())

        let firstRepository = DemoRepository(workoutPersistenceStore: persistence)
        firstRepository.currentProfile.id = ownerID
        firstRepository.pendingFriendActivityShares = [workoutStart, topLift, foreignShare]

        XCTAssertTrue(firstRepository.persistWorkoutSnapshotReportingError())
        let restoredRepository = DemoRepository(workoutPersistenceStore: persistence)

        XCTAssertEqual(restoredRepository.currentProfile.id, ownerID)
        XCTAssertEqual(restoredRepository.pendingFriendActivityShares, [workoutStart, topLift])

        restoredRepository.clearLocalUserData()
        XCTAssertTrue(restoredRepository.pendingFriendActivityShares.isEmpty)
    }

    @MainActor
    func testLegacyWorkoutSnapshotWithoutPendingFriendSharesRestoresEmptyQueue() throws {
        let persistence = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: persistence)
        var snapshot = try XCTUnwrap(persistence.snapshot)
        var profile = try XCTUnwrap(snapshot.currentProfile)
        profile.id = UUID()
        snapshot.currentProfile = profile
        snapshot.pendingFriendActivityShares = [
            PendingFriendActivityShare(ownerID: profile.id, kind: .workoutStarted, sourceID: UUID())
        ]

        let encoded = try JSONEncoder().encode(snapshot)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "pendingFriendActivityShares")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacySnapshot = try JSONDecoder().decode(WorkoutPersistenceSnapshot.self, from: legacyData)
        let legacyRepository = DemoRepository(
            workoutPersistenceStore: InMemoryWorkoutPersistenceStore(snapshot: legacySnapshot)
        )

        XCTAssertNil(legacySnapshot.pendingFriendActivityShares)
        XCTAssertTrue(legacyRepository.pendingFriendActivityShares.isEmpty)
    }

    @MainActor
    func testFailedSynchronousSnapshotWriteRetainsPendingFriendActivityIntent() {
        let repository = DemoRepository(workoutPersistenceStore: FailingWorkoutPersistenceStore())
        let pending = PendingFriendActivityShare(
            ownerID: repository.currentProfile.id,
            kind: .topLift,
            sourceID: UUID()
        )
        repository.pendingFriendActivityShares = [pending]

        XCTAssertFalse(repository.persistWorkoutSnapshotReportingError())
        XCTAssertEqual(repository.pendingFriendActivityShares, [pending])
        XCTAssertTrue(repository.workoutSaveError?.contains("Simulated write failure") == true)
    }

    @MainActor
    func testDemoRepositoryReportsWorkoutSaveFailureAndRetainsInMemoryState() {
        let repository = DemoRepository(workoutPersistenceStore: FailingWorkoutPersistenceStore())
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Retained workout", dayLabel: "Monday", startedAt: .now.addingTimeInterval(-600),
            completedAt: .now, duration: 600, effort: 3, notes: "Keep this in memory", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        repository.completedWorkouts = [workout]

        XCTAssertFalse(repository.persistWorkoutSnapshotReportingError())
        XCTAssertTrue(repository.workoutSaveError?.contains("Simulated write failure") == true)
        XCTAssertEqual(repository.completedWorkouts, [workout])
    }

    @MainActor
    func testDemoRepositoryUnchangedSnapshotFlushSkipsSaveAndRetriesFailure() {
        let persistence = CountingWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        let initialSaveCount = persistence.saveCount

        repository.persistWorkoutSnapshotIfChanged()
        repository.persistWorkoutSnapshotIfChanged()
        XCTAssertEqual(persistence.saveCount, initialSaveCount)

        var preferences = repository.workoutPreferences
        preferences.defaultRestTimerEnabled = false
        repository.workoutPreferences = preferences
        repository.persistWorkoutSnapshotIfChanged()
        XCTAssertEqual(persistence.saveCount, initialSaveCount + 1)
        repository.persistWorkoutSnapshotIfChanged()
        XCTAssertEqual(persistence.saveCount, initialSaveCount + 1)

        persistence.failNextSave = true
        preferences.missedWorkoutRemindersEnabled = true
        repository.workoutPreferences = preferences
        repository.persistWorkoutSnapshotIfChanged()
        XCTAssertEqual(persistence.saveCount, initialSaveCount + 2)
        XCTAssertTrue(repository.workoutSaveError?.contains("Simulated write failure") == true)

        repository.persistWorkoutSnapshotIfChanged()
        XCTAssertEqual(persistence.saveCount, initialSaveCount + 3)
        XCTAssertNil(repository.workoutSaveError)
    }

    @MainActor
    func testWorkoutCompletionRestoresDraftWhenPersistenceFails() throws {
        let repository = DemoRepository(workoutPersistenceStore: FailingWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        var setLog = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == repository.activeWorkout?.id })
        setLog.weight = 135
        setLog.reps = 5
        setLog.isComplete = true
        repository.updateWorkoutSetLog(setLog)
        let activeWorkoutID = try XCTUnwrap(repository.activeWorkout?.id)
        let draftSetLogs = repository.workoutSetLogs

        XCTAssertNil(appState.finishActiveWorkout(effort: 3, notes: ""))
        XCTAssertEqual(repository.activeWorkout?.id, activeWorkoutID)
        XCTAssertEqual(repository.workoutSetLogs, draftSetLogs)
        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertTrue(appState.workoutCompletionError?.contains("Simulated write failure") == true)
    }

    @MainActor
    func testSubstitutingWeightedExerciseToTimedClearsDraftAndPreservesCompletedSet() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let exerciseLibrary = ExerciseLibraryStore(repository: repository)
        let weighted = try XCTUnwrap(exerciseLibrary.createCustomExercise(
            name: "Weighted test press",
            bodyPart: "Chest",
            equipment: "Barbell",
            trackingType: "Weight + Reps"
        ))
        let timed = try XCTUnwrap(exerciseLibrary.createCustomExercise(
            name: "Timed test hold",
            bodyPart: "Chest",
            equipment: "Cable",
            trackingType: "Weight + Time"
        ))
        let workout = try XCTUnwrap(repository.startFreestyleWorkout(
            name: "Substitution test",
            gymID: nil,
            bodyweight: nil,
            unit: .pounds
        ))
        repository.addExercisesToActiveWorkout([weighted])
        let original = try XCTUnwrap(repository.activeWorkout?.exercises.first)
        var logs = repository.workoutSetLogs
            .filter { $0.workoutID == workout.id && $0.prescriptionID == original.id }
            .sorted { $0.setNumber < $1.setNumber }
        let completedIndex = try XCTUnwrap(logs.indices.first)
        let partialIndex = try XCTUnwrap(logs.indices.dropFirst().first)

        logs[completedIndex].weight = 100
        logs[completedIndex].reps = 6
        logs[completedIndex].rpe = 8
        logs[completedIndex].isComplete = true
        repository.updateWorkoutSetLog(logs[completedIndex])
        logs[partialIndex].weight = 120
        logs[partialIndex].reps = 7
        logs[partialIndex].rpe = 9
        repository.updateWorkoutSetLog(logs[partialIndex])

        let replacement = try XCTUnwrap(repository.substituteActiveWorkoutExercise(
            currentExerciseID: original.id,
            substitute: timed
        ))
        let preservedCompletedSet = try XCTUnwrap(repository.workoutSetLogs.first { $0.id == logs[completedIndex].id })
        let clearedPartialSet = try XCTUnwrap(repository.workoutSetLogs.first { $0.id == logs[partialIndex].id })

        XCTAssertEqual(replacement.trackingType, timed.trackingType)
        XCTAssertEqual(replacement.targetReps, timed.defaultReps)
        XCTAssertNil(replacement.targetLoadKilograms)
        XCTAssertTrue(preservedCompletedSet.isComplete)
        XCTAssertEqual(preservedCompletedSet.weight, 100)
        XCTAssertEqual(preservedCompletedSet.reps, 6)
        XCTAssertEqual(preservedCompletedSet.rpe, 8)
        XCTAssertFalse(clearedPartialSet.isComplete)
        XCTAssertNil(clearedPartialSet.weight)
        XCTAssertNil(clearedPartialSet.reps)
        XCTAssertNil(clearedPartialSet.rpe)
    }

    @MainActor
    func testLargeWorkoutSnapshotBackgroundPersistenceEnqueuePerformance() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PersistentLiftRecord.self, PersistentSettings.self,
            PersistentWorkoutRecord.self, PersistentWorkoutState.self,
            configurations: configuration
        )
        let persistence = SwiftDataWorkoutPersistenceStore(context: container.mainContext)
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        var logs: [WorkoutSetLog] = []
        logs.reserveCapacity(25_000)
        for index in 0..<25_000 {
            let log = WorkoutSetLog(
                id: UUID(),
                prescriptionID: UUID(),
                performedAt: Date(timeIntervalSince1970: 1_800_000_000 - Double(index)),
                setNumber: index % 5 + 1,
                weight: Double(100 + index % 400),
                reps: index % 12 + 1,
                rpe: index % 10,
                isWarmup: index.isMultiple(of: 5),
                isComplete: true,
                workoutID: UUID(),
                recordedUnit: .pounds
            )
            logs.append(log)
        }
        repository.workoutSetLogs = logs
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTClockMetric()], options: options) {
            repository.persistWorkoutSnapshotWithoutBlockingUI()
        }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(persistence.loadSnapshot()?.setLogs.count, 25_000)
    }

    @MainActor
    func testDiskBackedRichWorkoutSnapshotSaveAndColdReloadPerformance() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiftRankPersistenceBenchmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let schema = Schema([PersistentWorkoutState.self])
        func makeContainer(at storeURL: URL) throws -> ModelContainer {
            let configuration = ModelConfiguration(
                "WorkoutPersistenceBenchmark",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        var completedWorkouts: [CompletedWorkout] = []
        var setLogs: [WorkoutSetLog] = []
        for workoutIndex in 0..<80 {
            let workoutID = UUID()
            let startedAt = referenceDate.addingTimeInterval(-Double(workoutIndex) * 86_400)
            let exercises = (0..<4).map { exerciseIndex in
                WorkoutExerciseSnapshot(
                    id: UUID(), sourcePrescriptionID: nil,
                    exerciseID: "benchmark_exercise_\(exerciseIndex)",
                    exerciseName: "Benchmark exercise \(exerciseIndex + 1)",
                    bodyPart: ["Chest", "Back", "Legs", "Shoulders"][exerciseIndex],
                    equipment: "Barbell", targetSets: 5, targetReps: "5-8",
                    restSeconds: 120, order: exerciseIndex, notes: "Recorded from a disk persistence benchmark.",
                    trackingType: "Weight + Reps"
                )
            }
            var workoutSets: [WorkoutSetLog] = []
            for (exerciseIndex, exercise) in exercises.enumerated() {
                for setIndex in 0..<5 {
                    let log = WorkoutSetLog(
                        id: UUID(), prescriptionID: exercise.id,
                        performedAt: startedAt.addingTimeInterval(Double(exerciseIndex * 300 + setIndex * 60)),
                        setNumber: setIndex + 1,
                        weight: Double(100 + workoutIndex + exerciseIndex * 10 + setIndex),
                        reps: 5 + setIndex, rpe: 6 + setIndex % 3,
                        isWarmup: false, isComplete: true, workoutID: workoutID,
                        recordedUnit: .pounds, completionSource: .manual
                    )
                    workoutSets.append(log)
                    setLogs.append(log)
                }
            }
            completedWorkouts.append(CompletedWorkout(
                id: workoutID, source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
                name: "Benchmark strength session \(workoutIndex + 1)",
                dayLabel: "Day \(workoutIndex % 7 + 1)",
                startedAt: startedAt, completedAt: startedAt.addingTimeInterval(1_800),
                duration: 1_800, effort: 3, notes: "Rich workout history sample for disk save and reload.",
                gymID: nil, bodyweight: 180, unit: .pounds,
                exercises: exercises, sets: workoutSets, linkedSubmissionIDs: []
            ))
        }

        let expectedSetCount = setLogs.count
        let expectedWorkoutCount = completedWorkouts.count
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var iteration = 0
        measure(metrics: [XCTClockMetric()], options: options) {
            iteration += 1
            let storeURL = directoryURL.appendingPathComponent("workout-\(UUID().uuidString).store")
            let expectedWeight = 1_200 + Double(iteration)
            do {
                do {
                    let container = try makeContainer(at: storeURL)
                    let persistence = SwiftDataWorkoutPersistenceStore(context: ModelContext(container))
                    let repository = DemoRepository(workoutPersistenceStore: persistence)
                    repository.completedWorkouts = completedWorkouts
                    repository.workoutSetLogs = setLogs
                    var changedLog = repository.workoutSetLogs[0]
                    changedLog.weight = expectedWeight
                    repository.updateWorkoutSetLog(changedLog)
                    var changedWorkout = repository.completedWorkouts[0]
                    changedWorkout.sets[0].weight = expectedWeight
                    repository.completedWorkouts[0] = changedWorkout
                    XCTAssertTrue(repository.persistWorkoutSnapshotReportingError())
                    XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
                }

                let container = try makeContainer(at: storeURL)
                let persistence = SwiftDataWorkoutPersistenceStore(context: ModelContext(container))
                let loaded = try XCTUnwrap(persistence.loadSnapshot())
                XCTAssertEqual(loaded.setLogs.count, expectedSetCount)
                XCTAssertEqual(loaded.completedWorkouts.count, expectedWorkoutCount)
                XCTAssertEqual(loaded.completedWorkouts[0].sets[0].weight, expectedWeight)
            } catch {
                XCTFail("Disk-backed workout save and cold reload failed: \(error)")
            }
        }
    }

    func testUsernameValidationRejectsAtSymbol() async {
        let service = MockProfileService(repository: DemoRepository())
        do {
            _ = try await service.changeUsername(currentUsername: "current", newUsername: "@Not Valid")
            XCTFail("Expected validation failure")
        } catch {
            XCTAssertEqual(error as? LiftRankServiceError, .invalidInput("Use 3–24 lowercase letters, numbers, or underscores."))
        }
    }

    func testWorkoutSyncPreservesAConflictCopy() async throws {
        let service = MockWorkoutSyncService()
        let plan = WorkoutPlan(id: UUID(), name: "Strength", createdAt: .now)
        let payload = WorkoutPlanSyncPayload(
            plan: plan,
            phases: [],
            weeks: [],
            sessions: [],
            prescriptions: [],
            progression: nil
        )
        let original = WorkoutPlanDocument(
            id: UUID(), ownerID: session.userID, revision: 0, name: "Strength",
            payload: try JSONEncoder().encode(payload), updatedAt: .now
        )
        guard case let .saved(saved) = try await service.savePlan(original, expectedRevision: 0) else {
            return XCTFail("Expected initial save")
        }
        var stale = original
        var stalePayload = payload
        stalePayload.plan.notes = "Stale edit"
        stale.payload = try JSONEncoder().encode(stalePayload)
        guard case let .conflict(server, localCopy) = try await service.savePlan(stale, expectedRevision: 0) else {
            return XCTFail("Expected a conflict")
        }
        XCTAssertEqual(server.revision, saved.revision)
        XCTAssertTrue(localCopy.isConflictCopy)
        XCTAssertNotEqual(localCopy.id, original.id)
    }

    func testWorkoutPlanConflictCopyIsCanonicalAndDeterministic() throws {
        let planID = UUID()
        let phaseA = WorkoutPhase(id: UUID(), planID: planID, name: "A", order: 0, goal: "Strength", durationWeeks: 4)
        let phaseB = WorkoutPhase(id: UUID(), planID: planID, name: "B", order: 1, goal: "Hypertrophy", durationWeeks: 3)
        let weekA = WorkoutWeek(id: UUID(), planID: planID, phaseID: phaseA.id, weekNumber: 1, title: "A1", notes: "")
        let weekB = WorkoutWeek(id: UUID(), planID: planID, phaseID: phaseB.id, weekNumber: 1, title: "B1", notes: "")
        let sessionA = WorkoutSession(id: UUID(), weekID: weekA.id, day: "Monday", name: "Bench", order: 0, notes: "")
        let sessionB = WorkoutSession(id: UUID(), weekID: weekA.id, day: "Friday", name: "Press", order: 1, notes: "")
        let prescription = WorkoutExercisePrescription(
            id: UUID(), sessionID: sessionA.id, exerciseID: "bench-press", exerciseName: "Bench Press",
            bodyPart: "Chest", equipment: "Barbell", sets: 3, reps: "5", restSeconds: 120, order: 0,
            notes: "Pause", targetLoadKilograms: 42.5
        )
        let plan = WorkoutPlan(
            id: planID, name: "Plan (Conflict copy) (Conflict copy)", createdAt: .now,
            isActive: false, queueEnabled: true, queuedSessionIDs: [sessionB.id, sessionA.id]
        )
        let payload = WorkoutPlanSyncPayload(
            plan: plan, phases: [phaseB, phaseA], weeks: [weekB, weekA],
            sessions: [sessionB, sessionA], prescriptions: [prescription],
            progression: WorkoutPlanProgressionSettings(
                planID: planID, sourceTemplateID: "strength", sourceTemplateVersion: 1,
                startedAt: .now, scheduledWeekdays: [1, 4], method: .linear,
                preferredUnit: .pounds, trainingMaxKilograms: ["bench-press": 100]
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let sortedEncoder = JSONEncoder()
        sortedEncoder.outputFormatting = [.sortedKeys]
        let ordinaryJSON = try encoder.encode(payload)
        var reorderedPayload = payload
        reorderedPayload.phases.reverse()
        let sortedJSON = try sortedEncoder.encode(reorderedPayload)
        XCTAssertNotEqual(ordinaryJSON, sortedJSON)

        let decoded = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: ordinaryJSON)
        let reordered = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: sortedJSON)
        XCTAssertEqual(decoded.canonicalized, reordered.canonicalized)
        XCTAssertEqual(decoded.conflictBaseName, "Plan")
        XCTAssertEqual(decoded.conflictCopyName, "Plan (Conflict copy)")

        let ownerID = UUID()
        let document = WorkoutPlanDocument(
            id: planID, ownerID: ownerID, revision: 7, name: plan.name,
            payload: ordinaryJSON, updatedAt: .now
        )
        let equivalentDocument = WorkoutPlanDocument(
            id: planID, ownerID: ownerID, revision: 7, name: plan.name,
            payload: sortedJSON, updatedAt: .now
        )
        let first = try document.conflictCopy(expectedRevision: 6)
        let retry = try equivalentDocument.conflictCopy(expectedRevision: 6)
        let firstPayload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: first.payload)
        let retryPayload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: retry.payload)

        XCTAssertEqual(first.id, retry.id)
        XCTAssertEqual(firstPayload, retryPayload)
        XCTAssertEqual(first.name, "Plan (Conflict copy)")
        XCTAssertEqual(first.conflictOfRevision, 6)
        XCTAssertTrue(first.isConflictCopy)
        let copyComparison = try XCTUnwrap(firstPayload.duplicateComparisonPayload)
        XCTAssertEqual(copyComparison, try XCTUnwrap(decoded.duplicateComparisonPayload))
        XCTAssertEqual(firstPayload.plan.queuedSessionIDs.count, 2)
        XCTAssertEqual(firstPayload.progression?.planID, first.id)

        var differentCreationDate = firstPayload
        differentCreationDate.plan.createdAt = differentCreationDate.plan.createdAt.addingTimeInterval(1)
        XCTAssertNotEqual(differentCreationDate.duplicateComparisonPayload, decoded.duplicateComparisonPayload)

        var differentTarget = firstPayload
        differentTarget.prescriptions[0].targetLoadKilograms = 43
        XCTAssertNotEqual(differentTarget.duplicateComparisonPayload, decoded.duplicateComparisonPayload)
        var differentQueue = firstPayload
        differentQueue.plan.queuedSessionIDs.reverse()
        XCTAssertNotEqual(differentQueue.duplicateComparisonPayload, decoded.duplicateComparisonPayload)
        var differentProgression = firstPayload
        differentProgression.progression?.trainingMaxKilograms["bench-press"] = 101
        XCTAssertNotEqual(differentProgression.duplicateComparisonPayload, decoded.duplicateComparisonPayload)
    }

    @MainActor
    func testWorkoutSyncStoreOwnsCompletedUploadQueueAndIdempotentRetry() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let completedAt = Date.now
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Synced workout", dayLabel: "Today", startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        let snapshot = CompletedWorkoutSnapshot(
            id: workout.id,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(workout),
            completedAt: completedAt
        )

        store.enqueueCompletedWorkout(snapshot)
        store.enqueueCompletedWorkout(snapshot)
        XCTAssertEqual(store.pendingCompletedWorkoutUploads.map(\.id), [snapshot.id])
        XCTAssertEqual(store.historySyncState, .local)

        await store.synchronizeCompletedWorkoutHistory()
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(store.pendingCompletedWorkoutUploads.isEmpty)
        XCTAssertEqual(store.historySyncState, .synced)
        let uploadedWorkoutIDs = try await service.completedWorkouts(since: nil).map(\.id)
        XCTAssertEqual(uploadedWorkoutIDs, [snapshot.id])
    }

    @MainActor
    func testWorkoutSyncStoreSurfacesUnreadableRemoteWorkoutsAndRecoversOnRetry() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let localCompletedAt = Date.now.addingTimeInterval(-3_600)
        let localWorkout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Local workout", dayLabel: "Monday", startedAt: localCompletedAt.addingTimeInterval(-600),
            completedAt: localCompletedAt, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        repository.completedWorkouts = [localWorkout]

        var validWorkout = localWorkout
        validWorkout.id = UUID()
        validWorkout.name = "Remote valid workout"
        validWorkout.startedAt = .now.addingTimeInterval(-1_200)
        validWorkout.completedAt = .now
        let unreadableID = UUID()
        try await service.uploadCompletedWorkout(CompletedWorkoutSnapshot(
            id: validWorkout.id,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(validWorkout),
            completedAt: validWorkout.completedAt
        ))
        try await service.uploadCompletedWorkout(CompletedWorkoutSnapshot(
            id: unreadableID,
            ownerID: repository.currentProfile.id,
            payload: Data("not a workout payload".utf8),
            completedAt: .now
        ))

        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertTrue(repository.completedWorkouts.contains { $0.id == localWorkout.id })
        XCTAssertTrue(repository.completedWorkouts.contains { $0.id == validWorkout.id })
        XCTAssertEqual(store.unreadableRemoteWorkoutCount, 1)
        XCTAssertEqual(store.historySyncState, .needsAttention)

        var correctedWorkout = validWorkout
        correctedWorkout.id = unreadableID
        correctedWorkout.name = "Corrected remote workout"
        try await service.uploadCompletedWorkout(CompletedWorkoutSnapshot(
            id: unreadableID,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(correctedWorkout),
            completedAt: correctedWorkout.completedAt
        ))
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(store.unreadableRemoteWorkoutCount, 0)
        XCTAssertEqual(store.historySyncState, .synced)
        XCTAssertTrue(repository.completedWorkouts.contains { $0.id == localWorkout.id })
        XCTAssertTrue(repository.completedWorkouts.contains { $0.id == validWorkout.id })
        XCTAssertTrue(repository.completedWorkouts.contains { $0.id == correctedWorkout.id })
    }

    @MainActor
    func testWorkoutSyncStoreSurfacesNeedsAttentionAfterUploadFailure() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = FailingCompletedWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let completedAt = Date.now
        let workout = CompletedWorkout(
            id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: "Retry workout", dayLabel: "Today", startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt, duration: 600, effort: 3, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        let snapshot = CompletedWorkoutSnapshot(
            id: workout.id,
            ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(workout),
            completedAt: completedAt
        )

        store.enqueueCompletedWorkout(snapshot)
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(store.historySyncState, .needsAttention)
        XCTAssertEqual(store.pendingCompletedWorkoutUploads.map(\.id), [snapshot.id])

        service.shouldFailUploads = false
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(store.historySyncState, .synced)
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
        XCTAssertEqual(store.historySyncState, .syncing)
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
    func testWorkoutSyncStoreUploadsPlannedSessionOutcomeChanges() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let plan = WorkoutPlan(id: UUID(), name: "Outcome plan", createdAt: .now)
        let phase = WorkoutPhase(id: UUID(), planID: plan.id, name: "Phase", order: 0, goal: "Training", durationWeeks: 1)
        let week = WorkoutWeek(id: UUID(), planID: plan.id, phaseID: phase.id, weekNumber: 1, title: "Week 1", notes: "")
        let session = WorkoutSession(id: UUID(), weekID: week.id, day: "Monday", name: "Lower", order: 0, notes: "")
        repository.workoutPlans = [plan]
        repository.workoutPhases = [phase]
        repository.workoutWeeks = [week]
        repository.workoutSessions = [session]

        let store = WorkoutSyncStore(repository: repository, service: service)
        await store.synchronizeWorkoutPlans()
        repository.setWorkoutSessionOutcome(session, outcome: .skipped)
        await store.synchronizeWorkoutPlans()

        let documents = try await service.plans()
        let document = try XCTUnwrap(documents.first(where: { $0.id == plan.id }))
        let payload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: document.payload)
        XCTAssertEqual(payload.sessions.first?.outcome, .skipped)
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
        let persistence = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
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
        var serverPayload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: serverDocument.payload)
        serverPayload.plan.notes = "Server edited notes"
        serverDocument.payload = try JSONEncoder().encode(serverPayload)
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
        let serverPlan = try XCTUnwrap(repository.workoutPlans.first { $0.id == plan.id })
        XCTAssertEqual(serverPlan.name, "Local Strength")
        XCTAssertEqual(serverPlan.notes, "Server edited notes")
        let conflict = try XCTUnwrap(repository.workoutPlans.first { $0.name == "Local Strength Edited (Conflict copy)" })
        XCTAssertNotEqual(conflict.id, plan.id)
        XCTAssertNotNil(repository.workoutPlanSyncRevisions[conflict.id])
        XCTAssertNotNil(repository.workoutPlanLastSyncedPayloads[conflict.id])

        let conflictID = conflict.id
        await store.synchronizeWorkoutPlans()
        let restored = DemoRepository(workoutPersistenceStore: persistence)
        await WorkoutSyncStore(repository: restored, service: service).synchronizeWorkoutPlans()
        XCTAssertEqual(repository.workoutPlans.filter { $0.name.hasSuffix("(Conflict copy)") }.map(\.id), [conflictID])
        XCTAssertEqual(restored.workoutPlans.filter { $0.name.hasSuffix("(Conflict copy)") }.map(\.id), [conflictID])
    }

    @MainActor
    func testWorkoutSyncStoreTreatsRevisionOnlyAdvanceAsNoOpAndAppliesRemoteOnlyEdit() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let plan = WorkoutPlan(id: UUID(), name: "Baseline", createdAt: .now, isActive: false)
        repository.addWorkoutPlan(plan)
        await store.synchronizeWorkoutPlans()

        let initialDocuments = try await service.plans()
        var remote = try XCTUnwrap(initialDocuments.first { $0.id == plan.id })
        guard case let .saved(revisionOnly) = try await service.savePlan(remote, expectedRevision: remote.revision) else {
            return XCTFail("Expected revision-only server advance")
        }
        await store.synchronizeWorkoutPlans()
        XCTAssertEqual(repository.workoutPlanSyncRevisions[plan.id], revisionOnly.revision)
        let noOpDocuments = try await service.plans()
        let revisionAfterNoOp = noOpDocuments.first { $0.id == plan.id }?.revision
        XCTAssertEqual(revisionAfterNoOp, revisionOnly.revision)

        var serverPayload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: revisionOnly.payload)
        serverPayload.plan.notes = "Remote-only note"
        remote = revisionOnly
        remote.payload = try JSONEncoder().encode(serverPayload)
        guard case let .saved(serverEdit) = try await service.savePlan(remote, expectedRevision: revisionOnly.revision) else {
            return XCTFail("Expected remote content edit")
        }
        await store.synchronizeWorkoutPlans()

        let applied = try XCTUnwrap(repository.workoutPlans.first { $0.id == plan.id })
        XCTAssertEqual(applied.notes, "Remote-only note")
        XCTAssertEqual(repository.workoutPlanSyncRevisions[plan.id], serverEdit.revision)
        XCTAssertEqual(repository.workoutPlans.filter { $0.name.hasSuffix("(Conflict copy)") }.count, 0)
    }

    @MainActor
    func testWorkoutSyncRetriesFailedDuplicateCopyCleanupAndPreservesReferencedCopies() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = MockWorkoutSyncService()

        func addDuplicate(of original: WorkoutPlan, active: Bool = false) -> WorkoutPlan {
            let base = WorkoutPlanSyncPayload(
                plan: original, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
            )
            let copyID = UUID()
            var copyPayload = base.conflictCopy(documentID: copyID)
            copyPayload.plan.isActive = active
            repository.workoutPlans.append(copyPayload.plan)
            return copyPayload.plan
        }

        let retryPlan = WorkoutPlan(id: UUID(), name: "Retry", createdAt: .now, isActive: false)
        repository.workoutPlans.append(retryPlan)
        let retryCopy = addDuplicate(of: retryPlan)

        let historyPlan = WorkoutPlan(id: UUID(), name: "History", createdAt: .now, isActive: false)
        repository.workoutPlans.append(historyPlan)
        let historyCopy = addDuplicate(of: historyPlan)
        let historyWorkout = CompletedWorkout(
            id: UUID(), source: .planned, sourceSessionID: nil, sourcePlanID: historyCopy.id,
            name: "Completed from conflict copy", dayLabel: "Monday", startedAt: .now.addingTimeInterval(-300),
            completedAt: .now, duration: 300, effort: 0, notes: "", gymID: nil,
            bodyweight: nil, unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
        )
        try await service.uploadCompletedWorkout(CompletedWorkoutSnapshot(
            id: historyWorkout.id, ownerID: repository.currentProfile.id,
            payload: try JSONEncoder().encode(historyWorkout), completedAt: historyWorkout.completedAt
        ))

        let activePlan = WorkoutPlan(id: UUID(), name: "Active", createdAt: .now, isActive: false)
        repository.workoutPlans.append(activePlan)
        let activeCopy = addDuplicate(of: activePlan, active: true)

        let uniquePlan = WorkoutPlan(id: UUID(), name: "Unique", createdAt: .now, isActive: false)
        repository.workoutPlans.append(uniquePlan)
        var uniqueCopy = addDuplicate(of: uniquePlan)
        uniqueCopy.notes = "Different training content"
        repository.updateWorkoutPlan(uniqueCopy)

        let store = WorkoutSyncStore(repository: repository, service: service)
        service.failNextPlanDeletion = true
        await store.synchronizeWorkoutPlans()
        XCTAssertTrue(repository.workoutPlans.contains { $0.id == retryCopy.id }, "A failed cleanup must retain the local copy")
        XCTAssertEqual(store.planSyncState, .needsAttention)

        await store.synchronizeWorkoutPlans()
        XCTAssertFalse(repository.workoutPlans.contains { $0.id == retryCopy.id }, "A later sync should retry safe cleanup")
        let afterRetry = try await service.plans()
        XCTAssertFalse(afterRetry.contains { $0.id == retryCopy.id })
        XCTAssertTrue(repository.workoutPlans.contains { $0.id == historyCopy.id }, "Remote workout history protects its source plan")
        XCTAssertTrue(repository.workoutPlans.contains { $0.id == activeCopy.id }, "An active conflict copy must never be deleted")
        XCTAssertTrue(repository.workoutPlans.contains { $0.id == uniqueCopy.id }, "Different content must remain separate")
        XCTAssertTrue(afterRetry.contains { $0.id == historyCopy.id })
        XCTAssertTrue(afterRetry.contains { $0.id == activeCopy.id })
        XCTAssertTrue(afterRetry.contains { $0.id == uniqueCopy.id })
    }

    @MainActor
    func testWorkoutSyncPreservesPlanEditMadeWhileSaveIsAwaited() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let plan = WorkoutPlan(id: UUID(), name: "Gated", createdAt: .now, isActive: false)
        repository.workoutPlans.append(plan)
        let baseline = WorkoutPlanSyncPayload(
            plan: plan, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
        )
        let baselineData = try JSONEncoder().encode(baseline)
        let document = WorkoutPlanDocument(
            id: plan.id, ownerID: repository.currentProfile.id, revision: 1,
            name: plan.name, payload: baselineData, updatedAt: .now
        )
        let remoteService = MockWorkoutSyncService()
        guard case .saved = try await remoteService.savePlan(document, expectedRevision: 0) else {
            return XCTFail("Expected initial remote plan")
        }
        var serverEdit = document
        var serverPayload = baseline
        serverPayload.plan.notes = "Server edit"
        serverEdit.payload = try JSONEncoder().encode(serverPayload)
        guard case .saved = try await remoteService.savePlan(serverEdit, expectedRevision: 1) else {
            return XCTFail("Expected remote content edit")
        }
        repository.workoutPlanSyncRevisions[plan.id] = 1
        repository.workoutPlanLastSyncedPayloads[plan.id] = baselineData
        var firstEdit = plan
        firstEdit.notes = "First edit"
        repository.updateWorkoutPlan(firstEdit)

        let service = GatedWorkoutPlanSaveService(service: remoteService)
        let store = WorkoutSyncStore(repository: repository, service: service)
        let sync = Task { await store.synchronizeWorkoutPlans() }
        while !service.saveStarted { await Task.yield() }

        var newerEdit = firstEdit
        newerEdit.notes = "Newer edit while save was pending"
        repository.updateWorkoutPlan(newerEdit)
        service.releaseSave()
        await sync.value

        let deadline = Date.now.addingTimeInterval(2)
        var preservedCopy = false
        while Date.now < deadline {
            let plans = try await service.plans()
            let originalRemote = plans.first { $0.id == plan.id }
            let originalNotes = originalRemote.flatMap {
                try? JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: $0.payload).plan.notes
            }
            preservedCopy = plans.contains { document in
                guard document.isConflictCopy,
                      let payload = try? JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: document.payload) else { return false }
                return payload.plan.notes == newerEdit.notes
            }
            if originalNotes == "Server edit" && preservedCopy { break }
            await Task.yield()
        }
        let remotePlans = try await service.plans()
        let originalRemote = try XCTUnwrap(remotePlans.first { $0.id == plan.id })
        XCTAssertEqual(try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: originalRemote.payload).plan.notes, "Server edit")
        XCTAssertTrue(preservedCopy, "The queued follow-up sync should preserve the newer edit in a conflict copy")
        XCTAssertTrue(repository.workoutPlans.contains { $0.name == "Gated (Conflict copy)" && $0.notes == newerEdit.notes })
    }

    @MainActor
    func testWorkoutSyncDoesNotDeleteDuplicateWhenRemoteRevisionChangesDuringCleanup() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let base = WorkoutPlan(id: UUID(), name: "Stable", createdAt: .now, isActive: false)
        let basePayload = WorkoutPlanSyncPayload(
            plan: base, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
        )
        let copyPayload = basePayload.conflictCopy(documentID: UUID())
        repository.workoutPlans = [base, copyPayload.plan]
        let encoder = JSONEncoder()
        let documents = [
            WorkoutPlanDocument(
                id: base.id, ownerID: repository.currentProfile.id, revision: 4,
                name: base.name, payload: try encoder.encode(basePayload), updatedAt: .now
            ),
            WorkoutPlanDocument(
                id: copyPayload.plan.id, ownerID: repository.currentProfile.id, revision: 4,
                name: copyPayload.plan.name, payload: try encoder.encode(copyPayload), updatedAt: .now,
                isConflictCopy: true
            )
        ]
        let service = GatedWorkoutPlanCleanupService(documents: documents)
        let store = WorkoutSyncStore(repository: repository, service: service)
        let sync = Task { await store.synchronizeWorkoutPlans() }
        while !service.historyRequestStarted { await Task.yield() }

        service.advanceRevision(for: copyPayload.plan.id)
        service.releaseHistory()
        await sync.value

        XCTAssertTrue(repository.workoutPlans.contains { $0.id == copyPayload.plan.id })
        let remoteAfterRace = try await service.plans()
        XCTAssertTrue(remoteAfterRace.contains { $0.id == copyPayload.plan.id })
        XCTAssertEqual(store.planSyncState, .needsAttention)
    }

    @MainActor
    func testWorkoutSyncStopsDuplicateCleanupAfterAccountSwitch() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let ownerID = repository.currentProfile.id
        let base = WorkoutPlan(id: UUID(), name: "Account", createdAt: .now, isActive: false)
        let basePayload = WorkoutPlanSyncPayload(
            plan: base, phases: [], weeks: [], sessions: [], prescriptions: [], progression: nil
        )
        let copyPayload = basePayload.conflictCopy(documentID: UUID())
        repository.workoutPlans = [base, copyPayload.plan]
        let encoder = JSONEncoder()
        let documents = [
            WorkoutPlanDocument(
                id: base.id, ownerID: ownerID, revision: 1,
                name: base.name, payload: try encoder.encode(basePayload), updatedAt: .now
            ),
            WorkoutPlanDocument(
                id: copyPayload.plan.id, ownerID: ownerID, revision: 1,
                name: copyPayload.plan.name, payload: try encoder.encode(copyPayload), updatedAt: .now,
                isConflictCopy: true
            )
        ]
        let service = GatedWorkoutPlanCleanupService(documents: documents)
        let store = WorkoutSyncStore(repository: repository, service: service)
        let sync = Task { await store.synchronizeWorkoutPlans() }
        while !service.historyRequestStarted { await Task.yield() }

        repository.currentProfile.id = UUID()
        service.releaseHistory()
        await sync.value

        let remoteAfterSwitch = try await service.plans()
        XCTAssertTrue(remoteAfterSwitch.contains { $0.id == copyPayload.plan.id })
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

    private func makeState(
        session: AccountSession?,
        onboardingCompleted: Bool,
        hasCurrentLegalAcceptance: Bool = true,
        includesLiftService: Bool = false
    ) -> AppState {
        makeState(
            authentication: TestAuthenticationService(session: session),
            onboardingCompleted: onboardingCompleted,
            hasCurrentLegalAcceptance: hasCurrentLegalAcceptance,
            includesLiftService: includesLiftService
        )
    }

    private func makeState(
        authentication: any AuthenticationService,
        onboardingCompleted: Bool,
        hasCurrentLegalAcceptance: Bool = true,
        includesLiftService: Bool = false,
        profileError: Error? = nil
    ) -> AppState {
        let repository = DemoRepository()
        let profile = TestProfileService(profile: AuthenticatedProfile(
            id: session.userID, username: "member_test", displayName: "Member Test", bio: "",
            avatarPath: nil, onboardingCompleted: onboardingCompleted, preferredUnit: .pounds,
            birthDate: nil, sexCategory: .male, heightCentimeters: nil, city: nil, region: nil,
            countryCode: nil, yearsExperience: nil, experienceLevel: .beginner,
            privacy: ProfilePrivacySettings()
        ))
        profile.authenticatedProfileError = profileError
        return AppState(repository: repository, serviceContainer: AppServiceContainer(
            authentication: authentication,
            profile: profile,
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            lifts: includesLiftService ? MockLiftService(repository: repository) : nil,
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
    func friendRequests() async throws -> [FriendRequest] { [] }
    func requestFriendship(userID: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func respondToFriendship(id: UUID, accept: Bool) async throws { throw LiftRankServiceError.configurationMissing }
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
    func friendRequests() async throws -> [FriendRequest] { [] }
    func requestFriendship(userID: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func respondToFriendship(id: UUID, accept: Bool) async throws { throw LiftRankServiceError.configurationMissing }
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
    func friendRequests() async throws -> [FriendRequest] { [] }
    func requestFriendship(userID: UUID) async throws { throw LiftRankServiceError.configurationMissing }
    func respondToFriendship(id: UUID, accept: Bool) async throws { throw LiftRankServiceError.configurationMissing }
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
private final class FailingWorkoutPersistenceStore: WorkoutPersistenceStore {
    private let writeError = NSError(
        domain: "WorkoutPersistenceTests",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Simulated write failure"]
    )

    var loadError: String? { nil }
    func loadSnapshot() -> WorkoutPersistenceSnapshot? { nil }
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) throws { throw writeError }
    func saveSnapshotWithoutBlockingUI(_ snapshot: WorkoutPersistenceSnapshot) async throws { throw writeError }
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] { [] }
    func reset() {}
}

@MainActor
private final class CountingWorkoutPersistenceStore: WorkoutPersistenceStore {
    private let writeError = NSError(
        domain: "WorkoutPersistenceTests",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Simulated write failure"]
    )

    var loadError: String? { nil }
    private(set) var saveCount = 0
    var failNextSave = false

    func loadSnapshot() -> WorkoutPersistenceSnapshot? { nil }

    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) throws {
        saveCount += 1
        guard failNextSave else { return }
        failNextSave = false
        throw writeError
    }

    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] { [] }
    func reset() { saveCount = 0 }
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
private final class FailingCompletedWorkoutSyncService: WorkoutSyncService {
    var shouldFailUploads = true
    private var snapshots: [CompletedWorkoutSnapshot] = []

    func plans() async throws -> [WorkoutPlanDocument] { [] }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws {}
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        snapshots.filter { since == nil || $0.completedAt > since! }
    }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        if shouldFailUploads { throw LiftRankServiceError.server("Sync failed") }
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)
    }
    func deleteCompletedWorkout(id: UUID) async throws { snapshots.removeAll { $0.id == id } }
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
    private(set) var historyRequestStarted = false
    private let documentsToReturn: [WorkoutPlanDocument]
    private let snapshotsToReturn: [CompletedWorkoutSnapshot]
    private var continuation: CheckedContinuation<[WorkoutPlanDocument], Never>?

    init(documents: [WorkoutPlanDocument], snapshots: [CompletedWorkoutSnapshot] = []) {
        documentsToReturn = documents
        snapshotsToReturn = snapshots
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
        var saved = document
        saved.revision = expectedRevision + 1
        return .saved(saved)
    }
    func deletePlan(id: UUID) async throws {}
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        historyRequestStarted = true
        return snapshotsToReturn
    }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {}
    func deleteCompletedWorkout(id: UUID) async throws {}
}

@MainActor
private final class GatedWorkoutPlanSaveService: WorkoutSyncService {
    private let service: MockWorkoutSyncService
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var didGateSave = false
    private(set) var saveStarted = false

    init(service: MockWorkoutSyncService) { self.service = service }

    func plans() async throws -> [WorkoutPlanDocument] { try await service.plans() }

    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        if !didGateSave {
            didGateSave = true
            saveStarted = true
            await withCheckedContinuation { saveContinuation = $0 }
        }
        return try await service.savePlan(document, expectedRevision: expectedRevision)
    }

    func releaseSave() {
        saveContinuation?.resume()
        saveContinuation = nil
    }

    func deletePlan(id: UUID) async throws { try await service.deletePlan(id: id) }
    func deleteDuplicatePlan(_ document: WorkoutPlanDocument) async throws -> Bool {
        try await service.deleteDuplicatePlan(document)
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        try await service.completedWorkouts(since: since)
    }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        try await service.uploadCompletedWorkout(snapshot)
    }
    func deleteCompletedWorkout(id: UUID) async throws { try await service.deleteCompletedWorkout(id: id) }
}

@MainActor
private final class GatedWorkoutPlanCleanupService: WorkoutSyncService {
    private var documents: [WorkoutPlanDocument]
    private let snapshots: [CompletedWorkoutSnapshot]
    private var historyContinuation: CheckedContinuation<[CompletedWorkoutSnapshot], Never>?
    private(set) var historyRequestStarted = false

    init(documents: [WorkoutPlanDocument], snapshots: [CompletedWorkoutSnapshot] = []) {
        self.documents = documents
        self.snapshots = snapshots
    }

    func plans() async throws -> [WorkoutPlanDocument] { documents }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func deletePlan(id: UUID) async throws { documents.removeAll { $0.id == id } }
    func deleteDuplicatePlan(_ document: WorkoutPlanDocument) async throws -> Bool {
        guard let current = documents.first(where: { $0.id == document.id }),
              current.ownerID == document.ownerID, current.revision == document.revision else { return false }
        documents.removeAll { $0.id == document.id }
        return true
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        historyRequestStarted = true
        return await withCheckedContinuation { historyContinuation = $0 }
    }
    func releaseHistory() {
        historyContinuation?.resume(returning: snapshots)
        historyContinuation = nil
    }
    func advanceRevision(for id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].revision += 1
    }
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
    var callbackError: Error?
    var passwordError: Error?
    var requiresEmailConfirmation = false
    var resendConfirmationError: Error?
    private(set) var callbackURLs: [URL] = []
    private(set) var updatedPasswords: [String] = []
    private(set) var signUpEmails: [String] = []
    private(set) var resentConfirmationEmails: [String] = []
    func handleAuthCallback(_ url: URL) async throws -> AccountSession {
        callbackURLs.append(url)
        if let callbackError { throw callbackError }
        return try XCTUnwrap(session)
    }
    func updatePassword(_ password: String) async throws {
        updatedPasswords.append(password)
        if let passwordError { throw passwordError }
    }
    init(session: AccountSession?, restoreError: Error? = nil) {
        self.session = session
        self.restoreError = restoreError
    }
    func restoreSession() async throws -> AccountSession? {
        if let restoreError { throw restoreError }
        return requiresEmailConfirmation ? nil : session
    }
    func signUp(email: String, password: String) async throws -> AccountSession {
        signUpEmails.append(email)
        return try XCTUnwrap(session)
    }
    func resendConfirmation(email: String) async throws {
        resentConfirmationEmails.append(email)
        if let resendConfirmationError { throw resendConfirmationError }
    }
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
    var saveProfileError: Error?
    var saveSettingsResponse: AuthenticatedProfile?
    var saveSettingsError: Error?
    var holdSettingsSave = false
    private(set) var settingsSaveStarted = false
    private var settingsSaveRelease: CheckedContinuation<Void, Never>?
    private(set) var settingsSaveRequests: [(settings: ProfileSettingsSnapshot, expected: ProfileSettingsSnapshot)] = []
    private(set) var lastSavedProfileDraft: ProfileDraft?
    var avatarDownload: ProfileAvatarDownload?
    var uploadedAvatarReturnPath: String?
    private(set) var saveProfileCount = 0
    private(set) var usernameChangeCount = 0
    private(set) var updateProfileCount = 0
    private(set) var uploadedAvatarPaths: [String] = []
    private(set) var downloadedAvatarPaths: [String] = []
    private(set) var removedAvatarPaths: [String?] = []
    private(set) var savedBodyweightEntries: [BodyweightEntry] = []
    var bodyweightSyncError: Error?
    var bodyweightSaveError: Error?
    var bodyweightDeleteError: Error?
    private(set) var deletedBodyweightIDs: [UUID] = []
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
    func saveSettings(_ settings: ProfileSettingsSnapshot, expected: ProfileSettingsSnapshot) async throws -> AuthenticatedProfile {
        settingsSaveRequests.append((settings: settings, expected: expected))
        if let saveSettingsError { throw saveSettingsError }
        if holdSettingsSave {
            settingsSaveStarted = true
            await withCheckedContinuation { continuation in
                settingsSaveRelease = continuation
            }
        }
        if let saveSettingsResponse { profile = saveSettingsResponse }
        return profile
    }
    func releaseSettingsSave() {
        settingsSaveRelease?.resume()
        settingsSaveRelease = nil
    }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        saveProfileCount += 1
        lastSavedProfileDraft = draft
        if let saveProfileError { throw saveProfileError }
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
    func changeUsername(currentUsername: String, newUsername: String) async throws -> String {
        usernameChangeCount += 1
        guard profile.username.caseInsensitiveCompare(currentUsername) == .orderedSame else {
            throw LiftRankServiceError.sessionExpired
        }
        let normalized = newUsername.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            throw LiftRankServiceError.invalidInput("Use 3–24 lowercase letters, numbers, or underscores.")
        }
        profile.username = normalized
        return normalized
    }
    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        PublicProfileCard(id: userID, username: profile.username, displayName: profile.displayName, bio: profile.bio, avatarPath: nil, ageBand: nil, sexCategory: profile.sexCategory, city: nil, region: nil, countryCode: nil, primaryGymID: nil, primaryGymName: nil, bodyweightPounds: nil, bodyweightLastUpdatedAt: nil)
    }
    func sharedWorkoutStats(userID: UUID) async throws -> SharedWorkoutStats? { nil }
    func recordFriendWorkoutStart(workoutID: UUID, ownerID: UUID) async throws {}
    func recordFriendTopLift(liftID: UUID) async throws {}
    func friendTrainingActivity() async throws -> [FriendTrainingActivity] { [] }
    func currentProfile() async throws -> UserProfile { MockData.demoProfile }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        updateProfileCount += 1
        var savedProfile = profile
        savedProfile.username = self.profile.username
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
        return savedProfile
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
        if let bodyweightSaveError { throw bodyweightSaveError }
        savedBodyweightEntries.removeAll { $0.id == entry.id }
        savedBodyweightEntries.append(entry)
        if let latest = savedBodyweightEntries
            .filter({ ($0.actual ?? 0) > 0 })
            .max(by: { $0.targetDate < $1.targetDate }),
           let actual = latest.actual {
            profile.bodyweightPounds = actual
        }
    }
    func deleteBodyweightEntry(id: UUID) async throws {
        if let bodyweightDeleteError { throw bodyweightDeleteError }
        deletedBodyweightIDs.append(id)
        savedBodyweightEntries.removeAll { $0.id == id }
        profile.bodyweightPounds = savedBodyweightEntries
            .filter { ($0.actual ?? 0) > 0 }
            .max(by: { $0.targetDate < $1.targetDate })?.actual ?? 0
    }
    func strengthGoalTargets() async throws -> [String: Double]? { nil }
    func saveStrengthGoalTargets(_ targets: [String: Double]) async throws {}
    func saveTrainingGoals(_ goalIDs: [String]) async throws {}
    func releaseBodyweightSave() {
        bodyweightSaveRelease?.resume()
        bodyweightSaveRelease = nil
    }
}
