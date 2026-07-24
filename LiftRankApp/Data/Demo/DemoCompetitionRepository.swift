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
            verifiedLiftCount: lifts.filter(\.verificationStatus.isDefaultLeaderboardEligible).count,
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
        var titles: [String] = []
        func add(_ title: String, when condition: Bool) { if condition { titles.append(title) } }
        add("First Workout", when: stats.totalWorkouts >= 1)
        add("10 Workouts", when: stats.totalWorkouts >= 10)
        add("50 Workouts", when: stats.totalWorkouts >= 50)
        add("100 Workouts", when: stats.totalWorkouts >= 100)
        add("First Lift Logged", when: !lifts.isEmpty)
        add("First Verified Lift", when: stats.verifiedLiftCount >= 1)
        add("Ten Verified Lifts", when: stats.verifiedLiftCount >= 10)
        add("First PR", when: stats.prCount >= 1)
        add("10 PRs", when: stats.prCount >= 10)
        add("25 PRs", when: stats.prCount >= 25)
        add("135 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(135))
        add("225 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(225))
        add("315 Bench", when: maxBench >= RankingCalculator.poundsToKilograms(315))
        add("225 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(225))
        add("315 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(315))
        add("405 Squat", when: maxSquat >= RankingCalculator.poundsToKilograms(405))
        add("315 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(315))
        add("405 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(405))
        add("500 Deadlift", when: maxDeadlift >= RankingCalculator.poundsToKilograms(500))
        add("Bodyweight Bench", when: maxBench >= bodyweightKilograms)
        add("1.5x Bodyweight Squat", when: maxSquat >= bodyweightKilograms * 1.5)
        add("2x Bodyweight Deadlift", when: maxDeadlift >= bodyweightKilograms * 2)
        add("7-Day Workout Streak", when: stats.currentStreak >= 7)
        add("30-Day Workout Streak", when: stats.currentStreak >= 30)
        add("90-Day Workout Streak", when: stats.currentStreak >= 90)
        add("50,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 50_000)
        add("250,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 250_000)
        add("1,000,000 kg Volume", when: stats.lifetimeWorkingSetVolume >= 1_000_000)
        add("Profile Complete", when: isProfileComplete())
        return titles
    }

    private func maxVerifiedOrCompletedOneRepKilograms(for rankingExerciseID: String) -> Double {
        let liftBest = lifts.filter { $0.exerciseID == rankingExerciseID && $0.repetitions == 1 }.map(\.normalizedWeightKilograms).max() ?? 0
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

    private func isProfileComplete() -> Bool {
        !currentProfile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currentProfile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

