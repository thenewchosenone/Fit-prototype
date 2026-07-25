import XCTest
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
private final class TestAnalyticsCaptureService: AnalyticsService {
    private(set) var events: [AnalyticsEventRecord] = []
    func track(_ event: AnalyticsEventRecord) async { events.append(event) }
}

@MainActor
final class BackendFoundationTests: XCTestCase {
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

    func testFocusedProductionDefersBroadCommunityFeatures() {
        let features = FeatureAvailability.resolved(for: .production)

        XCTAssertTrue(features.connectionActivity)
        XCTAssertTrue(features.pushNotifications)
        XCTAssertFalse(features.communities)
        XCTAssertFalse(features.forums)
        XCTAssertFalse(features.messaging)
        XCTAssertFalse(features.gymFeeds)
        XCTAssertFalse(features.polls)
        XCTAssertFalse(features.savedAndWatchedPosts)
        XCTAssertFalse(features.advertising)
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

    func testFocusedLaunchProfileSourcesDoNotExposeHiddenGymControls() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let onboardingSource = repositoryRoot
            .appendingPathComponent("LiftRankApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("OnboardingView.swift")
        let editProfileSource = repositoryRoot
            .appendingPathComponent("LiftRankApp")
            .appendingPathComponent("Features")
            .appendingPathComponent("Profile")
            .appendingPathComponent("ProfileContentViews.swift")
        let source = try [
            String(contentsOf: onboardingSource, encoding: .utf8),
            String(contentsOf: editProfileSource, encoding: .utf8)
        ].joined(separator: "\n")

        XCTAssertTrue(
            source.contains("if appState.features.gymFeeds"),
            "Onboarding gym privacy controls should be gated by the gym feature flag."
        )
        XCTAssertFalse(
            source.contains("Locations appear when gyms are added to the directory."),
            "Launch location copy should not imply city choices depend on gym directory data."
        )
    }

    func testFocusedLaunchHidesGymAwardsFromAppState() {
        let repository = DemoRepository()
        repository.achievementUnlocks = [
            AchievementUnlock(id: "gym-top-10", title: "Gym Top 10", unlockedAt: .now),
            AchievementUnlock(id: "global-top-100", title: "Global Top 100", unlockedAt: .now)
        ]
        let container = AppServiceContainer(
            features: .focusedProduction,
            authentication: MockAuthenticationService(repository: repository),
            profile: MockProfileService(repository: repository),
            gyms: MockGymService(repository: repository),
            gymMemberships: MockGymMembershipService(repository: repository),
            friendships: MockFriendRelationshipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            lifts: MockLiftService(repository: repository),
            leaderboards: MockLeaderboardService(repository: repository),
            social: MockSocialService(repository: repository),
            communities: MockCommunityService(repository: repository),
            messaging: MockMessagingService(repository: repository),
            verification: MockVerificationService(repository: repository),
            media: MockMediaUploadService(),
            notifications: MockNotificationService(repository: repository),
            workoutSync: MockWorkoutSyncService(),
            analytics: MockAnalyticsService(),
            legalAcceptances: MockLegalAcceptanceService(),
            accountDeletion: MockAccountDeletionService()
        )
        let appState = AppState(repository: repository, serviceContainer: container)

        XCTAssertFalse(appState.achievements.contains { $0.title.localizedCaseInsensitiveContains("gym") })
        XCTAssertFalse(appState.achievementUnlocks.contains { $0.title.localizedCaseInsensitiveContains("gym") })
        XCTAssertTrue(appState.achievements.contains { $0.title == "Global Top 100" })
        XCTAssertTrue(appState.achievementUnlocks.contains { $0.title == "Global Top 100" })
    }

    func testAuthenticatedProfilePhotoDownloadsIntoLocalCache() async throws {
        let repository = DemoRepository()
        let userID = UUID()
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
            friendships: MockFriendRelationshipService(repository: repository),
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
            friendships: MockFriendRelationshipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestSessionLegalAcceptanceService(userID: userID)
        ))
        await appState.signIn(email: "avatar-cache@example.test", password: "password")
        let image = try XCTUnwrap(
            UIImage(systemName: "person.crop.circle.fill")?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        )

        appState.saveProfilePhoto(image)
        for _ in 0..<20 where service.updateProfileCount == 0 {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(appState.currentProfile.avatarPath, serverAvatarPath)
        XCTAssertNotNil(LocalProfilePhotoStore.shared.thumbnail(for: serverAvatarPath))
        LocalProfilePhotoStore.shared.remove(avatarPath: serverAvatarPath)
    }

    func testStagingDefaultsToFocusedLaunchFeatures() {
        let features = FeatureAvailability.resolved(
            for: .staging,
            arguments: [],
            processEnvironment: [:]
        )

        XCTAssertFalse(features.communities)
        XCTAssertFalse(features.forums)
        XCTAssertFalse(features.messaging)
    }

#if DEBUG
    func testDeferredFeaturesRequireExplicitDebugOptIn() {
        let features = FeatureAvailability.resolved(
            for: .staging,
            arguments: [FeatureAvailability.deferredFeaturesLaunchArgument],
            processEnvironment: [:]
        )

        XCTAssertTrue(features.communities)
        XCTAssertTrue(features.forums)
        XCTAssertTrue(features.messaging)
    }
#endif

    func testFocusedProductionFiltersDeferredNotifications() {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository, features: .focusedProduction)
        let workoutShareID = UUID()
        let notifications = [
            NotificationItem(
                id: UUID(), title: "Connection workout", message: "New workout", kind: "Workout",
                createdAt: .now, isRead: false,
                destination: NotificationDestination(kind: .workoutShare, targetID: workoutShareID)
            ),
            NotificationItem(
                id: UUID(), title: "Message", message: "Deferred", kind: "Message",
                createdAt: .now, isRead: false,
                destination: NotificationDestination(kind: .messageThread, targetID: UUID())
            ),
            NotificationItem(
                id: UUID(), title: "Forum", message: "Deferred", kind: "Forum",
                createdAt: .now, isRead: false,
                destination: NotificationDestination(kind: .forumPost, targetID: UUID())
            )
        ]

        store.replaceNotifications(notifications)

        XCTAssertEqual(store.notifications.map(\.destination.kind), [.workoutShare])
        XCTAssertEqual(store.open(store.notifications[0], fallbackGymID: UUID()), .workoutShare(workoutShareID))
    }

    func testAppRouterOwnsTypedTabSectionsAndExclusivePresentation() {
        let router = AppRouter()

        router.openTracker(.progress)
        XCTAssertEqual(router.selectedTab, .track)
        XCTAssertEqual(router.trackerSection, .progress)

        router.communitySection = .inbox
        router.setSheet(.settings, isPresented: true)
        XCTAssertEqual(router.communitySection, .inbox)
        XCTAssertEqual(router.sheet, .settings)

        router.setSheet(.submitLift, isPresented: true)
        XCTAssertEqual(router.sheet, .submitLift)
        router.setSheet(.settings, isPresented: false)
        XCTAssertEqual(router.sheet, .submitLift)
        router.setSheet(.submitLift, isPresented: false)
        XCTAssertNil(router.sheet)
    }

    func testAppStateRoutingCompatibilityForwardsIntoTypedRouter() throws {
        let appState = AppState()
        let profile = appState.currentProfile

        appState.selectedTab = 4
        appState.requestedTrackerSegment = "Library"
        appState.selectedCommunitySegment = "Explore"
        appState.selectedProfile = profile

        XCTAssertEqual(appState.router.selectedTab, .profile)
        XCTAssertEqual(appState.router.trackerSection, .library)
        XCTAssertEqual(appState.router.communitySection, .explore)
        guard case .profile(let routedProfile) = appState.router.sheet else {
            return XCTFail("Expected the profile sheet route")
        }
        XCTAssertEqual(routedProfile.id, profile.id)

        appState.selectedProfile = nil
        XCTAssertNil(appState.router.sheet)
        appState.showingForumComposer = true
        XCTAssertEqual(appState.router.cover, .forumComposer)
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

        let route = store.open(notification, fallbackGymID: UUID())

        guard case .leaderboard(let filters) = route else {
            return XCTFail("Expected a typed leaderboard route")
        }
        XCTAssertEqual(filters.exerciseID, "deadlift")
        XCTAssertEqual(filters.gymID, gymID)
        XCTAssertEqual(filters.rankingType, .poundForPound)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(try XCTUnwrap(store.notifications.first).isRead)
    }

    func testNotificationStoreResolvesTypedCommunityAndTrackerRoutes() {
        let repository = DemoRepository()
        let store = NotificationStore(repository: repository)
        let postID = repository.forumPosts[0].id
        var legacyThreadFixture = repository.communityThreads[0]
        legacyThreadFixture.id = UUID()
        repository.communityThreads.append(legacyThreadFixture)
        let legacyThreadID = legacyThreadFixture.id

        let post = NotificationItem(
            id: UUID(), title: "Reply", message: "New reply", kind: "Forum", createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .communityThread, targetID: postID)
        )
        let legacyThread = NotificationItem(
            id: UUID(), title: "Reply", message: "New reply", kind: "Community", createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .communityThread, targetID: legacyThreadID)
        )
        let progress = NotificationItem(
            id: UUID(), title: "Progress", message: "Review progress", kind: "Workout", createdAt: .now, isRead: false,
            destination: NotificationDestination(kind: .workoutTracker, trackerStartsOnProgress: true)
        )
        store.replaceNotifications([post, legacyThread, progress])

        XCTAssertEqual(store.open(post, fallbackGymID: UUID()), .forumPost(postID))
        XCTAssertEqual(store.open(legacyThread, fallbackGymID: UUID()), .communityThread(legacyThreadID))
        XCTAssertEqual(store.open(progress, fallbackGymID: UUID()), .tracker(.progress))
        XCTAssertEqual(store.unreadCount, 0)
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

    func testProfileStoreKeepsLocalAvatarWhenRemoteProfileHasNoAvatarYet() {
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

        XCTAssertEqual(store.currentProfile.avatarPath, "local-profile-photos/member-thumb.jpg")
    }

    func testProfileStoreOwnsRemoteEditedProfilePersistence() async throws {
        let repository = DemoRepository()
        let userID = UUID()
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
        edited.avatarPath = "avatars/updated.jpg"
        edited.preferredUnit = .kilograms
        edited.ageGroup = "30-34"
        edited.bodyweightPounds = 205
        edited.cityID = UUID()
        edited.city = "Miami"
        edited.state = "Florida"
        let gym = Gym(
            id: UUID(),
            name: "Downtown Strength",
            city: "Austin",
            state: "Texas",
            memberCount: 0,
            verifiedLiftCount: 0
        )
        let privacy = ProfilePrivacySettings(locationAudience: .friends)

        let saved = try await store.saveEditedProfile(
            edited,
            primaryGym: gym,
            privacy: privacy,
            authenticated: true
        )

        XCTAssertEqual(saved.id, userID)
        XCTAssertEqual(saved.displayName, "Updated Lifter")
        XCTAssertEqual(saved.avatarPath, "avatars/updated.jpg")
        XCTAssertEqual(saved.primaryGymID, gym.id)
        XCTAssertEqual(saved.bodyweightPounds, 205)
        XCTAssertEqual(saved.cityID, edited.cityID)
        XCTAssertEqual(saved.city, "Miami")
        XCTAssertEqual(saved.state, "Florida")
        XCTAssertEqual(service.profile.bio, "Keep this bio")
        XCTAssertEqual(
            ProfileDisplayFormatting.ageGroup(for: try XCTUnwrap(service.profile.birthDate)),
            "30-34"
        )
        XCTAssertEqual(service.profile.bodyweightPounds, 205)
        XCTAssertEqual(service.profile.cityID, edited.cityID)
        XCTAssertEqual(service.profile.city, "Miami")
        XCTAssertEqual(service.profile.region, "Florida")
        XCTAssertEqual(service.profile.privacy.locationAudience, .friends)
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
            friendships: MockFriendRelationshipService(repository: repository),
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
            friendships: MockFriendRelationshipService(repository: repository),
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

        let loaded = try await store.loadAuthenticatedProfile(retainingDemoProfiles: false)
        XCTAssertEqual(loaded.id, userID)
        XCTAssertEqual(store.profiles.map(\.id), [userID])

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
            privacy: ProfilePrivacySettings(locationAudience: .friends),
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

    func testProfileStoreOwnsGymMembershipLimitAndPrimaryProtection() {
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
        XCTAssertTrue(store.isGymJoined(primary.id))

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
        try await store.signOut()
        XCTAssertEqual(authentication.signOutCount, 1)
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

        await store.registerPushToken("token-value", userID: userID, environment: "sandbox")
        let registration = try XCTUnwrap(service.registrations.first)
        XCTAssertEqual(registration.userID, userID)
        XCTAssertEqual(registration.deviceID, "test-device")
        XCTAssertEqual(registration.token, "token-value")
        XCTAssertEqual(registration.environment, "sandbox")

        await store.revokeCurrentDevice()
        XCTAssertEqual(service.revokedDeviceIDs, ["test-device"])
    }

    func testNotificationDestinationDecodesServerMinimalPayload() throws {
        let threadID = UUID()
        let data = try XCTUnwrap("{\"kind\":\"messageThread\",\"targetID\":\"\(threadID.uuidString)\"}".data(using: .utf8))
        let destination = try JSONDecoder().decode(NotificationDestination.self, from: data)
        XCTAssertEqual(destination.kind, .messageThread)
        XCTAssertEqual(destination.targetID, threadID)
        XCTAssertFalse(destination.trackerStartsOnProgress)
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
            friendships: MockFriendRelationshipService(repository: repository),
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

    func testExplicitDemoSelectionIsIsolated() async {
        let state = makeState(session: nil, onboardingCompleted: false)
        await state.restoreAccount()
        XCTAssertFalse(state.serviceContainer.lifts is MockLiftService)
        await state.enterDemoMode()
        XCTAssertEqual(state.accountStatus, .demo)
        XCTAssertTrue(state.isDemoMode)
        XCTAssertNil(state.accountSession)
        XCTAssertTrue(state.serviceContainer.lifts is MockLiftService)

        await state.signOutAccount()
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertFalse(state.serviceContainer.lifts is MockLiftService)
    }

    func testMockSocialServicePersistsBlockRelationships() async throws {
        let repository = DemoRepository()
        let service = MockSocialService(repository: repository)
        let otherUserID = try XCTUnwrap(repository.profiles.first {
            $0.id != repository.currentProfile.id
        }?.id)

        try await service.block(userID: otherUserID)
        let blockedIDs = try await service.blocks().map(\.blockedID)
        XCTAssertEqual(blockedIDs, [otherUserID])

        try await service.unblock(userID: otherUserID)
        let remainingBlocks = try await service.blocks()
        XCTAssertTrue(remainingBlocks.isEmpty)
    }

    func testAccountSocialStoreOwnsDirectoryRelationshipsBlockingAndCleanup() async throws {
        let repository = DemoRepository()
        let profileStore = ProfileStore(repository: repository)
        let socialService = MockSocialService(repository: repository)
        let store = AccountSocialStore(
            repository: repository,
            profileStore: profileStore,
            gymService: MockGymService(repository: repository),
            gymMembershipService: MockGymMembershipService(repository: repository),
            friendRelationshipService: MockFriendRelationshipService(repository: repository),
            profileService: MockProfileService(repository: repository),
            socialService: socialService
        )

        try await store.refreshDirectoryAndRelationships()
        XCTAssertEqual(Set(store.gymMemberships.map(\.gymID)), repository.joinedGymIDs)
        XCTAssertEqual(store.friendRelationships.count, repository.friendRequests.count)

        if let originalPrimary = repository.gyms.first(where: {
            $0.id == repository.currentProfile.primaryGymID
        }), let additionalGym = repository.gyms.first(where: {
            !repository.joinedGymIDs.contains($0.id)
        }) {
            let joinedAdditionalGym = try await store.ensureGymJoined(
                additionalGym,
                maximumMemberships: 3,
                authenticated: true
            )
            XCTAssertTrue(joinedAdditionalGym)
            XCTAssertTrue(profileStore.isGymJoined(additionalGym.id))
            try await store.setPrimaryGym(additionalGym, authenticated: true)
            XCTAssertTrue(profileStore.isPrimaryGym(additionalGym.id))
            try await store.setPrimaryGym(originalPrimary, authenticated: true)
            try await store.leaveGym(additionalGym, authenticated: true)
            XCTAssertFalse(profileStore.isGymJoined(additionalGym.id))
        }

        let blockedUserID = try XCTUnwrap(repository.activities.first {
            $0.profile.id != repository.currentProfile.id
        }?.profile.id)
        XCTAssertTrue(repository.activities.contains { $0.profile.id == blockedUserID })
        try await store.setBlocked(blockedUserID, blocked: true)
        XCTAssertTrue(store.isBlocked(blockedUserID))
        XCTAssertFalse(repository.activities.contains { $0.profile.id == blockedUserID })

        store.clear()
        XCTAssertTrue(store.gymMemberships.isEmpty)
        XCTAssertTrue(store.friendRelationships.isEmpty)
        XCTAssertTrue(store.blocks.isEmpty)
    }

    func testFeatureStoresHydrateProductionDataThroughTheirServices() async {
        let local = DemoRepository()
        local.lifts = []
        local.activities = []
        local.forumCommunities = []
        local.forumPosts = []
        local.forumComments = []
        local.messageThreads = []
        local.directMessages = []
        local.notifications = []

        let remote = DemoRepository()
        let competition = CompetitionStore(
            repository: local,
            liftService: MockLiftService(repository: remote)
        )
        let community = CommunityStore(
            repository: local,
            socialService: MockSocialService(repository: remote),
            communityService: MockCommunityService(repository: remote)
        )
        let messaging = SocialMessagingStore(
            repository: local,
            messagingService: MockMessagingService(repository: remote)
        )
        let notifications = NotificationStore(
            repository: local,
            notificationService: MockNotificationService(repository: remote)
        )

        await competition.refreshProductionData()
        await community.refreshProductionData()
        await messaging.refreshProductionData()
        await notifications.refreshProductionData()

        XCTAssertEqual(local.lifts.map(\.id), remote.lifts.map(\.id))
        XCTAssertEqual(local.activities.map(\.id), remote.activities.map(\.id))
        XCTAssertEqual(local.forumCommunities.map(\.id), remote.visibleForumCommunities().map(\.id))
        XCTAssertEqual(local.forumPosts.map(\.id), remote.forumPosts.map(\.id))
        XCTAssertEqual(Set(local.forumComments.map(\.id)), Set(remote.forumComments.map(\.id)))
        XCTAssertEqual(local.messageThreads.map(\.id), remote.messageThreads.map(\.id))
        XCTAssertEqual(Set(local.directMessages.map(\.id)), Set(remote.directMessages.map(\.id)))
        XCTAssertEqual(local.notifications.map(\.id), remote.notifications.map(\.id))
    }

    func testFeatureStoresClearSeededDataWhenProductionServicesAreUnavailable() async {
        let repository = DemoRepository()
        let competition = CompetitionStore(repository: repository)
        let community = CommunityStore(repository: repository)
        let messaging = SocialMessagingStore(repository: repository)
        let notifications = NotificationStore(repository: repository)

        await competition.refreshProductionData()
        await community.refreshProductionData()
        await messaging.refreshProductionData()
        await notifications.refreshProductionData()

        XCTAssertTrue(repository.lifts.isEmpty)
        XCTAssertTrue(repository.activities.isEmpty)
        XCTAssertTrue(repository.forumCommunities.isEmpty)
        XCTAssertTrue(repository.forumMemberships.isEmpty)
        XCTAssertTrue(repository.forumPosts.isEmpty)
        XCTAssertTrue(repository.forumComments.isEmpty)
        XCTAssertTrue(repository.messageThreads.isEmpty)
        XCTAssertTrue(repository.directMessages.isEmpty)
        XCTAssertTrue(repository.notifications.isEmpty)
    }

    func testRepositoryClearLocalUserDataRemovesSeededVisibleCollections() {
        let repository = DemoRepository()

        repository.clearLocalUserData()

        XCTAssertTrue(repository.profiles.isEmpty)
        XCTAssertTrue(repository.gyms.isEmpty)
        XCTAssertTrue(repository.joinedGymIDs.isEmpty)
        XCTAssertTrue(repository.lifts.isEmpty)
        XCTAssertTrue(repository.activities.isEmpty)
        XCTAssertTrue(repository.activityComments.isEmpty)
        XCTAssertTrue(repository.friendRequests.isEmpty)
        XCTAssertTrue(repository.communityThreads.isEmpty)
        XCTAssertTrue(repository.communityThreadReplies.isEmpty)
        XCTAssertTrue(repository.forumCommunities.isEmpty)
        XCTAssertTrue(repository.forumMemberships.isEmpty)
        XCTAssertTrue(repository.forumPosts.isEmpty)
        XCTAssertTrue(repository.forumComments.isEmpty)
        XCTAssertTrue(repository.messageThreads.isEmpty)
        XCTAssertTrue(repository.directMessages.isEmpty)
        XCTAssertTrue(repository.notifications.isEmpty)
        XCTAssertTrue(repository.achievementUnlocks.isEmpty)
        XCTAssertTrue(repository.rankingHistory.isEmpty)
    }

    func testSignOutClearsAccountSocialState() async {
        let state = makeState(session: session, onboardingCompleted: true)
        await state.restoreAccount()
        await state.signOutAccount()
        XCTAssertEqual(state.accountStatus, .signedOut)
        XCTAssertNil(state.accountSession)
        XCTAssertTrue(state.remoteGymMemberships.isEmpty)
        XCTAssertTrue(state.remoteFriendRelationships.isEmpty)
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
        XCTAssertTrue(repository.deletedCompletedWorkoutIDs.contains(workout.id))
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
            friendships: MockFriendRelationshipService(repository: repository),
            exercises: MockExerciseCatalogService(),
            legalAcceptances: TestLegalAcceptanceService(userID: session.userID, accepted: hasCurrentLegalAcceptance)
        ))
    }
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
    var avatarDownload: ProfileAvatarDownload?
    var uploadedAvatarReturnPath: String?
    private(set) var saveProfileCount = 0
    private(set) var updateProfileCount = 0
    private(set) var uploadedAvatarPaths: [String] = []
    private(set) var downloadedAvatarPaths: [String] = []
    private(set) var removedAvatarPaths: [String?] = []
    init(profile: AuthenticatedProfile) { self.profile = profile }
    func authenticatedProfile() async throws -> AuthenticatedProfile { profile }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        saveProfileCount += 1
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
        return uploadedAvatarReturnPath ?? avatarPath
    }
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? {
        downloadedAvatarPaths.append(avatarPath)
        return avatarDownload
    }
    func removeProfileAvatar(avatarPath: String?) async throws {
        removedAvatarPaths.append(avatarPath)
    }
}
