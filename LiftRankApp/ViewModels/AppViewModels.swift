import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    static let maximumJoinedGyms = 3
    @Published var repository = DemoRepository()
    @Published var selectedTab = 0
    @Published var showingSubmitSheet = false
    @Published var showingLeaderboardFilters = false
    @Published var showingEditProfile = false
    @Published var showingModeratorReview = false
    @Published var showingSettings = false
    @Published var showingAuthentication = false
    @Published var showingReportLift = false
    @Published var showingTrainingTracker = false
    @Published var trainingTrackerStartOnProgress = false
    @Published var showingCreateThread = false
    @Published var showingRequestGym = false
    @Published var selectedProfile: UserProfile?
    @Published var selectedGym: Gym?
    @Published var selectedChallenge: Challenge?
    @Published var selectedWorkoutEntry: WorkoutExerciseEntry?
    @Published var selectedMessageThread: DirectMessageThread?
    @Published var selectedCommunityThread: CommunityThread?
    @Published var selectedActivity: ActivityItem?
    @Published var leaderboardFocusRequestID: UUID?
    @Published var selectedCommunitySegment = "Feed"
    @Published var selectedWorkoutPlanID = MockData.defaultWorkoutPlanID
    @Published var leaderboardFilters = LeaderboardFilters(exerciseID: nil)
    @Published var verifiedOnly = true
    @Published var uploadProgress = 0.0
    @Published var lastSubmissionResult: LiftSubmission?
    @Published private(set) var publicLeaderboardEntries: [LeaderboardEntry] = []
    @Published private(set) var isLoadingPublicLeaderboard = false
    @Published private(set) var hasLoadedPublicLeaderboard = false
    @Published private(set) var publicLeaderboardError: String?
    private var cancellables = Set<AnyCancellable>()

    lazy var authService = MockAuthenticationService(repository: repository)
    lazy var profileService = MockProfileService(repository: repository)
    lazy var liftService = MockLiftService(repository: repository)
    lazy var leaderboardService = MockLeaderboardService(repository: repository)
    lazy var gymService = MockGymService(repository: repository)
    lazy var challengeService = MockChallengeService(repository: repository)
    lazy var socialService = MockSocialService(repository: repository)
    lazy var verificationService = MockVerificationService(repository: repository)
    lazy var mediaUploadService = MockMediaUploadService()
    lazy var notificationService = MockNotificationService(repository: repository)

    init() {
        repository.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
    var communityThreads: [CommunityThread] { repository.communityThreads }
    var communityThreadReplies: [CommunityThreadReply] { repository.communityThreadReplies }
    var gymRequests: [GymRequest] { repository.gymRequests }
    var friendRequests: [FriendRequest] { repository.friendRequests }
    var messageThreads: [DirectMessageThread] { repository.messageThreads }
    var directMessages: [DirectMessage] { repository.directMessages }
    var messageReports: [MessageReport] { repository.messageReports }
    var activityComments: [ActivityComment] { repository.activityComments }

    func isGymJoined(_ gym: Gym) -> Bool {
        repository.joinedGymIDs.contains(gym.id)
    }

    func isPrimaryGym(_ gym: Gym) -> Bool {
        gym.id == currentProfile.primaryGymID
    }

    @discardableResult
    func joinGym(_ gym: Gym) -> Bool {
        let joined = repository.joinGym(gym, maximumMemberships: Self.maximumJoinedGyms)
        if joined {
            Haptics.success()
        } else {
            Haptics.warning()
        }
        return joined
    }

    func leaveGym(_ gym: Gym) {
        repository.leaveGym(gym)
        Haptics.light()
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

        let kind = notification.kind.lowercased()
        if kind.contains("ranking") {
            var filters = LeaderboardFilters(exerciseID: "deadlift")
            filters.rankingType = .absolute
            filters.gymID = currentProfile.primaryGymID
            leaderboardFilters = filters
            verifiedOnly = true
            leaderboardFocusRequestID = UUID()
            selectedTab = 1
        } else if kind.contains("friend") || kind.contains("message") {
            selectedCommunitySegment = "Messages"
            selectedTab = 3
        } else if kind.contains("gym") {
            selectedCommunitySegment = "Gyms"
            selectedTab = 3
        } else if kind.contains("lift") || kind.contains("approved") || kind.contains("rejected") || kind.contains("achievement") {
            selectedTab = 4
        } else {
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

    var leaderboardQueryKey: String {
        [
            leaderboardFilters.rankingType.rawValue,
            leaderboardFilters.exerciseID ?? "",
            leaderboardFilters.city ?? "",
            leaderboardFilters.gymID?.uuidString ?? "",
            leaderboardFilters.weightClassID ?? ""
        ].joined(separator: "|")
    }

    func refreshPublicLeaderboard() async {
        isLoadingPublicLeaderboard = true
        publicLeaderboardError = nil
        defer { isLoadingPublicLeaderboard = false }

        do {
            let entries = try await SupabaseMobileSync.shared.fetchPublicLeaderboard(
                filters: leaderboardFilters,
                currentProfile: currentProfile
            )
            guard !Task.isCancelled else { return }
            publicLeaderboardEntries = entries
            hasLoadedPublicLeaderboard = true
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            publicLeaderboardError = error.localizedDescription
            hasLoadedPublicLeaderboard = true
        }
    }

    func leaderboardEntries(referenceDate: Date = .now) -> [LeaderboardEntry] {
        if hasLoadedPublicLeaderboard {
            return publicLeaderboardEntries
        }
        let snapshotDate = leaderboardSnapshotDate(referenceDate: referenceDate)
        var filtered = repository.lifts.filter { $0.createdAt < snapshotDate }
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
        repository.likedCommunityThreadIDs.contains(thread.id)
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        repository.toggleThreadLike(thread)
        Haptics.light()
    }

    func threads(for challenge: Challenge) -> [CommunityThread] {
        repository.communityThreads.filter { $0.challengeID == challenge.id }
    }

    func addReply(to thread: CommunityThread, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            Haptics.warning()
            return
        }
        repository.addReply(to: thread, body: cleanBody, author: currentProfile)
        Haptics.success()
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
        repository.sendFriendRequest(to: profile)
        Haptics.success()
    }

    func acceptFriendRequest(_ request: FriendRequest) {
        repository.respondToFriendRequest(request, status: .accepted)
        Haptics.success()
    }

    func declineFriendRequest(_ request: FriendRequest) {
        repository.respondToFriendRequest(request, status: .declined)
        Haptics.warning()
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        repository.cancelFriendRequest(request)
        Haptics.warning()
    }

    func openMessageThread(with profile: UserProfile) {
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
        Task { _ = try? await profileService.updateProfile(profile) }
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
        repository.workoutSetLogs
            .filter(\.isComplete)
            .map(\.performedAt)
            .max()
    }

    func workoutStreak(referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(
            repository.workoutSetLogs
                .filter(\.isComplete)
                .map { calendar.startOfDay(for: $0.performedAt) }
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
        let planID = planID ?? selectedWorkoutPlanID
        let weekIDs = repository.workoutWeeks.filter { $0.planID == planID }.map(\.id)
        let sessionIDs = repository.workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id)
        let prescriptions = repository.workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }
        var totals: [String: Double] = [:]
        for prescription in prescriptions {
            let volume = repository.workoutSetLogs
                .filter { $0.prescriptionID == prescription.id && $0.isComplete }
                .reduce(0) { $0 + $1.volume }
            totals[prescription.bodyPart, default: 0] += volume
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
        return addSession(to: targetWeek, day: Self.currentWeekday(), name: "Freestyle Workout")
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

    func deleteSetLog(_ log: WorkoutSetLog) {
        repository.deleteWorkoutSetLog(log)
        Haptics.warning()
    }

    func saveCustomExercise(name: String, bodyPart: String, equipment: String, trackingType: String) -> TrainingExerciseCatalogItem? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return nil
        }
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
            defaultRestSeconds: 120
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

    func updateWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        Haptics.success()
        repository.updateWorkoutEntry(entry)
    }

    func addWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        Haptics.success()
        repository.addWorkoutEntry(entry)
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

    private func trainingCategory(for entry: WorkoutExerciseEntry) -> String {
        let text = "\(entry.exercise) \(entry.workout) \(entry.muscleGroup)".lowercased()
        if text.contains("crunch") || text.contains("core") { return "Core" }
        if text.contains("curl") || text.contains("triceps") || text.contains("lateral") || text.contains("shoulder") { return "Shoulders/Arms" }
        if text.contains("row") || text.contains("pulldown") || text.contains("pull") || text.contains("lat") { return "Pull" }
        if text.contains("squat") || text.contains("leg") || text.contains("hamstring") || text.contains("glute") || text.contains("deadlift") { return "Legs" }
        return "Push"
    }

    private static func currentWeekday() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Calendar.current.weekdaySymbols[max(0, min(Calendar.current.weekdaySymbols.count - 1, weekday - 1))]
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
