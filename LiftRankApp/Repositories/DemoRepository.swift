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
    @Published var notifications: [NotificationItem]
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
    @Published var completedWorkouts: [CompletedWorkout]
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
    private let seedDemoData: Bool
    private(set) var liftsRevision = 0
    private(set) var workoutSetLogsRevision = 0

    init(
        workoutPersistenceStore: WorkoutPersistenceStore? = nil,
        seedDemoData: Bool = true
    ) {
        self.seedDemoData = seedDemoData
        self.workoutPersistenceStore = workoutPersistenceStore ?? InMemoryWorkoutPersistenceStore()
        let seeded = MockData.seededCompetitionData()
        currentProfile = MockData.emptyProfile
        profiles = seedDemoData ? seeded.profiles : []
        gyms = []
        joinedGymIDs = []
        lifts = seedDemoData ? seeded.lifts : []
        challenges = seedDemoData ? MockData.challenges : []
        achievements = MockData.achievements
        workoutPlans = seedDemoData ? MockData.workoutPlans : []
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = seedDemoData ? MockData.workoutEntries : []
        bodyweightEntries = seedDemoData ? MockData.bodyweightEntries : []
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
        ensureDefaultWorkoutPlan()
        refreshAchievementUnlocks()
        bindWorkoutPersistence()
        persistWorkoutSnapshot()
    }

    func reset() {
        let seeded = MockData.seededCompetitionData()
        currentProfile = MockData.emptyProfile
        profiles = seedDemoData ? seeded.profiles : []
        gyms = []
        joinedGymIDs = []
        lifts = seedDemoData ? seeded.lifts : []
        challenges = seedDemoData ? MockData.challenges : []
        achievements = MockData.achievements
        workoutPlans = seedDemoData ? MockData.workoutPlans : []
        workoutPhases = []
        workoutWeeks = []
        workoutSessions = []
        workoutPrescriptions = []
        workoutSetLogs = []
        workoutFeedback = []
        customTrainingExercises = []
        workoutEntries = seedDemoData ? MockData.workoutEntries : []
        bodyweightEntries = seedDemoData ? MockData.bodyweightEntries : []
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
        ensureDefaultWorkoutPlan()
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
        guard !isRestoringWorkoutSnapshot else { return }
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
        guard !isRestoringWorkoutSnapshot else { return }
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
        let bundledPlanIDs = Set(MockData.workoutPlans.map(\.id)).union([PersonalWorkoutPlanCatalog.planID])
        let seededPlanIDs = Set(workoutPlans.filter { plan in
            bundledPlanIDs.contains(plan.id) ||
                plan.name.localizedCaseInsensitiveContains("Robert") ||
                plan.name.localizedCaseInsensitiveContains("Hypertrophy")
        }.map(\.id))
        let seededWorkoutIDs = Set(completedWorkouts.filter { workout in
            workout.notes.contains(Self.personalWorkoutDemoMarker) ||
                workout.sourcePlanID.map { planID in seededPlanIDs.contains(planID) || bundledPlanIDs.contains(planID) } == true ||
                workout.notes == "Imported from previous workout history."
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

    private func ensureDefaultWorkoutPlan() {
        guard seedDemoData, workoutPlans.isEmpty else { return }

        let planID = MockData.defaultWorkoutPlanID
        let phaseID = UUID()
        let weekID = UUID()
        let sessionID = UUID()
        let prescriptionID = UUID()
        let plan = WorkoutPlan(
            id: planID,
            name: "Strength Foundations",
            createdAt: .now,
            goal: "Build strength and muscle."
        )
        let phase = WorkoutPhase(
            id: phaseID,
            planID: planID,
            name: "Base Phase",
            order: 0,
            goal: "Build strength and muscle.",
            durationWeeks: 1
        )
        let week = WorkoutWeek(
            id: weekID,
            planID: planID,
            phaseID: phaseID,
            weekNumber: 1,
            title: "Week 1",
            notes: ""
        )
        let session = WorkoutSession(
            id: sessionID,
            weekID: weekID,
            day: "Monday",
            name: "Strength Session",
            order: 0,
            notes: ""
        )
        let exercise = MockData.trainingExerciseLibrary.first {
            $0.id == "barbell_bench_press"
        } ?? MockData.trainingExerciseLibrary[0]
        let prescription = WorkoutExercisePrescription(
            id: prescriptionID,
            sessionID: sessionID,
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
        workoutPlans = [plan]
        workoutPhases = [phase]
        workoutWeeks = [week]
        workoutSessions = [session]
        workoutPrescriptions = [prescription]
        workoutSetLogs = [WorkoutSetLog(
            id: UUID(),
            prescriptionID: prescriptionID,
            performedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            setNumber: 1,
            weight: 135,
            reps: 8,
            rpe: 7,
            isWarmup: false,
            isComplete: true,
            recordedUnit: .pounds
        )]
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
