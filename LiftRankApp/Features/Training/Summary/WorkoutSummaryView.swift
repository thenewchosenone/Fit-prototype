import PhotosUI
import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    private let initialSummary: WorkoutSummary
    let onComplete: (Int, String, [UUID: URL], Set<UUID>, Bool) -> Bool
    @State private var effort = 0
    @State private var notes = ""
    @State private var keepWorkoutPrivate = false
    @State private var sharePRs: Bool
    @State private var selectedPRSetIDs: Set<UUID>
    @State private var selectedVideoItems: [UUID: PhotosPickerItem] = [:]
    @State private var videoURLsBySetID: [UUID: URL] = [:]
    @State private var loadingVideoSetIDs: Set<UUID> = []
    @State private var videoError: String?
    @State private var hasSavedWorkout = false
    @State private var savedSummary: WorkoutSummary?
    @State private var completionHighlights: [String] = []
    @State private var savedAchievementBadges: [Achievement] = []
    @State private var savedAchievementProgress: (title: String, progress: Double, status: String)?
    @State private var showsAllAchievements = false
    @State private var showsNotes = false
    @State private var finishedDuration: TimeInterval?
    @State private var finishedUnit: UnitSystem?

    init(
        summary: WorkoutSummary,
        prCandidates: [WorkoutPRCandidate],
        automaticSubmissionEnabled: Bool,
        onComplete: @escaping (Int, String, [UUID: URL], Set<UUID>, Bool) -> Bool
    ) {
        self.initialSummary = summary
        self.onComplete = onComplete
        _sharePRs = State(initialValue: automaticSubmissionEnabled)
        _selectedPRSetIDs = State(initialValue: Set(prCandidates.map(\.setID)))
    }

    private var summary: WorkoutSummary {
        if hasSavedWorkout { return savedSummary ?? initialSummary }
        return appState.activeWorkoutSummary() ?? initialSummary
    }

    private var prCandidates: [WorkoutPRCandidate] {
        appState.activeWorkoutPRCandidates()
    }

    private var activeDuration: TimeInterval {
        appState.activeWorkout?.elapsedDuration() ?? 0
    }

    private var plannedSessionProgress: (plannedSets: Int, isComplete: Bool)? {
        guard let activeWorkout = appState.activeWorkout,
              let sessionID = activeWorkout.sourceSessionID,
              let session = appState.workoutSessions.first(where: { $0.id == sessionID }) else { return nil }
        let prescriptions = appState.prescriptions(for: session)
        let plannedSets = prescriptions.reduce(0) { $0 + $1.sets }
        guard plannedSets > 0 else { return nil }
        let isComplete = prescriptions.allSatisfy { prescription in
            guard let exercise = activeWorkout.exercises.first(where: { $0.sourcePrescriptionID == prescription.id }) else {
                return false
            }
            let progress = appState.activeWorkoutExerciseProgress(for: exercise)
            return progress.completedWorkingSets >= prescription.sets
        }
        return (plannedSets, isComplete)
    }

    private var plannedProgramMilestone: String? {
        guard plannedSessionProgress?.isComplete == true,
              let activeWorkout = appState.activeWorkout,
              let sessionID = activeWorkout.sourceSessionID,
              let session = appState.workoutSessions.first(where: { $0.id == sessionID }),
              let week = appState.workoutWeeks.first(where: { $0.id == session.weekID }),
              let plan = appState.workoutPlans.first(where: { $0.id == week.planID }) else { return nil }
        let planWeekIDs = Set(appState.workoutWeeks.filter { $0.planID == plan.id }.map(\.id))
        let plannedSessionCount = appState.workoutSessions.filter {
            planWeekIDs.contains($0.weekID) && !appState.prescriptions(for: $0).isEmpty
        }.count
        guard plannedSessionCount > 0 else { return nil }
        let priorCompletedSessionIDs = Set(appState.workoutSessions.filter {
            planWeekIDs.contains($0.weekID) && appState.isFullyCompletedPlanSession($0)
        }.map(\.id))
        guard !priorCompletedSessionIDs.contains(sessionID) else { return nil }
        let priorCompletedCount = priorCompletedSessionIDs.count
        let completedCount = priorCompletedCount + 1
        if completedCount == 1 { return "First planned session complete" }
        if completedCount >= plannedSessionCount { return "Program complete: \(plan.name)" }
        let halfway = max(2, Int(ceil(Double(plannedSessionCount) / 2)))
        return completedCount == halfway ? "Halfway through \(plan.name)" : nil
    }

    private var previousComparableWorkout: CompletedWorkout? {
        appState.previousComparableWorkout(for: summary)
    }

    static func projectedWorkoutStreak(
        currentStreak: Int,
        completedWorkouts: [CompletedWorkout],
        completingAt: Date,
        calendar: Calendar = .current
    ) -> Int {
        let alreadyTrainedToday = completedWorkouts.contains {
            !$0.completedWorkingSets.isEmpty && calendar.isDate($0.completedAt, inSameDayAs: completingAt)
        }
        return alreadyTrainedToday ? currentStreak : max(currentStreak, 0) + 1
    }

    private var volumePRDetails: (current: Double, previous: Double, unit: UnitSystem)? {
        let currentUnit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
        let currentKilograms = MeasurementFormatting.normalizeToKilograms(summary.totalVolume, unit: currentUnit)
        let previousKilograms = appState.completedWorkouts
                .filter { $0.id != summary.id }
                .map({ MeasurementFormatting.normalizeToKilograms($0.totalVolume, unit: $0.unit) })
                .max()
        guard currentKilograms > 0,
              let previousKilograms,
              currentKilograms > previousKilograms else {
            return nil
        }
        let displayUnit = appState.currentProfile.preferredUnit
        return (
            MeasurementFormatting.convert(currentKilograms, from: .kilograms, to: displayUnit),
            MeasurementFormatting.convert(previousKilograms, from: .kilograms, to: displayUnit),
            displayUnit
        )
    }

    private func newlyUnlockedAchievements(
        workingSets: [WorkoutSetLog],
        activeDuration: TimeInterval
    ) -> [AchievementUnlock] {
        let alreadyEarnedTitles = Set(currentAchievementTitles())
            .union(Set(appState.achievementUnlocks.map(\.title)))
        return Self.newlyUnlockedTitles(
            projected: projectedAchievementTitles(
                workingSets: workingSets,
                activeDuration: activeDuration
            ),
            alreadyEarned: alreadyEarnedTitles
        )
            .map {
                AchievementUnlock(
                    id: $0.lowercased().replacingOccurrences(of: " ", with: "-"),
                    title: $0,
                    unlockedAt: .now
                )
            }
    }

    private func nextAchievementProgress(
        workingSets: [WorkoutSetLog],
        activeDuration: TimeInterval,
        newlyUnlocked: [AchievementUnlock]
    ) -> (title: String, progress: Double, status: String)? {
        let stats = appState.competitiveStatistics
        let unlockedTitles = Set(appState.achievementUnlocks.map(\.title))
            .union(newlyUnlocked.map(\.title))
        let projected = [
            (suffix: " Workouts", current: Double(stats.totalWorkouts + 1), unit: "workouts"),
            (suffix: " Reps", current: Double(stats.totalWorkingSetRepetitions + currentWorkoutWorkingSetRepetitions(workingSets)), unit: "reps"),
            (suffix: " Training Hours", current: (stats.totalActiveTrainingTime + activeDuration) / 3600, unit: "hrs"),
            (suffix: " kg Lifted Volume", current: stats.lifetimeWorkingSetVolume + currentWorkoutVolumeKilograms(workingSets), unit: "")
        ]

        return appState.achievements.compactMap { achievement in
            guard !unlockedTitles.contains(achievement.title) else { return nil }
            for item in projected where achievement.title.hasSuffix(item.suffix) {
                let prefix = String(achievement.title.dropLast(item.suffix.count))
                    .replacingOccurrences(of: ",", with: "")
                guard let target = Double(prefix), target > 0 else { continue }
                let progress = min(1, max(0, item.current / target))
                guard progress > 0, progress < 1 else { continue }
                let status: String
                if item.suffix == " kg Lifted Volume" {
                    status = "\(formattedAchievementVolume(item.current)) / \(formattedAchievementVolume(target))"
                } else if item.unit == "hrs" {
                    status = "\(MeasurementFormatting.localizedDecimalText(item.current, minimumFractionDigits: 1, maximumFractionDigits: 1)) / \(Int(target)) hrs"
                } else {
                    status = "\(Int(item.current)) / \(Int(target)) \(item.unit)"
                }
                return (title: displayAchievementTitle(achievement.title), progress: progress, status: status)
            }
            return nil
        }
        .max { $0.progress < $1.progress }
    }

    private func formattedAchievementVolume(_ kilograms: Double) -> String {
        MeasurementFormatting.formatDisplayedWeight(
            kilograms,
            unit: appState.currentProfile.preferredUnit
        ) { Int($0.rounded()).formatted() }
    }

    static func newlyUnlockedTitles(
        projected: [String],
        alreadyEarned: Set<String>
    ) -> [String] {
        projected.filter { !alreadyEarned.contains($0) }
    }

    private func projectedStrengthTierSummary(workingSets: [WorkoutSetLog]) -> StrengthTierSummary {
        guard let workout = appState.activeWorkout else {
            return appState.strengthTierSummary
        }
        let exercisesByID = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
        let performances = workingSets.compactMap { set -> StrengthLiftPerformance? in
            guard let exercise = exercisesByID[set.prescriptionID],
                  let weight = set.weight, weight > 0,
                  let repetitions = set.reps, (1...10).contains(repetitions) else { return nil }
            let exerciseID = exercise.rankingExerciseID ?? exercise.exerciseID
            guard RankingCalculator.strengthTierExerciseIDs.contains(exerciseID) else { return nil }
            let kilograms = MeasurementFormatting.normalizeToKilograms(weight, unit: set.recordedUnit)
            return StrengthLiftPerformance(
                exerciseID: exerciseID,
                estimatedOneRepMaxKilograms: RankingCalculator.epleyOneRepMax(
                    weight: kilograms,
                    repetitions: repetitions
                )
            )
        }
        return appState.strengthTierSummary(including: performances)
    }

    var body: some View {
        let activeDuration = activeDuration
        let summaryUnit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
        let workingSets = currentWorkoutWorkingSets
        let projectedStrengthTierSummary = projectedStrengthTierSummary(workingSets: workingSets)
        let advancedStrengthLifts = projectedStrengthTierSummary.advancedLifts(
            comparedTo: appState.strengthTierSummary
        )
        let newlyUnlockedAchievements = newlyUnlockedAchievements(
            workingSets: workingSets,
            activeDuration: activeDuration
        )
        let nextAchievementProgress = nextAchievementProgress(
            workingSets: workingSets,
            activeDuration: activeDuration,
            newlyUnlocked: newlyUnlockedAchievements
        )

        NavigationStack {
            AppBackground {
                if hasSavedWorkout {
                    savedWorkoutContent
                } else {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(summary.workoutName)
                                .font(.title2.weight(.black))
                            Text((appState.activeWorkout?.startedAt ?? .now).formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            Text("\(summary.completedExercises)/\(summary.totalExercises) exercises · \(summary.totalSets) working \(summary.totalSets == 1 ? "set" : "sets") · \(durationText(activeDuration))")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Total volume: \(formattedVolume(summary.totalVolume, unit: summaryUnit))")
                                .font(.headline.weight(.bold).monospacedDigit())
                            if let plannedSessionProgress {
                                Label(
                                    plannedSessionProgress.isComplete ? "Will complete planned session" : "Will save shortened session",
                                    systemImage: plannedSessionProgress.isComplete ? "checkmark.circle" : "minus.circle"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(plannedSessionProgress.isComplete ? Color.liftGreen : Color.liftGold)
                                Text("\(summary.totalSets) of \(plannedSessionProgress.plannedSets) planned working sets logged")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if !prCandidates.isEmpty || volumePRDetails != nil || !advancedStrengthLifts.isEmpty || !newlyUnlockedAchievements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Workout highlights")
                                    .font(.title3.weight(.black))
                                if !prCandidates.isEmpty {
                                    prSubmissionSection
                                }
                                if let volumePRDetails {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Highest recorded workout volume", systemImage: "chart.bar.fill")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Color.liftGreen)
                                        Text("\(formattedVolume(volumePRDetails.current - volumePRDetails.previous, unit: volumePRDetails.unit)) above your previous highest. Exercise selection affects total volume.")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    .padding(14)
                                    .background(Color.liftGreen.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.liftGreen.opacity(0.28), lineWidth: 1)
                                    }
                                }

                                if !advancedStrengthLifts.isEmpty {
                                    rivalTierProgressSection(
                                        advancedStrengthLifts: advancedStrengthLifts,
                                        projectedStrengthTierSummary: projectedStrengthTierSummary
                                    )
                                }

                                if !newlyUnlockedAchievements.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Badge unlocked on saving")
                                            .font(.headline.weight(.bold))
                                        ForEach(newlyUnlockedAchievements.prefix(3)) { unlock in
                                            achievementBadgeRow(
                                                appState.achievements.first { $0.title == unlock.title },
                                                fallbackTitle: unlock.title
                                            )
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.liftGold.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.liftGold.opacity(0.28), lineWidth: 1)
                                    }
                                }

                                if let nextAchievementProgress {
                                    achievementProgressCard(nextAchievementProgress)
                                }

                            }
                        }

                        exerciseReviewSection

                        if !hasSavedWorkout {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Keep workout private", isOn: $keepWorkoutPrivate)
                                        .accessibilityIdentifier("workout.summary.keepPrivate")
                                    Text("Your public profile shows a workout summary. Notes, bodyweight, and gym details stay private.")
                                        .font(.caption).foregroundStyle(Color.liftMuted)
                                }
                            }
                        }

                        if let previous = previousComparableWorkout {
                            comparisonSection(previous)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workout effort · Optional")
                                .font(.title3.weight(.black))
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        effort = effort == value ? 0 : value
                                        Haptics.light()
                                    } label: {
                                        VStack(spacing: 5) {
                                            Text("\(value)")
                                                .font(.headline.weight(.black))
                                            Text(effortLabel(value))
                                                .font(.system(size: 9, weight: .bold))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(effort == value ? Color.liftBlue : Color.liftCard)
                                        .foregroundStyle(effort == value ? Color.liftOnAccent : Color.liftMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(value) of 5, \(effortLabel(value))")
                                    .accessibilityAddTraits(effort == value ? .isSelected : [])
                                }
                            }
                        }

                        DisclosureGroup("Add a note · Optional", isExpanded: $showsNotes) {
                            TextEditor(text: $notes)
                                .frame(minHeight: 90)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.liftCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Anything to remember for next time?")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.liftMuted)
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 18)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }

                    }
                    .padding(18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom) {
                        PrimaryButton(title: "Save & finish", symbolName: "checkmark.circle.fill") {
                            let prHighlights = prCandidates.prefix(2).map { candidate in
                                "New \(candidate.exerciseName) PR: \(MeasurementFormatting.recordedLiftSetText(weight: candidate.weight, unit: candidate.unit, repetitions: candidate.repetitions))"
                            }
                            let highlights = Self.orderedCompletionHighlights(
                                prHighlights: prHighlights,
                                hasVolumePR: volumePRDetails != nil,
                                plannedSessionComplete: plannedSessionProgress?.isComplete == true,
                                programMilestone: plannedProgramMilestone,
                                achievements: []
                            )
                            let reviewedSummary = summary
                            let eligibleIDs = Set(prCandidates.map(\.setID))
                            let sharedIDs = sharePRs ? selectedPRSetIDs.intersection(eligibleIDs) : []
                            if onComplete(effort, notes, videoURLsBySetID.filter { sharedIDs.contains($0.key) }, sharedIDs, !keepWorkoutPrivate) {
                                savedSummary = reviewedSummary
                                completionHighlights = highlights
                                savedAchievementBadges = newlyUnlockedAchievements.prefix(3).compactMap { unlock in
                                    appState.achievements.first { $0.title == unlock.title }
                                }
                                savedAchievementProgress = nextAchievementProgress
                                finishedDuration = activeDuration
                                finishedUnit = summaryUnit
                                hasSavedWorkout = true
                            }
                        }
                        .accessibilityIdentifier("workout.finish.save")
                        .disabled(!loadingVideoSetIDs.isEmpty || appState.activeWorkoutFinishReadiness == .empty)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle(hasSavedWorkout ? "Workout saved" : "Review workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasSavedWorkout ? "Done" : "Back") { dismiss() }
                }
            }

        }
    }

    private var savedWorkoutContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Color.liftOnAccent)
                    .frame(width: 72, height: 72)
                    .background(Color.liftGreen)
                    .clipShape(Circle())
                Text("Workout saved")
                    .font(.largeTitle.weight(.black))
                Text(summary.workoutName)
                    .font(.headline)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                summaryMetric("Sets", "\(summary.totalSets)", "checkmark.circle.fill")
                summaryMetric("Volume", formattedVolume(summary.totalVolume, unit: finishedUnit ?? appState.currentProfile.preferredUnit), "scalemass.fill")
                summaryMetric("Duration", durationText(finishedDuration ?? activeDuration), "timer")
            }

            if completionHighlights.isEmpty && savedAchievementBadges.isEmpty {
                Text("Session saved. Keep building toward your next milestone.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Workout highlights")
                        .font(.headline.weight(.bold))
                    ForEach(completionHighlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftGold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(Color.liftGold.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !savedAchievementBadges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(savedAchievementBadges.count == 1 ? "Badge earned" : "Badges earned")
                        .font(.headline.weight(.bold))
                    ForEach(savedAchievementBadges) { achievement in
                        achievementBadgeRow(achievement, fallbackTitle: achievement.title)
                    }
                }
                .padding(14)
                .background(Color.liftGold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.liftGold.opacity(0.28), lineWidth: 1)
                }
            }

            if let savedAchievementProgress {
                achievementProgressCard(savedAchievementProgress)
            }

            Button {
                showsAllAchievements.toggle()
            } label: {
                Label(
                    showsAllAchievements ? "Hide all achievements" : "View all achievements",
                    systemImage: showsAllAchievements ? "chevron.up" : "chevron.down"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.finish.saved.achievements")

            if showsAllAchievements {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All achievements")
                        .font(.headline.weight(.bold))
                    ForEach(appState.achievements) { achievement in
                        let isUnlocked = appState.achievementUnlocks.contains { $0.title == achievement.title }
                        Label(displayAchievementTitle(achievement.title), systemImage: isUnlocked ? achievement.symbolName : "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isUnlocked ? Color.liftGold : Color.liftMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if appState.selectedPlanQueueEnabled,
               let session = appState.nextQueuedWorkoutSession,
               let week = appState.selectedPlanWeeks.first(where: { $0.id == session.weekID }) {
                Text("Next: \(session.name) · Week \(week.weekNumber)")
                    .font(.subheadline).foregroundStyle(Color.liftMuted)
            } else if let next = appState.nextScheduledWorkout() {
                Text("Next: \(next.session.name) · \(LiftTimeFormatter.shortDateNoTime(next.date))")
                    .font(.subheadline).foregroundStyle(Color.liftMuted)
            }
            PrimaryButton(title: "Done", symbolName: "checkmark") { dismiss() }
                .accessibilityIdentifier("workout.finish.saved.done")
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
    }

    private func achievementBadgeRow(_ achievement: Achievement?, fallbackTitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: achievement?.symbolName ?? "medal.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftGold)
                .frame(width: 38, height: 38)
                .background(Color.liftGold.opacity(0.14))
                .clipShape(Circle())
            Text(displayAchievementTitle(fallbackTitle))
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    private func achievementProgressCard(
        _ progress: (title: String, progress: Double, status: String)
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Next achievement", systemImage: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            Text(progress.title)
                .font(.subheadline.weight(.semibold))
            ProgressView(value: progress.progress)
                .tint(Color.liftAccentText)
            Text(progress.status)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.liftMuted)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rivalTierProgressSection(
        advancedStrengthLifts: [LiftTierProgress],
        projectedStrengthTierSummary: StrengthTierSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Projected Rival Tiers", systemImage: "medal.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftGold)
            ForEach(advancedStrengthLifts) { lift in
                HStack {
                    Text("\(lift.exerciseName) tier")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(lift.currentTier.label)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color.liftGold)
                }
            }
            if projectedStrengthTierSummary.overallTier > appState.strengthTierSummary.overallTier {
                Text("Overall tier on saving: \(projectedStrengthTierSummary.overallTier.label)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftText)
            }
        }
        .padding(14)
        .background(Color.liftGold.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("workoutSummary.rivalTierProgress")
    }

    private var prSubmissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Share these PRs publicly", isOn: $sharePRs)
                .font(.subheadline.weight(.bold))
                .tint(Color.liftAccentText)
            Text(sharePRs ? "\(selectedPRSetIDs.intersection(Set(prCandidates.map(\.setID))).count) selected · Submitted when you save. Video evidence is not verification." : "No PRs will be published from this workout.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)

            let groupedRecords = Dictionary(grouping: prCandidates, by: \.rankingExerciseID)
            ForEach(groupedRecords.keys.sorted(), id: \.self) { exerciseID in
                let records = (groupedRecords[exerciseID] ?? []).sorted { $0.repetitions < $1.repetitions }
                VStack(alignment: .leading, spacing: 10) {
                    Text(records.first?.exerciseName ?? exerciseID)
                        .font(.headline.weight(.bold))
                    ForEach(records) { candidate in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(MeasurementFormatting.recordedLiftSetText(weight: candidate.weight, unit: candidate.unit, repetitions: candidate.repetitions))
                                        .font(.headline.weight(.black).monospacedDigit())
                                        .foregroundStyle(Color.liftGold)
                                    Text(candidate.previousBestKilograms == nil ? "First recorded \(candidate.repetitions)-rep best" : "New \(candidate.repetitions)-rep best")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                if sharePRs {
                                    Button {
                                        if !selectedPRSetIDs.insert(candidate.setID).inserted {
                                            selectedPRSetIDs.remove(candidate.setID)
                                        }
                                    } label: {
                                        Image(systemName: selectedPRSetIDs.contains(candidate.setID) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(Color.liftAccentText)
                                            .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Share \(candidate.exerciseName), \(candidate.repetitions)-rep record")
                                    .accessibilityValue(selectedPRSetIDs.contains(candidate.setID) ? "Selected" : "Not selected")
                                }
                            }
                            if sharePRs && selectedPRSetIDs.contains(candidate.setID) {
                                PhotosPicker(
                                    selection: Binding(
                                        get: { selectedVideoItems[candidate.setID] },
                                        set: { item in
                                            selectedVideoItems[candidate.setID] = item
                                            guard let item else {
                                                videoURLsBySetID.removeValue(forKey: candidate.setID)
                                                return
                                            }
                                            loadVideo(item, for: candidate)
                                        }
                                    ),
                                    matching: .videos
                                ) {
                                    HStack {
                                        if loadingVideoSetIDs.contains(candidate.setID) {
                                            ProgressView()
                                        } else {
                                            Image(systemName: videoURLsBySetID[candidate.setID] == nil ? "video.badge.plus" : "checkmark.circle.fill")
                                        }
                                        Text(videoURLsBySetID[candidate.setID] == nil ? "Attach lift video" : "Video attached")
                                        Spacer()
                                        if videoURLsBySetID[candidate.setID] != nil {
                                            Text("Ready")
                                                .foregroundStyle(Color.liftGreen)
                                        }
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftAccentText)
                                    .frame(minHeight: 44)
                                }
                            }
                        }
                        if candidate.id != records.last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color.liftScrim)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let videoError {
                Label(videoError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftRed)
            }
        }
        .padding(14)
        .background(Color.liftGold.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liftGold.opacity(0.25), lineWidth: 1)
        }
    }

    private func comparisonSection(_ previous: CompletedWorkout) -> some View {
        let currentUnit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
        let displayUnit = appState.currentProfile.preferredUnit
        let previousVolume = MeasurementFormatting.displayRecordedVolume(
            previous.totalVolume,
            recordedUnit: previous.unit,
            preferredUnit: displayUnit
        )
        let currentVolume = MeasurementFormatting.displayRecordedVolume(
            summary.totalVolume,
            recordedUnit: currentUnit,
            preferredUnit: displayUnit
        )
        let previousSets = previous.completedWorkingSets.count
        let volumeDelta = currentVolume - previousVolume
        let setDelta = summary.totalSets - previousSets
        let durationDelta = activeDuration - previous.duration
        let exercises = appState.activeWorkout?.exercises ?? []
        let previousExerciseIDs = Set(previous.exercises.map(\.exerciseID))
        let weightedExerciseIDs = Set(currentWorkoutWorkingSets.map(\.prescriptionID))
        let matchingExercises = exercises.filter {
            previousExerciseIDs.contains($0.exerciseID) && weightedExerciseIDs.contains($0.id)
        }
        return DisclosureGroup("View comparison") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last \(previous.name) · \(previous.completedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.semibold))
                Text("Session totals; more volume or time does not necessarily mean better performance.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                LabeledContent("Volume change", value: "\(signedValue(volumeDelta)) \(displayUnit.shortLabel)")
                LabeledContent("Working set change", value: signedValue(Double(setDelta)))
                LabeledContent("Duration", value: "\(durationText(abs(durationDelta))) \(durationDelta >= 0 ? "longer" : "shorter")")
                Text("Previous: \(formattedVolume(previousVolume, unit: displayUnit)) in \(previousSets) sets")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                if matchingExercises.isEmpty {
                    Text("No matching weighted exercises to compare. Session totals may reflect different exercises.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    Text("Matching weighted exercises · Volume")
                        .font(.subheadline.weight(.bold))
                    ForEach(matchingExercises) { exercise in
                        let currentSets = currentWorkoutWorkingSets.filter { $0.prescriptionID == exercise.id }
                        let priorIDs = Set(previous.exercises.filter { $0.exerciseID == exercise.exerciseID }.map(\.id))
                        let priorSets = previous.completedWorkingSets.filter { priorIDs.contains($0.prescriptionID) }
                        let current = currentSets.reduce(0) { $0 + $1.volume(in: displayUnit) }
                        let prior = priorSets.reduce(0) { $0 + $1.volume(in: displayUnit) }
                        if !currentSets.isEmpty && !priorSets.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(formattedVolume(prior, unit: displayUnit)) → \(formattedVolume(current, unit: displayUnit))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        if seconds >= 3_600 { return "\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }

    private func signedValue(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 0 ? "+\(rounded.formatted())" : rounded.formatted()
    }

    private func formattedVolume(_ value: Double, unit: UnitSystem) -> String {
        "\(Int(value.rounded()).formatted()) \(unit.shortLabel)"
    }

    private var exerciseReviewSection: some View {
        DisclosureGroup("Review exercises & sets") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap an exercise to review or edit its sets.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                ForEach((appState.activeWorkout?.exercises ?? []).sorted { $0.order < $1.order }) { exercise in
                    let catalog = appState.trainingExerciseLibrary.first(where: { $0.id == exercise.exerciseID }) ?? TrainingExerciseCatalogItem(
                        id: exercise.exerciseID,
                        name: exercise.exerciseName,
                        bodyPart: exercise.bodyPart,
                        workoutCategory: exercise.bodyPart,
                        defaultSets: exercise.targetSets,
                        defaultReps: exercise.targetReps,
                        symbolName: "figure.strengthtraining.traditional",
                        equipment: exercise.equipment,
                        muscleProfile: exercise.muscleProfile,
                        rankingExerciseID: exercise.rankingExerciseID
                    )
                    NavigationLink {
                        PrescriptionTrackView(exercise: exercise, catalogExercise: catalog)
                            .environmentObject(appState)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.exerciseName)
                                .font(.subheadline.weight(.bold))
                            let progress = appState.activeWorkoutExerciseProgress(for: exercise)
                            Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets) working sets")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline.weight(.semibold))
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func projectedAchievementTitles(
        workingSets: [WorkoutSetLog],
        activeDuration: TimeInterval
    ) -> [String] {
        let stats = appState.competitiveStatistics
        let workoutCount = stats.totalWorkouts + 1
        let volumeKilograms = stats.lifetimeWorkingSetVolume + currentWorkoutVolumeKilograms(workingSets)
        let trainingTime = stats.totalActiveTrainingTime + activeDuration
        let repetitions = stats.totalWorkingSetRepetitions + currentWorkoutWorkingSetRepetitions(workingSets)
        var titles: [String] = []

        addWorkoutMilestones(to: &titles, count: workoutCount)
        addRepetitionMilestones(to: &titles, count: repetitions)
        addTrainingHourMilestones(to: &titles, seconds: trainingTime)
        addVolumeMilestones(to: &titles, kilograms: volumeKilograms)

        return titles.filter { title in
            appState.achievements.contains { $0.title == title }
        }
    }

    private func currentAchievementTitles() -> [String] {
        let stats = appState.competitiveStatistics
        var titles: [String] = []

        addWorkoutMilestones(to: &titles, count: stats.totalWorkouts)
        addRepetitionMilestones(to: &titles, count: stats.totalWorkingSetRepetitions)
        addTrainingHourMilestones(to: &titles, seconds: stats.totalActiveTrainingTime)
        addVolumeMilestones(to: &titles, kilograms: stats.lifetimeWorkingSetVolume)

        return titles.filter { title in
            appState.achievements.contains { $0.title == title }
        }
    }

    private var currentWorkoutWorkingSets: [WorkoutSetLog] {
        Self.achievementWorkingSets(
            workout: appState.activeWorkout,
            logs: appState.workoutSetLogs,
            catalog: appState.trainingExerciseLibrary
        )
    }

    static func achievementWorkingSets(
        workout: ActiveWorkoutState?,
        logs: [WorkoutSetLog],
        catalog: [TrainingExerciseCatalogItem]
    ) -> [WorkoutSetLog] {
        guard let workout else { return [] }
        let exercisesByID = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
        let trackingTypesByExerciseID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.trackingType) })

        return logs.filter { log in
            guard log.workoutID == workout.id,
                  log.isComplete,
                  !log.isWarmup,
                  let exercise = exercisesByID[log.prescriptionID] else {
                return false
            }
            let rawTrackingType = exercise.trackingType ??
                trackingTypesByExerciseID[exercise.exerciseID]
            return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps") == .weightReps
        }
    }

    static func orderedCompletionHighlights(
        prHighlights: [String],
        hasVolumePR: Bool,
        plannedSessionComplete: Bool,
        programMilestone: String?,
        achievements: [String],
        limit: Int = 3
    ) -> [String] {
        guard limit > 0 else { return [] }
        var highlights: [String] = []
        if let programMilestone {
            highlights.append(programMilestone)
        }
        highlights.append(contentsOf: prHighlights)
        if hasVolumePR {
            highlights.append("New workout volume PR")
        }
        if plannedSessionComplete {
            highlights.append("Planned program session complete")
        }
        highlights.append(contentsOf: achievements)
        return Array(highlights.prefix(limit))
    }

    private func currentWorkoutWorkingSetRepetitions(_ workingSets: [WorkoutSetLog]) -> Int {
        workingSets.reduce(0) { $0 + ($1.reps ?? 0) }
    }

    private func currentWorkoutVolumeKilograms(_ workingSets: [WorkoutSetLog]) -> Double {
        let unit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
        let volume = workingSets.reduce(0) { $0 + $1.volume(in: unit) }
        return unit == .kilograms ? volume : RankingCalculator.poundsToKilograms(volume)
    }

    private func addWorkoutMilestones(to titles: inout [String], count: Int) {
        for milestone in [1, 2, 3, 5, 10, 25, 50, 75, 100, 200, 300, 500, 1_000] where count >= milestone {
            titles.append(milestone == 1 ? "First Workout" : "\(milestone.formatted()) Workouts")
        }
    }

    private func addRepetitionMilestones(to titles: inout [String], count: Int) {
        for milestone in [1_000, 5_000, 10_000, 15_000, 25_000, 50_000, 100_000] where count >= milestone {
            titles.append("\(milestone.formatted()) Reps")
        }
    }

    private func addTrainingHourMilestones(to titles: inout [String], seconds: TimeInterval) {
        for milestone in [10, 50, 100, 150, 250, 500, 1_000] where seconds >= Double(milestone * 60 * 60) {
            titles.append("\(milestone.formatted()) Training Hours")
        }
    }

    private func addVolumeMilestones(to titles: inout [String], kilograms: Double) {
        for milestone in [10_000, 50_000, 100_000, 250_000, 500_000, 1_000_000, 2_500_000, 5_000_000] where kilograms >= Double(milestone) {
            titles.append("\(milestone.formatted()) kg Lifted Volume")
        }
    }

    private func displayAchievementTitle(_ title: String) -> String {
        let suffix = " kg Lifted Volume"
        guard title.hasSuffix(suffix),
              let kilograms = MeasurementFormatting.parseGroupedInteger(String(title.dropLast(suffix.count))) else {
            return title
        }
        let formattedVolume = MeasurementFormatting.formatDisplayedWeight(
            Double(kilograms),
            unit: appState.currentProfile.preferredUnit
        ) { value in
            Int(value.rounded()).formatted()
        }
        return "\(formattedVolume) Lifted Volume"
    }

    private func loadVideo(_ item: PhotosPickerItem, for candidate: WorkoutPRCandidate) {
        loadingVideoSetIDs.insert(candidate.setID)
        videoError = nil
        Task {
            do {
                guard let pickedVideo = try await item.loadTransferable(type: PickedWorkoutVideo.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                defer { try? FileManager.default.removeItem(at: pickedVideo.temporaryURL) }
                let url = try await appState.persistWorkoutVideo(
                    from: pickedVideo.temporaryURL,
                    fileExtension: pickedVideo.temporaryURL.pathExtension
                )
                await MainActor.run {
                    videoURLsBySetID[candidate.setID] = url
                    loadingVideoSetIDs.remove(candidate.setID)
                }
            } catch {
                await MainActor.run {
                    loadingVideoSetIDs.remove(candidate.setID)
                    if let policyError = error as? LiftVideoPolicyError {
                        videoError = switch policyError {
                        case .tooLong: "Videos must be 30 seconds or shorter."
                        case .invalidOrTooLarge: "Videos must be 500 MB or smaller. Choose a smaller video."
                        }
                    } else {
                        videoError = "That video could not be prepared. Choose it again before saving."
                    }
                }
            }
        }
    }

    private func effortLabel(_ value: Int) -> String {
        ["Easy", "Light", "Solid", "Hard", "Max"][value - 1]
    }

    private func summaryMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func trackingKind(for set: WorkoutSetLog) -> ExerciseTrackingKind {
        guard let exercise = appState.activeWorkout?.exercises.first(where: { $0.id == set.prescriptionID }) else {
            return .weightReps
        }
        let rawTrackingType = exercise.trackingType ??
            appState.trainingExerciseLibrary.first(where: { $0.id == exercise.exerciseID })?.trackingType
        return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps")
    }
}
