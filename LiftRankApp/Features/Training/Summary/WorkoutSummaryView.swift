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
    let onComplete: (Int, String, [UUID: URL], Bool) -> Void
    @State private var effort = 3
    @State private var notes = ""
    @State private var automaticSubmissionEnabled: Bool
    @State private var selectedVideoItems: [UUID: PhotosPickerItem] = [:]
    @State private var videoURLsBySetID: [UUID: URL] = [:]
    @State private var loadingVideoSetIDs: Set<UUID> = []
    @State private var videoError: String?
    @State private var showingAutomaticSubmissionExplanation = false

    init(
        summary: WorkoutSummary,
        prCandidates: [WorkoutPRCandidate],
        automaticSubmissionEnabled: Bool,
        didExplainAutomaticSubmission: Bool,
        onAutomaticSubmissionChanged: @escaping (Bool) -> Void,
        onExplanationShown: @escaping () -> Void,
        onComplete: @escaping (Int, String, [UUID: URL], Bool) -> Void
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

    private var previousComparableWorkout: CompletedWorkout? {
        appState.completedWorkouts.first {
            $0.sourceSessionID == summary.sessionID || $0.name == summary.workoutName
        }
    }

    private var projectedWorkoutCount: Int {
        appState.competitiveStatistics.totalWorkouts + 1
    }

    private var projectedStreak: Int {
        max(appState.competitiveStatistics.currentStreak, 0) + 1
    }

    private var newlyUnlockedAchievements: [AchievementUnlock] {
        let alreadyEarnedTitles = Set(currentAchievementTitles())
            .union(Set(appState.achievementUnlocks.map(\.title)))
        return Self.newlyUnlockedTitles(
            projected: projectedAchievementTitles(),
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

    private var projectedStrengthTierSummary: StrengthTierSummary {
        let workout = appState.activeWorkout
        let performances = currentWorkoutWorkingSets.compactMap { set -> StrengthLiftPerformance? in
            guard let workout,
                  let exercise = workout.exercises.first(where: { $0.id == set.prescriptionID }),
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

    private var advancedStrengthLifts: [LiftTierProgress] {
        projectedStrengthTierSummary.advancedLifts(comparedTo: appState.strengthTierSummary)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(Color.liftOnAccent)
                                .frame(width: 72, height: 72)
                                .background(Color.liftGreen)
                                .clipShape(Circle())
                            Text("Workout complete")
                                .font(.largeTitle.weight(.black))
                            Text(summary.workoutName)
                                .font(.headline)
                                .foregroundStyle(Color.liftMuted)
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

                        if let best = summary.bestSet {
                            let trackingKind = trackingKind(for: best)
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.liftGold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Best set")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                    Text(MeasurementFormatting.workoutSetText(set: best, trackingKind: trackingKind))
                                        .font(.headline.weight(.black))
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let previous = previousComparableWorkout {
                            comparisonSection(previous)
                        }

                        if !prCandidates.isEmpty {
                            prSubmissionSection
                        }

                        if !advancedStrengthLifts.isEmpty {
                            rivalTierProgressSection
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
                            onComplete(effort, notes, videoURLsBySetID, false)
                        }
                        .accessibilityIdentifier("workout.finish.save")
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                if !prCandidates.isEmpty && !didExplainAutomaticSubmission {
                    onExplanationShown()
                    showingAutomaticSubmissionExplanation = true
                }
            }
            .alert("Submit video-backed PRs automatically?", isPresented: $showingAutomaticSubmissionExplanation) {
                Button("Enable") {
                    automaticSubmissionEnabled = true
                    onAutomaticSubmissionChanged(true)
                }
                Button("Keep Private", role: .cancel) {
                    automaticSubmissionEnabled = false
                    onAutomaticSubmissionChanged(false)
                }
            } message: {
                Text("When enabled, only canonical lift PRs with an attached video are posted publicly as Video-backed. PRs without video stay private.")
            }
        }
    }

    private var rivalTierProgressSection: some View {
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
                    Text("Attach video now if you want an eligible PR to be submitted.")
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
                    Text("Automatically submit video-backed PRs")
                        .font(.subheadline.weight(.bold))
                    Text("Public • Video-backed • next daily ranking update")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftBlue)

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
                        .foregroundStyle(Color.liftBlue)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.liftBlue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !automaticSubmissionEnabled {
                Label("These PRs will remain private even if a video is attached.", systemImage: "lock.fill")
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

    private func projectedAchievementTitles() -> [String] {
        let stats = appState.competitiveStatistics
        let workoutCount = stats.totalWorkouts + 1
        let volumeKilograms = stats.lifetimeWorkingSetVolume + currentWorkoutVolumeKilograms
        let trainingTime = stats.totalActiveTrainingTime + activeDuration
        let repetitions = stats.totalWorkingSetRepetitions + currentWorkoutWorkingSetRepetitions
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
        return logs.filter { log in
            guard log.workoutID == workout.id,
                  log.isComplete,
                  !log.isWarmup,
                  let exercise = workout.exercises.first(where: { $0.id == log.prescriptionID }) else {
                return false
            }
            let rawTrackingType = exercise.trackingType ??
                catalog.first(where: { $0.id == exercise.exerciseID })?.trackingType
            return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps") == .weightReps
        }
    }

    private var currentWorkoutWorkingSetRepetitions: Int {
        currentWorkoutWorkingSets.reduce(0) { $0 + ($1.reps ?? 0) }
    }

    private var currentWorkoutVolumeKilograms: Double {
        let unit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
        let volume = currentWorkoutWorkingSets.reduce(0) { $0 + $1.volume(in: unit) }
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
                let url = try appState.persistWorkoutVideo(data)
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
                .foregroundStyle(Color.liftBlue)
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
