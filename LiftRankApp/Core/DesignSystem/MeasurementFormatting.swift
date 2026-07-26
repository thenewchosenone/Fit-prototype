import Foundation

enum MeasurementFormatting {
    static func longClockText(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    static func shortClockText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return shortClockText(seconds: seconds)
    }

    static func shortClockText(seconds totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func signedShortClockText(_ duration: TimeInterval) -> String {
        return signedShortClockText(seconds: Int(duration.rounded()))
    }

    static func signedShortClockText(seconds deltaSeconds: Int) -> String {
        let sign = deltaSeconds >= 0 ? "+" : "-"
        let text = shortClockText(seconds: abs(deltaSeconds))
        return "\(sign)\(text)"
    }

    static func displayWeight(_ kilograms: Double, unit: UnitSystem) -> Double {
        convert(kilograms, from: .kilograms, to: unit)
    }

    static func convert(_ value: Double, from source: UnitSystem, to target: UnitSystem) -> Double {
        guard source != target else { return value }
        return target == .kilograms ? RankingCalculator.poundsToKilograms(value) : RankingCalculator.kilogramsToPounds(value)
    }

    static func normalizeToKilograms(_ value: Double, unit: UnitSystem) -> Double {
        convert(value, from: unit, to: .kilograms)
    }

    static func formatDisplayedWeight(_ kilograms: Double, unit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        "\(format(displayWeight(kilograms, unit: unit))) \(unit.shortLabel)"
    }

    static func formatRecordedWeight(_ value: Double, unit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        "\(format(value)) \(unit.shortLabel)"
    }

    static func displayRecordedVolume(_ value: Double, recordedUnit: UnitSystem, preferredUnit: UnitSystem) -> Double {
        convert(value, from: recordedUnit, to: preferredUnit)
    }

    static func formatRecordedVolume(
        _ value: Double,
        recordedUnit: UnitSystem,
        preferredUnit: UnitSystem,
        format: (Double) -> String = RankingCalculator.format
    ) -> String {
        "\(format(displayRecordedVolume(value, recordedUnit: recordedUnit, preferredUnit: preferredUnit))) \(preferredUnit.shortLabel)"
    }

    static func compactDisplayedWeight(_ kilograms: Double, unit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        "\(format(displayWeight(kilograms, unit: unit)))\(unit.shortLabel)"
    }

    static func compactDisplayedWeightOrDash(_ kilograms: Double?, unit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        guard let kilograms else { return "—" }
        return compactDisplayedWeight(kilograms, unit: unit, format: format)
    }

    static func formatBodyweight(_ pounds: Double, preferredUnit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        let value = convert(pounds, from: .pounds, to: preferredUnit)
        return "\(format(value)) \(preferredUnit.shortLabel)"
    }

    static func displayBodyweightValue(_ pounds: Double, preferredUnit: UnitSystem) -> Double {
        convert(pounds, from: .pounds, to: preferredUnit)
    }

    static func formatBodyweightOrDash(_ pounds: Double?, preferredUnit: UnitSystem, format: (Double) -> String = RankingCalculator.format) -> String {
        guard let pounds, pounds > 0 else { return "—" }
        return formatBodyweight(pounds, preferredUnit: preferredUnit, format: format)
    }

    static func repetitionText(_ repetitions: Int, includeLabel: Bool = false) -> String {
        includeLabel ? "× \(repetitions) \(repetitions == 1 ? "rep" : "reps")" : "× \(repetitions)"
    }

    static func liftSetText(
        weightKilograms: Double,
        unit: UnitSystem,
        repetitions: Int,
        includeRepLabel: Bool = false,
        format: (Double) -> String = RankingCalculator.format
    ) -> String {
        let repLabel = includeRepLabel ? " \(repetitions == 1 ? "rep" : "reps")" : ""
        return "\(formatDisplayedWeight(weightKilograms, unit: unit, format: format)) × \(repetitions)\(repLabel)"
    }

    static func liftSetTextWithX(
        weightKilograms: Double,
        unit: UnitSystem,
        repetitions: Int,
        includeRepLabel: Bool = false,
        format: (Double) -> String = RankingCalculator.format
    ) -> String {
        let repLabel = includeRepLabel ? " \(repetitions == 1 ? "rep" : "reps")" : ""
        return "\(formatDisplayedWeight(weightKilograms, unit: unit, format: format)) x \(repetitions)\(repLabel)"
    }

    static func workoutSetText(
        set: WorkoutSetLog,
        trackingKind: ExerciseTrackingKind,
        includeRepLabel: Bool = false,
        format: (Double) -> String = RankingCalculator.format
    ) -> String {
        let reps = set.reps ?? 0
        let weight = set.weight ?? 0
        switch trackingKind {
        case .weightReps:
            let repLabel = includeRepLabel ? " \(reps == 1 ? "rep" : "reps")" : ""
            return "\(formatRecordedWeight(weight, unit: set.recordedUnit, format: format)) × \(reps)\(repLabel)"
        case .bodyweightReps, .repsOnly:
            return "\(reps) \(reps == 1 ? "rep" : "reps")"
        case .assistedBodyweight:
            return "\(reps) \(reps == 1 ? "rep" : "reps") @ \(formatRecordedWeight(weight, unit: set.recordedUnit, format: format)) assist"
        case .time:
            return shortClockText(TimeInterval(reps))
        case .weightTime:
            return "\(formatRecordedWeight(weight, unit: set.recordedUnit, format: format)) x \(shortClockText(TimeInterval(reps)))"
        }
    }

    static func bestPRsByReps(
        from points: [ExerciseProgressPoint]
    ) -> [(reps: Int, weight: Double, unit: UnitSystem)] {
        let grouped = Dictionary(grouping: points, by: \.reps)
        return grouped.compactMap { reps, values in
            guard let best = values.max(by: { lhs, rhs in
                let lhsKG = lhs.unit == .kilograms ? lhs.weight : RankingCalculator.poundsToKilograms(lhs.weight)
                let rhsKG = rhs.unit == .kilograms ? rhs.weight : RankingCalculator.poundsToKilograms(rhs.weight)
                return lhsKG < rhsKG
            }) else { return nil }
            return (reps, best.weight, best.unit)
        }
        .sorted { $0.reps < $1.reps }
    }

    static func formatWeight(_ kilograms: Double, format: (Double) -> String = RankingCalculator.format) -> String {
        format(kilograms)
    }

    static func shortDurationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
