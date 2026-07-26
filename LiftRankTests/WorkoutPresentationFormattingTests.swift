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
        XCTAssertEqual(MeasurementFormatting.compactDisplayedWeight(200, unit: .pounds), "200lb")
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
            "220.5 lb"
        )
    }

    func testCurrentWeekBodyweightDraftReusesExistingEntry() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let existing = BodyweightEntry(
            id: UUID(),
            week: 4,
            targetDate: now.addingTimeInterval(-86_400),
            actual: 205,
            notes: "existing"
        )

        let draft = BodyweightEntry.draftForCurrentWeek(
            entries: [existing],
            currentBodyweightPounds: 210,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(draft.id, existing.id)
        XCTAssertEqual(draft.actual, 205)
    }

    func testCurrentWeekBodyweightDraftStartsBlankWhenProfileBodyweightIsMissing() {
        let draft = BodyweightEntry.draftForCurrentWeek(
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
        XCTAssertEqual(MeasurementFormatting.shortDurationText(3_700), "61m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(-600), "0m")
        XCTAssertEqual(MeasurementFormatting.shortDurationText(3_780), "1h 3m")
    }

    func testWeightClassDisplayNameUsesNameWhenNotPounds() {
        XCTAssertEqual(
            RankingFormatting.weightClassDisplayName(
                WeightClass(id: "test", sexCategory: .open, name: "Test", minKilograms: 0, maxKilograms: nil),
                preferredUnit: .kilograms
            ),
            "Test"
        )
    }

    func testWeightClassDisplayNameForOpenClassInPounds() {
        XCTAssertEqual(
            RankingFormatting.weightClassDisplayName(
                WeightClass(id: "test", sexCategory: .open, name: "Open", minKilograms: 90, maxKilograms: nil),
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
