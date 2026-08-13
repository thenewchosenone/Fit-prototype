import Foundation


struct ProgramPlanDeletion: Equatable {
    let deletedPlanID: UUID
    let fallbackPlanID: UUID
}

@MainActor
final class ProgramStore {
    private let repository: any ProgramRepository
    private let now: () -> Date
    private let makeID: () -> UUID

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
        repository.workoutPlans.first { $0.id == id }
    }

    func phases(planID: UUID) -> [WorkoutPhase] {
        repository.workoutPhases
            .filter { $0.planID == planID }
            .sorted { $0.order < $1.order }
    }

    func weeks(planID: UUID) -> [WorkoutWeek] {
        repository.workoutWeeks
            .filter { $0.planID == planID }
            .sorted { $0.weekNumber < $1.weekNumber }
    }

    func currentWeek(planID: UUID) -> WorkoutWeek? {
        repository.currentProgramWeek(planID: planID, at: now())
    }

    func sessions(week: WorkoutWeek) -> [WorkoutSession] {
        repository.workoutSessions
            .filter { $0.weekID == week.id }
            .sorted { $0.order < $1.order }
    }

    func prescriptions(session: WorkoutSession) -> [WorkoutExercisePrescription] {
        repository.workoutPrescriptions
            .filter { $0.sessionID == session.id }
            .sorted { $0.order < $1.order }
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
