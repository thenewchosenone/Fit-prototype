import SwiftUI

struct PrescriptionTrackView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: WorkoutExerciseSnapshot
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            let logs = activeLogs
                            let completedLogs = completedLogs(in: logs)
                            let previousLogs = cachedPreviousLogsBySetNumber
                            let progress = appState.activeWorkoutDisplayState.progressByExerciseID[exercise.id]
                                ?? appState.activeWorkoutExerciseProgress(for: exercise)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    ExerciseCatalogIcon(exercise: catalogExercise)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(exercise.exerciseName)
                                            .font(.title3.weight(.black))
                                        Text("Target: \(progress.plannedWorkingSets) × \(exercise.targetReps)")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    Spacer()
                                    Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                                        .font(.headline.weight(.black).monospacedDigit())
                                        .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftBlue)
                                }

                                HStack(spacing: 8) {
                                    compactExerciseMetric("\(exercise.restSeconds)s", "timer")
                                    compactExerciseMetric("\(Int(completedVolume(in: completedLogs))) \(appState.activeWorkout?.unit.shortLabel ?? "lb")", "scalemass")
                                    if let previous = previousLogs[1] {
                                        compactExerciseMetric("Last \(previous.reps ?? 0) × \(RankingCalculator.format(previous.weight ?? 0))", "clock.arrow.circlepath")
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                showingExerciseInfo = true
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Shows exercise information")

                            setColumnHeader

                            ForEach(logs) { log in
                                WorkoutSetLogRow(
                                    log: log,
                                    trackingKind: trackingKind,
                                    previousLog: previousLogs[log.setNumber],
                                    focusedInput: $focusedInput
                                ) {
                                    startRestTimer()
                                }
                                .environmentObject(appState)
                                .id(log.id)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 18)
                    }
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
                }

                Button {
                    _ = appState.addSetLog(to: exercise)
                } label: {
                    Label("Add another set", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.liftCard)
                        .foregroundStyle(Color.liftBlue)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(keyboardActionTitle) {
                    advanceKeyboardFocus()
                }
                .font(.headline.weight(.bold))
                .accessibilityIdentifier("workout.setInput.keyboardAction")
            }
        }
        .onAppear {
            ensureTargetSetsExist()
            refreshActiveLogs()
            refreshPreviousLogs(for: activeLogs)
            restoreRestTimer()
        }
        .onChange(of: appState.workoutSetLogs) { _, logs in
            let previousSetNumbers = activeLogs.map(\.setNumber)
            guard refreshActiveLogs(from: logs) else { return }
            guard previousSetNumbers != activeLogs.map(\.setNumber) else { return }
            refreshPreviousLogs(for: activeLogs)
        }
        .onChange(of: appState.completedWorkouts.count) {
            refreshPreviousLogs(for: activeLogs)
        }
    }

    private var keyboardActionTitle: String {
        guard let focusedInput else { return "Next" }
        return WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs, trackingKind: trackingKind, alreadyOrdered: true) == nil ? "Done" : "Next"
    }

    private func advanceKeyboardFocus() {
        guard let focusedInput else { return }
        guard let nextInput = WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs, trackingKind: trackingKind, alreadyOrdered: true) else {
            self.focusedInput = nil
            Haptics.light()
            return
        }
        self.focusedInput = nextInput
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

    private func refreshActiveLogs() {
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

    private var catalogExercise: TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ??
            TrainingExerciseCatalogItem(
                id: exercise.exerciseID,
                name: exercise.exerciseName,
                bodyPart: exercise.bodyPart,
                workoutCategory: exercise.bodyPart,
                defaultSets: exercise.targetSets,
                defaultReps: exercise.targetReps,
                symbolName: "dumbbell.fill",
                equipment: exercise.equipment,
                muscleProfile: exercise.muscleProfile,
                rankingExerciseID: exercise.rankingExerciseID
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
            .background(Color.black.opacity(0.16))
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

    private var setColumnHeader: some View {
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
                        .foregroundStyle(Color.liftBlue)
                    Text(remaining > 0 ? "\(remaining / 60):\(String(format: "%02d", remaining % 60))" : "Ready")
                        .font(.title2.weight(.black).monospacedDigit())
                }

                Spacer()

                Button("Skip") {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.liftBlue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.liftCardRaised)
            .overlay(alignment: .bottom) {
                ProgressView(
                    value: Double(remaining),
                    total: Double(max(1, exercise.restSeconds))
                )
                .tint(Color.liftBlue)
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
        appState.persistLocalWorkoutSnapshot()
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
