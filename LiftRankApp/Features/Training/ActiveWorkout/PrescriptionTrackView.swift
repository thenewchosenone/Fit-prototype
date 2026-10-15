import SwiftUI

struct PrescriptionTrackView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exercise: WorkoutExerciseSnapshot
    let catalogExercise: TrainingExerciseCatalogItem
    @State private var restEndsAt: Date?
    @State private var showingExerciseInfo = false
    @State private var activeLogs: [WorkoutSetLog] = []
    @State private var activeLogIDs: [UUID] = []
    @State private var cachedPreviousLogsBySetNumber: [Int: WorkoutSetLog] = [:]
    @FocusState private var focusedInput: WorkoutSetInputFocus?

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                if let restEndsAt {
                    restTimerBanner(endsAt: restEndsAt)
                }

                ScrollViewReader { proxy in
                    let logs = activeLogs
                    let completedLogs = completedLogs(in: logs)
                    let previousLogs = cachedPreviousLogsBySetNumber
                    let progress = appState.activeWorkoutDisplayState.progressByExerciseID[exercise.id]
                        ?? appState.activeWorkoutExerciseProgress(for: exercise)
                    let restMetric = "\(exercise.restSeconds)s"
                    let volumeMetric = "\(Int(completedVolume(in: completedLogs))) \(appState.activeWorkout?.unit.shortLabel ?? "lb")"
                    let activeUnit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
                    let targetLoad = exercise.targetLoadKilograms.map {
                        MeasurementFormatting.formatDisplayedWeight($0, unit: activeUnit)
                    }
                    let targetDetails = [
                        !ExerciseTrackingKind(catalogExercise.trackingType).usesDuration ? exercise.targetRIR.map { "\($0) reps in reserve" } : nil,
                        exercise.trainingMaxPercentage.map { "\(Int(($0 * 100).rounded()))% of training max" },
                        targetLoad
                    ].compactMap { $0 }.joined(separator: " · ")
                    let targetSummary = "Target: \(progress.plannedWorkingSets) × \(exercise.targetReps)" +
                        (targetDetails.isEmpty ? "" : " · \(targetDetails)")
                    let previousMetric = previousLogs[1].map {
                        "Last \($0.reps ?? 0) × \(RankingCalculator.format($0.weight ?? 0))"
                    }
                    List {
                            VStack(alignment: .leading, spacing: 12) {
                                if dynamicTypeSize.isAccessibilitySize {
                                    HStack(alignment: .center, spacing: 12) {
                                        ExerciseCatalogIcon(exercise: catalogExercise)
                                        Spacer(minLength: 0)
                                        Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                                            .font(.headline.weight(.black).monospacedDigit())
                                            .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftAccentText)
                                    }
                                    Text(exercise.exerciseName)
                                        .font(.title3.weight(.black))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(targetSummary)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    HStack(spacing: 12) {
                                        ExerciseCatalogIcon(exercise: catalogExercise)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(exercise.exerciseName)
                                                .font(.title3.weight(.black))
                                            Text(targetSummary)
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                                            .font(.headline.weight(.black).monospacedDigit())
                                            .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftAccentText)
                                    }
                                }

                                if !dynamicTypeSize.isAccessibilitySize {
                                    HStack(spacing: 8) {
                                        compactExerciseMetric(restMetric, "timer")
                                        compactExerciseMetric(volumeMetric, "scalemass")
                                        if let previousMetric {
                                            compactExerciseMetric(previousMetric, "clock.arrow.circlepath")
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.liftOverlay, lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                showingExerciseInfo = true
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Shows exercise information")
                            .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                            if let substitutionIDs = exercise.substitutionExerciseIDs,
                               !substitutionIDs.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Specific substitutions")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                    ForEach(Array(substitutionIDs.prefix(2).enumerated()), id: \.element) { index, exerciseID in
                                        if let substitute = appState.trainingExerciseLibrary.first(where: { $0.id == exerciseID }) {
                                            Button {
                                                _ = appState.substituteActiveWorkoutExercise(exercise, with: substitute)
                                            } label: {
                                                HStack {
                                                    Text("Option \(index + 1): \(substitute.name)")
                                                        .font(.subheadline.weight(.semibold))
                                                    Spacer()
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                        .font(.caption.weight(.bold))
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .foregroundStyle(Color.liftAccentText)
                                                .background(Color.liftCard)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityIdentifier("workout.specificSubstitution.\(exerciseID)")
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }

                            setColumnHeader
                                .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 4, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)

                            ForEach(logs) { log in
                                WorkoutSetLogRow(
                                    log: log,
                                    trackingKind: trackingKind,
                                    previousLog: previousLogs[log.setNumber],
                                    focusedInput: $focusedInput,
                                    onDelete: { appState.deleteSetLog($0) },
                                    onApplyCompletion: { appState.applyWorkoutSetCompletion($0, isComplete: $1, source: .manual) },
                                    onAttemptAutomaticCompletion: { appState.attemptAutomaticCompletion(before: $0) },
                                    onUpdate: { appState.updateSetLog($0) },
                                    onPersistImmediately: { appState.persistLocalWorkoutSnapshot() }
                                ) {
                                    startRestTimer()
                                }
                                .id(log.id)
                                .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        focusedInput = nil
                                        appState.deleteSetLog(log)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .tint(Color.liftRed)
                                }
                            }
                        }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.vertical, 8, for: .scrollContent)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    .onChange(of: focusedInput) { _, focus in
                        guard let focus else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(focus.logID, anchor: .center)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(keyboardActionTitle) {
                                advanceKeyboardFocus(using: proxy)
                            }
                            .font(.headline.weight(.bold))
                            .accessibilityIdentifier("workout.setInput.keyboardAction")
                        }
                    }
                }

                Button {
                    _ = appState.addSetLog(to: exercise)
                } label: {
                    Label("Add another set", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.liftCard)
                        .foregroundStyle(Color.liftAccentText)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.liftBlue.opacity(0.40), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Track exercise")
        .navigationBarTitleDisplayMode(.inline)
        .alert(catalogExercise.name, isPresented: $showingExerciseInfo) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(exerciseDescription(for: catalogExercise))
        }
        .onAppear {
            ensureTargetSetsExist()
            refreshActiveLogs()
            refreshPreviousLogs(for: activeLogs)
            restoreRestTimer()
        }
        .onChange(of: appState.workoutSetLogsRevision) {
            let previousSetNumbers = activeLogs.map(\.setNumber)
            guard refreshActiveLogs() else { return }
            guard previousSetNumbers != activeLogs.map(\.setNumber) else { return }
            refreshPreviousLogs(for: activeLogs)
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            refreshPreviousLogs(for: activeLogs)
        }
    }

    private var keyboardActionTitle: String {
        guard let focusedInput else { return "Next" }
        return WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs, trackingKind: trackingKind, alreadyOrdered: true) == nil ? "Done" : "Next"
    }

    private func advanceKeyboardFocus(using proxy: ScrollViewProxy) {
        guard let focusedInput else { return }
        guard let nextInput = WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs, trackingKind: trackingKind, alreadyOrdered: true) else {
            self.focusedInput = nil
            Haptics.light()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(nextInput.logID, anchor: .center)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.focusedInput == focusedInput else { return }
            self.focusedInput = nextInput
        }
        Haptics.light()
    }

    private func completedLogs(in logs: [WorkoutSetLog]) -> [WorkoutSetLog] {
        logs.filter(\.isComplete)
    }

    private func completedVolume(in logs: [WorkoutSetLog]) -> Double {
        logs.reduce(0) { total, log in
            total + setVolume(log)
        }
    }

    @discardableResult
    private func refreshActiveLogs() -> Bool {
        refreshActiveLogs(from: appState.workoutSetLogs)
    }

    @discardableResult
    private func refreshActiveLogs(from logs: [WorkoutSetLog]) -> Bool {
        guard let workoutID = appState.activeWorkout?.id else {
            activeLogs = []
            activeLogIDs = []
            return true
        }
        let updatedLogs = logs
            .filter { $0.workoutID == workoutID && $0.prescriptionID == exercise.id }
            .sorted { $0.setNumber < $1.setNumber }
        let updatedLogIDs = updatedLogs.map(\.id)
        guard updatedLogIDs != activeLogIDs || updatedLogs != activeLogs else { return false }
        activeLogs = updatedLogs
        activeLogIDs = updatedLogIDs
        return true
    }

    private func refreshPreviousLogs(for logs: [WorkoutSetLog]) {
        cachedPreviousLogsBySetNumber = appState.previousSetLogsBySetNumber(
            for: exercise,
            setNumbers: logs.map(\.setNumber)
        )
    }

    private var trackingKind: ExerciseTrackingKind {
        ExerciseTrackingKind(catalogExercise.trackingType)
    }

    private func compactExerciseMetric(_ value: String, _ symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.liftScrim)
            .clipShape(Capsule())
    }

    private func exerciseDescription(for exercise: TrainingExerciseCatalogItem) -> String {
        guard let guidance = exercise.guidance else {
            return "\(exercise.bodyPart) exercise using \(exercise.equipment)."
        }

        if guidance.cues.isEmpty {
            return guidance.summary
        }

        return "\(guidance.summary)\n\nCues: \(guidance.cues.joined(separator: " • "))"
    }

    @ViewBuilder
    private var setColumnHeader: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 8) {
                Text("SET").frame(width: 34)
                Text("PREVIOUS").frame(maxWidth: .infinity)
                Text(trackingKind.repsHeader).frame(width: 64)
                if trackingKind.requiresWeight {
                    Text(weightHeader).frame(width: 72)
                }
                Color.clear.frame(width: 38, height: 1)
            }
            .font(.caption2.weight(.black))
            .tracking(0.7)
            .foregroundStyle(Color.liftMuted)
            .padding(.horizontal, 10)
        }
    }

    private var weightHeader: String {
        trackingKind == .assistedBodyweight ? "ASSIST" : (appState.activeWorkout?.unit.shortLabel ?? "lb").uppercased()
    }

    private func setVolume(_ log: WorkoutSetLog) -> Double {
        switch trackingKind {
        case .weightReps:
            return log.volume(in: appState.activeWorkout?.unit ?? log.recordedUnit)
        case .bodyweightReps, .assistedBodyweight, .repsOnly, .time, .weightTime:
            return 0
        }
    }

    private func restTimerBanner(endsAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endsAt.timeIntervalSince(context.date)))
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftOnAccent)
                    .frame(width: 40, height: 40)
                    .background(Color.liftBlue)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftAccentText)
                    Text(remaining > 0 ? "\(remaining / 60):\(String(format: "%02d", remaining % 60))" : "Ready")
                        .font(.title2.weight(.black).monospacedDigit())
                }

                Spacer()

                Button("Skip") {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.liftCardRaised)
            .overlay(alignment: .bottom) {
                ProgressView(
                    value: Double(remaining),
                    total: Double(max(1, exercise.restSeconds))
                )
                .tint(Color.liftAccentText)
            }
            .onChange(of: remaining) { _, value in
                if value == 0 {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                    Haptics.success()
                }
            }
        }
    }

    private func ensureTargetSetsExist() {
        let existing = appState.setLogs(for: exercise).count
        guard existing == 0, exercise.targetSets > 0 else { return }
        for _ in existing..<exercise.targetSets {
            _ = appState.addSetLog(to: exercise, persistImmediately: false)
        }
    }

    private func startRestTimer() {
        guard appState.activeWorkout?.automaticRestTimerEnabled ?? appState.workoutPreferences.defaultRestTimerEnabled else { return }
        let end = Date.now.addingTimeInterval(TimeInterval(exercise.restSeconds))
        restEndsAt = end
        appState.updateActiveRestTimer(endsAt: end, exerciseID: exercise.id)
        SystemWorkoutRestNotificationScheduler.shared.schedule(endsAt: end, exerciseName: exercise.exerciseName)
    }

    private func restoreRestTimer() {
        guard let workout = appState.activeWorkout,
              workout.restTimerExerciseID == exercise.id,
              let end = workout.restTimerEndsAt else { return }
        if end > .now {
            restEndsAt = end
        } else {
            appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
        }
    }
}
