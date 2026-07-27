import Foundation

enum StrengthTier: Int, CaseIterable, Codable, Comparable, Hashable {
    case unranked
    case novice
    case beginner
    case intermediate
    case advanced
    case elite
    case legend

    static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .unranked: "Unranked"
        case .novice: "Novice"
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .elite: "Elite"
        case .legend: "Legend"
        }
    }
}

struct StrengthTierStandard: Hashable {
    let tier: StrengthTier
    let exerciseID: String
    let sexCategory: SexCategory
    let bodyweightMultiple: Double
}

struct StrengthLiftPerformance: Hashable {
    let exerciseID: String
    let estimatedOneRepMaxKilograms: Double
}

struct LiftTierProgress: Identifiable, Hashable {
    var id: String { exerciseID }
    let exerciseID: String
    let exerciseName: String
    let estimatedOneRepMaxKilograms: Double?
    let bodyweightMultiple: Double
    let currentTier: StrengthTier
    let nextTier: StrengthTier?
    let progressToNextTier: Double
    let nextThresholdMultiple: Double?
}

struct StrengthTierSummary: Hashable {
    let overallTier: StrengthTier
    let liftProgress: [LiftTierProgress]

    var completedRequiredLiftCount: Int {
        liftProgress.filter { $0.estimatedOneRepMaxKilograms != nil }.count
    }

    var requiredLiftCount: Int { liftProgress.count }

    var nextTier: StrengthTier? {
        StrengthTier.allCases.first { $0 > overallTier }
    }
}

struct PlateauPerformance: Identifiable, Hashable {
    var id: UUID
    var workoutID: UUID
    var performedAt: Date
    var weightKilograms: Double
    var repetitions: Int
    var estimatedOneRepMaxKilograms: Double
    var volumeKilograms: Double
}

struct PlateauInsight: Identifiable, Hashable {
    var id: String
    var exerciseID: String
    var exerciseName: String
    var performances: [PlateauPerformance]

    var latestPerformance: PlateauPerformance { performances[0] }
}

struct ExerciseHistoryEntry: Identifiable, Hashable {
    var id: UUID { workout.id }
    var workout: CompletedWorkout
    var sets: [WorkoutSetLog]
    var bestWeightKilograms: Double?
    var bestRepetitions: Int?
    var estimatedOneRepMaxKilograms: Double?
    var sessionVolumeKilograms: Double
}

struct ExerciseRecords: Hashable {
    var bestEstimatedOneRepMaxKilograms: Double?
    var bestSessionVolumeKilograms: Double?
    var bestSetVolumeKilograms: Double?
    var heaviestWeightKilograms: Double?
    var mostRepetitions: Int?
}

struct WorkoutCompletionInsights: Hashable {
    var volumeDelta: Double
    var volumeDeltaPercent: Double?
    var setDelta: Int
    var durationDelta: TimeInterval
    var improvedExerciseNames: [String]
    var projectedStatistics: CompetitiveStatistics
    var newlyUnlockedAchievements: [AchievementUnlock]
}
