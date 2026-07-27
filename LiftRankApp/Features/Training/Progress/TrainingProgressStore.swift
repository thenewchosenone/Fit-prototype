import Foundation

struct ExerciseProgressPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let reps: Int
    let unit: UnitSystem
}

enum ExerciseProgressSeries {
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
                    unit: best.unit
                )
            }
            .sorted { $0.date < $1.date }
    }
}


@MainActor
final class TrainingProgressStore {
    private let repository: any TrainingProgressRepository
    private let calendar: Calendar
    private var cachedUserID: UUID

    init(
        repository: any TrainingProgressRepository,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.calendar = calendar
        self.cachedUserID = repository.currentProfile.id
    }

    var completedWorkouts: [CompletedWorkout] { repository.completedWorkouts }
    var strengthTierSummary: StrengthTierSummary {
        strengthTierSummary(including: [])
    }

    func strengthTierSummary(including additionalPerformances: [StrengthLiftPerformance]) -> StrengthTierSummary {
        var bestEstimatedMaxByExercise: [String: Double] = [:]
        for workout in repository.completedWorkouts {
            for exercise in workout.exercises where RankingCalculator.strengthTierExerciseIDs.contains(exercise.exerciseID) {
                for set in workout.sets where set.prescriptionID == exercise.id && set.isComplete && !set.isWarmup {
                    guard let weight = set.weight, weight > 0,
                          let repetitions = set.reps, (1...10).contains(repetitions) else { continue }
                    let kilograms = MeasurementFormatting.normalizeToKilograms(weight, unit: set.recordedUnit)
                    let estimatedMax = RankingCalculator.epleyOneRepMax(weight: kilograms, repetitions: repetitions)
                    bestEstimatedMaxByExercise[exercise.exerciseID] = max(
                        bestEstimatedMaxByExercise[exercise.exerciseID] ?? 0,
                        estimatedMax
                    )
                }
            }
        }
        let performances = bestEstimatedMaxByExercise.map {
            StrengthLiftPerformance(exerciseID: $0.key, estimatedOneRepMaxKilograms: $0.value)
        } + additionalPerformances
        return RankingCalculator.strengthTierSummary(
            performances: performances,
            bodyweightKilograms: RankingCalculator.poundsToKilograms(repository.currentProfile.bodyweightPounds),
            sexCategory: repository.currentProfile.sexCategory
        )
    }
    var bodyweightEntries: [BodyweightEntry] {
        resetAccountScopedEntriesIfNeeded()
        return repository.bodyweightEntries
    }
    var strainEntries: [StrainEntry] {
        resetAccountScopedEntriesIfNeeded()
        return repository.strainEntries
    }
    var injuryEntries: [InjuryEntry] {
        resetAccountScopedEntriesIfNeeded()
        return repository.injuryEntries
    }

    func updateBodyweight(_ entry: BodyweightEntry) {
        resetAccountScopedEntriesIfNeeded()
        repository.updateBodyweight(entry)
    }

    func updateStrainEntry(_ entry: StrainEntry) {
        resetAccountScopedEntriesIfNeeded()
        repository.updateStrainEntry(entry)
    }

    func removeStrainEntry(_ entryID: UUID) {
        resetAccountScopedEntriesIfNeeded()
        repository.deleteStrainEntry(entryID)
    }

    func updateInjuryEntry(_ entry: InjuryEntry) {
        resetAccountScopedEntriesIfNeeded()
        repository.updateInjuryEntry(entry)
    }

    func removeInjuryEntry(_ entryID: UUID) {
        resetAccountScopedEntriesIfNeeded()
        repository.deleteInjuryEntry(entryID)
    }

    private func resetAccountScopedEntriesIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        repository.clearTrainingHealthEntries()
    }

    private func trackingKind(for exerciseID: String) -> ExerciseTrackingKind {
        ExerciseTrackingKind(
            repository.trainingExerciseCatalog.first { $0.id == exerciseID }?.trackingType ?? "Weight + Reps"
        )
    }

    func completedPrescriptionCount(for session: WorkoutSession) -> Int {
        let prescriptions = prescriptions(for: session)
        let completedIDs = Set(repository.workoutSetLogs.filter { log in
            log.isComplete && !log.isWarmup && prescriptions.contains { $0.id == log.prescriptionID }
        }.map(\.prescriptionID))
        return completedIDs.count
    }

    func weekCompletion(for week: WorkoutWeek) -> Double {
        let plannedPrescriptions = sessions(for: week).flatMap { prescriptions(for: $0) }
        guard !plannedPrescriptions.isEmpty else { return 0 }
        let completedIDs = Set(repository.workoutSetLogs.filter { log in
            log.isComplete && !log.isWarmup && plannedPrescriptions.contains { $0.id == log.prescriptionID }
        }.map(\.prescriptionID))
        return Double(completedIDs.count) / Double(plannedPrescriptions.count)
    }

    func lastCompletedWorkoutDate() -> Date? {
        repository.completedWorkouts
            .filter { !$0.completedWorkingSets.isEmpty }
            .map(\.completedAt)
            .max()
    }

    func workoutStreak(referenceDate: Date) -> Int {
        let completedDays = Set(
            repository.completedWorkouts
                .filter { !$0.completedWorkingSets.isEmpty }
                .map { calendar.startOfDay(for: $0.completedAt) }
        )
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var cursor: Date
        if completedDays.contains(today) {
            cursor = today
        } else if completedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    func volumeByBodyPart(planID: UUID, preferredUnit: UnitSystem) -> [String: Double] {
        volumeByBodyPart(
            workouts: repository.completedWorkouts.filter { $0.sourcePlanID == nil || $0.sourcePlanID == planID },
            preferredUnit: preferredUnit
        )
    }

    func weeklyVolumeByBodyPart(referenceDate: Date = .now, preferredUnit: UnitSystem) -> [String: Double] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return volumeByBodyPart(workouts: repository.completedWorkouts, preferredUnit: preferredUnit)
        }
        return volumeByBodyPart(
            workouts: repository.completedWorkouts.filter {
                $0.completedAt >= week.start && $0.completedAt < week.end
            },
            preferredUnit: preferredUnit
        )
    }

    private func volumeByBodyPart(workouts: [CompletedWorkout], preferredUnit: UnitSystem) -> [String: Double] {
        var totals: [String: Double] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                guard trackingKind(for: exercise.exerciseID) == .weightReps else { continue }
                let volume = workout.sets
                    .filter { $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup }
                    .reduce(0) { total, set in
                        guard let weight = set.weight, let reps = set.reps else { return total }
                        let displayedWeight: Double
                        if set.recordedUnit == preferredUnit {
                            displayedWeight = weight
                        } else if preferredUnit == .kilograms {
                            displayedWeight = RankingCalculator.poundsToKilograms(weight)
                        } else {
                            displayedWeight = RankingCalculator.kilogramsToPounds(weight)
                        }
                        return total + (displayedWeight * Double(reps))
                    }
                totals[exercise.bodyPart, default: 0] += volume
            }
        }
        return totals
    }

    func weekOptions(planID: UUID) -> [Int] {
        let programWeeks = Set(repository.workoutWeeks.filter { $0.planID == planID }.map(\.weekNumber))
        let legacyWeeks = Set(repository.workoutEntries.filter { $0.planID == planID }.map(\.week))
        return Array(programWeeks.union(legacyWeeks).union([1])).sorted()
    }

    func workoutDays(week: Int, planID: UUID) -> [WorkoutDaySummary] {
        let entries = repository.workoutEntries.filter { $0.planID == planID && $0.week == week }
        let grouped = Dictionary(grouping: entries, by: \.workout)
        return grouped.values.map { entries in
            WorkoutDaySummary(
                day: entries.first?.day ?? "",
                workout: entries.first?.workout ?? "",
                exercises: entries.count,
                completed: entries.filter(\.isDone).count
            )
        }
        .sorted { lhs, rhs in
            let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            return (order.firstIndex(of: lhs.day) ?? 99) < (order.firstIndex(of: rhs.day) ?? 99)
        }
    }

    func strengthBalance(week: Int, planID: UUID) -> StrengthBalance {
        let entries = repository.workoutEntries.filter { $0.planID == planID && $0.week == week && $0.isDone }
        let categories = ["Push", "Pull", "Legs", "Shoulders/Arms", "Core"]
        var volumes = Dictionary(uniqueKeysWithValues: categories.map { ($0, 0.0) })
        for entry in entries {
            volumes[trainingCategory(for: entry), default: 0] += entry.volume
        }
        let nonZero = volumes.values.filter { $0 > 0 }
        let maxVolume = nonZero.max() ?? 1
        let minVolume = nonZero.min() ?? 0
        let score = maxVolume == 0 ? 0 : Int((minVolume / maxVolume) * 100)
        let weakest = volumes.min { $0.value < $1.value }?.key ?? "Core"
        let label = score >= 75 ? "Balanced" : score >= 45 ? "Developing" : "Needs attention"
        return StrengthBalance(score: score, label: label, weakest: weakest, volumes: volumes)
    }

    func exerciseHistory(for exerciseID: String) -> [ExerciseHistoryEntry] {
        let trackingKind = trackingKind(for: exerciseID)
        return repository.completedWorkouts.compactMap { workout -> ExerciseHistoryEntry? in
            let snapshotIDs = Set(workout.exercises.filter { $0.exerciseID == exerciseID }.map(\.id))
            let sets = workout.sets.filter {
                snapshotIDs.contains($0.prescriptionID) && $0.isComplete && !$0.isWarmup
            }
            let normalized = sets.compactMap { set -> (weight: Double, reps: Int, estimatedMax: Double, volume: Double)? in
                guard trackingKind == .weightReps else { return nil }
                guard let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
                let kilograms = set.recordedUnit == .kilograms
                    ? weight
                    : RankingCalculator.poundsToKilograms(weight)
                return (
                    weight: kilograms,
                    reps: reps,
                    estimatedMax: RankingCalculator.epleyOneRepMax(weight: kilograms, repetitions: reps),
                    volume: kilograms * Double(reps)
                )
            }
            guard !sets.isEmpty else { return nil }
            let best = normalized.max { $0.estimatedMax < $1.estimatedMax }
            let bestRepsOrDuration = sets.compactMap(\.reps).max()
            return ExerciseHistoryEntry(
                workout: workout,
                sets: sets,
                bestWeightKilograms: best?.weight,
                bestRepetitions: best?.reps ?? bestRepsOrDuration,
                estimatedOneRepMaxKilograms: best?.estimatedMax,
                sessionVolumeKilograms: normalized.reduce(0) { $0 + $1.volume }
            )
        }
        .sorted { $0.workout.completedAt > $1.workout.completedAt }
    }

    func exerciseRecords(for exerciseID: String) -> ExerciseRecords {
        let trackingKind = trackingKind(for: exerciseID)
        let history = exerciseHistory(for: exerciseID)
        let normalizedSets = history.flatMap(\.sets).compactMap { set -> (weight: Double, reps: Int)? in
            guard trackingKind == .weightReps else { return nil }
            guard let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
            return (set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight), reps)
        }
        let estimatedMaxes = normalizedSets.map {
            RankingCalculator.epleyOneRepMax(weight: $0.weight, repetitions: $0.reps)
        }
        let setVolumes = normalizedSets.map { $0.weight * Double($0.reps) }
        let sessionVolumes = history.map(\.sessionVolumeKilograms).filter { $0 > 0 }
        return ExerciseRecords(
            bestEstimatedOneRepMaxKilograms: estimatedMaxes.max(),
            bestSessionVolumeKilograms: sessionVolumes.max(),
            bestSetVolumeKilograms: setVolumes.max(),
            heaviestWeightKilograms: normalizedSets.map(\.weight).max(),
            mostRepetitions: history.flatMap(\.sets).compactMap(\.reps).max()
        )
    }

    var plateauInsights: [PlateauInsight] {
        var exerciseNames: [String: String] = [:]
        var performancesByExercise: [String: [PlateauPerformance]] = [:]

        for workout in repository.completedWorkouts.sorted(by: { $0.completedAt > $1.completedAt }) {
            for exercise in workout.exercises {
                guard trackingKind(for: exercise.exerciseID) == .weightReps else { continue }
                let sets = workout.sets.filter {
                    $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup
                }
                guard !sets.isEmpty else { continue }
                let normalizedSets = sets.compactMap { set -> (WorkoutSetLog, Double, Int)? in
                    guard let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
                    let kilograms = set.recordedUnit == .kilograms
                        ? weight
                        : RankingCalculator.poundsToKilograms(weight)
                    return (set, kilograms, reps)
                }
                guard let best = normalizedSets.max(by: {
                    RankingCalculator.epleyOneRepMax(weight: $0.1, repetitions: $0.2) <
                        RankingCalculator.epleyOneRepMax(weight: $1.1, repetitions: $1.2)
                }) else { continue }

                let volume = normalizedSets.reduce(0) { $0 + ($1.1 * Double($1.2)) }
                exerciseNames[exercise.exerciseID] = exercise.exerciseName
                performancesByExercise[exercise.exerciseID, default: []].append(
                    PlateauPerformance(
                        id: best.0.id,
                        workoutID: workout.id,
                        performedAt: workout.completedAt,
                        weightKilograms: best.1,
                        repetitions: best.2,
                        estimatedOneRepMaxKilograms: RankingCalculator.epleyOneRepMax(
                            weight: best.1,
                            repetitions: best.2
                        ),
                        volumeKilograms: volume
                    )
                )
            }
        }

        return performancesByExercise.compactMap { exerciseID, performances in
            let recent = Array(performances.sorted { $0.performedAt > $1.performedAt }.prefix(3))
            guard RankingCalculator.isPlateau(performances: recent), let latest = recent.first else { return nil }
            return PlateauInsight(
                id: "\(exerciseID)-\(Int(latest.performedAt.timeIntervalSince1970))",
                exerciseID: exerciseID,
                exerciseName: exerciseNames[exerciseID] ?? "Exercise",
                performances: recent
            )
        }
        .sorted { $0.latestPerformance.performedAt > $1.latestPerformance.performedAt }
    }

    private func sessions(for week: WorkoutWeek) -> [WorkoutSession] {
        repository.workoutSessions
            .filter { $0.weekID == week.id }
            .sorted { $0.order < $1.order }
    }

    private func prescriptions(for session: WorkoutSession) -> [WorkoutExercisePrescription] {
        repository.workoutPrescriptions
            .filter { $0.sessionID == session.id }
            .sorted { $0.order < $1.order }
    }

    private func trainingCategory(for entry: WorkoutExerciseEntry) -> String {
        let text = "\(entry.exercise) \(entry.workout) \(entry.muscleGroup)".lowercased()
        if text.contains("crunch") || text.contains("core") { return "Core" }
        if text.contains("curl") || text.contains("triceps") || text.contains("lateral") || text.contains("shoulder") {
            return "Shoulders/Arms"
        }
        if text.contains("row") || text.contains("pulldown") || text.contains("pull") || text.contains("lat") {
            return "Pull"
        }
        if text.contains("squat") || text.contains("leg") || text.contains("hamstring") ||
            text.contains("glute") || text.contains("deadlift") {
            return "Legs"
        }
        return "Push"
    }
}
