import Foundation

struct ExerciseProgressPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let reps: Int
    let unit: UnitSystem
    var workoutID: UUID? = nil
    var targetReps: String? = nil
}

struct RepRangeProgressionSummary: Identifiable, Equatable {
    var id: UUID { workoutID }
    let workoutID: UUID
    let date: Date
    let targetReps: String
    let inRangeSetCount: Int
    let totalSetCount: Int
    let bestInRangeWeight: Double?
}

struct WeeklyPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let day: String
    let count: Int
}

struct HomeWeeklySummary: Equatable {
    let points: [WeeklyPoint]
    let completedWorkoutCount: Int
    let plannedWorkoutCount: Int
    let completedSetCount: Int
    let volume: Double
    let duration: TimeInterval

    var completedTrainingDayCount: Int {
        points.filter { $0.count > 0 }.count
    }
}

struct TrainingRecoverySummary: Equatable {
    let muscle: ExerciseMuscleRegion
    let setCount: Int
    let hoursSinceTraining: Int
}

struct TrainingAttentionInsight: Identifiable {
    let id: String
    let title: String
    let evidence: String
    let nextStep: String
}

struct MuscleTrainingWeek: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let historyStart: Date?
    let counts: [ExerciseMuscleRegion: Int]
    let secondaryCounts: [ExerciseMuscleRegion: Int]
    let trainingDays: [ExerciseMuscleRegion: Int]
    let completedSetCount: Int
    let trainingDayCount: Int

    var hasHistory: Bool { historyStart.map { $0 < weekEnd } ?? false }
    var hasFullHistory: Bool { historyStart.map { $0 <= weekStart } ?? false }
}

struct MuscleTrainingContribution: Identifiable {
    var id: String { "\(workout.id)-\(exercise.id)" }
    let workout: CompletedWorkout
    let exercise: WorkoutExerciseSnapshot
    let sets: [WorkoutSetLog]
    let isPrimary: Bool
    let trackingKind: ExerciseTrackingKind
}

struct CompletedWorkoutPresentation {
    let workout: CompletedWorkout
    let exercises: [WorkoutExerciseSnapshot]
    let completedSetsByExercise: [UUID: [WorkoutSetLog]]
    let trackingKinds: [String: ExerciseTrackingKind]
}

enum ExerciseProgressSeries {
    static func dailyHighestRepetitions(
        from points: [ExerciseProgressPoint],
        calendar: Calendar = .current
    ) -> [ExerciseProgressPoint] {
        Dictionary(grouping: points.filter { $0.reps > 0 }) { calendar.startOfDay(for: $0.date) }
            .compactMap { day, points in
                guard let best = points.max(by: { $0.reps == $1.reps ? $0.date < $1.date : $0.reps < $1.reps }) else { return nil }
                return ExerciseProgressPoint(id: best.id, date: day, weight: 0, reps: best.reps, unit: best.unit, workoutID: best.workoutID)
            }
            .sorted { $0.date < $1.date }
    }

    static func dailyHighest(
        from points: [ExerciseProgressPoint],
        calendar: Calendar = .current
    ) -> [ExerciseProgressPoint] {
        Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
            .compactMap { day, dailyPoints in
                guard let best = dailyPoints.max(by: { lhs, rhs in
                    let lhsKilograms = MeasurementFormatting.normalizeToKilograms(lhs.weight, unit: lhs.unit)
                    let rhsKilograms = MeasurementFormatting.normalizeToKilograms(rhs.weight, unit: rhs.unit)
                    if lhsKilograms == rhsKilograms { return lhs.reps < rhs.reps }
                    return lhsKilograms < rhsKilograms
                }) else { return nil }
                return ExerciseProgressPoint(
                    id: best.id,
                    date: day,
                    weight: best.weight,
                    reps: best.reps,
                    unit: best.unit,
                    workoutID: best.workoutID,
                    targetReps: best.targetReps
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func dailyHighestEstimatedOneRepMax(
        from points: [ExerciseProgressPoint],
        calendar: Calendar = .current
    ) -> [ExerciseProgressPoint] {
        let eligible = points.filter { $0.weight.isFinite && $0.weight > 0 && (1...10).contains($0.reps) }
        return Dictionary(grouping: eligible) { calendar.startOfDay(for: $0.date) }
            .compactMap { day, dailyPoints in
                guard let best = dailyPoints.max(by: { lhs, rhs in
                    estimatedOneRepMax(lhs) < estimatedOneRepMax(rhs)
                }) else { return nil }
                return ExerciseProgressPoint(
                    id: best.id,
                    date: day,
                    weight: best.weight,
                    reps: best.reps,
                    unit: best.unit,
                    workoutID: best.workoutID,
                    targetReps: best.targetReps
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func estimatedOneRepMax(_ point: ExerciseProgressPoint) -> Double {
        let kilograms = MeasurementFormatting.normalizeToKilograms(point.weight, unit: point.unit)
        return RankingCalculator.epleyOneRepMax(weight: kilograms, repetitions: point.reps)
    }

    static func repRangeProgressions(from points: [ExerciseProgressPoint]) -> [RepRangeProgressionSummary] {
        Dictionary(grouping: points.compactMap { point -> (UUID, ExerciseProgressPoint)? in
            guard let workoutID = point.workoutID,
                  let targetReps = point.targetReps,
                  repRangeBounds(targetReps) != nil else { return nil }
            return (workoutID, point)
        }, by: \.0)
        .compactMap { workoutID, entries in
            let reps = Set(entries.compactMap { normalizedRepTarget($0.1.targetReps) })
            guard reps.count == 1,
                  let target = entries.first?.1.targetReps,
                  let bounds = repRangeBounds(target) else { return nil }
            let inRange = entries.map(\.1).filter { (bounds.lower...bounds.upper).contains($0.reps) }
            return RepRangeProgressionSummary(
                workoutID: workoutID,
                date: entries.map(\.1.date).max() ?? .distantPast,
                targetReps: target,
                inRangeSetCount: inRange.count,
                totalSetCount: entries.count,
                bestInRangeWeight: inRange.map(\.weight).max()
            )
        }
        .sorted { $0.date < $1.date }
    }

    private static func normalizedRepTarget(_ target: String?) -> String? {
        target?.replacingOccurrences(of: "–", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func repRangeBounds(_ target: String) -> (lower: Int, upper: Int)? {
        let normalizedTarget = target.replacingOccurrences(of: "–", with: "-")
        let components = normalizedTarget.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count <= 2,
              components.count == 1 || !components[1].trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let bounds = components[0].split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2,
              let lower = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
              let upper = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
              lower > 0, upper >= lower else { return nil }
        return (lower, upper)
    }
}


struct TrainingRecapSummary: Equatable {
    let workoutCount: Int
    let trainingDayCount: Int
    let workingSetCount: Int
    let duration: TimeInterval
    let volumeKilograms: Double
    var exerciseCount: Int = 0
    var exerciseSetCounts: [String: Int] = [:]

    var averageWorkoutDuration: TimeInterval { workoutCount > 0 ? duration / Double(workoutCount) : 0 }
    var averageSetsPerWorkout: Double { workoutCount > 0 ? Double(workingSetCount) / Double(workoutCount) : 0 }
}
