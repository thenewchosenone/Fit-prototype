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

    func testLiftSetTextWithoutRepLabel() {
        XCTAssertEqual(
            MeasurementFormatting.liftSetText(weightKilograms: 150, unit: .kilograms, repetitions: 5),
            "150 kg × 5"
        )
    }

    func testLiftSetTextWithXKeepsXSeparator() {
        XCTAssertEqual(
            MeasurementFormatting.liftSetTextWithX(weightKilograms: 225, unit: .pounds, repetitions: 3),
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

    func testLiftSetTextWithRepLabel() {
        XCTAssertEqual(
            MeasurementFormatting.liftSetText(weightKilograms: 150, unit: .kilograms, repetitions: 1, includeRepLabel: true),
            "150 kg × 1 rep"
        )
    }

    func testBodyweightInLbText() {
        XCTAssertEqual(RankingFormatting.bodyweightInLbText(225.4), "225 lb BW")
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
