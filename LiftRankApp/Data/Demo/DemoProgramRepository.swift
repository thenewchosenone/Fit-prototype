import Foundation

extension DemoRepository {
    private static let demoProgramHistoryMarker = "[demo:program-history-v2]"
    private static let previousDemoProgramHistoryMarker = "[demo:program-history-v1]"

    /// Seeds one complete 12-week program for simulator demonstrations. The
    /// marker keeps this idempotent and makes the history easy to replace.
    @discardableResult
    func seedDemoProgramHistoryIfNeeded(referenceDate: Date = .now) -> UUID? {
        let previousSeed = completedWorkouts.filter { $0.notes.contains(Self.previousDemoProgramHistoryMarker) }
        if !previousSeed.isEmpty {
            let oldPlanIDs = Set(previousSeed.compactMap(\.sourcePlanID))
            completedWorkouts.removeAll { $0.notes.contains(Self.previousDemoProgramHistoryMarker) }
            workoutPlans.removeAll { oldPlanIDs.contains($0.id) }
            workoutPhases.removeAll { oldPlanIDs.contains($0.planID) }
            let oldWeekIDs = Set(workoutWeeks.filter { oldPlanIDs.contains($0.planID) }.map(\.id))
            workoutWeeks.removeAll { oldWeekIDs.contains($0.id) }
            let oldSessionIDs = Set(workoutSessions.filter { oldWeekIDs.contains($0.weekID) }.map(\.id))
            workoutSessions.removeAll { oldSessionIDs.contains($0.id) }
            let oldPrescriptionIDs = Set(workoutPrescriptions.filter { oldSessionIDs.contains($0.sessionID) }.map(\.id))
            workoutPrescriptions.removeAll { oldSessionIDs.contains($0.sessionID) }
            workoutSetLogs.removeAll { oldPrescriptionIDs.contains($0.prescriptionID) }
            workoutEntries.removeAll { oldPlanIDs.contains($0.planID) }
            workoutPlanProgressionSettings.removeAll { oldPlanIDs.contains($0.planID) }
        }
        guard !completedWorkouts.contains(where: { $0.notes.contains(Self.demoProgramHistoryMarker) }) else {
            return completedWorkouts.first(where: { $0.notes.contains(Self.demoProgramHistoryMarker) })?.sourcePlanID
        }
        guard let template = WorkoutProgramCatalog.templates.first else { return nil }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .weekOfYear, value: -12, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let scheduledWeekdays = template.sessions.map(\.dayIndex)
        let plan = startWorkoutProgram(
            template: template,
            startDate: startDate,
            scheduledWeekdays: scheduledWeekdays,
            method: template.defaultProgression,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        )

        let weeks = workoutWeeks.filter { $0.planID == plan.id }.sorted { $0.weekNumber < $1.weekNumber }
        for week in weeks {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: week.weekNumber - 1, to: startDate) ?? startDate
            for session in workoutSessions.filter({ $0.weekID == week.id }).sorted(by: { $0.order < $1.order }) {
                let sessionDate = calendar.date(byAdding: .day, value: session.order * 2, to: weekStart) ?? weekStart
                let startedAt = calendar.date(bySettingHour: 16 + ((week.weekNumber + session.order) % 4), minute: 10 + (session.order * 11), second: 0, of: sessionDate) ?? sessionDate
                let completedAt = startedAt.addingTimeInterval(TimeInterval((38 + session.order * 9 + (week.weekNumber % 3) * 5) * 60))
                let prescriptions = workoutPrescriptions.filter { $0.sessionID == session.id }.sorted { $0.order < $1.order }
                let exercises = prescriptions.map(exerciseSnapshot)
                let sets = exercises.flatMap { exercise in
                    let range = exercise.targetReps.split(separator: "-").compactMap { Int($0) }
                    let minimumReps = range.first ?? 8
                    let maximumReps = range.last ?? minimumReps
                    let variation = (week.weekNumber + session.order + exercise.order) % max(1, maximumReps - minimumReps + 1)
                    let reps = minimumReps + variation
                    let completedSetCount = (week.weekNumber == 4 || week.weekNumber == 8 || week.weekNumber == 12)
                        ? max(1, exercise.targetSets - 1) : exercise.targetSets
                    let effort = min(9, 6 + ((week.weekNumber + exercise.order + session.order) % 4))
                    let loadVariation = Double(((week.weekNumber * 3 + session.order * 2 + exercise.order) % 5) - 2) * 2.5
                    let weight = max(25, 70 + Double(week.weekNumber * 2 + exercise.order * 7) + loadVariation)
                    return (1...max(1, completedSetCount)).map { setNumber in
                        WorkoutSetLog(
                            id: UUID(), prescriptionID: exercise.id, performedAt: completedAt,
                            setNumber: setNumber, weight: weight, reps: reps, rpe: effort, isWarmup: false, isComplete: true,
                            workoutID: nil, recordedUnit: .pounds
                        )
                    }
                }
                completedWorkouts.append(
                    CompletedWorkout(
                        id: UUID(), source: .planned, sourceSessionID: session.id, sourcePlanID: plan.id,
                        name: session.name, dayLabel: session.day, startedAt: startedAt, completedAt: completedAt,
                        duration: completedAt.timeIntervalSince(startedAt), effort: 3,
                        notes: Self.demoProgramHistoryMarker, gymID: nil, bodyweight: 180, unit: .pounds,
                        exercises: exercises, sets: sets, linkedSubmissionIDs: []
                    )
                )
            }
        }
        completedWorkouts.sort { $0.completedAt > $1.completedAt }
        refreshAchievementUnlocks()
        persistWorkoutSnapshot()
        return plan.id
    }

    func clearAccountScopedWorkoutHistory() {
        workoutFeedback.removeAll()
        workoutEntries.removeAll()
        workoutSetLogs.removeAll()
        persistWorkoutSnapshot()
    }

    func addWorkoutPlan(_ plan: WorkoutPlan) {
        workoutPlans.insert(plan, at: 0)
        createDefaultProgramScaffold(for: plan)
        scheduleWorkoutSnapshotPersistence()
    }

    /// Retained for importing and maintaining legacy workout records while the
    /// active tracker uses snapshot-based workouts.
    func addWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        workoutEntries.insert(entry, at: 0)
        scheduleWorkoutSnapshotPersistence()
    }

    func updateWorkoutEntry(_ entry: WorkoutExerciseEntry) {
        guard let index = workoutEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        workoutEntries[index] = entry
        scheduleWorkoutSnapshotPersistence()
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
        scheduleWorkoutSnapshotPersistence()
    }

    func updateWorkoutPlan(_ plan: WorkoutPlan) {
        guard let index = workoutPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        workoutPlans[index] = plan
        scheduleWorkoutSnapshotPersistence()
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

        var generatedWeeks: [WorkoutWeek] = []
        var generatedSessions: [WorkoutSession] = []
        var generatedPrescriptions: [WorkoutExercisePrescription] = []
        var generatedEntries: [WorkoutExerciseEntry] = []
        var generatedEntryKeys: Set<String> = []

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
            generatedWeeks.append(week)

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
                generatedSessions.append(session)

                for (exerciseIndex, exerciseTemplate) in sessionTemplate.exercises.enumerated() {
                    guard let prescription = programPrescription(
                        exerciseTemplate,
                        sessionID: session.id,
                        order: exerciseIndex,
                        templateID: template.id,
                        sessionIndex: sessionIndex,
                        exerciseIndex: exerciseIndex,
                        week: weekNumber,
                        method: method,
                        trainingMaxKilograms: trainingMaxKilograms
                    ) else { continue }
                    generatedPrescriptions.append(prescription)
                    let entryKey = "\(weekNumber)|\(session.name)|\(prescription.exerciseName)"
                    guard generatedEntryKeys.insert(entryKey).inserted else { continue }
                    generatedEntries.append(WorkoutExerciseEntry(
                        id: UUID(),
                        planID: plan.id,
                        week: weekNumber,
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
                    ))
                }
            }
        }

        workoutWeeks.append(contentsOf: generatedWeeks)
        workoutSessions.append(contentsOf: generatedSessions)
        workoutPrescriptions.append(contentsOf: generatedPrescriptions)
        workoutEntries.insert(contentsOf: generatedEntries.reversed(), at: 0)

        scheduleWorkoutSnapshotPersistence()
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
                            templateID: template.id,
                            sessionIndex: session.order,
                            exerciseIndex: workoutPrescriptions[index].order,
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
        scheduleWorkoutSnapshotPersistence()
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

        scheduleWorkoutSnapshotPersistence()
        return copy
    }

    @discardableResult
    func addWorkoutWeek(planID: UUID, phaseID: UUID? = nil, title: String? = nil) -> WorkoutWeek {
        let phase = phaseID.flatMap { id in workoutPhases.first { $0.id == id } } ?? firstPhase(for: planID)
        let resolvedPhase = phase ?? createDefaultPhase(for: planID)
        let nextNumber = (workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber).max() ?? 0) + 1
        let week = WorkoutWeek(id: UUID(), planID: planID, phaseID: resolvedPhase.id, weekNumber: nextNumber, title: title ?? "Week \(nextNumber)", notes: "")
        workoutWeeks.append(week)
        scheduleWorkoutSnapshotPersistence()
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
        scheduleWorkoutSnapshotPersistence()
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
        scheduleWorkoutSnapshotPersistence()
    }

    @discardableResult
    func addWorkoutSession(weekID: UUID, day: String, name: String) -> WorkoutSession {
        let nextOrder = (workoutSessions.filter { $0.weekID == weekID }.map(\.order).max() ?? -1) + 1
        let session = WorkoutSession(id: UUID(), weekID: weekID, day: day, name: name, order: nextOrder, notes: "")
        workoutSessions.append(session)
        scheduleWorkoutSnapshotPersistence()
        return session
    }

    func deleteWorkoutSession(_ session: WorkoutSession) {
        guard let week = workoutWeeks.first(where: { $0.id == session.weekID }) else { return }
        let prescriptionIDs = workoutPrescriptions.filter { $0.sessionID == session.id }.map(\.id)
        workoutSessions.removeAll { $0.id == session.id }
        workoutPrescriptions.removeAll { $0.sessionID == session.id }
        workoutSetLogs.removeAll { prescriptionIDs.contains($0.prescriptionID) }
        workoutEntries.removeAll { $0.planID == week.planID && $0.week == week.weekNumber && $0.workout == session.name }
        scheduleWorkoutSnapshotPersistence()
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
        scheduleWorkoutSnapshotPersistence()
    }

    @discardableResult
    func addWorkoutPrescription(_ prescription: WorkoutExercisePrescription) -> WorkoutExercisePrescription {
        workoutPrescriptions.append(prescription)
        bridgePrescriptionToWorkoutEntry(prescription)
        scheduleWorkoutSnapshotPersistence()
        return prescription
    }

    func updateWorkoutPrescription(_ prescription: WorkoutExercisePrescription) {
        guard let index = workoutPrescriptions.firstIndex(where: { $0.id == prescription.id }) else { return }
        workoutPrescriptions[index] = prescription
        scheduleWorkoutSnapshotPersistence()
    }

    func deleteWorkoutPrescription(_ prescription: WorkoutExercisePrescription) {
        workoutPrescriptions.removeAll { $0.id == prescription.id }
        workoutSetLogs.removeAll { $0.prescriptionID == prescription.id }
        workoutEntries.removeAll { $0.exercise == prescription.exerciseName && $0.workout == session(for: prescription)?.name }
        scheduleWorkoutSnapshotPersistence()
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
        templateID: String,
        sessionIndex: Int,
        exerciseIndex: Int,
        week: Int,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutExercisePrescription? {
        let effectiveTemplate = WorkoutProgramCatalog.effectiveTemplateExercise(
            template,
            templateID: templateID,
            sessionIndex: sessionIndex,
            exerciseIndex: exerciseIndex,
            week: week
        )
        guard let exercise = (MockData.trainingExerciseLibrary + customTrainingExercises).first(where: { $0.id == effectiveTemplate.exerciseID }) else {
            return nil
        }
        let setCount = WorkoutProgramCatalog.workingSetCount(
            for: templateID,
            baseSets: effectiveTemplate.sets,
            sessionIndex: sessionIndex,
            exerciseIndex: exerciseIndex,
            week: week
        )
        let percentage = method == .percentage ? trainingMaxKilograms[exercise.id].map { _ in WorkoutProgramCatalog.percentage(for: week, exerciseID: exercise.id) } : nil
        let percentageReps = [6, 6, 5, 5, 5, 4, 3, 5, 3, 2, 1, 5][max(0, min(11, week - 1))]
        let reps = percentage == nil ? effectiveTemplate.reps : "\(percentageReps)"
        let targetRIR = method == .rirRepRange || (method == .percentage && percentage == nil)
            ? WorkoutProgramCatalog.rirTarget(for: week)
            : nil
        let targetLoad = percentage.flatMap { value in trainingMaxKilograms[exercise.id].map { $0 * value } }
        var notes = effectiveTemplate.notes
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
            restSeconds: effectiveTemplate.restSeconds,
            order: order,
            notes: notes,
            substitutionExerciseIDs: effectiveTemplate.substitutionExerciseIDs,
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
