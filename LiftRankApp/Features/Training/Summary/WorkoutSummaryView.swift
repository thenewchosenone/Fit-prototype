import PhotosUI
import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary
    let prCandidates: [WorkoutPRCandidate]
    let didExplainAutomaticSubmission: Bool
    let onAutomaticSubmissionChanged: (Bool) -> Void
    let onExplanationShown: () -> Void
    let onComplete: (Int, String, [UUID: URL], Bool) -> Bool
    @State private var effort = 3
    @State private var notes = ""
    @State private var automaticSubmissionEnabled: Bool
    @State private var selectedVideoItems: [UUID: PhotosPickerItem] = [:]
    @State private var videoURLsBySetID: [UUID: URL] = [:]
    @State private var loadingVideoSetIDs: Set<UUID> = []
    @State private var videoError: String?
    @State private var showingAutomaticSubmissionExplanation = false
    @State private var hasSavedWorkout = false
    @State private var completionHighlights: [String] = []
    @State private var showsAllAchievements = false
    @State private var finishedDuration: TimeInterval?
    @State private var finishedUnit: UnitSystem?

    init(
        summary: WorkoutSummary,
        prCandidates: [WorkoutPRCandidate],
        automaticSubmissionEnabled: Bool,
        didExplainAutomaticSubmission: Bool,
        onAutomaticSubmissionChanged: @escaping (Bool) -> Void,
        onExplanationShown: @escaping () -> Void,
        onComplete: @escaping (Int, String, [UUID: URL], Bool) -> Bool
    ) {
        self.summary = summary
        self.prCandidates = prCandidates
        self.didExplainAutomaticSubmission = didExplainAutomaticSubmission
        self.onAutomaticSubmissionChanged = onAutomaticSubmissionChanged
        self.onExplanationShown = onExplanationShown
        self.onComplete = onComplete
        _automaticSubmissionEnabled = State(initialValue: automaticSubmissionEnabled)
    }

    private var activeDuration: TimeInterval {
        appState.activeWorkout?.elapsedDuration() ?? 0
    }

    private var plannedSessionProgress: (plannedSets: Int, isComplete: Bool)? {
        guard let sessionID = appState.activeWorkout?.sourceSessionID,
              let session = appState.workoutSessions.first(where: { $0.id == sessionID }) else { return nil }
        let plannedSets = appState.prescriptions(for: session).reduce(0) { $0 + $1.sets }
        guard plannedSets > 0 else { return nil }
        return (plannedSets, summary.totalSets >= plannedSets)
    }

    private var previousComparableWorkout: CompletedWorkout? {
        appState.previousComparableWorkout(for: summary)
    }

    private var projectedWorkoutCount: Int {
        appState.competitiveStatistics.totalWorkouts + 1
    }

    private var projectedStreak: Int {
        Self.projectedWorkoutStreak(
            currentStreak: appState.competitiveStatistics.currentStreak,
            completedWorkouts: appState.completedWorkouts,
            completingAt: .now
        )
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

        NavigationStack {
            AppBackground {
                if hasSavedWorkout {
                    savedWorkoutContent
                } else {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(Color.liftOnAccent)
                                .frame(width: 72, height: 72)
                                .background(Color.liftGreen)
                                .clipShape(Circle())
                            Text("Review workout")
                                .font(.largeTitle.weight(.black))
                            Text(summary.workoutName)
                                .font(.headline)
                                .foregroundStyle(Color.liftMuted)
                            if let plannedSessionProgress {
                                Label(
                                    plannedSessionProgress.isComplete ? "Will complete planned session" : "Will save shortened session",
                                    systemImage: plannedSessionProgress.isComplete ? "checkmark.circle.fill" : "minus.circle.fill"
                                )
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(plannedSessionProgress.isComplete ? Color.liftGreen : Color.liftGold)
                                Text("\(summary.totalSets) of \(plannedSessionProgress.plannedSets) planned working sets logged")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 10) {
                            summaryMetric("Exercises", "\(summary.completedExercises)/\(summary.totalExercises)", "dumbbell.fill")
                            summaryMetric("Sets", "\(summary.totalSets)", "checkmark.circle.fill")
                            summaryMetric("Volume", MeasurementFormatting.formatRecordedWeight(summary.totalVolume, unit: appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit), "scalemass.fill")
                        }

                        HStack(spacing: 10) {
                            summaryMetric("Duration", durationText(activeDuration), "timer")
                            summaryMetric("Projected streak", "\(projectedStreak)d", "flame.fill")
                            summaryMetric("Lifetime workouts", "\(projectedWorkoutCount)", "calendar")
                        }

                        if let previous = previousComparableWorkout {
                            comparisonSection(previous)
                        }

                        if !prCandidates.isEmpty {
                            prSubmissionSection
                        }

                        if let volumePRDetails {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("New volume PR", systemImage: "chart.bar.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.liftGreen)
                                Text("You moved \(MeasurementFormatting.formatRecordedWeight(volumePRDetails.current, unit: volumePRDetails.unit)) total volume — \(MeasurementFormatting.formatRecordedWeight(volumePRDetails.current - volumePRDetails.previous, unit: volumePRDetails.unit)) more than your previous best.")
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
                                Text("Unlocked achievements")
                                    .font(.headline.weight(.bold))
                                ForEach(newlyUnlockedAchievements.prefix(3)) { unlock in
                                    HStack(spacing: 10) {
                                        Image(systemName: "medal.fill")
                                            .foregroundStyle(Color.liftGold)
                                        Text(unlock.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("How hard did this workout feel?")
                                .font(.title3.weight(.black))
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        effort = value
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
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout notes")
                                .font(.headline.weight(.bold))
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

                        PrimaryButton(title: "Save & finish", symbolName: "checkmark.circle.fill") {
                            var highlights = prCandidates.prefix(2).map { candidate in
                                "New \(candidate.exerciseName) PR: \(MeasurementFormatting.recordedLiftSetText(weight: candidate.weight, unit: candidate.unit, repetitions: candidate.repetitions))"
                            }
                            if volumePRDetails != nil {
                                highlights.append("New workout volume PR")
                            }
                            highlights.append(contentsOf: newlyUnlockedAchievements.prefix(2).map { "Achievement: \($0.title)" })
                            if onComplete(effort, notes, videoURLsBySetID, false) {
                                completionHighlights = Array(highlights.prefix(3))
                                finishedDuration = activeDuration
                                finishedUnit = summaryUnit
                                hasSavedWorkout = true
                            }
                        }
                        .accessibilityIdentifier("workout.finish.save")
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(hasSavedWorkout ? "Workout saved" : "Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasSavedWorkout ? "Done" : "Back") { dismiss() }
                }
            }
            .onAppear {
                if !prCandidates.isEmpty && !didExplainAutomaticSubmission {
                    onExplanationShown()
                    showingAutomaticSubmissionExplanation = true
                }
            }
            .alert("Share eligible PRs automatically?", isPresented: $showingAutomaticSubmissionExplanation) {
                Button("Enable") {
                    automaticSubmissionEnabled = true
                    onAutomaticSubmissionChanged(true)
                }
                Button("Keep Private", role: .cancel) {
                    automaticSubmissionEnabled = false
                    onAutomaticSubmissionChanged(false)
                }
            } message: {
                Text("When enabled, eligible PRs are posted publicly as self-reported without a video, or video-backed when you attach one.")
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
                summaryMetric("Volume", MeasurementFormatting.formatRecordedWeight(summary.totalVolume, unit: finishedUnit ?? appState.currentProfile.preferredUnit), "scalemass.fill")
                summaryMetric("Duration", durationText(finishedDuration ?? activeDuration), "timer")
            }

            if completionHighlights.isEmpty {
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
                        Label(achievement.title, systemImage: isUnlocked ? achievement.symbolName : "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isUnlocked ? Color.liftGold : Color.liftMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            PrimaryButton(title: "Done", symbolName: "checkmark") { dismiss() }
                .accessibilityIdentifier("workout.finish.saved.done")
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
    }

    private func rivalTierProgressSection(
        advancedStrengthLifts: [LiftTierProgress],
        projectedStrengthTierSummary: StrengthTierSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Rival Tier progress", systemImage: "medal.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftGold)
            ForEach(advancedStrengthLifts) { lift in
                HStack {
                    Text(lift.exerciseName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(lift.currentTier.label)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color.liftGold)
                }
            }
            if projectedStrengthTierSummary.overallTier > appState.strengthTierSummary.overallTier {
                Text("Overall Rival Tier advanced to \(projectedStrengthTierSummary.overallTier.label).")
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
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personal records")
                        .font(.title3.weight(.black))
                    Text("Enable automatic sharing to publish these PRs; attach video to mark one video-backed.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.liftGold)
            }

            Toggle(isOn: Binding(
                get: { automaticSubmissionEnabled },
                set: { enabled in
                    automaticSubmissionEnabled = enabled
                    onAutomaticSubmissionChanged(enabled)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatically share eligible PRs")
                        .font(.subheadline.weight(.bold))
                    Text("Public • Self-reported or video-backed • next daily ranking update")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftAccentText)

            ForEach(prCandidates) { candidate in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.exerciseName)
                                .font(.subheadline.weight(.bold))
                            Text(MeasurementFormatting.recordedLiftSetText(weight: candidate.weight, unit: candidate.unit, repetitions: candidate.repetitions))
                                .font(.headline.weight(.black).monospacedDigit())
                                .foregroundStyle(Color.liftGold)
                        }
                        Spacer()
                        Text("NEW PR")
                            .font(.caption2.weight(.black))
                            .tracking(0.7)
                            .foregroundStyle(Color.liftGold)
                    }

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
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.liftBlue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.liftScrim)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !automaticSubmissionEnabled {
                Label("These PRs remain private until you enable automatic sharing.", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
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
        return VStack(alignment: .leading, spacing: 10) {
            Text("Compared with last \(previous.name)")
                .font(.headline.weight(.bold))
            HStack(spacing: 10) {
                summaryMetric("Volume", "\(signedValue(volumeDelta)) \(displayUnit.shortLabel)", "chart.bar.fill")
                summaryMetric("Sets", signedValue(Double(setDelta)), "plusminus")
                summaryMetric("Time", signedDuration(durationDelta), "clock.arrow.circlepath")
            }
            Text("Previous: \(Int(previousVolume)) \(displayUnit.shortLabel) in \(previousSets) sets")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func durationText(_ duration: TimeInterval) -> String {
        MeasurementFormatting.shortClockText(duration)
    }

    private func signedValue(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func signedDuration(_ value: TimeInterval) -> String {
        MeasurementFormatting.signedShortClockText(seconds: Int(value.rounded()))
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

    private func loadVideo(_ item: PhotosPickerItem, for candidate: WorkoutPRCandidate) {
        loadingVideoSetIDs.insert(candidate.setID)
        videoError = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                let url = try await appState.persistWorkoutVideo(data)
                await MainActor.run {
                    videoURLsBySetID[candidate.setID] = url
                    loadingVideoSetIDs.remove(candidate.setID)
                }
            } catch {
                await MainActor.run {
                    loadingVideoSetIDs.remove(candidate.setID)
                    videoError = "That video could not be prepared. Choose it again before saving."
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
