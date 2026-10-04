import Foundation


struct ProgramPlanDeletion: Equatable {
    let deletedPlanID: UUID
    let fallbackPlanID: UUID
}

struct ProgramWeekPresentation {
    let sessions: [WorkoutSession]
    let prescriptionsBySessionID: [UUID: [WorkoutExercisePrescription]]
    let completedPrescriptionIDs: Set<UUID>
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

    var completedSessionCount: Int {
        sessions.filter { session in
            guard let prescriptions = prescriptionsBySessionID[session.id],
                  !prescriptions.isEmpty else { return false }
            return prescriptions.allSatisfy { completedPrescriptionIDs.contains($0.id) }
        }.count
    }

    init(
        sessions: [WorkoutSession],
        prescriptions: [WorkoutExercisePrescription],
        workoutSetLogs: [WorkoutSetLog],
        completedWorkouts: [CompletedWorkout],
        catalog: [TrainingExerciseCatalogItem]
    ) {
        self.sessions = sessions
        prescriptionsBySessionID = Dictionary(grouping: prescriptions, by: \.sessionID)
            .mapValues { $0.sorted { $0.order < $1.order } }
        let plannedPrescriptionIDs = Set(prescriptions.map(\.id))
        var completedPrescriptionIDs = Set(workoutSetLogs.lazy.filter {
            $0.isComplete && !$0.isWarmup && plannedPrescriptionIDs.contains($0.prescriptionID)
        }.map(\.prescriptionID))
        let sessionIDs = Set(sessions.map(\.id))
        for workout in completedWorkouts where workout.sourceSessionID.map(sessionIDs.contains) == true {
            let completedExerciseIDs = Set(workout.completedWorkingSets.map(\.prescriptionID))
            completedPrescriptionIDs.formUnion(
                workout.exercises.compactMap { exercise in
                    guard completedExerciseIDs.contains(exercise.id),
                          let sourcePrescriptionID = exercise.sourcePrescriptionID,
                          plannedPrescriptionIDs.contains(sourcePrescriptionID) else {
                        return nil
                    }
                    return sourcePrescriptionID
                }
            )
        }
        self.completedPrescriptionIDs = completedPrescriptionIDs
        var completedSetNumbersByPrescriptionID: [UUID: Set<Int>] = [:]
        for log in workoutSetLogs where log.isComplete && !log.isWarmup && plannedPrescriptionIDs.contains(log.prescriptionID) {
            completedSetNumbersByPrescriptionID[log.prescriptionID, default: []].insert(log.setNumber)
        }
        for workout in completedWorkouts where workout.sourceSessionID.map(sessionIDs.contains) == true {
            let prescriptionIDByExerciseID = Dictionary(uniqueKeysWithValues: workout.exercises.compactMap { exercise in
                exercise.sourcePrescriptionID.map { (exercise.id, $0) }
            })
            for log in workout.completedWorkingSets {
                guard let prescriptionID = prescriptionIDByExerciseID[log.prescriptionID],
                      plannedPrescriptionIDs.contains(prescriptionID) else { continue }
                completedSetNumbersByPrescriptionID[prescriptionID, default: []].insert(log.setNumber)
            }
        }
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
        guard repository.workoutPlans.count > 1,
              let plan = plan(id: id),
              let fallback = repository.workoutPlans.first(where: { $0.id != id }) else {
            return nil
        }
        repository.deleteWorkoutPlan(plan)
        return ProgramPlanDeletion(deletedPlanID: id, fallbackPlanID: fallback.id)
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
        guard scheduledWeekdays.count == template.sessions.count else { return nil }
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
