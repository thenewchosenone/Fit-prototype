import XCTest
@testable import LiftRank

@MainActor
final class BackendFoundationTests: XCTestCase {
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
        await state.enterDemoMode()
        XCTAssertEqual(state.accountStatus, .demo)
        XCTAssertTrue(state.isDemoMode)
        XCTAssertNil(state.accountSession)
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
    init(profile: AuthenticatedProfile) { self.profile = profile }
    func authenticatedProfile() async throws -> AuthenticatedProfile { profile }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        profile.onboardingCompleted = draft.completesOnboarding
        return profile
    }
    func claimUsername(_ username: String) async throws -> String { username }
    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        PublicProfileCard(id: userID, username: profile.username, displayName: profile.displayName, bio: profile.bio, avatarPath: nil, ageBand: nil, sexCategory: profile.sexCategory, city: nil, region: nil, countryCode: nil, primaryGymID: nil, primaryGymName: nil)
    }
    func currentProfile() async throws -> UserProfile { MockData.demoProfile }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile { profile }
}
