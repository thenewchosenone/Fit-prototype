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

struct CompletedWorkoutPresentation {
    let workout: CompletedWorkout
    let exercises: [WorkoutExerciseSnapshot]
    let completedSetsByExercise: [UUID: [WorkoutSetLog]]
    let trackingKinds: [String: ExerciseTrackingKind]
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
        Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
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


@MainActor
final class TrainingProgressStore {
    private let repository: any TrainingProgressRepository
    private let calendar: Calendar
    private var cachedUserID: UUID
    private var cachedStrengthTierSummary: StrengthTierSummary?
    private var cachedStrengthTierSignature: StrengthTierSignature?
    private var cachedWorkoutStreak: Int?
    private var cachedWorkoutStreakSignature: WorkoutStreakSignature?
    private var cachedHomeWeeklySummary: HomeWeeklySummary?
    private var cachedHomeWeeklySummarySignature: HomeWeeklySummarySignature?
    private var cachedWeeklyVolumeByBodyPart: [String: Double]?
    private var cachedWeeklyVolumeByBodyPartSignature: WeeklyVolumeByBodyPartSignature?
    private var cachedExerciseHistory: [ExerciseHistoryEntry]?
    private var cachedExerciseHistorySignature: ExerciseHistorySignature?
    private var cachedExerciseProgressPoints: [ExerciseProgressPoint]?
    private var cachedExerciseProgressPointsSignature: ExerciseProgressPointsSignature?
    private var cachedExerciseRecords: ExerciseRecords?
    private var cachedExerciseRecordsSignature: ExerciseHistorySignature?
    private var cachedProgressExerciseOptions: [TrainingExerciseCatalogItem]?
    private var cachedProgressExerciseOptionsSignature: ProgressExerciseOptionsSignature?
    private var cachedPreviousComparableWorkout: CompletedWorkout?
    private var cachedPreviousComparableWorkoutSignature: PreviousComparableWorkoutSignature?
    private var cachedPlateauInsights: [PlateauInsight]?
    private var cachedPlateauInsightsSignature: WorkoutHistorySignature?
    private var cachedRecoverySummaries: [TrainingRecoverySummary]?
    private var cachedRecoverySummariesSignature: RecoverySummariesSignature?
    private var cachedWeekCompletion: Double?
    private var cachedWeekCompletionSignature: WeekCompletionSignature?
    private var cachedWorkoutHistoryIndex: WorkoutHistoryIndex?
    private var cachedWorkoutHistoryRevision: Int?
    private var cachedWorkoutHistoryPresentation: WorkoutHistoryCalendarPresentation?
    private var cachedWorkoutHistoryPresentationSignature: WorkoutHistoryPresentationSignature?
    private var cachedCompletedWorkoutPresentation: CompletedWorkoutPresentation?
    private var cachedCompletedWorkoutPresentationSignature: CompletedWorkoutPresentationSignature?

    init(
        repository: any TrainingProgressRepository,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.calendar = calendar
        self.cachedUserID = repository.currentProfile.id
    }

    var completedWorkouts: [CompletedWorkout] { repository.completedWorkouts }

    func previousComparableWorkout(sessionID: UUID, workoutName: String) -> CompletedWorkout? {
        resetAccountScopedEntriesIfNeeded()
        let signature = PreviousComparableWorkoutSignature(
            accountID: repository.currentProfile.id,
            sessionID: sessionID,
            workoutName: workoutName,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if cachedPreviousComparableWorkoutSignature == signature {
            return cachedPreviousComparableWorkout
        }
        let workout = repository.completedWorkouts.first {
            $0.sourceSessionID == sessionID || $0.name == workoutName
        }
        cachedPreviousComparableWorkout = workout
        cachedPreviousComparableWorkoutSignature = signature
        return workout
    }

    func progressExerciseOptions(
        catalog: [TrainingExerciseCatalogItem],
        customTrainingExercisesRevision: Int
    ) -> [TrainingExerciseCatalogItem] {
        resetAccountScopedEntriesIfNeeded()
        let signature = ProgressExerciseOptionsSignature(
            accountID: repository.currentProfile.id,
            completedWorkoutsRevision: repository.completedWorkoutsRevision,
            customTrainingExercisesRevision: customTrainingExercisesRevision
        )
        if let cachedProgressExerciseOptions,
           cachedProgressExerciseOptionsSignature == signature {
            return cachedProgressExerciseOptions
        }
        let exerciseIDs = Set(repository.completedWorkouts.flatMap { $0.exercises.map(\.exerciseID) })
        let options = catalog
            .filter { exerciseIDs.contains($0.id) && ExerciseTrackingKind($0.trackingType) == .weightReps }
            .sorted { $0.name < $1.name }
        cachedProgressExerciseOptions = options
        cachedProgressExerciseOptionsSignature = signature
        return options
    }

    var strengthTierSummary: StrengthTierSummary {
        strengthTierSummary(including: [])
    }

    func strengthTierSummary(including additionalPerformances: [StrengthLiftPerformance]) -> StrengthTierSummary {
        let signature = StrengthTierSignature(
            completedWorkoutsRevision: repository.completedWorkoutsRevision,
            profile: repository.currentProfile,
            additionalPerformances: additionalPerformances
        )
        if let cachedStrengthTierSummary, cachedStrengthTierSignature == signature {
            return cachedStrengthTierSummary
        }
        let summary = calculateStrengthTierSummary(including: additionalPerformances)
        cachedStrengthTierSignature = signature
        cachedStrengthTierSummary = summary
        return summary
    }

    private func calculateStrengthTierSummary(including additionalPerformances: [StrengthLiftPerformance]) -> StrengthTierSummary {
        let performances = RankingCalculator.strengthPerformances(from: repository.completedWorkouts) + additionalPerformances
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

    private func resetAccountScopedEntriesIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        cachedStrengthTierSummary = nil
        cachedStrengthTierSignature = nil
        cachedWorkoutStreak = nil
        cachedWorkoutStreakSignature = nil
        cachedHomeWeeklySummary = nil
        cachedHomeWeeklySummarySignature = nil
        cachedWeeklyVolumeByBodyPart = nil
        cachedWeeklyVolumeByBodyPartSignature = nil
        cachedExerciseHistory = nil
        cachedExerciseHistorySignature = nil
        cachedExerciseProgressPoints = nil
        cachedExerciseProgressPointsSignature = nil
        cachedExerciseRecords = nil
        cachedExerciseRecordsSignature = nil
        cachedProgressExerciseOptions = nil
        cachedProgressExerciseOptionsSignature = nil
        cachedPreviousComparableWorkout = nil
        cachedPreviousComparableWorkoutSignature = nil
        cachedPlateauInsights = nil
        cachedPlateauInsightsSignature = nil
        cachedRecoverySummaries = nil
        cachedRecoverySummariesSignature = nil
        cachedWeekCompletion = nil
        cachedWeekCompletionSignature = nil
        cachedWorkoutHistoryIndex = nil
        cachedWorkoutHistoryRevision = nil
        cachedWorkoutHistoryPresentation = nil
        cachedWorkoutHistoryPresentationSignature = nil
        cachedCompletedWorkoutPresentation = nil
        cachedCompletedWorkoutPresentationSignature = nil
        repository.clearTrainingHealthEntries()
    }

    func completedWorkoutPresentation(
        for workoutID: UUID,
        fallback: CompletedWorkout,
        catalog: [TrainingExerciseCatalogItem],
        customTrainingExercisesRevision: Int
    ) -> CompletedWorkoutPresentation {
        let signature = CompletedWorkoutPresentationSignature(
            workoutID: workoutID,
            accountID: repository.currentProfile.id,
            completedWorkoutsRevision: repository.completedWorkoutsRevision,
            customTrainingExercisesRevision: customTrainingExercisesRevision
        )
        if let cachedCompletedWorkoutPresentation,
           cachedCompletedWorkoutPresentationSignature == signature {
            return cachedCompletedWorkoutPresentation
        }

        let workout = repository.completedWorkouts.first { $0.id == workoutID } ?? fallback
        let exercises = workout.exercises.sorted { $0.order < $1.order }
        let completedSetsByExercise = Dictionary(
            grouping: workout.sets.filter(\.isComplete),
            by: \.prescriptionID
        ).mapValues { $0.sorted { $0.setNumber < $1.setNumber } }
        let exerciseIDs = Set(exercises.map(\.exerciseID))
        let trackingKinds = Dictionary(uniqueKeysWithValues: catalog.lazy
            .filter { exerciseIDs.contains($0.id) }
            .map { ($0.id, ExerciseTrackingKind($0.trackingType)) })
        let presentation = CompletedWorkoutPresentation(
            workout: workout,
            exercises: exercises,
            completedSetsByExercise: completedSetsByExercise,
            trackingKinds: trackingKinds
        )
        cachedCompletedWorkoutPresentationSignature = signature
        cachedCompletedWorkoutPresentation = presentation
        return presentation
    }

    var trainingHistoryWorkouts: [CompletedWorkout] {
        workoutHistoryIndex().workouts
    }

    func workoutHistoryPresentation(
        displayedMonth: Date,
        selectedDate: Date?,
        referenceDate: Date = .now
    ) -> WorkoutHistoryCalendarPresentation {
        let displayedMonth = WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
        let currentMonth = WorkoutHistoryCalendarData.monthStart(for: referenceDate, calendar: calendar)
        let selectedDay = selectedDate.map(calendar.startOfDay)
        let signature = WorkoutHistoryPresentationSignature(
            displayedMonth: displayedMonth,
            selectedDay: selectedDay,
            currentMonth: currentMonth,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedWorkoutHistoryPresentation,
           cachedWorkoutHistoryPresentationSignature == signature {
            return cachedWorkoutHistoryPresentation
        }

        let index = workoutHistoryIndex()
        let earliestBrowsableMonth = calendar.date(byAdding: .year, value: -120, to: currentMonth) ?? currentMonth
        let latestBrowsableMonth = calendar.date(byAdding: .year, value: 120, to: currentMonth) ?? currentMonth
        let presentation = WorkoutHistoryCalendarPresentation(
            workoutCount: index.workouts.count,
            currentMonth: currentMonth,
            firstBrowsableMonth: earliestBrowsableMonth,
            lastBrowsableMonth: latestBrowsableMonth,
            calendarDays: WorkoutHistoryCalendarData.days(
                in: displayedMonth,
                workoutCountsByDay: index.workoutCountsByDay,
                calendar: calendar
            ),
            selectedWorkouts: selectedDay.flatMap { index.workoutsByDay[$0] } ?? [],
            mostRecentWorkoutDateByMonth: index.mostRecentWorkoutDateByMonth
        )
        cachedWorkoutHistoryPresentation = presentation
        cachedWorkoutHistoryPresentationSignature = signature
        return presentation
    }

    private func workoutHistoryIndex() -> WorkoutHistoryIndex {
        let revision = repository.completedWorkoutsRevision
        if let cachedWorkoutHistoryIndex, cachedWorkoutHistoryRevision == revision {
            return cachedWorkoutHistoryIndex
        }
        let index = WorkoutHistoryIndex(
            workouts: repository.completedWorkouts.filter { !$0.completedWorkingSets.isEmpty },
            calendar: calendar
        )
        cachedWorkoutHistoryIndex = index
        cachedWorkoutHistoryRevision = revision
        cachedWorkoutHistoryPresentation = nil
        cachedWorkoutHistoryPresentationSignature = nil
        return index
    }

    func recoverySummaries(referenceDate: Date = .now) -> [TrainingRecoverySummary] {
        let referenceMinute = calendar.dateInterval(of: .minute, for: referenceDate)?.start ?? referenceDate
        let signature = RecoverySummariesSignature(
            referenceMinute: referenceMinute,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedRecoverySummaries,
           cachedRecoverySummariesSignature == signature {
            return cachedRecoverySummaries
        }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        var workingSets: [ExerciseMuscleRegion: (lastTrained: Date, setCount: Int)] = [:]

        for workout in repository.completedWorkouts where workout.completedAt >= weekAgo {
            let workingSetCounts = Dictionary(
                grouping: workout.sets.lazy.filter { $0.isComplete && !$0.isWarmup },
                by: \.prescriptionID
            ).mapValues(\.count)
            for exercise in workout.exercises {
                let count = workingSetCounts[exercise.id] ?? 0
                guard count > 0 else { continue }

                for muscle in exercise.muscleProfile?.primary ?? [] {
                    let existing = workingSets[muscle]
                    workingSets[muscle] = (
                        max(existing?.lastTrained ?? workout.completedAt, workout.completedAt),
                        (existing?.setCount ?? 0) + count
                    )
                }
            }
        }

        let summaries = workingSets.map { muscle, entry in
            TrainingRecoverySummary(
                muscle: muscle,
                setCount: entry.setCount,
                hoursSinceTraining: max(0, Int(referenceDate.timeIntervalSince(entry.lastTrained) / 3_600))
            )
        }
        .sorted {
            if $0.hoursSinceTraining == $1.hoursSinceTraining {
                return $0.setCount > $1.setCount
            }
            return $0.hoursSinceTraining < $1.hoursSinceTraining
        }

        cachedRecoverySummaries = summaries
        cachedRecoverySummariesSignature = signature
        return summaries
    }

    private func trackingKind(for exerciseID: String) -> ExerciseTrackingKind {
        ExerciseTrackingKind(
            repository.trainingExerciseCatalog.first { $0.id == exerciseID }?.trackingType ?? "Weight + Reps"
        )
    }

    func completedPrescriptionCount(for session: WorkoutSession) -> Int {
        let prescriptionIDs = Set(prescriptions(for: session).map(\.id))
        let completedIDs = completedPrescriptionIDs(
            for: [session.id],
            within: prescriptionIDs
        )
        return completedIDs.count
    }

    func weekCompletion(for week: WorkoutWeek) -> Double {
        resetAccountScopedEntriesIfNeeded()
        let signature = WeekCompletionSignature(
            weekID: week.id,
            accountID: repository.currentProfile.id,
            programDataRevision: repository.programDataRevision,
            workoutSetLogsRevision: repository.workoutSetLogsRevision,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedWeekCompletion,
           cachedWeekCompletionSignature == signature {
            return cachedWeekCompletion
        }
        let weekSessions = sessions(for: week)
        let plannedPrescriptionIDs = Set(weekSessions.flatMap { prescriptions(for: $0).map(\.id) })
        guard !plannedPrescriptionIDs.isEmpty else {
            cachedWeekCompletion = 0
            cachedWeekCompletionSignature = signature
            return 0
        }
        let sessionIDs = Set(weekSessions.map(\.id))
        let completedIDs = completedPrescriptionIDs(for: sessionIDs, within: plannedPrescriptionIDs)
        let completion = Double(completedIDs.count) / Double(plannedPrescriptionIDs.count)
        cachedWeekCompletion = completion
        cachedWeekCompletionSignature = signature
        return completion
    }

    private func completedPrescriptionIDs(for sessionIDs: Set<UUID>, within plannedPrescriptionIDs: Set<UUID>) -> Set<UUID> {
        var completedIDs = Set(repository.workoutSetLogs.compactMap { log in
            log.isComplete && !log.isWarmup && plannedPrescriptionIDs.contains(log.prescriptionID)
                ? log.prescriptionID
                : nil
        })
        for workout in repository.completedWorkouts where workout.sourceSessionID.map(sessionIDs.contains) == true {
            let completedExerciseIDs = Set(workout.completedWorkingSets.map(\.prescriptionID))
            completedIDs.formUnion(
                workout.exercises.compactMap { exercise in
                    guard completedExerciseIDs.contains(exercise.id),
                          let sourcePrescriptionID = exercise.sourcePrescriptionID,
                          plannedPrescriptionIDs.contains(sourcePrescriptionID) else {
                        return nil
                    }
                    return sourcePrescriptionID
                }
            )
        }
        return completedIDs
    }

    func lastCompletedWorkoutDate() -> Date? {
        repository.completedWorkouts
            .filter { !$0.completedWorkingSets.isEmpty }
            .map(\.completedAt)
            .max()
    }

    func workoutStreak(referenceDate: Date) -> Int {
        let signature = WorkoutStreakSignature(
            referenceDay: calendar.startOfDay(for: referenceDate),
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedWorkoutStreak,
           cachedWorkoutStreakSignature == signature {
            return cachedWorkoutStreak
        }

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
            cachedWorkoutStreakSignature = signature
            cachedWorkoutStreak = 0
            return 0
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        cachedWorkoutStreakSignature = signature
        cachedWorkoutStreak = streak
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
        let signature = WeeklyVolumeByBodyPartSignature(
            week: week,
            preferredUnit: preferredUnit,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedWeeklyVolumeByBodyPart,
           cachedWeeklyVolumeByBodyPartSignature == signature {
            return cachedWeeklyVolumeByBodyPart
        }
        let volume = volumeByBodyPart(
            workouts: repository.completedWorkouts.filter {
                $0.completedAt >= week.start && $0.completedAt < week.end
            },
            preferredUnit: preferredUnit
        )
        cachedWeeklyVolumeByBodyPart = volume
        cachedWeeklyVolumeByBodyPartSignature = signature
        return volume
    }

    func weeklyWorkingSetsByMuscle(
        referenceDate: Date = .now,
        weekCount: Int = 4
    ) -> [(weekStart: Date, counts: [ExerciseMuscleRegion: Int])] {
        guard weekCount > 0,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return [] }

        return (0..<weekCount).reversed().compactMap { offset in
            guard let weekStart = calendar.date(
                byAdding: .weekOfYear,
                value: -offset,
                to: currentWeek.start
            ), let week = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { return nil }

            var totals: [ExerciseMuscleRegion: Int] = [:]
            for workout in repository.completedWorkouts where week.contains(workout.completedAt) {
            let countsByExercise = Dictionary(
                grouping: workout.sets.lazy.filter { $0.isComplete && !$0.isWarmup },
                by: { $0.prescriptionID }
            ).mapValues { $0.count }

                for exercise in workout.exercises {
                    let count = countsByExercise[exercise.id] ?? 0
                    guard count > 0 else { continue }
                    let profile = exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(
                        name: exercise.exerciseName,
                        bodyPart: exercise.bodyPart
                    )
                    for muscle in Set(profile.primary) {
                        totals[muscle, default: 0] += count
                    }
                }
            }

            return (weekStart, totals)
        }
    }

    func homeWeeklySummary(
        referenceDate: Date = .now,
        currentWeek: WorkoutWeek?,
        preferredUnit: UnitSystem
    ) -> HomeWeeklySummary {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return HomeWeeklySummary(points: [], completedWorkoutCount: 0, plannedWorkoutCount: 0, completedSetCount: 0, volume: 0, duration: 0)
        }

        let signature = HomeWeeklySummarySignature(
            week: interval,
            preferredUnit: preferredUnit,
            currentWeekID: currentWeek?.id,
            programDataRevision: repository.programDataRevision,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedHomeWeeklySummary, cachedHomeWeeklySummarySignature == signature {
            return cachedHomeWeeklySummary
        }

        let completedWorkouts = repository.completedWorkouts.filter {
            interval.contains($0.completedAt) && !$0.completedWorkingSets.isEmpty
        }
        let symbols = WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar)
        let points = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: interval.start) ?? interval.start
            let symbol = symbols.indices.contains(offset) ? symbols[offset] : ""
            let count = completedWorkouts.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }.count
            return WeeklyPoint(date: date, day: symbol, count: count)
        }
        let sets = completedWorkouts.flatMap(\.completedWorkingSets)
        let trackingKindsByExerciseID = Dictionary(uniqueKeysWithValues: repository.trainingExerciseCatalog.map {
            ($0.id, ExerciseTrackingKind($0.trackingType))
        })
        let volume = completedWorkouts.reduce(0.0) { total, workout in
            let exerciseIDsByPrescriptionID = Dictionary(uniqueKeysWithValues: workout.exercises.map {
                ($0.id, $0.exerciseID)
            })
            let workoutVolume = workout.completedWorkingSets.reduce(0.0) { subtotal, set in
                guard let exerciseID = exerciseIDsByPrescriptionID[set.prescriptionID],
                      (trackingKindsByExerciseID[exerciseID] ?? .weightReps) == .weightReps,
                      let weight = set.weight,
                      let reps = set.reps else { return subtotal }
                let displayedWeight = MeasurementFormatting.convert(weight, from: set.recordedUnit, to: preferredUnit)
                return subtotal + displayedWeight * Double(reps)
            }
            return total + workoutVolume
        }
        let summary = HomeWeeklySummary(
            points: points,
            completedWorkoutCount: completedWorkouts.count,
            plannedWorkoutCount: currentWeek.map { week in repository.workoutSessions.filter { $0.weekID == week.id }.count } ?? 0,
            completedSetCount: sets.count,
            volume: volume,
            duration: completedWorkouts.reduce(0) { $0 + $1.duration }
        )
        cachedHomeWeeklySummary = summary
        cachedHomeWeeklySummarySignature = signature
        return summary
    }

    private func volumeByBodyPart(workouts: [CompletedWorkout], preferredUnit: UnitSystem) -> [String: Double] {
        var totals: [String: Double] = [:]
        let trackingKindsByExerciseID = Dictionary(uniqueKeysWithValues: repository.trainingExerciseCatalog.map {
            ($0.id, ExerciseTrackingKind($0.trackingType))
        })
        for workout in workouts {
            let workingSetsByExercise = Dictionary(
                grouping: workout.sets.lazy.filter { $0.isComplete && !$0.isWarmup },
                by: \.prescriptionID
            )
            for exercise in workout.exercises {
                guard (trackingKindsByExerciseID[exercise.exerciseID] ?? .weightReps) == .weightReps else { continue }
                let volume = (workingSetsByExercise[exercise.id] ?? []).reduce(0) { total, set in
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
                let profile = exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(
                    name: exercise.exerciseName,
                    bodyPart: exercise.bodyPart
                )
                let muscleGroup = profile.primary.map(\.displayName).sorted().joined(separator: ", ")
                totals[muscleGroup.isEmpty ? exercise.bodyPart : muscleGroup, default: 0] += volume
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
        let signature = ExerciseHistorySignature(
            userID: repository.currentProfile.id,
            exerciseID: exerciseID,
            trackingKind: trackingKind,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedExerciseHistory, cachedExerciseHistorySignature == signature {
            return cachedExerciseHistory
        }
        let history = repository.completedWorkouts.compactMap { workout -> ExerciseHistoryEntry? in
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
        cachedExerciseHistorySignature = signature
        cachedExerciseHistory = history
        return history
    }

    func exerciseProgressPoints(for exerciseID: String, preferredUnit: UnitSystem) -> [ExerciseProgressPoint] {
        let signature = ExerciseProgressPointsSignature(
            userID: repository.currentProfile.id,
            exerciseID: exerciseID,
            preferredUnit: preferredUnit,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedExerciseProgressPoints,
           cachedExerciseProgressPointsSignature == signature {
            return cachedExerciseProgressPoints
        }
        let points = WorkoutProgressPresentation.progressPoints(
            from: repository.completedWorkouts,
            exerciseID: exerciseID,
            preferredUnit: preferredUnit
        )
        cachedExerciseProgressPointsSignature = signature
        cachedExerciseProgressPoints = points
        return points
    }

    func exerciseRecords(for exerciseID: String) -> ExerciseRecords {
        let trackingKind = trackingKind(for: exerciseID)
        let signature = ExerciseHistorySignature(
            userID: repository.currentProfile.id,
            exerciseID: exerciseID,
            trackingKind: trackingKind,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedExerciseRecords, cachedExerciseRecordsSignature == signature {
            return cachedExerciseRecords
        }
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
        let records = ExerciseRecords(
            bestEstimatedOneRepMaxKilograms: estimatedMaxes.max(),
            bestSessionVolumeKilograms: sessionVolumes.max(),
            bestSetVolumeKilograms: setVolumes.max(),
            heaviestWeightKilograms: normalizedSets.map(\.weight).max(),
            mostRepetitions: history.flatMap(\.sets).compactMap(\.reps).max()
        )
        cachedExerciseRecordsSignature = signature
        cachedExerciseRecords = records
        return records
    }

    var plateauInsights: [PlateauInsight] {
        let signature = WorkoutHistorySignature(
            userID: repository.currentProfile.id,
            completedWorkoutsRevision: repository.completedWorkoutsRevision
        )
        if let cachedPlateauInsights, cachedPlateauInsightsSignature == signature {
            return cachedPlateauInsights
        }
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

        let insights: [PlateauInsight] = performancesByExercise.compactMap { exerciseID, performances in
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
        cachedPlateauInsightsSignature = signature
        cachedPlateauInsights = insights
        return insights
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

private struct StrengthTierSignature: Equatable {
    let bodyweightPounds: Double
    let sexCategory: SexCategory
    let completedWorkoutsRevision: Int
    let additionalPerformances: [StrengthLiftPerformance]

    init(
        completedWorkoutsRevision: Int,
        profile: UserProfile,
        additionalPerformances: [StrengthLiftPerformance]
    ) {
        bodyweightPounds = profile.bodyweightPounds
        sexCategory = profile.sexCategory
        self.completedWorkoutsRevision = completedWorkoutsRevision
        self.additionalPerformances = additionalPerformances
    }
}

private struct WorkoutStreakSignature: Equatable {
    let referenceDay: Date
    let completedWorkoutsRevision: Int

    init(referenceDay: Date, completedWorkoutsRevision: Int) {
        self.referenceDay = referenceDay
        self.completedWorkoutsRevision = completedWorkoutsRevision
    }
}

private struct ExerciseHistorySignature: Equatable {
    let userID: UUID
    let exerciseID: String
    let trackingKind: ExerciseTrackingKind
    let completedWorkoutsRevision: Int
}

private struct ExerciseProgressPointsSignature: Equatable {
    let userID: UUID
    let exerciseID: String
    let preferredUnit: UnitSystem
    let completedWorkoutsRevision: Int
}

private struct WorkoutHistorySignature: Equatable {
    let userID: UUID
    let completedWorkoutsRevision: Int
}

private struct ProgressExerciseOptionsSignature: Equatable {
    let accountID: UUID
    let completedWorkoutsRevision: Int
    let customTrainingExercisesRevision: Int
}

private struct PreviousComparableWorkoutSignature: Equatable {
    let accountID: UUID
    let sessionID: UUID
    let workoutName: String
    let completedWorkoutsRevision: Int
}

private struct WorkoutHistoryPresentationSignature: Equatable {
    let displayedMonth: Date
    let selectedDay: Date?
    let currentMonth: Date
    let completedWorkoutsRevision: Int
}

private struct CompletedWorkoutPresentationSignature: Equatable {
    let workoutID: UUID
    let accountID: UUID
    let completedWorkoutsRevision: Int
    let customTrainingExercisesRevision: Int
}

private struct WorkoutHistoryIndex {
    let workouts: [CompletedWorkout]
    let workoutCountsByDay: [Date: Int]
    let workoutsByDay: [Date: [CompletedWorkout]]
    let mostRecentWorkoutDateByMonth: [Date: Date]
    let earliestMonth: Date?
    let latestMonth: Date?

    init(workouts: [CompletedWorkout], calendar: Calendar) {
        self.workouts = workouts
        let workoutsByDay = Dictionary(grouping: workouts) {
            calendar.startOfDay(for: $0.completedAt)
        }.mapValues { workouts in
            workouts.sorted { $0.completedAt > $1.completedAt }
        }
        self.workoutsByDay = workoutsByDay
        workoutCountsByDay = workoutsByDay.mapValues(\.count)

        var mostRecentWorkoutDateByMonth: [Date: Date] = [:]
        for workout in workouts {
            let month = WorkoutHistoryCalendarData.monthStart(for: workout.completedAt, calendar: calendar)
            mostRecentWorkoutDateByMonth[month] = max(
                mostRecentWorkoutDateByMonth[month] ?? workout.completedAt,
                workout.completedAt
            )
        }
        self.mostRecentWorkoutDateByMonth = mostRecentWorkoutDateByMonth
        earliestMonth = workouts.map(\.completedAt).min().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        }
        latestMonth = workouts.map(\.completedAt).max().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        }
    }
}

private struct RecoverySummariesSignature: Equatable {
    let referenceMinute: Date
    let completedWorkoutsRevision: Int
}

private struct WeekCompletionSignature: Equatable {
    let weekID: UUID
    let accountID: UUID
    let programDataRevision: Int
    let workoutSetLogsRevision: Int
    let completedWorkoutsRevision: Int
}

private struct WeeklyVolumeByBodyPartSignature: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let preferredUnit: UnitSystem
    let completedWorkoutsRevision: Int

    init(
        week: DateInterval,
        preferredUnit: UnitSystem,
        completedWorkoutsRevision: Int
    ) {
        self.weekStart = week.start
        self.weekEnd = week.end
        self.preferredUnit = preferredUnit
        self.completedWorkoutsRevision = completedWorkoutsRevision
    }
}

private struct HomeWeeklySummarySignature: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let preferredUnit: UnitSystem
    let currentWeekID: UUID?
    private let programDataRevision: Int
    private let completedWorkoutsRevision: Int

    init(
        week: DateInterval,
        preferredUnit: UnitSystem,
        currentWeekID: UUID?,
        programDataRevision: Int,
        completedWorkoutsRevision: Int
    ) {
        self.weekStart = week.start
        self.weekEnd = week.end
        self.preferredUnit = preferredUnit
        self.currentWeekID = currentWeekID
        self.programDataRevision = programDataRevision
        self.completedWorkoutsRevision = completedWorkoutsRevision
    }
}
