import Foundation

@MainActor
extension AppState {
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
        trainingProgressStore.completedPrescriptionCount(for: session)
    }

    func weekCompletion(for week: WorkoutWeek) -> Double {
        trainingProgressStore.weekCompletion(for: week)
    }

    func lastCompletedWorkoutDate() -> Date? {
        trainingProgressStore.lastCompletedWorkoutDate()
    }

    func workoutStreak(referenceDate: Date = .now) -> Int {
        trainingProgressStore.workoutStreak(referenceDate: referenceDate)
    }

    func volumeByBodyPart(for planID: UUID? = nil) -> [String: Double] {
        trainingProgressStore.volumeByBodyPart(
            planID: planID ?? selectedWorkoutPlanID,
            preferredUnit: currentProfile.preferredUnit
        )
    }

    func addWeekToSelectedPlan() -> WorkoutWeek {
        let week = programStore.addWeek(planID: selectedWorkoutPlanID)
        Haptics.success()
        return week
    }

    func cloneWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        let clone = programStore.cloneWeek(week)
        Haptics.success()
        return clone
    }

    func deleteWeek(_ week: WorkoutWeek) {
        programStore.deleteWeek(week)
        Haptics.warning()
    }

    func addSession(to week: WorkoutWeek, day: String, name: String) -> WorkoutSession {
        let session = programStore.addSession(to: week, day: day, name: name)
        Haptics.success()
        return session
    }

    func startFreestyleSession(in week: WorkoutWeek? = nil) -> WorkoutSession {
        let targetWeek = week ?? addWeekToSelectedPlan()
        let session = programStore.startFreestyleSession(in: targetWeek, day: Calendar.current.weekdayName())
        Haptics.success()
        return session
    }

    func deleteSession(_ session: WorkoutSession) {
        programStore.deleteSession(session)
        Haptics.warning()
    }

    func cancelWorkout(_ session: WorkoutSession) {
        programStore.cancelSession(session)
        Haptics.warning()
    }

    func addExercises(_ exercises: [TrainingExerciseCatalogItem], to session: WorkoutSession) {
        programStore.addExercises(exercises, to: session)
        Haptics.success()
    }

    func addExercise(_ exercise: TrainingExerciseCatalogItem, to session: WorkoutSession, sets: Int, reps: String, restSeconds: Int) {
        _ = programStore.addExercise(
            exercise,
            to: session,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds
        )
        Haptics.success()
    }

    func deletePrescription(_ prescription: WorkoutExercisePrescription) {
        programStore.deletePrescription(prescription)
        Haptics.warning()
    }

    func updateSetLog(_ log: WorkoutSetLog) {
        activeWorkoutStore.updateSet(log)
    }

    @discardableResult
    func addSetLog(to prescription: WorkoutExercisePrescription) -> WorkoutSetLog {
        let nextActiveSet = (activeSetLogs(for: prescription).map(\.setNumber).max() ?? 0) + 1
        return repository.addWorkoutSetLog(prescriptionID: prescription.id, setNumber: nextActiveSet)
    }

    @discardableResult
    func addSetLog(to exercise: WorkoutExerciseSnapshot) -> WorkoutSetLog? {
        activeWorkoutStore.addSet(to: exercise)
    }

    func deleteSetLog(_ log: WorkoutSetLog) {
        activeWorkoutStore.deleteSet(log)
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
        guard let exercise = exerciseLibraryStore.createCustomExercise(
            name: name,
            bodyPart: bodyPart,
            equipment: equipment,
            trackingType: trackingType,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles
        ) else {
            Haptics.warning()
            return nil
        }
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
        trainingProgressStore.weekOptions(planID: planID ?? selectedWorkoutPlanID)
    }

    func workoutDays(for week: Int, planID: UUID? = nil) -> [WorkoutDaySummary] {
        trainingProgressStore.workoutDays(
            week: week,
            planID: planID ?? selectedWorkoutPlanID
        )
    }

    func strengthBalance(for week: Int, planID: UUID? = nil) -> StrengthBalance {
        trainingProgressStore.strengthBalance(
            week: week,
            planID: planID ?? selectedWorkoutPlanID
        )
    }

    func createWorkoutPlan(name: String) {
        guard let plan = programStore.createPlan(name: name) else {
            Haptics.warning()
            return
        }
        selectedWorkoutPlanID = plan.id
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
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
        guard let plan = programStore.startProgram(
            template: template,
            startDate: startDate,
            scheduledWeekdays: scheduledWeekdays,
            method: method,
            preferredUnit: currentProfile.preferredUnit,
            trainingMaxKilograms: trainingMaxKilograms
        ) else {
            Haptics.warning()
            return nil
        }
        selectedWorkoutPlanID = plan.id
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
        return plan
    }

    @discardableResult
    func changeProgression(
        for planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> Bool {
        let changed = programStore.changeProgression(
            planID: planID,
            method: method,
            trainingMaxKilograms: trainingMaxKilograms
        )
        changed ? Haptics.success() : Haptics.warning()
        if changed { Task { await synchronizeWorkoutPlans() } }
        return changed
    }

    func renameSelectedWorkoutPlan(to name: String) {
        guard programStore.renamePlan(id: selectedWorkoutPlanID, to: name) else {
            Haptics.warning()
            return
        }
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
    }

    func duplicateSelectedWorkoutPlan() {
        guard let copy = programStore.duplicatePlan(id: selectedWorkoutPlanID) else { return }
        selectedWorkoutPlanID = copy.id
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
    }

    func deleteSelectedWorkoutPlan() {
        guard let deletion = programStore.deletePlan(id: selectedWorkoutPlanID) else {
            Haptics.warning()
            return
        }
        workoutSyncStore.forgetPlan(deletion.deletedPlanID)
        selectedWorkoutPlanID = deletion.fallbackPlanID
        Haptics.warning()
        if isAuthenticated, !isDemoMode {
            Task { await workoutSyncStore.deleteRemotePlan(deletion.deletedPlanID) }
        }
    }

}
