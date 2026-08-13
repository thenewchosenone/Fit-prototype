import Foundation

extension DemoRepository {
    func clearAccountScopedWorkoutHistory() {
        workoutFeedback.removeAll()
        workoutEntries.removeAll()
        workoutSetLogs.removeAll()
        persistWorkoutSnapshot()
    }

    func addWorkoutPlan(_ plan: WorkoutPlan) {
        workoutPlans.insert(plan, at: 0)
        createDefaultProgramScaffold(for: plan)
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

                    guard let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { continue }
                    for entryIndex in workoutEntries.indices where
                        workoutEntries[entryIndex].planID == planID &&
                        workoutEntries[entryIndex].week == week.weekNumber &&
                        workoutEntries[entryIndex].workout == session.name &&
                        workoutEntries[entryIndex].exercise == workoutPrescriptions[index].exerciseName {
                        workoutEntries[entryIndex].targetSets = replacement.sets
                        workoutEntries[entryIndex].targetReps = replacement.reps
                    }
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


    func rebuildProgramBuilderDataFromEntries() {
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
}
