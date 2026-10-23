import SwiftUI

struct CreateWorkoutPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create Workout Plan")
                                .font(.title2.bold())
                            TextField("Plan name", text: $planName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.liftScrim)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        appState.createWorkoutPlan(name: planName)
                        dismiss()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct CreateWorkoutPlanFromHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var planName = "Freestyle Workout Plan"
    @State private var selectedWorkoutIDs: Set<UUID>
    private let workouts: [CompletedWorkout]

    init(workouts: [CompletedWorkout]) {
        self.workouts = workouts
        _selectedWorkoutIDs = State(initialValue: Set(workouts.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Choose completed freestyle workouts. Each selected workout becomes a day, and only exercises with completed working sets are copied.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                TextField("Plan name", text: $planName)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.liftScrim)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout history")
                                .font(.headline.weight(.bold))
                            Text("\(selectedWorkoutIDs.count) of \(workouts.count) selected · your history stays unchanged")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)

                            VStack(spacing: 0) {
                                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                                    let isSelected = selectedWorkoutIDs.contains(workout.id)
                                    Button {
                                        if isSelected {
                                            selectedWorkoutIDs.remove(workout.id)
                                        } else {
                                            selectedWorkoutIDs.insert(workout.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(isSelected ? Color.liftGreen : Color.liftMuted)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(workout.name.isEmpty ? "Freestyle Workout" : workout.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.liftText)
                                    Text("\(workout.completedAt.formatted(date: .abbreviated, time: .omitted)) · \(workout.exercisesWithCompletedWorkingSets.count) exercises · \(workout.completedWorkingSets.count) sets")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 64)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("planFromHistory.workout.\(workout.id.uuidString)")

                                    if index < workouts.count - 1 {
                                        Divider().overlay(Color.liftOverlay).padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Color.liftCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Build from history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Plan") {
                        guard appState.createWorkoutPlan(fromWorkouts: selectedWorkouts, name: planName) else { return }
                        dismiss()
                    }
                    .disabled(selectedWorkouts.isEmpty || planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var selectedWorkouts: [CompletedWorkout] {
        workouts.filter { selectedWorkoutIDs.contains($0.id) }
    }
}

struct BodyweightEntryEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BodyweightEntry
    @State private var isSaving = false
    @State private var saveError: String?
    let onSave: (BodyweightEntry) async throws -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) async throws -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftSheetHeader(
                        title: "Week \(draft.week)",
                        subtitle: draft.targetDate.formatted(date: .long, time: .omitted)
                    )

                    OptionalNumericInputField(
                        title: "Actual bodyweight (required)",
                        value: displayedBodyweight,
                        unit: appState.currentProfile.preferredUnit.shortLabel,
                        placeholder: "Enter weight"
                    )
                    Text(bodyweightRangeText)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(Color.liftRed)
                            .accessibilityIdentifier("bodyweight.saveError")
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                        TextField("Optional notes", text: $draft.notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.liftField)
                            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
                    }

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Bodyweight Entry")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task {
                            guard !isSaving else { return }
                            isSaving = true
                            saveError = nil
                            defer { isSaving = false }
                            do {
                                try await onSave(draft)
                                dismiss()
                            } catch {
                                saveError = (error as? LocalizedError)?.errorDescription
                                    ?? "Bodyweight couldn't be saved. Check your connection and try again."
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftAccentText)
                    .disabled((draft.actual ?? 0) < 40 || (draft.actual ?? 0) > 1500 || isSaving)
                    .accessibilityIdentifier("bodyweight.save")
                }
            }
        }
    }

    private var bodyweightRangeText: String {
        let unit = appState.currentProfile.preferredUnit
        guard unit == .kilograms else { return "Enter between 40 and 1500 lb." }
        let minimum = ceil(MeasurementFormatting.convert(40, from: .pounds, to: unit) * 100) / 100
        let maximum = floor(MeasurementFormatting.convert(1500, from: .pounds, to: unit) * 100) / 100
        return "Enter between \(MeasurementFormatting.localizedDecimalText(minimum, maximumFractionDigits: 2)) and \(MeasurementFormatting.localizedDecimalText(maximum, maximumFractionDigits: 2)) kg (40–1500 lb)."
    }

    private var displayedBodyweight: Binding<Double?> {
        Binding(
            get: {
                draft.actual.map {
                    MeasurementFormatting.convert(
                        $0,
                        from: .pounds,
                        to: appState.currentProfile.preferredUnit
                    )
                }
            },
            set: { newValue in
                draft.actual = newValue.map {
                    MeasurementFormatting.convert(
                        $0,
                        from: appState.currentProfile.preferredUnit,
                        to: .pounds
                    )
                }
            }
        )
    }
}
