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

    var selectedPlanScheduleMode: WorkoutScheduleMode { selectedWorkoutPlan?.scheduleMode ?? .weekdays }
    var selectedPlanIsFlexible: Bool { selectedPlanScheduleMode == .flexible }
    var availableFlexibleWorkoutSessions: [WorkoutSession] {
        programStore.availableFlexibleSessions(planID: selectedWorkoutPlanID, completedWorkouts: completedWorkouts)
    }

    var selectedPlanQueueEnabled: Bool {
        programStore.queueEnabled(planID: selectedWorkoutPlanID)
    }

    var selectedPlanQueuedSessions: [WorkoutSession] {
        programStore.queuedSessions(planID: selectedWorkoutPlanID)
    }

    var nextQueuedWorkoutSession: WorkoutSession? {
        guard selectedPlanScheduleMode == .inOrder else { return nil }
        return programStore.nextQueuedSession(planID: selectedWorkoutPlanID, completedWorkouts: completedWorkouts)
    }

    @discardableResult
    func setSelectedPlanQueueEnabled(_ enabled: Bool) -> Bool {
        setSelectedPlanScheduleMode(enabled ? .inOrder : .weekdays)
    }

    @discardableResult
    func setSelectedPlanScheduleMode(_ mode: WorkoutScheduleMode) -> Bool {
        guard activeWorkout == nil else { return false }
        let changed = programStore.setQueue(planID: selectedWorkoutPlanID, enabled: mode != .weekdays, allowsAnyOrder: mode == .flexible)
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

    func scheduledDates(for week: WorkoutWeek) -> ClosedRange<Date>? {
        let dates = scheduledPlanRows(referenceDate: .now).filter { $0.week.id == week.id }.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }

    func scheduledDate(for session: WorkoutSession) -> Date? {
        guard !selectedPlanQueueEnabled else { return nil }
        return scheduledPlanRows(referenceDate: .now).first { $0.session.id == session.id }?.date
    }

    func sessionsInScheduleOrder(for week: WorkoutWeek) -> [WorkoutSession] {
        let sessions = sessions(for: week)
        guard !selectedPlanQueueEnabled else { return sessions }
        let dates = Dictionary(uniqueKeysWithValues: scheduledPlanRows(referenceDate: .now)
            .filter { $0.week.id == week.id }.map { ($0.session.id, $0.date) })
        return sessions.sorted {
            let left = dates[$0.id] ?? .distantFuture
            let right = dates[$1.id] ?? .distantFuture
            return left == right ? $0.order < $1.order : left < right
        }
    }

    func refreshWorkoutDayReminders() {
        let defaults = UserDefaults.standard
        let sessions = eligibleWorkoutReminderSessions()
        Task {
            do {
                try await WorkoutTodayReminderScheduler.shared.schedule(
                    dayEnabled: isAuthenticated && workoutPreferences.workoutDayRemindersEnabled == true,
                    missedEnabled: isAuthenticated && workoutPreferences.missedWorkoutRemindersEnabled == true,
                    sessions: sessions,
                    minutesAfterMidnight: (defaults.object(forKey: "liftrank.workoutReminder.hour") as? Int ?? 9) * 60
                        + (defaults.object(forKey: "liftrank.workoutReminder.minute") as? Int ?? 0)
                )
                workoutReminderError = nil
            } catch {
                workoutReminderError = error.localizedDescription
            }
        }
    }

    func nextWorkoutDayReminder(minutesAfterMidnight: Int, referenceDate: Date = .now) -> (name: String, date: Date)? {
        WorkoutTodayReminderScheduler.upcomingReminders(
            dayEnabled: true,
            missedEnabled: false,
            sessions: eligibleWorkoutReminderSessions(referenceDate: referenceDate),
            minutesAfterMidnight: minutesAfterMidnight,
            referenceDate: referenceDate
        ).first.map { (name: $0.name, date: $0.date) }
    }

    func nextMissedWorkoutReminder(minutesAfterMidnight: Int, referenceDate: Date = .now) -> (name: String, date: Date)? {
        WorkoutTodayReminderScheduler.upcomingReminders(
            dayEnabled: false,
            missedEnabled: true,
            sessions: eligibleWorkoutReminderSessions(referenceDate: referenceDate),
            minutesAfterMidnight: minutesAfterMidnight,
            referenceDate: referenceDate
        ).first.map { (name: $0.name, date: $0.date) }
    }

    private func eligibleWorkoutReminderSessions(referenceDate: Date = .now) -> [(date: Date, name: String)] {
        guard !selectedPlanQueueEnabled, selectedWorkoutPlan?.isActive == true else { return [] }
        return scheduledPlanRows(referenceDate: referenceDate).filter {
            !isCompletedPlanSession($0.session) && !prescriptions(for: $0.session).isEmpty
        }.map { (date: $0.date, name: $0.session.name) }
    }

    func suggestedRescheduleDate(for session: WorkoutSession, referenceDate: Date = .now) -> Date? {
        guard !selectedPlanQueueEnabled, canEditWorkoutSession(session),
              let week = selectedPlanWeeks.first(where: { $0.id == session.weekID }),
              let row = scheduledPlanRows(referenceDate: referenceDate).first(where: { $0.session.id == session.id }),
              row.date < Calendar.current.startOfDay(for: referenceDate) else { return nil }
        let calendar = Calendar.current
        let settings = workoutPlanProgressionSettings.first { $0.planID == week.planID }
        let start = settings.flatMap { calendar.date(byAdding: .weekOfYear, value: week.weekNumber - 1, to: calendar.startOfDay(for: $0.startedAt)) }
            ?? calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        guard let start, let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
        let occupied = Set(sessions(for: week).filter { $0.id != session.id }.map { $0.day.lowercased() })
        for offset in 0..<7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: referenceDate)),
                  candidate >= start, candidate < end else { continue }
            if !occupied.contains(calendar.weekdayName(for: calendar.component(.weekday, from: candidate)).lowercased()) { return candidate }
        }
        return nil
    }

    private func scheduledPlanRows(referenceDate: Date) -> [(week: WorkoutWeek, session: WorkoutSession, date: Date)] {
        guard !selectedPlanQueueEnabled else { return [] }
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

    var selectedProgramCycleHasEnded: Bool {
        let sessions = selectedPlanWeeks.flatMap { self.sessions(for: $0) }.filter { !prescriptions(for: $0).isEmpty }
        return !sessions.isEmpty && sessions.allSatisfy({ isCompletedPlanSession($0) }) && nextScheduledWorkout() == nil
    }

    var selectedProgramStatus: String {
        let sessions = selectedPlanWeeks.flatMap { self.sessions(for: $0) }.filter { !prescriptions(for: $0).isEmpty }
        if !sessions.isEmpty && sessions.allSatisfy({ $0.outcome == .rest || isFullyCompletedPlanSession($0) }) {
            return "Program complete"
        }
        if selectedProgramCycleHasEnded {
            return "Cycle ended · shortened or skipped sessions"
        }
        return selectedWorkoutPlan?.isActive == true ? "Active program" : "Saved program"
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

    @discardableResult
    func createWorkoutPlan(name: String, startDate: Date = .now, schedule: WorkoutScheduleMode = .weekdays) -> Bool {
        guard activeWorkout == nil else { return false }
        guard let plan = programStore.createPlan(name: name, startDate: startDate, schedule: schedule) else {
            Haptics.warning()
            return false
        }
        guard selectWorkoutPlan(plan.id) else { return false }
        Haptics.success()
        return true
    }

    @discardableResult
    func createWorkoutPlanFromHistory(
        name: String,
        assignments: [(workout: CompletedWorkout, weekday: Int)],
        durationWeeks: Int,
        startDate: Date,
        schedule: WorkoutScheduleMode = .weekdays
    ) -> Bool {
        guard activeWorkout == nil,
              let plan = programStore.createPlanFromHistory(
                name: name,
                assignments: assignments,
                durationWeeks: durationWeeks,
                startDate: startDate,
                preferredUnit: currentProfile.preferredUnit,
                schedule: schedule
              ) else {
            Haptics.warning()
            return false
        }
        guard selectWorkoutPlan(plan.id) else { return false }
        Haptics.success()
        return true
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

    func suggestedTrainingMaxSource(for exerciseID: String) -> String? {
        let acceptedIDs = trainingMaxCompatibleExerciseIDs(for: exerciseID)
        if let lift = currentUserLifts
            .filter({ acceptedIDs.contains($0.exerciseID) && $0.estimatedOneRepMax > 0 })
            .max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax }) {
            return "90% of submitted estimate from \(lift.performedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        let source = completedWorkouts
            .filter { workout in workout.exercises.contains { acceptedIDs.contains($0.exerciseID) || $0.rankingExerciseID.map(acceptedIDs.contains) == true } }
            .max(by: { $0.completedAt < $1.completedAt })
        if let source { return "Estimated from logged sets in \(source.name) · \(source.completedAt.formatted(date: .abbreviated, time: .omitted))" }
        return nil
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
              template.availableProgressionMethods.contains(method),
              method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy({ (trainingMaxKilograms[$0] ?? 0) > 0 }) else { return false }
        let previousSettings = repository.workoutPlanProgressionSettings[index]
        if previousSettings.method != method || previousSettings.trainingMaxKilograms != trainingMaxKilograms {
            guard programStore.changeProgression(planID: planID, method: method, trainingMaxKilograms: trainingMaxKilograms) else { return false }
        }
        repository.workoutPlanProgressionSettings[index].startedAt = startDate
        repository.workoutPlanProgressionSettings[index].scheduledWeekdays = scheduledWeekdays
        let weekIDs = Set(weeks(for: planID).map(\.id))
        let protectedSessionIDs = protectedWorkoutSessionIDs
        for sessionIndex in repository.workoutSessions.indices {
            let session = repository.workoutSessions[sessionIndex]
            guard weekIDs.contains(session.weekID), !protectedSessionIDs.contains(session.id),
                  scheduledWeekdays.indices.contains(session.order) else { continue }
            repository.workoutSessions[sessionIndex].day = Calendar.current.weekdayName(for: scheduledWeekdays[session.order])
        }
        repository.persistWorkoutSnapshotWithoutBlockingUI()
        Task { await synchronizeWorkoutPlans() }
        return true
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

    @discardableResult
    func updateWorkoutPrescription(
        _ prescription: WorkoutExercisePrescription,
        scope: WorkoutPrescriptionEditScope
    ) -> Int {
        let updatedCount = programStore.updatePrescription(
            prescription,
            scope: scope,
            excludingSessionIDs: protectedWorkoutSessionIDs
        )
        guard updatedCount > 0 else {
            Haptics.warning()
            return 0
        }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return updatedCount
    }

    @discardableResult
    func setWorkoutSuperset(sessionID: UUID, exerciseIDs: [UUID], restSeconds: Int) -> Bool {
        guard activeWorkout == nil, !protectedWorkoutSessionIDs.contains(sessionID),
              programStore.setSuperset(sessionID: sessionID, exerciseIDs: exerciseIDs, restSeconds: restSeconds) else {
            Haptics.warning()
            return false
        }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return true
    }

    func removeWorkoutSuperset(sessionID: UUID, exerciseID: UUID) {
        guard activeWorkout == nil, !protectedWorkoutSessionIDs.contains(sessionID) else { return }
        programStore.removeSuperset(sessionID: sessionID, exerciseID: exerciseID)
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
    }

    func canEditWorkoutSession(_ session: WorkoutSession) -> Bool {
        activeWorkout == nil && !protectedWorkoutSessionIDs.contains(session.id)
    }

    @discardableResult
    func duplicateWorkoutSession(_ session: WorkoutSession, day: String) -> Bool {
        guard activeWorkout == nil, let copy = programStore.duplicateSession(session, day: day),
              let week = workoutWeeks.first(where: { $0.id == copy.weekID }) else { return false }
        if programStore.queueEnabled(planID: week.planID) {
            _ = programStore.setQueue(planID: week.planID, enabled: true)
        }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return true
    }

    @discardableResult
    func rescheduleWorkoutSession(_ session: WorkoutSession, day: String) -> Bool {
        guard canEditWorkoutSession(session), programStore.rescheduleSession(session, day: day) else { return false }
        Task { await synchronizeWorkoutPlans() }
        Haptics.success()
        return true
    }

    func workoutScheduleDateRange(for session: WorkoutSession) -> ClosedRange<Date>? {
        guard !selectedPlanQueueEnabled,
              let week = workoutWeeks.first(where: { $0.id == session.weekID }),
              let start = workoutPlanProgressionSettings.first(where: { $0.planID == week.planID })?.startedAt
                ?? Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start,
              let lastWeek = workoutWeeks.filter({ $0.planID == week.planID }).map(\.weekNumber).max(),
              let end = Calendar.current.date(byAdding: .day, value: (lastWeek + 1) * 7 - 1, to: Calendar.current.startOfDay(for: start)) else { return nil }
        return Calendar.current.startOfDay(for: start)...end
    }

    @discardableResult
    func scheduleWorkoutSession(_ session: WorkoutSession, on date: Date, duplicate: Bool) -> Bool {
        guard activeWorkout == nil, !selectedPlanQueueEnabled,
              duplicate || canEditWorkoutSession(session),
              let range = workoutScheduleDateRange(for: session), range.contains(Calendar.current.startOfDay(for: date)),
              programStore.scheduleSession(session, on: date, duplicate: duplicate) != nil else { return false }
        Task { await synchronizeWorkoutPlans() }
        refreshWorkoutDayReminders()
        Haptics.success()
        return true
    }

    func workoutPlanSummary(_ plan: WorkoutPlan) -> String {
        let weeks = workoutWeeks.filter { $0.planID == plan.id }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = workoutSessions.filter { weekIDs.contains($0.weekID) }
        let sessionIDs = Set(sessions.map(\.id))
        let saved = Set(completedWorkouts.compactMap(\.sourceSessionID)).intersection(sessionIDs).count
        let current = repository.currentProgramWeek(planID: plan.id)?.weekNumber ?? 1
        let progress = sessions.isEmpty ? "No workout days yet" : "Week \(current) of \(weeks.count) · \(saved)/\(sessions.count) workouts logged"
        if let start = workoutPlanProgressionSettings.first(where: { $0.planID == plan.id })?.startedAt {
            return "\(progress) · Starts \(start.formatted(date: .abbreviated, time: .omitted))"
        }
        return progress
    }

    private var protectedWorkoutSessionIDs: Set<UUID> {
        let sessionIDByPrescriptionID = Dictionary(uniqueKeysWithValues: workoutPrescriptions.map { ($0.id, $0.sessionID) })
        var ids = Set(workoutSessions.filter { $0.outcome != nil }.map(\.id))
        ids.formUnion(completedWorkouts.compactMap(\.sourceSessionID))
        ids.formUnion(workoutSetLogs.compactMap { sessionIDByPrescriptionID[$0.prescriptionID] })
        if let sessionID = activeWorkout?.sourceSessionID { ids.insert(sessionID) }
        return ids
    }

    func duplicateSelectedWorkoutPlan() {
        guard activeWorkout == nil else { return }
        guard let copy = programStore.duplicatePlan(id: selectedWorkoutPlanID) else { return }
        _ = selectWorkoutPlan(copy.id)
        Haptics.success()
    }

    func shareableWorkoutPlanText(planID: UUID) -> String? {
        programStore.shareablePlanText(planID: planID)
    }

    @discardableResult
    func importWorkoutPlanCopy(from text: String) -> Bool {
        guard activeWorkout == nil, programStore.importSharedPlan(text) != nil else {
            Haptics.warning()
            return false
        }
        Haptics.success()
        Task { await synchronizeWorkoutPlans() }
        return true
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
