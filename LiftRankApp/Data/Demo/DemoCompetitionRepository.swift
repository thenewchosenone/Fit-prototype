import Foundation

extension DemoRepository {
    func addLift(_ lift: LiftSubmission) {
        var eligibleLift = lift
        if eligibleLift.leaderboardEligibleAt == .distantPast {
            eligibleLift.leaderboardEligibleAt = Self.nextLocalMidnight()
        }
        lifts.insert(eligibleLift, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) logged \(eligibleLift.exerciseName)", detail: "\(RankingCalculator.format(eligibleLift.weight)) \(eligibleLift.unit.shortLabel) × \(eligibleLift.repetitions)", liftID: eligibleLift.id, createdAt: .now, isLiked: false, isSaved: false), at: 0)
        notifications.insert(NotificationItem(id: UUID(), title: "Lift submitted", message: "Your lift will enter eligible rankings at the next daily update.", kind: "Lift submitted", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .lift, targetID: eligibleLift.id)), at: 0)
        refreshAchievementUnlocks()
    }

    private static func nextLocalMidnight(referenceDate: Date = .now) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? referenceDate
    }

    func computedStatistics(referenceDate: Date = .now) -> CompetitiveStatistics {
        let completedWorkingSets = completedWorkouts.flatMap(\.completedWorkingSets)
        return CompetitiveStatistics(
            totalWorkouts: completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }.count,
            lifetimeWorkingSetVolume: completedWorkingSets.reduce(0) { total, log in
                let kilograms = log.recordedUnit == .kilograms ? (log.weight ?? 0) : RankingCalculator.poundsToKilograms(log.weight ?? 0)
                return total + (kilograms * Double(log.reps ?? 0))
            },
            totalActiveTrainingTime: completedWorkouts.reduce(0) { $0 + $1.duration },
            totalWorkingSetRepetitions: completedWorkingSets.reduce(0) { $0 + ($1.reps ?? 0) },
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

    private func completedPRCount() -> Int {
        var seen = Set<String>()
        var count = 0
        for workout in completedWorkouts.sorted(by: { $0.completedAt < $1.completedAt }) {
            for set in workout.completedWorkingSets {
                guard let exercise = workout.exercises.first(where: { $0.id == set.prescriptionID }),
                      let rankingID = exercise.rankingExerciseID,
                      let weight = set.weight,
                      let reps = set.reps else { continue }
                let kilograms = set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
                let key = "\(rankingID)|\(reps)"
                let previous = seen.contains(key) ? maxVerifiedOrCompletedOneRepKilograms(for: rankingID) : nil
                if previous == nil || kilograms > (previous ?? 0) {
                    count += 1
                }
                seen.insert(key)
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
        achievementUnlocks = refreshed.sorted { $0.unlockedAt > $1.unlockedAt }
    }

    private func earnedAchievementTitles() -> [String] {
        let stats = computedStatistics()
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(currentProfile.bodyweightPounds)
        let maxBench = maxVerifiedOrCompletedOneRepKilograms(for: "bench")
        let maxSquat = maxVerifiedOrCompletedOneRepKilograms(for: "squat")
        let maxDeadlift = maxVerifiedOrCompletedOneRepKilograms(for: "deadlift")
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
        add("First Lift Logged", when: !currentUserLifts.isEmpty)
        add("3 Lifts Logged", when: currentUserLifts.count >= 3)
        add("10 Lifts Logged", when: currentUserLifts.count >= 10)
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
        add("Bodyweight Logged", when: bodyweightEntries.contains { $0.actual != nil })
        add("4 Bodyweight Logs", when: bodyweightEntries.filter { $0.actual != nil }.count >= 4)
        add("12 Bodyweight Logs", when: bodyweightEntries.filter { $0.actual != nil }.count >= 12)
        add("18 Bodyweight Logs", when: bodyweightEntries.filter { $0.actual != nil }.count >= 18)
        add("26 Bodyweight Logs", when: bodyweightEntries.filter { $0.actual != nil }.count >= 26)
        add("52 Bodyweight Logs", when: bodyweightEntries.filter { $0.actual != nil }.count >= 52)
        add("3-Day Workout Streak", when: stats.currentStreak >= 3)
        add("7-Day Workout Streak", when: stats.currentStreak >= 7)
        add("14-Day Workout Streak", when: stats.currentStreak >= 14)
        add("30-Day Workout Streak", when: stats.currentStreak >= 30)
        add("60-Day Workout Streak", when: stats.currentStreak >= 60)
        add("90-Day Workout Streak", when: stats.currentStreak >= 90)
        add("180-Day Workout Streak", when: stats.currentStreak >= 180)
        add("365-Day Workout Streak", when: stats.currentStreak >= 365)
        add("10,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 10_000)
        add("50,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 50_000)
        add("100,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 100_000)
        add("250,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 250_000)
        add("500,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 500_000)
        add("1,000,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 1_000_000)
        add("2,500,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 2_500_000)
        add("5,000,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 5_000_000)
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

    private func maxVerifiedOrCompletedOneRepKilograms(for rankingExerciseID: String) -> Double {
        let liftBest = currentUserLifts.filter { $0.exerciseID == rankingExerciseID && $0.repetitions == 1 }.map(\.normalizedWeightKilograms).max() ?? 0
        let workoutBest = completedWorkouts.flatMap { workout in
            workout.completedWorkingSets.compactMap { log -> Double? in
                guard log.reps == 1,
                      let exercise = workout.exercises.first(where: { $0.id == log.prescriptionID }),
                      exercise.rankingExerciseID == rankingExerciseID,
                      let weight = log.weight else { return nil }
                return log.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
            }
        }.max() ?? 0
        return max(liftBest, workoutBest)
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
