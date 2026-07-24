import Foundation

extension DemoRepository {
    func startWorkout(
        session: WorkoutSession,
        planID: UUID?,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem,
        at startedAt: Date = .now
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
            startedAt: startedAt,
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
        unit: UnitSystem,
        at startedAt: Date = .now
    ) -> ActiveWorkoutState? {
        guard activeWorkout == nil else { return nil }
        let workout = ActiveWorkoutState(
            id: UUID(),
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            sourceWeekID: nil,
            name: name,
            dayLabel: startedAt.formatted(.dateTime.weekday(.wide)),
            startedAt: startedAt,
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
        deletedCompletedWorkoutIDs.remove(completed.id)
        completedWorkouts.insert(completed, at: 0)
        workoutSetLogs.removeAll { $0.workoutID == workout.id }
        activeWorkout = nil
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
        return completed
    }

    func deleteCompletedWorkout(_ workout: CompletedWorkout) {
        deletedCompletedWorkoutIDs.insert(workout.id)
        completedWorkouts.removeAll { $0.id == workout.id }
        pendingCompletedWorkoutUploads.removeAll { $0.id == workout.id }
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

    func exerciseSnapshot(_ prescription: WorkoutExercisePrescription) -> WorkoutExerciseSnapshot {
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
        let remainingIndices = workoutSetLogs.indices
            .filter {
                workoutSetLogs[$0].prescriptionID == log.prescriptionID &&
                    workoutSetLogs[$0].workoutID == log.workoutID
            }
            .sorted { workoutSetLogs[$0].setNumber < workoutSetLogs[$1].setNumber }
        for (offset, index) in remainingIndices.enumerated() {
            workoutSetLogs[index].setNumber = offset + 1
        }
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

}
