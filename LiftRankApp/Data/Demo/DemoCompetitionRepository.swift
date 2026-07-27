import Foundation

extension DemoRepository {
    func addLift(_ lift: LiftSubmission, refreshAchievements: Bool = true) {
        var eligibleLift = lift
        if eligibleLift.leaderboardEligibleAt == .distantPast {
            eligibleLift.leaderboardEligibleAt = Self.nextLocalMidnight()
        }
        lifts.insert(eligibleLift, at: 0)
        notifications.insert(NotificationItem(id: UUID(), title: "Lift submitted", message: "Your lift will enter eligible rankings at the next daily update.", kind: "Lift submitted", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .lift, targetID: eligibleLift.id)), at: 0)
        if refreshAchievements {
            refreshAchievementUnlocks()
        }
    }

    private static func nextLocalMidnight(referenceDate: Date = .now) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? referenceDate
    }

    func computedStatistics(referenceDate: Date = .now) -> CompetitiveStatistics {
        let lifetimeWorkingSetVolume = completedWorkouts.reduce(0.0) { workoutTotal, workout in
            workoutTotal + workout.completedWorkingSets.reduce(0.0) { total, log in
                let trackingKind = trackingKind(for: log, workout: workout)
                guard trackingKind == .weightReps,
                      let weight = log.weight,
                      weight > 0,
                      let reps = log.reps,
                      reps > 0 else { return total }
                let kilograms = log.recordedUnit == .kilograms
                    ? weight
                    : RankingCalculator.poundsToKilograms(weight)
                return total + (kilograms * Double(reps))
            }
        }
        return CompetitiveStatistics(
            totalWorkouts: completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }.count,
            lifetimeWorkingSetVolume: lifetimeWorkingSetVolume,
            totalActiveTrainingTime: completedWorkouts.reduce(0) { $0 + $1.duration },
            totalWorkingSetRepetitions: completedWorkouts.reduce(0) { workoutTotal, workout in
                workoutTotal + workout.completedWorkingSets.reduce(0) { total, log in
                    guard !trackingKind(for: log, workout: workout).usesDuration else { return total }
                    return total + (log.reps ?? 0)
                }
            },
            prCount: completedPRCount(),
            currentStreak: currentWorkoutStreak(referenceDate: referenceDate),
            longestStreak: longestWorkoutStreak(),
            verifiedLiftCount: currentUserLifts.filter(\.verificationStatus.isDefaultLeaderboardEligible).count,
            currentGlobalTotalRank: nil,
            highestGlobalTotalRank: nil,
            currentGymTotalRank: nil,
            highestGymTotalRank: nil
        )
    }

    private func trackingKind(for log: WorkoutSetLog, workout: CompletedWorkout) -> ExerciseTrackingKind {
        guard let exercise = workout.exercises.first(where: { $0.id == log.prescriptionID }) else { return .weightReps }
        let rawTrackingType = exercise.trackingType ??
            trainingExerciseCatalog.first(where: { $0.id == exercise.exerciseID })?.trackingType
        return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps")
    }

    private func completedPRCount() -> Int {
        var bestByKey: [String: Double] = [:]
        var count = 0
        for workout in completedWorkouts.sorted(by: { $0.completedAt < $1.completedAt }) {
            for set in workout.completedWorkingSets {
                guard let exercise = workout.exercises.first(where: { $0.id == set.prescriptionID }),
                      let rankingID = exercise.rankingExerciseID,
                      let weight = set.weight,
                      let reps = set.reps else { continue }
                let kilograms = set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
                let key = "\(rankingID)|\(reps)"
                if kilograms > (bestByKey[key] ?? 0) {
                    count += 1
                    bestByKey[key] = kilograms
                }
            }
        }
        return count
    }

    private func currentWorkoutStreak(referenceDate: Date = .now) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }.map { calendar.startOfDay(for: $0.completedAt) })
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
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func longestWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = completedWorkouts
            .filter { !$0.completedWorkingSets.isEmpty }
            .map { calendar.startOfDay(for: $0.completedAt) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if delta == 0 { continue }
            if delta == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    func refreshAchievementUnlocks(now: Date = .now) {
        let existingByTitle = Dictionary(uniqueKeysWithValues: achievementUnlocks.map { ($0.title, $0) })
        var refreshed: [AchievementUnlock] = []
        for title in earnedAchievementTitles() {
            refreshed.append(existingByTitle[title] ?? AchievementUnlock(
                id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: title,
                unlockedAt: now
            ))
        }
        let sortedUnlocks = refreshed.sorted { $0.unlockedAt > $1.unlockedAt }
        if achievementUnlocks != sortedUnlocks {
            achievementUnlocks = sortedUnlocks
        }
    }

    private func earnedAchievementTitles() -> [String] {
        let stats = computedStatistics()
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
        let userLifts = currentUserLifts
        let strengthMaxes = verifiedOrCompletedOneRepKilogramsByExercise(userLifts: userLifts)
        let maxBench = strengthMaxes["bench"] ?? 0
        let maxSquat = strengthMaxes["squat"] ?? 0
        let maxDeadlift = strengthMaxes["deadlift"] ?? 0
        let powerliftingTotal = maxBench + maxSquat + maxDeadlift
        var titles: [String] = []
        func add(_ title: String, when condition: Bool) { if condition { titles.append(title) } }
        add("First Workout", when: stats.totalWorkouts >= 1)
        add("2 Workouts", when: stats.totalWorkouts >= 2)
        add("3 Workouts", when: stats.totalWorkouts >= 3)
        add("5 Workouts", when: stats.totalWorkouts >= 5)
        add("10 Workouts", when: stats.totalWorkouts >= 10)
        add("25 Workouts", when: stats.totalWorkouts >= 25)
        add("50 Workouts", when: stats.totalWorkouts >= 50)
        add("75 Workouts", when: stats.totalWorkouts >= 75)
        add("100 Workouts", when: stats.totalWorkouts >= 100)
        add("200 Workouts", when: stats.totalWorkouts >= 200)
        add("300 Workouts", when: stats.totalWorkouts >= 300)
        add("500 Workouts", when: stats.totalWorkouts >= 500)
        add("1,000 Workouts", when: stats.totalWorkouts >= 1_000)
        add("First Lift Logged", when: !userLifts.isEmpty)
        add("3 Lifts Logged", when: userLifts.count >= 3)
        add("10 Lifts Logged", when: userLifts.count >= 10)
        add("First Verified Lift", when: stats.verifiedLiftCount >= 1)
        add("Five Verified Lifts", when: stats.verifiedLiftCount >= 5)
        add("Ten Verified Lifts", when: stats.verifiedLiftCount >= 10)
        add("25 Verified Lifts", when: stats.verifiedLiftCount >= 25)
        add("50 Verified Lifts", when: stats.verifiedLiftCount >= 50)
        add("100 Verified Lifts", when: stats.verifiedLiftCount >= 100)
        add("First PR", when: stats.prCount >= 1)
        add("5 PRs", when: stats.prCount >= 5)
        add("10 PRs", when: stats.prCount >= 10)
        add("25 PRs", when: stats.prCount >= 25)
        add("50 PRs", when: stats.prCount >= 50)
        add("100 PRs", when: stats.prCount >= 100)
        add("1,000 Reps", when: stats.totalWorkingSetRepetitions >= 1_000)
        add("5,000 Reps", when: stats.totalWorkingSetRepetitions >= 5_000)
        add("10,000 Reps", when: stats.totalWorkingSetRepetitions >= 10_000)
        add("15,000 Reps", when: stats.totalWorkingSetRepetitions >= 15_000)
        add("25,000 Reps", when: stats.totalWorkingSetRepetitions >= 25_000)
        add("50,000 Reps", when: stats.totalWorkingSetRepetitions >= 50_000)
        add("100,000 Reps", when: stats.totalWorkingSetRepetitions >= 100_000)
        add("10 Training Hours", when: stats.totalActiveTrainingTime >= 10 * 60 * 60)
        add("50 Training Hours", when: stats.totalActiveTrainingTime >= 50 * 60 * 60)
        add("100 Training Hours", when: stats.totalActiveTrainingTime >= 100 * 60 * 60)
        add("150 Training Hours", when: stats.totalActiveTrainingTime >= 150 * 60 * 60)
        add("250 Training Hours", when: stats.totalActiveTrainingTime >= 250 * 60 * 60)
        add("500 Training Hours", when: stats.totalActiveTrainingTime >= 500 * 60 * 60)
        add("1,000 Training Hours", when: stats.totalActiveTrainingTime >= 1_000 * 60 * 60)
        add("135 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(135))
        add("185 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(185))
        add("225 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(225))
        add("315 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(315))
        add("405 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(405))
        add("500 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(500))
        add("225 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(225))
        add("315 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(315))
        add("405 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(405))
        add("500 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(500))
        add("600 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(600))
        add("315 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(315))
        add("405 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(405))
        add("500 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(500))
        add("600 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(600))
        add("700 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(700))
        add("500 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(500))
        add("750 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(750))
        add("1,000 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(1_000))
        add("1,250 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(1_250))
        add("1,500 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(1_500))
        add("2,000 lb Total", when: powerliftingTotal >= RankingCalculator.poundsToKilograms(2_000))
        add("Bodyweight Bench", when: maxBench >= bodyweightKilograms)
        add("1.5x Bodyweight Bench", when: maxBench >= bodyweightKilograms * 1.5)
        add("1.5x Bodyweight Squat", when: maxSquat >= bodyweightKilograms * 1.5)
        add("2x Bodyweight Squat", when: maxSquat >= bodyweightKilograms * 2)
        add("2x Bodyweight Deadlift", when: maxDeadlift >= bodyweightKilograms * 2)
        add("2.5x Bodyweight Deadlift", when: maxDeadlift >= bodyweightKilograms * 2.5)
        let strengthTier = RankingCalculator.strengthTierSummary(
            performances: RankingCalculator.strengthPerformances(from: completedWorkouts),
            bodyweightKilograms: bodyweightKilograms,
            sexCategory: currentProfile.sexCategory
        ).overallTier
        for tier in StrengthTier.allCases where tier != .unranked && tier <= strengthTier {
            add("\(tier.label) Rival", when: true)
        }
        let actualBodyweightEntryCount = bodyweightEntries.reduce(0) { count, entry in
            count + (entry.actual == nil ? 0 : 1)
        }
        add("Bodyweight Logged", when: actualBodyweightEntryCount >= 1)
        add("4 Bodyweight Logs", when: actualBodyweightEntryCount >= 4)
        add("12 Bodyweight Logs", when: actualBodyweightEntryCount >= 12)
        add("18 Bodyweight Logs", when: actualBodyweightEntryCount >= 18)
        add("26 Bodyweight Logs", when: actualBodyweightEntryCount >= 26)
        add("52 Bodyweight Logs", when: actualBodyweightEntryCount >= 52)
        add("3-Day Workout Streak", when: stats.currentStreak >= 3)
        add("7-Day Workout Streak", when: stats.currentStreak >= 7)
        add("14-Day Workout Streak", when: stats.currentStreak >= 14)
        add("30-Day Workout Streak", when: stats.currentStreak >= 30)
        add("60-Day Workout Streak", when: stats.currentStreak >= 60)
        add("90-Day Workout Streak", when: stats.currentStreak >= 90)
        add("180-Day Workout Streak", when: stats.currentStreak >= 180)
        add("365-Day Workout Streak", when: stats.currentStreak >= 365)
        add("10,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 10_000)
        add("50,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 50_000)
        add("100,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 100_000)
        add("250,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 250_000)
        add("500,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 500_000)
        add("1,000,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 1_000_000)
        add("2,500,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 2_500_000)
        add("5,000,000 kg Lifted Volume", when: stats.lifetimeWorkingSetVolume >= 5_000_000)
        add("Global Top 100", when: stats.highestGlobalTotalRank.map { $0 <= 100 } == true)
        add("Global Top 50", when: stats.highestGlobalTotalRank.map { $0 <= 50 } == true)
        add("Global Top 10", when: stats.highestGlobalTotalRank.map { $0 <= 10 } == true)
        add("Gym Top 10", when: stats.highestGymTotalRank.map { $0 <= 10 } == true)
        add("Gym Record Holder", when: stats.highestGymTotalRank == 1)
        add("Global Number One", when: stats.highestGlobalTotalRank == 1)
        add("90-Day Improvement Leader", when: stats.biggestRealDailyRankingJump >= 25)
        add("Profile Complete", when: isProfileComplete())
        return titles
    }

    private func verifiedOrCompletedOneRepKilogramsByExercise(userLifts: [LiftSubmission]) -> [String: Double] {
        let trackedExerciseIDs: Set<String> = ["bench", "squat", "deadlift"]
        var bestByExercise: [String: Double] = [:]
        for lift in userLifts where lift.repetitions == 1 && trackedExerciseIDs.contains(lift.exerciseID) {
            bestByExercise[lift.exerciseID] = max(bestByExercise[lift.exerciseID] ?? 0, lift.normalizedWeightKilograms)
        }
        for workout in completedWorkouts {
            let exerciseByID = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
            for log in workout.completedWorkingSets {
                guard log.reps == 1,
                      let exercise = exerciseByID[log.prescriptionID],
                      let rankingExerciseID = exercise.rankingExerciseID,
                      trackedExerciseIDs.contains(rankingExerciseID),
                      let weight = log.weight else { continue }
                let kilograms = log.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
                bestByExercise[rankingExerciseID] = max(bestByExercise[rankingExerciseID] ?? 0, kilograms)
            }
        }
        return bestByExercise
    }

    private var currentUserLifts: [LiftSubmission] {
        lifts.filter { $0.userID == currentProfile.id }
    }

    private func isProfileComplete() -> Bool {
        !currentProfile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
