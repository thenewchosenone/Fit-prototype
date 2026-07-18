import Foundation
import Combine
import SwiftData

@MainActor
protocol WorkoutPersistenceStore: AnyObject {
    func loadSnapshot() -> WorkoutPersistenceSnapshot?
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot)
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue]
    func reset()
}

@MainActor
final class InMemoryWorkoutPersistenceStore: WorkoutPersistenceStore {
    private(set) var snapshot: WorkoutPersistenceSnapshot?
    var legacyRecords: [LegacyWorkoutRecordValue]

    init(snapshot: WorkoutPersistenceSnapshot? = nil, legacyRecords: [LegacyWorkoutRecordValue] = []) {
        self.snapshot = snapshot
        self.legacyRecords = legacyRecords
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) { self.snapshot = snapshot }
    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] { legacyRecords }
    func reset() {
        snapshot = nil
        legacyRecords = []
    }

}

@MainActor
final class SwiftDataWorkoutPersistenceStore: WorkoutPersistenceStore {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    func loadSnapshot() -> WorkoutPersistenceSnapshot? {
        guard let record = try? context.fetch(FetchDescriptor<PersistentWorkoutState>()).first else { return nil }
        return try? decoder.decode(WorkoutPersistenceSnapshot.self, from: record.payload)
    }

    func saveSnapshot(_ snapshot: WorkoutPersistenceSnapshot) {
        guard let payload = try? encoder.encode(snapshot) else { return }
        let descriptor = FetchDescriptor<PersistentWorkoutState>()
        if let existing = try? context.fetch(descriptor).first {
            existing.schemaVersion = snapshot.schemaVersion
            existing.updatedAt = .now
            existing.payload = payload
        } else {
            context.insert(PersistentWorkoutState(schemaVersion: snapshot.schemaVersion, payload: payload))
        }
        try? context.save()
    }

    func legacyWorkoutRecords() -> [LegacyWorkoutRecordValue] {
        let records = (try? context.fetch(FetchDescriptor<PersistentWorkoutRecord>())) ?? []
        return records.map {
            LegacyWorkoutRecordValue(
                id: $0.id,
                exercise: $0.exercise,
                workout: $0.workout,
                weight: $0.weight,
                reps: $0.reps,
                rpe: $0.rpe,
                performedAt: $0.performedAt
            )
        }
    }

    func reset() {
        let records = (try? context.fetch(FetchDescriptor<PersistentWorkoutState>())) ?? []
        records.forEach(context.delete)
        try? context.save()
    }
}

@MainActor
protocol ForumPersistenceStore: AnyObject {
    func loadSnapshot() -> ForumPersistenceSnapshot?
    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot)
    func reset()
}

@MainActor
final class InMemoryForumPersistenceStore: ForumPersistenceStore {
    private(set) var snapshot: ForumPersistenceSnapshot?

    init(snapshot: ForumPersistenceSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> ForumPersistenceSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot) { self.snapshot = snapshot }
    func reset() { snapshot = nil }
}

@MainActor
final class SwiftDataForumPersistenceStore: ForumPersistenceStore {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    func loadSnapshot() -> ForumPersistenceSnapshot? {
        guard let record = try? context.fetch(FetchDescriptor<PersistentForumState>()).first else { return nil }
        return try? decoder.decode(ForumPersistenceSnapshot.self, from: record.payload)
    }

    func saveSnapshot(_ snapshot: ForumPersistenceSnapshot) {
        guard let payload = try? encoder.encode(snapshot) else { return }
        let descriptor = FetchDescriptor<PersistentForumState>()
        if let existing = try? context.fetch(descriptor).first {
            existing.schemaVersion = snapshot.schemaVersion
            existing.updatedAt = .now
            existing.payload = payload
        } else {
            context.insert(PersistentForumState(schemaVersion: snapshot.schemaVersion, payload: payload))
        }
        try? context.save()
    }

    func reset() {
        let records = (try? context.fetch(FetchDescriptor<PersistentForumState>())) ?? []
        records.forEach(context.delete)
        try? context.save()
    }
}

@MainActor
final class DemoRepository: ObservableObject {
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
    @Published var activeWorkout: ActiveWorkoutState?
    @Published var completedWorkouts: [CompletedWorkout]
    @Published var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission]
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
        currentProfile = MockData.demoProfile
        profiles = seeded.profiles
        gyms = MockData.gyms
        joinedGymIDs = [MockData.demoGymID]
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
        notifications = [
            NotificationItem(id: UUID(), title: "Deadlift approved", message: "Your 495 lb deadlift is competition verified.", kind: "Lift approved", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .profile, targetID: MockData.demoUserID)),
            NotificationItem(id: UUID(), title: "Ranking increased", message: "You moved up three spots at Crunch Fitness - South Beach.", kind: "Ranking increased", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .leaderboard, exerciseID: "deadlift", gymID: MockData.demoGymID, rankingType: .absolute)),
            NotificationItem(id: UUID(), title: "Achievement earned", message: "2x Bodyweight Deadlift unlocked.", kind: "Achievement earned", createdAt: .now, isRead: true, destination: NotificationDestination(kind: .profile, targetID: MockData.demoUserID))
        ]
        rebuildProgramBuilderDataFromEntries()
        restoreWorkoutSnapshotOrImportLegacy()
        ensurePersonalWorkoutPlan()
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
        currentProfile = MockData.demoProfile
        profiles = seeded.profiles
        gyms = MockData.gyms
        joinedGymIDs = [MockData.demoGymID]
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
            $activeWorkout.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $completedWorkouts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pendingWorkoutPRSubmissions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
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
                activeWorkout: activeWorkout,
                completedWorkouts: completedWorkouts,
                pendingPRSubmissions: pendingWorkoutPRSubmissions,
                preferences: workoutPreferences,
                planProgressionSettings: workoutPlanProgressionSettings,
                achievementUnlocks: achievementUnlocks,
                rankingHistory: rankingHistory
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
            activeWorkout = snapshot.activeWorkout
            completedWorkouts = snapshot.completedWorkouts
            pendingWorkoutPRSubmissions = snapshot.pendingPRSubmissions
            workoutPreferences = snapshot.preferences
            workoutPlanProgressionSettings = snapshot.planProgressionSettings ?? []
            achievementUnlocks = snapshot.achievementUnlocks ?? []
            rankingHistory = snapshot.rankingHistory ?? []
            refreshAchievementUnlocks()
            isRestoringWorkoutSnapshot = false
            return
        }

        completedWorkouts = importedCompletedWorkouts(
            legacyRecords: workoutPersistenceStore.legacyWorkoutRecords(),
            legacyEntries: workoutEntries
        )
        persistWorkoutSnapshot()
    }

    private func ensurePersonalWorkoutPlan() {
        guard currentProfile.id == MockData.demoUserID,
              !workoutPlans.contains(where: { $0.id == PersonalWorkoutPlanCatalog.planID }) else { return }

        let seed = PersonalWorkoutPlanCatalog.makeSeed()
        workoutPlans.append(seed.plan)
        workoutPhases.append(contentsOf: seed.phases)
        workoutWeeks.append(contentsOf: seed.weeks)
        workoutSessions.append(contentsOf: seed.sessions)
        workoutPrescriptions.append(contentsOf: seed.prescriptions)
        persistWorkoutSnapshot()
    }

    /// Populates the private demo routine with a realistic, deterministic
    /// twelve-week training history. This is only invoked by explicit DEBUG
    /// demo mode and is idempotent so seeded workouts can never multiply.
    func seedPersonalWorkoutDemoHistory(referenceDate: Date = .now) {
        let marker = "[demo:private-history-v1]"
        guard currentProfile.id == MockData.demoUserID else { return }

        ensurePersonalWorkoutPlan()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let firstMonday = calendar.date(byAdding: .weekOfYear, value: -11, to: currentMonday) else { return }

        if !workoutPlanProgressionSettings.contains(where: { $0.planID == PersonalWorkoutPlanCatalog.planID }) {
            workoutPlanProgressionSettings.append(WorkoutPlanProgressionSettings(
                planID: PersonalWorkoutPlanCatalog.planID,
                sourceTemplateID: "private_bts_beginner_12",
                sourceTemplateVersion: 1,
                startedAt: firstMonday,
                scheduledWeekdays: [2, 3, 5, 6, 7],
                method: .rirRepRange,
                preferredUnit: .pounds,
                trainingMaxKilograms: [:]
            ))
        }

        if completedWorkouts.contains(where: {
            $0.sourcePlanID == PersonalWorkoutPlanCatalog.planID && $0.notes.contains(marker)
        }) {
            persistWorkoutSnapshot()
            return
        }

        let weeks = workoutWeeks
            .filter { $0.planID == PersonalWorkoutPlanCatalog.planID }
            .sorted { $0.weekNumber < $1.weekNumber }
        guard weeks.count == 12 else { return }

        var seededWorkouts: [CompletedWorkout] = []
        var historicalPlanLogs: [WorkoutSetLog] = []
        var seededFeedback: [WorkoutFeedback] = []

        for week in weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: week.weekNumber - 1, to: firstMonday) else { continue }
            let sessions = workoutSessions
                .filter { $0.weekID == week.id }
                .sorted { $0.order < $1.order }

            for session in sessions {
                // Three scattered misses keep streaks and calendar states realistic.
                let isMissed = (week.weekNumber == 2 && session.order == 4) ||
                    (week.weekNumber == 7 && session.order == 2) ||
                    (week.weekNumber == 10 && session.order == 0)
                if isMissed { continue }

                let dayOffset = personalDemoDayOffset(session.day)
                guard let workoutDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart),
                      let completedAt = calendar.date(byAdding: .hour, value: 8, to: workoutDay),
                      completedAt <= referenceDate else { continue }

                let prescriptions = workoutPrescriptions
                    .filter { $0.sessionID == session.id }
                    .sorted { $0.order < $1.order }
                guard !prescriptions.isEmpty else { continue }

                let workoutID = UUID()
                let snapshots = prescriptions.map(exerciseSnapshot)
                var completedLogs: [WorkoutSetLog] = []

                for (exerciseIndex, pair) in zip(prescriptions, snapshots).enumerated() {
                    let prescription = pair.0
                    let snapshot = pair.1
                    let repRange = personalDemoRepRange(prescription.reps)
                    let workingWeight = personalDemoWeight(
                        for: prescription,
                        week: week.weekNumber,
                        exerciseIndex: exerciseIndex
                    )

                    if let workingWeight, workingWeight >= 40 {
                        completedLogs.append(WorkoutSetLog(
                            id: UUID(),
                            prescriptionID: snapshot.id,
                            performedAt: completedAt.addingTimeInterval(Double(exerciseIndex * 420)),
                            setNumber: 0,
                            weight: personalDemoRoundedWeight(workingWeight * 0.55),
                            reps: min(10, repRange.upperBound),
                            rpe: 4,
                            isWarmup: true,
                            isComplete: true,
                            workoutID: workoutID,
                            recordedUnit: .pounds,
                            completionSource: .manual,
                            hasTriggeredRestTimer: true
                        ))
                    }

                    for setIndex in 0..<max(1, prescription.sets) {
                        let reps = max(repRange.lowerBound, repRange.upperBound - (setIndex % 2))
                        let weight = workingWeight.map {
                            personalDemoRoundedWeight($0 + Double(setIndex) * ($0 < 40 ? 2.5 : 5))
                        }
                        let rpe = min(10, max(6, 10 - (prescription.targetRIR ?? 2) + (setIndex == prescription.sets - 1 ? 1 : 0)))
                        let performedAt = completedAt.addingTimeInterval(Double(exerciseIndex * 420 + setIndex * 90))

                        completedLogs.append(WorkoutSetLog(
                            id: UUID(),
                            prescriptionID: snapshot.id,
                            performedAt: performedAt,
                            setNumber: setIndex + 1,
                            weight: weight,
                            reps: reps,
                            rpe: rpe,
                            isWarmup: false,
                            isComplete: true,
                            workoutID: workoutID,
                            recordedUnit: .pounds,
                            completionSource: .manual,
                            hasTriggeredRestTimer: true
                        ))

                        // The plan-completion UI intentionally retains a source-
                        // prescription log after the immutable workout is created.
                        historicalPlanLogs.append(WorkoutSetLog(
                            id: UUID(),
                            prescriptionID: prescription.id,
                            performedAt: performedAt,
                            setNumber: setIndex + 1,
                            weight: weight,
                            reps: reps,
                            rpe: rpe,
                            isWarmup: false,
                            isComplete: true,
                            workoutID: nil,
                            recordedUnit: .pounds,
                            completionSource: .manual,
                            hasTriggeredRestTimer: true
                        ))
                    }
                }

                let bodyweight = currentProfile.bodyweightPounds + 2.4 - (Double(week.weekNumber - 1) * 0.42)
                let duration = TimeInterval(48 + prescriptions.count * 4 + (session.order % 3) * 3) * 60
                let sessionNote = week.weekNumber == 6
                    ? "Ramping week—kept every set controlled."
                    : (week.weekNumber == 12 ? "Finished the block feeling strong." : "Consistent session with clean reps.")

                seededWorkouts.append(CompletedWorkout(
                    id: workoutID,
                    source: .planned,
                    sourceSessionID: session.id,
                    sourcePlanID: PersonalWorkoutPlanCatalog.planID,
                    name: session.name,
                    dayLabel: session.day,
                    startedAt: completedAt.addingTimeInterval(-duration),
                    completedAt: completedAt,
                    duration: duration,
                    effort: 3 + ((week.weekNumber + session.order) % 3),
                    notes: "\(marker) \(sessionNote)",
                    gymID: MockData.demoGymID,
                    bodyweight: bodyweight,
                    unit: .pounds,
                    exercises: snapshots,
                    sets: completedLogs,
                    linkedSubmissionIDs: []
                ))
                seededFeedback.append(WorkoutFeedback(
                    id: UUID(),
                    sessionID: session.id,
                    completedAt: completedAt,
                    effort: 3 + ((week.weekNumber + session.order) % 3),
                    notes: sessionNote
                ))
            }
        }

        guard !seededWorkouts.isEmpty else { return }
        completedWorkouts.append(contentsOf: seededWorkouts)
        completedWorkouts.sort { $0.completedAt > $1.completedAt }
        workoutSetLogs.append(contentsOf: historicalPlanLogs)
        workoutFeedback.append(contentsOf: seededFeedback)
        seedPersonalDemoBodyweight(firstMonday: firstMonday, marker: marker, calendar: calendar)
        refreshAchievementUnlocks(now: referenceDate)
        persistWorkoutSnapshot()
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

    func addLift(_ lift: LiftSubmission) {
        var eligibleLift = lift
        if eligibleLift.leaderboardEligibleAt == .distantPast {
            eligibleLift.leaderboardEligibleAt = Self.nextLocalMidnight()
        }
        lifts.insert(eligibleLift, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) logged \(eligibleLift.exerciseName)", detail: "\(RankingCalculator.format(eligibleLift.weight)) \(eligibleLift.unit.shortLabel) × \(eligibleLift.repetitions)", liftID: eligibleLift.id, createdAt: .now, isLiked: false, isSaved: false), at: 0)
        notifications.insert(NotificationItem(id: UUID(), title: "Lift submitted", message: "Your lift will enter eligible rankings at the next daily update.", kind: "Lift submitted", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .lift, targetID: eligibleLift.id)), at: 0)
        refreshAchievementUnlocks()
    }

    private static func nextLocalMidnight(referenceDate: Date = .now) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? referenceDate
    }

    func addWorkoutPlan(_ plan: WorkoutPlan) {
        workoutPlans.insert(plan, at: 0)
        createDefaultProgramScaffold(for: plan)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) created a workout plan", detail: plan.name, createdAt: plan.createdAt, isLiked: false, isSaved: false), at: 0)
        persistWorkoutSnapshot()
    }

    /// Retained for importing and maintaining legacy workout records while the
    /// active tracker uses snapshot-based workouts.
    func addWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        workoutEntries.insert(entry, at: 0)
        persistWorkoutSnapshot()
    }

    func updateWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        guard let index = workoutEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        workoutEntries[index] = entry
        persistWorkoutSnapshot()
    }

    func deleteWorkoutPlan(_ plan: WorkoutPlan) {
        let phaseIDs = workoutPhases.filter { $0.planID == plan.id }.map(\.id)
        let weekIDs = workoutWeeks.filter { $0.planID == plan.id || phaseIDs.contains($0.phaseID) }.map(\.id)
        let sessionIDs = workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id)
        let prescriptionIDs = workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }.map(\.id)
        workoutPlans.removeAll { $0.id == plan.id }
        workoutPhases.removeAll { $0.planID == plan.id }
        workoutWeeks.removeAll { $0.planID == plan.id }
        workoutSessions.removeAll { weekIDs.contains($0.weekID) }
        workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == plan.id }
        workoutPlanProgressionSettings.removeAll { $0.planID == plan.id }
        persistWorkoutSnapshot()
    }

    func updateWorkoutPlan(_ plan: WorkoutPlan) {
        guard let index = workoutPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        workoutPlans[index] = plan
        persistWorkoutSnapshot()
    }

    @discardableResult
    func startWorkoutProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        preferredUnit: UnitSystem,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan {
        workoutPlans = workoutPlans.map { existing in
            var updated = existing
            updated.isActive = false
            return updated
        }

        let plan = WorkoutPlan(
            id: UUID(),
            name: template.name,
            createdAt: .now,
            goal: template.summary,
            notes: "Bundled 12-week \(template.category.rawValue.lowercased()) program.",
            isActive: true
        )
        workoutPlans.insert(plan, at: 0)
        let settings = WorkoutPlanProgressionSettings(
            planID: plan.id,
            sourceTemplateID: template.id,
            sourceTemplateVersion: template.version,
            startedAt: Calendar.current.startOfDay(for: startDate),
            scheduledWeekdays: normalizedWeekdays(scheduledWeekdays, fallback: template.sessions.map(\.dayIndex)),
            method: method,
            preferredUnit: preferredUnit,
            trainingMaxKilograms: trainingMaxKilograms
        )
        workoutPlanProgressionSettings.append(settings)

        let phaseSpecs = [
            ("Foundation", "Build technique and work capacity", 0),
            ("Progressive Overload", "Add productive volume and load", 1),
            ("Intensification", "Practice heavier, high-quality work", 2)
        ]
        let phases = phaseSpecs.map { spec in
            WorkoutPhase(id: UUID(), planID: plan.id, name: spec.0, order: spec.2, goal: spec.1, durationWeeks: 4)
        }
        workoutPhases.append(contentsOf: phases)

        for weekNumber in 1...12 {
            let phaseOrder = (weekNumber - 1) / 4
            let week = WorkoutWeek(
                id: UUID(),
                planID: plan.id,
                phaseID: phases[phaseOrder].id,
                weekNumber: weekNumber,
                title: WorkoutProgramCatalog.weekTitle(weekNumber),
                notes: weekNumber == 12 ? "Recover first. A performance check is optional, never required." : ""
            )
            workoutWeeks.append(week)

            for (sessionIndex, sessionTemplate) in template.sessions.enumerated() {
                let weekday = settings.scheduledWeekdays.indices.contains(sessionIndex)
                    ? settings.scheduledWeekdays[sessionIndex]
                    : sessionTemplate.dayIndex
                let session = WorkoutSession(
                    id: UUID(),
                    weekID: week.id,
                    day: weekdayName(weekday),
                    name: sessionTemplate.name,
                    order: sessionIndex,
                    notes: ""
                )
                workoutSessions.append(session)

                for (exerciseIndex, exerciseTemplate) in sessionTemplate.exercises.enumerated() {
                    guard let prescription = programPrescription(
                        exerciseTemplate,
                        sessionID: session.id,
                        order: exerciseIndex,
                        week: weekNumber,
                        method: method,
                        trainingMaxKilograms: trainingMaxKilograms
                    ) else { continue }
                    workoutPrescriptions.append(prescription)
                    bridgePrescriptionToWorkoutEntry(prescription)
                }
            }
        }

        activities.insert(
            ActivityItem(
                id: UUID(),
                profile: currentProfile,
                title: "\(currentProfile.displayName) started a 12-week program",
                detail: template.name,
                createdAt: .now,
                isLiked: false,
                isSaved: false
            ),
            at: 0
        )
        persistWorkoutSnapshot()
        return plan
    }

    @discardableResult
    func changeWorkoutProgramProgression(
        planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double],
        at date: Date = .now
    ) -> Bool {
        guard let settingsIndex = workoutPlanProgressionSettings.firstIndex(where: { $0.planID == planID }),
              let template = WorkoutProgramCatalog.template(id: workoutPlanProgressionSettings[settingsIndex].sourceTemplateID) else {
            return false
        }
        workoutPlanProgressionSettings[settingsIndex].method = method
        workoutPlanProgressionSettings[settingsIndex].trainingMaxKilograms = trainingMaxKilograms

        let completedWeekIDs = Set(completedWorkouts.filter { $0.sourcePlanID == planID }.compactMap { workout in
            workout.sourceSessionID.flatMap { sessionID in workoutSessions.first(where: { $0.id == sessionID })?.weekID }
        })
        let activeWeekID = activeWorkout?.sourcePlanID == planID ? activeWorkout?.sourceWeekID : nil
        let currentNumber = currentProgramWeek(planID: planID, at: date)?.weekNumber ?? 1
        let eligibleWeeks = workoutWeeks.filter {
            $0.planID == planID && $0.weekNumber >= currentNumber && !completedWeekIDs.contains($0.id) && $0.id != activeWeekID
        }

        for week in eligibleWeeks {
            for session in workoutSessions.filter({ $0.weekID == week.id }) {
                guard let sessionTemplate = template.sessions.first(where: { $0.name == session.name }) else { continue }
                for index in workoutPrescriptions.indices where workoutPrescriptions[index].sessionID == session.id {
                    guard let base = sessionTemplate.exercises.first(where: { $0.exerciseID == workoutPrescriptions[index].exerciseID }),
                          let replacement = programPrescription(
                            base,
                            sessionID: session.id,
                            order: workoutPrescriptions[index].order,
                            week: week.weekNumber,
                            method: method,
                            trainingMaxKilograms: trainingMaxKilograms
                          ) else { continue }
                    workoutPrescriptions[index].sets = replacement.sets
                    workoutPrescriptions[index].reps = replacement.reps
                    workoutPrescriptions[index].targetRIR = replacement.targetRIR
                    workoutPrescriptions[index].trainingMaxPercentage = replacement.trainingMaxPercentage
                    workoutPrescriptions[index].targetLoadKilograms = replacement.targetLoadKilograms
                }
            }
        }
        persistWorkoutSnapshot()
        return true
    }

    func currentProgramWeek(planID: UUID, at date: Date = .now) -> WorkoutWeek? {
        let weeks = workoutWeeks.filter { $0.planID == planID }.sorted { $0.weekNumber < $1.weekNumber }
        guard !weeks.isEmpty else { return nil }
        guard let settings = workoutPlanProgressionSettings.first(where: { $0.planID == planID }) else { return weeks.first }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: settings.startedAt)
        let today = calendar.startOfDay(for: date)
        let elapsedDays = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        let number = min(weeks.count, elapsedDays / 7 + 1)
        return weeks.first { $0.weekNumber == number } ?? weeks.last
    }

    func duplicateWorkoutPlan(_ plan: WorkoutPlan) -> WorkoutPlan {
        let copy = WorkoutPlan(
            id: UUID(),
            name: "\(plan.name) Copy",
            createdAt: .now,
            goal: plan.goal,
            notes: plan.notes,
            isActive: false
        )
        workoutPlans.insert(copy, at: 0)

        let phases = workoutPhases.filter { $0.planID == plan.id }.sorted { $0.order < $1.order }
        var phaseMap: [UUID: UUID] = [:]
        for phase in phases {
            let newID = UUID()
            phaseMap[phase.id] = newID
            workoutPhases.append(WorkoutPhase(id: newID, planID: copy.id, name: phase.name, order: phase.order, goal: phase.goal, durationWeeks: phase.durationWeeks))
        }

        let weeks = workoutWeeks.filter { $0.planID == plan.id }.sorted { $0.weekNumber < $1.weekNumber }
        var weekMap: [UUID: UUID] = [:]
        for week in weeks {
            guard let newPhaseID = phaseMap[week.phaseID] else { continue }
            let newID = UUID()
            weekMap[week.id] = newID
            workoutWeeks.append(WorkoutWeek(id: newID, planID: copy.id, phaseID: newPhaseID, weekNumber: week.weekNumber, title: week.title, notes: week.notes))
        }

        let sessions = workoutSessions.filter { weekMap.keys.contains($0.weekID) }.sorted { $0.order < $1.order }
        var sessionMap: [UUID: UUID] = [:]
        for session in sessions {
            guard let newWeekID = weekMap[session.weekID] else { continue }
            let newID = UUID()
            sessionMap[session.id] = newID
            workoutSessions.append(WorkoutSession(id: newID, weekID: newWeekID, day: session.day, name: session.name, order: session.order, notes: session.notes))
        }

        let prescriptions = workoutPrescriptions.filter { sessionMap.keys.contains($0.sessionID) }.sorted { $0.order < $1.order }
        for prescription in prescriptions {
            guard let newSessionID = sessionMap[prescription.sessionID] else { continue }
            workoutPrescriptions.append(WorkoutExercisePrescription(
                id: UUID(),
                sessionID: newSessionID,
                exerciseID: prescription.exerciseID,
                exerciseName: prescription.exerciseName,
                bodyPart: prescription.bodyPart,
                equipment: prescription.equipment,
                sets: prescription.sets,
                reps: prescription.reps,
                restSeconds: prescription.restSeconds,
                order: prescription.order,
                notes: prescription.notes,
                muscleProfile: prescription.muscleProfile,
                targetRIR: prescription.targetRIR,
                trainingMaxPercentage: prescription.trainingMaxPercentage,
                targetLoadKilograms: prescription.targetLoadKilograms
            ))
        }

        if var settings = workoutPlanProgressionSettings.first(where: { $0.planID == plan.id }) {
            settings.planID = copy.id
            settings.startedAt = .now
            workoutPlanProgressionSettings.append(settings)
        }

        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) duplicated a workout plan", detail: copy.name, createdAt: copy.createdAt, isLiked: false, isSaved: false), at: 0)
        persistWorkoutSnapshot()
        return copy
    }

    @discardableResult
    func addWorkoutWeek(planID: UUID, phaseID: UUID? = nil, title: String? = nil) -> WorkoutWeek {
        let phase = phaseID.flatMap { id in workoutPhases.first { $0.id == id } } ?? firstPhase(for: planID)
        let resolvedPhase = phase ?? createDefaultPhase(for: planID)
        let nextNumber = (workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber).max() ?? 0) + 1
        let week = WorkoutWeek(id: UUID(), planID: planID, phaseID: resolvedPhase.id, weekNumber: nextNumber, title: title ?? "Week \(nextNumber)", notes: "")
        workoutWeeks.append(week)
        persistWorkoutSnapshot()
        return week
    }

    @discardableResult
    func cloneWorkoutWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        let newWeek = addWorkoutWeek(planID: week.planID, phaseID: week.phaseID, title: "Week \(nextWeekNumber(for: week.planID))")
        let sessions = workoutSessions.filter { $0.weekID == week.id }.sorted { $0.order < $1.order }
        var sessionMap: [UUID: UUID] = [:]
        for session in sessions {
            let clone = WorkoutSession(id: UUID(), weekID: newWeek.id, day: session.day, name: session.name, order: session.order, notes: session.notes)
            workoutSessions.append(clone)
            sessionMap[session.id] = clone.id
        }
        for prescription in workoutPrescriptions.filter({ sessionMap.keys.contains($0.sessionID) }) {
            guard let newSessionID = sessionMap[prescription.sessionID] else { continue }
            workoutPrescriptions.append(WorkoutExercisePrescription(
                id: UUID(),
                sessionID: newSessionID,
                exerciseID: prescription.exerciseID,
                exerciseName: prescription.exerciseName,
                bodyPart: prescription.bodyPart,
                equipment: prescription.equipment,
                sets: prescription.sets,
                reps: prescription.reps,
                restSeconds: prescription.restSeconds,
                order: prescription.order,
                notes: prescription.notes,
                muscleProfile: prescription.muscleProfile,
                targetRIR: prescription.targetRIR,
                trainingMaxPercentage: prescription.trainingMaxPercentage,
                targetLoadKilograms: prescription.targetLoadKilograms
            ))
        }
        persistWorkoutSnapshot()
        return newWeek
    }

    func deleteWorkoutWeek(_ week: WorkoutWeek) {
        let sessionIDs = workoutSessions.filter { $0.weekID == week.id }.map(\.id)
        let prescriptionIDs = workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }.map(\.id)
        workoutWeeks.removeAll { $0.id == week.id }
        workoutSessions.removeAll { $0.weekID == week.id }
        workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == week.planID && $0.week == week.weekNumber }
        persistWorkoutSnapshot()
    }

    @discardableResult
    func addWorkoutSession(weekID: UUID, day: String, name: String) -> WorkoutSession {
        let nextOrder = (workoutSessions.filter { $0.weekID == weekID }.map(\.order).max() ?? -1) + 1
        let session = WorkoutSession(id: UUID(), weekID: weekID, day: day, name: name, order: nextOrder, notes: "")
        workoutSessions.append(session)
        persistWorkoutSnapshot()
        return session
    }

    func deleteWorkoutSession(_ session: WorkoutSession) {
        guard let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return }
        let prescriptionIDs = workoutPrescriptions.filter { $0.sessionID == session.id }.map(\.id)
        workoutSessions.removeAll { $0.id == session.id }
        workoutPrescriptions.removeAll { $0.sessionID == session.id }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == week.planID && $0.week == week.weekNumber && $0.workout == session.name }
        persistWorkoutSnapshot()
    }

    func cancelWorkoutSession(_ session: WorkoutSession) {
        if session.name.localizedCaseInsensitiveContains("freestyle") {
            deleteWorkoutSession(session)
            return
        }

        let prescriptionIDs = Set(workoutPrescriptions.filter { $0.sessionID == session.id }.map(\.id))
        workoutSetLogs.removeAll { log in
            prescriptionIDs.contains(log.prescriptionID) && Calendar.current.isDateInToday(log.performedAt)
        }
        persistWorkoutSnapshot()
    }

    @discardableResult
    func addWorkoutPrescription(_ prescription: WorkoutExercisePrescription) -> WorkoutExercisePrescription {
        workoutPrescriptions.append(prescription)
        bridgePrescriptionToWorkoutEntry(prescription)
        persistWorkoutSnapshot()
        return prescription
    }

    func updateWorkoutPrescription(_ prescription: WorkoutExercisePrescription) {
        guard let index = workoutPrescriptions.firstIndex(where: { $0.id == prescription.id }) else { return }
        workoutPrescriptions[index] = prescription
        persistWorkoutSnapshot()
    }

    func deleteWorkoutPrescription(_ prescription: WorkoutExercisePrescription) {
        workoutPrescriptions.removeAll { $0.id == prescription.id }
        workoutSetLogs.removeAll { $0.prescriptionID == prescription.id }
        workoutEntries.removeAll { $0.exercise == prescription.exerciseName && $0.workout == session(for: prescription)?.name }
        persistWorkoutSnapshot()
    }

    @discardableResult
    func startWorkout(
        session: WorkoutSession,
        planID: UUID?,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem
    ) -> ActiveWorkoutState? {
        guard activeWorkout == nil else { return nil }
        let snapshots = workoutPrescriptions
            .filter { $0.sessionID == session.id }
            .sorted { $0.order < $1.order }
            .map(exerciseSnapshot)
        let workout = ActiveWorkoutState(
            id: UUID(),
            source: .planned,
            sourceSessionID: session.id,
            sourcePlanID: planID,
            sourceWeekID: session.weekID,
            name: session.name,
            dayLabel: session.day,
            startedAt: .now,
            pausedAt: nil,
            accumulatedPausedTime: 0,
            gymID: gymID,
            bodyweight: bodyweight,
            unit: unit,
            exercises: snapshots,
            automaticRestTimerEnabled: workoutPreferences.defaultRestTimerEnabled,
            restTimerEndsAt: nil,
            restTimerExerciseID: nil
        )
        activeWorkout = workout
        createInitialSetLogs(for: workout)
        persistWorkoutSnapshot()
        return workout
    }

    @discardableResult
    func startFreestyleWorkout(
        name: String = "Freestyle Workout",
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem
    ) -> ActiveWorkoutState? {
        guard activeWorkout == nil else { return nil }
        let workout = ActiveWorkoutState(
            id: UUID(),
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            sourceWeekID: nil,
            name: name,
            dayLabel: Date.now.formatted(.dateTime.weekday(.wide)),
            startedAt: .now,
            pausedAt: nil,
            accumulatedPausedTime: 0,
            gymID: gymID,
            bodyweight: bodyweight,
            unit: unit,
            exercises: [],
            automaticRestTimerEnabled: workoutPreferences.defaultRestTimerEnabled,
            restTimerEndsAt: nil,
            restTimerExerciseID: nil
        )
        activeWorkout = workout
        persistWorkoutSnapshot()
        return workout
    }

    func addExercisesToActiveWorkout(_ exercises: [TrainingExerciseCatalogItem]) {
        guard var workout = activeWorkout else { return }
        var existingExerciseIDs = Set(workout.exercises.map(\.exerciseID))
        let newExercises = exercises.filter { existingExerciseIDs.insert($0.id).inserted }
        guard !newExercises.isEmpty else { return }
        let nextOrder = workout.exercises.count
        for (offset, exercise) in newExercises.enumerated() {
            let snapshot = WorkoutExerciseSnapshot(
                id: UUID(),
                sourcePrescriptionID: nil,
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart,
                equipment: exercise.equipment,
                targetSets: exercise.defaultSets,
                targetReps: exercise.defaultReps,
                restSeconds: exercise.defaultRestSeconds,
                order: nextOrder + offset,
                notes: "",
                rankingExerciseID: exercise.rankingExerciseID,
                muscleProfile: exercise.resolvedMuscleProfile,
                demonstrationMediaID: exercise.demonstrationMediaID
            )
            workout.exercises.append(snapshot)
            for setNumber in 1...max(1, snapshot.targetSets) {
                workoutSetLogs.append(
                    WorkoutSetLog(
                        id: UUID(),
                        prescriptionID: snapshot.id,
                        performedAt: .now,
                        setNumber: setNumber,
                        weight: nil,
                        reps: nil,
                        rpe: nil,
                        isWarmup: false,
                        isComplete: false,
                        workoutID: workout.id,
                        recordedUnit: workout.unit
                    )
                )
            }
        }
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    func removeExerciseFromActiveWorkout(_ exercise: WorkoutExerciseSnapshot) {
        guard var workout = activeWorkout else { return }
        workout.exercises.removeAll { $0.id == exercise.id }
        normalizeActiveExerciseOrder(&workout)
        workoutSetLogs.removeAll { $0.workoutID == workout.id && $0.prescriptionID == exercise.id }
        if workout.restTimerExerciseID == exercise.id {
            workout.restTimerEndsAt = nil
            workout.restTimerExerciseID = nil
        }
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    @discardableResult
    func reorderActiveWorkout(exerciseIDs: [UUID]) -> Bool {
        guard var workout = activeWorkout else { return false }
        let currentIDs = Set(workout.exercises.map(\.id))
        guard currentIDs == Set(exerciseIDs), exerciseIDs.count == workout.exercises.count else { return false }
        let lookup = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
        workout.exercises = exerciseIDs.enumerated().compactMap { index, id in
            guard var exercise = lookup[id] else { return nil }
            exercise.order = index
            return exercise
        }
        activeWorkout = workout
        persistWorkoutSnapshot()
        return true
    }

    @discardableResult
    func moveActiveWorkoutExercise(_ exerciseID: UUID, direction: Int) -> Bool {
        guard var workout = activeWorkout,
              let index = workout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return false }
        let target = max(0, min(workout.exercises.count - 1, index + direction))
        guard target != index else { return false }
        let moved = workout.exercises.remove(at: index)
        workout.exercises.insert(moved, at: target)
        normalizeActiveExerciseOrder(&workout)
        activeWorkout = workout
        persistWorkoutSnapshot()
        return true
    }

    func setAutomaticRestTimerEnabledForActiveWorkout(_ enabled: Bool) {
        guard var workout = activeWorkout else { return }
        workout.automaticRestTimerEnabled = enabled
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    @discardableResult
    func substituteActiveWorkoutExercise(
        currentExerciseID: UUID,
        substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot? {
        guard var workout = activeWorkout,
              let index = workout.exercises.firstIndex(where: { $0.id == currentExerciseID }) else { return nil }
        let current = workout.exercises[index]
        let completedSets = workoutSetLogs.filter {
            $0.workoutID == workout.id && $0.prescriptionID == current.id && $0.isComplete
        }

        if completedSets.isEmpty {
            workout.exercises[index] = replacementSnapshot(from: current, substitute: substitute, preserveID: true)
            activeWorkout = workout
            persistWorkoutSnapshot()
            return workout.exercises[index]
        }

        let replacement = replacementSnapshot(from: current, substitute: substitute, preserveID: false)
        workout.exercises.insert(replacement, at: index + 1)
        normalizeActiveExerciseOrder(&workout)
        for setNumber in 1...max(1, replacement.targetSets) {
            workoutSetLogs.append(
                WorkoutSetLog(
                    id: UUID(),
                    prescriptionID: replacement.id,
                    performedAt: .now,
                    setNumber: setNumber,
                    weight: nil,
                    reps: nil,
                    rpe: nil,
                    isWarmup: false,
                    isComplete: false,
                    workoutID: workout.id,
                    recordedUnit: workout.unit
                )
            )
        }
        activeWorkout = workout
        persistWorkoutSnapshot()
        return replacement
    }

    @discardableResult
    func updateSourcePlanFromActiveWorkout() -> Bool {
        guard let workout = activeWorkout, let sessionID = workout.sourceSessionID else { return false }
        let existingIDs = Set(workoutPrescriptions.filter { $0.sessionID == sessionID }.map(\.id))
        workoutPrescriptions.removeAll { $0.sessionID == sessionID }
        workoutSetLogs.removeAll { $0.workoutID == nil && existingIDs.contains($0.prescriptionID) }
        workoutPrescriptions += workout.exercises.sorted { $0.order < $1.order }.map { exercise in
            WorkoutExercisePrescription(
                id: exercise.sourcePrescriptionID ?? UUID(),
                sessionID: sessionID,
                exerciseID: exercise.exerciseID,
                exerciseName: exercise.exerciseName,
                bodyPart: exercise.bodyPart,
                equipment: exercise.equipment,
                sets: exercise.targetSets,
                reps: exercise.targetReps,
                restSeconds: exercise.restSeconds,
                order: exercise.order,
                notes: exercise.notes,
                muscleProfile: exercise.muscleProfile,
                targetRIR: exercise.targetRIR,
                trainingMaxPercentage: exercise.trainingMaxPercentage,
                targetLoadKilograms: exercise.targetLoadKilograms
            )
        }
        persistWorkoutSnapshot()
        return true
    }

    func pauseActiveWorkout(at date: Date = .now) {
        guard var workout = activeWorkout, workout.pausedAt == nil else { return }
        workout.pausedAt = date
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    func resumeActiveWorkout(at date: Date = .now) {
        guard var workout = activeWorkout, let pausedAt = workout.pausedAt else { return }
        workout.accumulatedPausedTime += max(0, date.timeIntervalSince(pausedAt))
        workout.pausedAt = nil
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    func updateActiveRestTimer(endsAt: Date?, exerciseID: UUID?) {
        guard var workout = activeWorkout else { return }
        workout.restTimerEndsAt = endsAt
        workout.restTimerExerciseID = exerciseID
        activeWorkout = workout
        persistWorkoutSnapshot()
    }

    func discardActiveWorkout() {
        guard let workoutID = activeWorkout?.id else { return }
        workoutSetLogs.removeAll { $0.workoutID == workoutID }
        activeWorkout = nil
        persistWorkoutSnapshot()
    }

    @discardableResult
    func finishActiveWorkout(effort: Int, notes: String, at completedAt: Date = .now) -> CompletedWorkout? {
        guard let workout = activeWorkout else { return nil }
        let logs = workoutSetLogs.filter { $0.workoutID == workout.id }
        guard logs.contains(where: { $0.isComplete && !$0.isWarmup }) else { return nil }
        let safeCompletedAt = max(completedAt, workout.startedAt)
        let completed = CompletedWorkout(
            id: workout.id,
            source: workout.source,
            sourceSessionID: workout.sourceSessionID,
            sourcePlanID: workout.sourcePlanID,
            name: workout.name,
            dayLabel: workout.dayLabel,
            startedAt: workout.startedAt,
            completedAt: safeCompletedAt,
            duration: workout.elapsedDuration(at: safeCompletedAt),
            effort: min(max(effort, 1), 5),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            gymID: workout.gymID,
            bodyweight: workout.bodyweight,
            unit: workout.unit,
            exercises: workout.exercises,
            sets: logs,
            linkedSubmissionIDs: []
        )
        completedWorkouts.insert(completed, at: 0)
        workoutSetLogs.removeAll { $0.workoutID == workout.id }
        activeWorkout = nil
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
        return completed
    }

    func deleteCompletedWorkout(_ workout: CompletedWorkout) {
        completedWorkouts.removeAll { $0.id == workout.id }
        pendingWorkoutPRSubmissions.removeAll {
            $0.candidate.completedWorkoutID == workout.id && $0.state != .submitted
        }
        persistWorkoutSnapshot()
    }

    func linkSubmission(_ submissionID: UUID, to workoutID: UUID) {
        guard let index = completedWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }
        if !completedWorkouts[index].linkedSubmissionIDs.contains(submissionID) {
            completedWorkouts[index].linkedSubmissionIDs.append(submissionID)
        }
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
    }

    func upsertPendingPRSubmission(_ pending: PendingWorkoutPRSubmission) {
        if let index = pendingWorkoutPRSubmissions.firstIndex(where: { $0.candidate.setID == pending.candidate.setID }) {
            pendingWorkoutPRSubmissions[index] = pending
        } else {
            pendingWorkoutPRSubmissions.append(pending)
        }
        persistWorkoutSnapshot()
    }

    private func exerciseSnapshot(_ prescription: WorkoutExercisePrescription) -> WorkoutExerciseSnapshot {
        let catalog = (MockData.trainingExerciseLibrary + customTrainingExercises).first { $0.id == prescription.exerciseID }
        return WorkoutExerciseSnapshot(
            id: UUID(),
            sourcePrescriptionID: prescription.id,
            exerciseID: prescription.exerciseID,
            exerciseName: prescription.exerciseName,
            bodyPart: prescription.bodyPart,
            equipment: prescription.equipment,
            targetSets: prescription.sets,
            targetReps: prescription.reps,
            restSeconds: prescription.restSeconds,
            order: prescription.order,
            notes: prescription.notes,
            rankingExerciseID: catalog?.rankingExerciseID,
            muscleProfile: prescription.muscleProfile ?? catalog?.resolvedMuscleProfile,
            targetRIR: prescription.targetRIR,
            trainingMaxPercentage: prescription.trainingMaxPercentage,
            targetLoadKilograms: prescription.targetLoadKilograms,
            demonstrationMediaID: catalog?.demonstrationMediaID
        )
    }

    private func createInitialSetLogs(for workout: ActiveWorkoutState) {
        for exercise in workout.exercises {
            for setNumber in 1...max(1, exercise.targetSets) {
                workoutSetLogs.append(
                    WorkoutSetLog(
                        id: UUID(),
                        prescriptionID: exercise.id,
                        performedAt: workout.startedAt,
                        setNumber: setNumber,
                        weight: nil,
                        reps: nil,
                        rpe: nil,
                        isWarmup: false,
                        isComplete: false,
                        workoutID: workout.id,
                        recordedUnit: workout.unit
                    )
                )
            }
        }
    }

    func updateWorkoutSetLog(_ log: WorkoutSetLog) {
        if let index = workoutSetLogs.firstIndex(where: { $0.id == log.id }) {
            let previous = workoutSetLogs[index]
            var updated = log
            let valuesChanged = previous.weight != updated.weight || previous.reps != updated.reps
            if valuesChanged {
                updated.suppressAutoCompletion = false
            }
            workoutSetLogs[index] = updated
        } else {
            workoutSetLogs.append(log)
        }
        persistWorkoutSnapshot()
    }

    @discardableResult
    func addWorkoutSetLog(prescriptionID: UUID, setNumber: Int? = nil, workoutID: UUID? = nil, unit: UnitSystem = .pounds) -> WorkoutSetLog {
        let nextNumber = setNumber ?? ((workoutSetLogs.filter { $0.prescriptionID == prescriptionID && $0.workoutID == workoutID }.map(\.setNumber).max() ?? 0) + 1)
        let log = WorkoutSetLog(id: UUID(), prescriptionID: prescriptionID, performedAt: .now, setNumber: nextNumber, weight: nil, reps: nil, rpe: nil, isWarmup: false, isComplete: false, workoutID: workoutID, recordedUnit: unit)
        workoutSetLogs.append(log)
        persistWorkoutSnapshot()
        return log
    }

    func deleteWorkoutSetLog(_ log: WorkoutSetLog) {
        workoutSetLogs.removeAll { $0.id == log.id }
        persistWorkoutSnapshot()
    }

    @discardableResult
    func applyWorkoutSetCompletion(
        logID: UUID,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> WorkoutSetLog? {
        guard let index = workoutSetLogs.firstIndex(where: { $0.id == logID }) else { return nil }
        var log = workoutSetLogs[index]
        if !isComplete, log.completionSource == .automatic, source == .manual {
            log.suppressAutoCompletion = true
        }
        log.isComplete = isComplete
        log.performedAt = .now
        log.completionSource = isComplete ? source : nil
        log.hasTriggeredRestTimer = isComplete
        workoutSetLogs[index] = log
        persistWorkoutSnapshot()
        return log
    }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem) {
        customTrainingExercises.insert(exercise, at: 0)
        persistWorkoutSnapshot()
    }

    func workoutSummary(for session: WorkoutSession) -> WorkoutSummary {
        let prescriptions = workoutPrescriptions.filter { $0.sessionID == session.id }
        let prescriptionIDs = Set(prescriptions.map(\.id))
        let completedLogs = workoutSetLogs.filter { log in
            prescriptionIDs.contains(log.prescriptionID) &&
            log.isComplete &&
            Calendar.current.isDateInToday(log.performedAt)
        }
        let completedExerciseIDs = Set(completedLogs.map(\.prescriptionID))
        let best = completedLogs.max { lhs, rhs in
            (lhs.weight ?? 0) < (rhs.weight ?? 0)
        }
        return WorkoutSummary(
            id: UUID(),
            sessionID: session.id,
            workoutName: session.name,
            completedExercises: completedExerciseIDs.count,
            totalExercises: prescriptions.count,
            totalSets: completedLogs.count,
            totalVolume: completedLogs.reduce(0) { $0 + $1.volume },
            bestSet: best
        )
    }

    func saveWorkoutFeedback(sessionID: UUID, effort: Int, notes: String) {
        let feedback = WorkoutFeedback(
            id: UUID(),
            sessionID: sessionID,
            completedAt: .now,
            effort: min(max(effort, 1), 5),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        workoutFeedback.removeAll { $0.sessionID == sessionID && Calendar.current.isDateInToday($0.completedAt) }
        workoutFeedback.append(feedback)
        persistWorkoutSnapshot()
    }

    private func rebuildProgramBuilderDataFromEntries() {
        workoutPhases.removeAll()
        workoutWeeks.removeAll()
        workoutSessions.removeAll()
        workoutPrescriptions.removeAll()
        workoutSetLogs.removeAll()

        for plan in workoutPlans {
            let entries = workoutEntries.filter { $0.planID == plan.id }
            let maxWeek = max(1, entries.map(\.week).max() ?? 1)
            let phase = WorkoutPhase(id: UUID(), planID: plan.id, name: "Base Phase", order: 0, goal: plan.goal, durationWeeks: maxWeek)
            workoutPhases.append(phase)

            let weekNumbers = Set(entries.map(\.week)).union([1]).sorted()
            for weekNumber in weekNumbers {
                let week = WorkoutWeek(id: UUID(), planID: plan.id, phaseID: phase.id, weekNumber: weekNumber, title: "Week \(weekNumber)", notes: "")
                workoutWeeks.append(week)

                let weekEntries = entries.filter { $0.week == weekNumber }
                let groups = Dictionary(grouping: weekEntries) { $0.workout }
                for (sessionIndex, group) in groups.sorted(by: { lhs, rhs in
                    let lhsDay = lhs.value.first?.day ?? ""
                    let rhsDay = rhs.value.first?.day ?? ""
                    return dayOrder(lhsDay) < dayOrder(rhsDay)
                }).enumerated() {
                    let session = WorkoutSession(
                        id: UUID(),
                        weekID: week.id,
                        day: group.value.first?.day ?? "Any day",
                        name: group.key,
                        order: sessionIndex,
                        notes: ""
                    )
                    workoutSessions.append(session)

                    for (exerciseIndex, entry) in group.value.sorted(by: { $0.exercise < $1.exercise }).enumerated() {
                        let catalog = (MockData.trainingExerciseLibrary + customTrainingExercises).first { $0.name == entry.exercise }
                        let prescription = WorkoutExercisePrescription(
                            id: UUID(),
                            sessionID: session.id,
                            exerciseID: catalog?.id ?? entry.exercise.lowercased().replacingOccurrences(of: " ", with: "_"),
                            exerciseName: entry.exercise,
                            bodyPart: entry.muscleGroup,
                            equipment: catalog?.equipment ?? "Mixed",
                            sets: entry.targetSets,
                            reps: entry.targetReps,
                            restSeconds: catalog?.defaultRestSeconds ?? 120,
                            order: exerciseIndex,
                            notes: entry.notes,
                            muscleProfile: catalog?.resolvedMuscleProfile
                        )
                        workoutPrescriptions.append(prescription)

                        for (setIndex, set) in entry.sets.enumerated() {
                            workoutSetLogs.append(WorkoutSetLog(
                                id: set.id,
                                prescriptionID: prescription.id,
                                performedAt: entry.date,
                                setNumber: setIndex + 1,
                                weight: set.weight,
                                reps: set.reps,
                                rpe: set.rpe,
                                isWarmup: false,
                                isComplete: entry.isDone
                            ))
                        }
                    }
                }
            }
        }
    }

    private func createDefaultProgramScaffold(for plan: WorkoutPlan) {
        let phase = createDefaultPhase(for: plan.id)
        let week = WorkoutWeek(id: UUID(), planID: plan.id, phaseID: phase.id, weekNumber: 1, title: "Week 1", notes: "")
        workoutWeeks.append(week)
        workoutSessions.append(WorkoutSession(id: UUID(), weekID: week.id, day: "Monday", name: "Freestyle Workout", order: 0, notes: ""))
    }

    private func programPrescription(
        _ template: WorkoutProgramExerciseTemplate,
        sessionID: UUID,
        order: Int,
        week: Int,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutExercisePrescription? {
        guard let exercise = (MockData.trainingExerciseLibrary + customTrainingExercises).first(where: { $0.id == template.exerciseID }) else {
            return nil
        }
        let setCount = max(1, Int((Double(template.sets) * WorkoutProgramCatalog.volumeMultiplier(for: week)).rounded()))
        let percentage = method == .percentage ? trainingMaxKilograms[exercise.id].map { _ in WorkoutProgramCatalog.percentage(for: week) } : nil
        let percentageReps = [6, 6, 5, 5, 5, 4, 3, 5, 3, 2, 1, 5][max(0, min(11, week - 1))]
        let reps = percentage == nil ? template.reps : "\(percentageReps)"
        let targetRIR = method == .rirRepRange || (method == .percentage && percentage == nil)
            ? WorkoutProgramCatalog.rirTarget(for: week)
            : nil
        let targetLoad = percentage.flatMap { value in trainingMaxKilograms[exercise.id].map { $0 * value } }
        var notes = template.notes
        if week == 4 || week == 8 || week == 12 {
            notes = [notes, "Deload week: prioritize recovery and clean technique."].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return WorkoutExercisePrescription(
            id: UUID(),
            sessionID: sessionID,
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            bodyPart: exercise.bodyPart,
            equipment: exercise.equipment,
            sets: setCount,
            reps: reps,
            restSeconds: template.restSeconds,
            order: order,
            notes: notes,
            muscleProfile: exercise.resolvedMuscleProfile,
            targetRIR: targetRIR,
            trainingMaxPercentage: percentage,
            targetLoadKilograms: targetLoad
        )
    }

    private func normalizedWeekdays(_ values: [Int], fallback: [Int]) -> [Int] {
        let valid = values.filter { (1...7).contains($0) }
        return valid.count == fallback.count ? valid : fallback
    }

    private func weekdayName(_ weekday: Int) -> String {
        let names = Calendar.current.weekdaySymbols
        guard names.indices.contains(weekday - 1) else { return "Any day" }
        return names[weekday - 1]
    }

    private func createDefaultPhase(for planID: UUID) -> WorkoutPhase {
        let phase = WorkoutPhase(id: UUID(), planID: planID, name: "Base Phase", order: 0, goal: "Build strength and muscle", durationWeeks: 1)
        workoutPhases.append(phase)
        return phase
    }

    private func firstPhase(for planID: UUID) -> WorkoutPhase? {
        workoutPhases
            .filter { $0.planID == planID }
            .sorted { $0.order < $1.order }
            .first
    }

    private func nextWeekNumber(for planID: UUID) -> Int {
        (workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber).max() ?? 0) + 1
    }

    private func bridgePrescriptionToWorkoutEntry(_ prescription: WorkoutExercisePrescription) {
        guard let session = session(for: prescription),
              let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return }
        let exists = workoutEntries.contains { entry in
            entry.planID == week.planID &&
            entry.week == week.weekNumber &&
            entry.workout == session.name &&
            entry.exercise == prescription.exerciseName
        }
        guard !exists else { return }
        workoutEntries.insert(
            WorkoutExerciseEntry(
                id: UUID(),
                planID: week.planID,
                week: week.weekNumber,
                date: .now,
                day: session.day,
                workout: session.name,
                exercise: prescription.exerciseName,
                muscleGroup: prescription.bodyPart,
                targetSets: prescription.sets,
                targetReps: prescription.reps,
                sets: [],
                isDone: false,
                notes: prescription.notes
            ),
            at: 0
        )
    }

    private func session(for prescription: WorkoutExercisePrescription) -> WorkoutSession? {
        workoutSessions.first { $0.id == prescription.sessionID }
    }

    private func dayOrder(_ day: String) -> Int {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].firstIndex(of: day) ?? 99
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        guard let index = bodyweightEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        bodyweightEntries[index] = entry
        persistWorkoutSnapshot()
    }

    func computedStatistics(referenceDate: Date = .now) -> CompetitiveStatistics {
        let completedWorkingSets = completedWorkouts.flatMap(\.completedWorkingSets)
        return CompetitiveStatistics(
            totalWorkouts: completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }.count,
            lifetimeWorkingSetVolume: completedWorkingSets.reduce(0) { total, log in
                let kilograms = log.recordedUnit == .kilograms ? (log.weight ?? 0) : RankingCalculator.poundsToKilograms(log.weight ?? 0)
                return total + (kilograms * Double(log.reps ?? 0))
            },
            totalActiveTrainingTime: completedWorkouts.reduce(0) { $0 + $1.duration },
            totalWorkingSetRepetitions: completedWorkingSets.reduce(0) { $0 + ($1.reps ?? 0) },
            prCount: completedPRCount(),
            currentStreak: currentWorkoutStreak(referenceDate: referenceDate),
            longestStreak: longestWorkoutStreak(),
            verifiedLiftCount: lifts.filter(\.verificationStatus.isDefaultLeaderboardEligible).count,
            currentGlobalTotalRank: nil,
            highestGlobalTotalRank: nil,
            currentGymTotalRank: nil,
            highestGymTotalRank: nil
        )
    }

    private func completedPRCount() -> Int {
        var seen = Set<String>()
        var count = 0
        for workout in completedWorkouts.sorted(by: { $0.completedAt < $1.completedAt }) {
            for set in workout.completedWorkingSets {
                guard let exercise = workout.exercises.first(where: { $0.id == set.prescriptionID }),
                      let rankingID = exercise.rankingExerciseID,
                      let weight = set.weight,
                      let reps = set.reps else { continue }
                let kilograms = set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
                let key = "\(rankingID)|\(reps)"
                let previous = seen.contains(key) ? maxVerifiedOrCompletedOneRepKilograms(for: rankingID) : nil
                if previous == nil || kilograms > (previous ?? 0) {
                    count += 1
                }
                seen.insert(key)
            }
        }
        return count
    }

    private func currentWorkoutStreak(referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }.map { calendar.startOfDay(for: $0.completedAt) })
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
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func longestWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = completedWorkouts
            .filter { !$0.completedWorkingSets.isEmpty }
            .map { calendar.startOfDay(for: $0.completedAt) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if delta == 0 { continue }
            if delta == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private func refreshAchievementUnlocks(now: Date = .now) {
        let existingByTitle = Dictionary(uniqueKeysWithValues: achievementUnlocks.map { ($0.title, $0) })
        var refreshed: [AchievementUnlock] = []
        for title in earnedAchievementTitles() {
            refreshed.append(existingByTitle[title] ?? AchievementUnlock(
                id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: title,
                unlockedAt: now
            ))
        }
        achievementUnlocks = refreshed.sorted { $0.unlockedAt > $1.unlockedAt }
    }

    private func earnedAchievementTitles() -> [String] {
        let stats = computedStatistics()
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
        let maxBench = maxVerifiedOrCompletedOneRepKilograms(for: "bench")
        let maxSquat = maxVerifiedOrCompletedOneRepKilograms(for: "squat")
        let maxDeadlift = maxVerifiedOrCompletedOneRepKilograms(for: "deadlift")
        var titles: [String] = []
        func add(_ title: String, when condition: Bool) { if condition { titles.append(title) } }
        add("First Workout", when: stats.totalWorkouts >= 1)
        add("10 Workouts", when: stats.totalWorkouts >= 10)
        add("50 Workouts", when: stats.totalWorkouts >= 50)
        add("100 Workouts", when: stats.totalWorkouts >= 100)
        add("First Lift Logged", when: !lifts.isEmpty)
        add("First Verified Lift", when: stats.verifiedLiftCount >= 1)
        add("Ten Verified Lifts", when: stats.verifiedLiftCount >= 10)
        add("First PR", when: stats.prCount >= 1)
        add("10 PRs", when: stats.prCount >= 10)
        add("25 PRs", when: stats.prCount >= 25)
        add("135 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(135))
        add("225 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(225))
        add("315 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(315))
        add("225 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(225))
        add("315 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(315))
        add("405 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(405))
        add("315 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(315))
        add("405 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(405))
        add("500 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(500))
        add("Bodyweight Bench", when: maxBench >= bodyweightKilograms)
        add("1.5x Bodyweight Squat", when: maxSquat >= bodyweightKilograms * 1.5)
        add("2x Bodyweight Deadlift", when: maxDeadlift >= bodyweightKilograms * 2)
        add("7-Day Workout Streak", when: stats.currentStreak >= 7)
        add("30-Day Workout Streak", when: stats.currentStreak >= 30)
        add("90-Day Workout Streak", when: stats.currentStreak >= 90)
        add("50,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 50_000)
        add("250,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 250_000)
        add("1,000,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 1_000_000)
        add("Profile Complete", when: isProfileComplete())
        return titles
    }

    private func maxVerifiedOrCompletedOneRepKilograms(for rankingExerciseID: String) -> Double {
        let liftBest = lifts.filter { $0.exerciseID == rankingExerciseID && $0.repetitions == 1 }.map(\.normalizedWeightKilograms).max() ?? 0
        let workoutBest = completedWorkouts.flatMap { workout in
            workout.completedWorkingSets.compactMap { log -> Double? in
                guard log.reps == 1,
                      let exercise = workout.exercises.first(where: { $0.id == log.prescriptionID }),
                      exercise.rankingExerciseID == rankingExerciseID,
                      let weight = log.weight else { return nil }
                return log.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
            }
        }.max() ?? 0
        return max(liftBest, workoutBest)
    }

    private func isProfileComplete() -> Bool {
        !currentProfile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizeActiveExerciseOrder(_ workout: inout ActiveWorkoutState) {
        workout.exercises = workout.exercises.enumerated().map { index, exercise in
            var exercise = exercise
            exercise.order = index
            return exercise
        }
    }

    private func replacementSnapshot(
        from current: WorkoutExerciseSnapshot,
        substitute: TrainingExerciseCatalogItem,
        preserveID: Bool
    ) -> WorkoutExerciseSnapshot {
        WorkoutExerciseSnapshot(
            id: preserveID ? current.id : UUID(),
            sourcePrescriptionID: preserveID ? current.sourcePrescriptionID : nil,
            exerciseID: substitute.id,
            exerciseName: substitute.name,
            bodyPart: substitute.bodyPart,
            equipment: substitute.equipment,
            targetSets: current.targetSets,
            targetReps: current.targetReps,
            restSeconds: current.restSeconds,
            order: current.order,
            notes: current.notes,
            rankingExerciseID: substitute.rankingExerciseID,
            muscleProfile: substitute.resolvedMuscleProfile,
            targetRIR: current.targetRIR,
            trainingMaxPercentage: current.trainingMaxPercentage,
            targetLoadKilograms: current.targetLoadKilograms,
            substitutedFromExerciseID: current.exerciseID,
            substitutedFromExerciseName: current.exerciseName,
            demonstrationMediaID: substitute.demonstrationMediaID
        )
    }

    func addThread(_ thread: CommunityThread) {
        communityThreads.insert(thread, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) started a thread", detail: thread.title, createdAt: thread.createdAt, isLiked: false, isSaved: false), at: 0)
    }

    func addReply(to thread: CommunityThread, body: String, author: UserProfile) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }),
              !communityThreads[index].isLocked,
              communityThreads[index].removedAt == nil else { return }
        communityThreads[index].replyCount += 1
        communityThreadReplies.append(
            CommunityThreadReply(
                id: UUID(),
                threadID: thread.id,
                authorID: author.id,
                authorName: author.displayName,
                body: body,
                createdAt: .now
            )
        )
        activities.insert(ActivityItem(id: UUID(), profile: author, title: "\(author.displayName) replied to \(thread.title)", detail: body, createdAt: .now, isLiked: false, isSaved: false), at: 0)
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        voteThread(thread, vote: communityThreads[index].votes[currentProfile.id] == .up ? nil : .up)
    }

    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }),
              communityThreads[index].removedAt == nil else { return }
        let previousVote = communityThreads[index].votes[currentProfile.id]
        communityThreads[index].votes[currentProfile.id] = vote
        let previousUpvote = previousVote == .up ? 1 : 0
        let nextUpvote = vote == .up ? 1 : 0
        communityThreads[index].likeCount = max(0, communityThreads[index].likeCount + nextUpvote - previousUpvote)
    }

    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) {
        guard let index = communityThreadReplies.firstIndex(where: { $0.id == reply.id }),
              communityThreadReplies[index].removedAt == nil else { return }
        communityThreadReplies[index].votes[currentProfile.id] = vote
    }

    func reportCommunity(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) {
        let duplicate = communityReports.contains { report in
            report.targetType == targetType &&
            report.targetID == targetID &&
            report.reporterID == currentProfile.id &&
            report.status == "Open"
        }
        guard !duplicate else { return }
        communityReports.insert(
            CommunityReport(id: UUID(), targetType: targetType, targetID: targetID, reporterID: currentProfile.id, reason: reason, note: note, status: "Open", createdAt: .now),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Community report submitted", message: "Thanks. Moderators can now review it.", kind: "Community report", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .communityThread, targetID: targetID)), at: 0)
    }

    func moderateThread(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String? = nil) {
        guard isForumStaff(),
              let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        switch operation {
        case .lock:
            communityThreads[index].isLocked = true
        case .unlock:
            communityThreads[index].isLocked = false
        case .remove:
            communityThreads[index].removedAt = .now
            communityThreads[index].removalReason = reason ?? "Removed by a moderator."
        case .restore:
            communityThreads[index].removedAt = nil
            communityThreads[index].removalReason = nil
        case .warn:
            communityThreads[index].warning = reason ?? "Moderator warning"
        }
    }

    func resolveCommunityReport(_ report: CommunityReport) {
        guard isForumStaff(),
              let index = communityReports.firstIndex(where: { $0.id == report.id }) else { return }
        communityReports[index].status = "Resolved"
    }

    func toggleActivityLike(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isLiked.toggle()
    }

    func toggleActivitySave(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isSaved.toggle()
    }

    func addComment(to activity: ActivityItem, body: String) {
        activityComments.append(
            ActivityComment(
                id: UUID(),
                activityID: activity.id,
                authorID: currentProfile.id,
                authorName: currentProfile.displayName,
                body: body,
                createdAt: .now
            )
        )
    }

    func requestGym(_ request: GymRequest) {
        gymRequests.insert(request, at: 0)
        let demoGym = Gym(id: UUID(), name: request.name, city: request.city, state: request.state, memberCount: 1, verifiedLiftCount: 0)
        gyms.insert(demoGym, at: 0)
        communityThreads.insert(CommunityThread(id: UUID(), title: "\(request.name) members thread", body: "Use this thread for lift checks, meetups, and gym-specific questions.", authorID: currentProfile.id, authorName: currentProfile.displayName, kind: .gym, challengeID: nil, gymID: demoGym.id, replyCount: 0, likeCount: 0, createdAt: .now), at: 0)
        forumPosts.insert(ForumPost(
            id: UUID(), destination: .gym(demoGym.id), authorID: currentProfile.id,
            authorName: currentProfile.displayName, kind: .discussion,
            title: "Welcome to \(request.name)",
            body: "Use this gym discussion for lift checks, meetups, and equipment updates.",
            tag: nil, attachments: [], poll: nil, liftID: nil, workoutID: nil,
            linkURL: nil, challengeID: nil, createdAt: .now, editedAt: nil,
            commentCount: 0, votes: [:], savedByUserIDs: [], watchedByUserIDs: [],
            isPinned: true, isLocked: false, removedAt: nil, removalReason: nil
        ), at: 0)
        persistForumSnapshot()
        notifications.insert(NotificationItem(id: UUID(), title: "Gym request submitted", message: "\(request.name) is now available as a demo gym.", kind: "Gym request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .gym, targetID: demoGym.id, gymID: demoGym.id)), at: 0)
    }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool {
        guard !joinedGymIDs.contains(gym.id), joinedGymIDs.count < maximumMemberships else {
            return joinedGymIDs.contains(gym.id)
        }
        joinedGymIDs.insert(gym.id)
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount += 1
        }
        return true
    }

    func leaveGym(_ gym: Gym) {
        guard gym.id != currentProfile.primaryGymID, joinedGymIDs.remove(gym.id) != nil else { return }
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount = max(0, gyms[index].memberCount - 1)
        }
    }

    func setChallengeJoined(_ challenge: Challenge, joined: Bool) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        let wasJoined = challenges[index].isJoined
        guard wasJoined != joined else { return }
        challenges[index].isJoined = joined
        challenges[index].participantCount += joined ? 1 : -1
        challenges[index].participantCount = max(0, challenges[index].participantCount)
    }

    func sendFriendRequest(to profile: UserProfile) {
        guard profile.id != currentProfile.id else { return }
        if let index = friendRequests.firstIndex(where: { request in
            (request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
            (request.fromUserID == profile.id && request.toUserID == currentProfile.id)
        }) {
            if friendRequests[index].status == .declined {
                friendRequests[index].fromUserID = currentProfile.id
                friendRequests[index].toUserID = profile.id
                friendRequests[index].status = .pending
                friendRequests[index].createdAt = .now
                friendRequests[index].respondedAt = nil
            }
            return
        }
        friendRequests.insert(
            FriendRequest(id: UUID(), fromUserID: currentProfile.id, toUserID: profile.id, status: .pending, createdAt: .now, respondedAt: nil),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request sent", message: "Request sent to \(profile.displayName).", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func respondToFriendRequest(_ request: FriendRequest, status: FriendRequestStatus) {
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else { return }
        friendRequests[index].status = status
        friendRequests[index].respondedAt = .now
        let otherID = request.fromUserID == currentProfile.id ? request.toUserID : request.fromUserID
        let otherName = profiles.first { $0.id == otherID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: status == .accepted ? "Friend request accepted" : "Friend request declined", message: "\(otherName) was updated.", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        guard request.fromUserID == currentProfile.id, request.status == .pending else { return }
        friendRequests.removeAll { $0.id == request.id }
        let otherName = profiles.first { $0.id == request.toUserID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request canceled", message: "Request to \(otherName) was canceled.", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func messageThread(with profile: UserProfile) -> DirectMessageThread {
        let isFriend = friendRequests.contains { request in
            request.status == .accepted &&
            ((request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
             (request.fromUserID == profile.id && request.toUserID == currentProfile.id))
        }
        guard isFriend || profile.id == currentProfile.id else {
            return messageThreads.first ?? DirectMessageThread(id: UUID(), participantIDs: [currentProfile.id, profile.id], createdAt: .now, updatedAt: .now)
        }
        if let thread = messageThreads.first(where: { Set($0.participantIDs) == Set([currentProfile.id, profile.id]) }) {
            return thread
        }
        let thread = DirectMessageThread(id: UUID(), participantIDs: [currentProfile.id, profile.id], createdAt: .now, updatedAt: .now)
        messageThreads.insert(thread, at: 0)
        return thread
    }

    func addMessage(to thread: DirectMessageThread, body: String) {
        guard !body.isEmpty else { return }
        let message = DirectMessage(id: UUID(), threadID: thread.id, senderID: currentProfile.id, body: body, createdAt: .now, isRead: true, isReported: false)
        directMessages.append(message)
        if let index = messageThreads.firstIndex(where: { $0.id == thread.id }) {
            messageThreads[index].updatedAt = message.createdAt
        }
    }

    func deleteMessage(_ message: DirectMessage) {
        directMessages.removeAll { $0.id == message.id }
        messageReports.removeAll { $0.messageID == message.id }
        if let latest = directMessages
            .filter({ $0.threadID == message.threadID })
            .max(by: { $0.createdAt < $1.createdAt }),
           let index = messageThreads.firstIndex(where: { $0.id == message.threadID }) {
            messageThreads[index].updatedAt = latest.createdAt
        }
    }

    func deleteMessageThread(_ thread: DirectMessageThread) {
        let messageIDs = Set(directMessages.filter { $0.threadID == thread.id }.map(\.id))
        directMessages.removeAll { $0.threadID == thread.id }
        messageReports.removeAll { messageIDs.contains($0.messageID) }
        messageThreads.removeAll { $0.id == thread.id }
    }

    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        if let index = directMessages.firstIndex(where: { $0.id == message.id }) {
            directMessages[index].isReported = true
        }
        messageReports.insert(
            MessageReport(id: UUID(), messageID: message.id, reporterID: currentProfile.id, reason: reason, note: note, createdAt: .now),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Message reported", message: "Thanks. We flagged the message for review.", kind: "Message report", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .messageThread, targetID: message.threadID)), at: 0)
    }

    // MARK: - Multi-community forum

    func forumMembership(communityID: UUID, userID: UUID? = nil) -> ForumMembership? {
        let resolvedUserID = userID ?? currentProfile.id
        return forumMemberships.first { $0.communityID == communityID && $0.userID == resolvedUserID }
    }

    func isForumStaff(_ userID: UUID? = nil) -> Bool {
        forumGlobalStaffUserIDs.contains(userID ?? currentProfile.id)
    }

    func canReadForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        guard let community = forumCommunities.first(where: { $0.id == communityID }),
              community.archivedAt == nil else { return false }
        if isForumStaff(userID) || community.visibility == .publicOpen { return true }
        return forumMembership(communityID: communityID, userID: userID)?.isActive == true
    }

    func canContributeToForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        guard let community = forumCommunities.first(where: { $0.id == communityID }),
              community.archivedAt == nil else { return false }
        return forumMembership(communityID: communityID, userID: resolvedUserID)?.canContribute == true
    }

    func canModerateForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        if isForumStaff(resolvedUserID) { return true }
        guard let membership = forumMembership(communityID: communityID, userID: resolvedUserID),
              membership.isActive else { return false }
        return membership.role.authority >= ForumMemberRole.moderator.authority
    }

    func canAdministerForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        if isForumStaff(resolvedUserID) { return true }
        guard let membership = forumMembership(communityID: communityID, userID: resolvedUserID),
              membership.isActive else { return false }
        return membership.role.authority >= ForumMemberRole.admin.authority
    }

    func visibleForumCommunities(for userID: UUID? = nil) -> [ForumCommunity] {
        let resolvedUserID = userID ?? currentProfile.id
        return forumCommunities.filter { community in
            guard community.archivedAt == nil else { return isForumStaff(resolvedUserID) }
            guard community.visibility == .inviteOnly else { return true }
            return isForumStaff(resolvedUserID) || forumMembership(communityID: community.id, userID: resolvedUserID) != nil
        }
    }

    @discardableResult
    func joinForumCommunity(_ communityID: UUID, note: String = "") -> ForumMembershipStatus? {
        guard let communityIndex = forumCommunities.firstIndex(where: { $0.id == communityID }),
              forumCommunities[communityIndex].archivedAt == nil else { return nil }
        let userID = currentProfile.id
        let visibility = forumCommunities[communityIndex].visibility
        let existingIndex = forumMemberships.firstIndex { $0.communityID == communityID && $0.userID == userID }
        if let existingIndex, forumMemberships[existingIndex].status == .banned { return .banned }

        switch visibility {
        case .publicOpen:
            let wasActive = existingIndex.map { forumMemberships[$0].isActive } ?? false
            if let existingIndex {
                forumMemberships[existingIndex].status = .joined
                forumMemberships[existingIndex].joinedAt = forumMemberships[existingIndex].joinedAt ?? .now
                forumMemberships[existingIndex].mutedUntil = nil
            } else {
                forumMemberships.append(ForumMembership(
                    id: UUID(), communityID: communityID, userID: userID, role: .member,
                    status: .joined, notificationLevel: .mentions, joinedAt: .now,
                    mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
                ))
            }
            if !wasActive { forumCommunities[communityIndex].memberCount += 1 }
            persistForumSnapshot()
            return .joined

        case .restricted:
            if let existingIndex, forumMemberships[existingIndex].isActive { return forumMemberships[existingIndex].status }
            if let existingIndex {
                forumMemberships[existingIndex].status = .pending
            } else {
                forumMemberships.append(ForumMembership(
                    id: UUID(), communityID: communityID, userID: userID, role: .member,
                    status: .pending, notificationLevel: .mentions, joinedAt: nil,
                    mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
                ))
            }
            if !forumJoinRequests.contains(where: { $0.communityID == communityID && $0.userID == userID && $0.status == "Pending" }) {
                forumJoinRequests.insert(ForumJoinRequest(
                    id: UUID(), communityID: communityID, userID: userID, note: note,
                    status: "Pending", createdAt: .now, resolvedAt: nil, resolvedBy: nil
                ), at: 0)
            }
            persistForumSnapshot()
            return .pending

        case .inviteOnly:
            guard let existingIndex, forumMemberships[existingIndex].status == .invited else { return nil }
            forumMemberships[existingIndex].status = .joined
            forumMemberships[existingIndex].joinedAt = .now
            forumCommunities[communityIndex].memberCount += 1
            persistForumSnapshot()
            return .joined
        }
    }

    func leaveForumCommunity(_ communityID: UUID) {
        guard let membershipIndex = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == currentProfile.id && $0.isActive
        }) else { return }
        forumMemberships[membershipIndex].status = .left
        forumMemberships[membershipIndex].notificationLevel = .off
        if let communityIndex = forumCommunities.firstIndex(where: { $0.id == communityID }) {
            forumCommunities[communityIndex].memberCount = max(0, forumCommunities[communityIndex].memberCount - 1)
        }
        persistForumSnapshot()
    }

    func setForumNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID) {
        guard let index = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == currentProfile.id && $0.isActive
        }) else { return }
        forumMemberships[index].notificationLevel = level
        persistForumSnapshot()
    }

    @discardableResult
    func inviteForumMember(userID: UUID, communityID: UUID) -> Bool {
        guard canAdministerForumCommunity(communityID),
              !isForumStaff(userID),
              forumCommunities.contains(where: { $0.id == communityID && $0.archivedAt == nil }) else { return false }
        if let index = forumMemberships.firstIndex(where: { $0.communityID == communityID && $0.userID == userID }) {
            guard forumMemberships[index].status != .banned else { return false }
            forumMemberships[index].status = .invited
            forumMemberships[index].invitedBy = currentProfile.id
        } else {
            forumMemberships.append(ForumMembership(
                id: UUID(), communityID: communityID, userID: userID, role: .member,
                status: .invited, notificationLevel: .mentions, joinedAt: nil,
                mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: currentProfile.id
            ))
        }
        addForumNotification(
            userID: userID, kind: .membership, title: "Community invitation",
            message: "You were invited to join a private community.",
            communityID: communityID, postID: nil, commentID: nil
        )
        persistForumSnapshot()
        return true
    }

    func setForumMemberRole(userID: UUID, communityID: UUID, role: ForumMemberRole) {
        guard canAdministerForumCommunity(communityID),
              !isForumStaff(userID),
              role != .staff,
              let index = forumMemberships.firstIndex(where: {
                  $0.communityID == communityID && $0.userID == userID && $0.isActive
              }) else { return }
        if !isForumStaff(), role == .admin { return }
        forumMemberships[index].role = role
        persistForumSnapshot()
    }

    @discardableResult
    func createForumCommunity(_ community: ForumCommunity) -> Bool {
        guard isForumStaff(),
              !forumCommunities.contains(where: { $0.slug.caseInsensitiveCompare(community.slug) == .orderedSame }) else { return false }
        forumCommunities.append(community)
        forumMemberships.append(ForumMembership(
            id: UUID(), communityID: community.id, userID: currentProfile.id, role: .staff,
            status: .joined, notificationLevel: .all, joinedAt: .now,
            mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
        ))
        persistForumSnapshot()
        return true
    }

    func updateForumCommunity(_ community: ForumCommunity) {
        guard canAdministerForumCommunity(community.id),
              let index = forumCommunities.firstIndex(where: { $0.id == community.id }) else { return }
        forumCommunities[index] = community
        persistForumSnapshot()
    }

    func setForumCommunityArchived(_ communityID: UUID, archived: Bool) {
        guard isForumStaff(), let index = forumCommunities.firstIndex(where: { $0.id == communityID }) else { return }
        forumCommunities[index].archivedAt = archived ? .now : nil
        recordForumModerationAction(
            communityID: communityID, kind: .archive, targetID: communityID,
            reason: archived ? "Community archived" : "Community restored"
        )
        persistForumSnapshot()
    }

    @discardableResult
    func createForumPost(_ post: ForumPost) -> Bool {
        let titleCount = post.title.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard (5...140).contains(titleCount), post.body.count <= 10_000 else { return false }
        if post.attachments.count > 4 { return false }
        if post.attachments.contains(where: { $0.mediaType == .video }) && post.attachments.count > 1 { return false }
        if post.kind == .poll, !(2...6).contains(post.poll?.options.count ?? 0) { return false }
        if post.kind == .link {
            guard let url = post.linkURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        }
        if let communityID = post.destination.communityID {
            guard canContributeToForumCommunity(communityID) else { return false }
        } else if let gymID = post.destination.gymID {
            guard joinedGymIDs.contains(gymID) else { return false }
        }
        forumPosts.insert(post, at: 0)
        if let communityID = post.destination.communityID,
           let index = forumCommunities.firstIndex(where: { $0.id == communityID }) {
            forumCommunities[index].postCount += 1
        }
        createForumMentionNotifications(body: "\(post.title) \(post.body)", postID: post.id, commentID: nil, communityID: post.destination.communityID)
        persistForumSnapshot()
        return true
    }

    func updateForumPost(_ post: ForumPost) {
        guard let index = forumPosts.firstIndex(where: { $0.id == post.id }),
              forumPosts[index].authorID == currentProfile.id,
              forumPosts[index].removedAt == nil else { return }
        var updated = post
        updated.editedAt = .now
        forumPosts[index] = updated
        persistForumSnapshot()
    }

    func softDeleteForumPost(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              forumPosts[index].authorID == currentProfile.id || canModerateForumPost(forumPosts[index]) else { return }
        forumPosts[index].attachments.forEach { removeForumMedia(at: $0.localURL) }
        forumPosts[index].attachments = []
        forumPosts[index].body = ""
        forumPosts[index].removedAt = .now
        forumPosts[index].removalReason = "Deleted"
        persistForumSnapshot()
    }

    func voteForumPost(_ postID: UUID, vote: CommunityVote?) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              forumPosts[index].removedAt == nil,
              canContributeToForumPost(forumPosts[index]) else { return }
        forumPosts[index].votes[currentProfile.id] = vote
        persistForumSnapshot()
    }

    func toggleForumPostSaved(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[index]) else { return }
        if !forumPosts[index].savedByUserIDs.insert(currentProfile.id).inserted {
            forumPosts[index].savedByUserIDs.remove(currentProfile.id)
        }
        persistForumSnapshot()
    }

    func toggleForumPostWatched(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[index]) else { return }
        if !forumPosts[index].watchedByUserIDs.insert(currentProfile.id).inserted {
            forumPosts[index].watchedByUserIDs.remove(currentProfile.id)
        }
        persistForumSnapshot()
    }

    func voteInForumPoll(postID: UUID, optionID: UUID) {
        guard let postIndex = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[postIndex]),
              var poll = forumPosts[postIndex].poll,
              !poll.isClosed,
              poll.options.contains(where: { $0.id == optionID }) else { return }
        for index in poll.options.indices {
            poll.options[index].voterIDs.remove(currentProfile.id)
            if poll.options[index].id == optionID { poll.options[index].voterIDs.insert(currentProfile.id) }
        }
        forumPosts[postIndex].poll = poll
        persistForumSnapshot()
    }

    @discardableResult
    func addForumComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 10_000,
              let postIndex = forumPosts.firstIndex(where: { $0.id == postID }),
              !forumPosts[postIndex].isLocked,
              forumPosts[postIndex].removedAt == nil,
              canContributeToForumPost(forumPosts[postIndex]) else { return nil }

        var resolvedParentID = parentCommentID
        var resolvedBody = trimmed
        var selectedParent: ForumComment?
        if let parentCommentID, let parent = forumComments.first(where: { $0.id == parentCommentID }) {
            selectedParent = parent
            if let rootID = parent.parentCommentID {
                resolvedParentID = rootID
                if !resolvedBody.lowercased().hasPrefix("@\(parent.authorName.lowercased())") {
                    resolvedBody = "@\(parent.authorName) \(resolvedBody)"
                }
            }
        }

        let comment = ForumComment(
            id: UUID(), postID: postID, parentCommentID: resolvedParentID,
            authorID: currentProfile.id, authorName: currentProfile.displayName,
            body: resolvedBody, createdAt: .now, editedAt: nil,
            votes: [:], removedAt: nil, removalReason: nil
        )
        forumComments.append(comment)
        forumPosts[postIndex].commentCount += 1

        if let selectedParent, selectedParent.authorID != currentProfile.id {
            addForumNotification(
                userID: selectedParent.authorID, kind: .reply,
                title: "New reply", message: "\(currentProfile.displayName) replied to your comment.",
                communityID: forumPosts[postIndex].destination.communityID,
                postID: postID, commentID: comment.id
            )
        } else if forumPosts[postIndex].authorID != currentProfile.id {
            addForumNotification(
                userID: forumPosts[postIndex].authorID, kind: .reply,
                title: "New comment", message: "\(currentProfile.displayName) commented on your post.",
                communityID: forumPosts[postIndex].destination.communityID,
                postID: postID, commentID: comment.id
            )
        }
        if resolvedParentID == nil {
            notifyForumWatchers(for: forumPosts[postIndex], comment: comment)
        }
        createForumMentionNotifications(body: resolvedBody, postID: postID, commentID: comment.id, communityID: forumPosts[postIndex].destination.communityID)
        persistForumSnapshot()
        return comment
    }

    func updateForumComment(_ comment: ForumComment, body: String) {
        guard let index = forumComments.firstIndex(where: { $0.id == comment.id }),
              forumComments[index].authorID == currentProfile.id,
              forumComments[index].removedAt == nil else { return }
        forumComments[index].body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        forumComments[index].editedAt = .now
        persistForumSnapshot()
    }

    func softDeleteForumComment(_ commentID: UUID) {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              forumComments[index].authorID == currentProfile.id || canModerateForumComment(forumComments[index]) else { return }
        forumComments[index].body = ""
        forumComments[index].removedAt = .now
        forumComments[index].removalReason = "Deleted"
        persistForumSnapshot()
    }

    func voteForumComment(_ commentID: UUID, vote: CommunityVote?) {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              forumComments[index].removedAt == nil,
              let post = forumPosts.first(where: { $0.id == forumComments[index].postID }),
              canContributeToForumPost(post) else { return }
        forumComments[index].votes[currentProfile.id] = vote
        persistForumSnapshot()
    }

    @discardableResult
    func reportForumContent(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String
    ) -> Bool {
        let duplicate = forumReports.contains {
            $0.targetType == targetType && $0.targetID == targetID &&
            $0.reporterID == currentProfile.id && $0.status == .open
        }
        guard !duplicate else { return false }
        forumReports.insert(ForumReport(
            id: UUID(), communityID: communityID, targetType: targetType, targetID: targetID,
            reporterID: currentProfile.id, reason: reason, note: note,
            status: .open, createdAt: .now, resolvedAt: nil, resolvedBy: nil
        ), at: 0)
        persistForumSnapshot()
        return true
    }

    func resolveForumJoinRequest(_ requestID: UUID, approved: Bool) {
        guard let requestIndex = forumJoinRequests.firstIndex(where: { $0.id == requestID }),
              canAdministerForumCommunity(forumJoinRequests[requestIndex].communityID) else { return }
        let request = forumJoinRequests[requestIndex]
        forumJoinRequests[requestIndex].status = approved ? "Approved" : "Declined"
        forumJoinRequests[requestIndex].resolvedAt = .now
        forumJoinRequests[requestIndex].resolvedBy = currentProfile.id
        if let membershipIndex = forumMemberships.firstIndex(where: {
            $0.communityID == request.communityID && $0.userID == request.userID
        }) {
            forumMemberships[membershipIndex].status = approved ? .joined : .declined
            forumMemberships[membershipIndex].joinedAt = approved ? .now : nil
        }
        if approved, let communityIndex = forumCommunities.firstIndex(where: { $0.id == request.communityID }) {
            forumCommunities[communityIndex].memberCount += 1
        }
        addForumNotification(
            userID: request.userID, kind: .membership,
            title: approved ? "Membership approved" : "Membership declined",
            message: approved ? "You can now participate in the community." : "Your membership request was declined.",
            communityID: request.communityID, postID: nil, commentID: nil
        )
        recordForumModerationAction(
            communityID: request.communityID, kind: approved ? .approve : .decline,
            targetID: request.userID, reason: approved ? "Membership approved" : "Membership declined"
        )
        persistForumSnapshot()
    }

    func resolveForumReport(_ reportID: UUID, dismiss: Bool) {
        guard let index = forumReports.firstIndex(where: { $0.id == reportID }),
              forumReports[index].communityID.map({ canModerateForumCommunity($0) }) ?? isForumStaff() else { return }
        forumReports[index].status = dismiss ? .dismissed : .resolved
        forumReports[index].resolvedAt = .now
        forumReports[index].resolvedBy = currentProfile.id
        persistForumSnapshot()
    }

    func moderateForumPost(_ postID: UUID, action: ForumModerationActionKind, reason: String = "") {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canModerateForumPost(forumPosts[index]) else { return }
        switch action {
        case .pin: forumPosts[index].isPinned = true
        case .unpin: forumPosts[index].isPinned = false
        case .lock: forumPosts[index].isLocked = true
        case .unlock: forumPosts[index].isLocked = false
        case .remove:
            forumPosts[index].removedAt = .now
            forumPosts[index].removalReason = reason.isEmpty ? "Removed by a moderator" : reason
        case .restore:
            forumPosts[index].removedAt = nil
            forumPosts[index].removalReason = nil
        case .warn:
            addForumNotification(
                userID: forumPosts[index].authorID, kind: .moderation,
                title: "Moderator warning", message: reason.isEmpty ? "A moderator reviewed your post." : reason,
                communityID: forumPosts[index].destination.communityID, postID: postID, commentID: nil
            )
        default: return
        }
        recordForumModerationAction(
            communityID: forumPosts[index].destination.communityID,
            kind: action, targetID: postID, reason: reason
        )
        persistForumSnapshot()
    }

    func moderateForumComment(_ commentID: UUID, action: ForumModerationActionKind, reason: String = "") {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              canModerateForumComment(forumComments[index]),
              let post = forumPosts.first(where: { $0.id == forumComments[index].postID }) else { return }
        switch action {
        case .remove:
            forumComments[index].removedAt = .now
            forumComments[index].removalReason = reason.isEmpty ? "Removed by a moderator" : reason
        case .restore:
            forumComments[index].removedAt = nil
            forumComments[index].removalReason = nil
        case .warn:
            addForumNotification(
                userID: forumComments[index].authorID, kind: .moderation,
                title: "Moderator warning", message: reason.isEmpty ? "A moderator reviewed your comment." : reason,
                communityID: post.destination.communityID, postID: post.id, commentID: commentID
            )
        default: return
        }
        recordForumModerationAction(
            communityID: post.destination.communityID, kind: action,
            targetID: commentID, reason: reason
        )
        persistForumSnapshot()
    }

    func moderateForumMember(
        userID: UUID,
        communityID: UUID,
        action: ForumModerationActionKind,
        reason: String,
        mutedUntil: Date? = nil
    ) {
        guard let targetIndex = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == userID
        }), canRestrictForumMembership(forumMemberships[targetIndex], communityID: communityID) else { return }
        switch action {
        case .warn:
            break
        case .mute:
            forumMemberships[targetIndex].status = .muted
            forumMemberships[targetIndex].mutedUntil = mutedUntil ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)
            forumMemberships[targetIndex].restrictionReason = reason
        case .ban:
            forumMemberships[targetIndex].status = .banned
            forumMemberships[targetIndex].bannedAt = .now
            forumMemberships[targetIndex].restrictionReason = reason
        default: return
        }
        addForumNotification(
            userID: userID, kind: .moderation, title: action.rawValue,
            message: reason.isEmpty ? "A moderator updated your community access." : reason,
            communityID: communityID, postID: nil, commentID: nil
        )
        recordForumModerationAction(communityID: communityID, kind: action, targetID: userID, reason: reason)
        persistForumSnapshot()
    }

    func markForumNotificationRead(_ notificationID: UUID) {
        guard let index = forumNotifications.firstIndex(where: { $0.id == notificationID }) else { return }
        forumNotifications[index].isRead = true
        persistForumSnapshot()
    }

    private func canContributeToForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canContributeToForumCommunity(communityID) }
        if let gymID = post.destination.gymID { return joinedGymIDs.contains(gymID) }
        return false
    }

    private func canModerateForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canModerateForumCommunity(communityID) }
        return isForumStaff()
    }

    private func canModerateForumComment(_ comment: ForumComment) -> Bool {
        guard let post = forumPosts.first(where: { $0.id == comment.postID }) else { return false }
        return canModerateForumPost(post)
    }

    private func canRestrictForumMembership(_ target: ForumMembership, communityID: UUID) -> Bool {
        guard canModerateForumCommunity(communityID), !isForumStaff(target.userID) else { return false }
        let actorAuthority = isForumStaff() ? ForumMemberRole.staff.authority :
            (forumMembership(communityID: communityID)?.role.authority ?? -1)
        return actorAuthority > target.role.authority
    }

    private func recordForumModerationAction(
        communityID: UUID?,
        kind: ForumModerationActionKind,
        targetID: UUID,
        reason: String
    ) {
        forumModerationActions.insert(ForumModerationAction(
            id: UUID(), communityID: communityID, moderatorID: currentProfile.id,
            kind: kind, targetID: targetID, reason: reason, createdAt: .now
        ), at: 0)
    }

    private func addForumNotification(
        userID: UUID,
        kind: ForumNotificationKind,
        title: String,
        message: String,
        communityID: UUID?,
        postID: UUID?,
        commentID: UUID?
    ) {
        guard userID != currentProfile.id else { return }
        forumNotifications.insert(ForumNotification(
            id: UUID(), userID: userID, actorID: currentProfile.id, kind: kind,
            title: title, message: message, communityID: communityID,
            postID: postID, commentID: commentID, createdAt: .now, isRead: false
        ), at: 0)
    }

    private func createForumMentionNotifications(body: String, postID: UUID, commentID: UUID?, communityID: UUID?) {
        let pattern = "@([A-Za-z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        let usernames = Set(regex.matches(in: body, range: range).compactMap { result -> String? in
            guard let usernameRange = Range(result.range(at: 1), in: body) else { return nil }
            return String(body[usernameRange]).lowercased()
        })
        for profile in profiles where usernames.contains(profile.username.lowercased()) {
            addForumNotification(
                userID: profile.id, kind: .mention, title: "You were mentioned",
                message: "\(currentProfile.displayName) mentioned you in the forum.",
                communityID: communityID, postID: postID, commentID: commentID
            )
        }
    }

    private func notifyForumWatchers(for post: ForumPost, comment: ForumComment) {
        for userID in post.watchedByUserIDs where userID != currentProfile.id {
            if let communityID = post.destination.communityID,
               forumMembership(communityID: communityID, userID: userID)?.notificationLevel == .off { continue }
            addForumNotification(
                userID: userID, kind: .watchedPost, title: "Watched post updated",
                message: "\(comment.authorName) added a new comment.",
                communityID: post.destination.communityID, postID: post.id, commentID: comment.id
            )
        }
    }
}

enum CommunityModerationOperation {
    case lock
    case unlock
    case remove
    case restore
    case warn
}
