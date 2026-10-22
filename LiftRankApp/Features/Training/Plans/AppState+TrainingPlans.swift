import Foundation

@MainActor
extension AppState {
    func activeSetLogs(for prescription: WorkoutExercisePrescription) -> [WorkoutSetLog] {
        setLogs(for: prescription)
            .filter { Calendar.current.isDateInToday($0.performedAt) }
            .sorted { $0.setNumber < $1.setNumber }
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

    func weeklyVolumeByBodyPart(referenceDate: Date = .now) -> [String: Double] {
        trainingProgressStore.weeklyVolumeByBodyPart(
            referenceDate: referenceDate,
            preferredUnit: currentProfile.preferredUnit
        )
    }

    func weeklyWorkingSetsByMuscle(
        referenceDate: Date = .now,
        weekCount: Int = 4
    ) -> [MuscleTrainingWeek] {
        trainingProgressStore.weeklyWorkingSetsByMuscle(referenceDate: referenceDate, weekCount: weekCount)
    }

    var trainingHistoryWorkouts: [CompletedWorkout] {
        trainingProgressStore.trainingHistoryWorkouts
    }

    func progressExerciseOptions() -> [TrainingExerciseCatalogItem] {
        trainingProgressStore.progressExerciseOptions(
            catalog: trainingExerciseLibrary,
            customTrainingExercisesRevision: repository.customTrainingExercisesRevision
        )
    }

    func completedWorkoutPresentation(for workout: CompletedWorkout) -> CompletedWorkoutPresentation {
        trainingProgressStore.completedWorkoutPresentation(
            for: workout.id,
            fallback: workout,
            catalog: trainingExerciseLibrary,
            customTrainingExercisesRevision: repository.customTrainingExercisesRevision
        )
    }

    func workoutHistoryPresentation(
        displayedMonth: Date,
        selectedDate: Date?,
        referenceDate: Date = .now
    ) -> WorkoutHistoryCalendarPresentation {
        trainingProgressStore.workoutHistoryPresentation(
            displayedMonth: displayedMonth,
            selectedDate: selectedDate,
            referenceDate: referenceDate
        )
    }

    func homeWeeklySummary(referenceDate: Date = .now) -> HomeWeeklySummary {
        trainingProgressStore.homeWeeklySummary(
            referenceDate: referenceDate,
            currentWeek: currentSelectedProgramWeek,
            preferredUnit: currentProfile.preferredUnit
        )
    }

    func addWeekToSelectedPlan() -> WorkoutWeek {
        let week = programStore.addWeek(planID: selectedWorkoutPlanID)
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return week
    }

    var selectedPlanQueueEnabled: Bool {
        programStore.queueEnabled(planID: selectedWorkoutPlanID)
    }

    var selectedPlanQueuedSessions: [WorkoutSession] {
        programStore.queuedSessions(planID: selectedWorkoutPlanID)
    }

    var nextQueuedWorkoutSession: WorkoutSession? {
        programStore.nextQueuedSession(planID: selectedWorkoutPlanID, completedWorkouts: completedWorkouts)
    }

    @discardableResult
    func setSelectedPlanQueueEnabled(_ enabled: Bool) -> Bool {
        guard activeWorkout == nil else { return false }
        let changed = programStore.setQueue(planID: selectedWorkoutPlanID, enabled: enabled)
        if changed {
            Haptics.success()
            Task { await synchronizeWorkoutPlans() }
        } else {
            Haptics.warning()
        }
        return changed
    }

    @discardableResult
    func reorderSelectedPlanQueue(_ sessionIDs: [UUID]) -> Bool {
        guard activeWorkout == nil else { return false }
        let changed = programStore.reorderQueue(planID: selectedWorkoutPlanID, sessionIDs: sessionIDs)
        if changed { Task { await synchronizeWorkoutPlans() } }
        return changed
    }

    func cloneWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        let clone = programStore.cloneWeek(week)
        if selectedPlanQueueEnabled {
            _ = programStore.setQueue(planID: selectedWorkoutPlanID, enabled: true)
        }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return clone
    }

    func deleteWeek(_ week: WorkoutWeek) {
        guard activeWorkout == nil else { return }
        programStore.deleteWeek(week)
        Task { await synchronizeWorkoutPlans() }
        Haptics.warning()
    }

    func addSession(to week: WorkoutWeek, day: String, name: String) -> WorkoutSession {
        let session = programStore.addSession(to: week, day: day, name: name)
        if selectedPlanQueueEnabled {
            let sessionIDs = selectedPlanQueuedSessions.map(\.id) + [session.id]
            _ = programStore.reorderQueue(planID: selectedWorkoutPlanID, sessionIDs: sessionIDs)
        }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return session
    }

    func startFreestyleSession(in week: WorkoutWeek? = nil) -> WorkoutSession {
        let targetWeek = week ?? addWeekToSelectedPlan()
        let session = programStore.startFreestyleSession(in: targetWeek, day: Calendar.current.weekdayName())
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return session
    }

    func deleteSession(_ session: WorkoutSession) {
        guard activeWorkout == nil else { return }
        programStore.deleteSession(session)
        Task { await synchronizeWorkoutPlans() }
        Haptics.warning()
    }

    func cancelWorkout(_ session: WorkoutSession) {
        guard activeWorkout == nil else { return }
        programStore.cancelSession(session)
        Task { await synchronizeWorkoutPlans() }
        Haptics.warning()
    }

    func markWorkoutSessionOutcome(_ outcome: WorkoutSessionOutcome, for sessionID: UUID?) {
        guard activeWorkout == nil,
              let sessionID,
              let session = workoutSessions.first(where: { $0.id == sessionID }) else { return }
        programStore.setSessionOutcome(session, outcome: outcome)
        Task { await synchronizeWorkoutPlans() }
        Haptics.warning()
    }

    func addExercises(_ exercises: [TrainingExerciseCatalogItem], to session: WorkoutSession) {
        guard activeWorkout == nil else { return }
        programStore.addExercises(exercises, to: session)
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
    }

    func addExercise(_ exercise: TrainingExerciseCatalogItem, to session: WorkoutSession, sets: Int, reps: String, restSeconds: Int) {
        guard activeWorkout == nil else { return }
        _ = programStore.addExercise(
            exercise,
            to: session,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds
        )
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
    }

    func deletePrescription(_ prescription: WorkoutExercisePrescription) {
        guard activeWorkout == nil else { return }
        programStore.deletePrescription(prescription)
        Task { await synchronizeWorkoutPlans() }
        Haptics.warning()
    }

    @discardableResult
    func replacePlannedExercise(
        _ prescription: WorkoutExercisePrescription,
        in session: WorkoutSession,
        with exercise: TrainingExerciseCatalogItem
    ) -> Int {
        guard activeWorkout == nil,
              let planWeek = weeks(for: selectedWorkoutPlanID).first(where: { $0.id == session.weekID }) else { return 0 }
        let completedSessionIDs = Set(completedWorkouts.compactMap(\.sourceSessionID))
        let eligibleSessionIDs = Set(weeks(for: planWeek.planID).flatMap(sessions(for:)).filter { candidate in
            guard candidate.outcome == nil,
                  !completedSessionIDs.contains(candidate.id),
                  activeWorkout?.sourceSessionID != candidate.id,
                  !isFullyCompletedPlanSession(candidate) else { return false }
            return prescriptions(for: candidate).allSatisfy { setLogs(for: $0).isEmpty }
        }.map(\.id))
        guard !eligibleSessionIDs.isEmpty else { return 0 }
        let count = programStore.replaceExercise(
            in: planWeek.planID,
            matching: prescription.exerciseID,
            with: exercise,
            eligibleSessionIDs: eligibleSessionIDs
        )
        if count > 0 {
            Task { await synchronizeWorkoutPlans() }
            Haptics.success()
        }
        return count
    }

    func updateSetLog(_ log: WorkoutSetLog) {
        activeWorkoutStore.updateSet(log)
    }

    @discardableResult
    func addSetLog(to prescription: WorkoutExercisePrescription) -> WorkoutSetLog {
        let nextActiveSet = (activeSetLogs(for: prescription).map(\.setNumber).max() ?? 0) + 1
        return repository.addWorkoutSetLog(
            prescriptionID: prescription.id,
            setNumber: nextActiveSet,
            workoutID: nil,
            unit: .pounds,
            persistImmediately: true
        )
    }

    @discardableResult
    func addSetLog(to exercise: WorkoutExerciseSnapshot, persistImmediately: Bool = true) -> WorkoutSetLog? {
        activeWorkoutStore.addSet(to: exercise, persistImmediately: persistImmediately)
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

    func scheduledWorkout(referenceDate: Date = .now) -> (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        if selectedPlanQueueEnabled {
            guard let session = nextQueuedWorkoutSession,
                  let week = selectedPlanWeeks.first(where: { $0.id == session.weekID }) else { return nil }
            return (week, session, referenceDate)
        }
        let today = Calendar.current.startOfDay(for: referenceDate)
        let rows = scheduledPlanRows(referenceDate: referenceDate)
        return rows.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) && !isCompletedPlanSession($0.session) })
            ?? rows.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
    }

    func missedScheduledWorkout(referenceDate: Date = .now) -> (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        guard !selectedPlanQueueEnabled else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return scheduledPlanRows(referenceDate: referenceDate)
            .filter { $0.date < today && !isCompletedPlanSession($0.session) }
        .sorted { $0.date < $1.date }
        .last
    }

    func nextScheduledWorkout(referenceDate: Date = .now) -> (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        guard !selectedPlanQueueEnabled else { return nil }
        let today = Calendar.current.startOfDay(for: referenceDate)
        return scheduledPlanRows(referenceDate: referenceDate)
            .first { $0.date > today && !isCompletedPlanSession($0.session) }
    }

    func scheduledPlanSessions(on date: Date) -> [(week: WorkoutWeek, session: WorkoutSession)] {
        let target = Calendar.current.startOfDay(for: date)
        return scheduledPlanRows(referenceDate: date)
            .filter {
                Calendar.current.isDate($0.date, inSameDayAs: target) &&
                    !isCompletedPlanSession($0.session)
            }
            .map { (week: $0.week, session: $0.session) }
    }

    private func scheduledPlanRows(referenceDate: Date) -> [(week: WorkoutWeek, session: WorkoutSession, date: Date)] {
        let calendar = Calendar.current
        let settings = workoutPlanProgressionSettings.first { $0.planID == selectedWorkoutPlanID }
        let currentWeekID = currentSelectedProgramWeek?.id ?? selectedPlanWeeks.first?.id

        return selectedPlanWeeks.flatMap { week in
            sessions(for: week).compactMap { session -> (week: WorkoutWeek, session: WorkoutSession, date: Date)? in
                guard let weekdayIndex = calendar.weekdaySymbols.firstIndex(where: {
                    $0.caseInsensitiveCompare(session.day) == .orderedSame
                }) else { return nil }

                let cycleStart: Date
                if let settings {
                    guard let start = calendar.date(
                        byAdding: .weekOfYear,
                        value: week.weekNumber - 1,
                        to: calendar.startOfDay(for: settings.startedAt)
                    ) else { return nil }
                    cycleStart = start
                } else {
                    guard week.id == currentWeekID,
                          let start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else { return nil }
                    cycleStart = start
                }

                let targetWeekday = weekdayIndex + 1
                let cycleWeekday = calendar.component(.weekday, from: cycleStart)
                let dayOffset = (targetWeekday - cycleWeekday + 7) % 7
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) else { return nil }
                return (week, session, date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    func isCompletedPlanSession(_ session: WorkoutSession) -> Bool {
        session.outcome != nil || completedWorkouts.contains {
            $0.sourceSessionID == session.id && !$0.completedWorkingSets.isEmpty
        } || isFullyCompletedPlanSession(session)
    }

    func isFullyCompletedPlanSession(_ session: WorkoutSession) -> Bool {
        guard let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return false }
        return programWeekPresentation(for: week).completedSessionIDs.contains(session.id)
    }

    func strengthBalance(for week: Int, planID: UUID? = nil) -> StrengthBalance {
        trainingProgressStore.strengthBalance(
            week: week,
            planID: planID ?? selectedWorkoutPlanID
        )
    }

    func createWorkoutPlan(name: String) {
        guard activeWorkout == nil else { return }
        guard let plan = programStore.createPlan(name: name) else {
            Haptics.warning()
            return
        }
        _ = selectWorkoutPlan(plan.id)
        Haptics.success()
    }

    func suggestedTrainingMaxKilograms(for template: WorkoutProgramTemplate) -> [String: Double] {
        var result: [String: Double] = [:]
        for exerciseID in template.requiredTrainingMaxExerciseIDs {
            let acceptedIDs = trainingMaxCompatibleExerciseIDs(for: exerciseID)
            if let bestPounds = currentUserLifts
                .filter({ acceptedIDs.contains($0.exerciseID) })
                .map(\.estimatedOneRepMax)
                .max(), bestPounds > 0 {
                result[exerciseID] = RankingCalculator.poundsToKilograms(bestPounds) * 0.90
                continue
            }

            let bestCompletedKilograms = completedWorkouts.flatMap { workout in
                workout.exercises.compactMap { exercise -> Double? in
                    guard acceptedIDs.contains(exercise.exerciseID) ||
                            exercise.rankingExerciseID.map(acceptedIDs.contains) == true else { return nil }
                    return workout.sets
                        .filter { $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup }
                        .compactMap { set -> Double? in
                            guard let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
                            let kilograms = set.recordedUnit == .kilograms
                                ? weight
                                : RankingCalculator.poundsToKilograms(weight)
                            return RankingCalculator.epleyOneRepMax(weight: kilograms, repetitions: reps)
                        }
                        .max()
                }
            }.max() ?? 0

            if bestCompletedKilograms > 0 {
                result[exerciseID] = bestCompletedKilograms * 0.90
            }
        }
        return result
    }

    private func trainingMaxCompatibleExerciseIDs(for exerciseID: String) -> Set<String> {
        let catalogRankingID = trainingExerciseLibrary.first { $0.id == exerciseID }?.rankingExerciseID
        var IDs = Set([exerciseID])
        if let catalogRankingID { IDs.insert(catalogRankingID) }

        switch catalogRankingID ?? exerciseID {
        case "squat", "back_squat":
            IDs.formUnion(["squat", "back_squat"])
        case "bench", "barbell_bench_press", "flat_barbell_bench_press":
            IDs.formUnion(["bench", "barbell_bench_press", "flat_barbell_bench_press"])
        case "deadlift", "conventional_deadlift", "sumo_deadlift":
            IDs.formUnion(["deadlift", "conventional_deadlift", "sumo_deadlift"])
        case "press", "barbell_overhead_press":
            IDs.formUnion(["press", "barbell_overhead_press"])
        default:
            break
        }
        return IDs
    }

    func programPreviewPrescription(
        _ base: WorkoutProgramExerciseTemplate,
        templateID: String,
        sessionIndex: Int,
        exerciseIndex: Int,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutExercisePrescription? {
        repository.programPrescription(
            base, sessionID: Self.noWorkoutPlanID, order: exerciseIndex,
            templateID: templateID, sessionIndex: sessionIndex, exerciseIndex: exerciseIndex,
            week: 1, method: method, trainingMaxKilograms: trainingMaxKilograms
        )
    }

    @discardableResult
    func startWorkoutProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan? {
        guard activeWorkout == nil else { return nil }
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
        _ = selectWorkoutPlan(plan.id)
        Haptics.success()
        return plan
    }

    static let noWorkoutPlanID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @discardableResult
    func selectWorkoutPlan(_ planID: UUID?) -> Bool {
        guard activeWorkout == nil,
              planID == nil || workoutPlans.contains(where: { $0.id == planID }) else { return false }
        repository.workoutPlans = workoutPlans.map { plan in
            var updated = plan
            updated.isActive = plan.id == planID
            return updated
        }
        selectedWorkoutPlanID = planID ?? Self.noWorkoutPlanID
        repository.persistWorkoutSnapshotWithoutBlockingUI()
        Task { await synchronizeWorkoutPlans() }
        return true
    }

    func restoreSelectedWorkoutPlanIfNeeded() {
        let activePlans = workoutPlans.filter(\.isActive)
        // Multiple active plans are a sync conflict requiring an explicit selection.
        selectedWorkoutPlanID = activePlans.count == 1 ? activePlans[0].id : Self.noWorkoutPlanID
    }

    @discardableResult
    func changeProgression(
        for planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> Bool {
        guard activeWorkout == nil else { return false }
        let changed = programStore.changeProgression(
            planID: planID,
            method: method,
            trainingMaxKilograms: trainingMaxKilograms
        )
        changed ? Haptics.success() : Haptics.warning()
        if changed { Task { await synchronizeWorkoutPlans() } }
        return changed
    }

    @discardableResult
    func updateWorkoutProgramSetup(
        planID: UUID, startDate: Date, scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod, trainingMaxKilograms: [String: Double]
    ) -> Bool {
        guard activeWorkout == nil,
              let index = repository.workoutPlanProgressionSettings.firstIndex(where: { $0.planID == planID }),
              let template = WorkoutProgramCatalog.template(id: repository.workoutPlanProgressionSettings[index].sourceTemplateID),
              scheduledWeekdays.count == template.sessions.count,
              Set(scheduledWeekdays).count == scheduledWeekdays.count,
              scheduledWeekdays.allSatisfy({ (1...7).contains($0) }),
              method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy({ (trainingMaxKilograms[$0] ?? 0) > 0 }) else { return false }
        repository.workoutPlanProgressionSettings[index].startedAt = startDate
        repository.workoutPlanProgressionSettings[index].scheduledWeekdays = scheduledWeekdays
        let weekIDs = Set(weeks(for: planID).map(\.id))
        for sessionIndex in repository.workoutSessions.indices {
            let session = repository.workoutSessions[sessionIndex]
            guard weekIDs.contains(session.weekID), !isCompletedPlanSession(session),
                  scheduledWeekdays.indices.contains(session.order) else { continue }
            repository.workoutSessions[sessionIndex].day = Calendar.current.weekdayName(for: scheduledWeekdays[session.order])
        }
        guard programStore.changeProgression(planID: planID, method: method, trainingMaxKilograms: trainingMaxKilograms) else { return false }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
        Task { await synchronizeWorkoutPlans() }
        return true
    }

    func changeWorkoutDay(_ session: WorkoutSession, to day: String) {
        guard activeWorkout == nil,
              Calendar.current.weekdaySymbols.contains(day),
              let index = repository.workoutSessions.firstIndex(where: { $0.id == session.id }) else { return }
        repository.workoutSessions[index].day = day
        repository.persistWorkoutSnapshotWithoutBlockingUI()
        Task { await synchronizeWorkoutPlans() }
    }

    func renameSelectedWorkoutPlan(to name: String) {
        guard activeWorkout == nil else { return }
        guard programStore.renamePlan(id: selectedWorkoutPlanID, to: name) else {
            Haptics.warning()
            return
        }
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
    }

    func updateSelectedWorkoutPlanNotes(_ notes: String) {
        guard programStore.updatePlanNotes(id: selectedWorkoutPlanID, notes: notes) else { return }
        Task { await synchronizeWorkoutPlans() }
    }

    func duplicateSelectedWorkoutPlan() {
        guard activeWorkout == nil else { return }
        guard let copy = programStore.duplicatePlan(id: selectedWorkoutPlanID) else { return }
        _ = selectWorkoutPlan(copy.id)
        Haptics.success()
    }

    @discardableResult
    func saveWorkoutAsRoutine(_ workout: CompletedWorkout) -> Bool {
        guard let plan = programStore.saveWorkoutAsRoutine(workout) else {
            Haptics.warning()
            return false
        }
        _ = selectWorkoutPlan(plan.id)
        Haptics.success()
        return true
    }

    func deleteSelectedWorkoutPlan() {
        guard activeWorkout == nil else { return }
        guard let deletion = programStore.deletePlan(id: selectedWorkoutPlanID) else {
            Haptics.warning()
            return
        }
        workoutSyncStore.forgetPlan(deletion.deletedPlanID)
        selectedWorkoutPlanID = Self.noWorkoutPlanID
        Haptics.warning()
        if isAuthenticated, !isDemoMode {
            Task { await workoutSyncStore.deleteRemotePlan(deletion.deletedPlanID) }
        }
    }

}
