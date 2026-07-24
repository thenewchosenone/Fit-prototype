import Foundation
import SwiftUI

enum RankingFormatting {
    static func strengthTier(for score: Double) -> (label: String, tint: Color) {
        switch score {
        case 80...:
            return ("Elite", .liftGold)
        case 60..<80:
            return ("Advanced", .liftGreen)
        case 35..<60:
            return ("Intermediate", .liftBlue)
        case 15..<35:
            return ("Novice", .liftPurple)
        default:
            return ("Beginner", .liftMuted)
        }
    }

    static func earnedExperienceLevel(relativeTotal: Double, verifiedLiftCount: Int) -> ExperienceLevel {
        guard verifiedLiftCount > 0, relativeTotal > 0 else { return .beginner }
        switch relativeTotal {
        case 5.0...:
            return .veteran
        case 4.0..<5.0:
            return .advanced
        case 3.0..<4.0:
            return .intermediate
        case 2.0..<3.0:
            return .novice
        default:
            return .beginner
        }
    }

    static func earnedExperienceDescription(relativeTotal: Double, verifiedLiftCount: Int) -> String {
        guard verifiedLiftCount > 0 else { return "Submit verified lifts to earn a level" }
        return "\(verifiedLiftCount) verified \(verifiedLiftCount == 1 ? "lift" : "lifts") • \(ratioText(relativeTotal)) total"
    }

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

    static func leaderboardRankText(rank: Int?) -> String {
        guard let rank else { return "Unranked" }
        return "#\(rank)"
    }

    static func threeLiftTotalText(totalPounds: Double, preferredUnit: UnitSystem) -> String {
        let displayValue = MeasurementFormatting.convert(totalPounds, from: .pounds, to: preferredUnit)
        return "\(RankingCalculator.format(displayValue)) \(preferredUnit.shortLabel)"
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
