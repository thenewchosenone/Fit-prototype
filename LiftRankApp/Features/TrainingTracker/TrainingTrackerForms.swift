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
                                .background(Color.black.opacity(0.18))
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
    let onSave: (BodyweightEntry) -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) -> Void) {
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
                        title: "Actual bodyweight",
                        value: displayedBodyweight,
                        unit: appState.currentProfile.preferredUnit.shortLabel
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftBlue)
                }
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
