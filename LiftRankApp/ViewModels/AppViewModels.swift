import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    static let maximumJoinedGyms = 3
    let profilePhotoStore: ProfilePhotoStore = LocalProfilePhotoStore.shared
    let repository: DemoRepository
    @Published var selectedWorkoutPlanID = MockData.defaultWorkoutPlanID
    @Published var showingPasswordUpdate = false
    private var cancellables = Set<AnyCancellable>()
    let router: AppRouter
    let sessionStore: SessionStore
    let profileStore: ProfileStore
    let accountSocialStore: AccountSocialStore
    let activeWorkoutStore: ActiveWorkoutStore
    let workoutPRSubmissionStore: WorkoutPRSubmissionStore
    let programStore: ProgramStore
    let workoutSyncStore: WorkoutSyncStore
    let trainingProgressStore: TrainingProgressStore
    let exerciseLibraryStore: ExerciseLibraryStore
    let competitionStore: CompetitionStore
    let communityStore: CommunityStore
    let socialMessagingStore: SocialMessagingStore
    let notificationStore: NotificationStore
    let analyticsStore: AnalyticsStore
    let features: FeatureAvailability

    private let launchServiceContainer: AppServiceContainer
    private(set) var serviceContainer: AppServiceContainer!

    private(set) var accountStatus: AccountStatus {
        get { sessionStore.status }
        set { sessionStore.transition(to: newValue) }
    }

    private(set) var accountSession: AccountSession? {
        get { sessionStore.session }
        set { sessionStore.updateSession(newValue) }
    }

    var accountOperationInProgress: Bool { sessionStore.isOperationInProgress }

    var accountMessage: String? {
        get { sessionStore.message }
        set { sessionStore.message = newValue }
    }

    var remoteGymMemberships: [GymMembershipRecord] { accountSocialStore.gymMemberships }
    var remoteFriendRelationships: [FriendRelationshipRecord] { accountSocialStore.friendRelationships }
    var remoteBlocks: [UserBlockRecord] { accountSocialStore.blocks }

    private(set) var outstandingLegalDocuments: [LegalDocument] {
        get { sessionStore.outstandingLegalDocuments }
        set { sessionStore.updateOutstandingLegalDocuments(newValue) }
    }

    private(set) var authenticatedPrivacy: ProfilePrivacySettings {
        get { sessionStore.privacy }
        set { sessionStore.updatePrivacy(newValue) }
    }

    init(repository: DemoRepository? = nil, serviceContainer: AppServiceContainer? = nil) {
        let resolvedRepository = repository ?? DemoRepository()
        let resolvedServiceContainer = serviceContainer ?? AppServiceContainer.make(repository: resolvedRepository)
        self.launchServiceContainer = resolvedServiceContainer
        self.features = resolvedServiceContainer.features
        self.repository = resolvedRepository
        self.router = AppRouter()
        self.sessionStore = SessionStore(
            authenticationService: resolvedServiceContainer.authentication,
            legalAcceptanceService: resolvedServiceContainer.legalAcceptances,
            accountDeletionService: resolvedServiceContainer.accountDeletion
        )
        let resolvedProfileStore = ProfileStore(
            repository: resolvedRepository,
            profileService: resolvedServiceContainer.profile
        )
        self.profileStore = resolvedProfileStore
        self.accountSocialStore = AccountSocialStore(
            repository: resolvedRepository,
            profileStore: resolvedProfileStore,
            gymService: resolvedServiceContainer.gyms,
            gymMembershipService: resolvedServiceContainer.gymMemberships,
            friendRelationshipService: resolvedServiceContainer.friendships,
            profileService: resolvedServiceContainer.profile,
            socialService: resolvedServiceContainer.social
        )
        self.activeWorkoutStore = ActiveWorkoutStore(repository: resolvedRepository)
        self.programStore = ProgramStore(repository: resolvedRepository)
        self.workoutSyncStore = WorkoutSyncStore(
            repository: resolvedRepository,
            service: resolvedServiceContainer.workoutSync
        )
        self.trainingProgressStore = TrainingProgressStore(repository: resolvedRepository)
        self.exerciseLibraryStore = ExerciseLibraryStore(repository: resolvedRepository)
        let resolvedCompetitionStore = CompetitionStore(
            repository: resolvedRepository,
            liftService: resolvedServiceContainer.lifts,
            leaderboardService: resolvedServiceContainer.leaderboards,
            verificationService: resolvedServiceContainer.verification,
            mediaUploadService: resolvedServiceContainer.media,
            analyticsService: resolvedServiceContainer.analytics
        )
        self.competitionStore = resolvedCompetitionStore
        self.workoutPRSubmissionStore = WorkoutPRSubmissionStore(
            repository: resolvedRepository,
            liftSubmitter: resolvedCompetitionStore,
            exercise: { exerciseID in
                MockData.exercises.first { $0.id == exerciseID }
            }
        )
        self.communityStore = CommunityStore(
            repository: resolvedRepository,
            socialService: resolvedServiceContainer.social,
            communityService: resolvedServiceContainer.communities
        )
        self.socialMessagingStore = SocialMessagingStore(
            repository: resolvedRepository,
            messagingService: resolvedServiceContainer.messaging
        )
        self.notificationStore = NotificationStore(
            repository: resolvedRepository,
            notificationService: resolvedServiceContainer.notifications,
            features: resolvedServiceContainer.features
        )
        self.analyticsStore = AnalyticsStore(service: resolvedServiceContainer.analytics)
        self.serviceContainer = resolvedServiceContainer
        self.repository.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        self.competitionStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        self.sessionStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        self.accountSocialStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        self.router.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    var leaderboardFocusRequestID: UUID? {
        get { competitionStore.focusRequestID }
        set { competitionStore.focusRequestID = newValue }
    }

    var leaderboardFilters: LeaderboardFilters {
        get { competitionStore.filters }
        set { competitionStore.filters = newValue }
    }

    var verifiedOnly: Bool {
        get { competitionStore.verifiedOnly }
        set { competitionStore.verifiedOnly = newValue }
    }

    var uploadProgress: Double {
        get { competitionStore.uploadProgress }
        set { competitionStore.uploadProgress = newValue }
    }

    var lastSubmissionResult: LiftSubmission? {
        get { competitionStore.lastSubmissionResult }
        set { competitionStore.lastSubmissionResult = newValue }
    }

    var isDemoMode: Bool { sessionStore.isDemoMode }
    var isAuthenticated: Bool { sessionStore.isAuthenticated }

    static var allowsDemoMode: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    func restoreAccount() async {
        guard accountStatus == .restoring else { return }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-removePersonalWorkoutDemoHistory") {
            repository.removePersonalWorkoutDemoHistory()
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingAuthentication") {
            serviceContainer = .demo(repository: repository)
            accountStatus = .signedOut
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingDemoMode") {
            await enterDemoMode()
            if ProcessInfo.processInfo.arguments.contains("-uiTestingNoActiveWorkout") {
                repository.discardActiveWorkout()
            }
            if ProcessInfo.processInfo.arguments.contains("-uiTestingActiveWorkout") {
                repository.discardActiveWorkout()
                _ = repository.startFreestyleWorkout(
                    name: "Upper Strength",
                    gymID: nil,
                    bodyweight: currentProfile.bodyweightPounds,
                    unit: currentProfile.preferredUnit
                )
                let shouldAddExercise = ProcessInfo.processInfo.arguments.contains("-uiTestingActiveWorkoutWithExercise") ||
                    ProcessInfo.processInfo.arguments.contains("-uiTestingCompletedActiveSet")
                if shouldAddExercise,
                   let bench = trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }) {
                    repository.addExercisesToActiveWorkout([bench])
                    if ProcessInfo.processInfo.arguments.contains("-uiTestingCompletedActiveSet"),
                       var log = repository.workoutSetLogs.first(where: { $0.workoutID == repository.activeWorkout?.id }) {
                        log.weight = 225
                        log.reps = 5
                        repository.updateWorkoutSetLog(log)
                        _ = repository.applyWorkoutSetCompletion(
                            logID: log.id,
                            isComplete: true,
                            source: .manual
                        )
                    }
                }
            }
            return
        }
#endif
        guard sessionStore.isAuthenticationConfigured else {
            accountStatus = .configurationRequired
            return
        }
        do {
            guard let session = try await sessionStore.restoreAccountSession() else {
                accountStatus = .signedOut
                return
            }
            accountSession = session
            try await loadAuthenticatedAccount()
        } catch {
            accountMessage = userMessage(error)
            accountStatus = .signedOut
        }
    }

    func signUp(email: String, password: String) async {
        await performAccountOperation {
            self.accountSession = try await self.sessionStore.signUp(email: email, password: password)
            if try await self.sessionStore.hasRestorableSession() == false {
                self.accountMessage = "Check your email to confirm your account, then sign in."
                self.accountStatus = .signedOut
            } else {
                try await self.loadAuthenticatedAccount()
                await self.track(.signupCompleted)
            }
        }
    }

    func signIn(email: String, password: String) async {
        await performAccountOperation {
            self.accountSession = try await self.sessionStore.signIn(email: email, password: password)
            try await self.loadAuthenticatedAccount()
        }
    }

    func signInWithApple(identityToken: String, nonce: String) async {
        await performAccountOperation {
            self.accountSession = try await self.sessionStore.signInWithApple(identityToken: identityToken, nonce: nonce)
            try await self.loadAuthenticatedAccount()
        }
    }

    func requestPasswordReset(email: String) async {
        await performAccountOperation {
            try await self.sessionStore.requestPasswordReset(email: email)
            self.accountMessage = "If an account can receive a reset email, instructions are on the way."
            self.accountStatus = .signedOut
        }
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme?.lowercased() == "liftrank",
              url.host?.lowercased() == "auth-callback" else { return }
        let isRecovery = Self.authCallbackValue(named: "type", in: url) == "recovery"
        await performAccountOperation {
            self.accountSession = try await self.sessionStore.handleAuthCallback(url)
            try await self.loadAuthenticatedAccount()
            self.showingPasswordUpdate = isRecovery
        }
    }

    func updatePassword(_ password: String) async {
        await performAccountOperation {
            guard password.count >= 10 else {
                throw LiftRankServiceError.invalidInput("Use at least 10 characters for your password.")
            }
            try await self.sessionStore.updatePassword(password)
            self.showingPasswordUpdate = false
            self.accountMessage = "Your password has been updated."
        }
    }

    private static func authCallbackValue(named name: String, in url: URL) -> String? {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let value = queryItems.first(where: { $0.name == name })?.value { return value }
        guard let fragment = url.fragment else { return nil }
        return URLComponents(string: "https://callback.invalid/?\(fragment)")?
            .queryItems?.first(where: { $0.name == name })?.value
    }

    func enterDemoMode() async {
        guard Self.allowsDemoMode else {
            accountMessage = "Demo mode is unavailable in production builds."
            accountStatus = sessionStore.isAuthenticationConfigured ? .signedOut : .configurationRequired
            return
        }
        repository.seedPersonalWorkoutDemoHistory()
        selectedWorkoutPlanID = PersonalWorkoutPlanCatalog.planID
        installServiceContainer(.demo(repository: repository))
        do {
            try await sessionStore.enterDemoAuthentication()
            accountStatus = .demo
        } catch {
            accountMessage = userMessage(error)
            accountStatus = sessionStore.isAuthenticationConfigured ? .signedOut : .configurationRequired
        }
    }

    func signOutAccount() async {
        let wasDemoMode = isDemoMode
        if isAuthenticated, !wasDemoMode { await notificationStore.revokeCurrentDevice() }
        do { try await sessionStore.signOut() } catch { accountMessage = userMessage(error) }
        if wasDemoMode { installServiceContainer(launchServiceContainer) }
        sessionStore.clearRemoteAccountState()
        accountSocialStore.clear()
        profilePhotoStore.clearMemoryCache()
        accountStatus = sessionStore.isAuthenticationConfigured ? .signedOut : .configurationRequired
    }

    private func installServiceContainer(_ container: AppServiceContainer) {
        serviceContainer = container
        sessionStore.updateServices(
            authenticationService: container.authentication,
            legalAcceptanceService: container.legalAcceptances,
            accountDeletionService: container.accountDeletion
        )
        competitionStore.updateServices(
            liftService: container.lifts,
            leaderboardService: container.leaderboards,
            verificationService: container.verification,
            mediaUploadService: container.media,
            analyticsService: container.analytics
        )
        profileStore.updateService(container.profile)
        accountSocialStore.updateServices(
            gymService: container.gyms,
            gymMembershipService: container.gymMemberships,
            friendRelationshipService: container.friendships,
            profileService: container.profile,
            socialService: container.social
        )
        communityStore.updateServices(
            socialService: container.social,
            communityService: container.communities
        )
        socialMessagingStore.updateService(container.messaging)
        notificationStore.updateService(container.notifications)
        analyticsStore.updateService(container.analytics)
    }

    func deleteAuthenticatedAccount() async {
        await performAccountOperation {
            guard self.isAuthenticated, !self.isDemoMode else { throw LiftRankServiceError.permissionDenied }
            await self.notificationStore.revokeCurrentDevice()
            try await self.sessionStore.deleteAuthenticatedAccount()
            self.repository.clearLocalUserData()
            self.profilePhotoStore.removeNamespace(.authenticated)
            self.sessionStore.clearRemoteAccountState()
            self.accountSocialStore.clear()
            self.accountStatus = self.sessionStore.isAuthenticationConfigured ? .signedOut : .configurationRequired
            self.accountMessage = "Your account has been deleted."
        }
    }

    func saveAuthenticatedProfile(_ draft: ProfileDraft) async throws {
        var uploadReadyDraft = draft
        uploadReadyDraft.avatarPath = try await uploadProfilePhotoIfNeeded(avatarPath: draft.avatarPath)
        let profile = try await profileStore.saveAuthenticatedProfile(
            uploadReadyDraft,
            retainingDemoProfiles: sessionStore.usesDemoAuthenticationService
        )
        authenticatedPrivacy = profile.privacy
        if profile.onboardingCompleted {
            await track(.onboardingCompleted)
            try await refreshLegalAcceptanceStatus()
        } else {
            accountStatus = .needsOnboarding
        }
        await refreshRemoteSocialState()
    }

    func searchCities(countryCode: String, region: String, query: String, limit: Int = 8) async -> [LocationCitySuggestion] {
        do {
            return try await serviceContainer.locations.searchCities(
                countryCode: countryCode,
                region: region,
                query: query,
                limit: limit
            )
        } catch {
            return LaunchLocationCatalog.citySuggestions(
                countryCode: countryCode,
                regionName: region,
                query: query,
                limit: limit
            )
        }
    }

    func acceptCurrentLegalDocuments() async {
        await performAccountOperation {
            guard self.isAuthenticated, !self.isDemoMode else { throw LiftRankServiceError.permissionDenied }
            try await self.sessionStore.acceptCurrentLegalDocuments()
            await self.requestPushRegistrationIfNeeded()
        }
    }

    func refreshRemoteSocialState() async {
        guard isAuthenticated else { return }
        do {
            try await accountSocialStore.refreshDirectoryAndRelationships()
        } catch { accountMessage = userMessage(error) }
    }

    private func loadAuthenticatedAccount() async throws {
        let profile = try await profileStore.loadAuthenticatedProfile(
            retainingDemoProfiles: sessionStore.usesDemoAuthenticationService
        )
        authenticatedPrivacy = profile.privacy
        if profile.onboardingCompleted {
            try await refreshLegalAcceptanceStatus()
            if accountStatus == .authenticated {
                await track(.weeklyReturn)
                await requestPushRegistrationIfNeeded()
            }
        } else {
            outstandingLegalDocuments = []
            accountStatus = .needsOnboarding
        }
        await cacheAuthenticatedProfilePhotoIfNeeded()
        await refreshRemoteSocialState()
        await refreshProductionLaunchData()
        await synchronizeCompletedWorkoutHistory()
        await synchronizeWorkoutPlans()
    }

    private func refreshLegalAcceptanceStatus() async throws {
        try await sessionStore.refreshLegalAcceptanceStatus()
    }

    func track(_ name: AnalyticsEventName, properties: [String: String] = [:]) async {
        await analyticsStore.track(name, userID: accountSession?.userID, properties: properties)
    }

    func requestPushRegistrationIfNeeded() async {
#if DEBUG
        return
#else
        guard features.pushNotifications,
              accountStatus == .authenticated,
              !isDemoMode,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if settings.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        }
        if authorized { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }
#endif
    }

    func registerPushToken(_ token: String) async {
#if DEBUG
        return
#else
        guard features.pushNotifications,
              accountStatus == .authenticated,
              let userID = accountSession?.userID,
              !token.isEmpty else { return }
#if DEBUG
        let pushEnvironment = "sandbox"
#else
        let pushEnvironment = "production"
#endif
        await notificationStore.registerPushToken(token, userID: userID, environment: pushEnvironment)
#endif
    }

    func synchronizeCompletedWorkoutHistory() async {
        guard isAuthenticated, !isDemoMode else { return }
        await workoutSyncStore.synchronizeCompletedWorkoutHistory()
    }

    func synchronizeWorkoutPlans() async {
        guard isAuthenticated, !isDemoMode else { return }
        await workoutSyncStore.synchronizeWorkoutPlans()
    }

    func refreshProductionLaunchData() async {
        guard isAuthenticated, !isDemoMode else { return }
        await competitionStore.refreshProductionData()
        if features.connectionActivity || features.communities || features.forums {
            await communityStore.refreshProductionData(
                loadActivity: features.connectionActivity,
                loadCommunities: features.communities || features.forums
            )
        }
        if features.messaging {
            await socialMessagingStore.refreshProductionData()
        }
        await notificationStore.refreshProductionData()
        await accountSocialStore.refreshBlocks()
    }

    func isBlocked(_ userID: UUID) -> Bool { accountSocialStore.isBlocked(userID) }

    func searchAthletes(_ query: String, limit: Int = 20) async -> [UserProfile] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return [] }
        do {
            let cards = try await serviceContainer.social.searchProfiles(query: clean, limit: limit)
            for card in cards { profileStore.mergePublicProfileCard(card) }
            return cards.compactMap { profileStore.profile(id: $0.id) }
                .filter { $0.id != currentProfile.id && !isBlocked($0.id) }
        } catch {
            accountMessage = userMessage(error)
            return []
        }
    }

    func setBlocked(_ userID: UUID, blocked: Bool) {
        guard userID != currentProfile.id else { return }
        Task {
            do {
                try await accountSocialStore.setBlocked(userID, blocked: blocked)
            } catch { accountMessage = userMessage(error) }
        }
    }

    private func performAccountOperation(_ operation: @escaping @MainActor () async throws -> Void) async {
        guard beginAccountMutation() else { return }
        defer { endAccountMutation() }
        do { try await operation() }
        catch { accountMessage = userMessage(error) }
    }

    func beginAccountMutation() -> Bool {
        sessionStore.beginOperation()
    }

    func endAccountMutation() {
        sessionStore.endOperation()
    }

    func setAuthenticatedPrivacy(_ privacy: ProfilePrivacySettings) {
        authenticatedPrivacy = privacy
    }

    func userMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Lift Rivals couldn't complete that request."
    }

    var currentProfile: UserProfile { profileStore.currentProfile }
    var profiles: [UserProfile] { profileStore.profiles }
    var gyms: [Gym] { profileStore.gyms }
    var joinedGyms: [Gym] { profileStore.joinedGyms }
    var joinedGymCount: Int { profileStore.joinedGymCount }
    var canJoinAnotherGym: Bool { profileStore.canJoinAnotherGym(maximumMemberships: Self.maximumJoinedGyms) }
    var lifts: [LiftSubmission] { competitionStore.lifts }
    var pendingReviewLifts: [LiftSubmission] { competitionStore.pendingReviewLifts }
    var activities: [ActivityItem] { repository.activities }
    var challenges: [Challenge] { repository.challenges }
    var achievements: [Achievement] {
        repository.achievements.filter { shouldShowAchievement(title: $0.title) }
    }

    var achievementUnlocks: [AchievementUnlock] {
        repository.achievementUnlocks.filter { shouldShowAchievement(title: $0.title) }
    }
    var competitiveStatistics: CompetitiveStatistics { repository.computedStatistics() }
    var notifications: [NotificationItem] { notificationStore.notifications }
    var unreadNotificationCount: Int { notificationStore.unreadCount }
    var workoutPlans: [WorkoutPlan] { repository.workoutPlans }
    var workoutPhases: [WorkoutPhase] { repository.workoutPhases }
    var workoutWeeks: [WorkoutWeek] { repository.workoutWeeks }
    var workoutSessions: [WorkoutSession] { repository.workoutSessions }
    var workoutPrescriptions: [WorkoutExercisePrescription] { repository.workoutPrescriptions }
    var workoutSetLogs: [WorkoutSetLog] { repository.workoutSetLogs }
    var workoutFeedback: [WorkoutFeedback] { repository.workoutFeedback }
    var customTrainingExercises: [TrainingExerciseCatalogItem] { exerciseLibraryStore.customExercises }
    var trainingExerciseLibrary: [TrainingExerciseCatalogItem] { exerciseLibraryStore.exercises }
    var workoutEntries: [WorkoutExerciseEntry] { repository.workoutEntries }
    var bodyweightEntries: [BodyweightEntry] { trainingProgressStore.bodyweightEntries }

    private func shouldShowAchievement(title: String) -> Bool {
        features.gymFeeds || !title.localizedCaseInsensitiveContains("gym")
    }
    var strainEntries: [StrainEntry] { trainingProgressStore.strainEntries }
    var injuryEntries: [InjuryEntry] { trainingProgressStore.injuryEntries }
    var activeWorkout: ActiveWorkoutState? { activeWorkoutStore.workout }
    var completedWorkouts: [CompletedWorkout] { trainingProgressStore.completedWorkouts }
    var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission] { workoutPRSubmissionStore.pendingSubmissions }
    var workoutPreferences: WorkoutPreferences { workoutPRSubmissionStore.preferences }
    var workoutProgramTemplates: [WorkoutProgramTemplate] { WorkoutProgramCatalog.templates }
    var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings] { repository.workoutPlanProgressionSettings }
    var communityThreads: [CommunityThread] { communityStore.threads }
    var communityThreadReplies: [CommunityThreadReply] { communityStore.threadReplies }
    var communityReports: [CommunityReport] { communityStore.reports }
    var gymRequests: [GymRequest] { repository.gymRequests }
    var friendRequests: [FriendRequest] { socialMessagingStore.friendRequests }
    var messageThreads: [DirectMessageThread] { socialMessagingStore.messageThreads }
    var directMessages: [DirectMessage] { socialMessagingStore.directMessages }
    var messageReports: [MessageReport] { repository.messageReports }
    var activityComments: [ActivityComment] { communityStore.activityComments }
    var forumCommunities: [ForumCommunity] { communityStore.communities }
    var forumMemberships: [ForumMembership] { communityStore.memberships }
    var forumPosts: [ForumPost] { communityStore.posts }
    var forumComments: [ForumComment] { communityStore.comments }
    var forumJoinRequests: [ForumJoinRequest] { communityStore.joinRequests }
    var forumReports: [ForumReport] { communityStore.forumReports }
    var forumModerationActions: [ForumModerationAction] { communityStore.moderationActions }
    var forumNotifications: [ForumNotification] { communityStore.notifications }
    var unreadForumNotificationCount: Int { communityStore.unreadNotificationCount }
    var isForumStaff: Bool { communityStore.isStaff }
    var joinedForumCommunities: [ForumCommunity] { communityStore.joinedCommunities }

    func isGymJoined(_ gym: Gym) -> Bool {
        profileStore.isGymJoined(gym.id)
    }

    func isGymJoined(_ gymID: UUID) -> Bool {
        profileStore.isGymJoined(gymID)
    }

    func isPrimaryGym(_ gym: Gym) -> Bool {
        profileStore.isPrimaryGym(gym.id)
    }

    func joinGymForLift(_ gym: Gym) async -> Bool {
        do {
            let joined = try await accountSocialStore.ensureGymJoined(
                gym,
                maximumMemberships: Self.maximumJoinedGyms,
                authenticated: isAuthenticated
            )
            joined ? Haptics.success() : Haptics.warning()
            return joined
        } catch {
            accountMessage = userMessage(error)
            Haptics.warning()
            return false
        }
    }

    @discardableResult
    func joinGym(_ gym: Gym) -> Bool {
        if isAuthenticated {
            Task {
                do {
                    _ = try await accountSocialStore.ensureGymJoined(
                        gym,
                        maximumMemberships: Self.maximumJoinedGyms,
                        authenticated: true
                    )
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
            return true
        }
        let joined = profileStore.joinGym(gym, maximumMemberships: Self.maximumJoinedGyms)
        if joined {
            Haptics.success()
        } else {
            Haptics.warning()
        }
        return joined
    }

    func leaveGym(_ gym: Gym) {
        if isAuthenticated {
            Task {
                do {
                    try await accountSocialStore.leaveGym(gym, authenticated: true)
                    Haptics.light()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
            return
        }
        profileStore.leaveGym(gym)
        Haptics.light()
    }

    func setPrimaryGym(_ gym: Gym) {
        if isAuthenticated {
            Task {
                do {
                    try await accountSocialStore.setPrimaryGym(gym, authenticated: true)
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            profileStore.setPrimaryGym(gym)
            Haptics.success()
        }
    }

    func markNotificationRead(_ notification: NotificationItem) {
        notificationStore.markRead(notification.id)
    }

    func markAllNotificationsRead() {
        notificationStore.markAllRead()
    }

    func openNotification(_ notification: NotificationItem) {
        switch notificationStore.open(notification, fallbackGymID: currentProfile.primaryGymID) {
        case .leaderboard(let filters):
            competitionStore.requestFocus(filters: filters)
            selectedTab = 1
        case .profile(let targetID):
            if let targetID,
               let profile = profileStore.profile(id: targetID) {
                selectedProfile = profile
            }
            selectedTab = 4
        case .messageThread(let targetID):
            guard features.messaging else { router.selectedTab = .home; break }
            if let targetID,
               let thread = repository.messageThreads.first(where: { $0.id == targetID }) {
                selectedMessageThread = thread
            }
            selectedCommunitySegment = "Inbox"
            selectedTab = 3
        case .friendRequests:
            router.selectedTab = .home
        case .gym(let gymID):
            guard features.gymFeeds else { router.selectedTab = .home; break }
            if let gymID,
               profileStore.containsGym(id: gymID) {
                communityPath = [.gyms, .gym(gymID)]
            }
            selectedCommunitySegment = "Explore"
            selectedTab = 3
        case .tracker(let section):
            trainingTrackerStartOnProgress = section == .progress
            requestedTrackerSegment = section.rawValue
            selectedTab = 2
        case .workoutShare(let activityID):
            if features.connectionActivity,
               let activity = repository.activities.first(where: { $0.id == activityID }) {
                selectedActivity = activity
            }
            router.selectedTab = .home
        case .communityThread(let targetID):
            guard features.forums else { router.selectedTab = .home; break }
            selectedCommunityThread = repository.communityThreads.first { $0.id == targetID }
            selectedCommunitySegment = "Home"
            selectedTab = 3
        case .communityHome:
            router.selectedTab = features.communities ? .community : .home
        case .forumCommunity(let communityID):
            guard features.communities else { router.selectedTab = .home; break }
            communityPath = [.community(communityID)]
            selectedCommunitySegment = "Explore"
            selectedTab = 3
        case .forumPost(let postID):
            guard features.forums else { router.selectedTab = .home; break }
            communityPath = [.post(postID)]
            selectedCommunitySegment = "Home"
            selectedTab = 3
        case .home:
            selectedTab = 0
        }
        Haptics.light()
    }

    var currentUserLifts: [LiftSubmission] {
        competitionStore.currentUserLifts
    }

    var selectedWorkoutPlan: WorkoutPlan? {
        programStore.plan(id: selectedWorkoutPlanID)
    }

    var selectedPlanWorkoutEntries: [WorkoutExerciseEntry] {
        repository.workoutEntries.filter { $0.planID == selectedWorkoutPlanID }
    }

    var selectedPlanPhases: [WorkoutPhase] {
        programStore.phases(planID: selectedWorkoutPlanID)
    }

    var selectedPlanWeeks: [WorkoutWeek] {
        programStore.weeks(planID: selectedWorkoutPlanID)
    }

    var currentSelectedProgramWeek: WorkoutWeek? {
        programStore.currentWeek(planID: selectedWorkoutPlanID)
    }

    var incomingFriendRequests: [FriendRequest] {
        repository.friendRequests
            .filter { $0.toUserID == currentProfile.id && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var outgoingFriendRequests: [FriendRequest] {
        repository.friendRequests
            .filter { $0.fromUserID == currentProfile.id && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var friends: [UserProfile] {
        repository.friendRequests
            .filter { $0.status == .accepted && ($0.fromUserID == currentProfile.id || $0.toUserID == currentProfile.id) }
            .compactMap { request in
                profile(id: request.fromUserID == currentProfile.id ? request.toUserID : request.fromUserID)
            }
            .sorted { $0.displayName < $1.displayName }
    }

}

extension AppState {
    func exerciseHistory(for exerciseID: String) -> [ExerciseHistoryEntry] {
        trainingProgressStore.exerciseHistory(for: exerciseID)
    }

    func exerciseRecords(for exerciseID: String) -> ExerciseRecords {
        trainingProgressStore.exerciseRecords(for: exerciseID)
    }

    var plateauInsights: [PlateauInsight] {
        trainingProgressStore.plateauInsights
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
