import XCTest
@testable import LiftRank

final class WorkoutPresentationFormattingTests: XCTestCase {
    func testShortClockTextFromTimeInterval() {
        XCTAssertEqual(MeasurementFormatting.shortClockText(125.5), "2:05")
        XCTAssertEqual(MeasurementFormatting.shortClockText(-20), "0:00")
    }

    func testShortClockTextFromSeconds() {
        XCTAssertEqual(MeasurementFormatting.shortClockText(seconds: 125), "2:05")
        XCTAssertEqual(MeasurementFormatting.shortClockText(seconds: 59), "0:59")
    }

    func testLongClockText() {
        XCTAssertEqual(MeasurementFormatting.longClockText(3661), "01:01:01")
        XCTAssertEqual(MeasurementFormatting.longClockText(-10), "00:00:00")
    }

    func testSignedShortClockText() {
        XCTAssertEqual(MeasurementFormatting.signedShortClockText(seconds: 125), "+2:05")
        XCTAssertEqual(MeasurementFormatting.signedShortClockText(seconds: -125), "-2:05")
        XCTAssertEqual(MeasurementFormatting.signedShortClockText(seconds: 0), "+0:00")
    }

    func testWeightFormattingIsStable() {
        XCTAssertEqual(MeasurementFormatting.formatWeight(0), "0")
        XCTAssertEqual(MeasurementFormatting.formatWeight(77.5), "77.5")
        XCTAssertEqual(MeasurementFormatting.workoutLoadText(225), "225")
        XCTAssertEqual(MeasurementFormatting.workoutLoadText(225.015555), "225.02")
        XCTAssertEqual(MeasurementFormatting.workoutLoadText(2.5), "2.5")
    }

    func testWorkoutSetWeightParsingUsesLocaleAndRejectsInvalidValues() {
        let enUS = Locale(identifier: "en_US")
        XCTAssertEqual(WorkoutSetLogRow.parseWeight("100.5", locale: enUS), 100.5)
        XCTAssertNil(WorkoutSetLogRow.parseWeight("100,5", locale: enUS))
        XCTAssertEqual(WorkoutSetLogRow.parseWeight("1,000", locale: enUS), 1_000)
        XCTAssertNil(WorkoutSetLogRow.parseWeight("100.5 lb", locale: enUS))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("NaN", locale: enUS))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("inf", locale: enUS))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("", locale: enUS))

        let frFR = Locale(identifier: "fr_FR")
        XCTAssertEqual(WorkoutSetLogRow.parseWeight("100,5", locale: frFR), 100.5)
        XCTAssertNil(WorkoutSetLogRow.parseWeight("100.5", locale: frFR))
        XCTAssertEqual(WorkoutSetLogRow.parseWeight("1,000", locale: frFR), 1)
        XCTAssertNil(WorkoutSetLogRow.parseWeight("100,5 lb", locale: frFR))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("NaN", locale: frFR))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("inf", locale: frFR))
        XCTAssertNil(WorkoutSetLogRow.parseWeight("", locale: frFR))
    }

    func testRecordedLiftSetTextPreservesKilograms() {
        XCTAssertEqual(
            MeasurementFormatting.recordedLiftSetText(weight: 150, unit: .kilograms, repetitions: 5),
            "150 kg × 5"
        )
    }

    func testRecordedLiftSetTextPreservesPoundsWithoutDoubleConversion() {
        XCTAssertEqual(
            MeasurementFormatting.recordedLiftSetTextWithX(weight: 225, unit: .pounds, repetitions: 3),
            "225 lb x 3"
        )
    }

    func testCompactDisplayedWeightOmitsUnitSpacing() {
        XCTAssertEqual(MeasurementFormatting.compactDisplayedWeight(200, unit: .pounds), "440.9lb")
        XCTAssertEqual(MeasurementFormatting.compactDisplayedWeight(90.5, unit: .kilograms), "90.5kg")
    }

    func testCompactDisplayedWeightOrDashReturnsDashForMissingValue() {
        XCTAssertEqual(MeasurementFormatting.compactDisplayedWeightOrDash(nil, unit: .pounds), "—")
        XCTAssertEqual(MeasurementFormatting.compactDisplayedWeightOrDash(0, unit: .pounds), "0lb")
    }

    func testRecordedLiftSetTextWithRepLabel() {
        XCTAssertEqual(
            MeasurementFormatting.recordedLiftSetText(weight: 150, unit: .kilograms, repetitions: 1, includeRepLabel: true),
            "150 kg × 1 rep"
        )
    }

    func testNormalizedLiftSetTextConvertsAtDisplayBoundary() {
        XCTAssertEqual(
            MeasurementFormatting.normalizedLiftSetText(weightKilograms: 100, preferredUnit: .pounds, repetitions: 2),
            "220.5 lb × 2"
        )
    }

    func testDisplayedLeaderboardTotalConvertsCanonicalKilogramsToPreferredUnit() {
        XCTAssertEqual(MeasurementFormatting.formatDisplayedWeight(100, unit: .pounds), "220.5 lb")
        XCTAssertEqual(MeasurementFormatting.formatDisplayedWeight(100, unit: .kilograms), "100 kg")
    }

    func testBodyweightInLbText() {
        XCTAssertEqual(RankingFormatting.bodyweightInLbText(225.4), "225 lb BW")
    }

    func testLeaderboardRankTextNeverInventsPercentileForMissingRank() {
        XCTAssertEqual(RankingFormatting.leaderboardRankText(rank: nil), "Unranked")
        XCTAssertEqual(RankingFormatting.leaderboardRankText(rank: 4), "#4")
    }

    func testStrengthScoreTierKeepsLowScoreBeginner() {
        XCTAssertEqual(RankingFormatting.strengthTier(for: 14).label, "Beginner")
        XCTAssertEqual(RankingFormatting.strengthTier(for: 60).label, "Advanced")
    }

    func testEarnedExperienceRequiresVerifiedStrengthData() {
        XCTAssertEqual(
            RankingFormatting.earnedExperienceLevel(relativeTotal: 5.5, verifiedLiftCount: 0),
            .beginner
        )
        XCTAssertEqual(
            RankingFormatting.earnedExperienceDescription(relativeTotal: 5.5, verifiedLiftCount: 0),
            "Submit verified lifts to earn a level"
        )
        XCTAssertEqual(
            RankingFormatting.earnedExperienceLevel(relativeTotal: 4.2, verifiedLiftCount: 3),
            .advanced
        )
    }

    func testBodyweightFormattingUsesPreferredUnitFromPoundsStorage() {
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweight(220.46226218, preferredUnit: .kilograms),
            "100 kg"
        )
        XCTAssertEqual(
            MeasurementFormatting.displayBodyweightValue(220.46226218, preferredUnit: .kilograms),
            100,
            accuracy: 0.001
        )
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweightOrDash(nil, preferredUnit: .pounds),
            "—"
        )
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweightOrDash(0, preferredUnit: .pounds),
            "—"
        )
    }

    func testProfileLocationFormattingHandlesVisibleHiddenAndMissingStates() {
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: "Miami", region: "Florida"),
            "Miami, Florida"
        )
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: "Miami", region: nil),
            "Miami"
        )
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: nil, region: "Florida"),
            "Florida"
        )
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: "Miami", region: "Florida", hidden: true),
            "Location hidden"
        )
        XCTAssertEqual(
            ProfileDisplayFormatting.location(city: "  ", region: nil),
            "Location missing"
        )
    }

    func testThreeLiftTotalFormattingUsesPreferredUnitFromPoundsStorage() {
        XCTAssertEqual(
            RankingFormatting.threeLiftTotalText(totalPounds: 1102.31131, preferredUnit: .kilograms),
            "500 kg"
        )
        XCTAssertEqual(
            RankingFormatting.threeLiftTotalText(totalPounds: 500, preferredUnit: .pounds),
            "500 lb"
        )
    }

    func testWorkoutSetTextPreservesRecordedPoundsInsteadOfConvertingAgain() {
        let set = WorkoutSetLog(
            id: UUID(),
            prescriptionID: UUID(),
            performedAt: Date(timeIntervalSince1970: 1_800_000_000),
            setNumber: 1,
            weight: 500,
            reps: 10,
            rpe: 8,
            isWarmup: false,
            isComplete: true,
            recordedUnit: .pounds
        )

        XCTAssertEqual(
            MeasurementFormatting.workoutSetText(set: set, trackingKind: .weightReps),
            "500 lb × 10"
        )
    }

    func testCanonicalWorkoutAndBodyweightDisplayUseDifferentStorageRules() {
        let recordedSet = WorkoutSetLog(
            id: UUID(),
            prescriptionID: UUID(),
            performedAt: Date(timeIntervalSince1970: 1_800_000_000),
            setNumber: 1,
            weight: 500,
            reps: 10,
            rpe: nil,
            isWarmup: false,
            isComplete: true,
            recordedUnit: .pounds
        )

        XCTAssertEqual(
            MeasurementFormatting.workoutSetText(set: recordedSet, trackingKind: .weightReps),
            "500 lb × 10"
        )
        XCTAssertEqual(
            MeasurementFormatting.formatBodyweight(220.46226218, preferredUnit: .kilograms),
            "100 kg"
        )
    }

    func testRecordedVolumeDisplayConvertsBeforeComparingWorkoutSummaries() {
        XCTAssertEqual(
            MeasurementFormatting.displayRecordedVolume(220.46226218, recordedUnit: .pounds, preferredUnit: .kilograms),
            100,
            accuracy: 0.001
        )
        XCTAssertEqual(
            MeasurementFormatting.formatRecordedVolume(100, recordedUnit: .kilograms, preferredUnit: .pounds),
            "220.5 lb × reps"
        )
    }

    func testTodayBodyweightDraftReusesSameDayEntry() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let existing = BodyweightEntry(
            id: UUID(),
            week: 4,
            targetDate: now.addingTimeInterval(-60),
            actual: 205,
            notes: "existing"
        )

        let draft = BodyweightEntry.draftForToday(
            entries: [existing],
            currentBodyweightPounds: 210,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(draft.id, existing.id)
        XCTAssertEqual(draft, existing)
    }

    func testTodayBodyweightDraftDoesNotReuseEarlierEntryInSameWeek() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        calendar.firstWeekday = 1
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 23, minute: 36)))
        let previousDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12)))
        let existing = BodyweightEntry(id: UUID(), week: 3, targetDate: previousDate, actual: 207, notes: "Sunday")

        let draft = BodyweightEntry.draftForToday(
            entries: [existing],
            currentBodyweightPounds: 207,
            calendar: calendar,
            now: now
        )

        XCTAssertNotEqual(draft.id, existing.id)
        XCTAssertEqual(draft.targetDate, now)
        XCTAssertEqual(draft.week, 4)
        XCTAssertEqual(draft.actual, 207)
        XCTAssertEqual(draft.notes, "")
    }

    func testTodayBodyweightDraftUsesLocalDayAcrossMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 0, minute: 5)))
        let yesterday = BodyweightEntry(id: UUID(), week: 3, targetDate: now.addingTimeInterval(-600), actual: 207, notes: "")

        let draft = BodyweightEntry.draftForToday(entries: [yesterday], currentBodyweightPounds: 207, calendar: calendar, now: now)

        XCTAssertNotEqual(draft.id, yesterday.id)
        XCTAssertEqual(draft.targetDate, now)
    }

    func testTodayBodyweightDraftStartsNewEntryAfterPreviousWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let previousWeek = BodyweightEntry(
            id: UUID(),
            week: 4,
            targetDate: now.addingTimeInterval(-7 * 86_400),
            actual: 205,
            notes: "previous week"
        )

        let draft = BodyweightEntry.draftForToday(
            entries: [previousWeek],
            currentBodyweightPounds: 210,
            calendar: calendar,
            now: now
        )

        XCTAssertNotEqual(draft.id, previousWeek.id)
        XCTAssertEqual(draft.week, 5)
        XCTAssertEqual(draft.targetDate, now)
        XCTAssertEqual(draft.actual, 210)
    }

    func testTodayBodyweightDraftStartsBlankWhenProfileBodyweightIsMissing() {
        let draft = BodyweightEntry.draftForToday(
            entries: [],
            currentBodyweightPounds: 0,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertNil(draft.actual)
        XCTAssertEqual(draft.week, 1)
    }

    func testShortDurationText() {
        XCTAssertEqual(MeasurementFormatting.shortDurationText(0), "0m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(59), "0m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(60), "1m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(125), "2m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(3_700), "1h 1m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(-600), "0m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(3_780), "1h 3m")
    }

    func testWeightClassDisplayNameUsesNameWhenNotPounds() {
        XCTAssertEqual(
            RankingFormatting.weightClassDisplayName(
                WeightClass(id: "test", sexCategory: .male, name: "Test", minKilograms: 0, maxKilograms: nil),
                preferredUnit: .kilograms
            ),
            "Test"
        )
    }

    func testWeightClassDisplayNameForOpenClassInPounds() {
        XCTAssertEqual(
            RankingFormatting.weightClassDisplayName(
                WeightClass(id: "test", sexCategory: .male, name: "Open", minKilograms: 90, maxKilograms: nil),
                preferredUnit: .pounds
            ),
            "198.4+ lb (Open)"
        )
    }

    func testBestPRsByRepsSelectsHeaviestInBothUnits() {
        let reps1 = ExerciseProgressPoint(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: .now,
            weight: 225,
            reps: 5,
            unit: .kilograms
        )
        let reps2 = ExerciseProgressPoint(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            date: .now,
            weight: 500,
            reps: 5,
            unit: .kilograms
        )
        let reps3 = ExerciseProgressPoint(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            date: .now,
            weight: 300,
            reps: 3,
            unit: .kilograms
        )

        let best = MeasurementFormatting.bestPRsByReps(from: [reps1, reps2, reps3])

        XCTAssertEqual(best.count, 2)
        XCTAssertEqual(best[0].reps, 3)
        XCTAssertEqual(best[0].weight, 300)
        XCTAssertEqual(best[0].unit, .kilograms)
        XCTAssertEqual(best[1].reps, 5)
        XCTAssertEqual(best[1].weight, 500)
        XCTAssertEqual(best[1].unit, .kilograms)
    }
}

@MainActor
final class WorkoutProgramBuilderTests: XCTestCase {
    func testHistoryImportBuildsTwelveWeeksAcrossSixWeekdaysWithoutChangingSources() throws {
        let repository = DemoRepository()
        let pull = sourceWorkout(name: "Pull", exerciseIDs: ["row", "curl"], completedSetsPerExercise: 2)
        let push = sourceWorkout(name: "Push", exerciseIDs: ["press"], completedSetsPerExercise: 3)
        let legs = sourceWorkout(name: "Legs", exerciseIDs: ["squat"], completedSetsPerExercise: 4)
        repository.completedWorkouts = [pull, push, legs]
        let originalWorkouts = repository.completedWorkouts
        let store = ProgramStore(repository: repository)
        let assignments: [(workout: CompletedWorkout, weekday: Int)] = [
            (pull, 2), (push, 3), (legs, 4), (pull, 5), (push, 6), (legs, 7)
        ]

        let plan = try XCTUnwrap(store.createPlanFromHistory(
            name: "Winter Volume V2",
            assignments: assignments,
            durationWeeks: 12,
            startDate: .now,
            preferredUnit: .pounds
        ))
        let weeks = store.weeks(planID: plan.id)
        let sessions = weeks.flatMap(store.sessions(week:))

        XCTAssertEqual(weeks.count, 12)
        XCTAssertEqual(sessions.count, 72)
        XCTAssertEqual(Set(sessions.map(\.day)).count, 6)
        XCTAssertFalse(plan.isActive)
        XCTAssertEqual(repository.completedWorkouts, originalWorkouts)

        let firstPull = try XCTUnwrap(sessions.first { $0.name == "Pull" })
        let copiedPrescriptions = store.prescriptions(session: firstPull)
        XCTAssertEqual(copiedPrescriptions.map(\.exerciseName), ["Row", "Curl"])
        XCTAssertEqual(copiedPrescriptions.map(\.sets), [2, 2])
        XCTAssertEqual(copiedPrescriptions.map(\.reps), ["8–12", "8–12"])
        XCTAssertEqual(copiedPrescriptions.first?.notes, "Keep source notes")
        XCTAssertEqual(copiedPrescriptions.first?.targetRIR, 2)
        XCTAssertEqual(copiedPrescriptions.first?.targetLoadKilograms, 50)
        XCTAssertEqual(copiedPrescriptions.first?.substitutionExerciseIDs, ["test-sub"])
    }

    func testFutureWeekEditLeavesProtectedHistoryUnchanged() throws {
        let repository = DemoRepository()
        let source = sourceWorkout(name: "Full Body", exerciseIDs: ["squat"], completedSetsPerExercise: 2)
        repository.completedWorkouts = [source]
        let store = ProgramStore(repository: repository)
        let plan = try XCTUnwrap(store.createPlanFromHistory(
            name: "Three weeks",
            assignments: [(source, 2)],
            durationWeeks: 3,
            startDate: .now,
            preferredUnit: .kilograms
        ))
        let sessions = store.weeks(planID: plan.id).flatMap(store.sessions(week:))
        let original = try XCTUnwrap(store.prescriptions(session: sessions[0]).first)
        var edited = original
        edited.sets = 5

        let updatedCount = store.updatePrescription(
            edited,
            scope: .futureWeeks,
            excludingSessionIDs: [sessions[0].id]
        )

        XCTAssertEqual(updatedCount, 2)
        XCTAssertEqual(store.prescriptions(session: sessions[0]).first?.sets, 2)
        XCTAssertEqual(store.prescriptions(session: sessions[1]).first?.sets, 5)
        XCTAssertEqual(store.prescriptions(session: sessions[2]).first?.sets, 5)
    }

    func testSupersetGroupingStoresSharedRestBetweenRounds() throws {
        let repository = DemoRepository()
        let source = sourceWorkout(name: "Pair", exerciseIDs: ["row", "curl"], completedSetsPerExercise: 2)
        let store = ProgramStore(repository: repository)
        let plan = try XCTUnwrap(store.createPlanFromHistory(
            name: "Pair plan",
            assignments: [(source, 2)],
            durationWeeks: 1,
            startDate: .now,
            preferredUnit: .kilograms
        ))
        let session = try XCTUnwrap(store.weeks(planID: plan.id).first.flatMap { store.sessions(week: $0).first })
        let prescriptions = store.prescriptions(session: session)

        XCTAssertTrue(store.setSuperset(sessionID: session.id, exerciseIDs: prescriptions.map(\.id), restSeconds: 60))
        let grouped = store.prescriptions(session: session)
        XCTAssertEqual(grouped.compactMap(\.supersetGroup).count, 2)
        XCTAssertEqual(Set(grouped.compactMap(\.supersetGroup)).count, 1)
        XCTAssertEqual(grouped.compactMap(\.supersetRestSeconds), [60, 60])

        store.removeSuperset(sessionID: session.id, exerciseID: prescriptions[0].id)
        XCTAssertTrue(store.prescriptions(session: session).allSatisfy { $0.supersetGroup == nil && $0.supersetRestSeconds == nil })
    }

    func testSharedPlanImportsAsInactiveEditableCopyWithFreshIDs() throws {
        let repository = DemoRepository()
        let source = sourceWorkout(name: "Share source", exerciseIDs: ["row", "curl"], completedSetsPerExercise: 2)
        let store = ProgramStore(repository: repository)
        let plan = try XCTUnwrap(store.createPlanFromHistory(
            name: "Share source plan",
            assignments: [(source, 2)],
            durationWeeks: 2,
            startDate: .now,
            preferredUnit: .kilograms
        ))
        let sourceSession = try XCTUnwrap(store.weeks(planID: plan.id).first.flatMap { store.sessions(week: $0).first })
        let sourcePrescriptions = store.prescriptions(session: sourceSession)
        XCTAssertTrue(store.setSuperset(sessionID: sourceSession.id, exerciseIDs: sourcePrescriptions.map(\.id), restSeconds: 75))
        let sharedText = try XCTUnwrap(store.shareablePlanText(planID: plan.id))

        let copy = try XCTUnwrap(store.importSharedPlan(sharedText))
        let originalSessions = store.weeks(planID: plan.id).flatMap { store.sessions(week: $0) }
        let copiedSessions = store.weeks(planID: copy.id).flatMap { store.sessions(week: $0) }

        XCTAssertEqual(copy.name, "Share source plan (Copy)")
        XCTAssertFalse(copy.isActive)
        XCTAssertEqual(copiedSessions.count, originalSessions.count)
        XCTAssertTrue(Set(originalSessions.map(\.id)).isDisjoint(with: Set(copiedSessions.map(\.id))))
        let copiedPrescriptions = store.prescriptions(session: copiedSessions[0])
        XCTAssertEqual(copiedPrescriptions.first?.sets, 2)
        XCTAssertEqual(Set(copiedPrescriptions.compactMap(\.supersetGroup)).count, 1)
        XCTAssertEqual(copiedPrescriptions.compactMap(\.supersetRestSeconds), [75, 75])
    }

    func testSavedProgramSyncsAndRestoresFromRemotePlanService() async throws {
        let service = MockWorkoutSyncService()
        let persistence = InMemoryWorkoutPersistenceStore()
        let originalRepository = DemoRepository(workoutPersistenceStore: persistence)
        let plan = try XCTUnwrap(ProgramStore(repository: originalRepository).createPlan(name: "Sync test", isActive: false))
        originalRepository.persistWorkoutSnapshot()
        let initialSync = WorkoutSyncStore(repository: originalRepository, service: service)
        await initialSync.synchronizeWorkoutPlans()
        XCTAssertEqual(initialSync.planSyncState, .synced)
        originalRepository.persistWorkoutSnapshot()

        let relaunchedRepository = DemoRepository(workoutPersistenceStore: persistence)
        XCTAssertEqual(relaunchedRepository.workoutPlans.first(where: { $0.id == plan.id })?.name, "Sync test")

        let restoredRepository = DemoRepository()
        restoredRepository.currentProfile = originalRepository.currentProfile
        let restoredSync = WorkoutSyncStore(repository: restoredRepository, service: service)
        await restoredSync.synchronizeWorkoutPlans()

        XCTAssertEqual(restoredSync.planSyncState, .synced)
        XCTAssertEqual(restoredRepository.workoutPlans.first(where: { $0.id == plan.id })?.name, "Sync test")
        XCTAssertEqual(restoredRepository.workoutWeeks.filter { $0.planID == plan.id }.count, 1)
    }

    private func sourceWorkout(
        name: String,
        exerciseIDs: [String],
        completedSetsPerExercise: Int
    ) -> CompletedWorkout {
        let workoutID = UUID()
        let exercises = exerciseIDs.enumerated().map { order, exerciseID in
            WorkoutExerciseSnapshot(
                id: UUID(), sourcePrescriptionID: nil, exerciseID: exerciseID,
                exerciseName: exerciseID.capitalized, bodyPart: "Full body", equipment: "Barbell",
                targetSets: 4, targetReps: "8–12", restSeconds: 90, order: order,
                notes: "Keep source notes", substitutionExerciseIDs: ["test-sub"],
                targetRIR: 2, targetLoadKilograms: 50
            )
        }
        let logs = exercises.flatMap { exercise in
            (1...completedSetsPerExercise).map { number in
                WorkoutSetLog(
                    id: UUID(), prescriptionID: exercise.id, performedAt: .now,
                    setNumber: number, weight: 50, reps: 8, rpe: 8, isWarmup: false,
                    isComplete: true, workoutID: workoutID, recordedUnit: .kilograms
                )
            }
        }
        return CompletedWorkout(
            id: workoutID, source: .freestyle, sourceSessionID: nil, sourcePlanID: nil,
            name: name, dayLabel: "Monday", startedAt: .now.addingTimeInterval(-3600),
            completedAt: .now, duration: 3600, effort: 3, notes: "Source workout note",
            gymID: nil, bodyweight: nil, unit: .kilograms, exercises: exercises,
            sets: logs, linkedSubmissionIDs: []
        )
    }
}
