import Foundation

enum WorkoutPRDetector {
    static func candidates(
        workoutID: UUID,
        exercises: [WorkoutExerciseSnapshot],
        sets: [WorkoutSetLog],
        existingLifts: [LiftSubmission],
        completedWorkouts: [CompletedWorkout],
        excludingCompletedWorkoutID: UUID?
    ) -> [WorkoutPRCandidate] {
        let exerciseByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let eligibleSets = sets.compactMap { log -> EligibleSet? in
            guard log.isComplete,
                  !log.isWarmup,
                  let weight = log.weight,
                  let repetitions = log.reps,
                  repetitions > 0,
                  let exercise = exerciseByID[log.prescriptionID],
                  trackingKind(for: exercise) == .weightReps,
                  let rankingExerciseID = exercise.rankingExerciseID else {
                return nil
            }
            return EligibleSet(
                log: log,
                exercise: exercise,
                rankingExerciseID: rankingExerciseID,
                repetitions: repetitions,
                weightKilograms: normalizedKilograms(weight: weight, unit: log.recordedUnit)
            )
        }

        let groupedSets = Dictionary(grouping: eligibleSets) {
            PRKey(rankingExerciseID: $0.rankingExerciseID, repetitions: $0.repetitions)
        }

        return groupedSets.values.compactMap { group in
            guard let best = group.max(by: { $0.weightKilograms < $1.weightKilograms }) else {
                return nil
            }
            let previousBest = previousBestKilograms(
                rankingExerciseID: best.rankingExerciseID,
                repetitions: best.repetitions,
                existingLifts: existingLifts,
                completedWorkouts: completedWorkouts,
                excludingCompletedWorkoutID: excludingCompletedWorkoutID
            )
            guard best.weightKilograms > (previousBest ?? 0) else { return nil }

            return WorkoutPRCandidate(
                completedWorkoutID: workoutID,
                setID: best.log.id,
                exerciseSnapshotID: best.exercise.id,
                rankingExerciseID: best.rankingExerciseID,
                exerciseName: best.exercise.exerciseName,
                weight: best.log.weight ?? 0,
                repetitions: best.repetitions,
                unit: best.log.recordedUnit,
                previousBestKilograms: previousBest
            )
        }
        .sorted { $0.exerciseName < $1.exerciseName }
    }

    private static func previousBestKilograms(
        rankingExerciseID: String,
        repetitions: Int,
        existingLifts: [LiftSubmission],
        completedWorkouts: [CompletedWorkout],
        excludingCompletedWorkoutID: UUID?
    ) -> Double? {
        var values = existingLifts
            .filter { $0.exerciseID == rankingExerciseID && $0.repetitions == repetitions }
            .map(\.normalizedWeightKilograms)

        for workout in completedWorkouts where workout.id != excludingCompletedWorkoutID {
            let exerciseIDs = Set(
                workout.exercises
                    .filter { $0.rankingExerciseID == rankingExerciseID }
                    .map(\.id)
            )
            values += workout.sets.compactMap { log in
                guard let exercise = workout.exercises.first(where: { $0.id == log.prescriptionID }),
                      trackingKind(for: exercise) == .weightReps,
                      exerciseIDs.contains(log.prescriptionID),
                      log.isComplete,
                      !log.isWarmup,
                      log.reps == repetitions,
                      let weight = log.weight else {
                    return nil
                }
                return normalizedKilograms(weight: weight, unit: log.recordedUnit)
            }
        }
        return values.max()
    }

    private static func trackingKind(for exercise: WorkoutExerciseSnapshot) -> ExerciseTrackingKind {
        ExerciseTrackingKind(
            exercise.trackingType ??
                MockData.trainingExerciseLibrary.first { $0.id == exercise.exerciseID }?.trackingType ??
                "Weight + Reps"
        )
    }

    private static func normalizedKilograms(weight: Double, unit: UnitSystem) -> Double {
        unit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
    }

    private struct PRKey: Hashable {
        var rankingExerciseID: String
        var repetitions: Int
    }

    private struct EligibleSet {
        var log: WorkoutSetLog
        var exercise: WorkoutExerciseSnapshot
        var rankingExerciseID: String
        var repetitions: Int
        var weightKilograms: Double
    }
}

enum WorkoutProgressPresentation {
    static func progressPoints(
        from completedWorkouts: [CompletedWorkout],
        exerciseID: String,
        preferredUnit: UnitSystem
    ) -> [ExerciseProgressPoint] {
        completedWorkouts.flatMap { workout -> [ExerciseProgressPoint] in
            let matchingIDs = Set(workout.exercises.compactMap { exercise -> UUID? in
                guard exercise.exerciseID == exerciseID else { return nil }
                let rawTrackingType = exercise.trackingType ??
                    MockData.trainingExerciseLibrary.first { $0.id == exercise.exerciseID }?.trackingType
                return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps") == .weightReps ? exercise.id : nil
            })
            return workout.sets.compactMap { set in
                guard matchingIDs.contains(set.prescriptionID),
                      set.isComplete,
                      !set.isWarmup,
                      let weight = set.weight,
                      let reps = set.reps else { return nil }

                return ExerciseProgressPoint(
                    id: set.id,
                    date: workout.completedAt,
                    weight: MeasurementFormatting.convert(weight, from: set.recordedUnit, to: preferredUnit),
                    reps: reps,
                    unit: preferredUnit
                )
            }
        }
        .sorted { $0.date < $1.date }
    }
}
