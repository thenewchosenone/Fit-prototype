import Foundation

enum RankingFormatting {
    static func ratioText(_ value: Double) -> String {
        String(format: "%.2fx", value)
    }

    static func scoreText(for entry: LeaderboardEntry, rankingType: RankingType) -> String {
        leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: .pounds)
    }

    static func weightClassDisplayName(_ weightClass: WeightClass, preferredUnit: UnitSystem) -> String {
        guard preferredUnit == .pounds else { return weightClass.name }
        if let maximum = weightClass.maxKilograms {
            return "\(RankingCalculator.format(RankingCalculator.usaplPoundEquivalent(maximum))) lb (\(weightClass.name))"
        }
        let lower = RankingCalculator.usaplPoundEquivalent(weightClass.minKilograms ?? 0)
        return "\(RankingCalculator.format(lower))+ lb (\(weightClass.name))"
    }

    static func bodyweightInLbText(_ pounds: Double) -> String {
        "\(Int(pounds)) lb BW"
    }

    static func leaderboardValueText(
        for entry: LeaderboardEntry,
        rankingType: RankingType,
        preferredUnit: UnitSystem
    ) -> String {
        switch rankingType {
        case .absolute:
            let value = MeasurementFormatting.convert(entry.score, from: .kilograms, to: preferredUnit)
            return "\(RankingCalculator.format(value)) \(preferredUnit.shortLabel)"
        case .poundForPound:
            return ratioText(entry.score)
        case .total:
            let value = MeasurementFormatting.convert(entry.score, from: .kilograms, to: preferredUnit)
            return "\(RankingCalculator.format(value)) \(preferredUnit.shortLabel)"
        case .relativeTotal:
            return ratioText(entry.score)
        case .mostImproved:
            return "\(entry.score >= 0 ? "+" : "")\(RankingCalculator.format(entry.score))%"
        }
    }
}
