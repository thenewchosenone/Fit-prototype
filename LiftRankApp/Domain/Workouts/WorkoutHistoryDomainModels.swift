import Foundation
import SwiftData

struct LegacyWorkoutRecordValue: Hashable {
    var id: UUID
    var exercise: String
    var workout: String
    var weight: Double
    var reps: Int
    var rpe: Int
    var performedAt: Date
}

struct WorkoutSummary: Identifiable, Hashable {
    var id: UUID
    var sessionID: UUID
    var workoutName: String
    var completedExercises: Int
    var totalExercises: Int
    var totalSets: Int
    var totalVolume: Double
    var bestSet: WorkoutSetLog?
}

struct WorkoutFeedback: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var completedAt: Date
    var effort: Int
    var notes: String
}

struct WorkoutExerciseEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var week: Int
    var date: Date
    var day: String
    var workout: String
    var exercise: String
    var muscleGroup: String
    var targetSets: Int
    var targetReps: String
    var sets: [WorkoutSetEntry]
    var isDone: Bool
    var notes: String

    var bestSet: WorkoutSetEntry? {
        sets.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

    var volume: Double {
        sets.reduce(0) { total, set in
            total + ((set.weight ?? 0) * Double(set.reps ?? 0))
        }
    }

    var estimatedMax: Double {
        guard let bestSet, let weight = bestSet.weight else { return 0 }
        return RankingCalculator.epleyOneRepMax(weight: weight, repetitions: bestSet.reps ?? 1)
    }
}

@Model
final class PersistentLiftRecord {
    var id: UUID
    var exerciseID: String
    var exerciseName: String
    var weight: Double
    var repetitions: Int
    var performedAt: Date

    init(id: UUID, exerciseID: String, exerciseName: String, weight: Double, repetitions: Int, performedAt: Date) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.weight = weight
        self.repetitions = repetitions
        self.performedAt = performedAt
    }
}

@Model
final class PersistentSettings {
    var id: UUID
    var preferredUnitRawValue: String
    var privateProfile: Bool
    var hideBodyweight: Bool
    var hideExactAge: Bool
    var hideLocation: Bool
    var allowComments: Bool

    init() {
        id = UUID()
        preferredUnitRawValue = UnitSystem.pounds.rawValue
        privateProfile = false
        hideBodyweight = false
        hideExactAge = false
        hideLocation = false
        allowComments = true
    }
}

@Model
final class PersistentWorkoutRecord {
    var id: UUID
    var exercise: String
    var workout: String
    var weight: Double
    var reps: Int
    var rpe: Int
    var performedAt: Date

    init(id: UUID, exercise: String, workout: String, weight: Double, reps: Int, rpe: Int, performedAt: Date) {
        self.id = id
        self.exercise = exercise
        self.workout = workout
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
    }
}

@Model
final class PersistentWorkoutState {
    var id: UUID
    var schemaVersion: Int
    var updatedAt: Date
    var payload: Data

    init(
        id: UUID = UUID(uuidString: "A9000000-0000-0000-0000-000000000001")!,
        schemaVersion: Int,
        updatedAt: Date = .now,
        payload: Data
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
