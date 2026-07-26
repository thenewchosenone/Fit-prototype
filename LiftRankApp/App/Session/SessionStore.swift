import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var status: AccountStatus
    @Published private(set) var session: AccountSession?
    @Published private(set) var isOperationInProgress = false
    @Published var message: String?
    @Published private(set) var outstandingLegalDocuments: [LegalDocument] = []
    @Published private(set) var privacy = ProfilePrivacySettings()
    private var authenticationService: (any AuthenticationService)?
    private var legalAcceptanceService: (any LegalAcceptanceService)?
    private var accountDeletionService: (any AccountDeletionService)?

    init(
        status: AccountStatus = .restoring,
        session: AccountSession? = nil,
        authenticationService: (any AuthenticationService)? = nil,
        legalAcceptanceService: (any LegalAcceptanceService)? = nil,
        accountDeletionService: (any AccountDeletionService)? = nil
    ) {
        self.status = status
        self.session = session
        self.authenticationService = authenticationService
        self.legalAcceptanceService = legalAcceptanceService
        self.accountDeletionService = accountDeletionService
    }

    var isDemoMode: Bool { status == .demo }

    var isAuthenticated: Bool {
        status == .authenticated || status == .needsOnboarding || status == .needsLegalAcceptance
    }

    var isAuthenticationConfigured: Bool { authenticationService?.isConfigured == true }
    var usesDemoAuthenticationService: Bool { authenticationService?.isDemoMode == true }

    func updateServices(
        authenticationService: any AuthenticationService,
        legalAcceptanceService: any LegalAcceptanceService,
        accountDeletionService: any AccountDeletionService
    ) {
        self.authenticationService = authenticationService
        self.legalAcceptanceService = legalAcceptanceService
        self.accountDeletionService = accountDeletionService
    }

    func restoreAccountSession() async throws -> AccountSession? {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let restored = try await authenticationService.restoreSession()
        session = restored
        return restored
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> AccountSession {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let signedUp = try await authenticationService.signUp(email: email, password: password)
        session = signedUp
        return signedUp
    }

    func hasRestorableSession() async throws -> Bool {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        return try await authenticationService.restoreSession() != nil
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> AccountSession {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let signedIn = try await authenticationService.signIn(email: email, password: password)
        session = signedIn
        return signedIn
    }

    @discardableResult
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let signedIn = try await authenticationService.signInWithApple(identityToken: identityToken, nonce: nonce)
        session = signedIn
        return signedIn
    }

    func requestPasswordReset(email: String) async throws {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        try await authenticationService.requestPasswordReset(email: email)
    }

    @discardableResult
    func handleAuthCallback(_ url: URL) async throws -> AccountSession {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let callbackSession = try await authenticationService.handleAuthCallback(url)
        session = callbackSession
        return callbackSession
    }

    func updatePassword(_ password: String) async throws {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        try await authenticationService.updatePassword(password)
    }

    @discardableResult
    func enterDemoAuthentication() async throws -> UserProfile {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        let profile = try await authenticationService.signInDemo()
        session = nil
        message = nil
        status = .demo
        return profile
    }

    func signOut() async throws {
        guard let authenticationService else { throw LiftRankServiceError.configurationMissing }
        try await authenticationService.signOut()
    }

    func deleteAuthenticatedAccount() async throws {
        guard isAuthenticated, !isDemoMode else { throw LiftRankServiceError.permissionDenied }
        guard let accountDeletionService else { throw LiftRankServiceError.configurationMissing }
        try await accountDeletionService.deleteAccount()
        if let authenticationService {
            try? await authenticationService.signOut()
        }
    }

    @discardableResult
    func refreshLegalAcceptanceStatus() async throws -> [LegalDocument] {
        guard let legalAcceptanceService else { throw LiftRankServiceError.configurationMissing }
        guard let userID = session?.userID else { throw LiftRankServiceError.sessionExpired }
        let accepted = try await legalAcceptanceService.acceptances()
        guard session?.userID == userID else { throw LiftRankServiceError.sessionExpired }
        let acceptedKeys = Set(accepted.map { "\($0.documentKind):\($0.documentVersion)" })
        let outstanding = LegalDocument.current.filter {
            !acceptedKeys.contains("\($0.kind.rawValue):\($0.version)")
        }
        outstandingLegalDocuments = outstanding
        status = outstanding.isEmpty ? .authenticated : .needsLegalAcceptance
        return outstanding
    }

    func acceptCurrentLegalDocuments() async throws {
        guard isAuthenticated, !isDemoMode else { throw LiftRankServiceError.permissionDenied }
        guard let legalAcceptanceService else { throw LiftRankServiceError.configurationMissing }
        try await legalAcceptanceService.accept(documents: LegalDocument.current)
        try await refreshLegalAcceptanceStatus()
    }

    func transition(to status: AccountStatus) {
        self.status = status
    }

    func updateSession(_ session: AccountSession?) {
        self.session = session
    }

    func updateOutstandingLegalDocuments(_ documents: [LegalDocument]) {
        outstandingLegalDocuments = documents
    }

    func updatePrivacy(_ privacy: ProfilePrivacySettings) {
        self.privacy = privacy
    }

    @discardableResult
    func beginOperation() -> Bool {
        guard !isOperationInProgress else { return false }
        isOperationInProgress = true
        message = nil
        return true
    }

    func endOperation() {
        isOperationInProgress = false
    }

    func clearRemoteAccountState() {
        session = nil
        outstandingLegalDocuments = []
    }
}
