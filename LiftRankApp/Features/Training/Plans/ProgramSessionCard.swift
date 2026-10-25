import SwiftUI

struct ProgramSessionCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedWorkout: CompletedWorkout?
    @State private var editingSession: WorkoutSession?
    @State private var focusedSetID: UUID?
    @State private var showsExercises = false
    @State private var dropTargetPrescriptionID: UUID?
    @State private var prescriptionToRemove: WorkoutExercisePrescription?
    @State private var showingRemoveConfirmation = false
    let session: WorkoutSession
    let prescriptions: [WorkoutExercisePrescription]
    let completedPrescriptionCount: Int
    let catalogByID: [String: TrainingExerciseCatalogItem]
    let onStart: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(session.day) · \(session.name)")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button("Edit") { editingSession = session }
                        .font(.subheadline.weight(.semibold))
                        .disabled(appState.activeWorkout != nil)
                    Menu {
                        Button("Edit workout", systemImage: "pencil") { editingSession = session }
                            .disabled(appState.activeWorkout != nil)
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete Workout Day")
                        }
                        .disabled(appState.activeWorkout != nil)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                }

                sessionActions
                if hasSavedWorkout {
                    Text("Repeating starts a new workout; saved history remains.")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                    if let workout = appState.completedWorkouts
                        .filter({ $0.sourceSessionID == session.id })
                        .max(by: { $0.completedAt < $1.completedAt }) {
                        Button("Review saved workout") { selectedWorkout = workout }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: LiftDesign.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                }

                if prescriptions.isEmpty {
                    Text("No exercises added yet.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    Button {
                        withAnimation(.snappy) { showsExercises.toggle() }
                    } label: {
                        HStack {
                            Text("\(prescriptions.count) exercises · \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftText)
                            Spacer()
                            Text(showsExercises ? "Hide" : "Show")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftAccentText)
                            Image(systemName: showsExercises ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(prescriptions.count) exercises, \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                    .accessibilityValue(showsExercises ? "Expanded" : "Collapsed")
                }

                if showsExercises {
                    VStack(spacing: 0) {
                        ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, prescription in
                            exerciseRow(prescription, at: index)

                            if index < prescriptions.count - 1 {
                                Divider()
                                    .overlay(Color.liftOverlay)
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }

            }
        }
        .sheet(item: $selectedWorkout) { workout in
            CompletedWorkoutDetailView(workout: workout, focusedSetID: $focusedSetID)
                .environmentObject(appState)
        }
        .sheet(item: $editingSession) { session in
            ProgramSessionEditorView(session: session, prescriptions: prescriptions)
                .environmentObject(appState)
        }
        .confirmationDialog("Remove exercise from plan?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) {
                if let prescriptionToRemove { appState.deletePrescription(prescriptionToRemove) }
                prescriptionToRemove = nil
            }
            Button("Cancel", role: .cancel) { prescriptionToRemove = nil }
        } message: {
            Text("This removes the selected exercise from this plan. Saved workouts and history remain.")
        }
    }

    @ViewBuilder
    private var sessionActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                addExerciseButton
                startWorkoutButton
            }
        } else {
            HStack(spacing: 10) {
                addExerciseButton
                startWorkoutButton
            }
        }
    }

    private var addExerciseButton: some View {
        Button(action: onAddExercise) {
            Label("Add Exercise", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.liftAccentText)
        .disabled(appState.activeWorkout != nil)
    }

    private var startWorkoutButton: some View {
        Button(action: onStart) {
            Label(hasSavedWorkout ? "Repeat workout" : "Start workout", systemImage: "play.fill")
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LiftCompactProminentButtonStyle())
        .accessibilityHint(hasSavedWorkout ? "Starts a new workout attempt. Saved workout history remains available." : "Starts this scheduled workout.")
    }

    private func exerciseRow(_ prescription: WorkoutExercisePrescription, at index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .frame(width: 24, height: 44)
                .contentShape(Rectangle())
                .draggable(prescription.id.uuidString)
                .accessibilityLabel("Reorder \(prescription.exerciseName)")
                .accessibilityHint("Press and hold, then drag to move this exercise")
            ExerciseCatalogIcon(exercise: catalogExercise(for: prescription))
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(prescription.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Text("\(prescription.sets) × \(prescription.reps) • \(prescription.bodyPart)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                if let kilograms = prescription.targetLoadKilograms {
                    Text("Target: \(MeasurementFormatting.convert(kilograms, from: .kilograms, to: appState.currentProfile.preferredUnit).formatted(.number.precision(.fractionLength(0...1)))) \(appState.currentProfile.preferredUnit.shortLabel)")
                        .font(.caption2).foregroundStyle(Color.liftAccentText)
                } else if let rir = prescription.targetRIR {
                    Text("Target: \(rir) reps in reserve").font(.caption2).foregroundStyle(Color.liftMuted)
                }
            }
            Spacer()
            Menu {
                Button {
                    movePrescription(prescription, by: -1)
                } label: {
                    Label("Move up", systemImage: "arrow.up")
                }
                .disabled(index == 0 || appState.activeWorkout != nil)
                Button {
                    movePrescription(prescription, by: 1)
                } label: {
                    Label("Move down", systemImage: "arrow.down")
                }
                .disabled(index == prescriptions.count - 1 || appState.activeWorkout != nil)
                Divider()
                Button(role: .destructive) {
                    prescriptionToRemove = prescription
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove from plan", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(appState.activeWorkout != nil)
            .accessibilityLabel("Options for \(prescription.exerciseName)")
        }
        .padding(.vertical, 7)
        .frame(minHeight: 66)
        .background(
            dropTargetPrescriptionID == prescription.id
                ? Color.liftAccentText.opacity(0.16)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let item = items.first,
                  let draggedID = UUID(uuidString: item) else { return false }
            return movePrescription(draggedID, to: prescription.id)
        } isTargeted: { isTargeted in
            if isTargeted {
                dropTargetPrescriptionID = prescription.id
            } else if dropTargetPrescriptionID == prescription.id {
                dropTargetPrescriptionID = nil
            }
        }
    }

    private func movePrescription(_ prescription: WorkoutExercisePrescription, by offset: Int) {
        guard let index = prescriptions.firstIndex(where: { $0.id == prescription.id }),
              prescriptions.indices.contains(index + offset) else { return }
        var reordered = prescriptions
        reordered.swapAt(index, index + offset)
        _ = appState.reorderWorkoutPrescriptions(for: session, orderedIDs: reordered.map(\.id))
    }

    private func movePrescription(_ draggedID: UUID, to targetID: UUID) -> Bool {
        guard appState.activeWorkout == nil,
              let sourceIndex = prescriptions.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = prescriptions.firstIndex(where: { $0.id == targetID }),
              sourceIndex != targetIndex else { return false }
        var reordered = prescriptions
        let movedPrescription = reordered.remove(at: sourceIndex)
        reordered.insert(movedPrescription, at: min(targetIndex, reordered.count))
        dropTargetPrescriptionID = nil
        return withAnimation(.snappy) {
            appState.reorderWorkoutPrescriptions(for: session, orderedIDs: reordered.map(\.id))
        }
    }

    private var statusText: String {
        if let outcome = session.outcome { return outcome == .rest ? "Marked as rest" : "Skipped" }
        if appState.isFullyCompletedPlanSession(session) { return "All planned sets completed" }
        if appState.completedWorkouts.contains(where: { $0.sourceSessionID == session.id }) {
            return "Shortened session saved · \(completedPrescriptionCount)/\(prescriptions.count) exercises completed"
        }
        return "\(completedPrescriptionCount) of \(prescriptions.count) exercises completed"
    }

    private var hasSavedWorkout: Bool {
        appState.completedWorkouts.contains { $0.sourceSessionID == session.id }
    }

    private func catalogExercise(for prescription: WorkoutExercisePrescription) -> TrainingExerciseCatalogItem {
        catalogByID[prescription.exerciseID] ?? TrainingExerciseCatalogItem(
            id: prescription.exerciseID,
            name: prescription.exerciseName,
            bodyPart: prescription.bodyPart,
            workoutCategory: prescription.bodyPart,
            defaultSets: prescription.sets,
            defaultReps: prescription.reps,
            symbolName: "figure.strengthtraining.traditional",
            equipment: prescription.equipment,
            muscleProfile: prescription.muscleProfile
        )
    }
}

private struct ProgramSessionEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var session: WorkoutSession
    @State private var prescriptions: [WorkoutExercisePrescription]

    private let days = Calendar.current.weekdaySymbols

    init(session: WorkoutSession, prescriptions: [WorkoutExercisePrescription]) {
        _session = State(initialValue: session)
        _prescriptions = State(initialValue: prescriptions)
    }

    private var canSave: Bool {
        !session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            prescriptions.allSatisfy { $0.sets > 0 && $0.restSeconds >= 0 && !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Workout name", text: $session.name)
                    Picker("Day", selection: $session.day) {
                        ForEach(days, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Exercises") {
                    ForEach(prescriptions.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(prescriptions[index].exerciseName).font(.headline)
                            Stepper("\(prescriptions[index].sets) sets", value: $prescriptions[index].sets, in: 1...100)
                            TextField("Reps or target", text: $prescriptions[index].reps)
                            TextField("Rest (seconds)", value: $prescriptions[index].restSeconds, format: .number)
                                .keyboardType(.numberPad)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if appState.updateWorkoutSession(session, prescriptions: prescriptions) { dismiss() }
                    }
                    .disabled(!canSave || appState.activeWorkout != nil)
                }
            }
        }
    }
}
