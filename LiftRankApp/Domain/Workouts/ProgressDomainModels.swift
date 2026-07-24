import Foundation

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
