import Combine
import XCTest
@testable import LiftRank

private final class TestWorkoutRestNotificationScheduler: WorkoutRestNotificationScheduling {
    private(set) var scheduled: [(endsAt: Date, exerciseName: String)] = []
    private(set) var cancelCount = 0

    func schedule(endsAt: Date, exerciseName: String) {
        scheduled.append((endsAt, exerciseName))
    }

    func cancel() {
        cancelCount += 1
    }
}

private final class TestWorkoutVideoStore: WorkoutVideoStoring {
    let url: URL
    private(set) var savedData: Data?
    private(set) var savedExtension: String?
    private(set) var removedURLs: [URL] = []

    init(url: URL) {
        self.url = url
    }

    func save(_ data: Data, fileExtension: String) throws -> URL {
        savedData = data
        savedExtension = fileExtension
        return url
    }

    func remove(_ url: URL) { removedURLs.append(url) }
    func prune(retaining URLs: Set<URL>, olderThan cutoff: Date) {}
}

@MainActor
private final class GatedWorkoutPRLiftSubmitter: WorkoutPRLiftSubmitting {
    private(set) var attemptCount = 0
    private var release: CheckedContinuation<LiftSubmission?, Never>?

    func submitWorkoutPR(
        candidate: WorkoutPRCandidate,
        exercise: Exercise,
        workout: CompletedWorkout,
        profile: UserProfile,
        videoURL: URL
    ) async -> LiftSubmission? {
        attemptCount += 1
        return await withCheckedContinuation { continuation in
            release = continuation
        }
    }

    func releaseSubmission(_ submission: LiftSubmission? = nil) {
        release?.resume(returning: submission)
        release = nil
    }
}

@MainActor
private final class FlakyWorkoutPRLiftSubmitter: WorkoutPRLiftSubmitting {
    private let delegate: any WorkoutPRLiftSubmitting
    private(set) var attemptCount = 0
    var remainingFailures: Int

    init(delegate: any WorkoutPRLiftSubmitting, remainingFailures: Int) {
        self.delegate = delegate
        self.remainingFailures = remainingFailures
    }

    func submitWorkoutPR(
        candidate: WorkoutPRCandidate,
        exercise: Exercise,
        workout: CompletedWorkout,
        profile: UserProfile,
        videoURL: URL
    ) async -> LiftSubmission? {
        attemptCount += 1
        if remainingFailures > 0 {
            remainingFailures -= 1
            return nil
        }
        return await delegate.submitWorkoutPR(
            candidate: candidate,
            exercise: exercise,
            workout: workout,
            profile: profile,
            videoURL: videoURL
        )
    }
}

@MainActor
private final class StaticLeaderboardService: LeaderboardService {
    let entriesToReturn: [LeaderboardEntry]

    init(entries: [LeaderboardEntry]) {
        entriesToReturn = entries
    }

    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        entriesToReturn
    }
}

@MainActor
private final class ToggleLiftService: LiftService {
    let submissionsToReturn: [LiftSubmission]
    var shouldFail = false
    private(set) var reportedLiftID: UUID?
    private(set) var reportedReason: LiftReportReason?
    private(set) var reportedNote: String?

    init(submissions: [LiftSubmission]) {
        submissionsToReturn = submissions
    }

    func submissions() async throws -> [LiftSubmission] {
        if shouldFail { throw LiftRankServiceError.server("Lifts unavailable") }
        return submissionsToReturn
    }

    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission { submission }
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {}
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {
        reportedLiftID = liftID
        reportedReason = reason
        reportedNote = note
    }
}

@MainActor
private final class GatedLiftService: LiftService {
    var requestStarted = false
    private let submissionsToReturn: [LiftSubmission]
    private var continuation: CheckedContinuation<[LiftSubmission], Never>?

    init(submissions: [LiftSubmission]) {
        submissionsToReturn = submissions
    }

    func submissions() async throws -> [LiftSubmission] {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume(returning: submissionsToReturn)
        continuation = nil
    }

    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission { submission }
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {}
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {}
}

@MainActor
private final class GatedSubmitLiftService: LiftService {
    var requestStarted = false
    private var continuation: CheckedContinuation<LiftSubmission, Never>?
    private var pendingSubmission: LiftSubmission?

    func submissions() async throws -> [LiftSubmission] { [] }

    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        requestStarted = true
        pendingSubmission = submission
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {}
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {}

    func release() {
        guard let pendingSubmission else { return }
        continuation?.resume(returning: pendingSubmission)
        continuation = nil
        self.pendingSubmission = nil
    }
}

@MainActor
private final class GatedVerificationService: VerificationService {
    var requestStarted = false
    private var continuation: CheckedContinuation<LiftSubmission, Never>?
    private let updatedStatus: VerificationStatus

    init(updatedStatus: VerificationStatus) {
        self.updatedStatus = updatedStatus
    }

    func pendingSubmissions() async throws -> [LiftSubmission] { [] }

    func updateVerification(
        for lift: LiftSubmission,
        status: VerificationStatus,
        note: String?
    ) async throws -> LiftSubmission {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission {
        throw LiftRankServiceError.configurationMissing
    }

    func release(lift: LiftSubmission) {
        var updated = lift
        updated.verificationStatus = updatedStatus
        continuation?.resume(returning: updated)
        continuation = nil
    }
}

@MainActor
private final class GatedPlaybackMediaService: MediaUploadService {
    var requestStarted = false
    private var continuation: CheckedContinuation<URL, Never>?

    func upload(localURL: URL?) async throws -> URL? { localURL }
    func uploadLiftVideo(
        localURL: URL,
        liftID: UUID,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> LiftMediaAsset {
        throw LiftRankServiceError.configurationMissing
    }

    func signedPlaybackURL(assetID: UUID) async throws -> URL {
        requestStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume(returning: URL(fileURLWithPath: "/tmp/gated-playback.mov"))
        continuation = nil
    }
}

private struct FailingMediaUploadService: MediaUploadService {
    func upload(localURL: URL?) async throws -> URL? { nil }

    func uploadLiftVideo(
        localURL: URL,
        liftID: UUID,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> LiftMediaAsset {
        progress(0.5)
        throw LiftRankServiceError.networkUnavailable
    }

    func signedPlaybackURL(assetID: UUID) async throws -> URL {
        throw LiftRankServiceError.configurationMissing
    }
}

@MainActor
private final class WorkoutSyncServiceStub: WorkoutSyncService {
    var shouldFailDeletion = false
    var completedWorkoutSnapshots: [CompletedWorkoutSnapshot] = []
    private(set) var deletedIDs: [UUID] = []

    func plans() async throws -> [WorkoutPlanDocument] { [] }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        throw LiftRankServiceError.configurationMissing
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        completedWorkoutSnapshots.filter { since == nil || $0.completedAt > since! }
    }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {}
    func deleteCompletedWorkout(id: UUID) async throws {
        deletedIDs.append(id)
        if shouldFailDeletion { throw LiftRankServiceError.server("Deletion failed") }
    }
    func deletePlan(id: UUID) async throws {}
}

@MainActor
private final class RecordingNotificationService: NotificationService {
    private(set) var markedIDs: [UUID] = []
    var shouldFailRefresh = false

    func notifications() async throws -> [NotificationItem] {
        if shouldFailRefresh { throw LiftRankServiceError.server("Notifications unavailable") }
        return []
    }
    func markRead(notificationID: UUID) async throws { markedIDs.append(notificationID) }
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func revokeDevice(deviceID: String) async throws {}
}

@MainActor
private final class GatedLeaderboardService: LeaderboardService {
    private(set) var requests: [LeaderboardFilters] = []
    private var continuations: [CheckedContinuation<[LeaderboardEntry], Never>?] = []

    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        requests.append(filters)
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func release(request index: Int, entries: [LeaderboardEntry]) {
        continuations[index]?.resume(returning: entries)
        continuations[index] = nil
    }
}

final class RankingCalculatorTests: XCTestCase {
    @MainActor
    private func makePlannedRepository(
        workoutPersistenceStore: InMemoryWorkoutPersistenceStore? = nil
    ) -> DemoRepository {
        let repository = DemoRepository(
            workoutPersistenceStore: workoutPersistenceStore ?? InMemoryWorkoutPersistenceStore()
        )
        let seed = PersonalWorkoutPlanCatalog.makeSeed(createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        repository.workoutPlans = [seed.plan]
        repository.workoutPhases = seed.phases
        repository.workoutWeeks = seed.weeks
        repository.workoutSessions = seed.sessions
        repository.workoutPrescriptions = seed.prescriptions
        repository.persistWorkoutSnapshot()
        return repository
    }

    @MainActor
    private func makePlannedAppState() -> AppState {
        let repository = makePlannedRepository()
        let appState = AppState(repository: repository, serviceContainer: .demo(repository: repository))
        appState.selectedWorkoutPlanID = repository.workoutPlans[0].id
        return appState
    }

    func testLeaderboardMovementPresentation() {
        XCTAssertEqual(LeaderboardMovementPresentation(4), .up(4))
        XCTAssertEqual(LeaderboardMovementPresentation(-3), .down(3))
        XCTAssertEqual(LeaderboardMovementPresentation(0), .unchanged)
    }

    func testEpleyOneRepMaxCalculation() {
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 225, repetitions: 5), 262.5, accuracy: 0.001)
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 315, repetitions: 1), 315, accuracy: 0.001)
    }

    func testSubmittedCanonicalDeadliftFeedsStrengthProgress() {
        var lift = makeLift(userID: UUID(), weight: 315, exerciseID: "conventional-deadlift")
        lift.competitiveMovement = .conventionalDeadlift

        let performances = RankingCalculator.strengthPerformances(fromSubmissions: [lift])

        XCTAssertEqual(performances.count, 1)
        XCTAssertEqual(performances.first?.exerciseID, "deadlift")
        XCTAssertEqual(performances.first?.estimatedOneRepMaxKilograms ?? 0, RankingCalculator.poundsToKilograms(315), accuracy: 0.001)
    }

    func testPlateauRequiresThreeWorkoutsWithoutStrengthOrVolumeProgress() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let performances = [
            plateauPerformance(date: now, weight: 100, reps: 8, volume: 2_400),
            plateauPerformance(date: now.addingTimeInterval(-86_400), weight: 100, reps: 8, volume: 2_400),
            plateauPerformance(date: now.addingTimeInterval(-172_800), weight: 100, reps: 8, volume: 2_400)
        ]

        XCTAssertTrue(RankingCalculator.isPlateau(performances: performances))
        XCTAssertFalse(RankingCalculator.isPlateau(performances: Array(performances.prefix(2))))
    }

    func testPlateauClearsWhenStrengthOrVolumeImproves() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let baseline = plateauPerformance(date: now.addingTimeInterval(-172_800), weight: 100, reps: 8, volume: 2_400)
        let unchanged = plateauPerformance(date: now.addingTimeInterval(-86_400), weight: 100, reps: 8, volume: 2_400)
        let stronger = plateauPerformance(date: now, weight: 102.5, reps: 8, volume: 2_400)
        let moreVolume = plateauPerformance(date: now, weight: 100, reps: 8, volume: 2_500)

        XCTAssertFalse(RankingCalculator.isPlateau(performances: [stronger, unchanged, baseline]))
        XCTAssertFalse(RankingCalculator.isPlateau(performances: [moreVolume, unchanged, baseline]))
    }

    private func plateauPerformance(date: Date, weight: Double, reps: Int, volume: Double) -> PlateauPerformance {
        PlateauPerformance(
            id: UUID(),
            workoutID: UUID(),
            performedAt: date,
            weightKilograms: weight,
            repetitions: reps,
            estimatedOneRepMaxKilograms: RankingCalculator.epleyOneRepMax(weight: weight, repetitions: reps),
            volumeKilograms: volume
        )
    }

    func testPoundsToKilogramsConversion() {
        XCTAssertEqual(RankingCalculator.poundsToKilograms(220.46226218), 100, accuracy: 0.001)
    }

    func testWeightClassAssignment() {
        let weightClass = RankingCalculator.weightClass(for: 210, sexCategory: .male, classes: WeightClassCatalog.all)
        XCTAssertEqual(weightClass?.id, "usapl-m-100")
    }

    func testUSAPLWeightClassBoundaries() {
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(44), sexCategory: .female, classes: WeightClassCatalog.all)?.id, "usapl-f-44")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(44.01), sexCategory: .female, classes: WeightClassCatalog.all)?.id, "usapl-f-48")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(100.01), sexCategory: .female, classes: WeightClassCatalog.all)?.id, "usapl-f-100-plus")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(52), sexCategory: .male, classes: WeightClassCatalog.all)?.id, "usapl-m-52")
        XCTAssertEqual(RankingCalculator.weightClass(for: RankingCalculator.kilogramsToPounds(140.01), sexCategory: .male, classes: WeightClassCatalog.all)?.id, "usapl-m-140-plus")
    }

    func testBodyweightMultiple() {
        XCTAssertEqual(RankingCalculator.bodyweightMultiple(oneRepMax: 495, bodyweight: 210), 2.357, accuracy: 0.001)
    }

    func testStrengthTierRequiresAllThreeLifts() {
        let summary = RankingCalculator.strengthTierSummary(
            performances: [
                StrengthLiftPerformance(exerciseID: "squat", estimatedOneRepMaxKilograms: 150),
                StrengthLiftPerformance(exerciseID: "bench", estimatedOneRepMaxKilograms: 100)
            ],
            bodyweightKilograms: 100,
            sexCategory: .male
        )

        XCTAssertEqual(summary.overallTier, .unranked)
        XCTAssertEqual(summary.completedRequiredLiftCount, 2)
        XCTAssertEqual(summary.requiredLiftCount, 3)
    }

    func testStrengthTierUsesWeakestRequiredLift() {
        let summary = RankingCalculator.strengthTierSummary(
            performances: [
                StrengthLiftPerformance(exerciseID: "squat", estimatedOneRepMaxKilograms: 200),
                StrengthLiftPerformance(exerciseID: "bench", estimatedOneRepMaxKilograms: 100),
                StrengthLiftPerformance(exerciseID: "deadlift", estimatedOneRepMaxKilograms: 225)
            ],
            bodyweightKilograms: 100,
            sexCategory: .male
        )

        XCTAssertEqual(summary.overallTier, .intermediate)
        XCTAssertEqual(summary.liftProgress.first { $0.exerciseID == "squat" }?.currentTier, .advanced)
        XCTAssertEqual(summary.liftProgress.first { $0.exerciseID == "bench" }?.currentTier, .intermediate)
    }

    func testStrengthTierProgressIsClamped() {
        let summary = RankingCalculator.strengthTierSummary(
            performances: [
                StrengthLiftPerformance(exerciseID: "squat", estimatedOneRepMaxKilograms: 400),
                StrengthLiftPerformance(exerciseID: "bench", estimatedOneRepMaxKilograms: 300),
                StrengthLiftPerformance(exerciseID: "deadlift", estimatedOneRepMaxKilograms: 450)
            ],
            bodyweightKilograms: 100,
            sexCategory: .male
        )

        XCTAssertEqual(summary.overallTier, .legend)
        XCTAssertTrue(summary.liftProgress.allSatisfy { $0.progressToNextTier == 1 })
    }

    func testStrengthTierSummaryReportsOnlyAdvancedLifts() {
        let previous = RankingCalculator.strengthTierSummary(
            performances: [
                StrengthLiftPerformance(exerciseID: "squat", estimatedOneRepMaxKilograms: 100),
                StrengthLiftPerformance(exerciseID: "bench", estimatedOneRepMaxKilograms: 75),
                StrengthLiftPerformance(exerciseID: "deadlift", estimatedOneRepMaxKilograms: 125)
            ],
            bodyweightKilograms: 100,
            sexCategory: .male
        )
        let projected = RankingCalculator.strengthTierSummary(
            performances: [
                StrengthLiftPerformance(exerciseID: "squat", estimatedOneRepMaxKilograms: 150),
                StrengthLiftPerformance(exerciseID: "bench", estimatedOneRepMaxKilograms: 75),
                StrengthLiftPerformance(exerciseID: "deadlift", estimatedOneRepMaxKilograms: 125)
            ],
            bodyweightKilograms: 100,
            sexCategory: .male
        )

        XCTAssertEqual(projected.advancedLifts(comparedTo: previous).map(\.exerciseID), ["squat"])
    }

    @MainActor
    func testStrengthTierAchievementsUseCanonicalRankingExerciseIDs() {
        let repository = DemoRepository()
        repository.lifts = []
        repository.achievementUnlocks = []
        repository.currentProfile.bodyweightPounds = RankingCalculator.kilogramsToPounds(100)
        repository.currentProfile.sexCategory = .male
        let standards: [(String, Double)] = [("squat", 75), ("bench", 50), ("deadlift", 100)]
        repository.completedWorkouts = standards.map { exerciseID, kilograms in
            var workout = makeCompletedWorkout(completedAt: .now)
            workout.exercises[0].rankingExerciseID = exerciseID
            workout.sets[0].weight = kilograms
            workout.sets[0].reps = 1
            workout.sets[0].recordedUnit = .kilograms
            return workout
        }

        repository.refreshAchievementUnlocks()

        XCTAssertTrue(repository.achievementUnlocks.contains { $0.title == "Novice Rival" })
        XCTAssertFalse(repository.achievementUnlocks.contains { $0.title == "Beginner Rival" })
    }

    func testPowerliftingTotal() {
        XCTAssertEqual(RankingCalculator.powerliftingTotal(bench: 245, squat: 275, deadlift: 495), 1015)
    }

    func testRelativeTotal() {
        XCTAssertEqual(RankingCalculator.relativeTotal(total: 1015, bodyweight: 210), 4.833, accuracy: 0.001)
    }

    func testProgressPercentage() {
        XCTAssertEqual(RankingCalculator.progressPercentage(currentPersonalRecord: 315, previousPersonalRecord: 300), 5, accuracy: 0.001)
    }

    func testOverallScore() {
        XCTAssertEqual(RankingCalculator.overallScore(relativeStrength: 80, absoluteStrength: 70, recentProgress: 50), 71, accuracy: 0.001)
    }

    @MainActor
    func testCompetitionRefreshPreservesLoadedProductionLiftsWhenServerFails() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let productionLifts = [makeLift(userID: repository.currentProfile.id, weight: 405)]
        let service = ToggleLiftService(submissions: productionLifts)
        let store = CompetitionStore(repository: repository, liftService: service)

        await store.refreshProductionData()
        XCTAssertEqual(repository.lifts, productionLifts)

        service.shouldFail = true
        await store.refreshProductionData()

        XCTAssertEqual(repository.lifts, productionLifts)
    }

    @MainActor
    func testCompetitionReportTargetsAnotherAthletesLift() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let lift = makeLift(userID: UUID(), weight: 315)
        let service = ToggleLiftService(submissions: [])
        let store = CompetitionStore(repository: repository, liftService: service)

        let submitted = await store.report(lift, reason: .incorrectWeight, note: "Displayed weight is incorrect")

        XCTAssertTrue(submitted)
        XCTAssertEqual(service.reportedLiftID, lift.id)
        XCTAssertEqual(service.reportedReason, .incorrectWeight)
        XCTAssertEqual(service.reportedNote, "Displayed weight is incorrect")
    }

    @MainActor
    func testCompetitionRefreshClearsPreviousUsersProductionLifts() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let firstUserID = repository.currentProfile.id
        let productionLifts = [makeLift(userID: firstUserID, weight: 405)]
        let service = ToggleLiftService(submissions: productionLifts)
        let store = CompetitionStore(repository: repository, liftService: service)

        await store.refreshProductionData()
        XCTAssertEqual(repository.lifts, productionLifts)
        store.lastSubmissionResult = productionLifts.first

        repository.currentProfile.id = UUID()
        XCTAssertNotEqual(repository.currentProfile.id, firstUserID)
        repository.achievementUnlocks = [AchievementUnlock(id: "old", title: "Old award", unlockedAt: .now)]
        repository.rankingHistory = [RankingHistorySnapshot(id: UUID(), capturedAt: .now, globalTotalRank: 1, gymTotalRank: 1)]
        service.shouldFail = true
        await store.refreshProductionData()

        XCTAssertTrue(repository.lifts.isEmpty)
        XCTAssertTrue(repository.achievementUnlocks.isEmpty)
        XCTAssertTrue(repository.rankingHistory.isEmpty)
        XCTAssertNil(store.remoteLeaderboardEntries)
        XCTAssertNil(store.lastSubmissionResult)
        XCTAssertNil(store.leaderboardError)
        XCTAssertEqual(store.uploadProgress, 0)
    }

    @MainActor
    func testCompetitionRefreshDoesNotApplyPreviousUsersResponse() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = GatedLiftService(submissions: [
            makeLift(userID: repository.currentProfile.id, weight: 405)
        ])
        let store = CompetitionStore(repository: repository, liftService: service)
        let refresh = Task { await store.refreshProductionData() }

        while !service.requestStarted {
            await Task.yield()
        }
        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newUsersLift = makeLift(userID: newUserID, weight: 225)
        repository.lifts = [newUsersLift]
        let newUsersUnlock = AchievementUnlock(id: "new", title: "New award", unlockedAt: .now)
        repository.achievementUnlocks = [newUsersUnlock]
        service.release()
        await refresh.value

        XCTAssertEqual(repository.lifts, [newUsersLift])
        XCTAssertEqual(repository.achievementUnlocks, [newUsersUnlock])
        XCTAssertNil(store.remoteLeaderboardEntries)
    }

    @MainActor
    func testOverallScoreDoesNotAddProgressForUserWithNoLifts() {
        let repository = DemoRepository()
        repository.currentProfile = MockData.emptyProfile
        repository.lifts = []
        let store = CompetitionStore(repository: repository)

        XCTAssertEqual(store.overallScore, 0, accuracy: 0.001)
        XCTAssertEqual(RankingFormatting.strengthTier(for: store.overallScore).label, "Beginner")
    }

    func testExerciseProgressChartKeepsOnlyHighestSetPerDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 8)))
        let laterFirstDay = try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: firstDay))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let lightID = UUID()
        let heavyID = UUID()
        let nextDayID = UUID()
        let mixedUnitID = UUID()

        let result = ExerciseProgressSeries.dailyHighest(from: [
            ExerciseProgressPoint(id: lightID, date: firstDay, weight: 11, reps: 15, unit: .pounds),
            ExerciseProgressPoint(id: heavyID, date: laterFirstDay, weight: 22, reps: 8, unit: .pounds),
            ExerciseProgressPoint(id: mixedUnitID, date: laterFirstDay, weight: 10, reps: 1, unit: .kilograms),
            ExerciseProgressPoint(id: nextDayID, date: secondDay, weight: 16.5, reps: 10, unit: .pounds)
        ], calendar: calendar)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, mixedUnitID)
        XCTAssertEqual(result[0].weight, 10)
        XCTAssertEqual(result[0].unit, .kilograms)
        XCTAssertEqual(result[0].date, calendar.startOfDay(for: firstDay))
        XCTAssertEqual(result[1].id, nextDayID)
    }

    func testExerciseProgressPointsExcludeTimedExercises() {
        var workout = makeCompletedWorkout(completedAt: .now)
        workout.exercises[0].trackingType = "Weight + Time"
        XCTAssertTrue(
            WorkoutProgressPresentation.progressPoints(
                from: [workout],
                exerciseID: workout.exercises[0].exerciseID,
                preferredUnit: .pounds
            ).isEmpty
        )
    }

    func testWorkoutPRDetectorExcludesTimedSnapshots() {
        var workout = makeCompletedWorkout(completedAt: .now)
        workout.exercises[0].trackingType = "Weight + Time"
        XCTAssertTrue(
            WorkoutPRDetector.candidates(
                workoutID: workout.id,
                exercises: workout.exercises,
                sets: workout.sets,
                existingLifts: [],
                completedWorkouts: [],
                excludingCompletedWorkoutID: workout.id
            ).isEmpty
        )
    }

    @MainActor
    func testTrainingProgressDoesNotCountWarmupOnlyExerciseAsComplete() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let planID = UUID()
        let phaseID = UUID()
        let weekID = UUID()
        let sessionID = UUID()
        let prescriptionID = UUID()
        repository.workoutWeeks = [WorkoutWeek(
            id: weekID, planID: planID, phaseID: phaseID, weekNumber: 1, title: "Week 1", notes: ""
        )]
        repository.workoutSessions = [WorkoutSession(
            id: sessionID, weekID: weekID, day: "Monday", name: "Upper", order: 0, notes: ""
        )]
        repository.workoutPrescriptions = [WorkoutExercisePrescription(
            id: prescriptionID, sessionID: sessionID, exerciseID: "bench", exerciseName: "Bench",
            bodyPart: "Chest", equipment: "Barbell", sets: 1, reps: "5", restSeconds: 120, order: 0, notes: ""
        )]
        repository.workoutSetLogs = [WorkoutSetLog(
            id: UUID(), prescriptionID: prescriptionID, performedAt: .now, setNumber: 1,
            weight: 45, reps: 10, rpe: nil, isWarmup: true, isComplete: true
        )]
        let store = TrainingProgressStore(repository: repository)

        XCTAssertEqual(store.completedPrescriptionCount(for: repository.workoutSessions[0]), 0)
        XCTAssertEqual(store.weekCompletion(for: repository.workoutWeeks[0]), 0)
    }

    func testLeaderboardOrdering() {
        let profiles = (0..<6).map { makeProfile(username: "lifter_\($0)") }
        let lifts = profiles.enumerated().map { index, profile in
            makeLift(userID: profile.id, weight: 500 - Double(index * 10))
        }
        let entries = RankingCalculator.leaderboardEntries(
            profiles: profiles,
            lifts: lifts,
            rankingType: .absolute,
            verifiedOnly: true,
            currentUserID: profiles[0].id
        )
        XCTAssertGreaterThan(entries.count, 5)
        XCTAssertTrue(entries[0].score >= entries[1].score)
        XCTAssertTrue(entries.contains { $0.profile.id == profiles[0].id })
    }

    @MainActor
    func testLeaderboardUpdatesImmediately() {
        let repository = DemoRepository()
        repository.profiles = [repository.currentProfile]
        let store = CompetitionStore(repository: repository)
        store.verifiedOnly = false
        store.filters = LeaderboardFilters(exerciseID: "deadlift")
        store.filters.rankingType = .absolute

        let referenceDate = Date(timeIntervalSince1970: 1_782_374_400)
        let snapshotDate = store.leaderboardSnapshotDate(referenceDate: referenceDate)
        var pendingLift = makeLift(userID: repository.currentProfile.id, weight: 2_000)
        pendingLift.createdAt = snapshotDate.addingTimeInterval(60)
        pendingLift.performedAt = pendingLift.createdAt
        pendingLift.leaderboardEligibleAt = referenceDate
        repository.lifts.append(pendingLift)

        let currentSnapshot = store.leaderboardEntries(referenceDate: referenceDate)
        XCTAssertTrue(currentSnapshot.contains { $0.lift.id == pendingLift.id })
        XCTAssertEqual(currentSnapshot.first?.lift.id, pendingLift.id)
    }

    @MainActor
    func testCompetitionStoreOwnsLeaderboardStateAndCanonicalSubmissionDrafts() throws {
        let repository = DemoRepository()
        let referenceDate = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: 2026,
                month: 7,
                day: 18,
                hour: 12
            ))
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let store = CompetitionStore(
            repository: repository,
            calendar: calendar,
            now: { referenceDate },
            makeID: { fixedID }
        )

        store.verifiedOnly = false
        store.selectLeaderboardExercise("deadlift")
        store.filters.repetitionCount = 1
        XCTAssertEqual(store.filters.rankingType, .absolute)
        XCTAssertTrue(store.leaderboardEntries(referenceDate: referenceDate).allSatisfy {
            $0.lift.exerciseID == "deadlift" && $0.lift.repetitions == 1
        })

        store.filters.weightClassID = "not-a-class"
        store.normalizeFilters()
        XCTAssertNil(store.filters.weightClassID)
        store.selectLeaderboardExercise(nil)
        XCTAssertEqual(store.filters.rankingType, .total)
        XCTAssertNil(store.filters.repetitionCount)

        let exercise = try XCTUnwrap(MockData.exercises.first { $0.id == "bench" })
        let gymID = UUID()
        repository.gyms = [Gym(
            id: gymID, name: "Downtown Strength", city: "Austin", state: "Texas",
            memberCount: 0, verifiedLiftCount: 0
        )]
        repository.joinedGymIDs = [gymID]
        let submission = try XCTUnwrap(store.makeSubmission(
            exercise: exercise,
            weight: 100,
            unit: .kilograms,
            reps: 1,
            isActual: true,
            bodyweight: 200,
            date: referenceDate,
            gymID: gymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "Test PR",
            requestVerification: true
        ))

        XCTAssertEqual(submission.id, fixedID)
        XCTAssertEqual(submission.userID, repository.currentProfile.id)
        XCTAssertEqual(submission.competitiveMovement, .barbellBenchPress)
        XCTAssertEqual(submission.exerciseID, CompetitiveMovement.barbellBenchPress.canonicalExerciseID)
        XCTAssertEqual(submission.normalizedWeightKilograms, 100, accuracy: 0.001)
        XCTAssertEqual(submission.estimatedOneRepMax, RankingCalculator.kilogramsToPounds(100), accuracy: 0.001)
        XCTAssertEqual(submission.evidenceStatus, .selfReported)
        XCTAssertEqual(submission.verificationStatus, .selfReported)
        XCTAssertEqual(submission.leaderboardEligibleAt, referenceDate)

        XCTAssertNil(store.makeSubmission(
            exercise: exercise,
            weight: 225,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: 200,
            date: referenceDate,
            gymID: UUID(),
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "Invalid gym",
            requestVerification: false
        ))

        XCTAssertNotNil(store.makeSubmission(
            exercise: exercise,
            weight: 225,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: 200,
            date: referenceDate,
            gymID: nil,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "No gym",
            requestVerification: false
        ))
    }

    @MainActor
    func testRemoteLeaderboardAppliesClientSideFiltersAndRefreshKeyTracksThem() async throws {
        let repository = DemoRepository()
        var advancedProfile = makeProfile(username: "advanced_lifter")
        advancedProfile.experienceLevel = .advanced
        let advancedLift = makeLift(userID: advancedProfile.id, weight: 300, repetitions: 5)
        let beginnerProfile = makeProfile(username: "beginner_lifter")
        let beginnerLift = makeLift(userID: beginnerProfile.id, weight: 315)
        let service = StaticLeaderboardService(entries: [
            LeaderboardEntry(rank: 2, profile: advancedProfile, lift: advancedLift, rankMovement: 0, score: 300, powerliftingBreakdown: nil),
            LeaderboardEntry(rank: 1, profile: beginnerProfile, lift: beginnerLift, rankMovement: 0, score: 315, powerliftingBreakdown: nil)
        ])
        let store = CompetitionStore(repository: repository, leaderboardService: service)

        store.verifiedOnly = false
        await store.refreshLeaderboard()
        let unfilteredCount = store.leaderboardEntries(referenceDate: .now).count

        store.filters.repetitionCount = 5
        store.filters.experienceLevel = .advanced
        store.filters.verificationLevel = .videoVerified
        await store.refreshLeaderboard()
        let filtered = store.leaderboardEntries(referenceDate: .now)

        XCTAssertEqual(unfilteredCount, 2)
        XCTAssertEqual(filtered.map(\.profile.id), [advancedProfile.id])
        XCTAssertEqual(filtered.first?.lift.repetitions, 5)
        XCTAssertEqual(filtered.first?.profile.experienceLevel, .advanced)
        XCTAssertEqual(filtered.first?.lift.resolvedEvidenceStatus, .videoBacked)
        XCTAssertEqual(filtered.first?.rank, 1)

        let state = AppState()
        let initialKey = state.leaderboardRequestKey
        state.leaderboardFilters.repetitionCount = 5
        let repetitionKey = state.leaderboardRequestKey
        state.leaderboardFilters.experienceLevel = .advanced
        let experienceKey = state.leaderboardRequestKey
        state.leaderboardFilters.verificationLevel = .videoVerified

        XCTAssertNotEqual(initialKey, repetitionKey)
        XCTAssertNotEqual(repetitionKey, experienceKey)
        XCTAssertNotEqual(experienceKey, state.leaderboardRequestKey)
    }

    @MainActor
    func testProfileRankingUsesCanonicalCurrentUserTotalEntry() async {
        let repository = DemoRepository()
        let profile = makeProfile(id: repository.currentProfile.id, username: "canonical_total")
        let lift = makeLift(userID: profile.id, weight: 500)
        let canonical = LeaderboardEntry(
            rank: 4,
            profile: profile,
            lift: lift,
            rankMovement: 1,
            score: 1_225,
            powerliftingBreakdown: nil
        )
        let store = CompetitionStore(
            repository: repository,
            leaderboardService: StaticLeaderboardService(entries: [canonical])
        )

        await store.refreshCurrentUserTotalEntry()

        XCTAssertEqual(store.currentUserTotalEntry?.rank, 4)
        XCTAssertEqual(store.currentUserTotalEntry?.score, 1_225)
        XCTAssertEqual(store.currentUserTotalEntry?.profile.id, repository.currentProfile.id)
    }

    @MainActor
    func testLeaderboardRefreshIgnoresAnOlderResponseAfterFiltersChange() async {
        let repository = DemoRepository()
        let service = GatedLeaderboardService()
        let store = CompetitionStore(repository: repository, leaderboardService: service)
        let profile = repository.currentProfile
        let staleLift = makeLift(userID: profile.id, weight: 315)
        let staleEntry = LeaderboardEntry(
            rank: 1,
            profile: profile,
            lift: staleLift,
            rankMovement: 0,
            score: 315,
            powerliftingBreakdown: nil
        )

        let firstRefresh = Task { await store.refreshLeaderboard() }
        while service.requests.count < 1 {
            await Task.yield()
        }
        store.filters.exerciseID = "bench"
        let secondRefresh = Task { await store.refreshLeaderboard() }
        while service.requests.count < 2 {
            await Task.yield()
        }

        service.release(request: 1, entries: [])
        await secondRefresh.value
        service.release(request: 0, entries: [staleEntry])
        await firstRefresh.value

        XCTAssertEqual(store.remoteLeaderboardEntries, [])
    }

    @MainActor
    func testLeaderboardRefreshDoesNotClearNewAccountResponse() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = GatedLeaderboardService()
        let store = CompetitionStore(repository: repository, leaderboardService: service)
        let oldProfile = repository.currentProfile
        let oldLift = makeLift(userID: oldProfile.id, weight: 315)
        let oldEntry = LeaderboardEntry(
            rank: 1, profile: oldProfile, lift: oldLift,
            rankMovement: 0, score: 315, powerliftingBreakdown: nil
        )

        let oldRefresh = Task { await store.refreshLeaderboard() }
        while service.requests.count < 1 { await Task.yield() }

        var newProfile = oldProfile
        newProfile.id = UUID()
        newProfile.username = "new_account"
        repository.currentProfile = newProfile
        let newLift = makeLift(userID: newProfile.id, weight: 225)
        let newEntry = LeaderboardEntry(
            rank: 1, profile: newProfile, lift: newLift,
            rankMovement: 0, score: 225, powerliftingBreakdown: nil
        )
        let newRefresh = Task { await store.refreshLeaderboard() }
        while service.requests.count < 2 { await Task.yield() }

        service.release(request: 1, entries: [newEntry])
        await newRefresh.value
        service.release(request: 0, entries: [oldEntry])
        await oldRefresh.value

        XCTAssertEqual(store.remoteLeaderboardEntries, [newEntry])
    }

    @MainActor
    func testRankingNotificationOpensFocusedLeaderboardWithoutGymScope() {
        let appState = AppState()
        let notification = NotificationItem(
            id: UUID(), title: "Ranking update", message: "Your ranking changed.", kind: "Ranking",
            createdAt: .now, isRead: false,
            destination: NotificationDestination(
                kind: .leaderboard, exerciseID: "deadlift", rankingType: .absolute
            )
        )
        appState.repository.notifications = [notification]

        appState.openNotification(notification)

        XCTAssertEqual(appState.selectedTab, 1)
        XCTAssertEqual(appState.leaderboardFilters.exerciseID, "deadlift")
        XCTAssertNil(appState.leaderboardFilters.gymID)
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .absolute)
        XCTAssertTrue(appState.verifiedOnly)
        XCTAssertNotNil(appState.leaderboardFocusRequestID)
        XCTAssertTrue(appState.notifications.first(where: { $0.id == notification.id })?.isRead == true)
    }

    @MainActor
    func testVideoBackedSubmissionUpdatesStoredLiftAndResolvesPlayback() async throws {
        let repository = DemoRepository()
        let gymID = UUID()
        repository.gyms = [Gym(id: gymID, name: "Downtown Strength", city: "Austin", state: "Texas", memberCount: 0, verifiedLiftCount: 0)]
        repository.joinedGymIDs = [gymID]
        let store = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository),
            mediaUploadService: MockMediaUploadService()
        )
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("liftrank-video-\(UUID().uuidString).mov")
        try Data([0x00]).write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        let lift = await store.submitLift(
            exercise: MockData.exercises[2],
            weight: 585,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: repository.currentProfile.bodyweightPounds,
            date: .now,
            gymID: gymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: localURL,
            caption: "Playback regression",
            requestVerification: true
        )

        let submitted = try XCTUnwrap(lift)
        let stored = try XCTUnwrap(repository.lifts.first { $0.id == submitted.id })
        XCTAssertEqual(stored.evidenceStatus, .videoBacked)
        XCTAssertEqual(stored.verificationStatus, .videoVerified)
        XCTAssertNotNil(stored.videoAssetID)
        XCTAssertEqual(stored.localVideoURL, localURL)
        let playbackURL = await store.playbackURL(for: stored)
        XCTAssertEqual(playbackURL, localURL)
    }

    @MainActor
    func testFailedVideoUploadLeavesSelfReportedLiftWithoutMediaReference() async throws {
        let repository = DemoRepository()
        let gymID = UUID()
        repository.gyms = [Gym(id: gymID, name: "Downtown Strength", city: "Austin", state: "Texas", memberCount: 0, verifiedLiftCount: 0)]
        repository.joinedGymIDs = [gymID]
        let store = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository),
            mediaUploadService: FailingMediaUploadService()
        )
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("liftrank-failed-video-\(UUID().uuidString).mov")
        try Data([0x00]).write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        let lift = await store.submitLift(
            exercise: MockData.exercises[2],
            weight: 585,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: repository.currentProfile.bodyweightPounds,
            date: .now,
            gymID: gymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: localURL,
            caption: "Failed upload regression",
            requestVerification: true
        )

        let submitted = try XCTUnwrap(lift)
        XCTAssertEqual(submitted.evidenceStatus, .selfReported)
        XCTAssertEqual(submitted.verificationStatus, .selfReported)
        XCTAssertNil(submitted.videoAssetID)
        XCTAssertNil(submitted.localVideoURL)
        XCTAssertNil(submitted.remoteVideoURL)
        XCTAssertFalse(repository.lifts.contains {
            $0.id == submitted.id &&
                ($0.videoAssetID != nil || $0.localVideoURL != nil || $0.remoteVideoURL != nil)
        })
        XCTAssertEqual(store.uploadProgress, 0)
    }

    func testRemoteEstimatedLiftReconstructsOneRepMaxAndMapsApprovedRemovalProtection() throws {
        let performedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = CompetitiveLiftDTO(
            id: UUID(), userID: UUID(), exerciseID: "bench", gymID: UUID().uuidString,
            weight: 100, unit: "kg", reps: 5, bodyweight: 90, visibility: "Public",
            verification: "Self Reported", caption: "", performedAt: performedAt,
            createdAt: performedAt, repetitions: 5, isActualOneRepMax: false,
            competitiveMovement: CompetitiveMovement.barbellBenchPress.rawValue,
            evidenceStatus: "self_reported", moderationStatus: "clear", weightPerHand: false,
            leaderboardEligibleAt: performedAt, updatedAt: performedAt, videoAssetID: nil,
            approvedEvidenceStoragePath: nil, evidenceStoragePath: nil,
            reviewStatus: "approved", evidencePublic: false
        )

        let submission = try XCTUnwrap(dto.submission)

        XCTAssertEqual(
            submission.estimatedOneRepMax,
            RankingCalculator.epleyOneRepMax(
                weight: RankingCalculator.kilogramsToPounds(100),
                repetitions: 5
            ),
            accuracy: 0.001
        )
        XCTAssertTrue(submission.requiresCoordinatedRemoval)
    }

    @MainActor
    func testCompetitionStoreOwnsVerificationServiceMutation() async throws {
        let repository = DemoRepository()
        let lift = makeLift(userID: repository.currentProfile.id, weight: 405)
        repository.lifts = [lift]
        let store = CompetitionStore(
            repository: repository,
            verificationService: MockVerificationService(repository: repository)
        )
        let updated = await store.updateVerification(
            for: lift,
            status: .rejected,
            note: "Invalid evidence"
        )

        XCTAssertEqual(updated?.verificationStatus, .rejected)
        XCTAssertEqual(
            repository.lifts.first { $0.id == lift.id }?.verificationStatus,
            .rejected
        )
    }

    @MainActor
    func testCompetitionVerificationDoesNotApplyPreviousUsersResponse() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let lift = makeLift(userID: repository.currentProfile.id, weight: 405)
        repository.lifts = [lift]
        let service = GatedVerificationService(updatedStatus: .rejected)
        let store = CompetitionStore(repository: repository, verificationService: service)

        let update = Task {
            await store.updateVerification(for: lift, status: .rejected, note: "Invalid evidence")
        }
        while !service.requestStarted {
            await Task.yield()
        }

        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newUsersLift = makeLift(userID: newUserID, weight: 225)
        repository.lifts = [newUsersLift]
        service.release(lift: lift)
        let updated = await update.value

        XCTAssertNil(updated)
        XCTAssertEqual(repository.lifts, [newUsersLift])
    }

    @MainActor
    func testCompetitionPlaybackDoesNotUpdatePreviousUsersLift() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let lift = makeLift(userID: repository.currentProfile.id, weight: 405)
        var remoteLift = lift
        remoteLift.localVideoURL = nil
        remoteLift.remoteVideoURL = nil
        remoteLift.videoAssetID = UUID()
        repository.lifts = [remoteLift]
        let mediaService = GatedPlaybackMediaService()
        let store = CompetitionStore(repository: repository, mediaUploadService: mediaService)

        let playback = Task { await store.playbackURL(for: remoteLift) }
        while !mediaService.requestStarted {
            await Task.yield()
        }

        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newUsersLift = makeLift(userID: newUserID, weight: 225)
        repository.lifts = [newUsersLift]
        mediaService.release()
        let url = await playback.value

        XCTAssertNil(url)
        XCTAssertEqual(repository.lifts, [newUsersLift])
    }

    @MainActor
    func testCompetitionSubmissionDoesNotApplyPreviousUsersResponse() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let gymID = UUID()
        repository.gyms = [Gym(
            id: gymID, name: "Downtown Strength", city: "Austin", state: "Texas",
            memberCount: 0, verifiedLiftCount: 0
        )]
        repository.joinedGymIDs = [gymID]
        let service = GatedSubmitLiftService()
        let store = CompetitionStore(repository: repository, liftService: service)

        let submission = Task {
            await store.submitLift(
                exercise: MockData.exercises[0], weight: 225, unit: .pounds, reps: 1,
                isActual: true, bodyweight: 200, date: .now, gymID: gymID,
                equipment: .raw, visibility: .publicLift, videoURL: nil,
                caption: "", requestVerification: false
            )
        }
        while !service.requestStarted {
            await Task.yield()
        }

        let newUserID = UUID()
        repository.currentProfile.id = newUserID
        let newUsersLift = makeLift(userID: newUserID, weight: 225)
        repository.lifts = [newUsersLift]
        service.release()
        let result = await submission.value

        XCTAssertNil(result)
        XCTAssertEqual(repository.lifts, [newUsersLift])
    }

    @MainActor
    func testWorkoutStreakUsesCompletedWorkoutDates() {
        let appState = AppState()

        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 0)

        for daysAgo in 0...2 {
            let performedAt = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
            appState.repository.completedWorkouts.append(makeCompletedWorkout(completedAt: performedAt))
        }

        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 3)
    }

    func testWorkoutHistoryCalendarHandlesMonthBoundariesAndMultipleWorkoutsPerDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2

        let july = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let julyFourMorning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 8)))
        let julyFourEvening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 18)))
        let augustOne = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9)))
        let workouts = [
            makeCompletedWorkout(completedAt: julyFourMorning),
            makeCompletedWorkout(completedAt: julyFourEvening),
            makeCompletedWorkout(completedAt: augustOne)
        ]

        let days = WorkoutHistoryCalendarData.days(in: july, workouts: workouts, calendar: calendar)
        XCTAssertEqual(days.count, 35)
        XCTAssertEqual(days.prefix(2).compactMap(\.date).count, 0)
        XCTAssertEqual(
            days.first { day in
                day.date.map { calendar.component(.day, from: $0) == 4 } ?? false
            }?.workoutCount,
            2
        )

        let selected = WorkoutHistoryCalendarData.workouts(on: julyFourMorning, from: workouts, calendar: calendar)
        XCTAssertEqual(selected.count, 2)
        XCTAssertEqual(selected.first?.completedAt, julyFourEvening)
    }

    func testWorkoutHistoryCalendarSupportsLeapMonthAndEmptyHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 1
        let february = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))

        let days = WorkoutHistoryCalendarData.days(in: february, workouts: [], calendar: calendar)
        XCTAssertEqual(days.compactMap(\.date).count, 29)
        XCTAssertTrue(days.allSatisfy { $0.workoutCount == 0 })
        XCTAssertTrue(WorkoutHistoryCalendarData.workouts(on: nil, from: [], calendar: calendar).isEmpty)
    }

    func testWorkoutHistoryCalendarPlacesAugustFirstInItsSaturdayCell() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        let august = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15)))

        let days = WorkoutHistoryCalendarData.days(in: august, workouts: [], calendar: calendar)

        let augustFirst = try XCTUnwrap(days.compactMap(\.date).first {
            calendar.component(.day, from: $0) == 1
        })
        XCTAssertEqual(calendar.component(.weekday, from: augustFirst), 7)
    }

    func testWorkoutHistoryWeekdaySymbolsFollowCalendarWeekStart() {
        var sundayStart = Calendar(identifier: .gregorian)
        sundayStart.firstWeekday = 1
        XCTAssertEqual(WorkoutHistoryCalendarData.weekdaySymbols(calendar: sundayStart), ["S", "M", "T", "W", "T", "F", "S"])

        var mondayStart = Calendar(identifier: .gregorian)
        mondayStart.firstWeekday = 2
        XCTAssertEqual(WorkoutHistoryCalendarData.weekdaySymbols(calendar: mondayStart), ["M", "T", "W", "T", "F", "S", "S"])
    }

    @MainActor
    func testWorkoutStreakRemainsActiveWhenLastWorkoutWasYesterday() {
        let appState = AppState()

        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        for daysAgo in 1...2 {
            let completedAt = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
            appState.repository.completedWorkouts.append(makeCompletedWorkout(completedAt: completedAt))
        }

        XCTAssertEqual(appState.workoutStreak(referenceDate: referenceDate), 2)
    }

    @MainActor
    func testWorkoutFeedbackIsSavedAndReplacesSameDayEntry() {
        let appState = makePlannedAppState()
        guard let session = appState.workoutSessions.first else {
            XCTFail("Expected a seeded workout session")
            return
        }

        appState.completeWorkout(session, effort: 4, notes: "Strong session")
        appState.completeWorkout(session, effort: 5, notes: "Updated note")

        let feedback = appState.workoutFeedback.filter { $0.sessionID == session.id }
        XCTAssertEqual(feedback.count, 1)
        XCTAssertEqual(feedback.first?.effort, 5)
        XCTAssertEqual(feedback.first?.notes, "Updated note")
    }

    @MainActor
    func testLiftCannotBeSubmittedForUnjoinedGym() async {
        let appState = AppState()
        let unjoinedGym = Gym(id: UUID(), name: "Unjoined Gym", city: "Austin", state: "Texas", memberCount: 0, verifiedLiftCount: 0)
        appState.repository.gyms = [unjoinedGym]

        await appState.submitLift(
            exercise: MockData.exercises[2],
            weight: 315,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: 210,
            date: .now,
            gymID: unjoinedGym.id,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "",
            requestVerification: false
        )

        XCTAssertNil(appState.lastSubmissionResult)
        XCTAssertFalse(appState.currentUserLifts.contains { $0.gymID == unjoinedGym.id })
    }

    @MainActor
    func testLeaderboardFiltersByRankingCardScopes() {
        let repository = DemoRepository()
        var profile = makeProfile(id: repository.currentProfile.id)
        profile.city = "Austin"
        profile.state = "Texas"
        profile.sexCategory = .male
        let gymID = UUID()
        var lift = makeLift(userID: profile.id, weight: 405)
        lift.gymID = gymID
        repository.currentProfile = profile
        repository.profiles = [profile]
        repository.lifts = [lift]
        let store = CompetitionStore(repository: repository)
        store.verifiedOnly = false

        var gymFilters = LeaderboardFilters(exerciseID: "deadlift")
        gymFilters.gymID = gymID
        store.filters = gymFilters
        let gymEntries = store.leaderboardEntries(referenceDate: .now)
        XCTAssertFalse(gymEntries.isEmpty)
        XCTAssertTrue(gymEntries.allSatisfy { $0.lift.gymID == gymID })

        var cityFilters = LeaderboardFilters(exerciseID: "deadlift")
        cityFilters.city = repository.currentProfile.city
        cityFilters.state = repository.currentProfile.state
        store.filters = cityFilters
        let cityEntries = store.leaderboardEntries(referenceDate: .now)
        XCTAssertFalse(cityEntries.isEmpty)
        XCTAssertTrue(cityEntries.allSatisfy { $0.profile.city == repository.currentProfile.city && $0.profile.state == repository.currentProfile.state })

        var weightClassFilters = LeaderboardFilters(exerciseID: nil)
        weightClassFilters.sexCategory = repository.currentProfile.sexCategory
        weightClassFilters.weightClassID = RankingCalculator.weightClass(
            for: repository.currentProfile.bodyweightPounds,
            sexCategory: repository.currentProfile.sexCategory,
            classes: WeightClassCatalog.all
        )?.id
        store.filters = weightClassFilters
        let weightClassEntries = store.leaderboardEntries(referenceDate: .now)
        XCTAssertFalse(weightClassEntries.isEmpty)
        XCTAssertTrue(weightClassEntries.allSatisfy { entry in
            RankingCalculator.weightClass(
                for: entry.lift.bodyweightAtLift,
                sexCategory: entry.profile.sexCategory,
                classes: WeightClassCatalog.all
            )?.id == weightClassFilters.weightClassID
        })
    }

    func testTieHandlingUsesSameDisplayedRank() {
        let profileA = MockData.demoProfile
        var profileB = MockData.demoProfile
        profileB.id = UUID()
        profileB.username = "tie"
        let liftA = makeLift(userID: profileA.id, weight: 300)
        let liftB = makeLift(userID: profileB.id, weight: 300)
        let entries = RankingCalculator.leaderboardEntries(
            profiles: [profileA, profileB],
            lifts: [liftA, liftB],
            rankingType: .absolute,
            verifiedOnly: true,
            currentUserID: nil
        )
        XCTAssertEqual(entries.map(\.rank), [1, 1])
    }

    func testBestLiftSelection() {
        let lower = makeLift(userID: MockData.demoUserID, weight: 225)
        let higher = makeLift(userID: MockData.demoUserID, weight: 315)
        XCTAssertEqual(RankingCalculator.bestLift(exerciseID: "deadlift", submissions: [lower, higher])?.estimatedOneRepMax, 315)
    }

    func testBestLiftSelectionResolvesCanonicalCompetitiveMovementIDs() {
        var canonical = makeLift(
            userID: MockData.demoUserID,
            weight: 315,
            exerciseID: "conventional-deadlift"
        )
        canonical.competitiveMovement = .conventionalDeadlift

        XCTAssertEqual(
            RankingCalculator.bestLift(exerciseID: "deadlift", submissions: [canonical])?.estimatedOneRepMax,
            315
        )
    }

    func testWorkoutVolumeAndEstimatedMax() {
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: MockData.defaultWorkoutPlanID,
            week: 1,
            date: .now,
            day: "Monday",
            workout: "Push + Quads",
            exercise: "Incline DB Press",
            muscleGroup: "Upper Chest",
            targetSets: 3,
            targetReps: "8-10",
            sets: [
                WorkoutSetEntry(id: UUID(), weight: 100, reps: 10, rpe: 7),
                WorkoutSetEntry(id: UUID(), weight: 120, reps: 8, rpe: 9)
            ],
            isDone: true,
            notes: ""
        )
        XCTAssertEqual(entry.volume, 1960)
        XCTAssertEqual(entry.estimatedMax, 152, accuracy: 0.001)
    }

    func testTrainingExerciseLibraryHasBodyPartCoverage() {
        let library = MockData.trainingExerciseLibrary
        let bodyParts = Set(library.map(\.bodyPart))

        XCTAssertGreaterThanOrEqual(library.count, 30)
        XCTAssertTrue(bodyParts.contains("Chest"))
        XCTAssertTrue(bodyParts.contains("Back"))
        XCTAssertTrue(bodyParts.contains("Quads"))
        XCTAssertTrue(bodyParts.contains("Hamstrings"))
        XCTAssertTrue(bodyParts.contains("Glutes"))
        XCTAssertTrue(bodyParts.contains("Shoulders"))
        XCTAssertTrue(bodyParts.contains("Core"))
        XCTAssertTrue(library.allSatisfy { !$0.defaultReps.isEmpty && $0.defaultSets > 0 })
    }

    func testTrainingExerciseLibraryHasEquipmentCoverage() {
        let equipment = Set(MockData.trainingExerciseLibrary.map(\.equipment))

        XCTAssertTrue(equipment.contains("Barbell"))
        XCTAssertTrue(equipment.contains("Dumbbell"))
        XCTAssertTrue(equipment.contains("Cable"))
        XCTAssertTrue(equipment.contains("Machine"))
        XCTAssertTrue(equipment.contains("Bodyweight"))
    }

    func testEquipmentExerciseExpansionContainsGenericMachineAdditions() {
        let expansion = PopularExerciseCatalog.exercises
        let counts = Dictionary(grouping: expansion, by: \.equipment).mapValues(\.count)

        XCTAssertEqual(expansion.count, 295)
        XCTAssertEqual(counts["Machine"], 56)
        XCTAssertEqual(counts["Smith Machine"], 24)
        XCTAssertEqual(counts["Cable"], 50)
        XCTAssertEqual(counts["Dumbbell"], 54)
        XCTAssertEqual(counts["Barbell"], 35)
        XCTAssertEqual(counts["Bodyweight"], 36)
        XCTAssertEqual(counts["Kettlebell"], 20)
        XCTAssertEqual(counts["Band"], 20)
        XCTAssertEqual(Set(expansion.map(\.id)).count, expansion.count)
        XCTAssertEqual(Set(expansion.map { $0.name.lowercased() }).count, expansion.count)
        XCTAssertTrue(expansion.allSatisfy {
            !$0.name.isEmpty &&
            !$0.bodyPart.isEmpty &&
            !$0.workoutCategory.isEmpty &&
            $0.defaultSets > 0 &&
            !$0.defaultReps.isEmpty &&
            $0.defaultRestSeconds > 0
        })
    }

    func testCombinedTrainingLibraryHasUniqueIdentifiers() {
        let library = MockData.trainingExerciseLibrary
        XCTAssertEqual(Set(library.map(\.id)).count, library.count)
        XCTAssertEqual(Set(library.map { $0.name.lowercased() }).count, library.count)
    }

    func testBrandAliasesResolveToSingleGenericExercise() {
        let library = MockData.trainingExerciseLibrary
        let dyRowMatches = library.filter { $0.matchesSearch("Hammer Strength D.Y. Row") }
        let superInclineMatches = library.filter { $0.matchesSearch("Hammer Super Incline") }
        let wideChestMatches = library.filter { $0.matchesSearch("Hammer Wide Chest") }

        XCTAssertEqual(dyRowMatches.map(\.id), ["machine_iso_lateral_underhand_row"])
        XCTAssertEqual(superInclineMatches.map(\.id), ["machine_high_incline_chest_press"])
        XCTAssertEqual(wideChestMatches.map(\.id), ["machine_wide_grip_chest_press"])
        XCTAssertFalse(library.contains { $0.name.localizedCaseInsensitiveContains("Hammer Strength") })
    }

    func testAllPlannedGenericMachineMovementsArePresent() {
        let expectedIDs: Set<String> = [
            "machine_iso_lateral_underhand_row",
            "machine_plate_loaded_horizontal_bench_press",
            "machine_high_incline_chest_press",
            "machine_wide_grip_chest_press",
            "machine_front_lat_pulldown",
            "machine_plate_loaded_pec_fly",
            "machine_shrug",
            "machine_grip",
            "machine_neck_flexion",
            "machine_neck_extension",
            "machine_lateral_neck_flexion",
            "machine_linear_45_leg_press",
            "machine_iso_lateral_leg_press",
            "machine_iso_lateral_leg_curl",
            "machine_ground_base_squat",
            "machine_ground_base_rotational_twist"
        ]
        let libraryIDs = Set(MockData.trainingExerciseLibrary.map(\.id))
        XCTAssertTrue(expectedIDs.isSubset(of: libraryIDs))
    }

    func testWorkoutSetKeyboardNavigationMovesAcrossEachSet() {
        let first = makeSetLog(setNumber: 1)
        let second = makeSetLog(setNumber: 2)
        let third = makeSetLog(setNumber: 3)
        let logs = [second, third, first]

        let focuses = WorkoutSetInputNavigator.orderedFocuses(for: logs)

        XCTAssertEqual(focuses, [
            WorkoutSetInputFocus(logID: first.id, field: .reps),
            WorkoutSetInputFocus(logID: first.id, field: .weight),
            WorkoutSetInputFocus(logID: second.id, field: .reps),
            WorkoutSetInputFocus(logID: second.id, field: .weight),
            WorkoutSetInputFocus(logID: third.id, field: .reps),
            WorkoutSetInputFocus(logID: third.id, field: .weight)
        ])
        XCTAssertEqual(
            WorkoutSetInputNavigator.next(after: focuses[0], in: logs),
            WorkoutSetInputFocus(logID: first.id, field: .weight)
        )
        XCTAssertEqual(
            WorkoutSetInputNavigator.next(after: focuses[1], in: logs),
            WorkoutSetInputFocus(logID: second.id, field: .reps)
        )
        XCTAssertNil(WorkoutSetInputNavigator.next(after: focuses[5], in: logs))
    }

    func testWorkoutSetKeyboardNavigationIncludesNewlyAddedSet() {
        let first = makeSetLog(setNumber: 1)
        let second = makeSetLog(setNumber: 2)

        XCTAssertEqual(
            WorkoutSetInputNavigator.next(
                after: WorkoutSetInputFocus(logID: first.id, field: .weight),
                in: [first, second]
            ),
            WorkoutSetInputFocus(logID: second.id, field: .reps)
        )
        XCTAssertNil(
            WorkoutSetInputNavigator.next(
                after: WorkoutSetInputFocus(logID: second.id, field: .weight),
                in: [first, second]
            )
        )
    }

    func testWorkoutSetKeyboardNavigationSkipsWeightForBodyweightTracking() {
        let first = makeSetLog(setNumber: 1)
        let second = makeSetLog(setNumber: 2)

        XCTAssertEqual(
            WorkoutSetInputNavigator.orderedFocuses(for: [second, first], trackingKind: .bodyweightReps),
            [
                WorkoutSetInputFocus(logID: first.id, field: .reps),
                WorkoutSetInputFocus(logID: second.id, field: .reps)
            ]
        )
        XCTAssertEqual(
            WorkoutSetInputNavigator.next(
                after: WorkoutSetInputFocus(logID: first.id, field: .reps),
                in: [first, second],
                trackingKind: .bodyweightReps
            ),
            WorkoutSetInputFocus(logID: second.id, field: .reps)
        )
    }

    func testExerciseTrackingKindDefinesRequiredInputs() {
        XCTAssertTrue(ExerciseTrackingKind.weightReps.requiresWeight)
        XCTAssertFalse(ExerciseTrackingKind.bodyweightReps.requiresWeight)
        XCTAssertFalse(ExerciseTrackingKind.repsOnly.requiresWeight)
        XCTAssertFalse(ExerciseTrackingKind.time.requiresWeight)
        XCTAssertTrue(ExerciseTrackingKind.assistedBodyweight.requiresWeight)
        XCTAssertTrue(ExerciseTrackingKind.weightTime.requiresWeight)
        XCTAssertEqual(ExerciseTrackingKind.time.repsHeader, "TIME")
    }

    @MainActor
    func testDeletingWorkoutSetRenumbersRemainingSets() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        let exercise = try XCTUnwrap(appState.activeWorkout?.exercises.first)
        let originalLogs = appState.setLogs(for: exercise).sorted { $0.setNumber < $1.setNumber }
        XCTAssertGreaterThanOrEqual(originalLogs.count, 3)

        appState.deleteSetLog(originalLogs[1])

        XCTAssertEqual(
            appState.setLogs(for: exercise).sorted { $0.setNumber < $1.setNumber }.map(\.setNumber),
            Array(1..<originalLogs.count)
        )
        let added = try XCTUnwrap(appState.addSetLog(to: exercise))
        XCTAssertEqual(added.setNumber, originalLogs.count)
    }

    @MainActor
    func testDeletedPlannedWorkoutSetDoesNotReappearAfterRelaunch() throws {
        let store = InMemoryWorkoutPersistenceStore()
        let firstRepository = makePlannedRepository(workoutPersistenceStore: store)
        let firstState = AppState(repository: firstRepository)
        let prescription = try XCTUnwrap(firstRepository.workoutPrescriptions.first { $0.sets >= 3 })
        let session = try XCTUnwrap(firstRepository.workoutSessions.first { $0.id == prescription.sessionID })

        XCTAssertTrue(firstState.startWorkout(session))
        let exercise = try XCTUnwrap(firstState.activeWorkout?.exercises.first {
            $0.sourcePrescriptionID == prescription.id
        })
        let originalLogs = firstState.setLogs(for: exercise)
        XCTAssertGreaterThanOrEqual(originalLogs.count, 3)

        firstState.deleteSetLog(originalLogs[1])
        XCTAssertEqual(firstState.setLogs(for: exercise).count, originalLogs.count - 1)
        firstRepository.persistWorkoutSnapshot()

        let restoredRepository = DemoRepository(workoutPersistenceStore: store)
        let restoredStore = ActiveWorkoutStore(repository: restoredRepository)
        let restoredExercise = try XCTUnwrap(restoredStore.workout?.exercises.first)

        XCTAssertEqual(restoredStore.setLogs(for: restoredExercise).count, originalLogs.count - 1)
        XCTAssertFalse(restoredStore.setLogs(for: restoredExercise).contains { $0.id == originalLogs[1].id })
    }

    @MainActor
    func testDeletedSetDoesNotBlockActiveExerciseCompletion() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        let exercise = try XCTUnwrap(appState.activeWorkout?.exercises.first)
        let originalLogs = appState.setLogs(for: exercise).sorted { $0.setNumber < $1.setNumber }
        XCTAssertGreaterThanOrEqual(originalLogs.count, 3)

        appState.deleteSetLog(originalLogs[2])
        for var log in appState.setLogs(for: exercise) {
            log.weight = 135
            log.reps = 5
            log.isComplete = true
            appState.updateSetLog(log)
        }

        let progress = appState.activeWorkoutExerciseProgress(for: exercise)
        XCTAssertEqual(progress.plannedWorkingSets, originalLogs.count - 1)
        XCTAssertEqual(progress.completedWorkingSets, originalLogs.count - 1)
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(appState.activeWorkoutFinishReadiness, .ready)
    }

    func testCompositeBodyPartsResolveToMultipleHighlightedRegions() {
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Chest/Triceps")),
            Set([.chest, .arms])
        )
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Quads/Glutes")),
            Set([.upperLegs, .glutes])
        )
        XCTAssertEqual(
            Set(ExerciseBodyRegionResolver.regions(for: "Back/Core")),
            Set([.back, .core])
        )
    }

    func testEveryCatalogExerciseHasSpecificBodyRegionArtwork() {
        let unexpectedFallbacks = MockData.trainingExerciseLibrary.filter { exercise in
            ExerciseBodyRegionResolver.regions(for: exercise.bodyPart) == [.fullBody] &&
                !exercise.bodyPart.localizedCaseInsensitiveContains("full body")
        }
        XCTAssertTrue(unexpectedFallbacks.isEmpty, "Missing body-region mapping for: \(unexpectedFallbacks.map(\.bodyPart))")
    }

    @MainActor
    func testUserCanAddWorkoutEntry() {
        let repository = DemoRepository()
        let initialCount = repository.workoutEntries.count
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: MockData.defaultWorkoutPlanID,
            week: 1,
            date: .now,
            day: "Friday",
            workout: "Freestyle Workout",
            exercise: "Cable row",
            muscleGroup: "Back",
            targetSets: 3,
            targetReps: "10-12",
            sets: [WorkoutSetEntry(id: UUID(), weight: 120, reps: 12, rpe: 8)],
            isDone: true,
            notes: "Added by user"
        )

        repository.addWorkoutEntry(entry)

        XCTAssertEqual(repository.workoutEntries.count, initialCount + 1)
        XCTAssertEqual(repository.workoutEntries.first?.exercise, "Cable row")
        XCTAssertTrue(repository.workoutEntries.first?.isDone == true)
    }

    @MainActor
    func testDeletingWorkoutPlanRemovesOnlyThatPlansEntries() {
        let repository = DemoRepository()
        let plan = WorkoutPlan(id: UUID(), name: "Test Plan", createdAt: .now)
        let entry = WorkoutExerciseEntry(
            id: UUID(),
            planID: plan.id,
            week: 1,
            date: .now,
            day: "Friday",
            workout: "Pull",
            exercise: "Cable row",
            muscleGroup: "Back",
            targetSets: 3,
            targetReps: "10-12",
            sets: [],
            isDone: false,
            notes: ""
        )

        repository.addWorkoutPlan(plan)
        repository.addWorkoutEntry(entry)

        XCTAssertTrue(repository.workoutPlans.contains { $0.id == plan.id })
        XCTAssertTrue(repository.workoutEntries.contains { $0.planID == plan.id })

        repository.deleteWorkoutPlan(plan)

        XCTAssertFalse(repository.workoutPlans.contains { $0.id == plan.id })
        XCTAssertFalse(repository.workoutEntries.contains { $0.planID == plan.id })
    }


    @MainActor

    func testRelativeTimeFormatterDoesNotShowSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now), "Just now")
        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-90), now: now), "1 min ago")
        XCTAssertFalse(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now).contains("sec"))
    }

    @MainActor
    func testProgramBuilderCanCloneAndDeleteWeeks() {
        let repository = makePlannedRepository()
        guard let planID = repository.workoutPlans.first?.id,
              let originalWeek = repository.workoutWeeks.first(where: { $0.planID == planID && $0.weekNumber == 1 }) else {
            XCTFail("Expected seeded week")
            return
        }
        let originalSessionCount = repository.workoutSessions.filter { $0.weekID == originalWeek.id }.count
        let originalPrescriptionCount = repository.workoutPrescriptions.count
        let nextWeekNumber = (repository.workoutWeeks.map(\.weekNumber).max() ?? 0) + 1

        let clonedWeek = repository.cloneWorkoutWeek(originalWeek)

        XCTAssertNotEqual(clonedWeek.id, originalWeek.id)
        XCTAssertEqual(clonedWeek.weekNumber, nextWeekNumber)
        XCTAssertEqual(repository.workoutSessions.filter { $0.weekID == clonedWeek.id }.count, originalSessionCount)
        XCTAssertGreaterThan(repository.workoutPrescriptions.count, originalPrescriptionCount)

        repository.deleteWorkoutWeek(clonedWeek)

        XCTAssertFalse(repository.workoutWeeks.contains { $0.id == clonedWeek.id })
        XCTAssertFalse(repository.workoutSessions.contains { $0.weekID == clonedWeek.id })
    }

    @MainActor
    func testCancelFreestyleWorkoutRemovesSession() {
        let appState = AppState()
        let session = appState.startFreestyleSession()

        appState.cancelWorkout(session)

        XCTAssertFalse(appState.workoutSessions.contains { $0.id == session.id })
        XCTAssertTrue(appState.prescriptions(for: session).isEmpty)
    }

    @MainActor
    func testCancelPlannedWorkoutClearsTodaysSetLogsOnly() {
        let appState = makePlannedAppState()
        guard let session = appState.workoutSessions.first(where: { $0.name != "Freestyle Workout" }),
              let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected seeded planned workout")
            return
        }

        var log = appState.addSetLog(to: prescription)
        log.weight = 225
        log.reps = 5
        log.isComplete = true
        appState.updateSetLog(log)

        appState.cancelWorkout(session)

        XCTAssertTrue(appState.workoutSessions.contains { $0.id == session.id })
        XCTAssertTrue(appState.activeSetLogs(for: prescription).isEmpty)
    }

    @MainActor
    func testCustomExerciseCanBeSavedAndAddedToSession() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let session = appState.addSession(to: week, day: "Friday", name: "Arms")

        guard let exercise = appState.saveCustomExercise(name: "Cable Bayesian Curl", bodyPart: "Arms", equipment: "Cable", trackingType: "Weight + Reps") else {
            XCTFail("Expected custom exercise")
            return
        }
        appState.addExercise(exercise, to: session, sets: 3, reps: "10-15", restSeconds: 90)

        XCTAssertTrue(appState.customTrainingExercises.contains { $0.name == "Cable Bayesian Curl" })
        XCTAssertEqual(exercise.trackingType, "Weight + Reps")
        XCTAssertTrue(appState.prescriptions(for: session).contains { prescription in
            prescription.exerciseName == "Cable Bayesian Curl" &&
            prescription.sets == 3 &&
            prescription.reps == "10-15" &&
            prescription.restSeconds == 90
        })
    }

    @MainActor
    func testWorkoutSummaryUsesCompletedSetLogs() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let session = appState.addSession(to: week, day: "Saturday", name: "Test Workout")
        let exercise = TrainingExerciseCatalogItem(id: "test_press", name: "Test Press", bodyPart: "Chest", workoutCategory: "Push", defaultSets: 2, defaultReps: "5", symbolName: "dumbbell.fill", equipment: "Barbell")
        appState.addExercises([exercise], to: session)
        guard let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected prescription")
            return
        }

        var firstSet = appState.addSetLog(to: prescription)
        firstSet.weight = 100
        firstSet.reps = 5
        firstSet.rpe = 8
        firstSet.isComplete = true
        appState.updateSetLog(firstSet)

        var secondSet = appState.addSetLog(to: prescription)
        secondSet.weight = 110
        secondSet.reps = 4
        secondSet.rpe = 9
        secondSet.isComplete = true
        appState.updateSetLog(secondSet)

        let summary = appState.workoutSummary(for: session)

        XCTAssertEqual(summary.completedExercises, 1)
        XCTAssertEqual(summary.totalSets, 2)
        XCTAssertEqual(summary.totalVolume, 940)
        XCTAssertEqual(summary.bestSet?.weight, 110)
    }

    @MainActor
    func testWorkoutSummaryNormalizesMixedRecordedUnits() {
        let repository = DemoRepository()
        let session = WorkoutSession(
            id: UUID(), weekID: UUID(), day: "Sunday", name: "Mixed units", order: 0, notes: ""
        )
        let prescription = WorkoutExercisePrescription(
            id: UUID(), sessionID: session.id, exerciseID: "barbell_bench_press", exerciseName: "Bench",
            bodyPart: "Chest", equipment: "Barbell", sets: 1, reps: "1", restSeconds: 120, order: 0, notes: ""
        )
        repository.workoutSessions = [session]
        repository.workoutPrescriptions = [prescription]
        repository.workoutSetLogs = [WorkoutSetLog(
            id: UUID(), prescriptionID: prescription.id, performedAt: .now, setNumber: 1,
            weight: 100, reps: 1, rpe: nil, isWarmup: false, isComplete: true,
            workoutID: nil, recordedUnit: .kilograms
        )]

        let summary = repository.workoutSummary(for: session)

        XCTAssertEqual(summary.totalVolume, 220.46226218, accuracy: 0.001)
    }

    @MainActor
    func testWorkoutSummaryExcludesWarmupsAndTimedVolume() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let session = appState.addSession(to: week, day: "Sunday", name: "Summary Tracking Test")
        guard let bench = appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }),
              let timed = appState.trainingExerciseLibrary.first(where: { $0.id == "farmers_carry" }) else {
            XCTFail("Expected bench and timed exercises")
            return
        }
        appState.addExercises([bench, timed], to: session)
        let prescriptions = appState.prescriptions(for: session)
        guard let benchPrescription = prescriptions.first(where: { $0.exerciseID == bench.id }),
              let timedPrescription = prescriptions.first(where: { $0.exerciseID == timed.id }) else {
            XCTFail("Expected both prescriptions")
            return
        }

        var benchSet = appState.addSetLog(to: benchPrescription)
        benchSet.weight = 100
        benchSet.reps = 5
        benchSet.isComplete = true
        appState.updateSetLog(benchSet)

        var warmup = appState.addSetLog(to: benchPrescription)
        warmup.weight = 135
        warmup.reps = 3
        warmup.isWarmup = true
        warmup.isComplete = true
        appState.updateSetLog(warmup)

        var timedSet = appState.addSetLog(to: timedPrescription)
        timedSet.weight = 100
        timedSet.reps = 60
        timedSet.isComplete = true
        appState.updateSetLog(timedSet)

        let summary = appState.workoutSummary(for: session)

        XCTAssertEqual(summary.completedExercises, 2)
        XCTAssertEqual(summary.totalSets, 2)
        XCTAssertEqual(summary.totalVolume, 500)
        XCTAssertEqual(summary.bestSet?.id, benchSet.id)

    }

    func testWorkoutSummaryAchievementSetsExcludeWarmupsAndTimedExercises() {
        let workoutID = UUID()
        let benchID = UUID()
        let timedID = UUID()
        let benchSetID = UUID()
        let warmupID = UUID()
        let timedSetID = UUID()
        let workout = ActiveWorkoutState(
            id: workoutID,
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            sourceWeekID: nil,
            name: "Summary tracking test",
            dayLabel: "Sunday",
            startedAt: .now,
            pausedAt: nil,
            accumulatedPausedTime: 0,
            gymID: nil,
            bodyweight: nil,
            unit: .pounds,
            exercises: [
                WorkoutExerciseSnapshot(
                    id: benchID, sourcePrescriptionID: nil, exerciseID: "bench", exerciseName: "Bench",
                    bodyPart: "Chest", equipment: "Barbell", targetSets: 1, targetReps: "5", restSeconds: 120,
                    order: 0, notes: "", rankingExerciseID: "bench", trackingType: "Weight + Reps"
                ),
                WorkoutExerciseSnapshot(
                    id: timedID, sourcePrescriptionID: nil, exerciseID: "farmers_carry", exerciseName: "Carry",
                    bodyPart: "Full Body", equipment: "Dumbbell", targetSets: 1, targetReps: "60", restSeconds: 60,
                    order: 1, notes: "", rankingExerciseID: nil, trackingType: "Weight + Time"
                )
            ],
            automaticRestTimerEnabled: false,
            restTimerEndsAt: nil,
            restTimerExerciseID: nil
        )
        let logs = [
            WorkoutSetLog(
                id: benchSetID, prescriptionID: benchID, performedAt: .now, setNumber: 1,
                weight: 100, reps: 5, rpe: nil, isWarmup: false, isComplete: true, workoutID: workoutID
            ),
            WorkoutSetLog(
                id: warmupID, prescriptionID: benchID, performedAt: .now, setNumber: 2,
                weight: 135, reps: 3, rpe: nil, isWarmup: true, isComplete: true, workoutID: workoutID
            ),
            WorkoutSetLog(
                id: timedSetID, prescriptionID: timedID, performedAt: .now, setNumber: 1,
                weight: 100, reps: 60, rpe: nil, isWarmup: false, isComplete: true, workoutID: workoutID
            )
        ]

        XCTAssertEqual(
            WorkoutSummaryView.achievementWorkingSets(workout: workout, logs: logs, catalog: []).map(\.id),
            [benchSetID]
        )
    }

    func testWorkoutSummaryDoesNotRepeatPreviouslyEarnedMilestonesWhenUnlockStorageIsEmpty() {
        XCTAssertEqual(
            WorkoutSummaryView.newlyUnlockedTitles(
                projected: ["First Workout", "2 Workouts", "3 Workouts"],
                alreadyEarned: ["First Workout", "2 Workouts", "3 Workouts"]
            ),
            []
        )
        XCTAssertEqual(
            WorkoutSummaryView.newlyUnlockedTitles(
                projected: ["First Workout", "2 Workouts", "3 Workouts", "5 Workouts"],
                alreadyEarned: ["First Workout", "2 Workouts", "3 Workouts"]
            ),
            ["5 Workouts"]
        )
    }

    func testCompletedWorkoutVolumeNormalizesMixedRecordedUnits() {
        var workout = makeCompletedWorkout(completedAt: .now)
        workout.unit = .kilograms
        workout.sets[0].recordedUnit = .pounds
        workout.sets[0].weight = 220.46226218

        XCTAssertEqual(workout.totalVolume, 500, accuracy: 0.001)
    }

    @MainActor
    func testStartingFreestyleSessionAddsWorkoutToActiveWeek() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first else {
            XCTFail("Expected selected week")
            return
        }
        let initialCount = appState.sessions(for: week).count

        let session = appState.startFreestyleSession(in: week)

        XCTAssertEqual(session.name, "Freestyle Workout")
        XCTAssertEqual(appState.sessions(for: week).count, initialCount + 1)
        XCTAssertTrue(appState.sessions(for: week).contains { $0.id == session.id })
    }

    @MainActor
    func testFreestyleSessionCanReceiveExercisesImmediately() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first,
              let exercise = appState.trainingExerciseLibrary.first else {
            XCTFail("Expected seeded week and exercise")
            return
        }

        let session = appState.startFreestyleSession(in: week)
        appState.addExercises([exercise], to: session)

        XCTAssertEqual(appState.prescriptions(for: session).count, 1)
        XCTAssertEqual(appState.prescriptions(for: session).first?.exerciseName, exercise.name)
    }

    @MainActor
    func testActiveSetLogsStartBlankWhenHistoryExists() {
        let appState = makePlannedAppState()
        guard let week = appState.selectedPlanWeeks.first,
              let session = appState.sessions(for: week).first,
              let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected seeded prescription")
            return
        }
        appState.repository.workoutSetLogs.append(WorkoutSetLog(
            id: UUID(),
            prescriptionID: prescription.id,
            performedAt: Date().addingTimeInterval(-24 * 60 * 60),
            setNumber: 1,
            weight: 100,
            reps: 8,
            rpe: 7,
            isWarmup: false,
            isComplete: true,
            workoutID: nil
        ))
        XCTAssertFalse(appState.setLogs(for: prescription).isEmpty)

        let activeLog = appState.addSetLog(to: prescription)

        XCTAssertEqual(activeLog.setNumber, 1)
        XCTAssertNil(activeLog.weight)
        XCTAssertNil(activeLog.reps)
        XCTAssertEqual(appState.activeSetLogs(for: prescription).count, 1)
    }

    func testProfileLiftVideoLibraryShowsOnlyPlayableVisibleAthleteVideos() {
        let athleteID = UUID()
        let visitorID = UUID()
        let otherAthleteID = UUID()
        let publicVideo = makeLift(userID: athleteID, weight: 585, hasVideo: true)
        let privateVideo = makeLift(userID: athleteID, weight: 600, hasVideo: true, visibility: .privateLift)
        let noVideo = makeLift(userID: athleteID, weight: 610)
        let otherVideo = makeLift(userID: otherAthleteID, weight: 700, hasVideo: true)
        let lifts = [noVideo, privateVideo, publicVideo, otherVideo]

        XCTAssertEqual(
            ProfileLiftVideoLibrary.visibleLifts(for: athleteID, viewerID: visitorID, allLifts: lifts).map(\.id),
            [publicVideo.id]
        )
        XCTAssertEqual(
            Set(ProfileLiftVideoLibrary.visibleLifts(for: athleteID, viewerID: athleteID, allLifts: lifts).map(\.id)),
            Set([publicVideo.id, privateVideo.id])
        )
    }

    @MainActor
    func testLiftAwardsRefreshForCurrentUserLoggedLiftOnly() {
        let repository = DemoRepository()
        repository.lifts = []
        repository.achievementUnlocks = []
        let currentUserID = repository.currentProfile.id
        repository.lifts = [makeLift(userID: UUID(), weight: 225, exerciseID: "bench")]

        repository.refreshAchievementUnlocks(now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertFalse(repository.achievementUnlocks.contains { $0.title == "First Lift Logged" })

        repository.addLift(makeLift(userID: currentUserID, weight: 225, exerciseID: "bench"))

        XCTAssertTrue(repository.achievementUnlocks.contains { $0.title == "First Lift Logged" })
        XCTAssertEqual(
            RankingCalculator.bestLift(exerciseID: "bench", submissions: repository.lifts.filter { $0.userID == currentUserID })?.weight,
            225
        )
    }

    @MainActor
    func testAchievementRefreshSkipsUnchangedPublish() {
        let repository = DemoRepository()
        repository.lifts = []
        repository.achievementUnlocks = []
        var publishCount = 0
        let cancellable = repository.$achievementUnlocks.dropFirst().sink { _ in
            publishCount += 1
        }

        repository.addLift(makeLift(userID: repository.currentProfile.id, weight: 225, exerciseID: "bench"))
        XCTAssertEqual(publishCount, 1)

        repository.refreshAchievementUnlocks(now: Date(timeIntervalSince1970: 1_800_000_100))

        XCTAssertEqual(publishCount, 1)
        cancellable.cancel()
    }

    @MainActor
    func testAchievementRefreshPreservesPreviouslyUnlockedAwards() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.lifts = []
        repository.completedWorkouts = []
        repository.achievementUnlocks = [
            AchievementUnlock(id: "first-workout", title: "First Workout", unlockedAt: .now)
        ]

        repository.refreshAchievementUnlocks()

        XCTAssertTrue(repository.achievementUnlocks.contains { $0.title == "First Workout" })
    }

    @MainActor
    func testInitialProductionRefreshPreservesPersistedAchievementUnlocks() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let unlock = AchievementUnlock(
            id: "first-workout",
            title: "First Workout",
            unlockedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        repository.achievementUnlocks = [unlock]
        let store = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository)
        )

        await store.refreshProductionData()

        XCTAssertEqual(repository.achievementUnlocks, [unlock])
    }

    @MainActor
    func testVolumeAwardsNormalizeRecordedUnitsToKilograms() {
        let poundsRepository = DemoRepository()
        var poundsWorkout = makeCompletedWorkout(completedAt: .now)
        poundsWorkout.sets[0].weight = 220.46226218
        poundsWorkout.sets[0].reps = 100
        poundsRepository.completedWorkouts = [poundsWorkout]

        let kilogramsRepository = DemoRepository()
        var kilogramsWorkout = makeCompletedWorkout(completedAt: .now)
        kilogramsWorkout.sets[0].weight = 100
        kilogramsWorkout.sets[0].reps = 100
        kilogramsWorkout.sets[0].recordedUnit = .kilograms
        kilogramsRepository.completedWorkouts = [kilogramsWorkout]

        XCTAssertEqual(
            poundsRepository.computedStatistics().lifetimeWorkingSetVolume,
            kilogramsRepository.computedStatistics().lifetimeWorkingSetVolume,
            accuracy: 0.001
        )

        poundsRepository.refreshAchievementUnlocks()
        XCTAssertTrue(poundsRepository.achievementUnlocks.contains { $0.title == "10,000 kg Lifted Volume" })
    }

    @MainActor
    func testCompetitionPRCountUsesTheBestSetSeenSoFar() {
        let repository = DemoRepository()
        let weights = [200.0, 225.0, 250.0]
        repository.completedWorkouts = weights.enumerated().map { index, weight in
            var workout = makeCompletedWorkout(
                completedAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index) * 86_400)
            )
            workout.sets[0].weight = weight
            workout.sets[0].reps = 1
            return workout
        }

        XCTAssertEqual(repository.computedStatistics().prCount, weights.count)
    }

    private func makeLift(
        userID: UUID,
        weight: Double,
        exerciseID: String = "deadlift",
        repetitions: Int = 1,
        hasVideo: Bool = false,
        visibility: LiftVisibility = .publicLift
    ) -> LiftSubmission {
        LiftSubmission(
            id: UUID(),
            userID: userID,
            exerciseID: exerciseID,
            exerciseName: exerciseID.capitalized,
            weight: weight,
            unit: .pounds,
            normalizedWeightKilograms: RankingCalculator.poundsToKilograms(weight),
            repetitions: repetitions,
            isActualOneRepMax: repetitions == 1,
            estimatedOneRepMax: RankingCalculator.epleyOneRepMax(weight: weight, repetitions: repetitions),
            bodyweightAtLift: 200,
            bodyweightMultiple: RankingCalculator.bodyweightMultiple(oneRepMax: weight, bodyweight: 200),
            equipmentType: .raw,
            variation: "Conventional deadlift",
            gymID: MockData.demoGymID,
            performedAt: .now,
            localVideoURL: nil,
            remoteVideoURL: hasVideo ? URL(string: "https://example.com/lift.mov") : nil,
            demoMediaID: nil,
            caption: "",
            verificationStatus: .videoVerified,
            visibility: visibility,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeProfile(id: UUID = UUID(), username: String = "focused_lifter") -> UserProfile {
        var profile = MockData.emptyProfile
        profile.id = id
        profile.username = username
        profile.displayName = username.replacingOccurrences(of: "_", with: " ").capitalized
        profile.bodyweightPounds = 200
        return profile
    }

    private func makeSetLog(setNumber: Int) -> WorkoutSetLog {
        WorkoutSetLog(
            id: UUID(),
            prescriptionID: UUID(),
            performedAt: .now,
            setNumber: setNumber,
            weight: nil,
            reps: nil,
            rpe: nil,
            isWarmup: false,
            isComplete: false
        )
    }

    private func makeCompletedWorkout(completedAt: Date) -> CompletedWorkout {
        let workoutID = UUID()
        let exerciseID = UUID()
        let exercise = WorkoutExerciseSnapshot(
            id: exerciseID,
            sourcePrescriptionID: nil,
            exerciseID: "barbell_bench_press",
            exerciseName: "Barbell Bench Press",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetSets: 1,
            targetReps: "5",
            restSeconds: 120,
            order: 0,
            notes: "",
            rankingExerciseID: "bench"
        )
        let set = WorkoutSetLog(
            id: UUID(),
            prescriptionID: exerciseID,
            performedAt: completedAt,
            setNumber: 1,
            weight: 225,
            reps: 5,
            rpe: 8,
            isWarmup: false,
            isComplete: true,
            workoutID: workoutID,
            recordedUnit: .pounds
        )
        return CompletedWorkout(
            id: workoutID,
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            name: "Strength Workout",
            dayLabel: completedAt.formatted(.dateTime.weekday(.wide)),
            startedAt: completedAt.addingTimeInterval(-3_600),
            completedAt: completedAt,
            duration: 3_600,
            effort: 3,
            notes: "",
            gymID: nil,
            bodyweight: 210,
            unit: .pounds,
            exercises: [exercise],
            sets: [set],
            linkedSubmissionIDs: []
        )
    }

    func testLeaderboardTotalUsesOneRepPRsAndAllowsPartialTotals() {
        let profile = makeProfile()
        let userID = profile.id
        let lifts = [
            makeLift(userID: userID, weight: 300, exerciseID: "squat", repetitions: 1),
            makeLift(userID: userID, weight: 225, exerciseID: "bench", repetitions: 1),
            makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1),
            makeLift(userID: userID, weight: 600, exerciseID: "deadlift", repetitions: 5)
        ]
        let entries = RankingCalculator.leaderboardEntries(
            profiles: [profile],
            lifts: lifts,
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].score, RankingCalculator.poundsToKilograms(1_025), accuracy: 0.001)
        XCTAssertEqual(entries[0].powerliftingBreakdown?.deadliftKilograms ?? 0, RankingCalculator.poundsToKilograms(500), accuracy: 0.001)

        let partialEntries = RankingCalculator.leaderboardEntries(
            profiles: [profile],
            lifts: [makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1)],
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )
        XCTAssertEqual(partialEntries.count, 1)
        XCTAssertNil(partialEntries[0].powerliftingBreakdown?.benchKilograms)
    }

    func testExerciseLeaderboardUsesSubmittedWeightRatherThanEstimatedMax() {
        let profiles = [makeProfile(username: "first_lifter"), makeProfile(username: "second_lifter")]
        let firstUser = profiles[0].id
        let secondUser = profiles[1].id
        var lighter = makeLift(userID: firstUser, weight: 300, exerciseID: "bench", repetitions: 10)
        lighter.estimatedOneRepMax = 400
        let heavier = makeLift(userID: secondUser, weight: 315, exerciseID: "bench", repetitions: 1)

        let entries = RankingCalculator.leaderboardEntries(
            profiles: profiles,
            lifts: [lighter, heavier],
            rankingType: .absolute,
            verifiedOnly: false,
            currentUserID: nil,
            exerciseID: "bench"
        )

        XCTAssertEqual(entries.first?.profile.id, secondUser)
        XCTAssertEqual(entries.first?.score, heavier.normalizedWeightKilograms)
    }

    @MainActor
    func testExerciseRepFilterAndModeNormalization() {
        let appState = AppState()
        appState.verifiedOnly = false
        appState.selectLeaderboardExercise("deadlift")
        appState.leaderboardFilters.repetitionCount = 1
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .absolute)
        XCTAssertTrue(appState.leaderboardEntries().allSatisfy { $0.lift.repetitions == 1 })

        appState.selectLeaderboardExercise(nil)
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .total)
        XCTAssertNil(appState.leaderboardFilters.repetitionCount)
    }

    @MainActor
    func testFocusedLeaderboardStartsWithoutSeededOpponents() {
        let appState = AppState()
        XCTAssertTrue(appState.leaderboardEntries().isEmpty)
    }


    func testLegacyModeratorVerifiedStatusMigratesToVideoVerified() throws {
        let data = try XCTUnwrap("\"Moderator Verified\"".data(using: .utf8))

        let status = try JSONDecoder().decode(VerificationStatus.self, from: data)

        XCTAssertEqual(status, .videoVerified)
        XCTAssertEqual(status.rawValue, "Video Verified")
        XCTAssertFalse(VerificationStatus.allCases.map(\.rawValue).contains("Moderator Verified"))
    }

    func testCommunityVerifiedStatusMatchesCanonicalServerLabel() throws {
        let data = try JSONEncoder().encode("Community Verified")
        let status = try JSONDecoder().decode(VerificationStatus.self, from: data)

        XCTAssertEqual(status, .communityVerified)
        XCTAssertTrue(status.isDefaultLeaderboardEligible)
    }

    func testFriendsOnlyLiftVisibilityMatchesServerAndStaysOffPublicRankings() {
        var lift = makeLift(userID: UUID(), weight: 405)
        lift.visibility = .friendsLift

        XCTAssertEqual(LiftVisibility(rawValue: "Friends"), .friendsLift)
        XCTAssertFalse(lift.isLaunchLeaderboardEligible)
    }

    @MainActor
    func testEvidenceFreeOwnerSubmissionCanBePermanentlyDeleted() async throws {
        let repository = DemoRepository()
        var lift = makeLift(userID: repository.currentProfile.id, weight: 405)
        lift.visibility = .privateLift
        lift.verificationStatus = .selfReported
        lift.evidenceStatus = .selfReported
        lift.videoAssetID = nil
        lift.hasProtectedEvidence = false
        repository.lifts = [lift]
        let store = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository)
        )

        try await store.removeSubmission(lift)

        XCTAssertFalse(repository.lifts.contains(where: { $0.id == lift.id }))
    }

    @MainActor
    func testVideoBackedSubmissionUsesCoordinatedRemoval() async throws {
        let repository = DemoRepository()
        var lift = makeLift(userID: repository.currentProfile.id, weight: 405)
        lift.evidenceStatus = .videoBacked
        lift.videoAssetID = UUID()
        repository.lifts = [lift]
        let store = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository)
        )

        try await store.removeSubmission(lift)

        XCTAssertFalse(repository.lifts.contains(where: { $0.id == lift.id }))
    }

    func testAllSubmissionsIncludesSelfReportedTotal() {
        let profile = makeProfile()
        var lifts = [
            makeLift(userID: profile.id, weight: 300, exerciseID: "squat"),
            makeLift(userID: profile.id, weight: 200, exerciseID: "bench"),
            makeLift(userID: profile.id, weight: 400, exerciseID: "deadlift")
        ]
        for index in lifts.indices { lifts[index].verificationStatus = .selfReported }

        let verified = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: lifts, rankingType: .total,
            verifiedOnly: true, currentUserID: nil
        )
        let all = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: lifts, rankingType: .total,
            verifiedOnly: false, currentUserID: nil
        )

        XCTAssertTrue(verified.isEmpty)
        XCTAssertEqual(all.count, 1)
    }

    func testVideoBackedLiftRanksImmediatelyButReportedLiftIsRemovedWhileUnderReview() {
        let profile = makeProfile()
        var lift = makeLift(userID: profile.id, weight: 315, hasVideo: true)
        lift.evidenceStatus = .videoBacked
        lift.videoAssetID = UUID()
        lift.moderationStatus = .clear

        let ranked = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: [lift], rankingType: .absolute,
            verifiedOnly: true, currentUserID: nil
        )
        XCTAssertEqual(ranked.count, 1)

        lift.moderationStatus = .underReview
        let removedFromRanking = RankingCalculator.leaderboardEntries(
            profiles: [profile], lifts: [lift], rankingType: .absolute,
            verifiedOnly: true, currentUserID: nil
        )
        XCTAssertTrue(removedFromRanking.isEmpty)
    }

    @MainActor
    func testActiveWorkoutPersistsAcrossRepositoryRelaunch() {
        let store = InMemoryWorkoutPersistenceStore()
        let firstRepository = DemoRepository(workoutPersistenceStore: store)
        let firstState = AppState(repository: firstRepository)

        XCTAssertTrue(firstState.startFreestyleWorkoutInstance())
        guard let bench = firstState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }) else {
            return XCTFail("Expected canonical bench exercise")
        }
        firstState.addExercisesToActiveWorkout([bench])
        var log = try! XCTUnwrap(firstRepository.workoutSetLogs.first(where: { $0.workoutID == firstState.activeWorkout?.id }))
        log.weight = 275
        log.reps = 5
        log.isComplete = true
        firstState.updateSetLog(log)
        firstRepository.persistWorkoutSnapshot()

        let restoredRepository = DemoRepository(workoutPersistenceStore: store)
        let restoredStore = ActiveWorkoutStore(repository: restoredRepository)
        XCTAssertEqual(restoredRepository.activeWorkout?.id, firstState.activeWorkout?.id)
        XCTAssertEqual(restoredRepository.activeWorkout?.exercises.first?.exerciseID, "barbell_bench_press")
        XCTAssertEqual(restoredRepository.workoutSetLogs.first(where: { $0.id == log.id })?.weight, 275)
        XCTAssertTrue(restoredRepository.workoutSetLogs.first(where: { $0.id == log.id })?.isComplete == true)
        XCTAssertEqual(restoredStore.workout?.id, firstState.activeWorkout?.id)
        let restoredExercise = try! XCTUnwrap(restoredStore.workout?.exercises.first)
        XCTAssertEqual(restoredStore.setLogs(for: restoredExercise).first(where: { $0.id == log.id })?.weight, 275)
        XCTAssertTrue(restoredStore.setLogs(for: restoredExercise).first(where: { $0.id == log.id })?.isComplete == true)
    }

    @MainActor
    func testActiveWorkoutStoreStartsAndMutatesPlannedWorkout() throws {
        let repository = makePlannedRepository()
        let startedAt = Date(timeIntervalSince1970: 1_900_100_000)
        let store = ActiveWorkoutStore(repository: repository, now: { startedAt })
        let session = try XCTUnwrap(repository.workoutSessions.first(where: { session in
            repository.workoutPrescriptions.contains { $0.sessionID == session.id }
        }))
        let planID = repository.workoutWeeks.first(where: { $0.id == session.weekID })?.planID

        let started = try XCTUnwrap(store.startPlanned(
            session: session,
            planID: planID,
            gymID: nil,
            bodyweight: 95,
            unit: .kilograms
        ))

        XCTAssertEqual(started.startedAt, startedAt)
        XCTAssertEqual(started.source, .planned)
        XCTAssertEqual(started.sourceSessionID, session.id)
        XCTAssertEqual(started.sourcePlanID, planID)
        XCTAssertEqual(store.workout?.id, started.id)
        XCTAssertFalse(started.exercises.isEmpty)
        XCTAssertEqual(
            repository.workoutSetLogs.filter { $0.workoutID == started.id }.count,
            started.exercises.reduce(0) { $0 + max(1, $1.targetSets) }
        )
        XCTAssertNil(store.startPlanned(
            session: session,
            planID: planID,
            gymID: nil,
            bodyweight: 95,
            unit: .kilograms
        ))

        let original = try XCTUnwrap(store.workout?.exercises.first)
        let substitute = try XCTUnwrap(MockData.trainingExerciseLibrary.first { item in
            item.id != original.exerciseID &&
                !started.exercises.contains(where: { $0.exerciseID == item.id })
        })
        let replacement = try XCTUnwrap(store.substituteExercise(original, with: substitute))
        XCTAssertEqual(replacement.id, original.id)
        XCTAssertEqual(replacement.exerciseID, substitute.id)
        XCTAssertEqual(replacement.substitutedFromExerciseID, original.exerciseID)
        XCTAssertEqual(store.setLogs(for: replacement).count, max(1, replacement.targetSets))

        let exerciseCountBeforeAdd = try XCTUnwrap(store.workout?.exercises.count)
        let additional = try XCTUnwrap(MockData.trainingExerciseLibrary.first { item in
            !store.workout!.exercises.contains(where: { $0.exerciseID == item.id })
        })
        store.addExercises([additional, additional])
        XCTAssertEqual(store.workout?.exercises.count, exerciseCountBeforeAdd + 1)

        XCTAssertTrue(store.updateSourcePlan())
        let updatedPrescriptions = repository.workoutPrescriptions
            .filter { $0.sessionID == session.id }
            .sorted { $0.order < $1.order }
        XCTAssertEqual(updatedPrescriptions.map(\.exerciseID), store.workout?.exercises.map(\.exerciseID))
        XCTAssertEqual(updatedPrescriptions.map(\.sets), store.workout?.exercises.map(\.targetSets))

        store.discard()
        let freestyle = try XCTUnwrap(store.startFreestyle(
            name: "Evening Training",
            gymID: nil,
            bodyweight: 95,
            unit: .kilograms
        ))
        XCTAssertEqual(freestyle.startedAt, startedAt)
        XCTAssertEqual(freestyle.source, .freestyle)
        XCTAssertEqual(freestyle.name, "Evening Training")
        XCTAssertNil(freestyle.sourceSessionID)
    }

    @MainActor
    func testWorkoutSetEditsCoalesceSnapshotPersistence() async throws {
        let persistence = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: persistence)
        let store = ActiveWorkoutStore(repository: repository)
        let workout = try XCTUnwrap(store.startFreestyle(
            name: "Coalesced Logging",
            gymID: nil,
            bodyweight: 200,
            unit: .pounds
        ))
        let exercise = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })
        store.addExercises([exercise])
        var log = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == workout.id })
        repository.persistWorkoutSnapshot()
        let baselineSaveCount = persistence.saveCount

        log.reps = 5
        store.updateSet(log)
        log.weight = 185
        store.updateSet(log)
        log.rpe = 8
        store.updateSet(log)

        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(persistence.saveCount, baselineSaveCount + 1)

        log.weight = 190
        store.updateSet(log)
        repository.persistWorkoutSnapshot()
        XCTAssertEqual(persistence.saveCount, baselineSaveCount + 2)
    }

    @MainActor
    func testActiveWorkoutDisplayStateTracksSetProgress() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let store = ActiveWorkoutStore(repository: repository)
        let workout = try XCTUnwrap(store.startFreestyle(
            name: "Display State",
            gymID: nil,
            bodyweight: 200,
            unit: .pounds
        ))
        let exercise = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "back_squat" })
        store.addExercises([exercise])
        let activeExercise = try XCTUnwrap(store.workout?.exercises.first)
        let log = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == workout.id })

        XCTAssertEqual(store.displayState.exercises.map(\.id), [activeExercise.id])
        XCTAssertEqual(store.displayState.completedWorkingSets, 0)
        XCTAssertEqual(store.displayState.plannedWorkingSets, activeExercise.targetSets)
        XCTAssertEqual(store.displayState.progressByExerciseID[activeExercise.id]?.completedWorkingSets, 0)

        var editedLog = log
        editedLog.weight = 225
        editedLog.reps = 5
        store.updateSet(editedLog)

        XCTAssertEqual(store.displayState.completedWorkingSets, 0)
        XCTAssertEqual(store.displayState.totalVolume, 0)

        _ = store.applySetCompletion(editedLog, isComplete: true, source: .manual)

        XCTAssertEqual(store.displayState.completedWorkingSets, 1)
        XCTAssertEqual(store.displayState.progressByExerciseID[activeExercise.id]?.completedWorkingSets, 1)
        XCTAssertEqual(store.displayState.totalVolume, 1_125)

        store.deleteSet(log)

        XCTAssertEqual(store.displayState.completedWorkingSets, 0)
        XCTAssertEqual(store.displayState.progressByExerciseID[activeExercise.id]?.completedWorkingSets, 0)
    }

    @MainActor
    func testProgramStoreOwnsSelectedPlanProjectionsAndLifecycle() throws {
        let repository = makePlannedRepository()
        let createdAt = Date(timeIntervalSince1970: 1_900_200_000)
        let createdID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let store = ProgramStore(
            repository: repository,
            now: { createdAt },
            makeID: { createdID }
        )
        let existingPlan = try XCTUnwrap(store.plans.first)

        XCTAssertEqual(store.plan(id: existingPlan.id), existingPlan)
        XCTAssertEqual(store.phases(planID: existingPlan.id), store.phases(planID: existingPlan.id).sorted { $0.order < $1.order })
        XCTAssertEqual(store.weeks(planID: existingPlan.id), store.weeks(planID: existingPlan.id).sorted { $0.weekNumber < $1.weekNumber })
        XCTAssertNil(store.createPlan(name: "   "))

        let created = try XCTUnwrap(store.createPlan(name: "  Meet Prep  "))
        XCTAssertEqual(created.id, createdID)
        XCTAssertEqual(created.name, "Meet Prep")
        XCTAssertEqual(created.createdAt, createdAt)
        XCTAssertTrue(store.renamePlan(id: created.id, to: "  Updated Prep "))
        XCTAssertEqual(store.plan(id: created.id)?.name, "Updated Prep")
        XCTAssertFalse(store.renamePlan(id: created.id, to: "  "))

        let copy = try XCTUnwrap(store.duplicatePlan(id: created.id))
        XCTAssertEqual(copy.name, "Updated Prep Copy")
        let deletion = try XCTUnwrap(store.deletePlan(id: created.id))
        XCTAssertEqual(deletion.deletedPlanID, created.id)
        XCTAssertNotEqual(deletion.fallbackPlanID, created.id)
        XCTAssertNil(store.plan(id: created.id))
        XCTAssertNotNil(store.plan(id: deletion.fallbackPlanID))
    }

    @MainActor
    func testProgramStoreOwnsWeekSessionAndPrescriptionMutations() throws {
        let repository = makePlannedRepository()
        let generatedIDs = [
            UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        ]
        var generatedIndex = 0
        let store = ProgramStore(repository: repository, makeID: {
            defer { generatedIndex += 1 }
            return generatedIDs[generatedIndex]
        })
        let plan = try XCTUnwrap(store.plans.first)
        let week = store.addWeek(planID: plan.id)
        let session = store.addSession(to: week, day: "Saturday", name: "   ")
        XCTAssertEqual(session.name, "Workout")

        let exercises = Array(MockData.trainingExerciseLibrary.prefix(2))
        XCTAssertEqual(exercises.count, 2)
        store.addExercises(exercises, to: session)
        var prescriptions = store.prescriptions(session: session)
        XCTAssertEqual(prescriptions.map(\.id), Array(generatedIDs.prefix(2)))
        XCTAssertEqual(prescriptions.map(\.order), [0, 1])
        XCTAssertEqual(prescriptions.map(\.exerciseID), exercises.map(\.id))

        let custom = store.addExercise(
            exercises[0],
            to: session,
            sets: 0,
            reps: "   ",
            restSeconds: 75
        )
        XCTAssertEqual(custom.id, generatedIDs[2])
        XCTAssertEqual(custom.sets, 1)
        XCTAssertEqual(custom.reps, "8-12")
        XCTAssertEqual(custom.order, 2)

        store.deletePrescription(prescriptions.removeFirst())
        XCTAssertEqual(store.prescriptions(session: session).count, 2)
        let clone = store.cloneWeek(week)
        XCTAssertEqual(store.sessions(week: clone).count, 1)
        XCTAssertEqual(store.prescriptions(session: try XCTUnwrap(store.sessions(week: clone).first)).count, 2)

        store.deleteWeek(week)
        XCTAssertFalse(store.weeks(planID: plan.id).contains { $0.id == week.id })
        XCTAssertFalse(repository.workoutSessions.contains { $0.id == session.id })
        XCTAssertFalse(repository.workoutPrescriptions.contains { $0.sessionID == session.id })
    }

    @MainActor
    func testProgramStoreValidatesProgramSetupBeforeRepositoryMutation() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let store = ProgramStore(repository: repository)
        let template = try XCTUnwrap(WorkoutProgramCatalog.templates.first(where: { !$0.requiredTrainingMaxExerciseIDs.isEmpty }))
        let initialPlanCount = store.plans.count

        XCTAssertNil(store.startProgram(
            template: template,
            startDate: .now,
            scheduledWeekdays: [],
            method: .fixed,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        ))
        XCTAssertNil(store.startProgram(
            template: template,
            startDate: .now,
            scheduledWeekdays: template.sessions.map(\.dayIndex),
            method: .percentage,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        ))
        XCTAssertEqual(store.plans.count, initialPlanCount)
    }

    @MainActor
    func testTrainingProgressStoreOwnsNormalizedHistoryVolumeStreakAndPlateaus() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let bench = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let latestDate = Date(timeIntervalSince1970: 1_900_300_000)
        let volumePlanID = UUID()
        let store = TrainingProgressStore(repository: repository, calendar: calendar)
        let startingVolume = store.volumeByBodyPart(
            planID: volumePlanID,
            preferredUnit: .pounds
        )[bench.bodyPart] ?? 0

        for dayOffset in stride(from: 2, through: 0, by: -1) {
            let startedAt = calendar.date(byAdding: .day, value: -dayOffset, to: latestDate)!
            _ = try XCTUnwrap(repository.startFreestyleWorkout(
                name: "Bench Training",
                gymID: nil,
                bodyweight: 200,
                unit: .pounds,
                at: startedAt
            ))
            repository.addExercisesToActiveWorkout([bench])
            var log = try XCTUnwrap(repository.workoutSetLogs.first {
                $0.workoutID == repository.activeWorkout?.id
            })
            log.weight = 100
            log.reps = 5
            log.isComplete = true
            repository.updateWorkoutSetLog(log)
            _ = try XCTUnwrap(repository.finishActiveWorkout(
                effort: 3,
                notes: "",
                at: startedAt.addingTimeInterval(1_800)
            ))
        }

        let history = store.exerciseHistory(for: bench.id)
        let records = store.exerciseRecords(for: bench.id)
        let kilograms = RankingCalculator.poundsToKilograms(100)

        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history.first?.bestWeightKilograms ?? 0, kilograms, accuracy: 0.001)
        XCTAssertEqual(history.first?.sessionVolumeKilograms ?? 0, kilograms * 5, accuracy: 0.001)
        XCTAssertEqual(records.heaviestWeightKilograms ?? 0, kilograms, accuracy: 0.001)
        XCTAssertEqual(records.bestSetVolumeKilograms ?? 0, kilograms * 5, accuracy: 0.001)
        XCTAssertEqual(records.mostRepetitions, 5)
        XCTAssertEqual(
            (store.volumeByBodyPart(planID: volumePlanID, preferredUnit: .pounds)[bench.bodyPart] ?? 0) - startingVolume,
            1_500,
            accuracy: 0.001
        )
        XCTAssertEqual(store.workoutStreak(referenceDate: latestDate.addingTimeInterval(1_800)), 3)
        XCTAssertEqual(store.lastCompletedWorkoutDate(), latestDate.addingTimeInterval(1_800))
        XCTAssertEqual(store.plateauInsights.first?.exerciseID, bench.id)
        XCTAssertEqual(store.plateauInsights.first?.performances.count, 3)

        let draftBodyweight = BodyweightEntry.draftForCurrentWeek(
            entries: store.bodyweightEntries,
            currentBodyweightPounds: 200,
            calendar: calendar,
            now: latestDate
        )
        store.updateBodyweight(draftBodyweight)
        var bodyweight = try XCTUnwrap(store.bodyweightEntries.first(where: { $0.id == draftBodyweight.id }))
        bodyweight.actual = 201
        bodyweight.notes = "Store test"
        store.updateBodyweight(bodyweight)
        XCTAssertEqual(store.bodyweightEntries.first(where: { $0.id == bodyweight.id }), bodyweight)
        repository.strainEntries = [StrainEntry(strain: 5)]
        repository.injuryEntries = [InjuryEntry(area: "Knee", description: "Private", intensity: 3)]

        repository.currentProfile.id = UUID()
        XCTAssertTrue(store.bodyweightEntries.isEmpty)
        XCTAssertTrue(store.strainEntries.isEmpty)
        XCTAssertTrue(store.injuryEntries.isEmpty)
    }

    @MainActor
    func testTrainingProgressVolumeExcludesWeightAndTimeSets() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let exerciseStore = ExerciseLibraryStore(repository: repository)
        let carry = try XCTUnwrap(exerciseStore.createCustomExercise(
            name: "Timed Carry",
            bodyPart: "Full Body",
            equipment: "Dumbbell",
            trackingType: "Weight + Time"
        ))
        let startedAt = Date(timeIntervalSince1970: 1_900_400_000)
        _ = try XCTUnwrap(repository.startFreestyleWorkout(
            name: "Carry Conditioning",
            gymID: nil,
            bodyweight: 200,
            unit: .pounds,
            at: startedAt
        ))
        repository.addExercisesToActiveWorkout([carry])
        var log = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == repository.activeWorkout?.id })
        log.weight = 100
        log.reps = 60
        log.isComplete = true
        repository.updateWorkoutSetLog(log)
        let completed = try XCTUnwrap(repository.finishActiveWorkout(
            effort: 3,
            notes: "",
            at: startedAt.addingTimeInterval(1_800)
        ))
        let store = TrainingProgressStore(repository: repository)

        XCTAssertEqual(completed.totalVolume, 0)
        XCTAssertEqual(
            store.volumeByBodyPart(planID: completed.sourcePlanID ?? UUID(), preferredUnit: .pounds)[carry.bodyPart] ?? 0,
            0
        )
        XCTAssertTrue(store.plateauInsights.isEmpty)
        XCTAssertEqual(repository.computedStatistics().lifetimeWorkingSetVolume, 0)
        XCTAssertEqual(repository.computedStatistics().totalWorkingSetRepetitions, 0)
        repository.refreshAchievementUnlocks()
        XCTAssertFalse(repository.achievementUnlocks.contains { $0.title == "10,000 kg Lifted Volume" })
    }

    @MainActor
    func testActiveWorkoutStoreProjectsSummaryAndAutomaticCompletion() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])

        let store = ActiveWorkoutStore(repository: repository)
        let exercise = try XCTUnwrap(store.workout?.exercises.first)
        var logs = store.setLogs(for: exercise)
        XCTAssertGreaterThanOrEqual(logs.count, 2)

        logs[0].weight = 225
        logs[0].reps = 5
        repository.updateWorkoutSetLog(logs[0])
        repository.updateWorkoutSetLog(WorkoutSetLog(
            id: UUID(),
            prescriptionID: exercise.id,
            performedAt: .now,
            setNumber: 0,
            weight: 135,
            reps: 10,
            rpe: nil,
            isWarmup: false,
            isComplete: false,
            workoutID: store.workout?.id,
            recordedUnit: .pounds
        ))

        XCTAssertTrue(store.attemptAutomaticCompletion(before: logs[1]))
        XCTAssertEqual(store.completedWorkingSets.map(\.id), [logs[0].id])

        repository.updateWorkoutSetLog(WorkoutSetLog(
            id: UUID(),
            prescriptionID: exercise.id,
            performedAt: .now,
            setNumber: 0,
            weight: 135,
            reps: 10,
            rpe: nil,
            isWarmup: true,
            isComplete: true,
            workoutID: store.workout?.id,
            recordedUnit: .pounds
        ))

        let summary = try XCTUnwrap(store.summary())
        XCTAssertEqual(summary.completedExercises, 1)
        XCTAssertEqual(summary.totalSets, 1)
        XCTAssertEqual(summary.totalVolume, 1_125, accuracy: 0.001)
        XCTAssertEqual(summary.bestSet?.id, logs[0].id)
    }

    @MainActor
    func testActiveWorkoutStoreOwnsLifecycleRestTimerAndExerciseOrder() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        let squat = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "back_squat" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench, squat])
        let workoutID = try XCTUnwrap(repository.activeWorkout?.id)

        let pausedAt = Date(timeIntervalSince1970: 1_900_000_000)
        let resumedAt = pausedAt.addingTimeInterval(75)
        var dates = [pausedAt, resumedAt].makeIterator()
        let store = ActiveWorkoutStore(repository: repository) {
            dates.next() ?? resumedAt
        }

        store.pause()
        XCTAssertEqual(store.workout?.pausedAt, pausedAt)
        store.resume()
        XCTAssertNil(store.workout?.pausedAt)
        XCTAssertEqual(try XCTUnwrap(store.workout?.accumulatedPausedTime), 75, accuracy: 0.001)

        let exercises = try XCTUnwrap(store.workout?.exercises)
        let timerEnd = resumedAt.addingTimeInterval(120)
        store.updateRestTimer(endsAt: timerEnd, exerciseID: exercises[0].id)
        store.setAutomaticRestTimerEnabled(false)
        XCTAssertEqual(store.workout?.restTimerEndsAt, timerEnd)
        XCTAssertEqual(store.workout?.restTimerExerciseID, exercises[0].id)
        XCTAssertFalse(try XCTUnwrap(store.workout?.automaticRestTimerEnabled))

        XCTAssertTrue(store.reorderExercises(exercises.reversed().map(\.id)))
        XCTAssertEqual(store.workout?.exercises.map(\.id), exercises.reversed().map(\.id))
        XCTAssertTrue(store.moveExercise(exercises[0], direction: -1))
        XCTAssertEqual(store.workout?.exercises.map(\.id), exercises.map(\.id))

        store.discard()
        XCTAssertNil(store.workout)
        XCTAssertFalse(repository.workoutSetLogs.contains { $0.workoutID == workoutID })
    }

    @MainActor
    func testActiveWorkoutStoreValidatesAndFinishesWithNotificationCleanup() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        let completedAt = Date(timeIntervalSince1970: 1_900_000_500)
        let notifications = TestWorkoutRestNotificationScheduler()
        let store = ActiveWorkoutStore(
            repository: repository,
            now: { completedAt },
            restNotificationScheduler: notifications
        )

        XCTAssertEqual(store.finishReadiness, .unavailable)
        XCTAssertNil(store.finish(effort: 3, notes: "No workout"))
        XCTAssertEqual(notifications.cancelCount, 0)

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        XCTAssertEqual(store.finishReadiness, .empty)
        XCTAssertNil(store.finish(effort: 3, notes: "No completed set"))

        var log = try XCTUnwrap(store.workout.flatMap { workout in
            repository.workoutSetLogs.first { $0.workoutID == workout.id }
        })
        log.weight = 225
        log.reps = 5
        repository.updateWorkoutSetLog(log)
        _ = repository.applyWorkoutSetCompletion(logID: log.id, isComplete: true, source: .manual)

        XCTAssertEqual(
            store.finishReadiness,
            .incomplete(completedSets: 1, plannedSets: bench.defaultSets)
        )

        let completed = try XCTUnwrap(store.finish(effort: 7, notes: "  Strong session  "))
        XCTAssertEqual(completed.completedAt, max(completedAt, completed.startedAt))
        XCTAssertEqual(completed.effort, 5)
        XCTAssertEqual(completed.notes, "Strong session")
        XCTAssertNil(store.workout)
        XCTAssertEqual(store.finishReadiness, .unavailable)
        XCTAssertEqual(notifications.cancelCount, 1)
    }

    @MainActor
    func testActiveWorkoutCompletionPersistsDraftValuesBeforeMarkingSetComplete() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        let store = ActiveWorkoutStore(repository: repository)
        var draft = try XCTUnwrap(store.setLogs(for: try XCTUnwrap(store.workout?.exercises.first)).first)
        draft.weight = 225
        draft.reps = 5

        XCTAssertTrue(store.applySetCompletion(draft, isComplete: true, source: .manual))

        let saved = try XCTUnwrap(repository.workoutSetLogs.first { $0.id == draft.id })
        XCTAssertEqual(saved.weight, 225)
        XCTAssertEqual(saved.reps, 5)
        XCTAssertTrue(saved.isComplete)
    }

    @MainActor
    func testActiveWorkoutStoreOwnsSetEditingAndPRHandoff() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.completedWorkouts = []
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])

        let store = ActiveWorkoutStore(repository: repository)
        let exercise = try XCTUnwrap(store.workout?.exercises.first)
        var first = try XCTUnwrap(store.setLogs(for: exercise).first)
        first.weight = 225
        first.reps = 5
        store.updateSet(first)
        XCTAssertTrue(store.applySetCompletion(first, isComplete: true, source: .manual))

        let added = try XCTUnwrap(store.addSet(to: exercise))
        XCTAssertEqual(added.setNumber, bench.defaultSets + 1)
        XCTAssertTrue(store.setLogs(for: exercise).contains { $0.id == added.id })

        let candidates = store.prCandidates(existingLifts: [], liftsRevision: repository.liftsRevision)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.setID, first.id)
        XCTAssertEqual(candidates.first?.rankingExerciseID, "bench")

        store.deleteSet(added)
        XCTAssertFalse(store.setLogs(for: exercise).contains { $0.id == added.id })
    }

    @MainActor
    func testPlannedWorkoutUsesImmutableExerciseSnapshot() {
        let repository = makePlannedRepository()
        let appState = AppState(repository: repository)
        guard let session = appState.workoutSessions.first,
              var prescription = appState.prescriptions(for: session).first else {
            return XCTFail("Expected seeded workout prescription")
        }

        XCTAssertTrue(appState.startWorkout(session))
        let originalName = appState.activeWorkout?.exercises.first?.exerciseName
        prescription.exerciseName = "Changed Plan Exercise"
        prescription.sets = 12
        repository.updateWorkoutPrescription(prescription)

        XCTAssertEqual(appState.activeWorkout?.exercises.first?.exerciseName, originalName)
        XCTAssertNotEqual(appState.activeWorkout?.exercises.first?.targetSets, 12)
    }

    @MainActor
    func testActiveWorkoutRejectsDuplicateExercisesAndClearsRemovedExerciseTimer() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench, bench])
        let exercise = try XCTUnwrap(appState.activeWorkout?.exercises.first)
        XCTAssertEqual(appState.activeWorkout?.exercises.count, 1)
        XCTAssertEqual(repository.workoutSetLogs.filter { $0.workoutID == appState.activeWorkout?.id }.count, bench.defaultSets)

        appState.updateActiveRestTimer(endsAt: .now.addingTimeInterval(120), exerciseID: exercise.id)
        appState.removeExerciseFromActiveWorkout(exercise)
        XCTAssertTrue(appState.activeWorkout?.exercises.isEmpty == true)
        XCTAssertNil(appState.activeWorkout?.restTimerEndsAt)
        XCTAssertNil(appState.activeWorkout?.restTimerExerciseID)
    }

    @MainActor
    func testFinishingAfterClockRollbackClampsCompletionToWorkoutStart() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        let bench = try XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])

        let start = Date(timeIntervalSince1970: 1_900_000_000)
        repository.activeWorkout?.startedAt = start
        var log = try XCTUnwrap(repository.workoutSetLogs.first(where: { $0.workoutID == appState.activeWorkout?.id }))
        log.weight = 225
        log.reps = 5
        log.isComplete = true
        repository.updateWorkoutSetLog(log)

        let completed = try XCTUnwrap(repository.finishActiveWorkout(effort: 3, notes: "", at: start.addingTimeInterval(-300)))
        XCTAssertEqual(completed.completedAt, start)
        XCTAssertEqual(completed.duration, 0)
    }

    @MainActor
    func testDeletingWorkoutHistoryRemovesUnfinishedPRQueueItems() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let workout = makeCompletedWorkout(completedAt: .now)
        repository.completedWorkouts = [workout]
        let setID = workout.sets[0].id
        let candidate = WorkoutPRCandidate(
            completedWorkoutID: workout.id,
            setID: setID,
            exerciseSnapshotID: workout.exercises[0].id,
            rankingExerciseID: "bench",
            exerciseName: "Barbell Bench Press",
            weight: 225,
            repetitions: 5,
            unit: .pounds,
            previousBestKilograms: nil
        )
        repository.pendingWorkoutPRSubmissions = [
            PendingWorkoutPRSubmission(
                id: UUID(), candidate: candidate, localVideoURL: URL(fileURLWithPath: "/tmp/pending.mov"),
                state: .failed, attemptCount: 1, lastError: "Offline", submissionID: nil, updatedAt: .now
            ),
            PendingWorkoutPRSubmission(
                id: UUID(), candidate: candidate, localVideoURL: URL(fileURLWithPath: "/tmp/submitted.mov"),
                state: .submitted, attemptCount: 1, lastError: nil, submissionID: UUID(), updatedAt: .now
            )
        ]

        repository.deleteCompletedWorkout(workout)

        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertEqual(repository.pendingWorkoutPRSubmissions.map(\.state), [.submitted])

        let store = WorkoutPRSubmissionStore(
            repository: repository,
            liftSubmitter: GatedWorkoutPRLiftSubmitter(),
            exercise: { id in MockData.exercises.first { $0.id == id } }
        )
        repository.workoutPreferences.automaticallySubmitVideoBackedPRs = true
        repository.currentProfile.id = UUID()
        XCTAssertTrue(store.pendingSubmissions.isEmpty)
        XCTAssertFalse(store.preferences.automaticallySubmitVideoBackedPRs)
    }

    @MainActor
    func testActiveWorkoutStoreClearsDraftForANewAccount() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let store = ActiveWorkoutStore(repository: repository)
        let workout = repository.startFreestyleWorkout(
            name: "Private workout",
            gymID: nil,
            bodyweight: nil,
            unit: .pounds,
            at: .now
        )
        let workoutID = try! XCTUnwrap(workout?.id)
        _ = repository.addWorkoutSetLog(
            prescriptionID: UUID(),
            workoutID: workoutID,
            unit: .pounds
        )
        XCTAssertNotNil(store.workout)

        repository.currentProfile.id = UUID()

        XCTAssertNil(store.workout)
        XCTAssertFalse(repository.workoutSetLogs.contains { $0.workoutID == workoutID })
    }

    @MainActor
    func testUpdatingCompletedWorkoutReplacesAndPersistsHistoryEntry() throws {
        let store = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: store)
        let original = makeCompletedWorkout(completedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let later = makeCompletedWorkout(completedAt: Date(timeIntervalSince1970: 1_800_086_400))
        repository.completedWorkouts = [original, later]
        repository.deletedCompletedWorkoutIDs.insert(original.id)

        var edited = original
        edited.completedAt = Date(timeIntervalSince1970: 1_800_172_800)
        edited.notes = "Adjusted after workout"
        edited.effort = 5
        edited.sets[0].weight = 235
        edited.sets[0].reps = 4

        repository.updateCompletedWorkout(edited)

        XCTAssertEqual(repository.completedWorkouts.map(\.id), [edited.id, later.id])
        let saved = try XCTUnwrap(repository.completedWorkouts.first)
        XCTAssertEqual(saved.notes, "Adjusted after workout")
        XCTAssertEqual(saved.effort, 5)
        XCTAssertEqual(saved.sets[0].weight, 235)
        XCTAssertEqual(saved.sets[0].reps, 4)
        XCTAssertFalse(repository.deletedCompletedWorkoutIDs.contains(original.id))

        let persisted = try XCTUnwrap(store.loadSnapshot()?.completedWorkouts.first(where: { $0.id == edited.id }))
        XCTAssertEqual(persisted.notes, "Adjusted after workout")
        XCTAssertEqual(persisted.sets[0].weight, 235)
    }

    @MainActor
    func testWorkoutSyncRemovesSuccessfulDeletionRetriesAndRetainsFailures() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = WorkoutSyncServiceStub()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let workoutID = UUID()
        repository.deletedCompletedWorkoutIDs = [workoutID]

        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(service.deletedIDs, [workoutID])
        XCTAssertTrue(repository.deletedCompletedWorkoutIDs.isEmpty)

        service.shouldFailDeletion = true
        repository.deletedCompletedWorkoutIDs = [workoutID]
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(service.deletedIDs, [workoutID, workoutID])
        XCTAssertEqual(repository.deletedCompletedWorkoutIDs, [workoutID])
    }

    @MainActor
    func testWorkoutSyncRemovesEntirePreviousAccountPlanGraph() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let plan = WorkoutPlan(id: UUID(), name: "Previous Account Plan", createdAt: .now)
        repository.addWorkoutPlan(plan)
        let planWeekIDs = Set(repository.workoutWeeks.filter { $0.planID == plan.id }.map(\.id))
        let planSessionIDs = Set(repository.workoutSessions.filter { planWeekIDs.contains($0.weekID) }.map(\.id))
        XCTAssertFalse(planWeekIDs.isEmpty)
        XCTAssertFalse(planSessionIDs.isEmpty)
        let store = WorkoutSyncStore(repository: repository, service: WorkoutSyncServiceStub())

        repository.currentProfile.id = UUID()
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertFalse(repository.workoutPlans.contains { $0.id == plan.id })
        XCTAssertFalse(repository.workoutWeeks.contains { $0.planID == plan.id })
        XCTAssertFalse(repository.workoutSessions.contains { planWeekIDs.contains($0.weekID) })
        XCTAssertFalse(repository.workoutPrescriptions.contains { planSessionIDs.contains($0.sessionID) })
    }

    @MainActor
    func testWorkoutSyncRebuildsAchievementUnlocksAfterAccountHistoryRestore() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = WorkoutSyncServiceStub()
        let store = WorkoutSyncStore(repository: repository, service: service)
        let restoredUserID = UUID()
        let workout = makeCompletedWorkout(completedAt: Date(timeIntervalSince1970: 1_800_000_000))
        service.completedWorkoutSnapshots = [CompletedWorkoutSnapshot(
            id: workout.id,
            ownerID: restoredUserID,
            payload: try JSONEncoder().encode(workout),
            completedAt: workout.completedAt
        )]

        repository.currentProfile.id = restoredUserID
        repository.achievementUnlocks = []
        await store.synchronizeCompletedWorkoutHistory()

        XCTAssertEqual(repository.completedWorkouts.map(\.id), [workout.id])
        XCTAssertTrue(repository.achievementUnlocks.contains { $0.title == "First Workout" })
    }

    func testCommunityContentPolicyAllowsOrdinaryTrainingText() {
        XCTAssertTrue(CommunityContentPolicy.allows("Strong Session", "Hit a clean personal best today."))
    }

    func testCommunityContentPolicyRejectsObfuscatedProhibitedText() {
        XCTAssertFalse(CommunityContentPolicy.allows("That was sh1t"))
    }

    @MainActor
    func testNotificationReadStateSynchronizesWithRemoteService() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = RecordingNotificationService()
        let store = NotificationStore(
            repository: repository,
            notificationService: service,
            deviceID: "notification-test-device"
        )
        let firstID = UUID()
        let secondID = UUID()
        repository.notifications = [
            NotificationItem(id: firstID, title: "First", message: "", kind: "Test", createdAt: .now, isRead: false),
            NotificationItem(id: secondID, title: "Second", message: "", kind: "Test", createdAt: .now, isRead: false)
        ]

        store.markRead(firstID)
        for _ in 0..<3 { await Task.yield() }
        store.markAllRead()
        for _ in 0..<3 { await Task.yield() }

        XCTAssertEqual(service.markedIDs, [firstID, firstID, secondID])
        XCTAssertTrue(repository.notifications.allSatisfy(\.isRead))
    }

    @MainActor
    func testNotificationRefreshPreservesCachedItemsWhenRemoteFetchFails() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let service = RecordingNotificationService()
        let store = NotificationStore(repository: repository, notificationService: service)
        let notification = NotificationItem(
            id: UUID(), title: "Cached", message: "", kind: "Test", createdAt: .now, isRead: false
        )
        repository.notifications = [notification]
        service.shouldFailRefresh = true

        await store.refreshProductionData()

        XCTAssertEqual(repository.notifications, [notification])

        repository.currentProfile.id = UUID()
        await store.refreshProductionData()

        XCTAssertTrue(repository.notifications.isEmpty)
    }

    @MainActor
    func testWarmupOnlyWorkoutCannotFinishOrChangeStreak() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.completedWorkouts = []
        let appState = AppState(repository: repository)
        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        let bench = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        appState.addExercisesToActiveWorkout([bench])
        var log = try! XCTUnwrap(repository.workoutSetLogs.first(where: { $0.workoutID == appState.activeWorkout?.id }))
        log.weight = 135
        log.reps = 10
        log.isWarmup = true
        log.isComplete = true
        appState.updateSetLog(log)

        XCTAssertNil(appState.finishActiveWorkout(effort: 2, notes: "Warmup only"))
        XCTAssertNotNil(appState.activeWorkout)
        XCTAssertEqual(appState.workoutStreak(), 0)
    }

    @MainActor
    func testFinishedWorkoutCreatesHistoryAndStreakCountsDayOnce() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.completedWorkouts = []
        let appState = AppState(repository: repository)
        let bench = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))

        for weight in [225.0, 235.0] {
            XCTAssertTrue(appState.startFreestyleWorkoutInstance())
            appState.addExercisesToActiveWorkout([bench])
            var log = try! XCTUnwrap(repository.workoutSetLogs.first(where: { $0.workoutID == appState.activeWorkout?.id }))
            log.weight = weight
            log.reps = 5
            log.isComplete = true
            appState.updateSetLog(log)
            XCTAssertNotNil(appState.finishActiveWorkout(effort: 3, notes: ""))
        }

        XCTAssertEqual(appState.completedWorkouts.count, 2)
        XCTAssertNotEqual(appState.completedWorkouts[0].id, appState.completedWorkouts[1].id)
        XCTAssertEqual(appState.workoutStreak(), 1)
    }

    @MainActor
    func testPRDetectionUsesExactRepsUnitsAndCanonicalMappings() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.completedWorkouts = []
        let appState = AppState(repository: repository)
        let bench = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        let sumo = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "sumo_deadlift" }))
        let machine = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "machine_chest_press" }))

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench, sumo, machine])
        guard let active = appState.activeWorkout else { return XCTFail("Expected active workout") }
        for exercise in active.exercises {
            guard var log = repository.workoutSetLogs.first(where: {
                $0.workoutID == active.id && $0.prescriptionID == exercise.id
            }) else { continue }
            log.weight = exercise.exerciseID == "machine_chest_press" ? 5_000 : 500
            log.reps = exercise.exerciseID == "sumo_deadlift" ? 3 : 5
            log.recordedUnit = .kilograms
            log.isComplete = true
            appState.updateSetLog(log)
        }

        let candidates = appState.activeWorkoutPRCandidates()
        XCTAssertTrue(candidates.contains { $0.rankingExerciseID == "bench" && $0.repetitions == 5 })
        XCTAssertTrue(candidates.contains { $0.rankingExerciseID == "deadlift" && $0.repetitions == 3 })
        XCTAssertFalse(candidates.contains { $0.exerciseName == machine.name })
        XCTAssertEqual(candidates.first(where: { $0.rankingExerciseID == "bench" })?.normalizedKilograms ?? 0, 500, accuracy: 0.001)
    }

    func testWorkoutPRDetectorChoosesBestSetAndExcludesCurrentWorkoutFromHistory() throws {
        var historical = makeCompletedWorkout(completedAt: .now.addingTimeInterval(-86_400))
        historical.sets[0].weight = 240

        var current = makeCompletedWorkout(completedAt: .now)
        current.sets[0].weight = 235
        var best = current.sets[0]
        best.id = UUID()
        best.setNumber = 2
        best.weight = 245
        current.sets.append(best)

        let candidates = WorkoutPRDetector.candidates(
            workoutID: current.id,
            exercises: current.exercises,
            sets: current.sets,
            existingLifts: [],
            completedWorkouts: [historical, current],
            excludingCompletedWorkoutID: current.id
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidate.setID, best.id)
        XCTAssertEqual(candidate.weight, 245)
        XCTAssertEqual(
            candidate.previousBestKilograms ?? 0,
            RankingCalculator.poundsToKilograms(240),
            accuracy: 0.001
        )

        let blockingLift = makeLift(
            userID: UUID(),
            weight: 250,
            exerciseID: "bench",
            repetitions: 5
        )
        XCTAssertTrue(
            WorkoutPRDetector.candidates(
                workoutID: current.id,
                exercises: current.exercises,
                sets: current.sets,
                existingLifts: [blockingLift],
                completedWorkouts: [historical, current],
                excludingCompletedWorkoutID: current.id
            ).isEmpty
        )
    }

    @MainActor
    func testWorkoutPRSubmissionStoreOwnsMediaQueueSubmissionAndWorkoutLinking() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let gymID = repository.currentProfile.primaryGymID
        repository.gyms = [Gym(id: gymID, name: "Downtown Strength", city: "Austin", state: "Texas", memberCount: 0, verifiedLiftCount: 0)]
        repository.joinedGymIDs = [gymID]
        let competitionStore = CompetitionStore(
            repository: repository,
            liftService: MockLiftService(repository: repository),
            mediaUploadService: MockMediaUploadService(),
            analyticsService: MockAnalyticsService()
        )
        let videoURL = URL(fileURLWithPath: "/tmp/workout-pr-test.mov")
        let videoStore = TestWorkoutVideoStore(url: videoURL)
        let flakySubmitter = FlakyWorkoutPRLiftSubmitter(
            delegate: competitionStore,
            remainingFailures: 1
        )
        let pendingID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let store = WorkoutPRSubmissionStore(
            repository: repository,
            liftSubmitter: flakySubmitter,
            videoStore: videoStore,
            exercise: { id in MockData.exercises.first { $0.id == id } },
            now: { timestamp },
            makeID: { pendingID }
        )
        let workout = makeExerciseHistoryWorkout(
            completedAt: timestamp,
            unit: .pounds,
            sets: [(weight: 315, reps: 1, warmup: false, complete: true)]
        )
        repository.completedWorkouts = [workout]
        store.setAutomaticSubmissionEnabled(true)

        let data = Data([0x01, 0x02, 0x03])
        XCTAssertEqual(try store.persistVideo(data, fileExtension: "mp4"), videoURL)
        XCTAssertEqual(videoStore.savedData, data)
        XCTAssertEqual(videoStore.savedExtension, "mp4")

        let candidate = try XCTUnwrap(store.candidates(for: workout, existingLifts: []).first)
        let initialLiftCount = repository.lifts.count
        await store.submitVideoBackedPRs(
            for: workout,
            videoURLsBySetID: [candidate.setID: videoURL],
            existingLifts: []
        )

        var pending = try XCTUnwrap(store.pendingSubmissions.first)
        XCTAssertEqual(pending.id, pendingID)
        XCTAssertEqual(pending.state, .failed)
        XCTAssertEqual(pending.attemptCount, 1)
        XCTAssertEqual(repository.lifts.count, initialLiftCount)

        await store.retryFailedSubmissions()
        pending = try XCTUnwrap(store.pendingSubmissions.first)
        XCTAssertEqual(pending.state, .submitted)
        XCTAssertEqual(pending.attemptCount, 2)
        XCTAssertEqual(flakySubmitter.attemptCount, 2)
        XCTAssertEqual(repository.lifts.count, initialLiftCount + 1)
        XCTAssertEqual(videoStore.removedURLs, [videoURL])
        XCTAssertEqual(repository.completedWorkouts.first?.linkedSubmissionIDs, [pending.submissionID].compactMap { $0 })

        await store.submitVideoBackedPRs(
            for: workout,
            videoURLsBySetID: [candidate.setID: videoURL],
            existingLifts: []
        )
        XCTAssertEqual(store.pendingSubmissions.first?.attemptCount, 2)
        XCTAssertEqual(repository.lifts.count, initialLiftCount + 1)
    }

    @MainActor
    func testWorkoutPRSubmissionStorePrunesExpiredRetryMedia() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let videoURL = URL(fileURLWithPath: "/tmp/expired-workout-pr.mov")
        let videoStore = TestWorkoutVideoStore(url: videoURL)
        let workout = makeExerciseHistoryWorkout(
            completedAt: now,
            unit: .pounds,
            sets: [(weight: 315, reps: 1, warmup: false, complete: true)]
        )
        let set = try XCTUnwrap(workout.sets.first)
        let exercise = try XCTUnwrap(workout.exercises.first)
        repository.pendingWorkoutPRSubmissions = [PendingWorkoutPRSubmission(
            id: UUID(),
            candidate: WorkoutPRCandidate(
                completedWorkoutID: workout.id,
                setID: set.id,
                exerciseSnapshotID: exercise.id,
                rankingExerciseID: "bench",
                exerciseName: exercise.exerciseName,
                weight: set.weight ?? 0,
                repetitions: set.reps ?? 1,
                unit: workout.unit,
                previousBestKilograms: nil
            ),
            localVideoURL: videoURL,
            state: .failed,
            attemptCount: 1,
            lastError: "Offline",
            submissionID: nil,
            updatedAt: now.addingTimeInterval(-31 * 24 * 60 * 60)
        )]

        _ = WorkoutPRSubmissionStore(
            repository: repository,
            liftSubmitter: GatedWorkoutPRLiftSubmitter(),
            videoStore: videoStore,
            exercise: { id in MockData.exercises.first { $0.id == id } },
            now: { now }
        )

        XCTAssertTrue(repository.pendingWorkoutPRSubmissions.isEmpty)
        XCTAssertEqual(videoStore.removedURLs, [videoURL])
    }

    @MainActor
    func testWorkoutPRSubmissionStoreDoesNotDuplicateAnInFlightSubmission() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let submitter = GatedWorkoutPRLiftSubmitter()
        let store = WorkoutPRSubmissionStore(
            repository: repository,
            liftSubmitter: submitter,
            exercise: { id in MockData.exercises.first { $0.id == id } }
        )
        let workout = makeExerciseHistoryWorkout(
            completedAt: .now,
            unit: .pounds,
            sets: [(weight: 315, reps: 1, warmup: false, complete: true)]
        )
        repository.completedWorkouts = [workout]
        store.setAutomaticSubmissionEnabled(true)
        let candidate = try XCTUnwrap(store.candidates(for: workout, existingLifts: []).first)
        let videoURL = URL(fileURLWithPath: "/tmp/workout-pr-in-flight.mov")

        let firstSubmission = Task {
            await store.submitVideoBackedPRs(
                for: workout,
                videoURLsBySetID: [candidate.setID: videoURL],
                existingLifts: []
            )
        }
        for _ in 0..<20 where submitter.attemptCount == 0 {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        await store.submitVideoBackedPRs(
            for: workout,
            videoURLsBySetID: [candidate.setID: videoURL],
            existingLifts: []
        )
        XCTAssertEqual(submitter.attemptCount, 1)
        repository.currentProfile.id = UUID()
        submitter.releaseSubmission()
        await firstSubmission.value
        XCTAssertTrue(repository.pendingWorkoutPRSubmissions.isEmpty)
    }

    @MainActor
    func testPauseDurationAndMidnightDoNotDependOnCalendarDay() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let appState = AppState(repository: repository)
        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        guard var active = repository.activeWorkout else { return XCTFail("Expected active workout") }
        let end = Date(timeIntervalSince1970: 1_800_100_000)
        active.startedAt = end.addingTimeInterval(-7_200)
        active.accumulatedPausedTime = 1_800
        repository.activeWorkout = active

        XCTAssertEqual(repository.activeWorkout?.elapsedDuration(at: end) ?? 0, 5_400, accuracy: 0.001)
    }

    @MainActor
    func testResetClearsActiveAndHistoryAndRestoresCatalogData() {
        let store = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: store)
        let appState = AppState(repository: repository)
        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        repository.completedWorkouts.append(
            CompletedWorkout(
                id: UUID(), source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
                name: "Temporary", dayLabel: "Monday", startedAt: .now, completedAt: .now,
                duration: 60, effort: 3, notes: "", gymID: nil, bodyweight: nil,
                unit: .pounds, exercises: [], sets: [], linkedSubmissionIDs: []
            )
        )

        repository.reset()

        XCTAssertNil(repository.activeWorkout)
        XCTAssertTrue(repository.completedWorkouts.isEmpty)
        XCTAssertTrue(repository.workoutPlans.isEmpty)
        XCTAssertFalse(MockData.trainingExerciseLibrary.isEmpty)
        XCTAssertNotNil(store.loadSnapshot())
    }

    @MainActor

    func testBundledProgramsAreCompleteAndReferenceCatalogExercises() {
        let templates = WorkoutProgramCatalog.templates
        let catalogIDs = Set(MockData.trainingExerciseLibrary.map(\.id))

        XCTAssertEqual(templates.count, 7)
        for template in templates {
            XCTAssertEqual(template.sessions.count, template.daysPerWeek, template.name)
            XCTAssertFalse(template.sessions.flatMap(\.exercises).isEmpty, template.name)
            XCTAssertTrue(
                template.sessions.flatMap(\.exercises).allSatisfy { catalogIDs.contains($0.exerciseID) },
                "\(template.name) references an exercise missing from the bundled catalog."
            )
        }
    }

    func testBundledExercisesHaveDetailedMuscleProfiles() {
        for exercise in MockData.trainingExerciseLibrary {
            let profile = exercise.muscleProfile
            XCTAssertNotNil(profile, exercise.name)
            XCTAssertFalse(profile?.primary.isEmpty ?? true, exercise.name)
            XCTAssertTrue(
                Set(profile?.primary ?? []).isDisjoint(with: Set(profile?.secondary ?? [])),
                "\(exercise.name) marks a muscle as both primary and secondary."
            )
        }
    }

    func testLegPressMuscleProfileDoesNotIncludeUpperBodyPressMuscles() throws {
        let legPress = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "leg_press" })
        let profile = legPress.resolvedMuscleProfile

        XCTAssertTrue(profile.primary.contains(.quads))
        XCTAssertTrue(profile.secondary.contains(.glutes))
        XCTAssertFalse(profile.secondary.contains(.triceps))
        XCTAssertFalse(profile.secondary.contains(.frontDelts))
    }

    func testDipMuscleProfileSeparatesPrimaryAndSecondaryMuscles() throws {
        let dip = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "machine_assisted_dip" })
        let profile = dip.resolvedMuscleProfile

        XCTAssertEqual(profile.primary, [.chest, .triceps])
        XCTAssertEqual(profile.secondary, [.frontDelts])
        XCTAssertEqual(profile.orientation, .split)
    }

    func testBackPullMuscleProfileKeepsArmsSecondary() throws {
        let pulldown = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "lat_pulldown" })
        let profile = pulldown.resolvedMuscleProfile

        XCTAssertEqual(profile.primary, [.lats])
        XCTAssertTrue(profile.secondary.contains(.upperBack))
        XCTAssertTrue(profile.secondary.contains(.biceps))
        XCTAssertFalse(profile.primary.contains(.biceps))
    }

    func testPressMuscleProfileKeepsChestPrimaryAndTricepsSecondary() throws {
        let bench = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })
        let profile = bench.resolvedMuscleProfile

        XCTAssertEqual(profile.primary, [.chest])
        XCTAssertTrue(profile.secondary.contains(.frontDelts))
        XCTAssertTrue(profile.secondary.contains(.triceps))
    }

    func testExerciseLibraryFiltersUseORWithinAndANDBetweenCategories() throws {
        let cableFly = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "cable_fly" })
        let inclinePress = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "incline_db_press" })
        let latPulldown = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "lat_pulldown" })
        let filters = ExerciseLibraryFilterSelection(
            primaryMuscles: [.chest, .upperChest],
            equipment: ["Cable", "Dumbbell"]
        )

        XCTAssertTrue(filters.matches(cableFly))
        XCTAssertTrue(filters.matches(inclinePress))
        XCTAssertFalse(filters.matches(latPulldown))
        XCTAssertEqual(filters.activeCategoryCount, 2)
    }

    @MainActor
    func testExerciseLibraryStoreOwnsSearchSubstitutionsAndCustomExerciseCreation() throws {
        let repository = DemoRepository()
        let fixedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let store = ExerciseLibraryStore(repository: repository, makeID: { fixedID })
        let bench = try XCTUnwrap(store.exercises.first { $0.id == "barbell_bench_press" })

        let filteredResults = store.search(
            query: "press",
            filters: ExerciseLibraryFilterSelection(
                primaryMuscles: [.chest, .upperChest],
                equipment: ["Dumbbell"]
            ),
            excludingIDs: [bench.id]
        )

        XCTAssertFalse(filteredResults.isEmpty)
        XCTAssertTrue(filteredResults.allSatisfy { $0.exercise.equipment == "Dumbbell" })
        XCTAssertFalse(filteredResults.contains { $0.exercise.id == bench.id })

        let substitutions = store.substitutionRecommendations(for: bench, limit: 5)
        XCTAssertFalse(substitutions.isEmpty)
        XCTAssertLessThanOrEqual(substitutions.count, 5)
        XCTAssertFalse(substitutions.contains { $0.exercise.id == bench.id })
        XCTAssertTrue(substitutions.allSatisfy { !$0.reasons.isEmpty })
        XCTAssertEqual(substitutions.map(\.score), substitutions.map(\.score).sorted(by: >))

        let custom = try XCTUnwrap(store.createCustomExercise(
            name: "  Split Cable Press  ",
            bodyPart: "Chest",
            equipment: "Cable",
            trackingType: "Weight + Reps",
            primaryMuscles: [.chest, .lats],
            secondaryMuscles: [.triceps, .chest]
        ))

        XCTAssertEqual(custom.id, "custom_\(fixedID.uuidString)")
        XCTAssertEqual(custom.name, "Split Cable Press")
        XCTAssertEqual(custom.resolvedMuscleProfile.primary, [.chest, .lats])
        XCTAssertEqual(custom.resolvedMuscleProfile.secondary, [.triceps])
        XCTAssertEqual(custom.resolvedMuscleProfile.orientation, .split)
        XCTAssertEqual(store.customExercises.first, custom)
        XCTAssertEqual(store.search(query: "Split Cable Press").first?.exercise.id, custom.id)
        let repsOnly = try XCTUnwrap(store.createCustomExercise(
            name: "Timed Bodyweight Hold",
            bodyPart: "Core",
            equipment: "Bodyweight",
            trackingType: "Reps Only"
        ))
        XCTAssertEqual(repsOnly.trackingType, "Reps Only")
        XCTAssertNil(store.createCustomExercise(
            name: "   ",
            bodyPart: "Chest",
            equipment: "Cable",
            trackingType: "Weight + Reps"
        ))

        repository.currentProfile.id = UUID()
        XCTAssertTrue(store.customExercises.isEmpty)
        XCTAssertTrue(store.exercises.contains { $0.id == "barbell_bench_press" })
    }

    @MainActor
    func testStartingBundledProgramCreatesEditableTwelveWeekPlan() throws {
        let repository = DemoRepository()
        let template = try XCTUnwrap(WorkoutProgramCatalog.templates.first)
        let plan = repository.startWorkoutProgram(
            template: template,
            startDate: .now,
            scheduledWeekdays: template.sessions.map(\.dayIndex),
            method: template.defaultProgression,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        )
        let weeks = repository.workoutWeeks.filter { $0.planID == plan.id }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = repository.workoutSessions.filter { weekIDs.contains($0.weekID) }

        XCTAssertEqual(weeks.count, 12)
        XCTAssertEqual(sessions.count, 12 * template.daysPerWeek)
        XCTAssertEqual(repository.currentProgramWeek(planID: plan.id)?.weekNumber, 1)
        XCTAssertEqual(repository.workoutPlanProgressionSettings.first { $0.planID == plan.id }?.sourceTemplateID, template.id)
        XCTAssertEqual(Set(repository.workoutPrescriptions.filter { sessions.map(\.id).contains($0.sessionID) }.map(\.id)).count,
                       repository.workoutPrescriptions.filter { sessions.map(\.id).contains($0.sessionID) }.count)
    }

    @MainActor
    func testProgressionChangePreservesActiveWeekAndUpdatesFutureWeeks() throws {
        let repository = DemoRepository()
        let template = try XCTUnwrap(WorkoutProgramCatalog.templates.first { $0.id == "beginner_powerlifting_12" })
        let plan = repository.startWorkoutProgram(
            template: template,
            startDate: .now,
            scheduledWeekdays: template.sessions.map(\.dayIndex),
            method: .fixed,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        )
        let weekOne = try XCTUnwrap(repository.workoutWeeks.first { $0.planID == plan.id && $0.weekNumber == 1 })
        let weekTwo = try XCTUnwrap(repository.workoutWeeks.first { $0.planID == plan.id && $0.weekNumber == 2 })
        let weekOneSession = try XCTUnwrap(repository.workoutSessions.first { $0.weekID == weekOne.id })
        let weekTwoSession = try XCTUnwrap(repository.workoutSessions.first { $0.weekID == weekTwo.id })
        let weekOnePrescriptionID = try XCTUnwrap(repository.workoutPrescriptions.first { $0.sessionID == weekOneSession.id }?.id)
        let weekTwoPrescriptionID = try XCTUnwrap(repository.workoutPrescriptions.first { $0.sessionID == weekTwoSession.id }?.id)
        let weekTwoExerciseName = try XCTUnwrap(repository.workoutPrescriptions.first { $0.id == weekTwoPrescriptionID }?.exerciseName)
        let originalMirroredEntry = try XCTUnwrap(repository.workoutEntries.first {
            $0.planID == plan.id && $0.week == 2 && $0.workout == weekTwoSession.name && $0.exercise == weekTwoExerciseName
        })
        let templateExerciseIDs = Set(template.sessions.flatMap(\.exercises).map(\.exerciseID))
        let trainingMax = Dictionary(uniqueKeysWithValues: templateExerciseIDs.map { ($0, 100.0) })

        XCTAssertNotNil(repository.startWorkout(session: weekOneSession, planID: plan.id, gymID: nil, bodyweight: nil, unit: .pounds))
        XCTAssertTrue(repository.changeWorkoutProgramProgression(planID: plan.id, method: .percentage, trainingMaxKilograms: trainingMax))

        XCTAssertNil(repository.workoutPrescriptions.first { $0.id == weekOnePrescriptionID }?.targetRIR)
        XCTAssertNotNil(repository.workoutPrescriptions.first { $0.id == weekTwoPrescriptionID }?.trainingMaxPercentage)

        let updatedPrescription = try XCTUnwrap(repository.workoutPrescriptions.first { $0.id == weekTwoPrescriptionID })
        let mirroredEntry = try XCTUnwrap(repository.workoutEntries.first {
            $0.planID == plan.id && $0.week == 2 && $0.workout == weekTwoSession.name && $0.exercise == weekTwoExerciseName
        })
        XCTAssertEqual(mirroredEntry.targetSets, updatedPrescription.sets)
        XCTAssertEqual(mirroredEntry.targetReps, updatedPrescription.reps)
        XCTAssertNotEqual(mirroredEntry.targetReps, originalMirroredEntry.targetReps)
    }

    @MainActor
    func testVersionTwoWorkoutSnapshotDecodesWithProgressionDefaults() throws {
        let store = InMemoryWorkoutPersistenceStore()
        let repository = DemoRepository(workoutPersistenceStore: store)
        let template = try XCTUnwrap(WorkoutProgramCatalog.templates.first)
        _ = repository.startWorkoutProgram(
            template: template,
            startDate: .now,
            scheduledWeekdays: template.sessions.map(\.dayIndex),
            method: template.defaultProgression,
            preferredUnit: .pounds,
            trainingMaxKilograms: [:]
        )
        let snapshot = try XCTUnwrap(store.snapshot)
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 2
        object.removeValue(forKey: "planProgressionSettings")
        object.removeValue(forKey: "strainEntries")
        object.removeValue(forKey: "injuryEntries")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(WorkoutPersistenceSnapshot.self, from: legacyData)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertNil(decoded.planProgressionSettings)
        XCTAssertNil(decoded.strainEntries)
        XCTAssertNil(decoded.injuryEntries)
    }

    @MainActor
    func testVersionNineMigrationRemovesUntouchedPrivateSeedAndIsIdempotent() throws {
        let bootstrapStore = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: bootstrapStore)
        var snapshot = try XCTUnwrap(bootstrapStore.snapshot)
        let seed = PersonalWorkoutPlanCatalog.makeSeed(createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        snapshot.schemaVersion = 9
        snapshot.plans = [seed.plan]
        snapshot.phases = seed.phases
        snapshot.weeks = seed.weeks
        snapshot.sessions = seed.sessions
        snapshot.prescriptions = seed.prescriptions

        let migrationStore = InMemoryWorkoutPersistenceStore(snapshot: snapshot)
        let migrated = DemoRepository(workoutPersistenceStore: migrationStore)

        XCTAssertFalse(migrated.workoutPlans.contains { $0.id == PersonalWorkoutPlanCatalog.planID })
        XCTAssertEqual(migrationStore.snapshot?.schemaVersion, WorkoutPersistenceSnapshot.currentVersion)

        let relaunched = DemoRepository(workoutPersistenceStore: migrationStore)
        XCTAssertFalse(relaunched.workoutPlans.contains { $0.id == PersonalWorkoutPlanCatalog.planID })
        XCTAssertEqual(migrationStore.snapshot?.schemaVersion, WorkoutPersistenceSnapshot.currentVersion)
    }

    @MainActor
    func testVersionNineMigrationPreservesModifiedPrivateSeed() throws {
        let bootstrapStore = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: bootstrapStore)
        var snapshot = try XCTUnwrap(bootstrapStore.snapshot)
        var seed = PersonalWorkoutPlanCatalog.makeSeed(createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        seed.plan.notes += " User customization."
        snapshot.schemaVersion = 9
        snapshot.plans = [seed.plan]
        snapshot.phases = seed.phases
        snapshot.weeks = seed.weeks
        snapshot.sessions = seed.sessions
        snapshot.prescriptions = seed.prescriptions

        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore(snapshot: snapshot))

        XCTAssertEqual(repository.workoutPlans.first?.notes, seed.plan.notes)
        XCTAssertEqual(repository.workoutWeeks.count, seed.weeks.count)
        XCTAssertEqual(repository.workoutPrescriptions.count, seed.prescriptions.count)
    }

    @MainActor
    func testVersionNineMigrationDoesNotDeletePlansByNameOrUnrelatedLegacyEntries() throws {
        let bootstrapStore = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: bootstrapStore)
        var snapshot = try XCTUnwrap(bootstrapStore.snapshot)
        let planID = UUID()
        let plan = WorkoutPlan(
            id: planID,
            name: "Robert Hypertrophy Block",
            createdAt: .now,
            goal: "Personal training"
        )
        let entry = WorkoutExerciseEntry(
            id: UUID(), planID: planID, week: 1, date: .now, day: "Monday",
            workout: "Upper", exercise: "Cable Row", muscleGroup: "Back",
            targetSets: 3, targetReps: "8-12", sets: [], isDone: false, notes: ""
        )
        snapshot.schemaVersion = 9
        snapshot.plans = [plan]
        snapshot.legacyEntries = [entry]

        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore(snapshot: snapshot))

        XCTAssertEqual(repository.workoutPlans, [plan])
        XCTAssertEqual(repository.workoutEntries, [entry])
    }

    @MainActor
    func testVersionNineMigrationRemovesUntouchedDefaultWorkoutSeed() throws {
        let bootstrapStore = InMemoryWorkoutPersistenceStore()
        _ = DemoRepository(workoutPersistenceStore: bootstrapStore)
        var snapshot = try XCTUnwrap(bootstrapStore.snapshot)
        let planID = MockData.defaultWorkoutPlanID
        let phase = WorkoutPhase(
            id: UUID(), planID: planID, name: "Base Phase", order: 0,
            goal: "Build strength and muscle.", durationWeeks: 1
        )
        let week = WorkoutWeek(
            id: UUID(), planID: planID, phaseID: phase.id, weekNumber: 1,
            title: "Week 1", notes: ""
        )
        let session = WorkoutSession(
            id: UUID(), weekID: week.id, day: "Monday", name: "Strength Session",
            order: 0, notes: ""
        )
        let exercise = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })
        let prescription = WorkoutExercisePrescription(
            id: UUID(), sessionID: session.id, exerciseID: exercise.id,
            exerciseName: exercise.name, bodyPart: exercise.bodyPart, equipment: exercise.equipment,
            sets: 3, reps: "6-8", restSeconds: 120, order: 0, notes: "",
            muscleProfile: exercise.resolvedMuscleProfile
        )
        let log = WorkoutSetLog(
            id: UUID(), prescriptionID: prescription.id, performedAt: .now,
            setNumber: 1, weight: 135, reps: 8, rpe: 7,
            isWarmup: false, isComplete: true, recordedUnit: .pounds
        )
        snapshot.schemaVersion = 9
        snapshot.plans = [WorkoutPlan(
            id: planID, name: "Strength Foundations", createdAt: .now,
            goal: "Build strength and muscle."
        )]
        snapshot.phases = [phase]
        snapshot.weeks = [week]
        snapshot.sessions = [session]
        snapshot.prescriptions = [prescription]
        snapshot.setLogs = [log]

        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore(snapshot: snapshot))

        XCTAssertTrue(repository.workoutPlans.isEmpty)
        XCTAssertTrue(repository.workoutSetLogs.isEmpty)
    }

    func testExerciseSearchFindsGenericMachineChestPressThroughBrandAlias() throws {
        let results = ExerciseCatalogSearch.search(
            exercises: MockData.trainingExerciseLibrary,
            query: "Hammer Strength Chest Press"
        )

        XCTAssertEqual(results.first?.exercise.id, "machine_chest_press")
        XCTAssertEqual(results.first?.kind, .aliasExact)
        XCTAssertNotNil(results.first?.reasonLabel)
    }

    @MainActor
    func testStartingWorkoutCopiesGlobalRestPreferenceIntoWorkoutOverride() throws {
        let repository = makePlannedRepository()
        repository.workoutPreferences.defaultRestTimerEnabled = false
        let session = try XCTUnwrap(repository.workoutSessions.first)

        let workout = try XCTUnwrap(
            repository.startWorkout(session: session, planID: nil, gymID: nil, bodyweight: nil, unit: .pounds)
        )

        XCTAssertFalse(workout.automaticRestTimerEnabled)
    }

    @MainActor
    func testAutomaticCompletionCompletesPreviousSetOnceValuesExist() throws {
        let repository = makePlannedRepository()
        let prescription = try XCTUnwrap(repository.workoutPrescriptions.first { $0.sets >= 2 })
        let session = try XCTUnwrap(repository.workoutSessions.first { $0.id == prescription.sessionID })
        let workout = try XCTUnwrap(
            repository.startWorkout(session: session, planID: nil, gymID: nil, bodyweight: nil, unit: .pounds)
        )
        let exercise = try XCTUnwrap(workout.exercises.first { $0.sourcePrescriptionID == prescription.id })
        var first = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == workout.id && $0.prescriptionID == exercise.id && $0.setNumber == 1 })
        let second = try XCTUnwrap(repository.workoutSetLogs.first { $0.workoutID == workout.id && $0.prescriptionID == exercise.id && $0.setNumber == 2 })
        first.reps = 8
        first.weight = 135
        repository.updateWorkoutSetLog(first)

        let appState = AppState(repository: repository, serviceContainer: .demo(repository: repository))
        XCTAssertTrue(appState.attemptAutomaticCompletion(before: second))
        let updated = try XCTUnwrap(repository.workoutSetLogs.first { $0.id == first.id })
        XCTAssertTrue(updated.isComplete)
        XCTAssertEqual(updated.completionSource, .automatic)
    }

    func testTrainingExerciseLibraryDoesNotAssignGenericDemoMedia() {
        let genericDemoIDs: Set<String> = [
            "demo-horizontal-press",
            "demo-vertical-press",
            "demo-horizontal-pull",
            "demo-vertical-pull",
            "demo-squat",
            "demo-hinge",
            "demo-lunge",
            "demo-curl",
            "demo-extension",
            "demo-shoulder",
            "demo-calf",
            "demo-core",
            "demo-carry",
            "demo-general"
        ]
        let exercisesWithGenericMedia = MockData.trainingExerciseLibrary.filter {
            $0.demonstrationMediaID.map(genericDemoIDs.contains) ?? false
        }

        XCTAssertTrue(exercisesWithGenericMedia.isEmpty, "Generic demo media remains on: \(exercisesWithGenericMedia.map(\.id))")
    }

    func testExerciseGuidanceUsesCuratedEntriesAndPatternFallbacks() throws {
        let bench = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "barbell_bench_press" })
        let calfRaise = try XCTUnwrap(MockData.trainingExerciseLibrary.first { $0.id == "machine_standing_calf_raise" })

        XCTAssertEqual(bench.guidance?.steps.count, 3)
        XCTAssertFalse(try XCTUnwrap(bench.guidance?.summary).isEmpty)
        XCTAssertEqual(calfRaise.guidance?.steps.count, 3)
        XCTAssertFalse(try XCTUnwrap(calfRaise.guidance?.summary).isEmpty)
    }

    func testExerciseLibraryHasExplicitTrackingAndRankingEligibility() throws {
        let library = MockData.trainingExerciseLibrary
        let validTrackingTypes: Set<String> = ["Weight + Reps", "Bodyweight Reps", "Assisted Bodyweight", "Reps Only", "Time", "Weight + Time"]
        let validRankingIDs = Set(MockData.exercises.map(\.id))

        XCTAssertTrue(library.allSatisfy { validTrackingTypes.contains($0.trackingType) })
        XCTAssertTrue(library.compactMap(\.rankingExerciseID).allSatisfy(validRankingIDs.contains))
        XCTAssertEqual(try XCTUnwrap(library.first { $0.id == "barbell_bench_press" }).rankingEligibilityLabel, "Counts toward rankings")
        XCTAssertEqual(try XCTUnwrap(library.first { $0.id == "machine_chest_press" }).rankingEligibilityLabel, "Workout progress only")
    }

    @MainActor
    func testExerciseHistoryAndRecordsUseCompletedWorkingSetsInKilograms() throws {
        let repository = DemoRepository()
        repository.completedWorkouts = [
            makeExerciseHistoryWorkout(
                completedAt: Date(timeIntervalSince1970: 1_000),
                unit: .kilograms,
                sets: [
                    (weight: 100, reps: 5, warmup: false, complete: true),
                    (weight: 200, reps: 1, warmup: true, complete: true),
                    (weight: 120, reps: 5, warmup: false, complete: false)
                ]
            ),
            makeExerciseHistoryWorkout(
                completedAt: Date(timeIntervalSince1970: 2_000),
                unit: .pounds,
                sets: [(weight: 242.508, reps: 3, warmup: false, complete: true)]
            )
        ]
        let appState = AppState(repository: repository, serviceContainer: .demo(repository: repository))

        let history = appState.exerciseHistory(for: "barbell_bench_press")
        let records = appState.exerciseRecords(for: "barbell_bench_press")

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(try XCTUnwrap(records.heaviestWeightKilograms), 110, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(records.bestSetVolumeKilograms), 500, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(records.bestSessionVolumeKilograms), 500, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(records.bestEstimatedOneRepMaxKilograms), 121, accuracy: 0.01)
        XCTAssertEqual(records.mostRepetitions, 5)
    }

    private func makeExerciseHistoryWorkout(
        completedAt: Date,
        unit: UnitSystem,
        sets values: [(weight: Double, reps: Int, warmup: Bool, complete: Bool)]
    ) -> CompletedWorkout {
        let workoutID = UUID()
        let prescriptionID = UUID()
        let exercise = WorkoutExerciseSnapshot(
            id: prescriptionID,
            sourcePrescriptionID: nil,
            exerciseID: "barbell_bench_press",
            exerciseName: "Barbell Bench Press",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetSets: values.count,
            targetReps: "5",
            restSeconds: 120,
            order: 0,
            notes: "",
            rankingExerciseID: "bench"
        )
        let sets = values.enumerated().map { index, value in
            WorkoutSetLog(
                id: UUID(),
                prescriptionID: prescriptionID,
                performedAt: completedAt,
                setNumber: index + 1,
                weight: value.weight,
                reps: value.reps,
                rpe: 8,
                isWarmup: value.warmup,
                isComplete: value.complete,
                workoutID: workoutID,
                recordedUnit: unit
            )
        }
        return CompletedWorkout(
            id: workoutID,
            source: .freestyle,
            sourceSessionID: nil,
            sourcePlanID: nil,
            name: "History Test",
            dayLabel: "Test Day",
            startedAt: completedAt.addingTimeInterval(-1_800),
            completedAt: completedAt,
            duration: 1_800,
            effort: 3,
            notes: "",
            gymID: nil,
            bodyweight: nil,
            unit: unit,
            exercises: [exercise],
            sets: sets,
            linkedSubmissionIDs: []
        )
    }




}
