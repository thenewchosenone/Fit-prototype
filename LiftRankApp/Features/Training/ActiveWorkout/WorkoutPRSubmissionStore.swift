import Foundation

@MainActor
protocol WorkoutPRLiftSubmitting: AnyObject {
    func submitWorkoutPR(
        candidate: WorkoutPRCandidate,
        exercise: Exercise,
        workout: CompletedWorkout,
        profile: UserProfile,
        videoURL: URL
    ) async -> LiftSubmission?
}

@MainActor
final class WorkoutPRSubmissionStore {
    private let repository: any WorkoutPRSubmissionRepository
    private let liftSubmitter: any WorkoutPRLiftSubmitting
    private let videoStore: any WorkoutVideoStoring
    private let exercise: (String) -> Exercise?
    private let now: () -> Date
    private let makeID: () -> UUID
    private var cachedUserID: UUID

    init(
        repository: any WorkoutPRSubmissionRepository,
        liftSubmitter: any WorkoutPRLiftSubmitting,
        videoStore: any WorkoutVideoStoring = LocalWorkoutVideoStore(),
        exercise: @escaping (String) -> Exercise?,
        now: @escaping () -> Date = { .now },
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.liftSubmitter = liftSubmitter
        self.videoStore = videoStore
        self.exercise = exercise
        self.now = now
        self.makeID = makeID
        self.cachedUserID = repository.currentProfile.id
    }

    var pendingSubmissions: [PendingWorkoutPRSubmission] {
        resetAccountScopedQueueIfNeeded()
        return repository.pendingWorkoutPRSubmissions
    }

    var preferences: WorkoutPreferences {
        resetAccountScopedQueueIfNeeded()
        return repository.workoutPreferences
    }

    func setAutomaticSubmissionEnabled(_ enabled: Bool) {
        repository.workoutPreferences.automaticallySubmitVideoBackedPRs = enabled
        repository.workoutPreferences.didExplainAutomaticPRs = true
        repository.persistWorkoutSnapshot()
    }

    func markAutomaticSubmissionExplanationShown() {
        repository.workoutPreferences.didExplainAutomaticPRs = true
        repository.persistWorkoutSnapshot()
    }

    func candidates(
        for workout: CompletedWorkout,
        existingLifts: [LiftSubmission]
    ) -> [WorkoutPRCandidate] {
        WorkoutPRDetector.candidates(
            workoutID: workout.id,
            exercises: workout.exercises,
            sets: workout.sets,
            existingLifts: existingLifts,
            completedWorkouts: repository.completedWorkouts,
            excludingCompletedWorkoutID: workout.id
        )
    }

    func submitVideoBackedPRs(
        for workout: CompletedWorkout,
        videoURLsBySetID: [UUID: URL],
        existingLifts: [LiftSubmission]
    ) async {
        guard preferences.automaticallySubmitVideoBackedPRs else { return }
        for candidate in candidates(for: workout, existingLifts: existingLifts) {
            guard let videoURL = videoURLsBySetID[candidate.setID] else { continue }
            await submit(candidate, workout: workout, videoURL: videoURL)
        }
    }

    func retryFailedSubmissions() async {
        let retryable = pendingSubmissions.filter { $0.state == .failed || $0.state == .pending }
        for pending in retryable {
            guard let workout = repository.completedWorkouts.first(where: {
                $0.id == pending.candidate.completedWorkoutID
            }) else { continue }
            await submit(pending.candidate, workout: workout, videoURL: pending.localVideoURL)
        }
    }

    func persistVideo(_ data: Data, fileExtension: String = "mov") throws -> URL {
        try videoStore.save(data, fileExtension: fileExtension)
    }

    private func submit(
        _ candidate: WorkoutPRCandidate,
        workout: CompletedWorkout,
        videoURL: URL
    ) async {
        resetAccountScopedQueueIfNeeded()
        let userID = repository.currentProfile.id
        if pendingSubmissions.contains(where: {
            $0.candidate.setID == candidate.setID &&
                ($0.state == .submitted || $0.state == .uploading)
        }) {
            return
        }

        var pending = pendingSubmissions.first(where: { $0.candidate.setID == candidate.setID }) ??
            PendingWorkoutPRSubmission(
                id: makeID(),
                candidate: candidate,
                localVideoURL: videoURL,
                state: .pending,
                attemptCount: 0,
                lastError: nil,
                submissionID: nil,
                updatedAt: now()
            )
        pending.state = .uploading
        pending.attemptCount += 1
        pending.lastError = nil
        pending.updatedAt = now()
        repository.upsertPendingPRSubmission(pending)

        guard let rankingExercise = exercise(candidate.rankingExerciseID) else {
            pending.state = .failed
            pending.lastError = "The exercise is no longer eligible for ranking."
            pending.updatedAt = now()
            repository.upsertPendingPRSubmission(pending)
            return
        }

        let submission = await liftSubmitter.submitWorkoutPR(
            candidate: candidate,
            exercise: rankingExercise,
            workout: workout,
            profile: repository.currentProfile,
            videoURL: videoURL
        )
        guard repository.currentProfile.id == userID else {
            resetAccountScopedQueueIfNeeded()
            return
        }
        if let submission {
            pending.state = .submitted
            pending.submissionID = submission.id
            pending.lastError = nil
            repository.linkSubmission(submission.id, to: workout.id)
        } else {
            pending.state = .failed
            pending.lastError = "Upload could not be completed. It will remain available to retry."
        }
        pending.updatedAt = now()
        repository.upsertPendingPRSubmission(pending)
    }

    private func resetAccountScopedQueueIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        repository.clearPendingPRSubmissions()
        repository.workoutPreferences = WorkoutPreferences()
        repository.persistWorkoutSnapshot()
    }
}
