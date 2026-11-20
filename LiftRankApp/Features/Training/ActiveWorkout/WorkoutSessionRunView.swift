import PhotosUI
import SwiftUI

private enum WorkoutSessionSheet: Identifiable {
    case summary(WorkoutSummary)
    case addExercise
    case substitute(WorkoutExerciseSnapshot)

    var id: String {
        switch self {
        case let .summary(summary):
            return "summary-\(summary.id.uuidString)"
        case .addExercise:
            return "addExercise"
        case let .substitute(exercise):
            return "substitute-\(exercise.id.uuidString)"
        }
    }
}

struct WorkoutSessionRunView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var presentedSheet: WorkoutSessionSheet?
    @State private var showingCancelConfirmation = false
    @State private var showingSkipConfirmation = false
    @State private var showingEmptyWorkoutConfirmation = false
    @State private var isReorderingExercises = false
    @State private var exerciseToRemove: WorkoutExerciseSnapshot?
    @State private var dismissAfterSummary = false
    @State private var reviewDraftWorkoutID: UUID?
    @State private var reviewEffort = 0
    @State private var reviewNotes = ""
    @State private var reviewSharesPRs = false
    @State private var reviewSelectedPRSetIDs: Set<UUID> = []
    @State private var reviewVideoItems: [UUID: PhotosPickerItem] = [:]
    @State private var reviewVideoURLs: [UUID: URL] = [:]
    @State private var catalogByID: [String: TrainingExerciseCatalogItem] = [:]
    @State private var exercisePath: [UUID] = []
    @State private var resumeAfterReview = false

    private var workout: ActiveWorkoutState? { appState.activeWorkout }

    var body: some View {
        NavigationStack(path: $exercisePath) {
            AppBackground {
                if let workout {
                    let displayState = appState.activeWorkoutDisplayState
                    VStack(spacing: 0) {
                        activeHeader(workout, displayState: displayState)
                        List {
                            Group {
                                if displayState.exercises.isEmpty {
                                    emptyCard
                                } else {
                                    HStack {
                                        Text("Exercises")
                                            .font(LiftTypography.sectionTitle)
                                        Spacer()
                                        if isReorderingExercises {
                                            Text("Reorder mode")
                                                .font(LiftTypography.compactEmphasis)
                                                .foregroundStyle(Color.liftAccentText)
                                        }
                                    }

                                    ForEach(displayState.exercises) { exercise in
                                        let progress = displayState.progressByExerciseID[exercise.id]
                                            ?? appState.activeWorkoutExerciseProgress(for: exercise)
                                        NavigationLink(value: exercise.id) {
                                            exerciseCard(
                                                exercise,
                                                progress: progress
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("workout.exercise.\(exercise.id.uuidString)")
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                requestRemoveExercise(exercise)
                                            } label: {
                                                Label(progress.isComplete ? "Delete" : "Remove", systemImage: "trash.fill")
                                                    .foregroundStyle(Color.liftBackground)
                                            }
                                            .tint(Color.liftRed)
                                            if !progress.isComplete {
                                                Button {
                                                    presentedSheet = .substitute(exercise)
                                                } label: {
                                                    Label("Substitute", systemImage: "arrow.triangle.2.circlepath")
                                                        .foregroundStyle(Color.liftOnAccent)
                                                }
                                                .tint(Color.liftBlue)
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                guard !progress.isComplete else { return }
                                                presentedSheet = .substitute(exercise)
                                            } label: {
                                                Label("Find Substitute", systemImage: "arrow.triangle.2.circlepath")
                                            }
                                            .disabled(progress.isComplete)
                                            Button {
                                                _ = appState.moveActiveWorkoutExercise(exercise, direction: -1)
                                            } label: {
                                                Label("Move Up", systemImage: "arrow.up")
                                            }
                                            Button {
                                                _ = appState.moveActiveWorkoutExercise(exercise, direction: 1)
                                            } label: {
                                                Label("Move Down", systemImage: "arrow.down")
                                            }
                                            Button(role: .destructive) {
                                                requestRemoveExercise(exercise)
                                            } label: {
                                                Label(progress.isComplete ? "Delete from this workout" : "Remove from this workout", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .contentMargins(.vertical, 10, for: .scrollContent)
                        if !displayState.exercises.isEmpty { workoutControls }
                    }
                } else if !dismissAfterSummary {
                    LiftEmptyState(
                        title: "No active workout",
                        message: "Return to Track to review your history or start a workout.",
                        symbolName: "checkmark.circle.fill",
                        actionTitle: "Return to Track"
                    ) { dismiss() }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { exerciseID in
                if let exercise = workout?.exercises.first(where: { $0.id == exerciseID }) {
                    let next = appState.activeWorkoutDisplayState.exercises.first {
                        $0.id != exercise.id && !appState.activeWorkoutExerciseProgress(for: $0).isComplete
                    }
                    PrescriptionTrackView(
                        exercise: exercise,
                        catalogExercise: catalogByID[exercise.exerciseID] ?? exercise.fallbackCatalogExercise,
                        nextExerciseName: next?.exerciseName,
                        onNextExercise: next.map { next in { exercisePath = [next.id] } },
                        onFinishWorkout: {
                            if let summary = prepareSummaryReview() { presentedSheet = .summary(summary) }
                        }
                    )
                    .id(exercise.id)
                    .environmentObject(appState)
                }
            }
            .task(id: appState.exerciseLibraryStore.customExercisesRevision) {
                catalogByID = Dictionary(
                    uniqueKeysWithValues: appState.trainingExerciseLibrary.map { ($0.id, $0) }
                )
            }
            .sheet(item: $presentedSheet, onDismiss: {
                if dismissAfterSummary { dismiss() }
                else if resumeAfterReview { appState.resumeActiveWorkout() }
                resumeAfterReview = false
            }) { sheet in
                switch sheet {
                case let .summary(summary):
                    WorkoutSummaryView(
                        summary: summary,
                        effort: $reviewEffort,
                        notes: $reviewNotes,
                        sharePRs: $reviewSharesPRs,
                        selectedPRSetIDs: $reviewSelectedPRSetIDs,
                        selectedVideoItems: $reviewVideoItems,
                        videoURLsBySetID: $reviewVideoURLs,
                        onDone: { dismiss() }
                    ) { effort, notes, videos, selectedSetIDs in
                        guard let completed = appState.finishActiveWorkout(effort: effort, notes: notes) else { return false }
                        dismissAfterSummary = true
                        Task {
                            await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: videos, selectedSetIDs: selectedSetIDs)
                        }
                        return true
                    }
                    .environmentObject(appState)
                case .addExercise:
                    ActiveWorkoutAddExercisePickerView()
                        .environmentObject(appState)
                        .presentationDetents([.large])
                case let .substitute(exercise):
                    ActiveWorkoutSubstitutePickerView(exercise: exercise)
                        .environmentObject(appState)
                        .presentationDetents([.large])

                }
            }
            .confirmationDialog("Remove exercise and its sets?", isPresented: Binding(
                get: { exerciseToRemove != nil },
                set: { if !$0 { exerciseToRemove = nil } }
            ), titleVisibility: .visible) {
                Button("Remove exercise", role: .destructive) {
                    if let exerciseToRemove { appState.removeExerciseFromActiveWorkout(exerciseToRemove) }
                    exerciseToRemove = nil
                }
                Button("Keep exercise", role: .cancel) { exerciseToRemove = nil }
            } message: {
                if let exerciseToRemove {
                    Text("\(exerciseToRemove.exerciseName): \(enteredSets(for: exerciseToRemove)) entered sets will be removed from this workout.")
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    appState.discardActiveWorkout()
                    dismiss()
                }
                Button("Keep Working Out", role: .cancel) {}
            } message: {
                Text("All sets in this active workout will be permanently discarded. Your plan is not changed.")
            }
            .confirmationDialog("Skip this planned workout?", isPresented: $showingSkipConfirmation, titleVisibility: .visible) {
                Button("Skip Planned Workout", role: .destructive) {
                    appState.markWorkoutSessionOutcome(.skipped, for: appState.activeWorkout?.sourceSessionID)
                    appState.discardActiveWorkout()
                    dismiss()
                }
                Button("Mark Rest Day") {
                    appState.markWorkoutSessionOutcome(.rest, for: appState.activeWorkout?.sourceSessionID)
                    appState.discardActiveWorkout()
                    dismiss()
                }
                Button("Keep Training", role: .cancel) {}
            } message: {
                Text("Choose Skip when you did not complete this planned workout, or Rest Day when recovery was intentional. Neither is added to workout history or counted as completed.")
            }
            .confirmationDialog(
                "End this empty workout?",
                isPresented: $showingEmptyWorkoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("End Workout", role: .destructive) {
                    appState.discardActiveWorkout()
                    dismiss()
                }
                Button("Keep Training", role: .cancel) {}
            } message: {
                Text("No working sets have been completed, so this workout will not be added to your history.")
            }
        }
    }

    private func elapsedText(_ workout: ActiveWorkoutState, at date: Date) -> String {
        return MeasurementFormatting.longClockText(Int(workout.elapsedDuration(at: date)))
    }

    private func activeHeader(_ workout: ActiveWorkoutState, displayState: ActiveWorkoutDisplayState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(LiftTypography.cardTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize workout")

                VStack(alignment: .leading, spacing: 4) {
                    Text((workout.historyDate ?? workout.startedAt).formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftAccentText)
                    Text(workout.name)
                        .font(LiftTypography.cardTitle)
                        .lineLimit(2)
                }

                Spacer()

                if workout.pausedAt == nil {
                    TimelineView(.periodic(from: .now, by: 5)) { context in
                        Text(elapsedText(workout, at: context.date))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.liftAccentText)
                    }
                } else {
                    Text(elapsedText(workout, at: workout.pausedAt ?? .now))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.liftAccentText)
                }

                Menu {
                    Button {
                        workout.pausedAt == nil ? appState.pauseActiveWorkout() : appState.resumeActiveWorkout()
                    } label: {
                        Label(workout.pausedAt == nil ? "Pause Workout" : "Resume Workout", systemImage: workout.pausedAt == nil ? "pause.fill" : "play.fill")
                    }
                    if workout.exercises.count > 1 {
                    Button {
                        isReorderingExercises.toggle()
                    } label: {
                        Label(isReorderingExercises ? "Done Reordering" : "Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }
                    }
                    Button { presentedSheet = .addExercise } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    if workout.sourceSessionID != nil {
                        Button {
                            _ = appState.updateSourcePlanFromActiveWorkout()
                        } label: {
                            Label("Update Plan from Workout", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    if workout.source == .planned && workout.exercises.isEmpty {
                        Button("Skip planned workout", systemImage: "forward.end.fill") { showingSkipConfirmation = true }
                    }
                    Button(role: .destructive) { showingCancelConfirmation = true } label: {
                        Label("Discard Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(LiftTypography.cardTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Workout options")
            }

            if workout.pausedAt != nil {
                Label("Workout paused", systemImage: "pause.circle.fill")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftGold)
            }

            if let endsAt = workout.restTimerEndsAt,
               let exerciseID = workout.restTimerExerciseID,
               let exercise = workout.exercises.first(where: { $0.id == exerciseID }) {
                HStack {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label("Rest · \(MeasurementFormatting.shortClockText(seconds: max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))))", systemImage: "timer")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    Text(exercise.exerciseName)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                    Spacer()
                    Button("End") { appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil) }
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 12)
                .background(Color.liftBlue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .contain)
            }

            if !displayState.exercises.isEmpty {
            ProgressView(value: Double(displayState.completedWorkingSets), total: Double(max(1, displayState.plannedWorkingSets)))
                .tint(Color.liftAccentText)

            HStack(spacing: 14) {
                Label("\(displayState.completedExercises)/\(displayState.exercises.count) exercises", systemImage: "dumbbell.fill")
                Label("\(displayState.completedWorkingSets)/\(displayState.plannedWorkingSets) sets", systemImage: "checkmark.circle.fill")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Volume").font(.caption2)
                    Text("\(Int(displayState.totalVolume.rounded()).formatted()) \(workout.unit.shortLabel)")
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)

            }
            Toggle(isOn: Binding(
                get: { workout.automaticRestTimerEnabled },
                set: { appState.setAutomaticRestTimerEnabledForActiveWorkout($0) }
            )) {
                Label("Auto rest timer", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
            .tint(Color.liftAccentText)
            .accessibilityHint("Starts the prescribed rest countdown when a working set is completed")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.liftCardRaised)
        .overlay(alignment: .bottom) { Divider().overlay(Color.liftOverlay) }
    }

    private func enteredSets(for exercise: WorkoutExerciseSnapshot) -> Int {
        appState.setLogs(for: exercise).filter { $0.isComplete || $0.weight != nil || $0.reps != nil || $0.rpe != nil }.count
    }

    private func requestRemoveExercise(_ exercise: WorkoutExerciseSnapshot) {
        if enteredSets(for: exercise) > 0 { exerciseToRemove = exercise }
        else { appState.removeExerciseFromActiveWorkout(exercise) }
    }

    private var emptyCard: some View {
        LiftEmptyState(
            title: "Build this workout",
            message: "Add exercises from the library, then log at least one working set.",
            symbolName: "dumbbell.fill",
            actionTitle: "Add first exercise"
        ) { presentedSheet = .addExercise }
    }

    private func exerciseCard(
        _ exercise: WorkoutExerciseSnapshot,
        progress: ActiveWorkoutExerciseProgress
    ) -> some View {
        HStack(spacing: 12) {
            if isReorderingExercises {
                VStack(spacing: 6) {
                    Button {
                        _ = appState.moveActiveWorkoutExercise(exercise, direction: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(LiftTypography.compactEmphasis)
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Button {
                        _ = appState.moveActiveWorkoutExercise(exercise, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(LiftTypography.compactEmphasis)
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }
                .foregroundStyle(Color.liftAccentText)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.exerciseName)
                    .font(LiftTypography.cardTitle)
                    .foregroundStyle(Color.liftText)
                Text("\(progress.plannedWorkingSets) × \(exercise.targetReps)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                if let rest = exercise.supersetRestSeconds {
                    let partner = appState.activeWorkout?.exercises.first {
                        $0.id != exercise.id && $0.supersetGroup == exercise.supersetGroup
                    }?.exerciseName
                    Text("Superset with \(partner ?? "paired exercise") · rest \(activeRestTimeLabel(rest)) after each round")
                        .font(.caption2)
                        .foregroundStyle(Color.liftAccentText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Menu {
                    ForEach([60, 90, 120, 180, 240, 300], id: \.self) { seconds in
                        Button(activeRestTimeLabel(seconds)) {
                            appState.setActiveWorkoutRestTime(for: exercise.id, seconds: seconds)
                        }
                    }
                } label: {
                    Label("Rest: \(activeRestTimeLabel(exercise.restSeconds))", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftAccentText)
                }
                .accessibilityLabel("Rest time, \(activeRestTimeLabel(exercise.restSeconds))")
                .accessibilityHint("Choose a different rest timer for this exercise")
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(progress.isComplete ? "Done" : "\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftMuted)
            }
        }
        .padding(12)
        .background(progress.isComplete ? Color.liftGreen.opacity(0.08) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(progress.isComplete ? Color.liftGreen.opacity(0.28) : Color.liftOverlay, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private func activeRestTimeLabel(_ seconds: Int) -> String {
        seconds.isMultiple(of: 60) ? "\(seconds / 60) min" : "\(seconds) sec"
    }

    private func prepareSummaryReview() -> WorkoutSummary? {
        guard let workout = appState.activeWorkout else { return nil }
        resumeAfterReview = workout.pausedAt == nil
        if resumeAfterReview { appState.pauseActiveWorkout() }
        appState.updateActiveRestTimer(endsAt: nil, exerciseID: nil)
        if reviewDraftWorkoutID != workout.id {
            reviewDraftWorkoutID = workout.id
            reviewEffort = 0
            reviewNotes = ""
            reviewVideoItems = [:]
            reviewVideoURLs = [:]
            reviewSharesPRs = appState.workoutPreferences.automaticallySubmitVideoBackedPRs
            reviewSelectedPRSetIDs = Set(appState.activeWorkoutPRCandidates().map(\.setID))
        }
        return appState.activeWorkoutSummary()
    }

    private var workoutControls: some View {
        let readiness = appState.activeWorkoutFinishReadiness
        let finishTitle: String = switch readiness {
        case .unavailable, .empty: "End empty workout"
        case .incomplete: "Review to finish"
        case .ready: "Finish workout"
        }
        return HStack(spacing: 10) {
            Button { presentedSheet = .addExercise } label: {
                Image(systemName: "plus")
                    .font(LiftTypography.cardTitle)
                    .frame(width: 52, height: 52)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftAccentText)
            .accessibilityLabel("Add exercise")

            Button {
                switch readiness {
                case .unavailable, .empty:
                    showingEmptyWorkoutConfirmation = true
                case .incomplete, .ready:
                    if let summary = prepareSummaryReview() {
                        presentedSheet = .summary(summary)
                    }
                }
            } label: {
                HStack {
                    Text(finishTitle)
                        .font(LiftTypography.cardTitle)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(readiness == .empty ? Color.liftMuted : Color.liftOnGreen)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(readiness == .empty ? Color.liftCard : Color.liftGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            if workout?.source == .planned {
                Button {
                    showingSkipConfirmation = true
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(LiftTypography.cardTitle)
                        .frame(width: 52, height: 52)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftGold)
                .accessibilityLabel("Skip planned workout")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
