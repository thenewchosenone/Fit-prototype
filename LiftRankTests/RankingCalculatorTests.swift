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

    init(url: URL) {
        self.url = url
    }

    func save(_ data: Data, fileExtension: String) throws -> URL {
        savedData = data
        savedExtension = fileExtension
        return url
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

final class RankingCalculatorTests: XCTestCase {
    func testLeaderboardMovementPresentation() {
        XCTAssertEqual(LeaderboardMovementPresentation(4), .up(4))
        XCTAssertEqual(LeaderboardMovementPresentation(-3), .down(3))
        XCTAssertEqual(LeaderboardMovementPresentation(0), .unchanged)
    }

    func testEpleyOneRepMaxCalculation() {
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 225, repetitions: 5), 262.5, accuracy: 0.001)
        XCTAssertEqual(RankingCalculator.epleyOneRepMax(weight: 315, repetitions: 1), 315, accuracy: 0.001)
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

    func testExerciseProgressChartKeepsOnlyHighestSetPerDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 8)))
        let laterFirstDay = try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: firstDay))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let lightID = UUID()
        let heavyID = UUID()
        let nextDayID = UUID()

        let result = ExerciseProgressSeries.dailyHighest(from: [
            ExerciseProgressPoint(id: lightID, date: firstDay, weight: 11, reps: 15, unit: .pounds),
            ExerciseProgressPoint(id: heavyID, date: laterFirstDay, weight: 22, reps: 8, unit: .pounds),
            ExerciseProgressPoint(id: nextDayID, date: secondDay, weight: 16.5, reps: 10, unit: .pounds)
        ], calendar: calendar)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, heavyID)
        XCTAssertEqual(result[0].weight, 22)
        XCTAssertEqual(result[0].date, calendar.startOfDay(for: firstDay))
        XCTAssertEqual(result[1].id, nextDayID)
    }

    func testLeaderboardOrdering() {
        let seeded = MockData.community()
        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: seeded.lifts.filter { $0.exerciseID == "deadlift" },
            rankingType: .absolute,
            verifiedOnly: true,
            currentUserID: MockData.demoUserID
        )
        XCTAssertGreaterThan(entries.count, 5)
        XCTAssertTrue(entries[0].score >= entries[1].score)
        XCTAssertTrue(entries.contains { $0.profile.id == MockData.demoUserID })
    }

    @MainActor
    func testLeaderboardUsesDailySnapshot() {
        let appState = AppState()
        appState.verifiedOnly = false
        appState.leaderboardFilters = LeaderboardFilters(exerciseID: "deadlift")
        appState.leaderboardFilters.rankingType = .absolute

        let referenceDate = Date(timeIntervalSince1970: 1_782_374_400)
        let snapshotDate = appState.leaderboardSnapshotDate(referenceDate: referenceDate)
        var pendingLift = makeLift(userID: appState.currentProfile.id, weight: 2_000)
        pendingLift.createdAt = snapshotDate.addingTimeInterval(60)
        pendingLift.performedAt = pendingLift.createdAt
        pendingLift.leaderboardEligibleAt = appState.nextLeaderboardUpdateDate(referenceDate: referenceDate)
        appState.repository.lifts.append(pendingLift)

        let currentSnapshot = appState.leaderboardEntries(referenceDate: referenceDate)
        XCTAssertFalse(currentSnapshot.contains { $0.lift.id == pendingLift.id })

        let nextDay = appState.nextLeaderboardUpdateDate(referenceDate: referenceDate).addingTimeInterval(60)
        let refreshedSnapshot = appState.leaderboardEntries(referenceDate: nextDay)
        XCTAssertTrue(refreshedSnapshot.contains { $0.lift.id == pendingLift.id })
        XCTAssertEqual(refreshedSnapshot.first?.lift.id, pendingLift.id)
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
        let gymID = try XCTUnwrap(repository.joinedGymIDs.first)
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
        let nextSnapshotDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate))
        )
        XCTAssertEqual(submission.leaderboardEligibleAt, nextSnapshotDate)

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
    }

    @MainActor
    func testRankingNotificationOpensCurrentUsersGymLeaderboard() {
        let appState = AppState()
        guard let notification = appState.notifications.first(where: {
            $0.kind.localizedCaseInsensitiveContains("ranking")
        }) else {
            XCTFail("Expected a ranking notification")
            return
        }

        appState.openNotification(notification)

        XCTAssertEqual(appState.selectedTab, 1)
        XCTAssertEqual(appState.leaderboardFilters.exerciseID, "deadlift")
        XCTAssertEqual(appState.leaderboardFilters.gymID, appState.currentProfile.primaryGymID)
        XCTAssertEqual(appState.leaderboardFilters.rankingType, .absolute)
        XCTAssertTrue(appState.verifiedOnly)
        XCTAssertNotNil(appState.leaderboardFocusRequestID)
        XCTAssertTrue(appState.notifications.first(where: { $0.id == notification.id })?.isRead == true)
    }

    @MainActor
    func testOtherNotificationTypesOpenRelevantDestinations() {
        let appState = AppState()

        let liftNotification = NotificationItem(
            id: UUID(),
            title: "Lift approved",
            message: "Your lift was approved.",
            kind: "Lift approved",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(kind: .profile, targetID: appState.currentProfile.id)
        )
        appState.repository.notifications.append(liftNotification)
        appState.openNotification(liftNotification)
        XCTAssertEqual(appState.selectedTab, 4)

        let friendNotification = NotificationItem(
            id: UUID(),
            title: "Friend request",
            message: "You have a friend request.",
            kind: "Friend request",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(kind: .friendRequests)
        )
        appState.repository.notifications.append(friendNotification)
        appState.openNotification(friendNotification)
        XCTAssertEqual(appState.selectedTab, 0)
        XCTAssertEqual(appState.selectedCommunitySegment, "Home")

        let gymNotification = NotificationItem(
            id: UUID(),
            title: "Gym request submitted",
            message: "Your gym is available.",
            kind: "Gym request",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(kind: .gym, targetID: appState.currentProfile.primaryGymID, gymID: appState.currentProfile.primaryGymID)
        )
        appState.repository.notifications.append(gymNotification)
        appState.openNotification(gymNotification)
        XCTAssertEqual(appState.selectedTab, 0)
        XCTAssertTrue(appState.communityPath.isEmpty)
    }

    @MainActor
    func testTypedNotificationDestinationsOpenMessageAndWorkout() {
        let appState = AppState()
        guard let thread = appState.messageThreads.first else {
            XCTFail("Expected seeded message thread")
            return
        }

        let messageNotification = NotificationItem(
            id: UUID(),
            title: "New message",
            message: "You have a reply.",
            kind: "Message",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(kind: .messageThread, targetID: thread.id)
        )
        appState.repository.notifications.append(messageNotification)
        appState.openNotification(messageNotification)
        XCTAssertEqual(appState.selectedTab, 0)
        XCTAssertNil(appState.selectedMessageThread)

        let workoutNotification = NotificationItem(
            id: UUID(),
            title: "Weekly progress",
            message: "Review this week.",
            kind: "Workout",
            createdAt: .now,
            isRead: false,
            destination: NotificationDestination(kind: .workoutTracker, trackerStartsOnProgress: true)
        )
        appState.repository.notifications.append(workoutNotification)
        appState.openNotification(workoutNotification)
        XCTAssertEqual(appState.selectedTab, 2)
        XCTAssertTrue(appState.trainingTrackerStartOnProgress)
        XCTAssertEqual(appState.requestedTrackerSegment, "Progress")
    }

    @MainActor
    func testSubmitLiftCreatesDailyEligibleNotificationWithoutAutomaticForumPost() async {
        let appState = AppState()
        let initialThreadCount = appState.communityThreads.count
        let initialPostCount = appState.forumPosts.count
        let initialNotificationCount = appState.notifications.count
        let gymID = appState.currentProfile.primaryGymID
        let exercise = MockData.exercises[2]

        await appState.submitLift(
            exercise: exercise,
            weight: 405,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: appState.currentProfile.bodyweightPounds,
            date: .now,
            gymID: gymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: nil,
            caption: "Testing a public submit.",
            requestVerification: true
        )

        guard let lift = appState.lastSubmissionResult else {
            XCTFail("Expected submitted lift")
            return
        }
        XCTAssertGreaterThan(lift.leaderboardEligibleAt, lift.createdAt)
        XCTAssertEqual(appState.repository.lifts.first?.id, lift.id)
        XCTAssertEqual(appState.communityThreads.count, initialThreadCount)
        XCTAssertEqual(appState.forumPosts.count, initialPostCount)
        XCTAssertEqual(appState.notifications.count, initialNotificationCount + 1)
        XCTAssertEqual(appState.notifications.first?.destination.kind, .lift)
        XCTAssertEqual(appState.notifications.first?.destination.targetID, lift.id)
    }

    @MainActor
    func testVideoBackedSubmissionUpdatesStoredLiftAndResolvesPlayback() async throws {
        let repository = DemoRepository()
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
            gymID: repository.currentProfile.primaryGymID,
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
    func testCompetitionStoreOwnsVerificationServiceMutation() async throws {
        let repository = DemoRepository()
        let store = CompetitionStore(
            repository: repository,
            verificationService: MockVerificationService(repository: repository)
        )
        let lift = try XCTUnwrap(repository.lifts.first)

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
    func testPrivateSubmitLiftDoesNotCreateCommunityThread() async {
        let appState = AppState()
        let initialThreadCount = appState.communityThreads.count
        await appState.submitLift(
            exercise: MockData.exercises[0],
            weight: 225,
            unit: .pounds,
            reps: 1,
            isActual: true,
            bodyweight: appState.currentProfile.bodyweightPounds,
            date: .now,
            gymID: appState.currentProfile.primaryGymID,
            equipment: .raw,
            visibility: .privateLift,
            videoURL: nil,
            caption: "",
            requestVerification: false
        )
        XCTAssertEqual(appState.communityThreads.count, initialThreadCount)
    }

    @MainActor
    func testCommunityVotesReportsAndLockedThreads() {
        let appState = AppState()
        guard let thread = appState.communityThreads.first else {
            XCTFail("Expected seeded thread")
            return
        }

        appState.voteThread(thread, vote: .up)
        XCTAssertEqual(appState.currentThread(thread).voteScore, 1)
        appState.voteThread(thread, vote: .down)
        XCTAssertEqual(appState.currentThread(thread).voteScore, -1)
        appState.voteThread(thread, vote: nil)
        XCTAssertEqual(appState.currentThread(thread).voteScore, 0)

        appState.reportCommunity(targetType: .thread, targetID: thread.id, reason: .spam)
        appState.reportCommunity(targetType: .thread, targetID: thread.id, reason: .spam)
        XCTAssertEqual(appState.communityReports.filter { $0.targetID == thread.id && $0.status == "Open" }.count, 1)

        var moderator = appState.currentProfile
        moderator.experienceLevel = .veteran
        appState.repository.currentProfile = moderator
        if let index = appState.repository.profiles.firstIndex(where: { $0.id == moderator.id }) {
            appState.repository.profiles[index] = moderator
        }
        appState.moderateThread(thread, operation: .lock)
        XCTAssertTrue(appState.currentThread(thread).isLocked)
        let replyCount = appState.replies(for: thread).count
        appState.addReply(to: thread, body: "Should be blocked")
        XCTAssertEqual(appState.replies(for: thread).count, replyCount)
    }

    @MainActor
    func testGymMembershipCapAndPrimaryGymProtection() {
        let appState = AppState()
        let gyms = appState.gyms.filter { $0.id != appState.currentProfile.primaryGymID }
        XCTAssertTrue(appState.joinGym(gyms[0]))
        XCTAssertTrue(appState.joinGym(gyms[1]))
        XCTAssertFalse(appState.joinGym(gyms[2]))
        XCTAssertEqual(appState.joinedGymCount, AppState.maximumJoinedGyms)

        guard let primary = appState.gyms.first(where: { $0.id == appState.currentProfile.primaryGymID }) else {
            XCTFail("Expected primary gym")
            return
        }
        appState.leaveGym(primary)
        XCTAssertTrue(appState.isGymJoined(primary))
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
        let appState = AppState()
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
    func testGymMembershipIsLimitedToThreeGyms() {
        let appState = AppState()
        let secondaryGyms = appState.gyms.filter { $0.id != appState.currentProfile.primaryGymID }

        XCTAssertEqual(appState.joinedGymCount, 1)
        XCTAssertTrue(appState.joinGym(secondaryGyms[0]))
        XCTAssertTrue(appState.joinGym(secondaryGyms[1]))
        XCTAssertEqual(appState.joinedGymCount, 3)
        XCTAssertFalse(appState.joinGym(secondaryGyms[2]))
        XCTAssertEqual(appState.joinedGymCount, 3)
    }

    @MainActor
    func testLeavingSecondaryGymAllowsJoiningAnother() {
        let appState = AppState()
        let secondaryGyms = appState.gyms.filter { $0.id != appState.currentProfile.primaryGymID }

        XCTAssertTrue(appState.joinGym(secondaryGyms[0]))
        XCTAssertTrue(appState.joinGym(secondaryGyms[1]))
        appState.leaveGym(secondaryGyms[0])

        XCTAssertEqual(appState.joinedGymCount, 2)
        XCTAssertTrue(appState.joinGym(secondaryGyms[2]))
        XCTAssertEqual(appState.joinedGymCount, 3)
    }

    @MainActor
    func testPrimaryGymCannotBeLeft() {
        let appState = AppState()
        guard let primaryGym = appState.gyms.first(where: { $0.id == appState.currentProfile.primaryGymID }) else {
            XCTFail("Expected primary gym")
            return
        }

        appState.leaveGym(primaryGym)

        XCTAssertTrue(appState.isGymJoined(primaryGym))
        XCTAssertEqual(appState.joinedGymCount, 1)
    }

    @MainActor
    func testLiftCannotBeSubmittedForUnjoinedGym() async {
        let appState = AppState()
        guard let unjoinedGym = appState.gyms.first(where: { !appState.isGymJoined($0) }) else {
            XCTFail("Expected an unjoined gym")
            return
        }

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
        let appState = AppState()
        appState.verifiedOnly = false

        var gymFilters = LeaderboardFilters(exerciseID: "deadlift")
        gymFilters.gymID = appState.currentProfile.primaryGymID
        appState.leaderboardFilters = gymFilters
        let gymEntries = appState.leaderboardEntries()
        XCTAssertFalse(gymEntries.isEmpty)
        XCTAssertTrue(gymEntries.allSatisfy { $0.lift.gymID == appState.currentProfile.primaryGymID })

        var cityFilters = LeaderboardFilters(exerciseID: "deadlift")
        cityFilters.city = appState.currentProfile.city
        cityFilters.state = appState.currentProfile.state
        appState.leaderboardFilters = cityFilters
        let cityEntries = appState.leaderboardEntries()
        XCTAssertFalse(cityEntries.isEmpty)
        XCTAssertTrue(cityEntries.allSatisfy { $0.profile.city == appState.currentProfile.city && $0.profile.state == appState.currentProfile.state })

        var weightClassFilters = LeaderboardFilters(exerciseID: nil)
        weightClassFilters.sexCategory = appState.currentProfile.sexCategory
        weightClassFilters.weightClassID = RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: WeightClassCatalog.all
        )?.id
        appState.leaderboardFilters = weightClassFilters
        let weightClassEntries = appState.leaderboardEntries()
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

        XCTAssertEqual(expansion.count, 299)
        XCTAssertEqual(counts["Machine"], 56)
        XCTAssertEqual(counts["Smith Machine"], 27)
        XCTAssertEqual(counts["Cable"], 50)
        XCTAssertEqual(counts["Dumbbell"], 54)
        XCTAssertEqual(counts["Barbell"], 35)
        XCTAssertEqual(counts["Bodyweight"], 37)
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
    func testChallengeJoinAndLeaveUpdatesMembershipState() {
        let repository = DemoRepository()
        guard let challenge = repository.challenges.first(where: { !$0.isJoined }) else {
            XCTFail("Expected an unjoined challenge")
            return
        }
        let participantCount = challenge.participantCount

        repository.setChallengeJoined(challenge, joined: true)
        let joined = repository.challenges.first { $0.id == challenge.id }
        XCTAssertEqual(joined?.isJoined, true)
        XCTAssertEqual(joined?.participantCount, participantCount + 1)

        repository.setChallengeJoined(challenge, joined: false)
        let left = repository.challenges.first { $0.id == challenge.id }
        XCTAssertEqual(left?.isJoined, false)
        XCTAssertEqual(left?.participantCount, participantCount)
    }

    @MainActor
    func testGymRequestAddsVisibleGymAndRequestRecord() {
        let repository = DemoRepository()
        let request = GymRequest(
            id: UUID(),
            name: "Crunch Fitness - Test Club",
            city: "Miami",
            state: "Florida",
            requestedBy: MockData.demoUserID,
            note: "Prototype request",
            createdAt: .now
        )

        repository.requestGym(request)

        XCTAssertEqual(repository.gymRequests.first?.name, request.name)
        XCTAssertEqual(repository.gyms.first?.name, request.name)
        XCTAssertTrue(repository.communityThreads.contains { $0.kind == .gym && $0.gymID == repository.gyms.first?.id })
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
        XCTAssertTrue(repository.workoutEntries.contains { $0.planID == MockData.defaultWorkoutPlanID })
    }

    func testChallengeThreadsAreNotSeededWhileChallengesAreDisabled() {
        let challenges = MockData.challenges
        let challengeThreads = MockData.communityThreads(for: challenges).filter { $0.kind == .challenge }

        XCTAssertTrue(challengeThreads.isEmpty)
    }

    @MainActor
    func testFriendRequestCanBeSentAndAccepted() {
        let repository = DemoRepository()
        guard let profile = repository.profiles.first(where: { profile in
            profile.id != repository.currentProfile.id &&
            !repository.friendRequests.contains { request in
                (request.fromUserID == repository.currentProfile.id && request.toUserID == profile.id) ||
                (request.fromUserID == profile.id && request.toUserID == repository.currentProfile.id)
            }
        }) else {
            XCTFail("Expected a profile without a request")
            return
        }

        repository.sendFriendRequest(to: profile)

        guard let request = repository.friendRequests.first(where: { $0.fromUserID == repository.currentProfile.id && $0.toUserID == profile.id }) else {
            XCTFail("Expected sent friend request")
            return
        }
        XCTAssertEqual(request.status, .pending)

        repository.respondToFriendRequest(request, status: .accepted)

        XCTAssertEqual(repository.friendRequests.first { $0.id == request.id }?.status, .accepted)
        XCTAssertNotNil(repository.friendRequests.first { $0.id == request.id }?.respondedAt)
    }

    @MainActor
    func testPendingSentFriendRequestCanBeCanceled() {
        let repository = DemoRepository()
        guard let request = repository.friendRequests.first(where: { $0.fromUserID == repository.currentProfile.id && $0.status == .pending }) else {
            XCTFail("Expected seeded outgoing friend request")
            return
        }

        repository.cancelFriendRequest(request)

        XCTAssertFalse(repository.friendRequests.contains { $0.id == request.id })
    }

    func testRelativeTimeFormatterDoesNotShowSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now), "Just now")
        XCTAssertEqual(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-90), now: now), "1 min ago")
        XCTAssertFalse(LiftTimeFormatter.relativeNoSeconds(from: now.addingTimeInterval(-20), now: now).contains("sec"))
    }

    @MainActor
    func testMessageCanBeSentAndReported() {
        let repository = DemoRepository()
        guard let profile = repository.profiles.first(where: { $0.id != repository.currentProfile.id }) else {
            XCTFail("Expected another profile")
            return
        }
        let thread = repository.messageThread(with: profile)

        repository.addMessage(to: thread, body: "Can you spot bench later?")

        guard let sent = repository.directMessages.last(where: { $0.threadID == thread.id && $0.senderID == repository.currentProfile.id }) else {
            XCTFail("Expected sent message")
            return
        }
        XCTAssertEqual(sent.body, "Can you spot bench later?")

        repository.reportMessage(sent, reason: .spam, note: "Testing report")

        XCTAssertTrue(repository.directMessages.first { $0.id == sent.id }?.isReported == true)
        XCTAssertEqual(repository.messageReports.first?.messageID, sent.id)
        XCTAssertEqual(repository.messageReports.first?.reason, .spam)
    }

    @MainActor
    func testSocialMessagingStoreOwnsFriendAndMessageProjectionsAndMutations() throws {
        let repository = DemoRepository()
        let store = SocialMessagingStore(repository: repository)
        let profile = try XCTUnwrap(repository.profiles.first { candidate in
            candidate.id != repository.currentProfile.id && store.friendRequest(with: candidate) == nil
        })

        XCTAssertEqual(store.friendActionTitle(for: profile), "Connect")
        XCTAssertTrue(store.canSendFriendRequest(to: profile))
        store.sendLocalFriendRequest(to: profile)

        let request = try XCTUnwrap(store.friendRequest(with: profile))
        XCTAssertEqual(request.status, .pending)
        XCTAssertEqual(store.friendActionTitle(for: profile), "Request Sent")
        store.cancelLocalFriendRequest(request)
        XCTAssertNil(store.friendRequest(with: profile))

        store.sendLocalFriendRequest(to: profile)
        let resentRequest = try XCTUnwrap(store.friendRequest(with: profile))
        store.respondToLocalFriendRequest(resentRequest, accept: true)
        XCTAssertEqual(store.friendRequest(with: profile)?.status, .accepted)
        XCTAssertTrue(store.canOpenMessageThread(with: profile, friends: [profile]))

        let thread = store.openLocalMessageThread(with: profile)
        let initialMessageCount = store.messages(for: thread).count
        let updatedThread = try XCTUnwrap(store.sendLocalMessage(in: thread, body: "Store-owned message"))
        XCTAssertEqual(store.messages(for: thread).count, initialMessageCount + 1)
        XCTAssertEqual(store.lastMessage(in: thread)?.body, "Store-owned message")
        XCTAssertEqual(store.otherParticipant(in: updatedThread)?.id, profile.id)

        let sent = try XCTUnwrap(store.lastMessage(in: thread))
        _ = store.appendRemoteMessage(sent, in: thread)
        XCTAssertEqual(store.messages(for: thread).filter { $0.id == sent.id }.count, 1)
        store.reportLocalMessage(sent, reason: .spam, note: "Store report")
        XCTAssertTrue(repository.directMessages.first { $0.id == sent.id }?.isReported == true)
        store.deleteLocalMessage(sent)
        XCTAssertFalse(store.directMessages.contains { $0.id == sent.id })
        store.deleteLocalThread(thread)
        XCTAssertFalse(store.messageThreads.contains { $0.id == thread.id })
    }

    @MainActor
    func testIndividualMessageCanBeDeleted() {
        let appState = AppState()
        guard let thread = appState.messageThreads.first,
              let message = appState.messages(for: thread).first else {
            XCTFail("Expected seeded message")
            return
        }
        let initialCount = appState.messages(for: thread).count

        appState.deleteMessage(message)

        XCTAssertEqual(appState.messages(for: thread).count, initialCount - 1)
        XCTAssertFalse(appState.directMessages.contains { $0.id == message.id })
    }

    @MainActor
    func testConversationDeletionRemovesThreadAndMessages() {
        let appState = AppState()
        guard let thread = appState.messageThreads.first else {
            XCTFail("Expected seeded message thread")
            return
        }

        appState.selectedMessageThread = thread
        appState.deleteMessageThread(thread)

        XCTAssertFalse(appState.messageThreads.contains { $0.id == thread.id })
        XCTAssertFalse(appState.directMessages.contains { $0.threadID == thread.id })
        XCTAssertNil(appState.selectedMessageThread)
    }

    @MainActor
    func testCommunityThreadCanBeLikedAndCommentedOn() {
        let appState = AppState()
        guard let thread = appState.communityThreads.first else {
            XCTFail("Expected seeded thread")
            return
        }

        appState.toggleThreadLike(thread)
        appState.addReply(to: thread, body: "I am in for this lift check.")

        let updatedThread = appState.currentThread(thread)
        XCTAssertTrue(appState.isThreadLiked(updatedThread))
        XCTAssertEqual(updatedThread.likeCount, thread.likeCount + 1)
        XCTAssertEqual(updatedThread.replyCount, thread.replyCount + 1)
        XCTAssertTrue(appState.replies(for: updatedThread).contains { $0.body == "I am in for this lift check." })
    }

    @MainActor
    func testSeededCommunityThreadsHaveVisibleReplies() {
        let appState = AppState()
        guard let thread = appState.communityThreads.first(where: { $0.replyCount > 0 }) else {
            XCTFail("Expected seeded thread with replies")
            return
        }

        XCTAssertFalse(appState.replies(for: thread).isEmpty)
    }

    @MainActor
    func testSeededActivitiesHaveVisibleComments() {
        let appState = AppState()
        guard let activity = appState.activities.first(where: { !appState.comments(for: $0).isEmpty }) else {
            XCTFail("Expected seeded activity comments")
            return
        }

        XCTAssertGreaterThan(appState.comments(for: activity).count, 0)
    }

    @MainActor
    func testActivityCanBeLikedSavedAndCommentedOn() {
        let appState = AppState()
        guard let activity = appState.activities.first else {
            XCTFail("Expected seeded activity")
            return
        }

        appState.toggleActivityLike(activity)
        appState.toggleActivitySave(activity)
        appState.addComment(to: activity, body: "Strong lift.")

        let updatedActivity = appState.currentActivity(activity)
        XCTAssertTrue(updatedActivity.isLiked)
        XCTAssertTrue(updatedActivity.isSaved)
        XCTAssertTrue(appState.comments(for: updatedActivity).contains { $0.body == "Strong lift." })
    }

    @MainActor
    func testProgramBuilderCanCloneAndDeleteWeeks() {
        let repository = DemoRepository()
        guard let originalWeek = repository.workoutWeeks.first(where: { $0.planID == MockData.defaultWorkoutPlanID && $0.weekNumber == 1 }) else {
            XCTFail("Expected seeded week")
            return
        }
        let originalSessionCount = repository.workoutSessions.filter { $0.weekID == originalWeek.id }.count
        let originalPrescriptionCount = repository.workoutPrescriptions.count

        let clonedWeek = repository.cloneWorkoutWeek(originalWeek)

        XCTAssertNotEqual(clonedWeek.id, originalWeek.id)
        XCTAssertEqual(clonedWeek.weekNumber, 3)
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
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
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
    func testStartingFreestyleSessionAddsWorkoutToActiveWeek() {
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
        guard let week = appState.selectedPlanWeeks.first,
              let session = appState.sessions(for: week).first,
              let prescription = appState.prescriptions(for: session).first else {
            XCTFail("Expected seeded prescription")
            return
        }
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
        let seeded = MockData.community()
        let userID = seeded.profiles[0].id
        let lifts = [
            makeLift(userID: userID, weight: 300, exerciseID: "squat", repetitions: 1),
            makeLift(userID: userID, weight: 225, exerciseID: "bench", repetitions: 1),
            makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1),
            makeLift(userID: userID, weight: 600, exerciseID: "deadlift", repetitions: 5)
        ]
        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: lifts,
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].score, RankingCalculator.poundsToKilograms(1_025), accuracy: 0.001)
        XCTAssertEqual(entries[0].powerliftingBreakdown?.deadliftKilograms ?? 0, RankingCalculator.poundsToKilograms(500), accuracy: 0.001)

        let partialEntries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
            lifts: [makeLift(userID: userID, weight: 500, exerciseID: "deadlift", repetitions: 1)],
            rankingType: .total,
            verifiedOnly: false,
            currentUserID: nil
        )
        XCTAssertEqual(partialEntries.count, 1)
        XCTAssertNil(partialEntries[0].powerliftingBreakdown?.benchKilograms)
    }

    func testExerciseLeaderboardUsesSubmittedWeightRatherThanEstimatedMax() {
        let seeded = MockData.community()
        let firstUser = seeded.profiles[0].id
        let secondUser = seeded.profiles[1].id
        var lighter = makeLift(userID: firstUser, weight: 300, exerciseID: "bench", repetitions: 10)
        lighter.estimatedOneRepMax = 400
        let heavier = makeLift(userID: secondUser, weight: 315, exerciseID: "bench", repetitions: 1)

        let entries = RankingCalculator.leaderboardEntries(
            profiles: seeded.profiles,
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
    func testDefaultLeaderboardContainsSeededOpponents() {
        let appState = AppState()
        let entries = appState.leaderboardEntries()

        XCTAssertGreaterThan(entries.count, 1)
        XCTAssertTrue(entries.contains { $0.profile.id == appState.currentProfile.id })
        XCTAssertTrue(entries.contains { $0.profile.id != appState.currentProfile.id })
    }

    func testDefaultVerificationEligibilityIncludesEvidenceBasedStatuses() {
        XCTAssertTrue(VerificationStatus.videoVerified.isDefaultLeaderboardEligible)
        XCTAssertTrue(VerificationStatus.communityVerified.isDefaultLeaderboardEligible)
        XCTAssertTrue(VerificationStatus.competitionVerified.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.selfReported.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.videoSubmitted.isDefaultLeaderboardEligible)
        XCTAssertFalse(VerificationStatus.rejected.isDefaultLeaderboardEligible)
    }

    func testLegacyModeratorVerifiedStatusMigratesToVideoVerified() throws {
        let data = try XCTUnwrap("\"Moderator Verified\"".data(using: .utf8))

        let status = try JSONDecoder().decode(VerificationStatus.self, from: data)

        XCTAssertEqual(status, .videoVerified)
        XCTAssertEqual(status.rawValue, "Video Verified")
        XCTAssertFalse(VerificationStatus.allCases.map(\.rawValue).contains("Moderator Verified"))
    }

    func testAllSubmissionsIncludesSelfReportedTotal() {
        let seeded = MockData.community()
        let profile = seeded.profiles[1]
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

    @MainActor
    func testUnifiedCommunityFeedIsChronologicalAndSuppressesThreadEchoes() {
        let appState = AppState()
        let items = CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: .all
        )

        XCTAssertFalse(items.isEmpty)
        XCTAssertEqual(items.map(\.id), items.sorted { $0.createdAt > $1.createdAt }.map(\.id))
        XCTAssertFalse(items.contains { item in
            guard case .activity(let activity) = item else { return false }
            return activity.title.localizedCaseInsensitiveContains("started a thread") ||
                activity.title.localizedCaseInsensitiveContains("replied to")
        })
    }

    @MainActor
    func testCommunityBenchTopicUsesLinkedLiftData() {
        let appState = AppState()
        let items = CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: .bench
        )
        let liftByID = Dictionary(uniqueKeysWithValues: appState.lifts.map { ($0.id, $0) })

        XCTAssertFalse(items.isEmpty)
        for item in items {
            if case .activity(let activity) = item {
                XCTAssertEqual(activity.liftID.flatMap { liftByID[$0] }?.exerciseID, "bench")
            }
        }
    }

    @MainActor
    func testSubmittedLiftActivityRetainsLiftLink() {
        let appState = AppState()
        let lift = makeLift(userID: appState.currentProfile.id, weight: 405)

        appState.repository.addLift(lift)

        XCTAssertEqual(appState.activities.first?.liftID, lift.id)
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
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
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
    func testProgramStoreOwnsSelectedPlanProjectionsAndLifecycle() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
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
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
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

        var bodyweight = try XCTUnwrap(store.bodyweightEntries.first)
        bodyweight.actual = 201
        bodyweight.notes = "Store test"
        store.updateBodyweight(bodyweight)
        XCTAssertEqual(store.bodyweightEntries.first(where: { $0.id == bodyweight.id }), bodyweight)
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

        XCTAssertTrue(store.attemptAutomaticCompletion(before: logs[1]))
        XCTAssertEqual(store.completedWorkingSets.map(\.id), [logs[0].id])

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

        let candidates = store.prCandidates(existingLifts: [])
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.setID, first.id)
        XCTAssertEqual(candidates.first?.rankingExerciseID, "bench")

        store.deleteSet(added)
        XCTAssertFalse(store.setLogs(for: exercise).contains { $0.id == added.id })
    }

    @MainActor
    func testPlannedWorkoutUsesImmutableExerciseSnapshot() {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
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
    func testAutomaticPRSubmissionRequiresOptInAndVideoAndDoesNotDuplicate() async {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        repository.completedWorkouts = []
        let appState = AppState(repository: repository)
        let bench = try! XCTUnwrap(appState.trainingExerciseLibrary.first(where: { $0.id == "barbell_bench_press" }))
        XCTAssertFalse(appState.workoutPreferences.automaticallySubmitVideoBackedPRs)

        XCTAssertTrue(appState.startFreestyleWorkoutInstance())
        appState.addExercisesToActiveWorkout([bench])
        var log = try! XCTUnwrap(repository.workoutSetLogs.first(where: { $0.workoutID == appState.activeWorkout?.id }))
        log.weight = 1_000
        log.reps = 1
        log.isComplete = true
        appState.updateSetLog(log)
        let completed = try! XCTUnwrap(appState.finishActiveWorkout(effort: 5, notes: "PR"))
        let initialLiftCount = appState.lifts.count
        let initialThreadCount = appState.communityThreads.count

        await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: [log.id: URL(fileURLWithPath: "/tmp/pr.mov")])
        XCTAssertEqual(appState.lifts.count, initialLiftCount)

        appState.setAutomaticVideoPRSubmission(true)
        await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: [:])
        XCTAssertEqual(appState.lifts.count, initialLiftCount)

        let videoURL = URL(fileURLWithPath: "/tmp/pr.mov")
        await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: [log.id: videoURL])
        XCTAssertEqual(appState.lifts.count, initialLiftCount + 1)
        XCTAssertEqual(appState.communityThreads.count, initialThreadCount)
        XCTAssertEqual(appState.lifts.first?.verificationStatus, .videoVerified)
        XCTAssertEqual(appState.lifts.first?.evidenceStatus, .videoBacked)
        XCTAssertEqual(appState.lifts.first?.visibility, .publicLift)
        XCTAssertEqual(appState.lifts.first?.weight, 1_000)
        XCTAssertEqual(appState.lifts.first?.repetitions, 1)
        XCTAssertTrue(appState.lifts.first?.isActualOneRepMax == true)
        XCTAssertGreaterThan(appState.lifts.first?.leaderboardEligibleAt ?? .distantPast, appState.lifts.first?.createdAt ?? .distantFuture)
        XCTAssertEqual(appState.pendingWorkoutPRSubmissions.first(where: { $0.candidate.setID == log.id })?.state, .submitted)
        XCTAssertEqual(appState.completedWorkouts.first(where: { $0.id == completed.id })?.linkedSubmissionIDs.count, 1)

        await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: [log.id: videoURL])
        XCTAssertEqual(appState.lifts.count, initialLiftCount + 1)
    }

    @MainActor
    func testWorkoutPRSubmissionStoreOwnsMediaQueueSubmissionAndWorkoutLinking() async throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
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
        XCTAssertFalse(repository.workoutPlans.isEmpty)
        XCTAssertFalse(MockData.trainingExerciseLibrary.isEmpty)
        XCTAssertNotNil(store.loadSnapshot())
    }

    @MainActor
    func testForumSeedsEightCommunitiesAndThreeHomeMemberships() {
        let appState = AppState()
        XCTAssertEqual(appState.repository.forumCommunities.count, 8)
        XCTAssertEqual(appState.joinedForumCommunities.count, 3)
        XCTAssertTrue(appState.joinedForumCommunities.contains { $0.id == MockData.generalStrengthCommunityID })
        XCTAssertTrue(appState.joinedForumCommunities.contains { $0.id == MockData.powerliftingCommunityID })
        XCTAssertTrue(appState.joinedForumCommunities.contains { $0.id == MockData.milestonesCommunityID })
        XCTAssertTrue(appState.isForumStaff)
        XCTAssertTrue(appState.repository.forumPosts.contains { $0.destination.gymID != nil })
    }

    @MainActor
    func testCommunityStoreOwnsForumDiscoveryFeedsCommentsAndActivityProjection() throws {
        let repository = DemoRepository()
        let referenceDate = Date(timeIntervalSince1970: 1_782_374_400)
        let store = CommunityStore(repository: repository, now: { referenceDate })

        XCTAssertEqual(store.joinedCommunities.count, 3)
        XCTAssertTrue(store.isStaff)
        XCTAssertEqual(store.notifications.count, repository.forumNotifications.filter {
            $0.userID == repository.currentProfile.id
        }.count)

        let joinedCommunity = try XCTUnwrap(store.joinedCommunities.first)
        let searchResults = store.searchCommunities(query: joinedCommunity.name)
        XCTAssertEqual(searchResults.first?.id, joinedCommunity.id)

        let feed = store.feed(communityID: joinedCommunity.id, sort: .new)
        XCTAssertTrue(feed.allSatisfy { $0.destination.communityID == joinedCommunity.id })
        let unpinnedDates = feed.filter { !$0.isPinned }.map(\.createdAt)
        XCTAssertEqual(unpinnedDates, unpinnedDates.sorted(by: >))

        if let post = repository.forumPosts.first(where: { candidate in
            repository.forumComments.contains { $0.postID == candidate.id }
        }) {
            let newest = store.comments(for: post.id, sort: .new)
            XCTAssertEqual(newest.map(\.createdAt), newest.map(\.createdAt).sorted(by: >))
            let oldest = store.comments(for: post.id, sort: .old)
            XCTAssertEqual(oldest.map(\.createdAt), oldest.map(\.createdAt).sorted())
            XCTAssertEqual(
                store.hotScore(post, referenceDate: post.createdAt.addingTimeInterval(86_400)),
                Double(post.voteScore * 2) + log2(Double(post.commentCount) + 1) * 3 - 1,
                accuracy: 0.001
            )
        } else {
            XCTFail("Expected seeded forum comments")
        }

        let activity = try XCTUnwrap(repository.activities.first)
        XCTAssertEqual(store.currentActivity(activity).id, activity.id)
        XCTAssertEqual(
            store.comments(for: activity).map(\.createdAt),
            store.comments(for: activity).map(\.createdAt).sorted()
        )
    }

    @MainActor
    func testCommunityStoreOwnsMembershipAndForumEngagementMutations() throws {
        let repository = DemoRepository()
        let store = CommunityStore(repository: repository)
        let userID = repository.currentProfile.id
        let community = try XCTUnwrap(store.joinedCommunities.first)
        XCTAssertTrue(store.canRead(community.id))
        store.setArchived(true, communityID: community.id)
        XCTAssertNotNil(repository.forumCommunities.first { $0.id == community.id }?.archivedAt)
        store.setArchived(false, communityID: community.id)
        XCTAssertNil(repository.forumCommunities.first { $0.id == community.id }?.archivedAt)
        let post = try XCTUnwrap(repository.forumPosts.first {
            $0.destination.communityID == community.id && $0.removedAt == nil && !$0.isLocked
        })

        let newVote: CommunityVote = post.votes[userID] == .up ? .down : .up
        XCTAssertEqual(store.vote(on: post.id, selection: newVote)?.id, post.id)
        XCTAssertEqual(store.post(post.id)?.votes[userID], newVote)

        let wasSaved = post.savedByUserIDs.contains(userID)
        XCTAssertEqual(store.toggleSaved(postID: post.id)?.id, post.id)
        XCTAssertEqual(store.post(post.id)?.savedByUserIDs.contains(userID), !wasSaved)

        let wasWatched = post.watchedByUserIDs.contains(userID)
        XCTAssertEqual(store.toggleWatched(postID: post.id)?.id, post.id)
        XCTAssertEqual(store.post(post.id)?.watchedByUserIDs.contains(userID), !wasWatched)

        let comment = try XCTUnwrap(store.addComment(
            postID: post.id,
            parentCommentID: nil,
            body: "Store-owned engagement"
        ))
        XCTAssertTrue(store.comments(for: post.id).contains { $0.id == comment.id })
        XCTAssertEqual(store.vote(onComment: comment.id, selection: .up)?.id, comment.id)
        XCTAssertEqual(repository.forumComments.first { $0.id == comment.id }?.votes[userID], .up)
        XCTAssertTrue(store.report(
            targetType: .comment,
            targetID: comment.id,
            communityID: community.id,
            reason: .spam,
            note: "  duplicate links  "
        ))
        XCTAssertEqual(store.forumReports.first { $0.targetID == comment.id }?.note, "duplicate links")
        store.deleteComment(comment.id)
        XCTAssertNotNil(repository.forumComments.first { $0.id == comment.id }?.removedAt)

        let ownedPost = makeForumPost(
            communityID: community.id,
            author: repository.currentProfile,
            title: "Store edit target"
        )
        XCTAssertTrue(repository.createForumPost(ownedPost))
        store.update(ownedPost, title: "  Updated title  ", body: "  Updated body  ")
        XCTAssertEqual(store.post(ownedPost.id)?.title, "Updated title")
        XCTAssertEqual(store.post(ownedPost.id)?.body, "Updated body")
        store.deletePost(ownedPost.id)
        XCTAssertNotNil(store.post(ownedPost.id)?.removedAt)

        XCTAssertEqual(store.moderate(postID: post.id, action: .lock)?.id, post.id)
        XCTAssertTrue(store.post(post.id)?.isLocked == true)
        store.moderate(postID: post.id, action: .unlock)
        XCTAssertFalse(store.post(post.id)?.isLocked == true)

        if let unread = store.notifications.first(where: { !$0.isRead }) {
            store.markNotificationRead(unread.id)
            XCTAssertTrue(store.notifications.first { $0.id == unread.id }?.isRead == true)
        }

        store.setNotificationLevel(.off, communityID: community.id)
        XCTAssertEqual(store.membership(for: community.id)?.notificationLevel, .off)

        let unjoined = try XCTUnwrap(store.communities.first { !store.isJoined(to: $0.id) && $0.visibility == .publicOpen })
        XCTAssertEqual(store.join(unjoined.id), .joined)
        XCTAssertTrue(store.isJoined(to: unjoined.id))
        XCTAssertEqual(store.leave(unjoined.id)?.id, unjoined.id)
        XCTAssertFalse(store.isJoined(to: unjoined.id))
    }

    @MainActor
    func testCommunityStoreOwnsRemotePostAndEngagementBoundary() async throws {
        let local = DemoRepository()
        let remote = DemoRepository()
        let store = CommunityStore(
            repository: local,
            socialService: MockSocialService(repository: remote),
            communityService: MockCommunityService(repository: remote)
        )
        let community = try XCTUnwrap(store.joinedCommunities.first)
        let post = try XCTUnwrap(store.createPost(
            destination: .community(community.id),
            kind: .discussion,
            title: "Remote boundary",
            body: "Store forwards this mutation"
        ))

        await store.syncCreatedPost(post)
        XCTAssertTrue(remote.forumPosts.contains { $0.id == post.id })

        await store.syncVote(on: post, selection: .up)
        XCTAssertEqual(
            remote.forumPosts.first { $0.id == post.id }?.votes[remote.currentProfile.id],
            .up
        )

        await store.syncSavedState(of: post)
        XCTAssertTrue(
            remote.forumPosts.first { $0.id == post.id }?.savedByUserIDs.contains(remote.currentProfile.id) == true
        )

        await store.syncModeration(of: post, action: .lock, reason: "Review")
        XCTAssertTrue(remote.forumPosts.first { $0.id == post.id }?.isLocked == true)
    }

    @MainActor
    func testCommunityStoreBuildsDeterministicTrimmedPollPosts() throws {
        let repository = DemoRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let generatedIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000204")!
        ]
        var idIterator = generatedIDs.makeIterator()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = CommunityStore(
            repository: repository,
            calendar: calendar,
            now: { timestamp },
            makeUUID: { idIterator.next()! }
        )
        let community = try XCTUnwrap(store.joinedCommunities.first)

        let post = try XCTUnwrap(store.createPost(
            destination: .community(community.id),
            kind: .poll,
            title: "  Training split  ",
            body: "  Pick one  ",
            tag: "Programming",
            pollOptions: ["  Upper/Lower  ", "", "  Full body"],
            pollCloseDays: 3
        ))

        XCTAssertEqual(post.id, generatedIDs[3])
        XCTAssertEqual(post.poll?.id, generatedIDs[0])
        XCTAssertEqual(post.poll?.options.map(\.id), Array(generatedIDs[1...2]))
        XCTAssertEqual(post.poll?.options.map(\.text), ["Upper/Lower", "Full body"])
        XCTAssertEqual(post.poll?.closesAt, calendar.date(byAdding: .day, value: 3, to: timestamp))
        XCTAssertEqual(post.title, "Training split")
        XCTAssertEqual(post.body, "Pick one")
        XCTAssertEqual(post.tag, "Programming")
        XCTAssertEqual(post.createdAt, timestamp)
        XCTAssertEqual(store.post(post.id), post)
    }

    @MainActor
    func testPublicForumRequiresMembershipBeforeInteraction() throws {
        let repository = DemoRepository()
        let appState = AppState(repository: repository)
        let community = try XCTUnwrap(repository.forumCommunities.first { $0.id == MockData.bodybuildingCommunityID })
        let regular = try XCTUnwrap(repository.profiles.first { profile in
            profile.id != MockData.demoUserID && repository.forumMembership(communityID: community.id, userID: profile.id) == nil
        })
        repository.currentProfile = regular
        let post = makeForumPost(communityID: community.id, author: regular, title: "Testing membership gates")

        XCTAssertTrue(repository.canReadForumCommunity(community.id))
        XCTAssertFalse(repository.canContributeToForumCommunity(community.id))
        XCTAssertFalse(repository.createForumPost(post))
        XCTAssertEqual(repository.joinForumCommunity(community.id), .joined)
        XCTAssertTrue(repository.canContributeToForumCommunity(community.id))
        XCTAssertTrue(repository.createForumPost(post))
        appState.voteForumPost(post.id, vote: .up)
        XCTAssertEqual(appState.forumPost(post.id)?.votes[regular.id], .up)
        appState.toggleForumPostSaved(post.id)
        appState.toggleForumPostWatched(post.id)
        XCTAssertTrue(appState.forumPost(post.id)?.savedByUserIDs.contains(regular.id) == true)
        XCTAssertTrue(appState.forumPost(post.id)?.watchedByUserIDs.contains(regular.id) == true)
    }

    @MainActor
    func testRestrictedMembershipRequestRequiresStaffApproval() throws {
        let repository = DemoRepository()
        let appState = AppState(repository: repository)
        XCTAssertTrue(appState.createForumCommunity(
            name: "Coach Lab", summary: "Restricted programming reviews", details: "Private review room",
            category: "Training", visibility: .restricted, rules: ["Keep client data private"]
        ))
        let community = try XCTUnwrap(repository.forumCommunities.first { $0.name == "Coach Lab" })
        let regular = try XCTUnwrap(repository.profiles.first { $0.id != MockData.demoUserID })
        repository.currentProfile = regular

        XCTAssertFalse(repository.canReadForumCommunity(community.id))
        XCTAssertEqual(repository.joinForumCommunity(community.id, note: "I coach locally"), .pending)
        let request = try XCTUnwrap(repository.forumJoinRequests.first { $0.communityID == community.id && $0.userID == regular.id })
        XCTAssertFalse(repository.canContributeToForumCommunity(community.id))

        repository.currentProfile = MockData.demoProfile
        repository.resolveForumJoinRequest(request.id, approved: true)
        repository.currentProfile = regular
        XCTAssertTrue(repository.canReadForumCommunity(community.id))
        XCTAssertTrue(repository.canContributeToForumCommunity(community.id))
    }

    @MainActor
    func testInviteOnlyCommunityIsHiddenUntilStaffInvitesUser() throws {
        let repository = DemoRepository()
        let appState = AppState(repository: repository)
        XCTAssertTrue(appState.createForumCommunity(
            name: "Staff Testers", summary: "Invite-only feature testing", details: "Hidden room",
            category: "Staff", visibility: .inviteOnly, rules: ["Do not share builds"]
        ))
        let community = try XCTUnwrap(repository.forumCommunities.first { $0.name == "Staff Testers" })
        let regular = try XCTUnwrap(repository.profiles.first { $0.id != MockData.demoUserID })
        repository.currentProfile = regular
        XCTAssertFalse(repository.visibleForumCommunities().contains { $0.id == community.id })
        XCTAssertNil(repository.joinForumCommunity(community.id))

        repository.currentProfile = MockData.demoProfile
        XCTAssertTrue(repository.inviteForumMember(userID: regular.id, communityID: community.id))
        repository.currentProfile = regular
        XCTAssertTrue(repository.visibleForumCommunities().contains { $0.id == community.id })
        XCTAssertEqual(repository.joinForumCommunity(community.id), .joined)
    }

    @MainActor
    func testForumSnapshotRestoresPostsMembershipAndVotes() throws {
        let store = InMemoryForumPersistenceStore()
        let first = DemoRepository(forumPersistenceStore: store)
        let post = makeForumPost(
            communityID: MockData.generalStrengthCommunityID,
            author: first.currentProfile,
            title: "Persist this forum post"
        )
        XCTAssertTrue(first.createForumPost(post))
        first.voteForumPost(post.id, vote: .up)

        let restored = DemoRepository(forumPersistenceStore: store)
        let restoredPost = try XCTUnwrap(restored.forumPosts.first { $0.id == post.id })
        XCTAssertEqual(restoredPost.title, post.title)
        XCTAssertEqual(restoredPost.votes[MockData.demoUserID], .up)
        XCTAssertEqual(restored.forumCommunities.count, 8)
    }

    @MainActor
    func testForumRepliesPreserveNestedParentRelationships() throws {
        let repository = DemoRepository()
        let post = try XCTUnwrap(repository.forumPosts.first { $0.destination.communityID == MockData.generalStrengthCommunityID })
        let root = try XCTUnwrap(repository.addForumComment(postID: post.id, parentCommentID: nil, body: "Root comment"))
        let child = try XCTUnwrap(repository.addForumComment(postID: post.id, parentCommentID: root.id, body: "First reply"))
        let nestedAttempt = try XCTUnwrap(repository.addForumComment(postID: post.id, parentCommentID: child.id, body: "Replying deeper"))

        XCTAssertEqual(child.parentCommentID, root.id)
        XCTAssertEqual(nestedAttempt.parentCommentID, child.id)
        XCTAssertEqual(nestedAttempt.body, "Replying deeper")

        let items = ForumCommentThreadBuilder.flattened(comments: [root, child, nestedAttempt])
        XCTAssertEqual(items.map(\.comment.id), [root.id, child.id, nestedAttempt.id])
        XCTAssertEqual(items.map(\.depth), [0, 1, 2])
        XCTAssertEqual(items.map(\.descendantCount), [2, 1, 0])

        let collapsed = ForumCommentThreadBuilder.flattened(
            comments: [root, child, nestedAttempt],
            collapsedCommentIDs: [root.id]
        )
        XCTAssertEqual(collapsed.map(\.comment.id), [root.id])
        XCTAssertEqual(collapsed.first?.descendantCount, 2)
    }

    @MainActor
    func testPollVoteCanChangeAndForumReportsDoNotDuplicate() throws {
        let repository = DemoRepository()
        let appState = AppState(repository: repository)
        _ = repository.joinForumCommunity(MockData.programmingCommunityID)
        let pollPost = try XCTUnwrap(repository.forumPosts.first { $0.kind == .poll })
        let poll = try XCTUnwrap(pollPost.poll)
        let firstOption = try XCTUnwrap(poll.options.first)
        let secondOption = try XCTUnwrap(poll.options.dropFirst().first)
        appState.voteInForumPoll(postID: pollPost.id, optionID: firstOption.id)
        appState.voteInForumPoll(postID: pollPost.id, optionID: secondOption.id)
        let updated = try XCTUnwrap(appState.forumPost(pollPost.id)?.poll)
        XCTAssertFalse(updated.options.first(where: { $0.id == firstOption.id })?.voterIDs.contains(appState.currentProfile.id) == true)
        XCTAssertTrue(updated.options.first(where: { $0.id == secondOption.id })?.voterIDs.contains(appState.currentProfile.id) == true)

        XCTAssertTrue(appState.reportForumContent(targetType: .post, targetID: pollPost.id, communityID: pollPost.destination.communityID, reason: .spam))
        XCTAssertFalse(appState.reportForumContent(targetType: .post, targetID: pollPost.id, communityID: pollPost.destination.communityID, reason: .spam))
        XCTAssertEqual(appState.forumReports.filter { $0.targetID == pollPost.id && $0.status == .open }.count, 1)
    }

    @MainActor
    func testForumModerationUsesRolesAndRecordsAuditHistory() throws {
        let repository = DemoRepository()
        let post = try XCTUnwrap(repository.forumPosts.first { $0.destination.communityID == MockData.generalStrengthCommunityID && $0.removedAt == nil })
        let regular = try XCTUnwrap(repository.profiles.first { profile in
            profile.id != MockData.demoUserID && repository.forumMembership(communityID: MockData.generalStrengthCommunityID, userID: profile.id) == nil
        })
        repository.currentProfile = regular
        _ = repository.joinForumCommunity(MockData.generalStrengthCommunityID)
        repository.moderateForumPost(post.id, action: .remove, reason: "Should not work")
        XCTAssertNil(repository.forumPosts.first(where: { $0.id == post.id })?.removedAt)

        repository.currentProfile = MockData.demoProfile
        repository.moderateForumPost(post.id, action: .remove, reason: "Confirmed spam")
        XCTAssertNotNil(repository.forumPosts.first(where: { $0.id == post.id })?.removedAt)
        XCTAssertEqual(repository.forumModerationActions.first?.kind, .remove)
        repository.moderateForumPost(post.id, action: .restore, reason: "Appeal accepted")
        XCTAssertNil(repository.forumPosts.first(where: { $0.id == post.id })?.removedAt)
    }

    @MainActor
    func testPinnedForumPostsSortAheadOfHotPosts() throws {
        let repository = DemoRepository()
        let appState = AppState(repository: repository)
        let post = makeForumPost(
            communityID: MockData.generalStrengthCommunityID,
            author: repository.currentProfile,
            title: "Pinned staff announcement"
        )
        XCTAssertTrue(repository.createForumPost(post))
        repository.moderateForumPost(post.id, action: .pin, reason: "Important")
        let feed = appState.forumFeed(communityID: MockData.generalStrengthCommunityID, sort: .hot)
        let pinnedIndex = try XCTUnwrap(feed.firstIndex(where: { $0.id == post.id }))
        let firstUnpinnedIndex = feed.firstIndex(where: { !$0.isPinned }) ?? feed.endIndex
        XCTAssertTrue(feed.first?.isPinned == true)
        XCTAssertLessThan(pinnedIndex, firstUnpinnedIndex)
    }

    @MainActor
    func testForumNotificationRoutesDirectlyToPost() throws {
        let appState = AppState()
        let post = try XCTUnwrap(appState.forumPosts.first)
        let notification = ForumNotification(
            id: UUID(), userID: appState.currentProfile.id, actorID: nil, kind: .reply,
            title: "New reply", message: "A lifter replied", communityID: post.destination.communityID,
            postID: post.id, commentID: nil, createdAt: .now, isRead: false
        )
        appState.repository.forumNotifications.append(notification)
        appState.openForumNotification(notification)
        XCTAssertEqual(appState.selectedTab, 3)
        XCTAssertEqual(appState.communityPath, [.post(post.id)])
        XCTAssertTrue(appState.repository.forumNotifications.first(where: { $0.id == notification.id })?.isRead == true)
    }

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

    @MainActor
    func testPersonalPDFProgramIsPrivateCompleteAndFaithfulToProgression() throws {
        let repository = DemoRepository(workoutPersistenceStore: InMemoryWorkoutPersistenceStore())
        let plan = try XCTUnwrap(repository.workoutPlans.first { $0.id == PersonalWorkoutPlanCatalog.planID })
        let weeks = repository.workoutWeeks.filter { $0.planID == plan.id }
        let weekIDs = Set(weeks.map(\.id))
        let sessions = repository.workoutSessions.filter { weekIDs.contains($0.weekID) }
        let sessionIDs = Set(sessions.map(\.id))
        let prescriptions = repository.workoutPrescriptions.filter { sessionIDs.contains($0.sessionID) }

        XCTAssertEqual(plan.name, "BTS Beginner (Private)")
        XCTAssertFalse(plan.isActive)
        XCTAssertFalse(WorkoutProgramCatalog.templates.contains { $0.name == plan.name })
        XCTAssertEqual(weeks.count, 12)
        XCTAssertEqual(sessions.count, 60)
        XCTAssertEqual(prescriptions.count, 372)

        let weekOne = try XCTUnwrap(weeks.first { $0.weekNumber == 1 })
        let firstUpper = try XCTUnwrap(sessions.first { $0.weekID == weekOne.id && $0.name == "Upper (Strength Focus)" })
        let firstIncline = try XCTUnwrap(repository.workoutPrescriptions.first { $0.sessionID == firstUpper.id && $0.exerciseName == "45° Incline Barbell Press" })
        XCTAssertEqual(firstIncline.sets, 1)
        XCTAssertEqual(firstIncline.reps, "6-8")
        XCTAssertEqual(firstIncline.restSeconds, 240)
        XCTAssertEqual(firstIncline.targetRIR, 4)

        let weekTwelve = try XCTUnwrap(weeks.first { $0.weekNumber == 12 })
        let finalUpper = try XCTUnwrap(sessions.first { $0.weekID == weekTwelve.id && $0.name == "Upper (Strength Focus)" })
        let finalLateralRaise = try XCTUnwrap(repository.workoutPrescriptions.first { $0.sessionID == finalUpper.id && $0.exerciseName == "High-Cable Lateral Raise" })
        XCTAssertEqual(finalLateralRaise.sets, 2)
        XCTAssertEqual(finalLateralRaise.reps, "10-12")
        XCTAssertEqual(finalLateralRaise.targetRIR, 0)
        XCTAssertTrue(finalLateralRaise.notes.contains("technical failure"))
    }

    @MainActor
    func testPersonalPDFProgramMigratesIntoExistingSnapshotWithoutDuplication() {
        let store = InMemoryWorkoutPersistenceStore()
        let firstRepository = DemoRepository(workoutPersistenceStore: store)
        firstRepository.persistWorkoutSnapshot()

        let restoredRepository = DemoRepository(workoutPersistenceStore: store)
        XCTAssertEqual(
            restoredRepository.workoutPlans.filter { $0.id == PersonalWorkoutPlanCatalog.planID }.count,
            1
        )
        XCTAssertEqual(
            restoredRepository.workoutWeeks.filter { $0.planID == PersonalWorkoutPlanCatalog.planID }.count,
            12
        )
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
        XCTAssertNil(store.createCustomExercise(
            name: "   ",
            bodyPart: "Chest",
            equipment: "Cable",
            trackingType: "Weight + Reps"
        ))
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
    func testPrivateRoutineDemoHistoryFillsTwelveWeeksWithoutDuplicating() throws {
        let repository = DemoRepository()
        let referenceDate = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 12))
        )

        repository.seedPersonalWorkoutDemoHistory(referenceDate: referenceDate)
        let workouts = repository.completedWorkouts.filter {
            $0.sourcePlanID == PersonalWorkoutPlanCatalog.planID &&
                $0.notes.contains("[demo:private-history-v1]")
        }
        let sourcePrescriptionIDs = Set(repository.workoutPrescriptions
            .filter { prescription in
                repository.workoutSessions.contains { session in
                    session.id == prescription.sessionID &&
                        repository.workoutWeeks.contains {
                            $0.id == session.weekID && $0.planID == PersonalWorkoutPlanCatalog.planID
                        }
                }
            }
            .map(\.id))
        let loggedPrescriptionIDs = Set(repository.workoutSetLogs.filter(\.isComplete).map(\.prescriptionID))

        XCTAssertEqual(workouts.count, 57)
        XCTAssertEqual(Set(workouts.map(\.id)).count, workouts.count)
        XCTAssertTrue(workouts.allSatisfy { !$0.completedWorkingSets.isEmpty })
        XCTAssertTrue(workouts.allSatisfy { $0.completedAt <= referenceDate })
        XCTAssertFalse(sourcePrescriptionIDs.isDisjoint(with: loggedPrescriptionIDs))
        XCTAssertEqual(repository.bodyweightEntries.filter { $0.notes.contains("[demo:private-history-v1]") }.count, 12)

        repository.seedPersonalWorkoutDemoHistory(referenceDate: referenceDate)
        XCTAssertEqual(repository.completedWorkouts.filter {
            $0.sourcePlanID == PersonalWorkoutPlanCatalog.planID &&
                $0.notes.contains("[demo:private-history-v1]")
        }.count, 57)
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

        XCTAssertNotNil(repository.startWorkout(session: weekOneSession, planID: plan.id, gymID: nil, bodyweight: nil, unit: .pounds))
        XCTAssertTrue(repository.changeWorkoutProgramProgression(planID: plan.id, method: .rirRepRange, trainingMaxKilograms: [:]))

        XCTAssertNil(repository.workoutPrescriptions.first { $0.id == weekOnePrescriptionID }?.targetRIR)
        XCTAssertNotNil(repository.workoutPrescriptions.first { $0.id == weekTwoPrescriptionID }?.targetRIR)
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
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(WorkoutPersistenceSnapshot.self, from: legacyData)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertNil(decoded.planProgressionSettings)
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
        let repository = DemoRepository()
        repository.workoutPreferences.defaultRestTimerEnabled = false
        let session = try XCTUnwrap(repository.workoutSessions.first)

        let workout = try XCTUnwrap(
            repository.startWorkout(session: session, planID: nil, gymID: nil, bodyweight: nil, unit: .pounds)
        )

        XCTAssertFalse(workout.automaticRestTimerEnabled)
    }

    @MainActor
    func testAutomaticCompletionCompletesPreviousSetOnceValuesExist() throws {
        let repository = DemoRepository()
        let session = try XCTUnwrap(repository.workoutSessions.first)
        let workout = try XCTUnwrap(
            repository.startWorkout(session: session, planID: nil, gymID: nil, bodyweight: nil, unit: .pounds)
        )
        let exercise = try XCTUnwrap(workout.exercises.first)
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

    func testBundledDemoMediaResolvesOnlyForLeaderboardClips() throws {
        XCTAssertNil(BundledDemoMediaLibrary.shared.url(for: "demo-horizontal-press"))
        XCTAssertNotNil(BundledDemoMediaLibrary.shared.url(for: "demo-leaderboard-bench"))
        XCTAssertNotNil(BundledDemoMediaLibrary.shared.url(for: "demo-leaderboard-squat"))
        XCTAssertNotNil(BundledDemoMediaLibrary.shared.url(for: "demo-leaderboard-deadlift"))
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

    func testSeededDemoLiftsCarryDemoMediaIdentifiers() {
        let lifts = MockData.community().lifts
        let demoMediaIDs = lifts.compactMap(\.demoMediaID)

        XCTAssertTrue(demoMediaIDs.contains("demo-leaderboard-bench"))
        XCTAssertTrue(demoMediaIDs.contains("demo-leaderboard-squat"))
        XCTAssertTrue(demoMediaIDs.contains("demo-leaderboard-deadlift"))
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

    private func makeForumPost(communityID: UUID, author: UserProfile, title: String) -> ForumPost {
        ForumPost(
            id: UUID(), destination: .community(communityID), authorID: author.id,
            authorName: author.displayName, kind: .discussion, title: title,
            body: "A detailed test discussion for the LiftRank forum prototype.", tag: nil,
            attachments: [], poll: nil, liftID: nil, workoutID: nil, linkURL: nil,
            challengeID: nil, createdAt: .now, editedAt: nil, commentCount: 0,
            votes: [:], savedByUserIDs: [], watchedByUserIDs: [], isPinned: false,
            isLocked: false, removedAt: nil, removalReason: nil
        )
    }
}
