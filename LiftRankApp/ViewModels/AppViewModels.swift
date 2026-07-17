import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    static let maximumJoinedGyms = 3
    let profilePhotoStore: ProfilePhotoStore = LocalProfilePhotoStore.shared
    @Published var repository: DemoRepository
    @Published var selectedTab = 0
    @Published var showingSubmitSheet = false
    @Published var showingLeaderboardFilters = false
    @Published var showingEditProfile = false
    @Published var showingModeratorReview = false
    @Published var showingSettings = false
    @Published var showingAuthentication = false
    @Published var showingReportLift = false
    @Published var trainingTrackerStartOnProgress = false
    @Published var requestedTrackerSegment = "Today"
    @Published var showingCreateThread = false
    @Published var showingForumComposer = false
    @Published var showingRequestGym = false
    @Published var selectedProfile: UserProfile?
    @Published var selectedGym: Gym?
    @Published var selectedChallenge: Challenge?
    @Published var selectedMessageThread: DirectMessageThread?
    @Published var selectedCommunityThread: CommunityThread?
    @Published var communityPath: [ForumRoute] = []
    @Published var forumComposerCommunityID: UUID?
    @Published var forumComposerGymID: UUID?
    @Published var forumComposerLiftID: UUID?
    @Published var forumComposerWorkoutID: UUID?
    @Published var selectedActivity: ActivityItem?
    @Published var leaderboardFocusRequestID: UUID?
    @Published var selectedCommunitySegment = "Home"
    @Published var selectedWorkoutPlanID = MockData.defaultWorkoutPlanID
    @Published var leaderboardFilters = LeaderboardFilters(exerciseID: nil)
    @Published var verifiedOnly = true
    @Published var uploadProgress = 0.0
    @Published var lastSubmissionResult: LiftSubmission?
    @Published private(set) var accountStatus: AccountStatus = .restoring
    @Published private(set) var accountSession: AccountSession?
    @Published private(set) var accountOperationInProgress = false
    @Published var accountMessage: String?
    @Published private(set) var remoteGymMemberships: [GymMembershipRecord] = []
    @Published private(set) var remoteFriendRelationships: [FriendRelationshipRecord] = []
    private var cancellables = Set<AnyCancellable>()

    private(set) var serviceContainer: AppServiceContainer!
    var authService: any AuthenticationService { serviceContainer.authentication }
    var profileService: any ProfileService { serviceContainer.profile }
    lazy var liftService = MockLiftService(repository: repository)
    lazy var leaderboardService = MockLeaderboardService(repository: repository)
    var gymService: any GymService { serviceContainer.gyms }
    lazy var challengeService = MockChallengeService(repository: repository)
    lazy var socialService = MockSocialService(repository: repository)
    lazy var communityService = MockCommunityService(repository: repository)
    lazy var messagingService = MockMessagingService(repository: repository)
    var gymMembershipService: any GymMembershipService { serviceContainer.gymMemberships }
    var friendRelationshipService: any FriendRelationshipService { serviceContainer.friendships }
    var exerciseCatalogService: any ExerciseCatalogService { serviceContainer.exercises }
    lazy var verificationService = MockVerificationService(repository: repository)
    lazy var mediaUploadService = MockMediaUploadService()
    lazy var notificationService = MockNotificationService(repository: repository)

    init(repository: DemoRepository? = nil, serviceContainer: AppServiceContainer? = nil) {
        self.repository = repository ?? DemoRepository()
        self.serviceContainer = serviceContainer ?? AppServiceContainer.make(repository: self.repository)
        self.repository.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var isDemoMode: Bool { accountStatus == .demo }
    var isAuthenticated: Bool { accountStatus == .authenticated || accountStatus == .needsOnboarding }

    func restoreAccount() async {
        guard accountStatus == .restoring else { return }
        guard authService.isConfigured else {
            accountStatus = .configurationRequired
            return
        }
        do {
            guard let session = try await authService.restoreSession() else {
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
            self.accountSession = try await self.authService.signUp(email: email, password: password)
            if try await self.authService.restoreSession() == nil {
                self.accountMessage = "Check your email to confirm your account, then sign in."
                self.accountStatus = .signedOut
            } else {
                try await self.loadAuthenticatedAccount()
            }
        }
    }

    func signIn(email: String, password: String) async {
        await performAccountOperation {
            self.accountSession = try await self.authService.signIn(email: email, password: password)
            try await self.loadAuthenticatedAccount()
        }
    }

    func requestPasswordReset(email: String) async {
        await performAccountOperation {
            try await self.authService.requestPasswordReset(email: email)
            self.accountMessage = "If an account can receive a reset email, instructions are on the way."
            self.accountStatus = .signedOut
        }
    }

    func enterDemoMode() async {
        serviceContainer = .demo(repository: repository)
        _ = try? await authService.signInDemo()
        accountSession = nil
        accountMessage = nil
        accountStatus = .demo
    }

    func signOutAccount() async {
        do { try await authService.signOut() } catch { accountMessage = userMessage(error) }
        accountSession = nil
        remoteGymMemberships = []
        remoteFriendRelationships = []
        profilePhotoStore.clearMemoryCache()
        accountStatus = authService.isConfigured ? .signedOut : .configurationRequired
    }

    func saveAuthenticatedProfile(_ draft: ProfileDraft) async throws {
        let profile = try await profileService.saveProfile(draft)
        apply(profile)
        accountStatus = profile.onboardingCompleted ? .authenticated : .needsOnboarding
        await refreshRemoteSocialState()
    }

    func refreshRemoteSocialState() async {
        guard isAuthenticated else { return }
        async let gyms = gymService.gyms()
        async let memberships = gymService.memberships()
        async let relationships = friendRelationshipService.relationships()
        do {
            let (directory, joined, friends) = try await (gyms, memberships, relationships)
            repository.gyms = directory
            repository.joinedGymIDs = Set(joined.filter { $0.leftAt == nil }.map(\.gymID))
            remoteGymMemberships = joined
            remoteFriendRelationships = friends
            repository.friendRequests = friends.compactMap { relationship in
                guard relationship.status != .cancelled else { return nil }
                return FriendRequest(
                    id: relationship.id,
                    fromUserID: relationship.requestedBy,
                    toUserID: relationship.requestedBy == relationship.userLowID ? relationship.userHighID : relationship.userLowID,
                    status: relationship.status == .accepted ? .accepted : relationship.status == .declined ? .declined : .pending,
                    createdAt: relationship.createdAt,
                    respondedAt: relationship.respondedAt
                )
            }

            let relatedUserIDs = Set(friends.flatMap { [$0.userLowID, $0.userHighID] }).subtracting([currentProfile.id])
            for userID in relatedUserIDs {
                guard let card = try? await profileService.profileCard(userID: userID) else { continue }
                var profile = MockData.demoProfile
                profile.id = card.id
                profile.username = card.username
                profile.displayName = card.displayName
                profile.ageGroup = card.ageBand ?? "Hidden"
                profile.sexCategory = card.sexCategory ?? .open
                profile.city = card.city ?? ""
                profile.state = card.region ?? ""
                profile.primaryGymID = card.primaryGymID ?? UUID()
                profile.primaryGymName = card.primaryGymName ?? "Hidden"
                profile.bodyweightPounds = 0
                profile.followers = 0
                profile.following = 0
                profile.hideExactAge = card.ageBand == nil
                profile.hideCity = card.city == nil
                profile.hideGym = card.primaryGymID == nil
                if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
                    repository.profiles[index] = profile
                } else {
                    repository.profiles.append(profile)
                }
            }
        } catch { accountMessage = userMessage(error) }
    }

    private func loadAuthenticatedAccount() async throws {
        let profile = try await profileService.authenticatedProfile()
        apply(profile)
        accountStatus = profile.onboardingCompleted ? .authenticated : .needsOnboarding
        await refreshRemoteSocialState()
    }

    private func apply(_ remote: AuthenticatedProfile) {
        var local = repository.currentProfile
        local.id = remote.id
        local.username = remote.username
        local.displayName = remote.displayName
        local.preferredUnit = remote.preferredUnit
        local.sexCategory = remote.sexCategory ?? .open
        local.heightInches = (remote.heightCentimeters ?? 0) / 2.54
        local.city = remote.city ?? ""
        local.state = remote.region ?? ""
        local.yearsExperience = remote.yearsExperience ?? 0
        local.experienceLevel = remote.experienceLevel ?? .beginner
        local.followers = 0
        local.following = 0
        if let avatarPath = remote.avatarPath {
            local.avatarPath = avatarPath
        }
        repository.currentProfile = local
        if let index = repository.profiles.firstIndex(where: { $0.id == local.id }) {
            repository.profiles[index] = local
        } else {
            repository.profiles.insert(local, at: 0)
        }
    }

    private func performAccountOperation(_ operation: @escaping @MainActor () async throws -> Void) async {
        guard !accountOperationInProgress else { return }
        accountOperationInProgress = true
        accountMessage = nil
        defer { accountOperationInProgress = false }
        do { try await operation() }
        catch { accountMessage = userMessage(error) }
    }

    private func userMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "LiftRank couldn't complete that request."
    }

    var currentProfile: UserProfile { repository.currentProfile }
    var profiles: [UserProfile] { repository.profiles }
    var gyms: [Gym] { repository.gyms }
    var joinedGyms: [Gym] {
        repository.gyms.filter { repository.joinedGymIDs.contains($0.id) }
    }
    var joinedGymCount: Int { repository.joinedGymIDs.count }
    var canJoinAnotherGym: Bool { joinedGymCount < Self.maximumJoinedGyms }
    var lifts: [LiftSubmission] { repository.lifts }
    var activities: [ActivityItem] { repository.activities }
    var challenges: [Challenge] { repository.challenges }
    var achievements: [Achievement] { repository.achievements }
    var achievementUnlocks: [AchievementUnlock] { repository.achievementUnlocks }
    var competitiveStatistics: CompetitiveStatistics { repository.computedStatistics() }
    var notifications: [NotificationItem] { repository.notifications }
    var unreadNotificationCount: Int { repository.notifications.filter { !$0.isRead }.count }
    var workoutPlans: [WorkoutPlan] { repository.workoutPlans }
    var workoutPhases: [WorkoutPhase] { repository.workoutPhases }
    var workoutWeeks: [WorkoutWeek] { repository.workoutWeeks }
    var workoutSessions: [WorkoutSession] { repository.workoutSessions }
    var workoutPrescriptions: [WorkoutExercisePrescription] { repository.workoutPrescriptions }
    var workoutSetLogs: [WorkoutSetLog] { repository.workoutSetLogs }
    var workoutFeedback: [WorkoutFeedback] { repository.workoutFeedback }
    var customTrainingExercises: [TrainingExerciseCatalogItem] { repository.customTrainingExercises }
    var trainingExerciseLibrary: [TrainingExerciseCatalogItem] { MockData.trainingExerciseLibrary + repository.customTrainingExercises }
    var workoutEntries: [WorkoutExerciseEntry] { repository.workoutEntries }
    var bodyweightEntries: [BodyweightEntry] { repository.bodyweightEntries }
    var activeWorkout: ActiveWorkoutState? { repository.activeWorkout }
    var completedWorkouts: [CompletedWorkout] { repository.completedWorkouts }
    var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission] { repository.pendingWorkoutPRSubmissions }
    var workoutPreferences: WorkoutPreferences { repository.workoutPreferences }
    var workoutProgramTemplates: [WorkoutProgramTemplate] { WorkoutProgramCatalog.templates }
    var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings] { repository.workoutPlanProgressionSettings }
    var communityThreads: [CommunityThread] { repository.communityThreads }
    var communityThreadReplies: [CommunityThreadReply] { repository.communityThreadReplies }
    var communityReports: [CommunityReport] { repository.communityReports }
    var gymRequests: [GymRequest] { repository.gymRequests }
    var friendRequests: [FriendRequest] { repository.friendRequests }
    var messageThreads: [DirectMessageThread] { repository.messageThreads }
    var directMessages: [DirectMessage] { repository.directMessages }
    var messageReports: [MessageReport] { repository.messageReports }
    var activityComments: [ActivityComment] { repository.activityComments }
    var forumCommunities: [ForumCommunity] { repository.visibleForumCommunities() }
    var forumMemberships: [ForumMembership] { repository.forumMemberships }
    var forumPosts: [ForumPost] { repository.forumPosts }
    var forumComments: [ForumComment] { repository.forumComments }
    var forumJoinRequests: [ForumJoinRequest] { repository.forumJoinRequests }
    var forumReports: [ForumReport] { repository.forumReports }
    var forumModerationActions: [ForumModerationAction] { repository.forumModerationActions }
    var forumNotifications: [ForumNotification] {
        repository.forumNotifications.filter { $0.userID == currentProfile.id }
    }
    var unreadForumNotificationCount: Int { forumNotifications.filter { !$0.isRead }.count }
    var isForumStaff: Bool { repository.isForumStaff() }
    var joinedForumCommunities: [ForumCommunity] {
        forumCommunities.filter { repository.forumMembership(communityID: $0.id)?.isActive == true }
    }

    func isGymJoined(_ gym: Gym) -> Bool {
        repository.joinedGymIDs.contains(gym.id)
    }

    func isPrimaryGym(_ gym: Gym) -> Bool {
        gym.id == currentProfile.primaryGymID
    }

    @discardableResult
    func joinGym(_ gym: Gym) -> Bool {
        if isAuthenticated {
            Task {
                do {
                    _ = try await gymMembershipService.join(gym, maximumMemberships: Self.maximumJoinedGyms)
                    await refreshRemoteSocialState()
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
            return true
        }
        let joined = repository.joinGym(gym, maximumMemberships: Self.maximumJoinedGyms)
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
                    try await gymMembershipService.leave(gym)
                    await refreshRemoteSocialState()
                    Haptics.light()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
            return
        }
        repository.leaveGym(gym)
        Haptics.light()
    }

    func setPrimaryGym(_ gym: Gym) {
        if isAuthenticated {
            Task {
                do {
                    try await gymMembershipService.setPrimary(gym)
                    await refreshRemoteSocialState()
                    repository.currentProfile.primaryGymID = gym.id
                    repository.currentProfile.primaryGymName = gym.name
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            repository.currentProfile.primaryGymID = gym.id
            repository.currentProfile.primaryGymName = gym.name
            Haptics.success()
        }
    }

    func markNotificationRead(_ notification: NotificationItem) {
        guard let index = repository.notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        repository.notifications[index].isRead = true
    }

    func markAllNotificationsRead() {
        for index in repository.notifications.indices {
            repository.notifications[index].isRead = true
        }
    }

    func openNotification(_ notification: NotificationItem) {
        markNotificationRead(notification)

        switch notification.destination.kind {
        case .leaderboard:
            var filters = LeaderboardFilters(exerciseID: notification.destination.exerciseID)
            filters.rankingType = notification.destination.rankingType ?? .absolute
            filters.gymID = notification.destination.gymID ?? currentProfile.primaryGymID
            leaderboardFilters = filters
            verifiedOnly = true
            leaderboardFocusRequestID = UUID()
            selectedTab = 1
        case .lift, .profile:
            if let targetID = notification.destination.targetID,
               let profile = repository.profiles.first(where: { $0.id == targetID }) {
                selectedProfile = profile
            }
            selectedTab = 4
        case .messageThread:
            if let targetID = notification.destination.targetID,
               let thread = repository.messageThreads.first(where: { $0.id == targetID }) {
                selectedMessageThread = thread
            }
            selectedCommunitySegment = "Inbox"
            selectedTab = 3
        case .friendRequests:
            selectedCommunitySegment = "Inbox"
            selectedTab = 3
        case .gym:
            if let gymID = notification.destination.gymID ?? notification.destination.targetID,
               repository.gyms.contains(where: { $0.id == gymID }) {
                communityPath = [.gyms, .gym(gymID)]
            }
            selectedCommunitySegment = "Explore"
            selectedTab = 3
        case .workoutTracker:
            trainingTrackerStartOnProgress = notification.destination.trackerStartsOnProgress
            requestedTrackerSegment = notification.destination.trackerStartsOnProgress ? "Progress" : "Today"
            selectedTab = 2
        case .communityThread:
            if let targetID = notification.destination.targetID {
                if repository.forumPosts.contains(where: { $0.id == targetID }) {
                    communityPath = [.post(targetID)]
                } else if let thread = repository.communityThreads.first(where: { $0.id == targetID }) {
                    selectedCommunityThread = thread
                }
            }
            selectedCommunitySegment = "Home"
            selectedTab = 3
        case .forumCommunity:
            if let communityID = notification.destination.targetID {
                communityPath = [.community(communityID)]
            }
            selectedCommunitySegment = "Explore"
            selectedTab = 3
        case .forumPost:
            if let postID = notification.destination.targetID {
                communityPath = [.post(postID)]
            }
            selectedCommunitySegment = "Home"
            selectedTab = 3
        case .home:
            selectedTab = 0
        }
        Haptics.light()
    }

    var currentUserLifts: [LiftSubmission] {
        repository.lifts.filter { $0.userID == currentProfile.id }
    }

    var selectedWorkoutPlan: WorkoutPlan? {
        repository.workoutPlans.first { $0.id == selectedWorkoutPlanID }
    }

    var selectedPlanWorkoutEntries: [WorkoutExerciseEntry] {
        repository.workoutEntries.filter { $0.planID == selectedWorkoutPlanID }
    }

    var selectedPlanPhases: [WorkoutPhase] {
        repository.workoutPhases
            .filter { $0.planID == selectedWorkoutPlanID }
            .sorted { $0.order < $1.order }
    }

    var selectedPlanWeeks: [WorkoutWeek] {
        repository.workoutWeeks
            .filter { $0.planID == selectedWorkoutPlanID }
            .sorted { $0.weekNumber < $1.weekNumber }
    }

    var currentSelectedProgramWeek: WorkoutWeek? {
        repository.currentProgramWeek(planID: selectedWorkoutPlanID)
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

    var powerliftingTotal: Double {
        RankingCalculator.totalForUser(currentProfile.id, lifts: repository.lifts)
    }

    var relativeTotal: Double {
        RankingCalculator.relativeTotal(total: powerliftingTotal, bodyweight: currentProfile.bodyweightPounds)
    }

    var overallScore: Double {
        let best = currentUserLifts.map(\.estimatedOneRepMax).max() ?? 0
        return RankingCalculator.overallScore(relativeStrength: min(100, relativeTotal * 22), absoluteStrength: min(100, best / 6), recentProgress: 74)
    }

    func leaderboardSnapshotDate(referenceDate: Date = .now) -> Date {
        Calendar.current.startOfDay(for: referenceDate)
    }

    func nextLeaderboardUpdateDate(referenceDate: Date = .now) -> Date {
        let snapshotDate = leaderboardSnapshotDate(referenceDate: referenceDate)
        return Calendar.current.date(byAdding: .day, value: 1, to: snapshotDate) ?? snapshotDate
    }

    func leaderboardEntries(referenceDate: Date = .now) -> [LeaderboardEntry] {
        let snapshotDate = leaderboardSnapshotDate(referenceDate: referenceDate)
        var filtered = repository.lifts.filter { $0.leaderboardEligibleAt <= snapshotDate }
        let profileByID = Dictionary(uniqueKeysWithValues: repository.profiles.map { ($0.id, $0) })

        if let exerciseID = leaderboardFilters.exerciseID {
            filtered = filtered.filter { $0.exerciseID == exerciseID }
        }
        if let repetitionCount = leaderboardFilters.repetitionCount {
            filtered = filtered.filter { $0.repetitions == repetitionCount }
        }
        if let status = leaderboardFilters.verificationLevel {
            filtered = filtered.filter { $0.verificationStatus == status }
        }
        if let gymID = leaderboardFilters.gymID {
            filtered = filtered.filter { $0.gymID == gymID }
        }
        if let city = leaderboardFilters.city, !city.isEmpty {
            filtered = filtered.filter { lift in
                profileByID[lift.userID]?.city.caseInsensitiveCompare(city) == .orderedSame
            }
        }
        if let state = leaderboardFilters.state, !state.isEmpty {
            filtered = filtered.filter { lift in
                profileByID[lift.userID]?.state.caseInsensitiveCompare(state) == .orderedSame
            }
        }
        if let sexCategory = leaderboardFilters.sexCategory {
            filtered = filtered.filter { lift in
                profileByID[lift.userID]?.sexCategory == sexCategory
            }
        }
        if let ageGroup = leaderboardFilters.ageGroup, !ageGroup.isEmpty {
            filtered = filtered.filter { lift in
                profileByID[lift.userID]?.ageGroup == ageGroup
            }
        }
        if let experienceLevel = leaderboardFilters.experienceLevel {
            filtered = filtered.filter { lift in
                profileByID[lift.userID]?.experienceLevel == experienceLevel
            }
        }
        if let weightClassID = leaderboardFilters.weightClassID {
            filtered = filtered.filter { lift in
                guard let profile = profileByID[lift.userID] else { return false }
                return RankingCalculator.weightClass(
                    for: lift.bodyweightAtLift,
                    sexCategory: profile.sexCategory,
                    classes: MockData.weightClasses
                )?.id == weightClassID
            }
        }
        filtered = filtered.filter { isLift($0, inTimeRange: leaderboardFilters.timeRange) }
        return RankingCalculator.leaderboardEntries(
            profiles: repository.profiles,
            lifts: filtered,
            rankingType: leaderboardFilters.rankingType,
            verifiedOnly: verifiedOnly,
            currentUserID: currentProfile.id,
            exerciseID: leaderboardFilters.exerciseID
        )
    }

    func selectLeaderboardExercise(_ exerciseID: String?) {
        leaderboardFilters.exerciseID = exerciseID
        leaderboardFilters.repetitionCount = nil
        if exerciseID == nil {
            leaderboardFilters.rankingType = .total
        } else if leaderboardFilters.rankingType == .total || leaderboardFilters.rankingType == .relativeTotal {
            leaderboardFilters.rankingType = .absolute
        }
    }

    func normalizeLeaderboardFilters() {
        if let weightClassID = leaderboardFilters.weightClassID,
           !MockData.weightClasses.contains(where: { $0.id == weightClassID }) {
            leaderboardFilters.weightClassID = nil
        }
        if leaderboardFilters.exerciseID == nil {
            leaderboardFilters.repetitionCount = nil
        } else if leaderboardFilters.rankingType == .total || leaderboardFilters.rankingType == .relativeTotal {
            leaderboardFilters.rankingType = .absolute
        }
    }

    private func isLift(_ lift: LiftSubmission, inTimeRange range: String) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        switch range {
        case "This year":
            return calendar.component(.year, from: lift.performedAt) == calendar.component(.year, from: now)
        case "Last 90 days":
            guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return lift.performedAt >= cutoff
        case "This month":
            return calendar.component(.year, from: lift.performedAt) == calendar.component(.year, from: now) &&
            calendar.component(.month, from: lift.performedAt) == calendar.component(.month, from: now)
        case "This week":
            return calendar.isDate(lift.performedAt, equalTo: now, toGranularity: .weekOfYear)
        default:
            return true
        }
    }

    func submitLift(exercise: Exercise, weight: Double, unit: UnitSystem, reps: Int, isActual: Bool, bodyweight: Double, date: Date, gymID: UUID, equipment: EquipmentType, visibility: LiftVisibility, videoURL: URL?, caption: String, requestVerification: Bool) async {
        guard repository.joinedGymIDs.contains(gymID) else {
            lastSubmissionResult = nil
            Haptics.warning()
            return
        }
        Haptics.success()
        uploadProgress = videoURL == nil ? 0 : 0.35
        let remoteURL = try? await mediaUploadService.upload(localURL: videoURL)
        uploadProgress = videoURL == nil ? 0 : 1.0
        let oneRep = isActual ? weight : RankingCalculator.epleyOneRepMax(weight: weight, repetitions: reps)
        let oneRepPounds = unit == .pounds ? oneRep : RankingCalculator.kilogramsToPounds(oneRep)
        let submission = LiftSubmission(
            id: UUID(),
            userID: currentProfile.id,
            exerciseID: exercise.id == "sumo_deadlift" ? "deadlift" : exercise.id,
            exerciseName: exercise.name,
            weight: weight,
            unit: unit,
            normalizedWeightKilograms: unit == .pounds ? RankingCalculator.poundsToKilograms(weight) : weight,
            repetitions: reps,
            isActualOneRepMax: isActual,
            estimatedOneRepMax: unit == .pounds ? oneRep : RankingCalculator.kilogramsToPounds(oneRep),
            bodyweightAtLift: bodyweight,
            bodyweightMultiple: RankingCalculator.bodyweightMultiple(oneRepMax: oneRepPounds, bodyweight: bodyweight),
            equipmentType: equipment,
            variation: exercise.name,
            gymID: gymID,
            performedAt: date,
            localVideoURL: videoURL,
            remoteVideoURL: remoteURL,
            caption: caption,
            verificationStatus: requestVerification ? .videoSubmitted : .selfReported,
            visibility: visibility,
            leaderboardEligibleAt: nextLeaderboardUpdateDate(),
            createdAt: .now,
            updatedAt: .now
        )
        _ = try? await liftService.submit(submission)
        lastSubmissionResult = submission
    }

    func joinChallenge(_ challenge: Challenge) {
        Haptics.light()
        repository.setChallengeJoined(challenge, joined: true)
    }

    func unjoinChallenge(_ challenge: Challenge) {
        Haptics.warning()
        repository.setChallengeJoined(challenge, joined: false)
    }

    func thread(for challenge: Challenge) -> CommunityThread? {
        repository.communityThreads.first { $0.challengeID == challenge.id }
    }

    func currentThread(_ thread: CommunityThread) -> CommunityThread {
        repository.communityThreads.first { $0.id == thread.id } ?? thread
    }

    func replies(for thread: CommunityThread) -> [CommunityThreadReply] {
        repository.communityThreadReplies
            .filter { $0.threadID == thread.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func isThreadLiked(_ thread: CommunityThread) -> Bool {
        thread.votes[currentProfile.id] == .up
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        voteThread(thread, vote: thread.votes[currentProfile.id] == .up ? nil : .up)
        Haptics.light()
    }

    func threadVote(for thread: CommunityThread) -> CommunityVote? {
        currentThread(thread).votes[currentProfile.id]
    }

    func replyVote(for reply: CommunityThreadReply) -> CommunityVote? {
        repository.communityThreadReplies.first { $0.id == reply.id }?.votes[currentProfile.id]
    }

    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) {
        repository.voteThread(thread, vote: vote)
        Haptics.light()
    }

    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) {
        repository.voteReply(reply, vote: vote)
        Haptics.light()
    }

    func threads(for challenge: Challenge) -> [CommunityThread] {
        repository.communityThreads.filter { $0.challengeID == challenge.id }
    }

    func addReply(to thread: CommunityThread, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = currentThread(thread)
        guard !cleanBody.isEmpty, !resolved.isLocked, resolved.removedAt == nil else {
            Haptics.warning()
            return
        }
        repository.addReply(to: resolved, body: cleanBody, author: currentProfile)
        Haptics.success()
    }

    func reportCommunity(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String = "") {
        repository.reportCommunity(targetType: targetType, targetID: targetID, reason: reason, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        Haptics.warning()
    }

    func moderateThread(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String? = nil) {
        repository.moderateThread(thread, operation: operation, reason: reason)
        Haptics.warning()
    }

    func resolveCommunityReport(_ report: CommunityReport) {
        repository.resolveCommunityReport(report)
        Haptics.success()
    }

    // MARK: - Multi-community forum

    func forumCommunity(_ id: UUID) -> ForumCommunity? {
        repository.forumCommunities.first { $0.id == id }
    }

    func forumPost(_ id: UUID) -> ForumPost? {
        repository.forumPosts.first { $0.id == id }
    }

    func forumMembership(for communityID: UUID) -> ForumMembership? {
        repository.forumMembership(communityID: communityID)
    }

    func isJoinedToForumCommunity(_ communityID: UUID) -> Bool {
        forumMembership(for: communityID)?.isActive == true
    }

    func canContributeToForumCommunity(_ communityID: UUID) -> Bool {
        repository.canContributeToForumCommunity(communityID)
    }

    func canModerateForumCommunity(_ communityID: UUID) -> Bool {
        repository.canModerateForumCommunity(communityID)
    }

    func forumFeed(
        communityID: UUID? = nil,
        sort: ForumFeedSort = .hot,
        topRange: ForumTopRange = .week,
        query: String = "",
        includeAllReadable: Bool = false
    ) -> [ForumPost] {
        if let communityID, !repository.canReadForumCommunity(communityID) { return [] }
        let joinedIDs = Set(joinedForumCommunities.map(\.id))
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cutoff: Date? = {
            guard sort == .top else { return nil }
            let days: Int?
            switch topRange {
            case .day: days = 1
            case .week: days = 7
            case .month: days = 30
            case .all: days = nil
            }
            return days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
        }()

        var posts = repository.forumPosts.filter { post in
            if let selectedCommunityID = communityID {
                guard post.destination.communityID == selectedCommunityID else { return false }
            } else if !includeAllReadable {
                guard let destinationCommunityID = post.destination.communityID,
                      joinedIDs.contains(destinationCommunityID) else { return false }
            } else if let destinationCommunityID = post.destination.communityID,
                      !repository.canReadForumCommunity(destinationCommunityID) {
                return false
            }
            if let cutoff, post.createdAt < cutoff { return false }
            guard !cleanQuery.isEmpty else { return true }
            let communityName = post.destination.communityID.flatMap { forumCommunity($0)?.name } ?? "Gym"
            return post.title.lowercased().contains(cleanQuery) ||
                post.body.lowercased().contains(cleanQuery) ||
                post.tag?.lowercased().contains(cleanQuery) == true ||
                communityName.lowercased().contains(cleanQuery)
        }

        posts.sort { left, right in
            if left.isPinned != right.isPinned { return left.isPinned }
            switch sort {
            case .new:
                return left.createdAt > right.createdAt
            case .top:
                if left.voteScore != right.voteScore { return left.voteScore > right.voteScore }
                if left.commentCount != right.commentCount { return left.commentCount > right.commentCount }
                return left.createdAt > right.createdAt
            case .hot:
                let leftScore = forumHotScore(left)
                let rightScore = forumHotScore(right)
                if leftScore != rightScore { return leftScore > rightScore }
                return left.createdAt > right.createdAt
            }
        }
        return posts
    }

    func forumHotScore(_ post: ForumPost, referenceDate: Date = .now) -> Double {
        let ageHours = max(0, referenceDate.timeIntervalSince(post.createdAt) / 3_600)
        return Double(post.voteScore * 2) + log2(Double(post.commentCount) + 1) * 3 - ageHours / 24
    }

    func forumSearchCommunities(query: String, category: String? = nil) -> [ForumCommunity] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return forumCommunities.filter { community in
            let categoryMatches = category == nil || category == "All" || community.category == category
            let queryMatches = cleanQuery.isEmpty || community.name.lowercased().contains(cleanQuery) ||
                community.summary.lowercased().contains(cleanQuery) ||
                community.category.lowercased().contains(cleanQuery) ||
                (repository.canReadForumCommunity(community.id) && repository.forumPosts.contains {
                    $0.destination.communityID == community.id &&
                    ($0.title.lowercased().contains(cleanQuery) || $0.body.lowercased().contains(cleanQuery))
                })
            return categoryMatches && queryMatches
        }
        .sorted { lhs, rhs in
            let lhsJoined = isJoinedToForumCommunity(lhs.id)
            let rhsJoined = isJoinedToForumCommunity(rhs.id)
            if lhsJoined != rhsJoined { return lhsJoined }
            return lhs.memberCount > rhs.memberCount
        }
    }

    func forumComments(for postID: UUID, sort: ForumCommentSort = .best) -> [ForumComment] {
        var comments = repository.forumComments.filter { $0.postID == postID }
        comments.sort { lhs, rhs in
            if lhs.parentCommentID == nil && rhs.parentCommentID != nil { return true }
            if lhs.parentCommentID != nil && rhs.parentCommentID == nil { return false }
            switch sort {
            case .best:
                if lhs.voteScore != rhs.voteScore { return lhs.voteScore > rhs.voteScore }
                return lhs.createdAt < rhs.createdAt
            case .new: return lhs.createdAt > rhs.createdAt
            case .old: return lhs.createdAt < rhs.createdAt
            }
        }
        return comments
    }

    func forumReplies(to commentID: UUID, postID: UUID) -> [ForumComment] {
        repository.forumComments
            .filter { $0.postID == postID && $0.parentCommentID == commentID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func joinForumCommunity(_ communityID: UUID, note: String = "") -> ForumMembershipStatus? {
        let result = repository.joinForumCommunity(communityID, note: note)
        result == .joined ? Haptics.success() : Haptics.light()
        return result
    }

    func leaveForumCommunity(_ communityID: UUID) {
        repository.leaveForumCommunity(communityID)
        Haptics.light()
    }

    func setForumNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID) {
        repository.setForumNotificationLevel(level, communityID: communityID)
        Haptics.light()
    }

    func beginForumComposer(communityID: UUID? = nil, gymID: UUID? = nil, liftID: UUID? = nil, workoutID: UUID? = nil) {
        forumComposerCommunityID = communityID ?? joinedForumCommunities.first?.id
        forumComposerGymID = gymID
        forumComposerLiftID = liftID
        forumComposerWorkoutID = workoutID
        selectedTab = 3
        showingForumComposer = true
    }

    func clearForumComposerPreset() {
        forumComposerCommunityID = nil
        forumComposerGymID = nil
        forumComposerLiftID = nil
        forumComposerWorkoutID = nil
    }

    @discardableResult
    func createForumPost(
        communityID: UUID,
        kind: ForumPostKind,
        title: String,
        body: String,
        tag: String?,
        attachments: [ForumAttachment] = [],
        pollOptions: [String] = [],
        pollCloseDays: Int? = nil,
        liftID: UUID? = nil,
        workoutID: UUID? = nil,
        linkURL: URL? = nil
    ) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let poll: ForumPoll? = kind == .poll ? ForumPoll(
            id: UUID(),
            options: pollOptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { ForumPollOption(id: UUID(), text: $0, voterIDs: []) },
            closesAt: pollCloseDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
        ) : nil
        let post = ForumPost(
            id: UUID(), destination: .community(communityID),
            authorID: currentProfile.id, authorName: currentProfile.displayName,
            kind: kind, title: cleanTitle, body: cleanBody, tag: tag,
            attachments: attachments, poll: poll, liftID: liftID,
            workoutID: workoutID, linkURL: linkURL, challengeID: nil,
            createdAt: .now, editedAt: nil, commentCount: 0, votes: [:],
            savedByUserIDs: [], watchedByUserIDs: [], isPinned: false,
            isLocked: false, removedAt: nil, removalReason: nil
        )
        let created = repository.createForumPost(post)
        created ? Haptics.success() : Haptics.warning()
        return created
    }

    @discardableResult
    func createForumGymPost(
        gymID: UUID,
        kind: ForumPostKind,
        title: String,
        body: String,
        attachments: [ForumAttachment] = [],
        pollOptions: [String] = [],
        pollCloseDays: Int? = nil,
        liftID: UUID? = nil,
        workoutID: UUID? = nil,
        linkURL: URL? = nil
    ) -> Bool {
        let poll: ForumPoll? = kind == .poll ? ForumPoll(
            id: UUID(),
            options: pollOptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }.map { ForumPollOption(id: UUID(), text: $0, voterIDs: []) },
            closesAt: pollCloseDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }
        ) : nil
        let post = ForumPost(
            id: UUID(), destination: .gym(gymID), authorID: currentProfile.id,
            authorName: currentProfile.displayName, kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines), tag: nil,
            attachments: attachments, poll: poll, liftID: liftID, workoutID: workoutID,
            linkURL: linkURL, challengeID: nil, createdAt: .now, editedAt: nil,
            commentCount: 0, votes: [:], savedByUserIDs: [], watchedByUserIDs: [],
            isPinned: false, isLocked: false, removedAt: nil, removalReason: nil
        )
        let created = repository.createForumPost(post)
        created ? Haptics.success() : Haptics.warning()
        return created
    }

    func canContributeToForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canContributeToForumCommunity(communityID) }
        if let gymID = post.destination.gymID { return repository.joinedGymIDs.contains(gymID) }
        return false
    }

    func voteForumPost(_ postID: UUID, vote: CommunityVote?) {
        repository.voteForumPost(postID, vote: vote)
        Haptics.light()
    }

    func toggleForumPostSaved(_ postID: UUID) {
        repository.toggleForumPostSaved(postID)
        Haptics.light()
    }

    func toggleForumPostWatched(_ postID: UUID) {
        repository.toggleForumPostWatched(postID)
        Haptics.light()
    }

    func voteInForumPoll(postID: UUID, optionID: UUID) {
        repository.voteInForumPoll(postID: postID, optionID: optionID)
        Haptics.light()
    }

    @discardableResult
    func addForumComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment? {
        let comment = repository.addForumComment(postID: postID, parentCommentID: parentCommentID, body: body)
        comment == nil ? Haptics.warning() : Haptics.success()
        return comment
    }

    func voteForumComment(_ commentID: UUID, vote: CommunityVote?) {
        repository.voteForumComment(commentID, vote: vote)
        Haptics.light()
    }

    func deleteForumPost(_ postID: UUID) {
        repository.softDeleteForumPost(postID)
        Haptics.warning()
    }

    func updateForumPost(_ post: ForumPost, title: String, body: String) {
        var updated = post
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        repository.updateForumPost(updated)
        Haptics.success()
    }

    func deleteForumComment(_ commentID: UUID) {
        repository.softDeleteForumComment(commentID)
        Haptics.warning()
    }

    @discardableResult
    func reportForumContent(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String = ""
    ) -> Bool {
        let submitted = repository.reportForumContent(
            targetType: targetType, targetID: targetID, communityID: communityID,
            reason: reason, note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        submitted ? Haptics.success() : Haptics.warning()
        return submitted
    }

    func moderateForumPost(_ postID: UUID, action: ForumModerationActionKind, reason: String = "") {
        repository.moderateForumPost(postID, action: action, reason: reason)
        Haptics.warning()
    }

    func moderateForumComment(_ commentID: UUID, action: ForumModerationActionKind, reason: String = "") {
        repository.moderateForumComment(commentID, action: action, reason: reason)
        Haptics.warning()
    }

    func resolveForumReport(_ reportID: UUID, dismiss: Bool) {
        repository.resolveForumReport(reportID, dismiss: dismiss)
        Haptics.success()
    }

    func resolveForumJoinRequest(_ requestID: UUID, approved: Bool) {
        repository.resolveForumJoinRequest(requestID, approved: approved)
        Haptics.success()
    }

    func openForumNotification(_ notification: ForumNotification) {
        repository.markForumNotificationRead(notification.id)
        selectedCommunitySegment = "Inbox"
        if let postID = notification.postID {
            communityPath = [.post(postID)]
        } else if let communityID = notification.communityID {
            communityPath = [.community(communityID)]
        }
        selectedTab = 3
        Haptics.light()
    }

    func openForumPost(_ postID: UUID) {
        communityPath.append(.post(postID))
    }

    func openForumCommunity(_ communityID: UUID) {
        communityPath.append(.community(communityID))
    }

    func persistForumMedia(_ data: Data, fileExtension: String, mediaType: ForumMediaType) throws -> ForumAttachment {
        let url = try repository.persistForumMedia(data, fileExtension: fileExtension)
        return ForumAttachment(id: UUID(), mediaType: mediaType, localURL: url, createdAt: .now)
    }

    @discardableResult
    func createForumCommunity(
        name: String,
        summary: String,
        details: String,
        category: String,
        visibility: ForumCommunityVisibility,
        rules: [String]
    ) -> Bool {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return repository.createForumCommunity(ForumCommunity(
            id: UUID(), slug: slug, name: name, summary: summary, details: details,
            category: category, symbolName: "person.3.fill", accentHex: "3568FF",
            visibility: visibility, rules: rules, availableTags: [],
            staffOwnerID: currentProfile.id, memberCount: 1, postCount: 0,
            createdAt: .now, archivedAt: nil
        ))
    }

    func currentActivity(_ activity: ActivityItem) -> ActivityItem {
        repository.activities.first { $0.id == activity.id } ?? activity
    }

    func comments(for activity: ActivityItem) -> [ActivityComment] {
        repository.activityComments
            .filter { $0.activityID == activity.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func toggleActivityLike(_ activity: ActivityItem) {
        repository.toggleActivityLike(activity)
        Haptics.light()
    }

    func toggleActivitySave(_ activity: ActivityItem) {
        repository.toggleActivitySave(activity)
        Haptics.light()
    }

    func addComment(to activity: ActivityItem, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            Haptics.warning()
            return
        }
        repository.addComment(to: activity, body: cleanBody)
        Haptics.success()
    }

    func createThread(title: String, body: String, kind: CommunityThreadKind = .general, challengeID: UUID? = nil, gymID: UUID? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            Haptics.warning()
            return
        }
        repository.addThread(
            CommunityThread(
                id: UUID(),
                title: cleanTitle,
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                authorID: currentProfile.id,
                authorName: currentProfile.displayName,
                kind: kind,
                challengeID: challengeID,
                gymID: gymID,
                replyCount: 0,
                likeCount: 0,
                createdAt: .now
            )
        )
        Haptics.success()
    }

    func requestGym(name: String, city: String, state: String, note: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return
        }
        repository.requestGym(
            GymRequest(
                id: UUID(),
                name: cleanName,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                state: state.trimmingCharacters(in: .whitespacesAndNewlines),
                requestedBy: currentProfile.id,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: .now
            )
        )
        Haptics.success()
    }

    func profile(id: UUID) -> UserProfile? {
        repository.profiles.first { $0.id == id }
    }

    func friendRequest(with profile: UserProfile) -> FriendRequest? {
        repository.friendRequests.first { request in
            (request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
            (request.fromUserID == profile.id && request.toUserID == currentProfile.id)
        }
    }

    func friendActionTitle(for profile: UserProfile) -> String {
        guard let request = friendRequest(with: profile) else { return "Add Friend" }
        switch request.status {
        case .accepted:
            return "Friends"
        case .declined:
            return "Add Friend"
        case .pending:
            return request.fromUserID == currentProfile.id ? "Request Sent" : "Accept Request"
        }
    }

    func canSendFriendRequest(to profile: UserProfile) -> Bool {
        guard profile.id != currentProfile.id else { return false }
        guard let request = friendRequest(with: profile) else { return true }
        return request.status == .declined
    }

    func sendFriendRequest(to profile: UserProfile) {
        guard canSendFriendRequest(to: profile) else {
            Haptics.warning()
            return
        }
        if isAuthenticated {
            Task {
                do {
                    try await friendRelationshipService.request(userID: profile.id)
                    await refreshRemoteSocialState()
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            repository.sendFriendRequest(to: profile)
            Haptics.success()
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) {
        respondToFriendRequest(request, accept: true)
    }

    func declineFriendRequest(_ request: FriendRequest) {
        respondToFriendRequest(request, accept: false)
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        if isAuthenticated {
            Task {
                do {
                    try await friendRelationshipService.cancel(relationshipID: request.id)
                    await refreshRemoteSocialState()
                    Haptics.warning()
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            repository.cancelFriendRequest(request)
            Haptics.warning()
        }
    }

    private func respondToFriendRequest(_ request: FriendRequest, accept: Bool) {
        if isAuthenticated {
            Task {
                do {
                    try await friendRelationshipService.respond(relationshipID: request.id, accept: accept)
                    await refreshRemoteSocialState()
                    accept ? Haptics.success() : Haptics.warning()
                } catch { accountMessage = userMessage(error) }
            }
        } else {
            repository.respondToFriendRequest(request, status: accept ? .accepted : .declined)
            accept ? Haptics.success() : Haptics.warning()
        }
    }

    func openMessageThread(with profile: UserProfile) {
        guard friends.contains(where: { $0.id == profile.id }) || profile.id == currentProfile.id else {
            Haptics.warning()
            return
        }
        selectedMessageThread = repository.messageThread(with: profile)
        Haptics.light()
    }

    func messages(for thread: DirectMessageThread) -> [DirectMessage] {
        repository.directMessages
            .filter { $0.threadID == thread.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func otherParticipant(in thread: DirectMessageThread) -> UserProfile? {
        guard let otherID = thread.participantIDs.first(where: { $0 != currentProfile.id }) else { return nil }
        return profile(id: otherID)
    }

    func lastMessage(in thread: DirectMessageThread) -> DirectMessage? {
        messages(for: thread).last
    }

    func sendMessage(in thread: DirectMessageThread, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            Haptics.warning()
            return
        }
        repository.addMessage(to: thread, body: cleanBody)
        if let updatedThread = repository.messageThreads.first(where: { $0.id == thread.id }) {
            selectedMessageThread = updatedThread
        }
        Haptics.success()
    }

    func deleteMessage(_ message: DirectMessage) {
        repository.deleteMessage(message)
        Haptics.warning()
    }

    func deleteMessageThread(_ thread: DirectMessageThread) {
        repository.deleteMessageThread(thread)
        if selectedMessageThread?.id == thread.id {
            selectedMessageThread = nil
        }
        Haptics.warning()
    }

    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        repository.reportMessage(message, reason: reason, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        Haptics.warning()
    }

    func updateProfile(_ profile: UserProfile) {
        Task {
            do {
                var saved = try await profileService.updateProfile(profile)
                saved.avatarPath = profile.avatarPath
                repository.currentProfile = saved
                if let index = repository.profiles.firstIndex(where: { $0.id == saved.id }) {
                    repository.profiles[index] = saved
                }
                repository.persistWorkoutSnapshot()
            } catch {
                accountMessage = userMessage(error)
            }
        }
    }

    func updateVerification(_ lift: LiftSubmission, status: VerificationStatus, note: String?) {
        Haptics.success()
        Task { _ = try? await verificationService.updateVerification(for: lift, status: status, note: note) }
    }

    func phase(for week: WorkoutWeek) -> WorkoutPhase? {
        repository.workoutPhases.first { $0.id == week.phaseID }
    }

    func weeks(for planID: UUID? = nil) -> [WorkoutWeek] {
        let planID = planID ?? selectedWorkoutPlanID
        return repository.workoutWeeks
            .filter { $0.planID == planID }
            .sorted { $0.weekNumber < $1.weekNumber }
    }

    func sessions(for week: WorkoutWeek) -> [WorkoutSession] {
        repository.workoutSessions
            .filter { $0.weekID == week.id }
            .sorted { $0.order < $1.order }
    }

    func prescriptions(for session: WorkoutSession) -> [WorkoutExercisePrescription] {
        repository.workoutPrescriptions
            .filter { $0.sessionID == session.id }
            .sorted { $0.order < $1.order }
    }

    func setLogs(for prescription: WorkoutExercisePrescription) -> [WorkoutSetLog] {
        repository.workoutSetLogs
            .filter { $0.prescriptionID == prescription.id }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func setLogs(for exercise: WorkoutExerciseSnapshot, workoutID: UUID? = nil) -> [WorkoutSetLog] {
        let targetWorkoutID = workoutID ?? activeWorkout?.id
        return repository.workoutSetLogs
            .filter { $0.prescriptionID == exercise.id && $0.workoutID == targetWorkoutID }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func previousSetLog(for exercise: WorkoutExerciseSnapshot, setNumber: Int) -> WorkoutSetLog? {
        completedWorkouts
            .sorted { $0.completedAt > $1.completedAt }
            .lazy
            .compactMap { workout -> WorkoutSetLog? in
                guard let previousExercise = workout.exercises.first(where: { $0.exerciseID == exercise.exerciseID }) else { return nil }
                return workout.sets.first {
                    $0.prescriptionID == previousExercise.id &&
                    $0.setNumber == setNumber &&
                    $0.isComplete
                }
            }
            .first
    }

    @discardableResult
    func startWorkout(_ session: WorkoutSession) -> Bool {
        guard activeWorkout == nil else { return false }
        let week = workoutWeeks.first { $0.id == session.weekID }
        let unit = currentProfile.preferredUnit
        let bodyweight = unit == .kilograms
            ? RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
            : currentProfile.bodyweightPounds
        let started = repository.startWorkout(
            session: session,
            planID: week?.planID,
            gymID: currentProfile.primaryGymID,
            bodyweight: bodyweight,
            unit: unit
        ) != nil
        if started { Haptics.success() }
        return started
    }

    @discardableResult
    func startFreestyleWorkoutInstance() -> Bool {
        guard activeWorkout == nil else { return false }
        let unit = currentProfile.preferredUnit
        let bodyweight = unit == .kilograms
            ? RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
            : currentProfile.bodyweightPounds
        let started = repository.startFreestyleWorkout(
            gymID: currentProfile.primaryGymID,
            bodyweight: bodyweight,
            unit: unit
        ) != nil
        if started { Haptics.success() }
        return started
    }

    func addExercisesToActiveWorkout(_ exercises: [TrainingExerciseCatalogItem]) {
        repository.addExercisesToActiveWorkout(exercises)
        Haptics.success()
    }

    func removeExerciseFromActiveWorkout(_ exercise: WorkoutExerciseSnapshot) {
        repository.removeExerciseFromActiveWorkout(exercise)
        Haptics.warning()
    }

    @discardableResult
    func updateSourcePlanFromActiveWorkout() -> Bool {
        let updated = repository.updateSourcePlanFromActiveWorkout()
        updated ? Haptics.success() : Haptics.warning()
        return updated
    }

    func pauseActiveWorkout() {
        repository.pauseActiveWorkout()
        Haptics.light()
    }

    func resumeActiveWorkout() {
        repository.resumeActiveWorkout()
        Haptics.light()
    }

    func discardActiveWorkout() {
        repository.discardActiveWorkout()
        Haptics.warning()
    }

    func updateActiveRestTimer(endsAt: Date?, exerciseID: UUID?) {
        repository.updateActiveRestTimer(endsAt: endsAt, exerciseID: exerciseID)
    }

    var activeWorkoutCompletedWorkingSets: [WorkoutSetLog] {
        guard let workoutID = activeWorkout?.id else { return [] }
        return repository.workoutSetLogs.filter {
            $0.workoutID == workoutID && $0.isComplete && !$0.isWarmup
        }
    }

    func activeWorkoutSummary() -> WorkoutSummary? {
        guard let workout = activeWorkout else { return nil }
        let logs = repository.workoutSetLogs.filter { $0.workoutID == workout.id && $0.isComplete }
        let completedExerciseIDs = Set(logs.map(\.prescriptionID))
        return WorkoutSummary(
            id: workout.id,
            sessionID: workout.sourceSessionID ?? workout.id,
            workoutName: workout.name,
            completedExercises: completedExerciseIDs.count,
            totalExercises: workout.exercises.count,
            totalSets: logs.count,
            totalVolume: logs.filter { !$0.isWarmup }.reduce(0) { $0 + $1.volume },
            bestSet: logs.filter { !$0.isWarmup }.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
        )
    }

    @discardableResult
    func finishActiveWorkout(effort: Int, notes: String) -> CompletedWorkout? {
        let completed = repository.finishActiveWorkout(effort: effort, notes: notes)
        if completed != nil { Haptics.success() }
        return completed
    }

    func deleteCompletedWorkout(_ workout: CompletedWorkout) {
        repository.deleteCompletedWorkout(workout)
        Haptics.warning()
    }

    func setAutomaticVideoPRSubmission(_ enabled: Bool) {
        repository.workoutPreferences.automaticallySubmitVideoBackedPRs = enabled
        repository.workoutPreferences.didExplainAutomaticPRs = true
        repository.persistWorkoutSnapshot()
    }

    func searchExercises(
        query: String,
        filters: ExerciseLibraryFilterSelection? = nil,
        excludingIDs: Set<String> = []
    ) -> [ExerciseSearchResult] {
        ExerciseCatalogSearch.search(exercises: trainingExerciseLibrary, query: query)
            .filter { !excludingIDs.contains($0.exercise.id) }
            .filter { filters?.matches($0.exercise) ?? true }
    }

    func substitutionRecommendations(
        for exercise: TrainingExerciseCatalogItem,
        equipmentFilter: Set<String> = [],
        limit: Int = 8
    ) -> [ExerciseSubstitutionRecommendation] {
        trainingExerciseLibrary
            .filter { $0.id != exercise.id }
            .filter { equipmentFilter.isEmpty || equipmentFilter.contains($0.equipment) }
            .compactMap { candidate in
                let primaryOverlap = overlapScore(exercise.resolvedMuscleProfile.primary, candidate.resolvedMuscleProfile.primary)
                let secondaryOverlap = overlapScore(exercise.resolvedMuscleProfile.secondary, candidate.resolvedMuscleProfile.secondary)
                let movementMatch = exercise.movementPattern == candidate.movementPattern ? 1.0 : 0.0
                let equipmentMatch = exercise.equipment == candidate.equipment ? 1.0 : 0.0
                let difficultyDistance = Double(abs(exercise.difficulty.rawValue - candidate.difficulty.rawValue))
                let difficultyScore = max(0, 1 - (difficultyDistance / 2))
                let score = (primaryOverlap * 0.45) + (movementMatch * 0.25) + (secondaryOverlap * 0.15) + (equipmentMatch * 0.10) + (difficultyScore * 0.05)
                guard score >= 0.35 else { return nil }
                let reasons = substitutionReasons(base: exercise, candidate: candidate, movementMatch: movementMatch > 0, equipmentMatch: equipmentMatch > 0)
                guard !reasons.isEmpty else { return nil }
                return ExerciseSubstitutionRecommendation(exercise: candidate, score: score, reasons: reasons)
            }
            .sorted {
                if $0.score == $1.score { return $0.exercise.name < $1.exercise.name }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    @discardableResult
    func moveActiveWorkoutExercise(_ exercise: WorkoutExerciseSnapshot, direction: Int) -> Bool {
        let moved = repository.moveActiveWorkoutExercise(exercise.id, direction: direction)
        if moved { Haptics.light() }
        return moved
    }

    @discardableResult
    func reorderActiveWorkout(exerciseIDs: [UUID]) -> Bool {
        let reordered = repository.reorderActiveWorkout(exerciseIDs: exerciseIDs)
        if reordered { Haptics.light() }
        return reordered
    }

    func setAutomaticRestTimerEnabledForActiveWorkout(_ enabled: Bool) {
        repository.setAutomaticRestTimerEnabledForActiveWorkout(enabled)
    }

    @discardableResult
    func substituteActiveWorkoutExercise(
        _ exercise: WorkoutExerciseSnapshot,
        with substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot? {
        let updated = repository.substituteActiveWorkoutExercise(currentExerciseID: exercise.id, substitute: substitute)
        if updated != nil { Haptics.success() }
        return updated
    }

    @discardableResult
    func applyWorkoutSetCompletion(
        _ log: WorkoutSetLog,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> Bool {
        let shouldTriggerTimer = isComplete && !log.hasTriggeredRestTimer
        _ = repository.applyWorkoutSetCompletion(logID: log.id, isComplete: isComplete, source: source)
        return shouldTriggerTimer
    }

    @discardableResult
    func attemptAutomaticCompletion(before log: WorkoutSetLog) -> Bool {
        guard let workout = activeWorkout else { return false }
        let logs = repository.workoutSetLogs
            .filter { $0.workoutID == workout.id && $0.prescriptionID == log.prescriptionID }
            .sorted { $0.setNumber < $1.setNumber }
        guard let currentIndex = logs.firstIndex(where: { $0.id == log.id }), currentIndex > 0 else { return false }
        let previous = logs[currentIndex - 1]
        guard !previous.isComplete,
              !previous.isWarmup,
              !previous.suppressAutoCompletion,
              let reps = previous.reps, reps > 0,
              let weight = previous.weight, weight >= 0 else { return false }
        return applyWorkoutSetCompletion(previous, isComplete: true, source: .automatic)
    }

    func markAutomaticVideoPRExplanationShown() {
        repository.workoutPreferences.didExplainAutomaticPRs = true
        repository.persistWorkoutSnapshot()
    }

    func activeWorkoutPRCandidates() -> [WorkoutPRCandidate] {
        guard let workout = activeWorkout else { return [] }
        let sets = repository.workoutSetLogs.filter { $0.workoutID == workout.id }
        return workoutPRCandidates(
            workoutID: workout.id,
            exercises: workout.exercises,
            sets: sets,
            excludingCompletedWorkoutID: nil
        )
    }

    func workoutPRCandidates(for workout: CompletedWorkout) -> [WorkoutPRCandidate] {
        workoutPRCandidates(
            workoutID: workout.id,
            exercises: workout.exercises,
            sets: workout.sets,
            excludingCompletedWorkoutID: workout.id
        )
    }

    private func workoutPRCandidates(
        workoutID: UUID,
        exercises: [WorkoutExerciseSnapshot],
        sets: [WorkoutSetLog],
        excludingCompletedWorkoutID: UUID?
    ) -> [WorkoutPRCandidate] {
        let exerciseByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let eligible = sets.compactMap { log -> (WorkoutSetLog, WorkoutExerciseSnapshot, String, Int, Double)? in
            guard log.isComplete,
                  !log.isWarmup,
                  let weight = log.weight,
                  let repetitions = log.reps,
                  repetitions > 0,
                  let exercise = exerciseByID[log.prescriptionID],
                  let rankingID = exercise.rankingExerciseID else { return nil }
            let kilograms = log.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
            return (log, exercise, rankingID, repetitions, kilograms)
        }

        let grouped = Dictionary(grouping: eligible) { "\($0.2)|\($0.3)" }
        return grouped.values.compactMap { group in
            guard let best = group.max(by: { $0.4 < $1.4 }) else { return nil }
            let previousBest = previousBestKilograms(
                rankingExerciseID: best.2,
                repetitions: best.3,
                excludingCompletedWorkoutID: excludingCompletedWorkoutID
            )
            guard best.4 > (previousBest ?? 0) else { return nil }
            return WorkoutPRCandidate(
                completedWorkoutID: workoutID,
                setID: best.0.id,
                exerciseSnapshotID: best.1.id,
                rankingExerciseID: best.2,
                exerciseName: best.1.exerciseName,
                weight: best.0.weight ?? 0,
                repetitions: best.3,
                unit: best.0.recordedUnit,
                previousBestKilograms: previousBest
            )
        }
        .sorted { $0.exerciseName < $1.exerciseName }
    }

    private func previousBestKilograms(
        rankingExerciseID: String,
        repetitions: Int,
        excludingCompletedWorkoutID: UUID?
    ) -> Double? {
        var values = currentUserLifts
            .filter { $0.exerciseID == rankingExerciseID && $0.repetitions == repetitions }
            .map(\.normalizedWeightKilograms)

        for workout in completedWorkouts where workout.id != excludingCompletedWorkoutID {
            let exerciseIDs = Set(workout.exercises.filter { $0.rankingExerciseID == rankingExerciseID }.map(\.id))
            values += workout.sets.compactMap { log in
                guard exerciseIDs.contains(log.prescriptionID),
                      log.isComplete,
                      !log.isWarmup,
                      log.reps == repetitions,
                      let weight = log.weight else { return nil }
                return log.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
            }
        }
        return values.max()
    }

    func submitVideoBackedPRs(for workout: CompletedWorkout, videoURLsBySetID: [UUID: URL]) async {
        guard workoutPreferences.automaticallySubmitVideoBackedPRs else { return }
        for candidate in workoutPRCandidates(for: workout) {
            guard let videoURL = videoURLsBySetID[candidate.setID] else { continue }
            await submitVideoBackedPR(candidate, workout: workout, videoURL: videoURL)
        }
    }

    func retryFailedWorkoutPRSubmissions() async {
        let failed = pendingWorkoutPRSubmissions.filter { $0.state == .failed || $0.state == .pending }
        for pending in failed {
            guard let workout = completedWorkouts.first(where: { $0.id == pending.candidate.completedWorkoutID }) else { continue }
            await submitVideoBackedPR(pending.candidate, workout: workout, videoURL: pending.localVideoURL)
        }
    }

    private func submitVideoBackedPR(
        _ candidate: WorkoutPRCandidate,
        workout: CompletedWorkout,
        videoURL: URL
    ) async {
        if pendingWorkoutPRSubmissions.contains(where: {
            $0.candidate.setID == candidate.setID && $0.state == .submitted
        }) {
            return
        }

        var pending = pendingWorkoutPRSubmissions.first(where: { $0.candidate.setID == candidate.setID }) ??
            PendingWorkoutPRSubmission(
                id: UUID(),
                candidate: candidate,
                localVideoURL: videoURL,
                state: .pending,
                attemptCount: 0,
                lastError: nil,
                submissionID: nil,
                updatedAt: .now
            )
        pending.state = .uploading
        pending.attemptCount += 1
        pending.lastError = nil
        pending.updatedAt = .now
        repository.upsertPendingPRSubmission(pending)

        guard let exercise = MockData.exercises.first(where: { $0.id == candidate.rankingExerciseID }) else {
            pending.state = .failed
            pending.lastError = "The exercise is no longer eligible for ranking."
            pending.updatedAt = .now
            repository.upsertPendingPRSubmission(pending)
            return
        }

        lastSubmissionResult = nil
        let bodyweight = workout.bodyweight ?? currentProfile.bodyweightPounds
        let bodyweightPounds = workout.unit == .kilograms ? RankingCalculator.kilogramsToPounds(bodyweight) : bodyweight
        await submitLift(
            exercise: exercise,
            weight: candidate.weight,
            unit: candidate.unit,
            reps: candidate.repetitions,
            isActual: candidate.repetitions == 1,
            bodyweight: bodyweightPounds,
            date: workout.completedAt,
            gymID: workout.gymID ?? currentProfile.primaryGymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: videoURL,
            caption: "PR from \(workout.name): \(candidate.exerciseName) \(RankingCalculator.format(candidate.weight)) \(candidate.unit.shortLabel) × \(candidate.repetitions)",
            requestVerification: true
        )

        if let submission = lastSubmissionResult {
            pending.state = .submitted
            pending.submissionID = submission.id
            pending.lastError = nil
            repository.linkSubmission(submission.id, to: workout.id)
        } else {
            pending.state = .failed
            pending.lastError = "Upload could not be completed. It will remain available to retry."
        }
        pending.updatedAt = .now
        repository.upsertPendingPRSubmission(pending)
    }

    func persistWorkoutVideo(_ data: Data, fileExtension: String = "mov") throws -> URL {
        let manager = FileManager.default
        let root = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("WorkoutPRVideos", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    func activeSetLogs(for prescription: WorkoutExercisePrescription) -> [WorkoutSetLog] {
        setLogs(for: prescription)
            .filter { Calendar.current.isDateInToday($0.performedAt) }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func previousSetLog(for prescription: WorkoutExercisePrescription, setNumber: Int) -> WorkoutSetLog? {
        setLogs(for: prescription)
            .filter { log in
                !Calendar.current.isDateInToday(log.performedAt) &&
                log.setNumber == setNumber &&
                (log.weight != nil || log.reps != nil)
            }
            .sorted { $0.performedAt > $1.performedAt }
            .first
    }

    func completedPrescriptionCount(for session: WorkoutSession) -> Int {
        let prescriptions = prescriptions(for: session)
        let completedIDs = Set(repository.workoutSetLogs.filter { log in
            log.isComplete && prescriptions.contains { $0.id == log.prescriptionID }
        }.map(\.prescriptionID))
        return completedIDs.count
    }

    func weekCompletion(for week: WorkoutWeek) -> Double {
        let weekSessions = sessions(for: week)
        let plannedPrescriptions = weekSessions.flatMap { prescriptions(for: $0) }
        guard !plannedPrescriptions.isEmpty else { return 0 }
        let completedIDs = Set(repository.workoutSetLogs.filter { log in
            log.isComplete && plannedPrescriptions.contains { $0.id == log.prescriptionID }
        }.map(\.prescriptionID))
        return Double(completedIDs.count) / Double(plannedPrescriptions.count)
    }

    func lastCompletedWorkoutDate() -> Date? {
        repository.completedWorkouts
            .filter { !$0.completedWorkingSets.isEmpty }
            .map(\.completedAt)
            .max()
    }

    func workoutStreak(referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(
            repository.completedWorkouts
                .filter { !$0.completedWorkingSets.isEmpty }
                .map { calendar.startOfDay(for: $0.completedAt) }
        )
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var cursor: Date
        if completedDays.contains(today) {
            cursor = today
        } else if completedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    func volumeByBodyPart(for planID: UUID? = nil) -> [String: Double] {
        var totals: [String: Double] = [:]
        let requestedPlanID = planID ?? selectedWorkoutPlanID
        for workout in repository.completedWorkouts where workout.sourcePlanID == nil || workout.sourcePlanID == requestedPlanID {
            for exercise in workout.exercises {
                let volume = workout.sets
                    .filter { $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup }
                    .reduce(0) { $0 + $1.volume }
                totals[exercise.bodyPart, default: 0] += volume
            }
        }
        return totals
    }

    func addWeekToSelectedPlan() -> WorkoutWeek {
        let week = repository.addWorkoutWeek(planID: selectedWorkoutPlanID)
        Haptics.success()
        return week
    }

    func cloneWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        let clone = repository.cloneWorkoutWeek(week)
        Haptics.success()
        return clone
    }

    func deleteWeek(_ week: WorkoutWeek) {
        repository.deleteWorkoutWeek(week)
        Haptics.warning()
    }

    func addSession(to week: WorkoutWeek, day: String, name: String) -> WorkoutSession {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = repository.addWorkoutSession(weekID: week.id, day: day, name: cleanName.isEmpty ? "Workout" : cleanName)
        Haptics.success()
        return session
    }

    func startFreestyleSession(in week: WorkoutWeek? = nil) -> WorkoutSession {
        let targetWeek = week ?? addWeekToSelectedPlan()
        return addSession(to: targetWeek, day: Calendar.current.weekdayName(), name: "Freestyle Workout")
    }

    func deleteSession(_ session: WorkoutSession) {
        repository.deleteWorkoutSession(session)
        Haptics.warning()
    }

    func cancelWorkout(_ session: WorkoutSession) {
        repository.cancelWorkoutSession(session)
        Haptics.warning()
    }

    func addExercises(_ exercises: [TrainingExerciseCatalogItem], to session: WorkoutSession) {
        let nextOrder = prescriptions(for: session).count
        for (offset, exercise) in exercises.enumerated() {
            _ = repository.addWorkoutPrescription(
                WorkoutExercisePrescription(
                    id: UUID(),
                    sessionID: session.id,
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    sets: exercise.defaultSets,
                    reps: exercise.defaultReps,
                    restSeconds: exercise.defaultRestSeconds,
                    order: nextOrder + offset,
                    notes: ""
                )
            )
        }
        Haptics.success()
    }

    func addExercise(_ exercise: TrainingExerciseCatalogItem, to session: WorkoutSession, sets: Int, reps: String, restSeconds: Int) {
        let cleanReps = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = repository.addWorkoutPrescription(
            WorkoutExercisePrescription(
                id: UUID(),
                sessionID: session.id,
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart,
                equipment: exercise.equipment,
                sets: max(1, sets),
                reps: cleanReps.isEmpty ? "8-12" : cleanReps,
                restSeconds: restSeconds,
                order: prescriptions(for: session).count,
                notes: ""
            )
        )
        Haptics.success()
    }

    func deletePrescription(_ prescription: WorkoutExercisePrescription) {
        repository.deleteWorkoutPrescription(prescription)
        Haptics.warning()
    }

    func updateSetLog(_ log: WorkoutSetLog) {
        repository.updateWorkoutSetLog(log)
    }

    @discardableResult
    func addSetLog(to prescription: WorkoutExercisePrescription) -> WorkoutSetLog {
        let nextActiveSet = (activeSetLogs(for: prescription).map(\.setNumber).max() ?? 0) + 1
        return repository.addWorkoutSetLog(prescriptionID: prescription.id, setNumber: nextActiveSet)
    }

    @discardableResult
    func addSetLog(to exercise: WorkoutExerciseSnapshot) -> WorkoutSetLog? {
        guard let workout = activeWorkout else { return nil }
        let nextSet = (setLogs(for: exercise, workoutID: workout.id).map(\.setNumber).max() ?? 0) + 1
        return repository.addWorkoutSetLog(
            prescriptionID: exercise.id,
            setNumber: nextSet,
            workoutID: workout.id,
            unit: workout.unit
        )
    }

    func deleteSetLog(_ log: WorkoutSetLog) {
        repository.deleteWorkoutSetLog(log)
        Haptics.warning()
    }

    func saveCustomExercise(
        name: String,
        bodyPart: String,
        equipment: String,
        trackingType: String,
        primaryMuscles: [ExerciseMuscleRegion] = [],
        secondaryMuscles: [ExerciseMuscleRegion] = []
    ) -> TrainingExerciseCatalogItem? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return nil
        }
        let fallbackProfile = ExerciseMuscleProfileResolver.profile(name: cleanName, bodyPart: bodyPart)
        let selectedPrimary = primaryMuscles.isEmpty ? fallbackProfile.primary : primaryMuscles
        let selectedSecondary = secondaryMuscles.filter { !selectedPrimary.contains($0) }
        let hasFront = selectedPrimary.contains { !$0.isBackFacing && $0 != .fullBody }
        let hasBack = selectedPrimary.contains { $0.isBackFacing }
        let orientation: ExerciseMuscleMapOrientation = selectedPrimary.contains(.fullBody) || (hasFront && hasBack)
            ? .split
            : (hasBack ? .back : .front)
        let exercise = TrainingExerciseCatalogItem(
            id: "custom_\(UUID().uuidString)",
            name: cleanName,
            bodyPart: bodyPart,
            workoutCategory: "Custom",
            defaultSets: 3,
            defaultReps: "8-12",
            symbolName: "dumbbell.fill",
            secondaryMuscles: [],
            equipment: equipment,
            movementType: "Custom",
            trackingType: trackingType,
            defaultRestSeconds: 120,
            muscleProfile: ExerciseMuscleProfile(
                primary: selectedPrimary,
                secondary: selectedSecondary,
                orientation: orientation
            )
        )
        repository.addCustomTrainingExercise(exercise)
        Haptics.success()
        return exercise
    }

    func workoutSummary(for session: WorkoutSession) -> WorkoutSummary {
        repository.workoutSummary(for: session)
    }

    func completeWorkout(_ session: WorkoutSession, effort: Int, notes: String) {
        repository.saveWorkoutFeedback(sessionID: session.id, effort: effort, notes: notes)
        Haptics.success()
    }

    func weekOptions(for planID: UUID? = nil) -> [Int] {
        let planID = planID ?? selectedWorkoutPlanID
        let programWeeks = Set(repository.workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber))
        let weeks = Set(repository.workoutEntries.filter { $0.planID == planID }.map(\.week)).union(programWeeks)
        return Array(weeks.union([1])).sorted()
    }

    func workoutDays(for week: Int, planID: UUID? = nil) -> [WorkoutDaySummary] {
        let planID = planID ?? selectedWorkoutPlanID
        let grouped = Dictionary(grouping: repository.workoutEntries.filter { $0.planID == planID && $0.week == week }) { $0.workout }
        return grouped.values.map { entries in
            WorkoutDaySummary(
                day: entries.first?.day ?? "",
                workout: entries.first?.workout ?? "",
                exercises: entries.count,
                completed: entries.filter(\.isDone).count
            )
        }
        .sorted { lhs, rhs in
            let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            return (order.firstIndex(of: lhs.day) ?? 99) < (order.firstIndex(of: rhs.day) ?? 99)
        }
    }

    func strengthBalance(for week: Int, planID: UUID? = nil) -> StrengthBalance {
        let planID = planID ?? selectedWorkoutPlanID
        let entries = repository.workoutEntries.filter { $0.planID == planID && $0.week == week && $0.isDone }
        let categories = ["Push", "Pull", "Legs", "Shoulders/Arms", "Core"]
        var volumes = Dictionary(uniqueKeysWithValues: categories.map { ($0, 0.0) })
        for entry in entries {
            let category = trainingCategory(for: entry)
            volumes[category, default: 0] += entry.volume
        }
        let nonZero = volumes.values.filter { $0 > 0 }
        let maxVolume = nonZero.max() ?? 1
        let minVolume = nonZero.min() ?? 0
        let score = maxVolume == 0 ? 0 : Int((minVolume / maxVolume) * 100)
        let weakest = volumes.min { $0.value < $1.value }?.key ?? "Core"
        let label = score >= 75 ? "Balanced" : score >= 45 ? "Developing" : "Needs attention"
        return StrengthBalance(score: score, label: label, weakest: weakest, volumes: volumes)
    }

    func createWorkoutPlan(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return
        }
        let plan = WorkoutPlan(id: UUID(), name: cleanName, createdAt: .now, goal: "Build strength and muscle", notes: "", isActive: true)
        repository.addWorkoutPlan(plan)
        selectedWorkoutPlanID = plan.id
        Haptics.success()
    }

    func suggestedTrainingMaxKilograms(for template: WorkoutProgramTemplate) -> [String: Double] {
        let rankingIDs: [String: Set<String>] = [
            "back_squat": ["squat"],
            "barbell_bench_press": ["bench"],
            "conventional_deadlift": ["deadlift", "sumo_deadlift"],
            "barbell_overhead_press": ["press"]
        ]
        var result: [String: Double] = [:]
        for exerciseID in template.requiredTrainingMaxExerciseIDs {
            guard let acceptedIDs = rankingIDs[exerciseID] else { continue }
            if let bestPounds = currentUserLifts
                .filter({ acceptedIDs.contains($0.exerciseID) })
                .map(\.estimatedOneRepMax)
                .max(), bestPounds > 0 {
                result[exerciseID] = RankingCalculator.poundsToKilograms(bestPounds) * 0.90
            }
        }
        return result
    }

    @discardableResult
    func startWorkoutProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan? {
        guard scheduledWeekdays.count == template.sessions.count else {
            Haptics.warning()
            return nil
        }
        if method == .percentage {
            guard template.requiredTrainingMaxExerciseIDs.allSatisfy({ (trainingMaxKilograms[$0] ?? 0) > 0 }) else {
                Haptics.warning()
                return nil
            }
        }
        let plan = repository.startWorkoutProgram(
            template: template,
            startDate: startDate,
            scheduledWeekdays: scheduledWeekdays,
            method: method,
            preferredUnit: currentProfile.preferredUnit,
            trainingMaxKilograms: trainingMaxKilograms
        )
        selectedWorkoutPlanID = plan.id
        Haptics.success()
        return plan
    }

    @discardableResult
    func changeProgression(
        for planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> Bool {
        let changed = repository.changeWorkoutProgramProgression(
            planID: planID,
            method: method,
            trainingMaxKilograms: trainingMaxKilograms
        )
        changed ? Haptics.success() : Haptics.warning()
        return changed
    }

    func renameSelectedWorkoutPlan(to name: String) {
        guard var plan = selectedWorkoutPlan else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return
        }
        plan.name = cleanName
        repository.updateWorkoutPlan(plan)
        Haptics.success()
    }

    func duplicateSelectedWorkoutPlan() {
        guard let plan = selectedWorkoutPlan else { return }
        let copy = repository.duplicateWorkoutPlan(plan)
        selectedWorkoutPlanID = copy.id
        Haptics.success()
    }

    func deleteSelectedWorkoutPlan() {
        guard let plan = selectedWorkoutPlan else { return }
        guard repository.workoutPlans.count > 1 else {
            Haptics.warning()
            return
        }
        let fallback = repository.workoutPlans.first { $0.id != plan.id }
        repository.deleteWorkoutPlan(plan)
        selectedWorkoutPlanID = fallback?.id ?? repository.workoutPlans.first?.id ?? MockData.defaultWorkoutPlanID
        Haptics.warning()
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        Haptics.light()
        repository.updateBodyweight(entry)
    }

    func saveProfilePhoto(_ image: UIImage) {
        do {
            var profile = currentProfile
            let mode: AccountMode = isDemoMode ? .demo : .authenticated
            profile.avatarPath = try profilePhotoStore.save(image: image, userID: profile.id, mode: mode)
            repository.currentProfile = profile
            if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
                repository.profiles[index] = profile
            }
            repository.persistWorkoutSnapshot()
            Haptics.success()
        } catch {
            accountMessage = "LiftRank couldn't save that profile photo."
        }
    }

    func removeProfilePhoto() {
        let oldPath = currentProfile.avatarPath
        var profile = currentProfile
        profile.avatarPath = nil
        repository.currentProfile = profile
        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            repository.profiles[index] = profile
        }
        profilePhotoStore.remove(avatarPath: oldPath)
        repository.persistWorkoutSnapshot()
        Haptics.warning()
    }

    private func trainingCategory(for entry: WorkoutExerciseEntry) -> String {
        let text = "\(entry.exercise) \(entry.workout) \(entry.muscleGroup)".lowercased()
        if text.contains("crunch") || text.contains("core") { return "Core" }
        if text.contains("curl") || text.contains("triceps") || text.contains("lateral") || text.contains("shoulder") { return "Shoulders/Arms" }
        if text.contains("row") || text.contains("pulldown") || text.contains("pull") || text.contains("lat") { return "Pull" }
        if text.contains("squat") || text.contains("leg") || text.contains("hamstring") || text.contains("glute") || text.contains("deadlift") { return "Legs" }
        return "Push"
    }

    private func overlapScore<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        guard !left.isEmpty || !right.isEmpty else { return 0 }
        let intersection = Double(left.intersection(right).count)
        let union = Double(left.union(right).count)
        return union == 0 ? 0 : intersection / union
    }

    private func substitutionReasons(
        base: TrainingExerciseCatalogItem,
        candidate: TrainingExerciseCatalogItem,
        movementMatch: Bool,
        equipmentMatch: Bool
    ) -> [String] {
        var reasons: [String] = []
        let primaryOverlap = Set(base.resolvedMuscleProfile.primary).intersection(candidate.resolvedMuscleProfile.primary)
        let secondaryOverlap = Set(base.resolvedMuscleProfile.secondary).intersection(candidate.resolvedMuscleProfile.secondary)
        if !primaryOverlap.isEmpty {
            reasons.append("same primary muscles")
        }
        if movementMatch {
            reasons.append("same \(base.movementPattern.rawValue.lowercased()) pattern")
        }
        if equipmentMatch {
            reasons.append("same equipment")
        }
        if !secondaryOverlap.isEmpty {
            reasons.append("similar assisting muscles")
        }
        if reasons.isEmpty && abs(base.difficulty.rawValue - candidate.difficulty.rawValue) <= 1 {
            reasons.append("similar difficulty")
        }
        return Array(reasons.prefix(3))
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
