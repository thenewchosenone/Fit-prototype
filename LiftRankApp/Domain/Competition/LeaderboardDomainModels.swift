import Foundation

enum RankingType: String, Codable, CaseIterable, Identifiable {
    case absolute = "Absolute"
    case poundForPound = "Pound-for-pound"
    case total = "Total"
    case relativeTotal = "Relative total"
    case mostImproved = "Most improved"
    var id: String { rawValue }
}

struct LeaderboardEntry: Identifiable, Hashable {
    var id: UUID { lift.id }
    let rank: Int
    let profile: UserProfile
    let lift: LiftSubmission
    let rankMovement: Int
    let score: Double
    let powerliftingBreakdown: PowerliftingBreakdown?
}

struct PowerliftingBreakdown: Hashable {
    let squatKilograms: Double?
    let benchKilograms: Double?
    let deadliftKilograms: Double?

    var totalKilograms: Double {
        (squatKilograms ?? 0) + (benchKilograms ?? 0) + (deadliftKilograms ?? 0)
    }
}

struct LeaderboardFilters: Hashable {
    var exerciseID: String?
    var rankingType: RankingType = .total
    var repetitionCount: Int?
    var sexCategory: SexCategory?
    var ageGroup: String?
    var weightClassID: String?
    var experienceLevel: ExperienceLevel?
    var gymID: UUID?
    var city: String?
    var state: String?
    var country: String?
    var verificationLevel: VerificationStatus?
    var timeRange: String = "All time"
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var symbolName: String
}

struct CompetitiveStatistics: Codable, Hashable {
    var totalWorkouts: Int = 0
    var lifetimeWorkingSetVolume: Double = 0
    var totalActiveTrainingTime: TimeInterval = 0
    var totalWorkingSetRepetitions: Int = 0
    var prCount: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var verifiedLiftCount: Int = 0
    var currentGlobalTotalRank: Int?
    var highestGlobalTotalRank: Int?
    var currentGymTotalRank: Int?
    var highestGymTotalRank: Int?
    var daysAtNumberOne: Int = 0
    var weeksAtNumberOne: Int = 0
    var biggestRealDailyRankingJump: Int = 0
    var topTenDailyFinishes: Int = 0
    var topHundredDailyFinishes: Int = 0
}

struct AchievementDefinition: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbolName: String
}

struct AchievementUnlock: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let unlockedAt: Date
}

struct RankingHistorySnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let capturedAt: Date
    let globalTotalRank: Int?
    let gymTotalRank: Int?
}
