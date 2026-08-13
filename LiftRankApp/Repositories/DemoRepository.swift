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
    @Published var lifts: [LiftSubmission] { didSet { liftsRevision &+= 1 } }
    @Published var challenges: [Challenge]
    @Published var achievements: [Achievement]
    @Published var notifications: [NotificationItem] { didSet { notificationsRevision &+= 1 } }
    @Published var workoutPlans: [WorkoutPlan]
    @Published var workoutPhases: [WorkoutPhase]
    @Published var workoutWeeks: [WorkoutWeek]
    @Published var workoutSessions: [WorkoutSession]
    @Published var workoutPrescriptions: [WorkoutExercisePrescription]
    @Published var workoutSetLogs: [WorkoutSetLog] { didSet { workoutSetLogsRevision &+= 1 } }
    @Published var workoutFeedback: [WorkoutFeedback]
    @Published var customTrainingExercises: [TrainingExerciseCatalogItem]
    @Published var workoutEntries: [WorkoutExerciseEntry]
    @Published var bodyweightEntries: [BodyweightEntry]
    @Published var strainEntries: [StrainEntry]
    @Published var injuryEntries: [InjuryEntry]
    @Published var activeWorkout: ActiveWorkoutState?
    @Published var completedWorkouts: [CompletedWorkout] { didSet { completedWorkoutsRevision &+= 1 } }
    @Published var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission]
    @Published var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot]
    @Published var deletedCompletedWorkoutIDs: Set<UUID>
    @Published var workoutPlanSyncRevisions: [UUID: Int]
    @Published var workoutPlanLastSyncedPayloads: [UUID: Data]
    @Published var pendingRemoteWorkoutPlanDeletions: Set<UUID>
    @Published var workoutPreferences: WorkoutPreferences
    @Published var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings]
    @Published var gymRequests: [GymRequest]
    @Published var achievementUnlocks: [AchievementUnlock]
    @Published var rankingHistory: [RankingHistorySnapshot]
    private let workoutPersistenceStore: WorkoutPersistenceStore
    private var persistenceCancellables = Set<AnyCancellable>()
    private var pendingPersistenceTask: Task<Void, Never>?
    private var isRestoringWorkoutSnapshot = false
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }
    }
    private(set) var liftsRevision = 0
    private(set) var workoutSetLogsRevision = 0
    private(set) var notificationsRevision = 0
    private(set) var completedWorkoutsRevision = 0

    init(
        workoutPersistenceStore: WorkoutPersistenceStore? = nil
    ) {
        self.workoutPersistenceStore = workoutPersistenceStore ?? InMemoryWorkoutPersistenceStore()
        currentProfile = MockData.emptyProfile
        profiles = []
        gyms = []
        joinedGymIDs = []
        lifts = []
        challenges = []
        achievements = MockData.achievements
        workoutPlans = []
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = []
        bodyweightEntries = []
        strainEntries = []
        injuryEntries = []
        activeWorkout = nil
        completedWorkouts = []
        pendingWorkoutPRSubmissions = []
        pendingCompletedWorkoutUploads = []
        deletedCompletedWorkoutIDs = []
        workoutPlanSyncRevisions = [:]
        workoutPlanLastSyncedPayloads = [:]
        pendingRemoteWorkoutPlanDeletions = []
        workoutPreferences = WorkoutPreferences()
        workoutPlanProgressionSettings = []
        gymRequests = []
        achievementUnlocks = []
        rankingHistory = []
        notifications = []
        rebuildProgramBuilderDataFromEntries()
        restoreWorkoutSnapshotOrImportLegacy()
        bindWorkoutPersistence()
        persistWorkoutSnapshot()
    }

    func reset() {
        currentProfile = MockData.emptyProfile
        profiles = []
        gyms = []
        joinedGymIDs = []
        lifts = []
        challenges = []
        achievements = MockData.achievements
        workoutPlans = []
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = []
        bodyweightEntries = []
        strainEntries = []
        injuryEntries = []
        activeWorkout = nil
        completedWorkouts = []
        pendingWorkoutPRSubmissions = []
        pendingCompletedWorkoutUploads = []
        deletedCompletedWorkoutIDs = []
        workoutPlanSyncRevisions = [:]
        workoutPlanLastSyncedPayloads = [:]
        pendingRemoteWorkoutPlanDeletions = []
        workoutPreferences = WorkoutPreferences()
        workoutPlanProgressionSettings = []
        gymRequests = []
        achievementUnlocks = []
        rankingHistory = []
        rebuildProgramBuilderDataFromEntries()
        workoutPersistenceStore.reset()
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
    }

    func clearLocalUserData() {
        currentProfile = MockData.emptyProfile
        profiles.removeAll()
        gyms.removeAll()
        joinedGymIDs.removeAll()
        lifts.removeAll()
        challenges.removeAll()
        notifications.removeAll()
        activeWorkout = nil
        completedWorkouts.removeAll()
        pendingWorkoutPRSubmissions.removeAll()
        pendingCompletedWorkoutUploads.removeAll()
        deletedCompletedWorkoutIDs.removeAll()
        workoutPlanSyncRevisions.removeAll()
        workoutPlanLastSyncedPayloads.removeAll()
        pendingRemoteWorkoutPlanDeletions.removeAll()
        workoutPlans.removeAll()
        workoutPhases.removeAll()
        workoutWeeks.removeAll()
        workoutSessions.removeAll()
        workoutPrescriptions.removeAll()
        workoutSetLogs.removeAll()
        workoutFeedback.removeAll()
        workoutEntries.removeAll()
        bodyweightEntries.removeAll()
        strainEntries.removeAll()
        injuryEntries.removeAll()
        workoutPlanProgressionSettings.removeAll()
        customTrainingExercises.removeAll()
        gymRequests.removeAll()
        achievementUnlocks.removeAll()
        rankingHistory.removeAll()
        workoutPreferences = WorkoutPreferences()
        workoutPersistenceStore.reset()
    }

    private func bindWorkoutPersistence() {
        let publishers: [AnyPublisher<Void, Never>] = [
            $currentProfile.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $profiles.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $gyms.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $joinedGymIDs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
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
            $deletedCompletedWorkoutIDs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanSyncRevisions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanLastSyncedPayloads.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pendingRemoteWorkoutPlanDeletions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPreferences.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $workoutPlanProgressionSettings.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $achievementUnlocks.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $rankingHistory.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] in self?.scheduleWorkoutSnapshotPersistence() }
            .store(in: &persistenceCancellables)
    }

    private func scheduleWorkoutSnapshotPersistence() {
        guard !isRestoringWorkoutSnapshot, !isUITesting else { return }
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.pendingPersistenceTask = nil
                self?.persistWorkoutSnapshot()
            }
        }
    }

    func persistWorkoutSnapshot() {
        guard !isRestoringWorkoutSnapshot, !isUITesting else { return }
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = nil
        workoutPersistenceStore.saveSnapshot(
            WorkoutPersistenceSnapshot(
                schemaVersion: WorkoutPersistenceSnapshot.currentVersion,
                currentProfile: currentProfile,
                profiles: profiles,
                gyms: gyms,
                gymRequests: gymRequests,
                joinedGymIDs: joinedGymIDs,
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
                deletedCompletedWorkoutIDs: deletedCompletedWorkoutIDs,
                workoutPlanSyncRevisions: workoutPlanSyncRevisions,
                workoutPlanLastSyncedPayloads: workoutPlanLastSyncedPayloads,
                pendingRemoteWorkoutPlanDeletions: pendingRemoteWorkoutPlanDeletions
            )
        )
    }

    private func restoreWorkoutSnapshotOrImportLegacy() {
        if let snapshot = workoutPersistenceStore.loadSnapshot() {
            isRestoringWorkoutSnapshot = true
            if let restoredProfile = snapshot.currentProfile {
                currentProfile = restoredProfile
            }
            if let restoredProfiles = snapshot.profiles, !restoredProfiles.isEmpty {
                profiles = restoredProfiles
            }
            if let restoredGyms = snapshot.gyms {
                gyms = restoredGyms
            }
            if let restoredJoinedGymIDs = snapshot.joinedGymIDs {
                joinedGymIDs = restoredJoinedGymIDs
            }
            gymRequests = snapshot.gymRequests ?? []
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
            strainEntries = snapshot.strainEntries ?? []
            injuryEntries = snapshot.injuryEntries ?? []
            activeWorkout = snapshot.activeWorkout
            completedWorkouts = snapshot.completedWorkouts
            pendingWorkoutPRSubmissions = snapshot.pendingPRSubmissions
            pendingCompletedWorkoutUploads = snapshot.pendingCompletedWorkoutUploads ?? []
            deletedCompletedWorkoutIDs = snapshot.deletedCompletedWorkoutIDs ?? []
            workoutPlanSyncRevisions = snapshot.workoutPlanSyncRevisions ?? [:]
            workoutPlanLastSyncedPayloads = snapshot.workoutPlanLastSyncedPayloads ?? [:]
            pendingRemoteWorkoutPlanDeletions = snapshot.pendingRemoteWorkoutPlanDeletions ?? []
            workoutPreferences = snapshot.preferences
            workoutPlanProgressionSettings = snapshot.planProgressionSettings ?? []
            achievementUnlocks = snapshot.achievementUnlocks ?? []
            rankingHistory = snapshot.rankingHistory ?? []
            migrateSeededWorkoutData(from: snapshot.schemaVersion)
            isRestoringWorkoutSnapshot = false
            return
        }

        completedWorkouts = []
        workoutEntries = []
        bodyweightEntries = []
        workoutPersistenceStore.reset()
        persistWorkoutSnapshot()
    }

    private func migrateSeededWorkoutData(from schemaVersion: Int) {
        let markerWorkoutIDs = Set(completedWorkouts.filter {
            $0.notes.contains(Self.personalWorkoutDemoMarker)
        }.map(\.id))
        completedWorkouts.removeAll { markerWorkoutIDs.contains($0.id) }
        workoutSetLogs.removeAll { log in
            log.workoutID.map(markerWorkoutIDs.contains) == true
        }
        bodyweightEntries.removeAll { $0.notes.contains(Self.personalWorkoutDemoMarker) }
        pendingCompletedWorkoutUploads.removeAll { snapshot in
            markerWorkoutIDs.contains(snapshot.id) ||
                String(data: snapshot.payload, encoding: .utf8)?.contains(Self.personalWorkoutDemoMarker) == true
        }

        guard schemaVersion < WorkoutPersistenceSnapshot.seedCleanupVersion else { return }

        var untouchedSeedPlanIDs = Set<UUID>()
        if isUntouchedDefaultWorkoutPlanSeed() {
            untouchedSeedPlanIDs.insert(MockData.defaultWorkoutPlanID)
        }
        if isUntouchedPersonalWorkoutPlanSeed() {
            untouchedSeedPlanIDs.insert(PersonalWorkoutPlanCatalog.planID)
        }
        removeWorkoutPlanGraphs(planIDs: untouchedSeedPlanIDs)
    }

    private func isUntouchedDefaultWorkoutPlanSeed() -> Bool {
        let planID = MockData.defaultWorkoutPlanID
        guard let plan = workoutPlans.first(where: { $0.id == planID }),
              plan.name == "Strength Foundations",
              plan.goal == "Build strength and muscle.",
              plan.notes.isEmpty,
              plan.isActive,
              workoutPlans.filter({ $0.id == planID }).count == 1,
              workoutEntries.allSatisfy({ $0.planID != planID }),
              completedWorkouts.allSatisfy({ $0.sourcePlanID != planID }),
              activeWorkout?.sourcePlanID != planID,
              workoutPlanProgressionSettings.allSatisfy({ $0.planID != planID }) else { return false }

        let phases = workoutPhases.filter { $0.planID == planID }
        guard phases.count == 1, let phase = phases.first,
              phase.name == "Base Phase", phase.order == 0,
              phase.goal == "Build strength and muscle.", phase.durationWeeks == 1 else { return false }
        let weeks = workoutWeeks.filter { $0.planID == planID }
        guard weeks.count == 1, let week = weeks.first,
              week.phaseID == phase.id, week.weekNumber == 1,
              week.title == "Week 1", week.notes.isEmpty else { return false }
        let sessions = workoutSessions.filter { $0.weekID == week.id }
        guard sessions.count == 1, let session = sessions.first,
              session.day == "Monday", session.name == "Strength Session",
              session.order == 0, session.notes.isEmpty,
              workoutFeedback.allSatisfy({ $0.sessionID != session.id }),
              activeWorkout?.sourceSessionID != session.id else { return false }
        let prescriptions = workoutPrescriptions.filter { $0.sessionID == session.id }
        guard prescriptions.count == 1, let prescription = prescriptions.first,
              let exercise = MockData.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }) else { return false }
        let expectedPrescription = WorkoutExercisePrescription(
            id: prescription.id,
            sessionID: session.id,
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            bodyPart: exercise.bodyPart,
            equipment: exercise.equipment,
            sets: 3,
            reps: "6-8",
            restSeconds: 120,
            order: 0,
            notes: "",
            muscleProfile: exercise.resolvedMuscleProfile
        )
        guard prescription == expectedPrescription else { return false }
        let logs = workoutSetLogs.filter { $0.prescriptionID == prescription.id }
        guard logs.count == 1, let log = logs.first else { return false }
        return log.workoutID == nil && log.setNumber == 1 && log.weight == 135 &&
            log.reps == 8 && log.rpe == 7 && !log.isWarmup && log.isComplete &&
            log.recordedUnit == .pounds && log.completionSource == nil &&
            !log.hasTriggeredRestTimer && !log.suppressAutoCompletion
    }

    private func isUntouchedPersonalWorkoutPlanSeed() -> Bool {
        let planID = PersonalWorkoutPlanCatalog.planID
        guard let plan = workoutPlans.first(where: { $0.id == planID }),
              workoutPlans.filter({ $0.id == planID }).count == 1 else { return false }
        let expected = PersonalWorkoutPlanCatalog.makeSeed(createdAt: plan.createdAt)
        guard plan == expected.plan,
              workoutEntries.allSatisfy({ $0.planID != planID }),
              completedWorkouts.allSatisfy({ $0.sourcePlanID != planID }),
              activeWorkout?.sourcePlanID != planID else { return false }

        let actualPhases = workoutPhases.filter { $0.planID == planID }.sorted { $0.order < $1.order }
        guard actualPhases.count == expected.phases.count else { return false }
        var phaseIDs: [UUID: UUID] = [:]
        for (actual, expectedPhase) in zip(actualPhases, expected.phases) {
            var normalized = actual
            normalized.id = expectedPhase.id
            guard normalized == expectedPhase else { return false }
            phaseIDs[actual.id] = expectedPhase.id
        }

        let actualWeeks = workoutWeeks.filter { $0.planID == planID }.sorted { $0.weekNumber < $1.weekNumber }
        guard actualWeeks.count == expected.weeks.count else { return false }
        var weekIDs: [UUID: UUID] = [:]
        for (actual, expectedWeek) in zip(actualWeeks, expected.weeks) {
            var normalized = actual
            normalized.id = expectedWeek.id
            normalized.phaseID = phaseIDs[actual.phaseID] ?? actual.phaseID
            guard normalized == expectedWeek else { return false }
            weekIDs[actual.id] = expectedWeek.id
        }

        let weekNumberByID = Dictionary(uniqueKeysWithValues: actualWeeks.map { ($0.id, $0.weekNumber) })
        let actualSessions = workoutSessions.filter { weekIDs[$0.weekID] != nil }.sorted {
            (weekNumberByID[$0.weekID] ?? 0, $0.order) < (weekNumberByID[$1.weekID] ?? 0, $1.order)
        }
        guard actualSessions.count == expected.sessions.count else { return false }
        var sessionIDs: [UUID: UUID] = [:]
        for (actual, expectedSession) in zip(actualSessions, expected.sessions) {
            var normalized = actual
            normalized.id = expectedSession.id
            normalized.weekID = weekIDs[actual.weekID] ?? actual.weekID
            guard normalized == expectedSession else { return false }
            sessionIDs[actual.id] = expectedSession.id
        }

        let sessionOrderByID = Dictionary(uniqueKeysWithValues: actualSessions.enumerated().map { ($0.element.id, $0.offset) })
        let actualPrescriptions = workoutPrescriptions.filter { sessionIDs[$0.sessionID] != nil }.sorted {
            (sessionOrderByID[$0.sessionID] ?? 0, $0.order) < (sessionOrderByID[$1.sessionID] ?? 0, $1.order)
        }
        guard actualPrescriptions.count == expected.prescriptions.count else { return false }
        for (actual, expectedPrescription) in zip(actualPrescriptions, expected.prescriptions) {
            var normalized = actual
            normalized.id = expectedPrescription.id
            normalized.sessionID = sessionIDs[actual.sessionID] ?? actual.sessionID
            guard normalized == expectedPrescription else { return false }
        }

        let sessionIDSet = Set(actualSessions.map(\.id))
        let prescriptionIDSet = Set(actualPrescriptions.map(\.id))
        return workoutSetLogs.allSatisfy { !prescriptionIDSet.contains($0.prescriptionID) } &&
            workoutFeedback.allSatisfy { !sessionIDSet.contains($0.sessionID) } &&
            activeWorkout.map { !sessionIDSet.contains($0.sourceSessionID ?? UUID()) } != false &&
            workoutPlanProgressionSettings.allSatisfy {
                $0.planID != planID || $0.sourceTemplateID == "private_bts_beginner_12"
            }
    }

    private func removeWorkoutPlanGraphs(planIDs: Set<UUID>) {
        guard !planIDs.isEmpty else { return }
        let weekIDs = Set(workoutWeeks.filter { planIDs.contains($0.planID) }.map(\.id))
        let sessionIDs = Set(workoutSessions.filter { weekIDs.contains($0.weekID) }.map(\.id))
        let prescriptionIDs = Set(workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }.map(\.id))
        let workoutIDs = Set(completedWorkouts.filter {
            $0.sourcePlanID.map(planIDs.contains) == true ||
                $0.sourceSessionID.map(sessionIDs.contains) == true
        }.map(\.id))

        completedWorkouts.removeAll { workoutIDs.contains($0.id) }
        workoutSetLogs.removeAll {
            prescriptionIDs.contains($0.prescriptionID) || $0.workoutID.map(workoutIDs.contains) == true
        }
        workoutFeedback.removeAll { sessionIDs.contains($0.sessionID) }
        workoutPlanProgressionSettings.removeAll { planIDs.contains($0.planID) }
        workoutPrescriptions.removeAll { sessionIDs.contains($0.sessionID) }
        workoutSessions.removeAll { sessionIDs.contains($0.id) }
        workoutWeeks.removeAll { weekIDs.contains($0.id) }
        workoutPhases.removeAll { planIDs.contains($0.planID) }
        workoutPlans.removeAll { planIDs.contains($0.id) }
        workoutEntries.removeAll { planIDs.contains($0.planID) }
        pendingCompletedWorkoutUploads.removeAll { workoutIDs.contains($0.id) }
        planIDs.forEach {
            workoutPlanSyncRevisions.removeValue(forKey: $0)
            workoutPlanLastSyncedPayloads.removeValue(forKey: $0)
            pendingRemoteWorkoutPlanDeletions.remove($0)
        }
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
