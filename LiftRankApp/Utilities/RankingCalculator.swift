import Foundation

enum RankingCalculator {
    static let poundsPerKilogram = 2.2046226218

    static func epleyOneRepMax(weight: Double, repetitions: Int) -> Double {
        guard repetitions > 1 else { return weight }
        return weight * (1.0 + Double(repetitions) / 30.0)
    }

    static func poundsToKilograms(_ pounds: Double) -> Double {
        pounds / poundsPerKilogram
    }

    static func kilogramsToPounds(_ kilograms: Double) -> Double {
        kilograms * poundsPerKilogram
    }

    static func usaplPoundEquivalent(_ kilograms: Double) -> Double {
        floor(kilogramsToPounds(kilograms) * 5) / 5
    }

    static func bodyweightMultiple(oneRepMax: Double, bodyweight: Double) -> Double {
        guard bodyweight > 0 else { return 0 }
        return oneRepMax / bodyweight
    }

    static func powerliftingTotal(bench: Double?, squat: Double?, deadlift: Double?) -> Double {
        (bench ?? 0) + (squat ?? 0) + (deadlift ?? 0)
    }

    static func relativeTotal(total: Double, bodyweight: Double) -> Double {
        guard bodyweight > 0 else { return 0 }
        return total / bodyweight
    }

    static func progressPercentage(currentPersonalRecord: Double, previousPersonalRecord: Double) -> Double {
        guard previousPersonalRecord > 0 else { return 0 }
        return ((currentPersonalRecord - previousPersonalRecord) / previousPersonalRecord) * 100
    }

    static func isPlateau(
        performances: [PlateauPerformance],
        requiredWorkouts: Int = 3,
        improvementThreshold: Double = 0.01
    ) -> Bool {
        guard requiredWorkouts >= 2, performances.count >= requiredWorkouts else { return false }
        let recent = Array(performances.sorted { $0.performedAt > $1.performedAt }.prefix(requiredWorkouts))
        guard let oldest = recent.last,
              oldest.estimatedOneRepMaxKilograms > 0,
              oldest.volumeKilograms > 0 else { return false }

        let newer = recent.dropLast()
        let strengthCeiling = oldest.estimatedOneRepMaxKilograms * (1 + improvementThreshold)
        let volumeCeiling = oldest.volumeKilograms * (1 + improvementThreshold)
        let strengthImproved = newer.contains { $0.estimatedOneRepMaxKilograms > strengthCeiling }
        let volumeImproved = newer.contains { $0.volumeKilograms > volumeCeiling }
        return !strengthImproved && !volumeImproved
    }

    static func weightClass(for bodyweight: Double, sexCategory: SexCategory, classes: [WeightClass]) -> WeightClass? {
        let bodyweightKilograms = poundsToKilograms(bodyweight)
        return classes.first { weightClass in
            weightClass.sexCategory == sexCategory &&
            (weightClass.minKilograms == nil || bodyweightKilograms > weightClass.minKilograms!) &&
            (weightClass.maxKilograms == nil || bodyweightKilograms <= weightClass.maxKilograms!)
        }
    }

    static func bestLift(exerciseID: String, submissions: [LiftSubmission]) -> LiftSubmission? {
        submissions
            .filter { $0.exerciseID == exerciseID }
            .max { $0.estimatedOneRepMax < $1.estimatedOneRepMax }
    }

    static func bestSubmittedLift(exerciseID: String, repetitions: Int? = nil, submissions: [LiftSubmission]) -> LiftSubmission? {
        submissions
            .filter { lift in
                lift.exerciseID == exerciseID && (repetitions == nil || lift.repetitions == repetitions)
            }
            .max { $0.normalizedWeightKilograms < $1.normalizedWeightKilograms }
    }

    static func powerliftingBreakdown(for userID: UUID, lifts: [LiftSubmission]) -> PowerliftingBreakdown {
        let userOneRepLifts = lifts.filter { $0.userID == userID && $0.repetitions == 1 }
        return PowerliftingBreakdown(
            squatKilograms: bestSubmittedLift(exerciseID: "squat", repetitions: 1, submissions: userOneRepLifts)?.normalizedWeightKilograms,
            benchKilograms: bestSubmittedLift(exerciseID: "bench", repetitions: 1, submissions: userOneRepLifts)?.normalizedWeightKilograms,
            deadliftKilograms: bestSubmittedLift(exerciseID: "deadlift", repetitions: 1, submissions: userOneRepLifts)?.normalizedWeightKilograms
        )
    }

    static func overallScore(relativeStrength: Double, absoluteStrength: Double, recentProgress: Double) -> Double {
        (relativeStrength * 0.5) + (absoluteStrength * 0.3) + (recentProgress * 0.2)
    }

    static func leaderboardEntries(
        profiles: [UserProfile],
        lifts: [LiftSubmission],
        rankingType: RankingType,
        verifiedOnly: Bool,
        currentUserID: UUID?,
        exerciseID: String? = nil
    ) -> [LeaderboardEntry] {
        let eligibleLifts = lifts.filter { lift in
            guard lift.visibility == .publicLift,
                  lift.repetitions == 1,
                  lift.isActualOneRepMax,
                  lift.resolvedModerationStatus != .rejected else { return false }
            if verifiedOnly {
                return lift.competitiveMovement == nil
                    ? lift.verificationStatus.isDefaultLeaderboardEligible
                    : lift.resolvedEvidenceStatus == .videoBacked
            }
            return true
        }

        let grouped = Dictionary(grouping: eligibleLifts, by: \.userID)
        let candidates: [(lift: LiftSubmission, score: Double, breakdown: PowerliftingBreakdown?)] = grouped.compactMap { userID, userLifts in
            if exerciseID == nil && (rankingType == .total || rankingType == .relativeTotal) {
                let breakdown = powerliftingBreakdown(for: userID, lifts: userLifts)
                guard breakdown.totalKilograms > 0,
                      let representative = userLifts
                        .filter({ $0.repetitions == 1 && ["squat", "bench", "deadlift"].contains($0.exerciseID) })
                        .max(by: { $0.normalizedWeightKilograms < $1.normalizedWeightKilograms }) else { return nil }
                let score = rankingType == .total
                    ? breakdown.totalKilograms
                    : relativeTotal(total: breakdown.totalKilograms, bodyweight: poundsToKilograms(representative.bodyweightAtLift))
                return (representative, score, breakdown)
            }

            guard let representative = userLifts.max(by: {
                score(for: $0, rankingType: rankingType, allLifts: userLifts) <
                score(for: $1, rankingType: rankingType, allLifts: userLifts)
            }) else { return nil }
            return (representative, score(for: representative, rankingType: rankingType, allLifts: userLifts), nil)
        }

        let profileByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                if lhs.lift.performedAt == rhs.lift.performedAt {
                    return lhs.lift.userID.uuidString < rhs.lift.userID.uuidString
                }
                return lhs.lift.performedAt < rhs.lift.performedAt
            }
            return lhs.score > rhs.score
        }

        var entries: [LeaderboardEntry] = []
        var previousScore: Double?
        var displayedRank = 0

        for (index, candidate) in sorted.enumerated() {
            let lift = candidate.lift
            guard let profile = profileByID[lift.userID] else { continue }
            let entryScore = candidate.score
            if previousScore == nil || entryScore != previousScore {
                displayedRank = index + 1
            }
            previousScore = entryScore
            let movementSeed = abs(profile.username.hashValue % 7) - 3
            entries.append(
                LeaderboardEntry(
                    rank: displayedRank,
                    profile: profile,
                    lift: lift,
                    rankMovement: lift.userID == currentUserID ? 3 : movementSeed,
                    score: entryScore,
                    powerliftingBreakdown: candidate.breakdown
                )
            )
        }
        return entries
    }

    static func score(for lift: LiftSubmission, rankingType: RankingType, allLifts: [LiftSubmission]) -> Double {
        switch rankingType {
        case .absolute:
            return lift.normalizedWeightKilograms
        case .poundForPound:
            return lift.normalizedWeightKilograms / max(1, poundsToKilograms(lift.bodyweightAtLift))
        case .total:
            return totalForUser(lift.userID, lifts: allLifts)
        case .relativeTotal:
            let total = totalForUser(lift.userID, lifts: allLifts)
            return relativeTotal(total: total, bodyweight: lift.bodyweightAtLift)
        case .mostImproved:
            let earlier = allLifts
                .filter { $0.exerciseID == lift.exerciseID && $0.performedAt < lift.performedAt }
                .map(\.normalizedWeightKilograms)
                .max() ?? lift.normalizedWeightKilograms
            return progressPercentage(currentPersonalRecord: lift.normalizedWeightKilograms, previousPersonalRecord: earlier)
        }
    }

    static func totalForUser(_ userID: UUID, lifts: [LiftSubmission]) -> Double {
        kilogramsToPounds(powerliftingBreakdown(for: userID, lifts: lifts).totalKilograms)
    }

    static func plateLoading(for totalWeight: Double, unit: UnitSystem) -> [(label: String, count: Int)] {
        let barWeight = unit == .pounds ? 45.0 : 20.0
        let plates = unit == .pounds ? [45.0, 35.0, 25.0, 10.0, 5.0, 2.5] : [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
        var sideWeight = max(0, (totalWeight - barWeight) / 2.0)
        var result: [(String, Int)] = []
        for plate in plates {
            let count = Int(sideWeight / plate)
            if count > 0 {
                result.append(("\(format(plate)) \(unit.shortLabel)", count))
                sideWeight -= Double(count) * plate
            }
        }
        return result
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
