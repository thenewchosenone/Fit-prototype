import Foundation
import Combine

@MainActor
final class DemoRepository: ObservableObject {
    private static let personalWorkoutDemoMarker = "[demo:private-history-v1]"
    private static let suppressPersonalWorkoutDemoHistoryKey = "liftrank.suppressPersonalWorkoutDemoHistory"

    @Published var currentProfile: UserProfile
    @Published var profiles: [UserProfile]
    @Published var gyms: [Gym]
    @Published var joinedGymIDs: Set<UUID>
    @Published var lifts: [LiftSubmission]
    @Published var challenges: [Challenge]
    @Published var achievements: [Achievement]
    @Published var activities: [ActivityItem]
    @Published var activityComments: [ActivityComment]
    @Published var notifications: [NotificationItem]
    @Published var workoutPlans: [WorkoutPlan]
    @Published var workoutPhases: [WorkoutPhase]
    @Published var workoutWeeks: [WorkoutWeek]
    @Published var workoutSessions: [WorkoutSession]
    @Published var workoutPrescriptions: [WorkoutExercisePrescription]
    @Published var workoutSetLogs: [WorkoutSetLog]
    @Published var workoutFeedback: [WorkoutFeedback]
    @Published var customTrainingExercises: [TrainingExerciseCatalogItem]
    @Published var workoutEntries: [WorkoutExerciseEntry]
    @Published var bodyweightEntries: [BodyweightEntry]
    @Published var strainEntries: [StrainEntry]
    @Published var injuryEntries: [InjuryEntry]
    @Published var activeWorkout: ActiveWorkoutState?
    @Published var completedWorkouts: [CompletedWorkout]
    @Published var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission]
    @Published var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot]
    @Published var workoutPlanSyncRevisions: [UUID: Int]
    @Published var workoutPlanLastSyncedPayloads: [UUID: Data]
    @Published var workoutPreferences: WorkoutPreferences
    @Published var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings]
    @Published var communityThreads: [CommunityThread]
    @Published var communityThreadReplies: [CommunityThreadReply]
    @Published var likedCommunityThreadIDs: Set<UUID>
    @Published var communityReports: [CommunityReport]
    @Published var gymRequests: [GymRequest]
    @Published var friendRequests: [FriendRequest]
    @Published var messageThreads: [DirectMessageThread]
    @Published var directMessages: [DirectMessage]
    @Published var messageReports: [MessageReport]
    @Published var forumCommunities: [ForumCommunity]
    @Published var forumMemberships: [ForumMembership]
    @Published var forumPosts: [ForumPost]
    @Published var forumComments: [ForumComment]
    @Published var forumJoinRequests: [ForumJoinRequest]
    @Published var forumReports: [ForumReport]
    @Published var forumModerationActions: [ForumModerationAction]
    @Published var forumNotifications: [ForumNotification]
    @Published var forumGlobalStaffUserIDs: Set<UUID>
    @Published var achievementUnlocks: [AchievementUnlock]
    @Published var rankingHistory: [RankingHistorySnapshot]
    private let workoutPersistenceStore: WorkoutPersistenceStore
    private let forumPersistenceStore: ForumPersistenceStore
    private var persistenceCancellables = Set<AnyCancellable>()
    private var forumPersistenceCancellables = Set<AnyCancellable>()
    private var isRestoringWorkoutSnapshot = false
    private var isRestoringForumSnapshot = false

    init(
        workoutPersistenceStore: WorkoutPersistenceStore? = nil,
        forumPersistenceStore: ForumPersistenceStore? = nil
    ) {
        self.workoutPersistenceStore = workoutPersistenceStore ?? InMemoryWorkoutPersistenceStore()
        self.forumPersistenceStore = forumPersistenceStore ?? InMemoryForumPersistenceStore()
        let seeded = MockData.community()
        let social = MockData.social(profiles: seeded.profiles)
        let seededThreads = MockData.communityThreads(for: MockData.challenges)
        let seededForum = MockData.forumSeed(profiles: seeded.profiles, lifts: seeded.lifts, legacyThreads: seededThreads)
        currentProfile = MockData.emptyProfile
        profiles = seeded.profiles
        gyms = []
        joinedGymIDs = []
        lifts = seeded.lifts
        challenges = MockData.challenges
        achievements = MockData.achievements
        activities = seeded.activities
        activityComments = Self.seedActivityComments(for: seeded.activities, profiles: seeded.profiles)
        workoutPlans = MockData.workoutPlans
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = MockData.workoutEntries
        bodyweightEntries = MockData.bodyweightEntries
        strainEntries = []
        injuryEntries = []
        activeWorkout = nil
        completedWorkouts = []
        pendingWorkoutPRSubmissions = []
        pendingCompletedWorkoutUploads = []
        workoutPlanSyncRevisions = [:]
        workoutPlanLastSyncedPayloads = [:]
        workoutPreferences = WorkoutPreferences()
        workoutPlanProgressionSettings = []
        communityThreads = seededThreads
        communityThreadReplies = Self.seedThreadReplies(for: seededThreads, profiles: seeded.profiles)
        likedCommunityThreadIDs = []
        communityReports = []
        gymRequests = []
        friendRequests = social.friendRequests
        messageThreads = social.messageThreads
        directMessages = social.messages
        messageReports = []
        forumCommunities = seededForum.communities
        forumMemberships = seededForum.memberships
        forumPosts = seededForum.posts
        forumComments = seededForum.comments
        forumJoinRequests = seededForum.joinRequests
        forumReports = seededForum.reports
        forumModerationActions = seededForum.moderationActions
        forumNotifications = seededForum.notifications
        forumGlobalStaffUserIDs = seededForum.globalStaffUserIDs
        achievementUnlocks = []
        rankingHistory = []
        notifications = []
        rebuildProgramBuilderDataFromEntries()
        restoreWorkoutSnapshotOrImportLegacy()
        refreshAchievementUnlocks()
        bindWorkoutPersistence()
        restoreForumSnapshot()
        bindForumPersistence()
    }

    func reset() {
        let seeded = MockData.community()
        let social = MockData.social(profiles: seeded.profiles)
        let seededThreads = MockData.communityThreads(for: MockData.challenges)
        let seededForum = MockData.forumSeed(profiles: seeded.profiles, lifts: seeded.lifts, legacyThreads: seededThreads)
        currentProfile = MockData.emptyProfile
        profiles = seeded.profiles
        gyms = []
        joinedGymIDs = []
        lifts = seeded.lifts
        challenges = MockData.challenges
        achievements = MockData.achievements
        activities = seeded.activities
        activityComments = Self.seedActivityComments(for: seeded.activities, profiles: seeded.profiles)
        workoutPlans = MockData.workoutPlans
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = MockData.workoutEntries
        bodyweightEntries = MockData.bodyweightEntries
        strainEntries = []
        injuryEntries = []
        activeWorkout = nil
        completedWorkouts = []
        pendingWorkoutPRSubmissions = []
        workoutPreferences = WorkoutPreferences()
        workoutPlanProgressionSettings = []
        communityThreads = seededThreads
        communityThreadReplies = Self.seedThreadReplies(for: seededThreads, profiles: seeded.profiles)
        likedCommunityThreadIDs = []
        communityReports = []
        gymRequests = []
        friendRequests = social.friendRequests
        messageThreads = social.messageThreads
        directMessages = social.messages
        messageReports = []
        forumCommunities = seededForum.communities
        forumMemberships = seededForum.memberships
        forumPosts = seededForum.posts
        forumComments = seededForum.comments
        forumJoinRequests = seededForum.joinRequests
        forumReports = seededForum.reports
        forumModerationActions = seededForum.moderationActions
        forumNotifications = seededForum.notifications
        forumGlobalStaffUserIDs = seededForum.globalStaffUserIDs
        achievementUnlocks = []
        rankingHistory = []
        rebuildProgramBuilderDataFromEntries()
        workoutPersistenceStore.reset()
        ensurePersonalWorkoutPlan()
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
        forumPersistenceStore.reset()
        removeForumMedia()
        persistForumSnapshot()
    }

    func clearLocalUserData() {
        activeWorkout = nil
        completedWorkouts.removeAll()
        pendingWorkoutPRSubmissions.removeAll()
        pendingCompletedWorkoutUploads.removeAll()
        workoutPlanSyncRevisions.removeAll()
        workoutPlanLastSyncedPayloads.removeAll()
        workoutPlans.removeAll()
        workoutPhases.removeAll()
        workoutWeeks.removeAll()
        workoutSessions.removeAll()
        workoutPrescriptions.removeAll()
        workoutSetLogs.removeAll()
        workoutFeedback.removeAll()
        workoutEntries.removeAll()
        bodyweightEntries.removeAll()
        workoutPlanProgressionSettings.removeAll()
        customTrainingExercises.removeAll()
        communityThreads.removeAll()
        communityThreadReplies.removeAll()
        forumPosts.removeAll()
        forumComments.removeAll()
        directMessages.removeAll()
        messageThreads.removeAll()
        notifications.removeAll()
        workoutPersistenceStore.reset()
        forumPersistenceStore.reset()
        removeForumMedia()
    }

    private func bindWorkoutPersistence() {
        let publishers: [AnyPublisher<Void, Never>] = [
            $workoutPlans.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPhases.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutWeeks.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutSessions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPrescriptions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutSetLogs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutFeedback.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $customTrainingExercises.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutEntries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $bodyweightEntries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $strainEntries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $injuryEntries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $activeWorkout.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $completedWorkouts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pendingWorkoutPRSubmissions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pendingCompletedWorkoutUploads.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanSyncRevisions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanLastSyncedPayloads.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPreferences.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanProgressionSettings.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $achievementUnlocks.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $rankingHistory.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] in self?.persistWorkoutSnapshot() }
            .store(in: &persistenceCancellables)
    }

    func persistWorkoutSnapshot() {
        guard !isRestoringWorkoutSnapshot else { return }
        workoutPersistenceStore.saveSnapshot(
            WorkoutPersistenceSnapshot(
                schemaVersion: WorkoutPersistenceSnapshot.currentVersion,
                plans: workoutPlans,
                phases: workoutPhases,
                weeks: workoutWeeks,
                sessions: workoutSessions,
                prescriptions: workoutPrescriptions,
                setLogs: workoutSetLogs,
                feedback: workoutFeedback,
                customExercises: customTrainingExercises,
                legacyEntries: workoutEntries,
                bodyweightEntries: bodyweightEntries,
                strainEntries: strainEntries,
                injuryEntries: injuryEntries,
                activeWorkout: activeWorkout,
                completedWorkouts: completedWorkouts,
                pendingPRSubmissions: pendingWorkoutPRSubmissions,
                preferences: workoutPreferences,
                planProgressionSettings: workoutPlanProgressionSettings,
                achievementUnlocks: achievementUnlocks,
                rankingHistory: rankingHistory,
                pendingCompletedWorkoutUploads: pendingCompletedWorkoutUploads,
                workoutPlanSyncRevisions: workoutPlanSyncRevisions,
                workoutPlanLastSyncedPayloads: workoutPlanLastSyncedPayloads
            )
        )
    }

    private func restoreWorkoutSnapshotOrImportLegacy() {
        if let snapshot = workoutPersistenceStore.loadSnapshot() {
            isRestoringWorkoutSnapshot = true
            workoutPlans = snapshot.plans
            workoutPhases = snapshot.phases
            workoutWeeks = snapshot.weeks
            workoutSessions = snapshot.sessions
            workoutPrescriptions = snapshot.prescriptions
            workoutSetLogs = snapshot.setLogs
            workoutFeedback = snapshot.feedback
            customTrainingExercises = snapshot.customExercises
            workoutEntries = snapshot.legacyEntries
            bodyweightEntries = snapshot.bodyweightEntries
            strainEntries = snapshot.strainEntries
            injuryEntries = snapshot.injuryEntries
            activeWorkout = snapshot.activeWorkout
            completedWorkouts = snapshot.completedWorkouts
            pendingWorkoutPRSubmissions = snapshot.pendingPRSubmissions
            pendingCompletedWorkoutUploads = snapshot.pendingCompletedWorkoutUploads ?? []
            workoutPlanSyncRevisions = snapshot.workoutPlanSyncRevisions ?? [:]
            workoutPlanLastSyncedPayloads = snapshot.workoutPlanLastSyncedPayloads ?? [:]
            workoutPreferences = snapshot.preferences
            workoutPlanProgressionSettings = snapshot.planProgressionSettings ?? []
            achievementUnlocks = snapshot.achievementUnlocks ?? []
            rankingHistory = snapshot.rankingHistory ?? []
            purgeSeededWorkoutData()
            refreshAchievementUnlocks()
            isRestoringWorkoutSnapshot = false
            persistWorkoutSnapshot()
            return
        }

        completedWorkouts = []
        workoutEntries = []
        bodyweightEntries = []
        workoutPersistenceStore.reset()
        persistWorkoutSnapshot()
    }

    private func purgeSeededWorkoutData() {
        let seededWorkoutIDs = Set(completedWorkouts.filter {
            $0.notes.contains(Self.personalWorkoutDemoMarker) ||
                $0.sourcePlanID == PersonalWorkoutPlanCatalog.planID ||
                $0.notes == "Imported from previous workout history."
        }.map(\.id))
        let seededPlanIDs = Set(workoutPlans.filter {
            $0.id == PersonalWorkoutPlanCatalog.planID ||
                $0.name.localizedCaseInsensitiveContains("Robert") ||
                $0.name.localizedCaseInsensitiveContains("Hypertrophy")
        }.map(\.id))
        let seededWeekIDs = Set(workoutWeeks.filter { seededPlanIDs.contains($0.planID) }.map(\.id))
        let seededSessionIDs = Set(workoutSessions.filter {
            seededWeekIDs.contains($0.weekID) ||
                $0.name.localizedCaseInsensitiveContains("Strength Focus") ||
                $0.name.localizedCaseInsensitiveContains("Hypertrophy")
        }.map(\.id))

        completedWorkouts.removeAll { seededWorkoutIDs.contains($0.id) }
        workoutSetLogs.removeAll { log in
            if let workoutID = log.workoutID, seededWorkoutIDs.contains(workoutID) { return true }
            return seededSessionIDs.contains(log.prescriptionID)
        }
        workoutFeedback.removeAll { seededSessionIDs.contains($0.sessionID) }
        workoutPlanProgressionSettings.removeAll { seededPlanIDs.contains($0.planID) }
        workoutPrescriptions.removeAll { seededSessionIDs.contains($0.sessionID) }
        workoutSessions.removeAll { seededWeekIDs.contains($0.weekID) || seededSessionIDs.contains($0.id) }
        workoutWeeks.removeAll { seededWeekIDs.contains($0.id) }
        workoutPhases.removeAll { seededPlanIDs.contains($0.planID) }
        workoutPlans.removeAll { seededPlanIDs.contains($0.id) }
        workoutEntries.removeAll()
        bodyweightEntries.removeAll { $0.notes.contains(Self.personalWorkoutDemoMarker) }
        pendingCompletedWorkoutUploads.removeAll { snapshot in
            seededWorkoutIDs.contains(snapshot.id) ||
                String(data: snapshot.payload, encoding: .utf8)?.contains(Self.personalWorkoutDemoMarker) == true
        }
    }

    private func ensurePersonalWorkoutPlan() {
        return
    }

    /// Populates the private demo routine with a realistic, deterministic
    /// twelve-week training history. This is only invoked by explicit DEBUG
    /// demo mode and is idempotent so seeded workouts can never multiply.
    func seedPersonalWorkoutDemoHistory(referenceDate: Date = .now) {
        _ = referenceDate
    }

    /// Removes only the deterministic private-history seed and its dependent
    /// local projections. The workout plan and unrelated user-entered records remain.
    @discardableResult
    func removePersonalWorkoutDemoHistory() -> Int {
        // Keep the cleanup durable. Demo mode normally seeds this history on
        // every entry, which would otherwise restore the deleted workouts.
        UserDefaults.standard.set(true, forKey: Self.suppressPersonalWorkoutDemoHistoryKey)

        let demoWorkouts = completedWorkouts.filter { $0.notes.contains(Self.personalWorkoutDemoMarker) }
        guard !demoWorkouts.isEmpty || bodyweightEntries.contains(where: {
            $0.notes.contains(Self.personalWorkoutDemoMarker)
        }) else { return 0 }

        let demoWorkoutIDs = Set(demoWorkouts.map(\.id))
        let demoSetSignatures = Set(demoWorkouts.flatMap(\.sets).map(DemoWorkoutSetSignature.init))
        let demoFeedbackSignatures = Set(demoWorkouts.compactMap { workout -> DemoWorkoutFeedbackSignature? in
            guard let sessionID = workout.sourceSessionID else { return nil }
            return DemoWorkoutFeedbackSignature(sessionID: sessionID, completedAt: workout.completedAt)
        })

        completedWorkouts.removeAll { demoWorkoutIDs.contains($0.id) }
        workoutSetLogs.removeAll { log in
            if let workoutID = log.workoutID, demoWorkoutIDs.contains(workoutID) { return true }
            return log.workoutID == nil && demoSetSignatures.contains(DemoWorkoutSetSignature(log))
        }
        workoutFeedback.removeAll {
            demoFeedbackSignatures.contains(DemoWorkoutFeedbackSignature(sessionID: $0.sessionID, completedAt: $0.completedAt))
        }
        bodyweightEntries.removeAll { $0.notes.contains(Self.personalWorkoutDemoMarker) }
        pendingCompletedWorkoutUploads.removeAll { snapshot in
            demoWorkoutIDs.contains(snapshot.id) ||
                String(data: snapshot.payload, encoding: .utf8)?.contains(Self.personalWorkoutDemoMarker) == true
        }
        workoutPlanProgressionSettings.removeAll {
            $0.planID == PersonalWorkoutPlanCatalog.planID && $0.sourceTemplateID == "private_bts_beginner_12"
        }
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
        return demoWorkouts.count
    }

    private func seedPersonalDemoBodyweight(firstMonday: Date, marker: String, calendar: Calendar) {
        guard !bodyweightEntries.contains(where: { $0.notes.contains(marker) }) else { return }
        let startingWeight = currentProfile.bodyweightPounds + 2.4
        let entries = (0..<12).compactMap { index -> BodyweightEntry? in
            guard let date = calendar.date(byAdding: .weekOfYear, value: index, to: firstMonday) else { return nil }
            let naturalVariation = Double((index % 3) - 1) * 0.25
            return BodyweightEntry(
                id: UUID(),
                week: bodyweightEntries.count + index + 1,
                targetDate: date,
                actual: startingWeight - (Double(index) * 0.42) + naturalVariation,
                notes: "\(marker) Weekly check-in"
            )
        }
        bodyweightEntries.append(contentsOf: entries)
    }

    private func personalDemoDayOffset(_ day: String) -> Int {
        ["Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6][day] ?? 0
    }

    private func personalDemoRepRange(_ value: String) -> ClosedRange<Int> {
        let numbers = value
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        let lower = max(1, numbers.first ?? 8)
        let upper = max(lower, numbers.dropFirst().first ?? lower)
        return lower...upper
    }

    private func personalDemoWeight(
        for exercise: WorkoutExercisePrescription,
        week: Int,
        exerciseIndex: Int
    ) -> Double? {
        let name = exercise.exerciseName.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        let equipment = exercise.equipment.lowercased()
        if equipment.contains("bodyweight") { return nil }

        let base: Double
        if name.contains("leg press") { base = 270 }
        else if name.contains("squat") || name.contains("lunge") { base = equipment.contains("dumbbell") ? 35 : 155 }
        else if name.contains("deadlift") || name.contains("rdl") { base = 165 }
        else if name.contains("bench press") || name.contains("incline barbell") { base = 115 }
        else if name.contains("row") { base = equipment.contains("barbell") ? 105 : 90 }
        else if name.contains("pulldown") { base = 95 }
        else if name.contains("shrug") || name.contains("calf") { base = 105 }
        else if name.contains("chest press") || name.contains("shoulder press") { base = equipment.contains("dumbbell") ? 40 : 85 }
        else if bodyPart.contains("hamstring") || bodyPart.contains("quad") || bodyPart.contains("glute") { base = 75 }
        else if bodyPart.contains("chest") || bodyPart.contains("back") || bodyPart.contains("lat") { base = 55 }
        else if bodyPart.contains("shoulder") || bodyPart.contains("delt") { base = 15 }
        else if bodyPart.contains("bicep") || bodyPart.contains("tricep") { base = 30 }
        else { base = 50 }

        let progression = 1 + Double(week - 1) * 0.022
        let sessionVariation = Double((exerciseIndex % 3) - 1) * (base < 40 ? 1.25 : 2.5)
        return max(2.5, (base * progression) + sessionVariation)
    }

    private func personalDemoRoundedWeight(_ value: Double) -> Double {
        let increment = value < 40 ? 2.5 : 5.0
        return (value / increment).rounded() * increment
    }

    private func bindForumPersistence() {
        let publishers: [AnyPublisher<Void, Never>] = [
            $forumCommunities.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumMemberships.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumPosts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumComments.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumJoinRequests.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumReports.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumModerationActions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumNotifications.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $forumGlobalStaffUserIDs.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .sink { [weak self] in self?.persistForumSnapshot() }
            .store(in: &forumPersistenceCancellables)
    }

    func persistForumSnapshot() {
        guard !isRestoringForumSnapshot else { return }
        forumPersistenceStore.saveSnapshot(
            ForumPersistenceSnapshot(
                schemaVersion: ForumPersistenceSnapshot.currentVersion,
                communities: forumCommunities,
                memberships: forumMemberships,
                posts: forumPosts,
                comments: forumComments,
                joinRequests: forumJoinRequests,
                reports: forumReports,
                moderationActions: forumModerationActions,
                notifications: forumNotifications,
                globalStaffUserIDs: forumGlobalStaffUserIDs
            )
        )
    }

    private func restoreForumSnapshot() {
        guard let snapshot = forumPersistenceStore.loadSnapshot(),
              snapshot.schemaVersion <= ForumPersistenceSnapshot.currentVersion,
              !snapshot.communities.isEmpty else {
            persistForumSnapshot()
            return
        }

        isRestoringForumSnapshot = true
        forumCommunities = snapshot.communities
        forumMemberships = snapshot.memberships
        forumPosts = snapshot.posts
        forumComments = snapshot.comments
        forumJoinRequests = snapshot.joinRequests
        forumReports = snapshot.reports
        forumModerationActions = snapshot.moderationActions
        forumNotifications = snapshot.notifications
        forumGlobalStaffUserIDs = snapshot.globalStaffUserIDs
        isRestoringForumSnapshot = false
    }

    static var forumMediaDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("LiftRank/ForumMedia", isDirectory: true)
    }

    func persistForumMedia(_ data: Data, fileExtension: String) throws -> URL {
        let directory = Self.forumMediaDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeExtension = fileExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        let fileURL = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(safeExtension.isEmpty ? "bin" : safeExtension)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func removeForumMedia(at localURL: URL) {
        guard localURL.path.hasPrefix(Self.forumMediaDirectory.path) else { return }
        try? FileManager.default.removeItem(at: localURL)
    }

    private func removeForumMedia() {
        try? FileManager.default.removeItem(at: Self.forumMediaDirectory)
    }

    private func importedCompletedWorkouts(
        legacyRecords: [LegacyWorkoutRecordValue],
        legacyEntries: [WorkoutExerciseEntry]
    ) -> [CompletedWorkout] {
        struct ImportRow {
            var id: UUID
            var exercise: String
            var workout: String
            var bodyPart: String
            var weight: Double
            var reps: Int
            var rpe: Int?
            var performedAt: Date
        }

        var rows = legacyRecords.map {
            ImportRow(
                id: $0.id,
                exercise: $0.exercise,
                workout: $0.workout,
                bodyPart: "Strength",
                weight: $0.weight,
                reps: $0.reps,
                rpe: $0.rpe,
                performedAt: $0.performedAt
            )
        }
        rows += legacyEntries.filter(\.isDone).flatMap { entry in
            entry.sets.compactMap { set in
                guard let weight = set.weight, let reps = set.reps else { return nil }
                return ImportRow(
                    id: set.id,
                    exercise: entry.exercise,
                    workout: entry.workout,
                    bodyPart: entry.muscleGroup,
                    weight: weight,
                    reps: reps,
                    rpe: set.rpe,
                    performedAt: entry.date
                )
            }
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rows) { row in
            "\(calendar.startOfDay(for: row.performedAt).timeIntervalSince1970)|\(row.workout)"
        }

        return grouped.values.compactMap { group in
            guard let first = group.min(by: { $0.performedAt < $1.performedAt }) else { return nil }
            let workoutID = UUID()
            let exerciseGroups = Dictionary(grouping: group, by: \.exercise)
            let snapshots = exerciseGroups.keys.sorted().enumerated().map { order, exerciseName in
                let sample = exerciseGroups[exerciseName]?.first
                let catalog = (MockData.trainingExerciseLibrary + customTrainingExercises).first {
                    $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame
                }
                return WorkoutExerciseSnapshot(
                    id: UUID(),
                    sourcePrescriptionID: nil,
                    exerciseID: catalog?.id ?? exerciseName.lowercased().replacingOccurrences(of: " ", with: "_"),
                    exerciseName: exerciseName,
                    bodyPart: catalog?.bodyPart ?? sample?.bodyPart ?? "Strength",
                    equipment: catalog?.equipment ?? "Weights",
                    targetSets: exerciseGroups[exerciseName]?.count ?? 1,
                    targetReps: "Recorded",
                    restSeconds: catalog?.defaultRestSeconds ?? 120,
                    order: order,
                    notes: "Imported workout",
                    rankingExerciseID: catalog?.rankingExerciseID
                )
            }
            let snapshotByName = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.exerciseName, $0) })
            let setNumberByExercise = Dictionary(grouping: group.sorted { $0.performedAt < $1.performedAt }, by: \.exercise)
            let logs = group.map { row -> WorkoutSetLog in
                let number = (setNumberByExercise[row.exercise]?.firstIndex(where: { $0.id == row.id }) ?? 0) + 1
                return WorkoutSetLog(
                    id: row.id,
                    prescriptionID: snapshotByName[row.exercise]?.id ?? UUID(),
                    performedAt: row.performedAt,
                    setNumber: number,
                    weight: row.weight,
                    reps: row.reps,
                    rpe: row.rpe,
                    isWarmup: false,
                    isComplete: true,
                    workoutID: workoutID,
                    recordedUnit: .pounds
                )
            }
            let start = first.performedAt
            let end = group.map(\.performedAt).max() ?? start
            return CompletedWorkout(
                id: workoutID,
                source: .legacyImport,
                sourceSessionID: nil,
                sourcePlanID: nil,
                name: first.workout,
                dayLabel: start.formatted(.dateTime.weekday(.wide)),
                startedAt: start,
                completedAt: end,
                duration: max(0, end.timeIntervalSince(start)),
                effort: 3,
                notes: "Imported from previous workout history.",
                gymID: nil,
                bodyweight: nil,
                unit: .pounds,
                exercises: snapshots,
                sets: logs,
                linkedSubmissionIDs: []
            )
        }
        .sorted { $0.completedAt > $1.completedAt }
    }

    private static func seedActivityComments(for activities: [ActivityItem], profiles: [UserProfile]) -> [ActivityComment] {
        guard !activities.isEmpty else { return [] }
        let commenters = Array(profiles.dropFirst().prefix(5))
        guard !commenters.isEmpty else { return [] }
        let commentTemplates = [
            "Clean rep. What was your warmup progression?",
            "That moved fast for a max attempt.",
            "Strong lift. Depth and control looked solid.",
            "Nice work. Are you running this as part of a plan?",
            "That estimated max is climbing quick."
        ]

        return Array(activities.prefix(6)).enumerated().flatMap { activityIndex, activity in
            let count = activityIndex % 2 == 0 ? 2 : 1
            return (0..<count).map { offset in
                let commenter = commenters[(activityIndex + offset) % commenters.count]
                return ActivityComment(
                    id: UUID(),
                    activityID: activity.id,
                    authorID: commenter.id,
                    authorName: commenter.displayName,
                    body: commentTemplates[(activityIndex + offset) % commentTemplates.count],
                    createdAt: activity.createdAt.addingTimeInterval(TimeInterval((offset + 1) * 900))
                )
            }
        }
    }

    private static func seedThreadReplies(for threads: [CommunityThread], profiles: [UserProfile]) -> [CommunityThreadReply] {
        guard !threads.isEmpty else { return [] }
        let commenters = Array(profiles.dropFirst().prefix(6))
        guard !commenters.isEmpty else { return [] }
        let replyTemplates = [
            "Side angle plus the full lockout has worked best for me.",
            "I usually film from hip height so the plates and bar path are clear.",
            "I am training tonight around 7 if anyone wants to run deadlifts.",
            "Good thread. Would be useful to pin examples that got approved.",
            "For lift checks, I try to show the setup and the full rep."
        ]

        return threads.enumerated().flatMap { threadIndex, thread in
            let count = min(max(thread.replyCount, 1), 3)
            return (0..<count).map { offset in
                let commenter = commenters[(threadIndex + offset) % commenters.count]
                return CommunityThreadReply(
                    id: UUID(),
                    threadID: thread.id,
                    authorID: commenter.id,
                    authorName: commenter.displayName,
                    body: replyTemplates[(threadIndex + offset) % replyTemplates.count],
                    createdAt: thread.createdAt.addingTimeInterval(TimeInterval((offset + 1) * 1_200))
                )
            }
        }
    }

}

private struct DemoWorkoutSetSignature: Hashable {
    let performedAt: Date
    let setNumber: Int
    let weight: Double?
    let reps: Int?

    init(_ log: WorkoutSetLog) {
        performedAt = log.performedAt
        setNumber = log.setNumber
        weight = log.weight
        reps = log.reps
    }
}

private struct DemoWorkoutFeedbackSignature: Hashable {
    let sessionID: UUID
    let completedAt: Date
}
