import Foundation


enum ActiveWorkoutFinishReadiness: Equatable {
    case unavailable
    case empty
    case incomplete(completedSets: Int, plannedSets: Int)
    case ready

    var hasIncompleteSets: Bool {
        if case .incomplete = self { return true }
        return false
    }
}

struct ActiveWorkoutExerciseProgress: Equatable {
    let completedWorkingSets: Int
    let plannedWorkingSets: Int

    var isComplete: Bool {
        plannedWorkingSets > 0 && completedWorkingSets >= plannedWorkingSets
    }
}

struct ActiveWorkoutDisplayState: Equatable {
    let exercises: [WorkoutExerciseSnapshot]
    let completedWorkingSets: Int
    let plannedWorkingSets: Int
    let completedExercises: Int
    let totalVolume: Double
    let progressByExerciseID: [UUID: ActiveWorkoutExerciseProgress]
}

private struct ActiveWorkoutDisplayStateSignature: Equatable {
    struct ExerciseSignature: Equatable {
        let id: UUID
        let order: Int
        let targetSets: Int
    }

    let workoutID: UUID?
    let unit: UnitSystem?
    let exercises: [ExerciseSignature]
    let workoutSetLogsRevision: Int
}

private struct ActiveWorkoutSummarySignature: Equatable {
    struct ExerciseSignature: Equatable {
        let id: UUID
        let exerciseID: String
        let trackingType: String?
    }

    let workoutID: UUID
    let sourceSessionID: UUID?
    let workoutName: String
    let unit: UnitSystem
    let exercises: [ExerciseSignature]
    let workoutSetLogsRevision: Int
}

private struct PreviousWorkoutSetLookupSignature: Equatable {
    let exerciseID: String
    let setNumbers: [Int]
    let completedWorkoutsRevision: Int
}

@MainActor
final class ActiveWorkoutStore {
    private let repository: any ActiveWorkoutRepository
    private let now: () -> Date
    private let restNotificationScheduler: any WorkoutRestNotificationScheduling
    private var cachedUserID: UUID
    private var cachedDisplayStateSignature: ActiveWorkoutDisplayStateSignature?
    private var cachedDisplayState: ActiveWorkoutDisplayState?
    private var cachedSummarySignature: ActiveWorkoutSummarySignature?
    private var cachedSummary: WorkoutSummary?
    private var cachedPreviousWorkoutSetLookupSignature: PreviousWorkoutSetLookupSignature?
    private var cachedPreviousWorkoutSetLookup: [Int: WorkoutSetLog]?

    init(
        repository: any ActiveWorkoutRepository,
        now: @escaping () -> Date = { .now },
        restNotificationScheduler: any WorkoutRestNotificationScheduling = SystemWorkoutRestNotificationScheduler.shared
    ) {
        self.repository = repository
        self.now = now
        self.restNotificationScheduler = restNotificationScheduler
        self.cachedUserID = repository.currentProfile.id
    }

    var workout: ActiveWorkoutState? {
        resetAccountScopedDraftIfNeeded()
        return repository.activeWorkout
    }

    var displayState: ActiveWorkoutDisplayState {
        guard let workout else {
            return ActiveWorkoutDisplayState(
                exercises: [],
                completedWorkingSets: 0,
                plannedWorkingSets: 0,
                completedExercises: 0,
                totalVolume: 0,
                progressByExerciseID: [:]
            )
        }

        let exercises = workout.exercises.sorted { $0.order < $1.order }
        let signature = ActiveWorkoutDisplayStateSignature(
            workoutID: workout.id,
            unit: workout.unit,
            exercises: exercises.map {
                ActiveWorkoutDisplayStateSignature.ExerciseSignature(
                    id: $0.id,
                    order: $0.order,
                    targetSets: $0.targetSets
                )
            },
            workoutSetLogsRevision: repository.workoutSetLogsRevision
        )
        if let cachedDisplayState, cachedDisplayStateSignature == signature {
            return cachedDisplayState
        }

        let activeLogs = repository.workoutSetLogs.filter { $0.workoutID == workout.id }
        let logsByExerciseID = Dictionary(grouping: activeLogs, by: \.prescriptionID)
        var progressByExerciseID: [UUID: ActiveWorkoutExerciseProgress] = [:]
        var completedWorkingSets = 0
        var plannedWorkingSets = 0
        var completedExerciseIDs: Set<UUID> = []
        var totalVolume = 0.0

        for exercise in exercises {
            let workingLogs = (logsByExerciseID[exercise.id] ?? []).filter { !$0.isWarmup }
            let planned = workingLogs.isEmpty ? exercise.targetSets : workingLogs.count
            let completed = workingLogs.filter(\.isComplete).count
            completedWorkingSets += completed
            plannedWorkingSets += planned
            if completed > 0 { completedExerciseIDs.insert(exercise.id) }
            totalVolume += workingLogs.filter(\.isComplete).reduce(0) { total, log in
                total + trackingAwareVolume(for: log, workout: workout)
            }
            progressByExerciseID[exercise.id] = ActiveWorkoutExerciseProgress(
                completedWorkingSets: completed,
                plannedWorkingSets: planned
            )
        }

        let displayState = ActiveWorkoutDisplayState(
            exercises: exercises,
            completedWorkingSets: completedWorkingSets,
            plannedWorkingSets: plannedWorkingSets,
            completedExercises: completedExerciseIDs.count,
            totalVolume: totalVolume,
            progressByExerciseID: progressByExerciseID
        )
        cachedDisplayState = displayState
        cachedDisplayStateSignature = signature
        return displayState
    }

    @discardableResult
    func startPlanned(
        session: WorkoutSession,
        planID: UUID?,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem
    ) -> ActiveWorkoutState? {
        guard workout == nil else { return nil }
        return repository.startWorkout(
            session: session,
            planID: planID,
            gymID: gymID,
            bodyweight: bodyweight,
            unit: unit,
            at: now()
        )
    }

    @discardableResult
    func startFreestyle(
        name: String = "Freestyle Workout",
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem
    ) -> ActiveWorkoutState? {
        guard workout == nil else { return nil }
        return repository.startFreestyleWorkout(
            name: name,
            gymID: gymID,
            bodyweight: bodyweight,
            unit: unit,
            at: now()
        )
    }

    func addExercises(_ exercises: [TrainingExerciseCatalogItem]) {
        repository.addExercisesToActiveWorkout(exercises)
    }

    @discardableResult
    func substituteExercise(
        _ exercise: WorkoutExerciseSnapshot,
        with substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot? {
        repository.substituteActiveWorkoutExercise(
            currentExerciseID: exercise.id,
            substitute: substitute
        )
    }

    @discardableResult
    func updateSourcePlan() -> Bool {
        repository.updateSourcePlanFromActiveWorkout()
    }

    func setLogs(for exercise: WorkoutExerciseSnapshot) -> [WorkoutSetLog] {
        guard let workoutID = workout?.id else { return [] }
        return repository.workoutSetLogs
            .filter { $0.workoutID == workoutID && $0.prescriptionID == exercise.id }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func updateSet(_ log: WorkoutSetLog) {
        repository.updateWorkoutSetLog(log)
    }

    @discardableResult
    func addSet(to exercise: WorkoutExerciseSnapshot, persistImmediately: Bool = true) -> WorkoutSetLog? {
        guard let workout else { return nil }
        let nextSetNumber = repository.workoutSetLogs.reduce(0) { currentMax, log in
            guard log.workoutID == workout.id, log.prescriptionID == exercise.id else { return currentMax }
            return max(currentMax, log.setNumber)
        } + 1
        return repository.addWorkoutSetLog(
            prescriptionID: exercise.id,
            setNumber: nextSetNumber,
            workoutID: workout.id,
            unit: workout.unit,
            persistImmediately: persistImmediately
        )
    }

    func deleteSet(_ log: WorkoutSetLog) {
        repository.deleteWorkoutSetLog(log)
    }

    func prCandidates(existingLifts: [LiftSubmission]) -> [WorkoutPRCandidate] {
        guard let workout else { return [] }
        let sets = repository.workoutSetLogs.filter { $0.workoutID == workout.id }
        return WorkoutPRDetector.candidates(
            workoutID: workout.id,
            exercises: workout.exercises,
            sets: sets,
            existingLifts: existingLifts,
            completedWorkouts: repository.completedWorkouts,
            excludingCompletedWorkoutID: nil
        )
    }

    var completedWorkingSets: [WorkoutSetLog] {
        guard let workoutID = workout?.id else { return [] }
        return repository.workoutSetLogs.filter {
            $0.workoutID == workoutID && $0.isComplete && !$0.isWarmup
        }
    }

    var plannedWorkingSetCount: Int {
        displayState.plannedWorkingSets
    }

    func exerciseProgress(for exercise: WorkoutExerciseSnapshot) -> ActiveWorkoutExerciseProgress {
        let workingLogs = setLogs(for: exercise).filter { !$0.isWarmup }
        let plannedSets = workingLogs.isEmpty ? exercise.targetSets : workingLogs.count
        let completedSets = workingLogs.filter(\.isComplete).count
        return ActiveWorkoutExerciseProgress(
            completedWorkingSets: completedSets,
            plannedWorkingSets: plannedSets
        )
    }

    func previousSetLogsBySetNumber(for exercise: WorkoutExerciseSnapshot, setNumbers: [Int]) -> [Int: WorkoutSetLog] {
        let neededSetNumbers = Array(Set(setNumbers)).sorted()
        guard !neededSetNumbers.isEmpty else { return [:] }

        let signature = PreviousWorkoutSetLookupSignature(
            exerciseID: exercise.exerciseID,
            setNumbers: neededSetNumbers,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedPreviousWorkoutSetLookup,
           cachedPreviousWorkoutSetLookupSignature == signature {
            return cachedPreviousWorkoutSetLookup
        }

        let needed = Set(neededSetNumbers)
        var lookup: [Int: (date: Date, log: WorkoutSetLog)] = [:]
        for workout in repository.completedWorkouts {
            guard let previousExercise = workout.exercises.first(where: { $0.exerciseID == exercise.exerciseID }) else { continue }
            for log in workout.sets where log.prescriptionID == previousExercise.id && log.isComplete {
                guard needed.contains(log.setNumber) else { continue }
                if lookup[log.setNumber]?.date ?? .distantPast < workout.completedAt {
                    lookup[log.setNumber] = (workout.completedAt, log)
                }
            }
        }

        let result = lookup.mapValues(\.log)
        cachedPreviousWorkoutSetLookup = result
        cachedPreviousWorkoutSetLookupSignature = signature
        return result
    }

    var finishReadiness: ActiveWorkoutFinishReadiness {
        guard workout != nil else { return .unavailable }
        let displayState = displayState
        let completedSets = displayState.completedWorkingSets
        guard completedSets > 0 else { return .empty }
        let plannedSets = displayState.plannedWorkingSets
        guard completedSets >= plannedSets else {
            return .incomplete(completedSets: completedSets, plannedSets: plannedSets)
        }
        return .ready
    }

    func pause() {
        repository.pauseActiveWorkout(at: now())
    }

    func resume() {
        repository.resumeActiveWorkout(at: now())
    }

    func updateRestTimer(endsAt: Date?, exerciseID: UUID?) {
        repository.updateActiveRestTimer(endsAt: endsAt, exerciseID: exerciseID)
        if endsAt == nil {
            restNotificationScheduler.cancel()
        }
    }

    func discard() {
        repository.discardActiveWorkout()
        restNotificationScheduler.cancel()
        repository.persistWorkoutSnapshot()
    }

    func deleteCompletedWorkout(_ workout: CompletedWorkout) {
        repository.deleteCompletedWorkout(workout)
    }

    func updateCompletedWorkout(_ workout: CompletedWorkout) {
        repository.updateCompletedWorkout(workout)
    }

    func removeExercise(_ exercise: WorkoutExerciseSnapshot) {
        let shouldCancelRestTimer = workout?.restTimerExerciseID == exercise.id
        repository.removeExerciseFromActiveWorkout(exercise)
        if shouldCancelRestTimer {
            restNotificationScheduler.cancel()
        }
    }

    func setAutomaticRestTimerEnabled(_ enabled: Bool) {
        repository.setAutomaticRestTimerEnabledForActiveWorkout(enabled)
    }

    func setDefaultRestTimerEnabled(_ enabled: Bool) {
        repository.workoutPreferences.defaultRestTimerEnabled = enabled
        repository.persistWorkoutSnapshot()
    }

    @discardableResult
    func reorderExercises(_ exerciseIDs: [UUID]) -> Bool {
        repository.reorderActiveWorkout(exerciseIDs: exerciseIDs)
    }

    @discardableResult
    func moveExercise(_ exercise: WorkoutExerciseSnapshot, direction: Int) -> Bool {
        repository.moveActiveWorkoutExercise(exercise.id, direction: direction)
    }

    @discardableResult
    func finish(effort: Int, notes: String) -> CompletedWorkout? {
        guard finishReadiness != .unavailable, finishReadiness != .empty else { return nil }
        guard let completed = repository.finishActiveWorkout(effort: effort, notes: notes, at: now()) else {
            return nil
        }
        restNotificationScheduler.cancel()
        repository.persistWorkoutSnapshot()
        return completed
    }

    func summary() -> WorkoutSummary? {
        guard let workout else { return nil }
        let signature = ActiveWorkoutSummarySignature(
            workoutID: workout.id,
            sourceSessionID: workout.sourceSessionID,
            workoutName: workout.name,
            unit: workout.unit,
            exercises: workout.exercises.map {
                ActiveWorkoutSummarySignature.ExerciseSignature(
                    id: $0.id,
                    exerciseID: $0.exerciseID,
                    trackingType: $0.trackingType
                )
            },
            workoutSetLogsRevision: repository.workoutSetLogsRevision
        )
        if let cachedSummary, cachedSummarySignature == signature {
            return cachedSummary
        }

        let displayState = displayState
        let logs = repository.workoutSetLogs.filter {
            $0.workoutID == workout.id && $0.isComplete && !$0.isWarmup
        }
        let summary = WorkoutSummary(
            id: workout.id,
            sessionID: workout.sourceSessionID ?? workout.id,
            workoutName: workout.name,
            completedExercises: displayState.completedExercises,
            totalExercises: workout.exercises.count,
            totalSets: displayState.completedWorkingSets,
            totalVolume: displayState.totalVolume,
            bestSet: logs.filter { trackingKind(for: $0, workout: workout) == .weightReps }.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
        )
        cachedSummary = summary
        cachedSummarySignature = signature
        return summary
    }

    private func trackingKind(for set: WorkoutSetLog, workout: ActiveWorkoutState) -> ExerciseTrackingKind {
        guard let exercise = workout.exercises.first(where: { $0.id == set.prescriptionID }) else { return .weightReps }
        let rawTrackingType = exercise.trackingType ??
            MockData.trainingExerciseLibrary.first(where: { $0.id == exercise.exerciseID })?.trackingType
        return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps")
    }

    private func trackingAwareVolume(for set: WorkoutSetLog, workout: ActiveWorkoutState) -> Double {
        trackingKind(for: set, workout: workout) == .weightReps ? set.volume(in: workout.unit) : 0
    }

    private func resetAccountScopedDraftIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        cachedDisplayState = nil
        cachedDisplayStateSignature = nil
        cachedSummary = nil
        cachedSummarySignature = nil
        cachedPreviousWorkoutSetLookup = nil
        cachedPreviousWorkoutSetLookupSignature = nil
        repository.clearActiveWorkoutDraft()
    }

    @discardableResult
    func applySetCompletion(
        _ log: WorkoutSetLog,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> Bool {
        let shouldTriggerTimer = isComplete && !log.hasTriggeredRestTimer
        var updated = log
        if !isComplete, updated.completionSource == .automatic, source == .manual {
            updated.suppressAutoCompletion = true
        }
        updated.isComplete = isComplete
        updated.performedAt = .now
        updated.completionSource = isComplete ? source : nil
        updated.hasTriggeredRestTimer = isComplete
        repository.updateWorkoutSetLog(updated)
        return shouldTriggerTimer
    }

    @discardableResult
    func attemptAutomaticCompletion(before log: WorkoutSetLog) -> Bool {
        guard let workout else { return false }
        var previous: WorkoutSetLog?
        for candidate in repository.workoutSetLogs where candidate.workoutID == workout.id && candidate.prescriptionID == log.prescriptionID {
            guard candidate.setNumber < log.setNumber else { continue }
            if previous?.setNumber ?? 0 < candidate.setNumber {
                previous = candidate
            }
        }
        guard let previous else { return false }
        let exerciseSnapshot = workout.exercises.first { $0.id == previous.prescriptionID }
        let catalogExercise = exerciseSnapshot.flatMap { snapshot in
            MockData.trainingExerciseLibrary.first { $0.id == snapshot.exerciseID }
        }
        let trackingKind = ExerciseTrackingKind(catalogExercise?.trackingType ?? "Weight + Reps")
        guard !previous.isComplete,
              !previous.isWarmup,
              !previous.suppressAutoCompletion,
              let reps = previous.reps, reps > 0 else {
            return false
        }
        if trackingKind.requiresWeight {
            guard let weight = previous.weight, weight >= 0 else { return false }
        }

        return applySetCompletion(previous, isComplete: true, source: .automatic)
    }
}
