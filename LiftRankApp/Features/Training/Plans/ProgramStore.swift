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
    func setQueue(planID: UUID, enabled: Bool, sessionIDs: [UUID]? = nil) -> Bool {
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
        return repository.updateWorkoutQueue(planID: planID, enabled: enabled, sessionIDs: resolved)
    }

    @discardableResult
    func reorderQueue(planID: UUID, sessionIDs: [UUID]) -> Bool {
        guard let plan = plan(id: planID), plan.queueEnabled else { return false }
        return repository.updateWorkoutQueue(planID: planID, enabled: true, sessionIDs: sessionIDs)
    }

    func nextQueuedSession(planID: UUID, completedWorkouts: [CompletedWorkout]) -> WorkoutSession? {
        let completedSessionIDs = Set(completedWorkouts.compactMap(\.sourceSessionID))
        return queuedSessions(planID: planID).first { session in
            session.outcome == nil && !completedSessionIDs.contains(session.id) && !prescriptions(session: session).isEmpty
        }
    }

    func prescriptions(session: WorkoutSession) -> [WorkoutExercisePrescription] {
        graph().prescriptionsBySessionID[session.id] ?? []
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
            prescriptions: sessions.flatMap { programGraph.prescriptionsBySessionID[$0.id] ?? [] },
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
    func createPlan(name: String) -> WorkoutPlan? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let plan = WorkoutPlan(
            id: makeID(),
            name: cleanName,
            createdAt: now(),
            goal: "Build strength and muscle",
            notes: "",
            isActive: true
        )
        repository.addWorkoutPlan(plan)
        return plan
    }

    @discardableResult
    func saveWorkoutAsRoutine(_ workout: CompletedWorkout, name: String? = nil) -> WorkoutPlan? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let routineName = trimmedName.isEmpty ? "\(workout.name) Routine" : trimmedName
        return createPlan(fromWorkouts: [workout], name: routineName)
    }

    @discardableResult
    func createPlan(fromWorkouts workouts: [CompletedWorkout], name: String) -> WorkoutPlan? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedWorkouts = workouts.sorted { $0.completedAt < $1.completedAt }
        guard !cleanName.isEmpty,
              !orderedWorkouts.isEmpty,
              let plan = createPlan(name: cleanName),
              let week = weeks(planID: plan.id).first,
              let originalSession = sessions(week: week).first else { return nil }

        repository.deleteWorkoutSession(originalSession)
        let duplicateNames = Dictionary(grouping: orderedWorkouts.indices) {
            orderedWorkouts[$0].name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        for (workoutIndex, workout) in orderedWorkouts.enumerated() {
            let workoutName = workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let repeated = (duplicateNames[workoutName.lowercased()]?.count ?? 0) > 1
            let sessionName = workoutName.isEmpty
                ? "Workout \(workoutIndex + 1)"
                : repeated ? "\(workoutName) \(workoutIndex + 1)" : workoutName
            let weekday = Calendar.current.weekdaySymbols.first {
                $0.caseInsensitiveCompare(workout.dayLabel) == .orderedSame
            } ?? Calendar.current.weekdaySymbols[
                Calendar.current.component(.weekday, from: workout.completedAt) - 1
            ]
            let session = repository.addWorkoutSession(weekID: week.id, day: weekday, name: sessionName)

            for (exerciseIndex, exercise) in workout.exercisesWithCompletedWorkingSets.sorted(by: { $0.order < $1.order }).enumerated() {
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
                        order: exerciseIndex,
                        notes: exercise.notes,
                        substitutionExerciseIDs: exercise.substitutionExerciseIDs,
                        muscleProfile: exercise.muscleProfile,
                        targetRIR: exercise.targetRIR,
                        trainingMaxPercentage: exercise.trainingMaxPercentage,
                        targetLoadKilograms: exercise.targetLoadKilograms
                    )
                )
            }
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
        return repository.addWorkoutSession(
            weekID: week.id,
            day: day,
            name: cleanName.isEmpty ? "Workout" : cleanName
        )
    }

    @discardableResult
    func startFreestyleSession(in week: WorkoutWeek, day: String) -> WorkoutSession {
        addSession(to: week, day: day, name: "Freestyle Workout")
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
    func startProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        preferredUnit: UnitSystem,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan? {
        guard scheduledWeekdays.count == template.sessions.count,
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
