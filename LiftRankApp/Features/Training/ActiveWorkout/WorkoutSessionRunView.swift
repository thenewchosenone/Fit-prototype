import SwiftUI

private enum WorkoutSessionSheet: Identifiable {
    case summary
    case addExercise
    case substitute(WorkoutExerciseSnapshot)
    case incompleteFinish(completedSets: Int, plannedSets: Int)

    var id: String {
        switch self {
        case .summary:
            return "summary"
        case .addExercise:
            return "addExercise"
        case let .substitute(exercise):
            return "substitute-\(exercise.id.uuidString)"
        case .incompleteFinish:
            return "incompleteFinish"
        }
    }
}

struct WorkoutSessionRunView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var presentedSheet: WorkoutSessionSheet?
    @State private var showingCancelConfirmation = false
    @State private var showingEmptyWorkoutConfirmation = false
    @State private var isReorderingExercises = false
    @State private var dismissAfterSummary = false
    @State private var showSummaryAfterSheetDismiss = false

    private var workout: ActiveWorkoutState? { appState.activeWorkout }

    var body: some View {
        NavigationStack {
            AppBackground {
                if let workout {
                    let displayState = appState.activeWorkoutDisplayState
                    VStack(spacing: 0) {
                        activeHeader(workout, displayState: displayState)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if displayState.exercises.isEmpty {
                                    emptyCard
                                } else {
                                    HStack {
                                        Text("Exercises")
                                            .font(.title3.weight(.black))
                                        Spacer()
                                        if isReorderingExercises {
                                            Text("Reorder mode")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.liftBlue)
                                        }
                                        Text("\(displayState.completedWorkingSets)/\(displayState.plannedWorkingSets) working sets")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.liftMuted)
                                    }

                                    ForEach(displayState.exercises) { exercise in
                                        let progress = displayState.progressByExerciseID[exercise.id]
                                            ?? appState.activeWorkoutExerciseProgress(for: exercise)
                                        ExerciseSwipeActionRow(
                                            isEnabled: true,
                                            showsSubstituteAction: !progress.isComplete,
                                            substituteAction: {
                                                presentedSheet = .substitute(exercise)
                                            },
                                            removeAction: {
                                                appState.removeExerciseFromActiveWorkout(exercise)
                                            }
                                        ) {
                                            NavigationLink {
                                                PrescriptionTrackView(exercise: exercise)
                                                    .environmentObject(appState)
                                            } label: {
                                                exerciseCard(exercise, progress: progress)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityIdentifier("workout.exercise.\(exercise.id.uuidString)")
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
                                                appState.removeExerciseFromActiveWorkout(exercise)
                                            } label: {
                                                Label(progress.isComplete ? "Delete from this workout" : "Remove from this workout", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 18)
                            .padding(.bottom, 20)
                        }
                        .scrollIndicators(.hidden)
                        workoutControls
                    }
                } else {
                    LiftEmptyState(
                        title: "Workout saved",
                        message: "Your active workout is no longer available.",
                        symbolName: "checkmark.circle.fill",
                        actionTitle: "Return to Track"
                    ) { dismiss() }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $presentedSheet, onDismiss: {
                if showSummaryAfterSheetDismiss {
                    showSummaryAfterSheetDismiss = false
                    presentedSheet = .summary
                    return
                }
                guard dismissAfterSummary else { return }
                dismissAfterSummary = false
                dismiss()
            }) { sheet in
                switch sheet {
                case .summary:
                    if let summary = appState.activeWorkoutSummary() {
                        WorkoutSummaryView(
                            summary: summary,
                            prCandidates: appState.activeWorkoutPRCandidates(),
                            automaticSubmissionEnabled: appState.workoutPreferences.automaticallySubmitVideoBackedPRs,
                            didExplainAutomaticSubmission: appState.workoutPreferences.didExplainAutomaticPRs,
                            onAutomaticSubmissionChanged: appState.setAutomaticVideoPRSubmission,
                            onExplanationShown: appState.markAutomaticVideoPRExplanationShown
                        ) { effort, notes, videos, _ in
                            guard let completed = appState.finishActiveWorkout(effort: effort, notes: notes) else { return }
                            dismissAfterSummary = true
                            presentedSheet = nil
                            Task {
                                await appState.submitVideoBackedPRs(for: completed, videoURLsBySetID: videos)
                            }
                        }
                        .environmentObject(appState)
                    }
                case .addExercise:
                    ActiveWorkoutAddExercisePickerView()
                        .environmentObject(appState)
                        .presentationDetents([.large])
                case let .substitute(exercise):
                    ActiveWorkoutSubstitutePickerView(exercise: exercise)
                        .environmentObject(appState)
                        .presentationDetents([.large])
                case let .incompleteFinish(completedSets, plannedSets):
                    IncompleteWorkoutFinishPrompt(
                        completedSets: completedSets,
                        plannedSets: plannedSets,
                        onReview: {
                            showSummaryAfterSheetDismiss = true
                            presentedSheet = nil
                        },
                        onKeepTraining: {
                            presentedSheet = nil
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.liftBackground)
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
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minimize workout")

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.dayLabel.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftBlue)
                    Text(workout.name)
                        .font(.headline.weight(.black))
                        .lineLimit(2)
                }

                Spacer()

                TimelineView(.periodic(from: .now, by: 5)) { context in
                    Text(elapsedText(workout, at: context.date))
                        .font(.subheadline.weight(.black).monospacedDigit())
                        .foregroundStyle(Color.liftBlue)
                }

                Menu {
                    Button {
                        workout.pausedAt == nil ? appState.pauseActiveWorkout() : appState.resumeActiveWorkout()
                    } label: {
                        Label(workout.pausedAt == nil ? "Pause Workout" : "Resume Workout", systemImage: workout.pausedAt == nil ? "pause.fill" : "play.fill")
                    }
                    Button {
                        isReorderingExercises.toggle()
                    } label: {
                        Label(isReorderingExercises ? "Done Reordering" : "Reorder Exercises", systemImage: "arrow.up.arrow.down")
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
                    Button(role: .destructive) { showingCancelConfirmation = true } label: {
                        Label("Discard Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Workout options")
            }

            if workout.pausedAt != nil {
                Label("Workout paused", systemImage: "pause.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftGold)
            }

            ProgressView(value: Double(displayState.completedWorkingSets), total: Double(max(1, displayState.plannedWorkingSets)))
                .tint(Color.liftBlue)

            HStack(spacing: 14) {
                Label("\(displayState.completedExercises)/\(displayState.exercises.count) exercises", systemImage: "dumbbell.fill")
                Label("\(displayState.completedWorkingSets)/\(displayState.plannedWorkingSets) sets", systemImage: "checkmark.circle.fill")
                Spacer()
                Text("\(Int(displayState.totalVolume)) \(workout.unit.shortLabel)")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)

            Toggle(isOn: Binding(
                get: { workout.automaticRestTimerEnabled },
                set: { appState.setAutomaticRestTimerEnabledForActiveWorkout($0) }
            )) {
                Label("Auto rest timer", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
            .tint(Color.liftBlue)
            .accessibilityHint("Starts the prescribed rest countdown when a working set is completed")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.liftCardRaised)
        .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }
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
                            .font(.caption.weight(.black))
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Button {
                        _ = appState.moveActiveWorkoutExercise(exercise, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.black))
                            .frame(width: 28, height: 20)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.liftMuted)
                }
                .foregroundStyle(Color.liftBlue)
            }
            ExerciseCatalogIcon(exercise: catalogExercise(for: exercise))
                .frame(width: 48, height: 48)
                .overlay(alignment: .bottomTrailing) {
                    if progress.isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.liftOnAccent)
                            .frame(width: 18, height: 18)
                            .background(Color.liftGreen)
                            .clipShape(Circle())
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.exerciseName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftText)
                Text("\(progress.plannedWorkingSets) × \(exercise.targetReps) • \(exercise.restSeconds)s rest")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(progress.isComplete ? "Done" : "\(progress.completedWorkingSets)/\(progress.plannedWorkingSets)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(progress.isComplete ? Color.liftGreen : Color.liftMuted)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(12)
        .background(progress.isComplete ? Color.liftGreen.opacity(0.08) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(progress.isComplete ? Color.liftGreen.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var workoutControls: some View {
        HStack(spacing: 10) {
            Button { presentedSheet = .addExercise } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Add exercise")

            Button {
                switch appState.activeWorkoutFinishReadiness {
                case .unavailable, .empty:
                    showingEmptyWorkoutConfirmation = true
                case let .incomplete(completedSets, plannedSets):
                    presentedSheet = .incompleteFinish(
                        completedSets: completedSets,
                        plannedSets: plannedSets
                    )
                case .ready:
                    presentedSheet = .summary
                }
            } label: {
                HStack {
                    Text("Finish workout")
                        .font(.headline.weight(.black))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(Color.liftOnAccent)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.liftGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func catalogExercise(for exercise: WorkoutExerciseSnapshot) -> TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ?? TrainingExerciseCatalogItem(
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
    }
}

private struct ExerciseSwipeActionRow<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false
    @State private var dragOffset: CGFloat = 0
    let isEnabled: Bool
    let showsSubstituteAction: Bool
    let substituteAction: () -> Void
    let removeAction: () -> Void
    @ViewBuilder let content: () -> Content

    private let substituteWidth: CGFloat = 104
    private let removeWidth: CGFloat = 88

    private var actionWidth: CGFloat { (showsSubstituteAction ? substituteWidth : 0) + removeWidth }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                if showsSubstituteAction {
                    Button {
                        close()
                        substituteAction()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Substitute")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Color.liftOnAccent)
                        .frame(width: substituteWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.liftBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Find a substitute")
                }

                Button(role: .destructive) {
                    close()
                    removeAction()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "trash.fill")
                        Text(showsSubstituteAction ? "Remove" : "Delete")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: removeWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.liftRed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsSubstituteAction ? "Remove exercise" : "Delete finished exercise")
            }
            .opacity(actionsAreVisible ? 1 : 0)
            .allowsHitTesting(actionsAreVisible)

            content()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .offset(x: displayedOffset)
                .simultaneousGesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            if !isEnabled { close() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { close() }
        }
        .accessibilityAction(named: "Find substitute") {
            guard isEnabled, showsSubstituteAction else { return }
            substituteAction()
        }
        .accessibilityAction(named: showsSubstituteAction ? "Remove exercise" : "Delete finished exercise") {
            guard isEnabled else { return }
            removeAction()
        }
    }

    private var displayedOffset: CGFloat {
        guard isEnabled else { return 0 }
        return min(0, max(-actionWidth, (isOpen ? -actionWidth : 0) + dragOffset))
    }

    private var actionsAreVisible: Bool {
        displayedOffset < -1
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard isEnabled else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard isEnabled else {
                    close()
                    return
                }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                let projectedOffset = (isOpen ? -actionWidth : 0) + value.predictedEndTranslation.width
                animate { isOpen = projectedOffset < -(actionWidth * 0.35) }
                dragOffset = 0
            }
    }

    private func close() {
        animate { isOpen = false }
        dragOffset = 0
    }

    private func animate(_ changes: @escaping () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappy(duration: 0.22), changes)
        }
    }
}

private struct ActiveWorkoutSubstitutePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let exercise: WorkoutExerciseSnapshot

    private var sourceExercise: TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ?? TrainingExerciseCatalogItem(
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
    }

    private var activeExerciseIDs: Set<String> {
        Set(appState.activeWorkout?.exercises.map(\.exerciseID) ?? []).subtracting([exercise.exerciseID])
    }

    private var recommendations: [ExerciseSubstitutionRecommendation] {
        appState.substitutionRecommendations(for: sourceExercise, limit: 12)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftSheetHeader(
                            title: "Find a substitute",
                            subtitle: "Replace \(exercise.exerciseName) in this workout only."
                        )

                        if recommendations.isEmpty {
                            LiftEmptyState(
                                title: "No substitutes found",
                                message: "Try adding a different exercise from the library.",
                                symbolName: "arrow.triangle.2.circlepath"
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                                    let substitute = recommendation.exercise
                                    let alreadyInWorkout = activeExerciseIDs.contains(substitute.id)
                                    Button {
                                        guard !alreadyInWorkout else { return }
                                        _ = appState.substituteActiveWorkoutExercise(exercise, with: substitute)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 13) {
                                            ExerciseCatalogIcon(exercise: substitute)
                                                .frame(width: 48, height: 48)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(substitute.name)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(Color.liftText)
                                                Text(recommendation.reasons.joined(separator: " • "))
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                                    .lineLimit(2)
                                                if alreadyInWorkout {
                                                    Text("Already in this workout")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(Color.liftGold)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: alreadyInWorkout ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(alreadyInWorkout ? Color.liftMuted : Color.liftBlue)
                                        }
                                        .padding(14)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(alreadyInWorkout)
                                    .accessibilityIdentifier("activeWorkout.substitute.\(substitute.id)")

                                    if index < recommendations.count - 1 {
                                        Divider().overlay(Color.liftSeparator).padding(.leading, 74)
                                    }
                                }
                            }
                            .liftSurface()
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Substitute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct IncompleteWorkoutFinishPrompt: View {
    let completedSets: Int
    let plannedSets: Int
    let onReview: () -> Void
    let onKeepTraining: () -> Void

    private var remainingSets: Int {
        max(0, plannedSets - completedSets)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.liftBlue)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("You have sets remaining")
                            .font(.title3.weight(.black))
                            .foregroundStyle(Color.liftText)
                        Text("Review what you logged, or keep training to finish the plan.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Workout progress")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(remainingSets) left")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Color.liftBlue)
                            .monospacedDigit()
                    }

                    ProgressView(value: Double(completedSets), total: Double(max(1, plannedSets)))
                        .tint(Color.liftBlue)

                    Text("Completed \(completedSets) of \(plannedSets) working sets")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .monospacedDigit()
                }
                .padding(16)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.liftSeparator, lineWidth: 1)
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Review workout anyway", symbolName: "doc.text.magnifyingglass") {
                        onReview()
                    }
                    .accessibilityIdentifier("workout.finish.reviewIncomplete")

                    Button("Keep training") {
                        onKeepTraining()
                    }
                    .buttonStyle(LiftSecondaryButtonStyle())
                    .accessibilityIdentifier("workout.finish.keepTraining")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.liftBackground)
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
                    WorkoutSetInputFocus(logID: log.id, field: .reps),
                    WorkoutSetInputFocus(logID: log.id, field: .weight)
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
