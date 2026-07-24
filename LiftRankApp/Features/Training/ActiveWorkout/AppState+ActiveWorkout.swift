import Foundation

@MainActor
extension AppState {
    func phase(for week: WorkoutWeek) -> WorkoutPhase? {
        programStore.phases(planID: week.planID).first { $0.id == week.phaseID }
    }

    func weeks(for planID: UUID? = nil) -> [WorkoutWeek] {
        programStore.weeks(planID: planID ?? selectedWorkoutPlanID)
    }

    func sessions(for week: WorkoutWeek) -> [WorkoutSession] {
        programStore.sessions(week: week)
    }

    func prescriptions(for session: WorkoutSession) -> [WorkoutExercisePrescription] {
        programStore.prescriptions(session: session)
    }

    func setLogs(for prescription: WorkoutExercisePrescription) -> [WorkoutSetLog] {
        repository.workoutSetLogs
            .filter { $0.prescriptionID == prescription.id }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func setLogs(for exercise: WorkoutExerciseSnapshot, workoutID: UUID? = nil) -> [WorkoutSetLog] {
        let targetWorkoutID = workoutID ?? activeWorkout?.id
        if targetWorkoutID == activeWorkoutStore.workout?.id {
            return activeWorkoutStore.setLogs(for: exercise)
        }
        return repository.workoutSetLogs
            .filter { $0.prescriptionID == exercise.id && $0.workoutID == targetWorkoutID }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func previousSetLog(for exercise: WorkoutExerciseSnapshot, setNumber: Int) -> WorkoutSetLog? {
        completedWorkouts
            .sorted { $0.completedAt > $1.completedAt }
            .lazy
            .compactMap { workout -> WorkoutSetLog? in
                guard let previousExercise = workout.exercises.first(where: { $0.exerciseID == exercise.exerciseID }) else { return nil }
                return workout.sets.first {
                    $0.prescriptionID == previousExercise.id &&
                    $0.setNumber == setNumber &&
                    $0.isComplete
                }
            }
            .first
    }

    @discardableResult
    func startWorkout(_ session: WorkoutSession) -> Bool {
        let isFirstWorkout = completedWorkouts.isEmpty
        let week = workoutWeeks.first { $0.id == session.weekID }
        let unit = currentProfile.preferredUnit
        let bodyweight = unit == .kilograms
            ? RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
            : currentProfile.bodyweightPounds
        let started = activeWorkoutStore.startPlanned(
            session: session,
            planID: week?.planID,
            gymID: currentProfile.primaryGymID,
            bodyweight: bodyweight,
            unit: unit
        ) != nil
        if started {
            Haptics.success()
            if isFirstWorkout { Task { await track(.firstWorkoutStarted) } }
        }
        return started
    }

    @discardableResult
    func startFreestyleWorkoutInstance() -> Bool {
        let isFirstWorkout = completedWorkouts.isEmpty
        let unit = currentProfile.preferredUnit
        let bodyweight = unit == .kilograms
            ? RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
            : currentProfile.bodyweightPounds
        let started = activeWorkoutStore.startFreestyle(
            gymID: currentProfile.primaryGymID,
            bodyweight: bodyweight,
            unit: unit
        ) != nil
        if started {
            Haptics.success()
            if isFirstWorkout { Task { await track(.firstWorkoutStarted) } }
        }
        return started
    }

    func addExercisesToActiveWorkout(_ exercises: [TrainingExerciseCatalogItem]) {
        activeWorkoutStore.addExercises(exercises)
        Haptics.success()
    }

    func removeExerciseFromActiveWorkout(_ exercise: WorkoutExerciseSnapshot) {
        activeWorkoutStore.removeExercise(exercise)
        Haptics.warning()
    }

    @discardableResult
    func updateSourcePlanFromActiveWorkout() -> Bool {
        let updated = activeWorkoutStore.updateSourcePlan()
        updated ? Haptics.success() : Haptics.warning()
        if updated { Task { await synchronizeWorkoutPlans() } }
        return updated
    }

    func pauseActiveWorkout() {
        activeWorkoutStore.pause()
        Haptics.light()
    }

    func resumeActiveWorkout() {
        activeWorkoutStore.resume()
        Haptics.light()
    }

    func discardActiveWorkout() {
        activeWorkoutStore.discard()
        Haptics.warning()
    }

    func updateActiveRestTimer(endsAt: Date?, exerciseID: UUID?) {
        activeWorkoutStore.updateRestTimer(endsAt: endsAt, exerciseID: exerciseID)
    }

    var activeWorkoutCompletedWorkingSets: [WorkoutSetLog] {
        activeWorkoutStore.completedWorkingSets
    }

    func activeWorkoutSummary() -> WorkoutSummary? {
        activeWorkoutStore.summary()
    }

    var activeWorkoutFinishReadiness: ActiveWorkoutFinishReadiness {
        activeWorkoutStore.finishReadiness
    }

    @discardableResult
    func finishActiveWorkout(effort: Int, notes: String) -> CompletedWorkout? {
        let completed = activeWorkoutStore.finish(effort: effort, notes: notes)
        if let completed {
            Haptics.success()
            if isAuthenticated, !isDemoMode, let payload = try? JSONEncoder().encode(completed) {
                let snapshot = CompletedWorkoutSnapshot(
                    id: completed.id,
                    ownerID: currentProfile.id,
                    payload: payload,
                    completedAt: completed.completedAt
                )
                workoutSyncStore.enqueueCompletedWorkout(snapshot)
                Task { await synchronizeCompletedWorkoutHistory() }
            }
            Task { await track(.workoutCompleted, properties: ["workout_id": completed.id.uuidString]) }
        }
        return completed
    }

    func deleteCompletedWorkout(_ workout: CompletedWorkout) {
        activeWorkoutStore.deleteCompletedWorkout(workout)
        Haptics.warning()
    }

    func shareCompletedWorkout(_ workout: CompletedWorkout) async {
        guard features.connectionActivity else { return }
        do {
            if isAuthenticated, !isDemoMode {
                await synchronizeCompletedWorkoutHistory()
            }
            let detail = "\(workout.completedWorkingSets.count) sets · \(Int(workout.totalVolume)) \(workout.unit.shortLabel) volume"
            let activity = try await serviceContainer.social.shareWorkout(
                snapshotID: workout.id,
                title: workout.name,
                detail: detail
            )
            if !repository.activities.contains(where: { $0.id == activity.id }) {
                repository.activities.insert(activity, at: 0)
            }
            await track(.workoutShared, properties: ["workout_id": workout.id.uuidString])
            Haptics.success()
        } catch {
            accountMessage = userMessage(error)
            Haptics.warning()
        }
    }

    func setAutomaticVideoPRSubmission(_ enabled: Bool) {
        workoutPRSubmissionStore.setAutomaticSubmissionEnabled(enabled)
    }

    func setDefaultRestTimerEnabled(_ enabled: Bool) {
        activeWorkoutStore.setDefaultRestTimerEnabled(enabled)
    }

    func resetDemoData() {
        guard isDemoMode else { return }
        Haptics.warning()
        profilePhotoStore.removeNamespace(.demo)
        repository.reset()
    }

    func searchExercises(
        query: String,
        filters: ExerciseLibraryFilterSelection? = nil,
        excludingIDs: Set<String> = []
    ) -> [ExerciseSearchResult] {
        exerciseLibraryStore.search(query: query, filters: filters, excludingIDs: excludingIDs)
    }

    func substitutionRecommendations(
        for exercise: TrainingExerciseCatalogItem,
        equipmentFilter: Set<String> = [],
        limit: Int = 8
    ) -> [ExerciseSubstitutionRecommendation] {
        exerciseLibraryStore.substitutionRecommendations(
            for: exercise,
            equipmentFilter: equipmentFilter,
            limit: limit
        )
    }

    @discardableResult
    func moveActiveWorkoutExercise(_ exercise: WorkoutExerciseSnapshot, direction: Int) -> Bool {
        let moved = activeWorkoutStore.moveExercise(exercise, direction: direction)
        if moved { Haptics.light() }
        return moved
    }

    @discardableResult
    func reorderActiveWorkout(exerciseIDs: [UUID]) -> Bool {
        let reordered = activeWorkoutStore.reorderExercises(exerciseIDs)
        if reordered { Haptics.light() }
        return reordered
    }

    func setAutomaticRestTimerEnabledForActiveWorkout(_ enabled: Bool) {
        activeWorkoutStore.setAutomaticRestTimerEnabled(enabled)
    }

    @discardableResult
    func substituteActiveWorkoutExercise(
        _ exercise: WorkoutExerciseSnapshot,
        with substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot? {
        let updated = activeWorkoutStore.substituteExercise(exercise, with: substitute)
        if updated != nil { Haptics.success() }
        return updated
    }

    @discardableResult
    func applyWorkoutSetCompletion(
        _ log: WorkoutSetLog,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> Bool {
        activeWorkoutStore.applySetCompletion(log, isComplete: isComplete, source: source)
    }

    @discardableResult
    func attemptAutomaticCompletion(before log: WorkoutSetLog) -> Bool {
        activeWorkoutStore.attemptAutomaticCompletion(before: log)
    }

    func markAutomaticVideoPRExplanationShown() {
        workoutPRSubmissionStore.markAutomaticSubmissionExplanationShown()
    }

    func activeWorkoutPRCandidates() -> [WorkoutPRCandidate] {
        activeWorkoutStore.prCandidates(existingLifts: currentUserLifts)
    }

    func workoutPRCandidates(for workout: CompletedWorkout) -> [WorkoutPRCandidate] {
        workoutPRSubmissionStore.candidates(for: workout, existingLifts: currentUserLifts)
    }

    func submitVideoBackedPRs(for workout: CompletedWorkout, videoURLsBySetID: [UUID: URL]) async {
        await workoutPRSubmissionStore.submitVideoBackedPRs(
            for: workout,
            videoURLsBySetID: videoURLsBySetID,
            existingLifts: currentUserLifts
        )
    }

    func retryFailedWorkoutPRSubmissions() async {
        await workoutPRSubmissionStore.retryFailedSubmissions()
    }

    func persistWorkoutVideo(_ data: Data, fileExtension: String = "mov") throws -> URL {
        try workoutPRSubmissionStore.persistVideo(data, fileExtension: fileExtension)
    }

}
