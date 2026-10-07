import SwiftUI

struct CompletedWorkoutDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let workout: CompletedWorkout
    @Binding var focusedSetID: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var editingWorkout: CompletedWorkout?

    init(workout: CompletedWorkout, focusedSetID: Binding<UUID?> = .constant(nil)) {
        self.workout = workout
        self._focusedSetID = focusedSetID
    }

    var body: some View {
        let presentation = appState.completedWorkoutPresentation(for: workout)
        let displayedWorkout = presentation.workout
        let exercises = presentation.exercises
        let completedSetsByExercise = presentation.completedSetsByExercise
        let trackingKinds = presentation.trackingKinds
        return NavigationStack {
            AppBackground {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(displayedWorkout.name)
                                    .font(.title2.weight(.black))
                                Text(LiftTimeFormatter.shortDateTime(displayedWorkout.completedAt))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                HStack(spacing: 8) {
                                    detailMetric("Duration", MeasurementFormatting.shortDurationText(displayedWorkout.duration), "timer")
                                    detailMetric("Sets", "\(displayedWorkout.completedWorkingSets.count)", "checkmark.circle")
                                    detailMetric("Volume", MeasurementFormatting.formatRecordedWeight(displayedWorkout.totalVolume, unit: displayedWorkout.unit), "scalemass")
                                }
                            }
                            .padding(14)
                            .liftSurface()

                            ForEach(exercises) { exercise in
                                let trackingKind = trackingKinds[exercise.exerciseID] ?? .weightReps
                                let sets = completedSetsByExercise[exercise.id] ?? []
                                if !sets.isEmpty {
                                    let muscleProfile = exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(
                                        name: exercise.exerciseName,
                                        bodyPart: exercise.bodyPart
                                    )
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            ExerciseMuscleMap(
                                                profile: muscleProfile,
                                                displayStyle: .compact
                                            )
                                                .frame(width: 46, height: 46)
                                                .accessibilityHidden(true)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(exercise.exerciseName)
                                                    .font(.headline.weight(.bold))
                                                Text(muscleProfile.primaryDescription)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                            }
                                            Spacer()
                                        }
                                        ForEach(sets) { set in
                                            HStack {
                                                Text(set.isWarmup ? "Warmup \(set.setNumber)" : "Set \(set.setNumber)")
                                                    .foregroundStyle(set.isWarmup ? Color.liftGold : Color.liftMuted)
                                                Spacer()
                                                Text(MeasurementFormatting.workoutSetText(set: set, trackingKind: trackingKind))
                                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                                if let rpe = set.rpe {
                                                    Text("@ \(rpe)")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(Color.liftAccentText)
                                                }
                                            }
                                            .font(.subheadline)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(set.id == focusedSetID ? Color.liftGreen.opacity(0.18) : .clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .id(set.id)
                                            .accessibilityIdentifier(
                                                set.id == focusedSetID
                                                    ? "workout.detail.focusedSet"
                                                    : "workout.detail.set.\(set.id.uuidString)"
                                            )
                                            if set.id != sets.last?.id {
                                                Divider().overlay(Color.liftOverlay)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .liftSurface()
                                }
                            }

                            if !displayedWorkout.notes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Notes")
                                        .font(.headline.weight(.bold))
                                    Text(displayedWorkout.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .padding(14)
                                .liftSurface()
                            }

                            if !displayedWorkout.linkedSubmissionIDs.isEmpty {
                                Label("\(displayedWorkout.linkedSubmissionIDs.count) public lift submission linked. Deleting this history entry will not delete it.", systemImage: "link")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                                    .padding(14)
                                    .liftSurface()
                            }
                        }
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                    .task(id: focusedSetID) {
                        guard let focusedSetID else { return }
                        do {
                            try await Task.sleep(for: .milliseconds(250))
                        } catch {
                            return
                        }
                        withAnimation(.snappy) {
                            scrollProxy.scrollTo(focusedSetID, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Workout details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if appState.repeatWorkout(displayedWorkout) {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Repeat workout")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _ = appState.saveWorkoutAsRoutine(displayedWorkout)
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Save workout as routine")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingWorkout = displayedWorkout
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit workout history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete workout history")
                }
            }
            .confirmationDialog("Delete this workout from history?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete History", role: .destructive) {
                    appState.deleteCompletedWorkout(displayedWorkout)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The workout snapshot is removed. Any public lift submissions already created remain public.")
            }
            .sheet(item: $editingWorkout) { workout in
                CompletedWorkoutEditView(workout: workout) { updated in
                    appState.updateCompletedWorkout(updated)
                    editingWorkout = nil
                }
            }
        }
    }

    private func detailMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompletedWorkoutEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CompletedWorkout
    @State private var notes: String
    let onSave: (CompletedWorkout) -> Void

    init(workout: CompletedWorkout, onSave: @escaping (CompletedWorkout) -> Void) {
        _draft = State(initialValue: workout)
        _notes = State(initialValue: workout.notes)
        self.onSave = onSave
    }

    var body: some View {
        let sortedExercises = sortedExercises
        let setIndicesByExercise = Dictionary(
            grouping: draft.sets.indices,
            by: { draft.sets[$0].prescriptionID }
        ).mapValues { indices in
            indices.sorted { draft.sets[$0].setNumber < draft.sets[$1].setNumber }
        }
        return NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        detailsSection

                        ForEach(sortedExercises) { exercise in
                            exerciseSection(exercise, setIndices: setIndicesByExercise[exercise.id] ?? [])
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard canSave else { return }
                        var updated = draft
                        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.startedAt = updated.completedAt.addingTimeInterval(-updated.duration)
                        updated.sets = normalizedSets(for: updated)
                        updated.exercises = normalizedExercises(for: updated)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var sortedExercises: [WorkoutExerciseSnapshot] {
        draft.exercises.sorted { $0.order < $1.order }
    }

    private var canSave: Bool {
        draft.sets.contains { $0.isComplete && !$0.isWarmup }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout")
                .font(.headline.weight(.bold))

            DatePicker("Completed", selection: $draft.completedAt, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline.weight(.semibold))

            Stepper("Effort \(draft.effort)/5", value: $draft.effort, in: 1...5)
                .font(.subheadline.weight(.semibold))

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color.liftCardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .liftSurface()
    }

    private func exerciseSection(_ exercise: WorkoutExerciseSnapshot, setIndices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exerciseName)
                        .font(.headline.weight(.bold))
                    Text(exercise.bodyPart)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button {
                    addSet(to: exercise)
                } label: {
                    Label("Set", systemImage: "plus")
                        .font(.caption.weight(.black))
                }
                .buttonStyle(.bordered)
            }

            if setIndices.isEmpty {
                Text("No sets logged.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                ForEach(setIndices, id: \.self) { index in
                    setRow(at: index, exercise: exercise)
                }
            }
        }
        .padding(14)
        .liftSurface()
    }

    private func setRow(at index: Int, exercise: WorkoutExerciseSnapshot) -> some View {
        let set = draft.sets[index]
        return VStack(spacing: 8) {
            HStack {
                Toggle(set.isWarmup ? "Warmup \(set.setNumber)" : "Set \(set.setNumber)", isOn: $draft.sets[index].isComplete)
                    .font(.subheadline.weight(.bold))
                Button(role: .destructive) {
                    deleteSet(set, from: exercise)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete set \(set.setNumber)")
            }

            HStack(spacing: 8) {
                editableField("Reps", value: intBinding(at: index, keyPath: \.reps))
                editableField(draft.unit.shortLabel.uppercased(), value: doubleBinding(at: index, keyPath: \.weight))
                editableField("RPE", value: intBinding(at: index, keyPath: \.rpe))
            }
        }
        .padding(10)
        .background(Color.liftCardRaised.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func editableField(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            TextField("-", text: value)
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private func sets(for exercise: WorkoutExerciseSnapshot) -> [WorkoutSetLog] {
        draft.sets
            .filter { $0.prescriptionID == exercise.id }
            .sorted { $0.setNumber < $1.setNumber }
    }

    private func addSet(to exercise: WorkoutExerciseSnapshot) {
        let nextSetNumber = (sets(for: exercise).map(\.setNumber).max() ?? 0) + 1
        draft.sets.append(WorkoutSetLog(
            id: UUID(),
            prescriptionID: exercise.id,
            performedAt: draft.completedAt,
            setNumber: nextSetNumber,
            weight: nil,
            reps: nil,
            rpe: nil,
            isWarmup: false,
            isComplete: true,
            workoutID: draft.id,
            recordedUnit: draft.unit,
            completionSource: .manual
        ))
    }

    private func deleteSet(_ set: WorkoutSetLog, from exercise: WorkoutExerciseSnapshot) {
        draft.sets.removeAll { $0.id == set.id }
        renumberSets(for: exercise.id)
    }

    private func renumberSets(for exerciseID: UUID) {
        let IDs = draft.sets
            .filter { $0.prescriptionID == exerciseID }
            .sorted { $0.setNumber < $1.setNumber }
            .map(\.id)
        for (offset, id) in IDs.enumerated() {
            guard let index = draft.sets.firstIndex(where: { $0.id == id }) else { continue }
            draft.sets[index].setNumber = offset + 1
        }
    }

    private func intBinding(at index: Int, keyPath: WritableKeyPath<WorkoutSetLog, Int?>) -> Binding<String> {
        Binding(
            get: {
                guard draft.sets.indices.contains(index),
                      let value = draft.sets[index][keyPath: keyPath] else { return "" }
                return "\(value)"
            },
            set: { text in
                guard draft.sets.indices.contains(index) else { return }
                draft.sets[index][keyPath: keyPath] = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    private func doubleBinding(at index: Int, keyPath: WritableKeyPath<WorkoutSetLog, Double?>) -> Binding<String> {
        Binding(
            get: {
                guard draft.sets.indices.contains(index),
                      let value = draft.sets[index][keyPath: keyPath] else { return "" }
                return value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
            },
            set: { text in
                guard draft.sets.indices.contains(index) else { return }
                draft.sets[index][keyPath: keyPath] = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    private func normalizedSets(for workout: CompletedWorkout) -> [WorkoutSetLog] {
        workout.sets.map { set in
            var normalized = set
            normalized.workoutID = workout.id
            normalized.performedAt = min(max(set.performedAt, workout.startedAt), workout.completedAt)
            normalized.recordedUnit = workout.unit
            normalized.completionSource = normalized.completionSource ?? .manual
            return normalized
        }
    }

    private func normalizedExercises(for workout: CompletedWorkout) -> [WorkoutExerciseSnapshot] {
        let workingSetCounts = Dictionary(
            grouping: workout.sets.filter { !$0.isWarmup },
            by: \.prescriptionID
        ).mapValues { $0.count }
        return workout.exercises.map { exercise in
            var normalized = exercise
            normalized.targetSets = max(
                normalized.targetSets,
                workingSetCounts[exercise.id] ?? 0
            )
            return normalized
        }
    }
}
