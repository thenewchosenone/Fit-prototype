import Foundation


struct ProgramPlanDeletion: Equatable {
    let deletedPlanID: UUID
}

struct ProgramWeekPresentation {
    let sessions: [WorkoutSession]
    let prescriptionsBySessionID: [UUID: [WorkoutExercisePrescription]]
    let completedPrescriptionIDs: Set<UUID>
    let completedSessionIDs: Set<UUID>
    let completedSetCount: Int
    let rirObservations: [(target: Int, estimated: Int)]
    let catalogByID: [String: TrainingExerciseCatalogItem]
    let completion: Double

    var plannedPrescriptionCount: Int {
        prescriptionsBySessionID.values.reduce(0) { $0 + $1.count }
    }

    var completedPrescriptionCount: Int {
        prescriptionsBySessionID.values
            .flatMap { $0.map(\.id) }
            .filter(completedPrescriptionIDs.contains)
            .count
    }

    var plannedSetCount: Int {
        prescriptionsBySessionID.values.flatMap { $0 }.reduce(0) { $0 + $1.sets }
    }

    var rirSummary: (target: Double, estimated: Double, setCount: Int)? {
        guard !rirObservations.isEmpty else { return nil }
        let count = Double(rirObservations.count)
        return (
            Double(rirObservations.reduce(0) { $0 + $1.target }) / count,
            Double(rirObservations.reduce(0) { $0 + $1.estimated }) / count,
            rirObservations.count
        )
    }

    var completedSessionCount: Int { completedSessionIDs.count }

    init(
        sessions: [WorkoutSession],
        prescriptions: [WorkoutExercisePrescription],
        workoutSetLogs: [WorkoutSetLog],
        completedWorkouts: [CompletedWorkout],
        catalog: [TrainingExerciseCatalogItem]
    ) {
        self.sessions = sessions
        let prescriptionsBySessionID = Dictionary(grouping: prescriptions, by: \.sessionID)
            .mapValues { $0.sorted { $0.order < $1.order } }
        self.prescriptionsBySessionID = prescriptionsBySessionID
        let plannedPrescriptionIDs = Set(prescriptions.map(\.id))
        let sessionIDs = Set(sessions.map(\.id))
        var completedSetNumbersByPrescriptionID: [UUID: Set<Int>] = [:]
        var attemptsBySessionID: [UUID: [String: [UUID: Set<Int>]]] = [:]
        let sessionIDByPrescriptionID = Dictionary(uniqueKeysWithValues: prescriptions.map { ($0.id, $0.sessionID) })
        func attemptKey(for log: WorkoutSetLog) -> String {
            if let workoutID = log.workoutID { return workoutID.uuidString }
            return String(Calendar.current.startOfDay(for: log.performedAt).timeIntervalSince1970)
        }
        for log in workoutSetLogs where log.isComplete && !log.isWarmup && plannedPrescriptionIDs.contains(log.prescriptionID) {
            completedSetNumbersByPrescriptionID[log.prescriptionID, default: []].insert(log.setNumber)
            if let sessionID = sessionIDByPrescriptionID[log.prescriptionID] {
                attemptsBySessionID[sessionID, default: [:]][attemptKey(for: log), default: [:]][log.prescriptionID, default: []].insert(log.setNumber)
            }
        }
        for workout in completedWorkouts where workout.sourceSessionID.map(sessionIDs.contains) == true {
            guard let sessionID = workout.sourceSessionID else { continue }
            let prescriptionIDByExerciseID = Dictionary(uniqueKeysWithValues: workout.exercises.compactMap { exercise in
                exercise.sourcePrescriptionID.map { (exercise.id, $0) }
            })
            for log in workout.completedWorkingSets {
                guard let prescriptionID = prescriptionIDByExerciseID[log.prescriptionID],
                      plannedPrescriptionIDs.contains(prescriptionID) else { continue }
                completedSetNumbersByPrescriptionID[prescriptionID, default: []].insert(log.setNumber)
                attemptsBySessionID[sessionID, default: [:]][workout.id.uuidString, default: [:]][prescriptionID, default: []].insert(log.setNumber)
            }
        }
        let completedPrescriptionIDs = Set(prescriptions.filter { prescription in
            guard prescription.sets > 0, let sessionID = sessionIDByPrescriptionID[prescription.id] else { return false }
            return attemptsBySessionID[sessionID]?.values.contains(where: {
                ($0[prescription.id]?.count ?? 0) >= prescription.sets
            }) == true
        }.map(\.id))
        self.completedPrescriptionIDs = completedPrescriptionIDs
        self.completedSessionIDs = Set(sessions.compactMap { session in
            guard let sessionPrescriptions = prescriptionsBySessionID[session.id], !sessionPrescriptions.isEmpty else { return nil }
            let hasCompleteAttempt = attemptsBySessionID[session.id]?.values.contains { attempt in
                sessionPrescriptions.allSatisfy { prescription in
                    prescription.sets > 0 && (attempt[prescription.id]?.count ?? 0) >= prescription.sets
                }
            } == true
            return hasCompleteAttempt ? session.id : nil
        })
        self.completedSetCount = prescriptions.reduce(0) { total, prescription in
            let logged = completedSetNumbersByPrescriptionID[prescription.id]?.count ?? 0
            return total + min(prescription.sets, logged)
        }
        var rirPairByPrescriptionAndSet: [UUID: [Int: (performedAt: Date, target: Int, estimated: Int)]] = [:]
        func includeRPE(_ log: WorkoutSetLog, for prescriptionID: UUID, targetRIR: Int?) {
            guard let targetRIR, let rpe = log.rpe, (1...10).contains(rpe) else { return }
            if let previous = rirPairByPrescriptionAndSet[prescriptionID]?[log.setNumber],
               previous.performedAt >= log.performedAt {
                return
            }
            rirPairByPrescriptionAndSet[prescriptionID, default: [:]][log.setNumber] = (
                log.performedAt,
                targetRIR,
                10 - rpe
            )
        }
        for workout in completedWorkouts where workout.sourceSessionID.map(sessionIDs.contains) == true {
            let exerciseByID = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
            for log in workout.completedWorkingSets {
                guard let exercise = exerciseByID[log.prescriptionID],
                      let prescriptionID = exercise.sourcePrescriptionID,
                      plannedPrescriptionIDs.contains(prescriptionID) else { continue }
                includeRPE(log, for: prescriptionID, targetRIR: exercise.targetRIR)
            }
        }
        let targetRIRByPrescriptionID = Dictionary(uniqueKeysWithValues: prescriptions.map { ($0.id, $0.targetRIR) })
        for log in workoutSetLogs where log.isComplete && !log.isWarmup && plannedPrescriptionIDs.contains(log.prescriptionID) {
            includeRPE(
                log,
                for: log.prescriptionID,
                targetRIR: targetRIRByPrescriptionID[log.prescriptionID] ?? nil
            )
        }
        self.rirObservations = rirPairByPrescriptionAndSet.values.flatMap { $0.values.map { (target: $0.target, estimated: $0.estimated) } }
        catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        completion = plannedPrescriptionIDs.isEmpty
            ? 0
            : Double(plannedPrescriptionIDs.intersection(completedPrescriptionIDs).count) /
                Double(plannedPrescriptionIDs.count)
    }
}

@MainActor
final class ProgramStore {
    private let repository: any ProgramRepository
    private let now: () -> Date
    private let makeID: () -> UUID
    private var cachedGraphRevision: Int?
    private var cachedGraph: ProgramGraphIndex?
    private var cachedCurrentWeekSignature: ProgramCurrentWeekSignature?
    private var cachedCurrentWeek: WorkoutWeek?
    private var cachedWeekPresentationSignature: ProgramWeekPresentationSignature?
    private var cachedWeekPresentation: ProgramWeekPresentation?

    init(
        repository: any ProgramRepository,
        now: @escaping () -> Date = { .now },
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.now = now
        self.makeID = makeID
    }

    var plans: [WorkoutPlan] { repository.workoutPlans }

    func plan(id: UUID) -> WorkoutPlan? {
        graph().plansByID[id]
    }

    func phases(planID: UUID) -> [WorkoutPhase] {
        graph().phasesByPlanID[planID] ?? []
    }

    func weeks(planID: UUID) -> [WorkoutWeek] {
        graph().weeksByPlanID[planID] ?? []
    }

    func currentWeek(planID: UUID) -> WorkoutWeek? {
        let referenceDate = now()
        let signature = ProgramCurrentWeekSignature(
            planID: planID,
            referenceDay: Calendar.current.startOfDay(for: referenceDate),
            programDataRevision: repository.programDataRevision
        )
        if cachedCurrentWeekSignature == signature {
            return cachedCurrentWeek
        }
        let week = repository.currentProgramWeek(planID: planID, at: referenceDate)
        cachedCurrentWeek = week
        cachedCurrentWeekSignature = signature
        return week
    }

    func sessions(week: WorkoutWeek) -> [WorkoutSession] {
        graph().sessionsByWeekID[week.id] ?? []
    }

    func queueEnabled(planID: UUID) -> Bool {
        plan(id: planID)?.queueEnabled == true
    }

    func queuedSessions(planID: UUID) -> [WorkoutSession] {
        guard let plan = plan(id: planID) else { return [] }
        let sessionsByID = Dictionary(uniqueKeysWithValues: weeks(planID: planID).flatMap { sessions(week: $0) }.map { ($0.id, $0) })
        return plan.queuedSessionIDs.compactMap { sessionsByID[$0] }
    }

    @discardableResult
    func setQueue(planID: UUID, enabled: Bool, sessionIDs: [UUID]? = nil, allowsAnyOrder: Bool = false) -> Bool {
        let current = plan(id: planID)?.queuedSessionIDs ?? []
        let available = weeks(planID: planID).flatMap { sessions(week: $0) }.map(\.id)
        let resolved: [UUID]
        if let sessionIDs {
            resolved = sessionIDs
        } else if enabled {
            let retained = current.filter(available.contains)
            resolved = retained + available.filter { !retained.contains($0) }
        } else {
            resolved = current
        }
        return repository.updateWorkoutQueue(planID: planID, enabled: enabled, sessionIDs: resolved, allowsAnyOrder: allowsAnyOrder)
    }

    @discardableResult
    func reorderQueue(planID: UUID, sessionIDs: [UUID]) -> Bool {
        guard let plan = plan(id: planID), plan.queueEnabled else { return false }
        return repository.updateWorkoutQueue(planID: planID, enabled: true, sessionIDs: sessionIDs, allowsAnyOrder: plan.allowsAnyOrder)
    }

    func availableFlexibleSessions(planID: UUID, completedWorkouts: [CompletedWorkout]) -> [WorkoutSession] {
        guard plan(id: planID)?.scheduleMode == .flexible else { return [] }
        let completedIDs = Set(completedWorkouts.compactMap(\.sourceSessionID))
        return weeks(planID: planID).flatMap { sessions(week: $0) }.filter {
            $0.outcome == nil && !completedIDs.contains($0.id) && !prescriptions(session: $0).isEmpty
        }
    }

    func nextQueuedSession(planID: UUID, completedWorkouts: [CompletedWorkout]) -> WorkoutSession? {
        let completedSessionIDs = Set(completedWorkouts.compactMap(\.sourceSessionID))
        return queuedSessions(planID: planID).first { session in
            session.outcome == nil && !completedSessionIDs.contains(session.id) && !prescriptions(session: session).isEmpty
        }
    }

    func prescriptions(session: WorkoutSession) -> [WorkoutExercisePrescription] {
        repository.resolvedWorkoutPrescriptions(sessionID: session.id, at: now())
    }

    func nextPrescription(after workout: CompletedWorkout, exercise: WorkoutExerciseSnapshot, completedWorkouts: [CompletedWorkout]) -> WorkoutExercisePrescription? {
        guard let planID = workout.sourcePlanID, let sessionID = workout.sourceSessionID else { return nil }
        let ordered = queueEnabled(planID: planID) ? queuedSessions(planID: planID)
            : weeks(planID: planID).flatMap { sessions(week: $0) }
        guard let index = ordered.firstIndex(where: { $0.id == sessionID }) else { return nil }
        let completed = Set(completedWorkouts.compactMap(\.sourceSessionID))
        for session in ordered.dropFirst(index + 1) where session.outcome == nil && !completed.contains(session.id) {
            if let prescription = prescriptions(session: session).first(where: {
                $0.exerciseID == exercise.exerciseID && $0.reps == exercise.targetReps
            }) { return prescription }
        }
        return nil
    }

    func weekPresentation(
        for week: WorkoutWeek,
        workoutSetLogs: [WorkoutSetLog],
        workoutSetLogsRevision: Int,
        completedWorkouts: [CompletedWorkout],
        completedWorkoutsRevision: Int,
        catalog: [TrainingExerciseCatalogItem],
        accountID: UUID,
        customTrainingExercisesRevision: Int
    ) -> ProgramWeekPresentation {
        let signature = ProgramWeekPresentationSignature(
            weekID: week.id,
            accountID: accountID,
            programDataRevision: repository.programDataRevision,
            workoutSetLogsRevision: workoutSetLogsRevision,
            completedWorkoutsRevision: completedWorkoutsRevision,
            customTrainingExercisesRevision: customTrainingExercisesRevision
        )
        if let cachedWeekPresentation,
           cachedWeekPresentationSignature == signature {
            return cachedWeekPresentation
        }

        let programGraph = graph()
        let sessions = programGraph.sessionsByWeekID[week.id] ?? []
        let presentation = ProgramWeekPresentation(
            sessions: sessions,
            prescriptions: sessions.flatMap { prescriptions(session: $0) },
            workoutSetLogs: workoutSetLogs,
            completedWorkouts: completedWorkouts,
            catalog: catalog
        )
        cachedWeekPresentationSignature = signature
        cachedWeekPresentation = presentation
        return presentation
    }

    private func graph() -> ProgramGraphIndex {
        let revision = repository.programDataRevision
        if let cachedGraph, cachedGraphRevision == revision {
            return cachedGraph
        }
        let graph = ProgramGraphIndex(repository: repository)
        cachedGraph = graph
        cachedGraphRevision = revision
        return graph
    }

    @discardableResult
    func createPlan(name: String, isActive: Bool = true, startDate: Date? = nil, schedule: WorkoutScheduleMode = .weekdays) -> WorkoutPlan? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let plan = WorkoutPlan(
            id: makeID(),
            name: cleanName,
            createdAt: now(),
            goal: "Build strength and muscle",
            notes: "",
            isActive: isActive,
            queueEnabled: schedule != .weekdays,
            allowsAnyOrder: schedule == .flexible
        )
        repository.addWorkoutPlan(plan)
        if let startDate {
            for week in weeks(planID: plan.id) {
                for session in sessions(week: week) { repository.deleteWorkoutSession(session) }
            }
            repository.workoutPlanProgressionSettings.append(WorkoutPlanProgressionSettings(
                planID: plan.id, sourceTemplateID: "custom", sourceTemplateVersion: 1,
                startedAt: Calendar.current.startOfDay(for: startDate), scheduledWeekdays: [],
                method: .fixed, preferredUnit: .kilograms,
                trainingMaxKilograms: [:]
            ))
        }
        return plan
    }

    static func importedSetCount(for exercise: WorkoutExerciseSnapshot, in workout: CompletedWorkout) -> Int {
        let count = Set(workout.completedWorkingSets
            .filter { $0.prescriptionID == exercise.id }.map(\.setNumber)).count
        return max(1, count > 0 ? count : exercise.targetSets)
    }

    static func importedLoadKilograms(for exercise: WorkoutExerciseSnapshot, in workout: CompletedWorkout) -> Double? {
        if let latestSet = workout.completedWorkingSets
            .filter({ $0.prescriptionID == exercise.id && $0.weight.map { $0.isFinite && $0 >= 0 } == true })
            .max(by: { $0.performedAt < $1.performedAt }), let weight = latestSet.weight {
            return MeasurementFormatting.normalizeToKilograms(weight, unit: latestSet.recordedUnit)
        }
        return exercise.targetLoadKilograms
    }

    @discardableResult
    func createPlanFromHistory(
        name: String,
        assignments: [(workout: CompletedWorkout, weekday: Int)],
        durationWeeks: Int,
        startDate: Date,
        preferredUnit: UnitSystem,
        schedule: WorkoutScheduleMode = .weekdays
    ) -> WorkoutPlan? {
        let weekdays = assignments.map(\.weekday)
        guard (1...52).contains(durationWeeks),
              !assignments.isEmpty,
              Set(weekdays).count == weekdays.count,
              weekdays.allSatisfy({ (1...7).contains($0) }),
              let plan = createPlan(name: name, isActive: false, schedule: schedule) else { return nil }

        let settings = WorkoutPlanProgressionSettings(
            planID: plan.id,
            sourceTemplateID: "custom-history",
            sourceTemplateVersion: 1,
            startedAt: Calendar.current.startOfDay(for: startDate),
            scheduledWeekdays: weekdays.sorted(),
            method: .fixed,
            preferredUnit: preferredUnit,
            trainingMaxKilograms: [:]
        )
        repository.workoutPlanProgressionSettings.append(settings)

        guard let firstWeek = repository.workoutWeeks.first(where: { $0.planID == plan.id }) else {
            repository.deleteWorkoutPlan(plan)
            return nil
        }
        if let scaffoldSession = repository.workoutSessions.first(where: { $0.weekID == firstWeek.id }) {
            repository.deleteWorkoutSession(scaffoldSession)
        }

        for weekNumber in 1...durationWeeks {
            let week = weekNumber == 1
                ? firstWeek
                : repository.addWorkoutWeek(planID: plan.id, phaseID: firstWeek.phaseID, title: "Week \(weekNumber)")
            if weekNumber == 1,
               var phase = repository.workoutPhases.first(where: { $0.planID == plan.id }) {
                phase.durationWeeks = durationWeeks
                phase.goal = "Repeat the selected workout prescriptions as written."
                repository.updateWorkoutPhase(phase)
            }

            for assignment in assignments.sorted(by: { $0.weekday < $1.weekday }) {
                let session = repository.addWorkoutSession(
                    weekID: week.id,
                    day: Calendar.current.weekdayName(for: assignment.weekday),
                    name: assignment.workout.name
                )
                let orderedExercises = assignment.workout.exercises.sorted { $0.order < $1.order }
                for (exerciseOrder, exercise) in orderedExercises.enumerated() {
                    _ = repository.addWorkoutPrescription(WorkoutExercisePrescription(
                        id: makeID(),
                        sessionID: session.id,
                        exerciseID: exercise.exerciseID,
                        exerciseName: exercise.exerciseName,
                        bodyPart: exercise.bodyPart,
                        equipment: exercise.equipment,
                        sets: Self.importedSetCount(for: exercise, in: assignment.workout),
                        reps: exercise.targetReps,
                        restSeconds: exercise.restSeconds,
                        order: exerciseOrder,
                        notes: exercise.notes,
                        substitutionExerciseIDs: exercise.substitutionExerciseIDs,
                        muscleProfile: exercise.muscleProfile,
                        targetRIR: exercise.targetRIR,
                        trainingMaxPercentage: exercise.trainingMaxPercentage,
                        targetLoadKilograms: Self.importedLoadKilograms(for: exercise, in: assignment.workout),
                        supersetGroup: exercise.supersetGroup,
                        supersetRestSeconds: exercise.supersetRestSeconds
                    ))
                }
            }
        }
        if schedule != .weekdays {
            _ = setQueue(planID: plan.id, enabled: true, allowsAnyOrder: schedule == .flexible)
        }
        return self.plan(id: plan.id)
    }

    func shareablePlanText(planID: UUID) -> String? {
        guard let plan = plan(id: planID) else { return nil }
        let phaseIDs = Set(repository.workoutPhases.filter { $0.planID == planID }.map(\.id))
        let weeks = repository.workoutWeeks.filter { $0.planID == planID }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = repository.workoutSessions.filter { weekIDs.contains($0.weekID) }
        let sessionIDs = Set(sessions.map(\.id))
        let payload = WorkoutPlanSyncPayload(
            plan: plan,
            phases: repository.workoutPhases.filter { phaseIDs.contains($0.id) },
            weeks: weeks,
            sessions: sessions,
            prescriptions: repository.workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) },
            progression: repository.workoutPlanProgressionSettings.first { $0.planID == planID }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func importSharedPlan(_ text: String) -> WorkoutPlan? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count <= 1_000_000,
              let data = trimmed.data(using: .utf8),
              let shared = try? JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: data),
              isValidSharedPlan(shared) else { return nil }

        let newPlanID = makeID()
        var payload = shared.conflictCopy(documentID: newPlanID, makeUUID: makeID)
        let cleanName = shared.plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        payload.plan.name = "\(cleanName) (Copy)"
        payload.plan.createdAt = now()
        payload.plan.isActive = false
        payload.plan.queueEnabled = false
        payload.plan.allowsAnyOrder = false
        payload.plan.queuedSessionIDs = []
        repository.addWorkoutPlan(payload.plan)

        guard let scaffoldPhase = repository.workoutPhases.first(where: { $0.planID == newPlanID }),
              let scaffoldWeek = repository.workoutWeeks.first(where: { $0.planID == newPlanID }) else {
            repository.deleteWorkoutPlan(payload.plan)
            return nil
        }
        repository.deleteWorkoutWeek(scaffoldWeek)
        let orderedPhases = payload.phases.sorted { $0.order < $1.order }
        guard let firstPhase = orderedPhases.first else {
            repository.deleteWorkoutPlan(payload.plan)
            return nil
        }
        var phaseIDMap: [UUID: UUID] = [firstPhase.id: scaffoldPhase.id]
        var savedFirstPhase = firstPhase
        savedFirstPhase.id = scaffoldPhase.id
        savedFirstPhase.planID = newPlanID
        repository.updateWorkoutPhase(savedFirstPhase)
        for phase in orderedPhases.dropFirst() {
            repository.addWorkoutPhase(phase)
            phaseIDMap[phase.id] = phase.id
        }

        var weekIDMap: [UUID: UUID] = [:]
        for sourceWeek in payload.weeks.sorted(by: { $0.weekNumber < $1.weekNumber }) {
            let phaseID = phaseIDMap[sourceWeek.phaseID] ?? sourceWeek.phaseID
            let newWeek = repository.addWorkoutWeek(planID: newPlanID, phaseID: phaseID, title: sourceWeek.title)
            var updatedWeek = newWeek
            updatedWeek.weekNumber = sourceWeek.weekNumber
            updatedWeek.notes = sourceWeek.notes
            repository.updateWorkoutWeek(updatedWeek)
            weekIDMap[sourceWeek.id] = newWeek.id
        }

        var sessionIDMap: [UUID: UUID] = [:]
        for sourceSession in payload.sessions.sorted(by: { $0.order < $1.order }) {
            guard let weekID = weekIDMap[sourceSession.weekID] else { continue }
            let newSession = repository.addWorkoutSession(weekID: weekID, day: sourceSession.day, name: sourceSession.name)
            var updatedSession = newSession
            updatedSession.order = sourceSession.order
            updatedSession.notes = sourceSession.notes
            updatedSession.outcome = nil
            repository.updateWorkoutSession(updatedSession)
            sessionIDMap[sourceSession.id] = newSession.id
        }
        for sourcePrescription in payload.prescriptions {
            guard let sessionID = sessionIDMap[sourcePrescription.sessionID] else { continue }
            var prescription = sourcePrescription
            prescription.id = makeID()
            prescription.sessionID = sessionID
            _ = repository.addWorkoutPrescription(prescription)
        }
        if var progression = payload.progression {
            progression.planID = newPlanID
            repository.workoutPlanProgressionSettings.append(progression)
        }
        return payload.plan
    }

    private func isValidSharedPlan(_ payload: WorkoutPlanSyncPayload) -> Bool {
        guard !payload.plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...50).contains(payload.phases.count),
              (1...104).contains(payload.weeks.count),
              !payload.sessions.isEmpty, payload.sessions.count <= 1_000,
              payload.prescriptions.count <= 10_000,
              Set(payload.phases.map(\.id)).count == payload.phases.count,
              Set(payload.weeks.map(\.id)).count == payload.weeks.count,
              Set(payload.sessions.map(\.id)).count == payload.sessions.count,
              Set(payload.prescriptions.map(\.id)).count == payload.prescriptions.count else { return false }
        let phaseIDs = Set(payload.phases.filter { $0.planID == payload.plan.id }.map(\.id))
        let weeks = payload.weeks.filter { $0.planID == payload.plan.id }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = payload.sessions.filter { weekIDs.contains($0.weekID) }
        let sessionIDs = Set(sessions.map(\.id))
        return phaseIDs.count == payload.phases.count &&
            weeks.count == payload.weeks.count &&
            weeks.allSatisfy { phaseIDs.contains($0.phaseID) } &&
            sessions.count == payload.sessions.count &&
            payload.prescriptions.allSatisfy { sessionIDs.contains($0.sessionID) }
    }

    @discardableResult
    func saveWorkoutAsRoutine(_ workout: CompletedWorkout, name: String? = nil) -> WorkoutPlan? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let routineName = trimmedName.isEmpty ? "\(workout.name) Routine" : trimmedName
        guard let plan = createPlan(name: routineName),
              let week = weeks(planID: plan.id).first,
              let originalSession = sessions(week: week).first else { return nil }
        repository.deleteWorkoutSession(originalSession)
        let session = repository.addWorkoutSession(weekID: week.id, day: workout.dayLabel, name: workout.name)
        for (index, exercise) in workout.exercises.enumerated() {
            _ = repository.addWorkoutPrescription(
                WorkoutExercisePrescription(
                    id: makeID(),
                    sessionID: session.id,
                    exerciseID: exercise.exerciseID,
                    exerciseName: exercise.exerciseName,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    sets: max(1, exercise.targetSets),
                    reps: exercise.targetReps,
                    restSeconds: exercise.restSeconds,
                    order: index,
                    notes: exercise.notes,
                    substitutionExerciseIDs: exercise.substitutionExerciseIDs,
                    muscleProfile: exercise.muscleProfile,
                    targetRIR: exercise.targetRIR,
                    trainingMaxPercentage: exercise.trainingMaxPercentage,
                    targetLoadKilograms: exercise.targetLoadKilograms
                )
            )
        }
        return plan
    }

    @discardableResult
    func renamePlan(id: UUID, to name: String) -> Bool {
        guard var plan = plan(id: id) else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        plan.name = cleanName
        repository.updateWorkoutPlan(plan)
        return true
    }

    @discardableResult
    func updatePlanNotes(id: UUID, notes: String) -> Bool {
        guard var plan = plan(id: id) else { return false }
        plan.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        repository.updateWorkoutPlan(plan)
        return true
    }

    @discardableResult
    func duplicatePlan(id: UUID) -> WorkoutPlan? {
        guard let plan = plan(id: id) else { return nil }
        return repository.duplicateWorkoutPlan(plan)
    }

    @discardableResult
    func deletePlan(id: UUID) -> ProgramPlanDeletion? {
        guard let plan = plan(id: id) else { return nil }
        repository.deleteWorkoutPlan(plan)
        return ProgramPlanDeletion(deletedPlanID: id)
    }

    @discardableResult
    func addWeek(planID: UUID) -> WorkoutWeek {
        repository.addWorkoutWeek(planID: planID, phaseID: nil, title: nil)
    }

    @discardableResult
    func cloneWeek(_ week: WorkoutWeek) -> WorkoutWeek {
        repository.cloneWorkoutWeek(week)
    }

    func deleteWeek(_ week: WorkoutWeek) {
        repository.deleteWorkoutWeek(week)
    }

    @discardableResult
    func addSession(to week: WorkoutWeek, day: String, name: String) -> WorkoutSession {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = repository.addWorkoutSession(
            weekID: week.id,
            day: day,
            name: cleanName.isEmpty ? "Workout" : cleanName
        )
        if let plan = plan(id: week.planID), plan.queueEnabled {
            _ = setQueue(planID: plan.id, enabled: true, sessionIDs: plan.queuedSessionIDs + [session.id], allowsAnyOrder: plan.allowsAnyOrder)
        }
        return session
    }

    @discardableResult
    func startFreestyleSession(in week: WorkoutWeek, day: String) -> WorkoutSession {
        addSession(to: week, day: day, name: "Freestyle Workout")
    }

    func duplicateSession(_ session: WorkoutSession, day: String, weekID: UUID? = nil) -> WorkoutSession? {
        guard let sourceWeek = repository.workoutWeeks.first(where: { $0.id == session.weekID }),
              let week = repository.workoutWeeks.first(where: { $0.id == (weekID ?? session.weekID) && $0.planID == sourceWeek.planID }),
              !sessions(week: week).contains(where: { $0.day.caseInsensitiveCompare(day) == .orderedSame }) else { return nil }
        var copy = repository.addWorkoutSession(weekID: week.id, day: day, name: session.name)
        copy.notes = session.notes
        repository.updateWorkoutSession(copy)
        for prescription in repository.workoutPrescriptions.filter({ $0.sessionID == session.id }) {
            var copied = prescription
            copied.id = makeID()
            copied.sessionID = copy.id
            _ = repository.addWorkoutPrescription(copied)
        }
        return copy
    }

    func rescheduleSession(_ session: WorkoutSession, day: String, weekID: UUID? = nil) -> Bool {
        guard repository.workoutSessions.contains(where: { $0.id == session.id }),
              let sourceWeek = repository.workoutWeeks.first(where: { $0.id == session.weekID }),
              let week = repository.workoutWeeks.first(where: { $0.id == (weekID ?? session.weekID) && $0.planID == sourceWeek.planID }),
              !repository.workoutSessions.contains(where: {
                  $0.weekID == week.id && $0.id != session.id && $0.day.caseInsensitiveCompare(day) == .orderedSame
              }) else { return false }
        var updated = session
        updated.day = day
        if updated.weekID != week.id {
            updated.weekID = week.id
            updated.order = (sessions(week: week).map(\.order).max() ?? -1) + 1
        }
        repository.updateWorkoutSession(updated)
        return true
    }

    func scheduleSession(_ session: WorkoutSession, on date: Date, duplicate: Bool) -> WorkoutSession? {
        guard repository.workoutSessions.contains(where: { $0.id == session.id }),
              let sourceWeek = repository.workoutWeeks.first(where: { $0.id == session.weekID }) else { return nil }
        let calendar = Calendar.current
        let existingSettings = repository.workoutPlanProgressionSettings.first { $0.planID == sourceWeek.planID }
        guard let start = existingSettings?.startedAt ?? calendar.dateInterval(of: .weekOfYear, for: now())?.start else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? -1
        let number = days / 7 + 1
        let planWeeks = weeks(planID: sourceWeek.planID)
        guard days >= 0, number <= (planWeeks.map(\.weekNumber).max() ?? 0) + 1 else { return nil }
        let day = calendar.weekdayName(for: calendar.component(.weekday, from: date))
        if let week = planWeeks.first(where: { $0.weekNumber == number }),
           sessions(week: week).contains(where: { (duplicate || $0.id != session.id) && $0.day.caseInsensitiveCompare(day) == .orderedSame }) { return nil }
        if existingSettings == nil {
            repository.workoutPlanProgressionSettings.append(WorkoutPlanProgressionSettings(
                planID: sourceWeek.planID, sourceTemplateID: "custom", sourceTemplateVersion: 1,
                startedAt: start, scheduledWeekdays: [], method: .fixed,
                preferredUnit: .kilograms, trainingMaxKilograms: [:]
            ))
        }
        let week = planWeeks.first { $0.weekNumber == number } ?? addWeek(planID: sourceWeek.planID)
        if duplicate { return duplicateSession(session, day: day, weekID: week.id) }
        guard rescheduleSession(session, day: day, weekID: week.id) else { return nil }
        return repository.workoutSessions.first { $0.id == session.id }
    }

    func deleteSession(_ session: WorkoutSession) {
        repository.deleteWorkoutSession(session)
    }

    func cancelSession(_ session: WorkoutSession) {
        repository.cancelWorkoutSession(session)
    }

    func setSessionOutcome(_ session: WorkoutSession, outcome: WorkoutSessionOutcome?) {
        repository.setWorkoutSessionOutcome(session, outcome: outcome)
    }

    func addExercises(_ exercises: [TrainingExerciseCatalogItem], to session: WorkoutSession) {
        let nextOrder = prescriptions(session: session).count
        for (offset, exercise) in exercises.enumerated() {
            _ = repository.addWorkoutPrescription(
                WorkoutExercisePrescription(
                    id: makeID(),
                    sessionID: session.id,
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    sets: exercise.defaultSets,
                    reps: exercise.defaultReps,
                    restSeconds: exercise.defaultRestSeconds,
                    order: nextOrder + offset,
                    notes: ""
                )
            )
        }
    }

    @discardableResult
    func addExercise(
        _ exercise: TrainingExerciseCatalogItem,
        to session: WorkoutSession,
        sets: Int,
        reps: String,
        restSeconds: Int
    ) -> WorkoutExercisePrescription {
        let cleanReps = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        return repository.addWorkoutPrescription(
            WorkoutExercisePrescription(
                id: makeID(),
                sessionID: session.id,
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                bodyPart: exercise.bodyPart,
                equipment: exercise.equipment,
                sets: max(1, sets),
                reps: cleanReps.isEmpty ? "8-12" : cleanReps,
                restSeconds: restSeconds,
                order: prescriptions(session: session).count,
                notes: ""
            )
        )
    }

    func deletePrescription(_ prescription: WorkoutExercisePrescription) {
        repository.deleteWorkoutPrescription(prescription)
    }

    @discardableResult
    func setSuperset(sessionID: UUID, exerciseIDs: [UUID], restSeconds: Int) -> Bool {
        guard exerciseIDs.count == 2, Set(exerciseIDs).count == 2, (15...300).contains(restSeconds) else { return false }
        let pair = repository.workoutPrescriptions.filter {
            $0.sessionID == sessionID && exerciseIDs.contains($0.id)
        }
        guard pair.count == 2 else { return false }
        for prescription in pair {
            removeSuperset(sessionID: sessionID, exerciseID: prescription.id)
        }
        let group = makeID().uuidString
        for var prescription in pair {
            prescription.supersetGroup = group
            prescription.supersetRestSeconds = restSeconds
            repository.updateWorkoutPrescription(prescription)
        }
        return true
    }

    func removeSuperset(sessionID: UUID, exerciseID: UUID) {
        guard let selected = repository.workoutPrescriptions.first(where: { $0.id == exerciseID && $0.sessionID == sessionID }),
              let group = selected.supersetGroup else { return }
        for var prescription in repository.workoutPrescriptions where prescription.sessionID == sessionID && prescription.supersetGroup == group {
            prescription.supersetGroup = nil
            prescription.supersetRestSeconds = nil
            repository.updateWorkoutPrescription(prescription)
        }
    }

    @discardableResult
    func updatePrescription(
        _ edited: WorkoutExercisePrescription,
        scope: WorkoutPrescriptionEditScope,
        excludingSessionIDs: Set<UUID>
    ) -> Int {
        guard let sourceSession = repository.workoutSessions.first(where: { $0.id == edited.sessionID }),
              let sourceWeek = repository.workoutWeeks.first(where: { $0.id == sourceSession.weekID }),
              repository.workoutPrescriptions.contains(where: { $0.id == edited.id }) else { return 0 }

        let targetSessions = repository.workoutSessions.filter { session in
            guard let week = repository.workoutWeeks.first(where: { $0.id == session.weekID }),
                  week.planID == sourceWeek.planID,
                  session.name.caseInsensitiveCompare(sourceSession.name) == .orderedSame else { return false }
            switch scope {
            case .thisWorkout:
                return session.id == sourceSession.id
            case .matchingWorkouts:
                return true
            case .futureWeeks:
                return week.weekNumber >= sourceWeek.weekNumber
            }
        }

        let sourceOccurrences = repository.workoutPrescriptions
            .filter { $0.sessionID == sourceSession.id && $0.exerciseID == edited.exerciseID }
            .sorted { $0.order < $1.order }
        guard let occurrence = sourceOccurrences.firstIndex(where: { $0.id == edited.id }) else { return 0 }
        var updatedCount = 0
        for session in targetSessions where !excludingSessionIDs.contains(session.id) && session.outcome == nil {
            let matches = repository.workoutPrescriptions
                .filter { $0.sessionID == session.id && $0.exerciseID == edited.exerciseID }
                .sorted { $0.order < $1.order }
            if matches.indices.contains(occurrence) {
                var prescription = matches[occurrence]
                prescription.sets = edited.sets
                prescription.reps = edited.reps
                prescription.restSeconds = edited.restSeconds
                prescription.targetRIR = edited.targetRIR
                prescription.targetLoadKilograms = edited.targetLoadKilograms
                prescription.substitutionExerciseIDs = edited.substitutionExerciseIDs
                repository.updateWorkoutPrescription(prescription)
                updatedCount += 1
            }
        }
        return updatedCount
    }

    @discardableResult
    func startProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        preferredUnit: UnitSystem,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan? {
        guard method != .linear || template.defaultProgression == .linear,
              scheduledWeekdays.count == template.sessions.count,
              Set(scheduledWeekdays).count == scheduledWeekdays.count,
              scheduledWeekdays.allSatisfy({ (1...7).contains($0) }) else { return nil }
        if method == .percentage {
            guard template.requiredTrainingMaxExerciseIDs.allSatisfy({ (trainingMaxKilograms[$0] ?? 0) > 0 }) else {
                return nil
            }
        }
        return repository.startWorkoutProgram(
            template: template,
            startDate: startDate,
            scheduledWeekdays: scheduledWeekdays,
            method: method,
            preferredUnit: preferredUnit,
            trainingMaxKilograms: trainingMaxKilograms
        )
    }

    @discardableResult
    func changeProgression(
        planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double]
    ) -> Bool {
        repository.changeWorkoutProgramProgression(
            planID: planID,
            method: method,
            trainingMaxKilograms: trainingMaxKilograms,
            at: now()
        )
    }
}

@MainActor
private struct ProgramGraphIndex {
    let plansByID: [UUID: WorkoutPlan]
    let phasesByPlanID: [UUID: [WorkoutPhase]]
    let weeksByPlanID: [UUID: [WorkoutWeek]]
    let sessionsByWeekID: [UUID: [WorkoutSession]]
    let prescriptionsBySessionID: [UUID: [WorkoutExercisePrescription]]

    init(repository: any ProgramRepository) {
        plansByID = Dictionary(uniqueKeysWithValues: repository.workoutPlans.map { ($0.id, $0) })
        phasesByPlanID = Dictionary(grouping: repository.workoutPhases, by: \.planID)
            .mapValues { $0.sorted { $0.order < $1.order } }
        weeksByPlanID = Dictionary(grouping: repository.workoutWeeks, by: \.planID)
            .mapValues { $0.sorted { $0.weekNumber < $1.weekNumber } }
        sessionsByWeekID = Dictionary(grouping: repository.workoutSessions, by: \.weekID)
            .mapValues { $0.sorted { $0.order < $1.order } }
        prescriptionsBySessionID = Dictionary(grouping: repository.workoutPrescriptions, by: \.sessionID)
            .mapValues { $0.sorted { $0.order < $1.order } }
    }
}

private struct ProgramCurrentWeekSignature: Equatable {
    let planID: UUID
    let referenceDay: Date
    let programDataRevision: Int
}

private struct ProgramWeekPresentationSignature: Equatable {
    let weekID: UUID
    let accountID: UUID
    let programDataRevision: Int
    let workoutSetLogsRevision: Int
    let completedWorkoutsRevision: Int
    let customTrainingExercisesRevision: Int
}
