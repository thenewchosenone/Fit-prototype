import SwiftUI
import UIKit

struct PrescriptionTrackView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var restNotificationScheduler = SystemWorkoutRestNotificationScheduler.shared
    let exercise: WorkoutExerciseSnapshot
    let catalogExercise: TrainingExerciseCatalogItem
    var nextExerciseName: String? = nil
    var onNextExercise: (() -> Void)? = nil
    var onFinishWorkout: (() -> Void)? = nil
    @State private var restEndsAt: Date?
    @State private var restTimerExplanation: String?
    @State private var showingExerciseInfo = false
    @State private var showingExerciseHistory = false
    @State private var activeLogs: [WorkoutSetLog] = []
    @State private var activeLogIDs: [UUID] = []
    @State private var cachedPreviousLogsBySetNumber: [Int: WorkoutSetLog] = [:]
    @State private var pendingSubstitute: TrainingExerciseCatalogItem?
    @State private var completionRequest: UUID?
    @FocusState private var focusedInput: WorkoutSetInputFocus?

    private var usesAdaptiveProgression: Bool {
        trackingKind == .weightReps && appState.workoutPlanProgressionSettings.contains {
            $0.planID == appState.activeWorkout?.sourcePlanID && $0.method == .adaptive
        }
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                restTimerBanner(endsAt: restEndsAt)

                ScrollViewReader { proxy in
                    let logs = activeLogs
                    let completedLogs = completedLogs(in: logs)
                    let previousLogs = cachedPreviousLogsBySetNumber
                    let progress = appState.activeWorkoutDisplayState.progressByExerciseID[exercise.id]
                        ?? appState.activeWorkoutExerciseProgress(for: exercise)
                    let restMetric = "\(exercise.restSeconds)s"
                    let activeUnit = appState.activeWorkout?.unit ?? appState.currentProfile.preferredUnit
                    let volumeMetric = "Volume · \(MeasurementFormatting.formatRecordedVolume(completedVolume(in: completedLogs), recordedUnit: activeUnit, preferredUnit: activeUnit) { $0.formatted(.number.precision(.fractionLength(0...1))) })"
                    let targetLoad = exercise.targetLoadKilograms.map {
                        "Suggested load \(MeasurementFormatting.formatDisplayedWeight($0, unit: activeUnit))"
                    }
                    let targetDetails = [
                        !ExerciseTrackingKind(catalogExercise.trackingType).usesDuration ? exercise.targetRIR.map { "RPE \(10 - $0) · \($0) reps left" } : nil,
                        exercise.trainingMaxPercentage.map { "\(Int(($0 * 100).rounded()))% of training max" },
                        targetLoad
                    ].compactMap { $0 }.joined(separator: " · ")
                    let targetSummary = "Today's sets: \(progress.plannedWorkingSets) × \(exercise.targetReps)" +
                        (targetDetails.isEmpty ? "" : " · \(targetDetails)")
                    List {
                            VStack(alignment: .leading, spacing: 12) {
                                if dynamicTypeSize.isAccessibilitySize {
                                    HStack(alignment: .center, spacing: 12) {
                                        Spacer(minLength: 0)
                                        Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                                            .font(.headline.weight(.bold).monospacedDigit())
                                            .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftAccentText)
                                    }
                                    Text(exercise.exerciseName)
                                        .font(LiftTypography.sectionTitle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(targetSummary)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                } else {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(exercise.exerciseName)
                                                .font(LiftTypography.sectionTitle)
                                            Text(targetSummary)
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Text("\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                                            .font(.headline.weight(.bold).monospacedDigit())
                                            .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftAccentText)
                                    }

                                }

                                if showsMachineLoadChoice { machineLoadTypeSelector }
                                DisclosureGroup("History, form & rest") {
                                Text("RPE is effort out of 10: 7 means about 3 reps left; 8 means 2; 9 means 1; 10 means none.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                (dynamicTypeSize.isAccessibilitySize
                                 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                                 : AnyLayout(HStackLayout(spacing: 12))) {
                                    Button {
                                        showingExerciseHistory = true
                                    } label: {
                                        Label("History", systemImage: "clock.arrow.circlepath")
                                            .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
                                    }
                                    .accessibilityIdentifier("workout.exercise.history")
                                    Button {
                                        showingExerciseInfo = true
                                    } label: {
                                        Label("Form & details", systemImage: "info.circle")
                                            .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
                                    }
                                    .accessibilityIdentifier("workout.exercise.details")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                                .buttonStyle(.plain)

                                DisclosureGroup("Rest & progression") {
                                if let guidance = catalogExercise.guidance {
                                    DisclosureGroup("Form cues") {
                                        Text(guidance.summary)
                                        ForEach(guidance.cues, id: \.self) { cue in
                                            Text("• \(cue)")
                                        }
                                    }
                                    .font(.caption)
                                    .tint(Color.liftAccentText)
                                }
                                if let settings = appState.workoutPlanProgressionSettings.first(where: {
                                    $0.planID == appState.activeWorkout?.sourcePlanID
                                }) {
                                    DisclosureGroup("How your target weight is chosen") {
                                        Text(settings.method.guidance)
                                        if !exercise.notes.isEmpty { Text(exercise.notes) }
                                        Text("Suggested targets are training guidance. You can change the weight you log.")
                                    }
                                    .font(.caption)
                                    .tint(Color.liftAccentText)
                                }
                                Toggle("Adjust rest to logged effort", isOn: Binding(
                                    get: { appState.workoutPreferences.adaptiveRestTimerEnabled == true },
                                    set: { appState.setAdaptiveRestTimerEnabled($0) }
                                ))
                                .font(.caption)
                                .tint(Color.liftAccentText)
                                .accessibilityHint("RPE 9–10 adds 30 seconds; RPE 1–6 removes up to 15 seconds. Without effort, prescribed rest is used.")
                                if appState.workoutPreferences.adaptiveRestTimerEnabled == true {
                                    Text("RPE 9–10: +30s · RPE 1–6: up to −15s. No effort logged: prescribed rest.")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }

                                if !dynamicTypeSize.isAccessibilitySize {
                                    HStack(spacing: 8) {
                                        compactExerciseMetric(restMetric, "timer")
                                        compactExerciseMetric(volumeMetric, "scalemass")
                                    }
                                }

                                }
                                .font(.caption)
                                .tint(Color.liftAccentText)
                                }
                                .font(.caption)
                                .tint(Color.liftMuted)
                            }
                            .padding(14)
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.liftOverlay, lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                            if let substitutionIDs = exercise.substitutionExerciseIDs,
                               !substitutionIDs.isEmpty {
                                DisclosureGroup("Specific substitutions") {
                                    ForEach(Array(substitutionIDs.prefix(2).enumerated()), id: \.element) { index, exerciseID in
                                        if let substitute = appState.trainingExerciseLibrary.first(where: { $0.id == exerciseID }) {
                                            Button {
                                                if activeLogs.contains(where: {
                                                    !$0.isComplete && ($0.weight != nil || $0.reps != nil || $0.rpe != nil)
                                                }) {
                                                    pendingSubstitute = substitute
                                                } else {
                                                    _ = appState.substituteActiveWorkoutExercise(exercise, with: substitute)
                                                }
                                            } label: {
                                                HStack {
                                                    Text("Option \(index + 1): \(substitute.name)")
                                                        .font(.subheadline.weight(.semibold))
                                                    Spacer()
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                        .font(LiftTypography.compactEmphasis)
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
                                .font(.caption)
                                .tint(Color.liftAccentText)
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
                                    lastCompletedLog: logs.last(where: { $0.setNumber < log.setNumber && $0.isComplete && !$0.isWarmup }),
                                    showsEffortControls: usesAdaptiveProgression || appState.workoutPreferences.adaptiveRestTimerEnabled == true,
                                    focusedInput: $focusedInput,
                                    completionRequest: $completionRequest,
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
                                            .foregroundStyle(Color.liftBackground)
                                    }
                                    .tint(Color.liftRed)
                                }
                            }
                            Button {
                                _ = appState.addSetLog(to: exercise)
                            } label: {
                                Label("Add another set", systemImage: "plus")
                                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                            }
                            .foregroundStyle(Color.liftAccentText)
                            .listRowBackground(Color.clear)
                        }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.vertical, 8, for: .scrollContent)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    .onChange(of: focusedInput) { _, focus in
                        guard let focus else { return }
                        DispatchQueue.main.async {
                            guard focusedInput == focus else { return }
                            proxy.scrollTo(focus, anchor: .center)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button {
                                focusedInput = nil
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil,
                                    from: nil,
                                    for: nil
                                )
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .frame(minWidth: LiftDesign.minimumTouchTarget, minHeight: LiftDesign.minimumTouchTarget)
                            }
                            .accessibilityLabel("Hide keyboard")
                            .accessibilityIdentifier("workout.setInput.hideKeyboard")
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            Spacer()
                            Button(keyboardActionTitle) {
                                advanceKeyboardFocus()
                            }
                            .font(LiftTypography.cardTitle)
                            .accessibilityIdentifier("workout.setInput.keyboardAction")
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                    }
                }

                if focusedInput == nil, appState.activeWorkoutExerciseProgress(for: exercise).isComplete {
                    PrimaryButton(
                        title: nextExerciseName.map { "Next: \($0)" } ?? (onFinishWorkout == nil ? "Back to workout" : "Finish workout"),
                        symbolName: nextExerciseName == nil ? "checkmark" : "arrow.right"
                    ) {
                        if let onNextExercise { onNextExercise() }
                        else if let onFinishWorkout { onFinishWorkout() }
                        else { dismiss() }
                    }
                    .accessibilityIdentifier("workout.exercise.continue")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle("Track exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Copy last set to empty sets") {
                        focusedInput = nil
                        appState.activeWorkoutStore.copyLastCompletedSetToEmptySets(in: exercise)
                        appState.persistLocalWorkoutSnapshot()
                    }
                    .disabled(!activeLogs.contains { $0.isComplete && !$0.isWarmup })
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Set actions")
            }
        }
        .confirmationDialog(
            "Clear unfinished set entries?",
            isPresented: Binding(get: { pendingSubstitute != nil }, set: { if !$0 { pendingSubstitute = nil } }),
            titleVisibility: .visible
        ) {
            Button("Clear entries and substitute") {
                if let pendingSubstitute {
                    _ = appState.substituteActiveWorkoutExercise(exercise, with: pendingSubstitute)
                }
                pendingSubstitute = nil
            }
            Button("Keep editing", role: .cancel) { pendingSubstitute = nil }
        } message: {
            Text("Unfinished weight, reps, and effort for \(exercise.exerciseName) will be cleared. Completed sets stay in this workout.")
        }
        .navigationDestination(isPresented: $showingExerciseInfo) {
            ExerciseLibraryDetailView(exercise: catalogExercise)
                .environmentObject(appState)
        }
        .navigationDestination(isPresented: $showingExerciseHistory) {
            ExerciseLibraryDetailView(
                exercise: catalogExercise,
                startsOnHistory: true,
                machineLoadType: exercise.machineLoadType,
                filtersByMachineLoadType: showsMachineLoadChoice
            )
                .environmentObject(appState)
        }
        .onAppear {
            ensureTargetSetsExist()
            refreshActiveLogs()
            refreshPreviousLogs(for: activeLogs)
            restoreRestTimer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let restEndsAt, restEndsAt > .now, let restExerciseName {
                restNotificationScheduler.schedule(endsAt: restEndsAt, exerciseName: restExerciseName)
            }
        }
        .onChange(of: appState.activeWorkout?.restTimerEndsAt) { _, end in
            if end == nil { restEndsAt = nil }
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
        .onChange(of: exercise.machineLoadType) {
            refreshPreviousLogs(for: activeLogs)
        }
    }

    private var keyboardActionTitle: String {
        focusedInput?.field == .reps ? "Log set" : "Next"
    }

    private func advanceKeyboardFocus() {
        guard let focusedInput else { return }
        if focusedInput.field == .reps {
            completionRequest = focusedInput.logID
            return
        }
        self.focusedInput = WorkoutSetInputNavigator.next(after: focusedInput, in: activeLogs, trackingKind: trackingKind, alreadyOrdered: true)
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

    private var showsMachineLoadChoice: Bool {
        catalogExercise.equipment.localizedCaseInsensitiveContains("machine") ||
            catalogExercise.name.localizedCaseInsensitiveContains("pullover")
    }

    private var machineLoadTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.machineLoadType.map { "Machine setup · \($0.rawValue)" } ?? "Choose machine setup")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 8) {
                ForEach(MachineLoadType.allCases) { type in
                    Button(type.rawValue) {
                        appState.setActiveWorkoutMachineLoadType(for: exercise.id, type: type)
                        refreshPreviousLogs(for: activeLogs)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(exercise.machineLoadType == type ? Color.liftAccentText : Color.liftCardRaised)
                    .foregroundStyle(exercise.machineLoadType == type ? Color.liftBackground : Color.liftText)
                    .accessibilityAddTraits(exercise.machineLoadType == type ? .isSelected : [])
                }
            }
        }
    }

    private func compactExerciseMetric(_ value: String, _ symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftText)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.liftCardRaised)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var setColumnHeader: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 6) {
                Text("SET").frame(width: 34)
                Text(trackingKind.requiresWeight ? "PREV \((appState.activeWorkout?.unit.shortLabel ?? "lb").uppercased())" : "PREV")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Previous workout")
                if trackingKind.requiresWeight {
                    Text(weightHeader).frame(width: 64)
                }
                Text(trackingKind.repsHeader).frame(width: 56)
                Color.clear.frame(width: LiftDesign.minimumTouchTarget, height: 1)
                Color.clear.frame(width: LiftDesign.minimumTouchTarget, height: 1)
            }
            .font(.caption2.weight(.bold))
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

    private func restTimerBanner(endsAt: Date?) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = endsAt.map { max(0, Int(ceil($0.timeIntervalSince(context.date)))) }
            (dynamicTypeSize.isAccessibilitySize
             ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
             : AnyLayout(HStackLayout(spacing: 12))) {
                Menu {
                    Text(restAlertStatusText)
                    if let restTimerExplanation { Text(restTimerExplanation) }
                    if restNotificationScheduler.status == .blocked || restNotificationScheduler.status == .failed {
                        Button("Notification settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } label: {
                    Label(
                        remaining.map { "Rest · \(MeasurementFormatting.shortClockText(TimeInterval($0)))" }
                            ?? "Rest · \(MeasurementFormatting.shortClockText(TimeInterval(exercise.restSeconds)))",
                        systemImage: "timer"
                    )
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .accessibilityLabel(remaining == nil ? "Rest between sets" : "Rest remaining")
                .accessibilityValue(remaining.map { "\($0) seconds" } ?? "\(exercise.restSeconds) seconds")
                .accessibilityHint(restAlertStatusText)
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                Button("+30s") {
                    guard let endsAt else { return }
                    let end = endsAt.addingTimeInterval(30)
                    restEndsAt = end
                    appState.updateActiveRestTimer(endsAt: end, exerciseID: appState.activeWorkout?.restTimerExerciseID)
                    if let restExerciseName {
                        restNotificationScheduler.schedule(endsAt: end, exerciseName: restExerciseName)
                    }
                }
                .accessibilityLabel("Add 30 seconds of rest")
                .frame(minWidth: 44, minHeight: 44)
                .disabled(endsAt == nil)
                .opacity(endsAt == nil ? 0 : 1)
                Button("Skip") {
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                }
                .accessibilityLabel("Skip rest")
                .frame(minWidth: 44, minHeight: 44)
                .disabled(endsAt == nil)
                .opacity(endsAt == nil ? 0 : 1)
                }
                .accessibilityHidden(endsAt == nil)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.liftAccentText)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Color.liftCardRaised)
            .onChange(of: remaining) { _, value in
                guard value == 0, self.restEndsAt == endsAt else { return }
                let needsSound = restNotificationScheduler.status != .scheduled && restNotificationScheduler.status != .quiet
                Task { @MainActor in
                    if !needsSound { try? await Task.sleep(for: .seconds(2)) }
                    guard self.restEndsAt == endsAt else { return }
                    restEndsAt = nil
                    appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
                    if needsSound { WorkoutRestTimerAlertSound.shared.play() }
                    Haptics.success()
                }
            }
        }
    }

    private var restAlertStatusText: String {
        switch restNotificationScheduler.status {
        case .inactive: return "Background alert not confirmed"
        case .checking: return "Setting up alert…"
        case .scheduled: return "Background alert on"
        case .quiet: return "Quiet alert"
        case .blocked: return "Background alert off"
        case .failed: return "Background alert unavailable"
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
        let latest = appState.setLogs(for: exercise)
            .filter { $0.isComplete }
            .max { $0.performedAt < $1.performedAt }
        let seconds = appState.workoutPreferences.adaptiveRestTimerEnabled == true
            ? WorkoutAdaptiveProgression.restSeconds(base: exercise.restSeconds, rpe: latest?.isWarmup == false ? latest?.rpe : nil)
            : exercise.restSeconds
        guard seconds > 0 else { return }
        restTimerExplanation = seconds > exercise.restSeconds ? "Rest · +30s for effort"
            : seconds < exercise.restSeconds ? "Rest · lighter effort" : nil
        let end = Date.now.addingTimeInterval(TimeInterval(seconds))
        restEndsAt = end
        appState.updateActiveRestTimer(endsAt: end, exerciseID: exercise.id)
        SystemWorkoutRestNotificationScheduler.shared.schedule(endsAt: end, exerciseName: exercise.exerciseName)
    }

    private func restoreRestTimer() {
        guard let workout = appState.activeWorkout,
              let end = workout.restTimerEndsAt else { return }
        if end > .now {
            restEndsAt = end
            if let restExerciseName {
                restNotificationScheduler.schedule(endsAt: end, exerciseName: restExerciseName)
            }
        } else {
            appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
        }
    }

    private var restExerciseName: String? {
        guard let workout = appState.activeWorkout else { return nil }
        return workout.exercises.first { $0.id == workout.restTimerExerciseID }?.exerciseName
    }
}

enum WorkoutSetInputField: String, Hashable {
    case reps
    case weight
}

struct WorkoutSetInputFocus: Hashable {
    let logID: UUID
    let field: WorkoutSetInputField
}

enum WorkoutSetInputNavigator {
    static func orderedFocuses(
        for logs: [WorkoutSetLog],
        trackingKind: ExerciseTrackingKind = .weightReps,
        alreadyOrdered: Bool = false
    ) -> [WorkoutSetInputFocus] {
        let orderedLogs = alreadyOrdered ? logs : logs.sorted { $0.setNumber < $1.setNumber }
        return orderedLogs.flatMap { log in
            if trackingKind.requiresWeight {
                return [
                    WorkoutSetInputFocus(logID: log.id, field: .weight),
                    WorkoutSetInputFocus(logID: log.id, field: .reps)
                ]
            }
            return [WorkoutSetInputFocus(logID: log.id, field: .reps)]
        }
    }

    static func next(
        after current: WorkoutSetInputFocus,
        in logs: [WorkoutSetLog],
        trackingKind: ExerciseTrackingKind = .weightReps,
        alreadyOrdered: Bool = false
    ) -> WorkoutSetInputFocus? {
        let focuses = orderedFocuses(for: logs, trackingKind: trackingKind, alreadyOrdered: alreadyOrdered)
        guard let index = focuses.firstIndex(of: current), focuses.indices.contains(index + 1) else {
            return nil
        }
        return focuses[index + 1]
    }
}
