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

struct BodyweightEntryEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BodyweightEntry
    @State private var showingDeleteConfirmation = false
    let onSave: (BodyweightEntry) -> Void
    let onDelete: (BodyweightEntry) -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) -> Void, onDelete: @escaping (BodyweightEntry) -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftSheetHeader(
                        title: appState.bodyweightEntries.contains(where: { $0.id == draft.id }) ? "Edit bodyweight" : "Log bodyweight",
                        subtitle: draft.targetDate.formatted(date: .long, time: .omitted)
                    )

                    OptionalNumericInputField(
                        title: "Bodyweight (required)",
                        value: displayedBodyweight,
                        unit: appState.currentProfile.preferredUnit.shortLabel,
                        placeholder: "Enter weight"
                    )

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if appState.bodyweightEntries.contains(where: { $0.id == draft.id }) {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Entry", role: .destructive) { showingDeleteConfirmation = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftAccentText)
                    .disabled((draft.actual ?? 0) <= 0)
                }
            }
            .confirmationDialog("Delete this bodyweight entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    onDelete(draft)
                    dismiss()
                }
            } message: {
                Text("This removes the measurement from your progress history.")
            }
        }
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
