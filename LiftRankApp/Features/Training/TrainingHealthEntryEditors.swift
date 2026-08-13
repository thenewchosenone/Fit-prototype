import SwiftUI

struct StrainEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StrainEntry
    let onSave: (StrainEntry) -> Void

    init(entry: StrainEntry, onSave: @escaping (StrainEntry) -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    private var strainDescriptor: (title: String, color: Color) {
        switch draft.strain {
        case 1...3:
            ("Low training load", Color.liftGreen)
        case 4...6:
            ("Moderate load", Color.liftBlue)
        case 7...8:
            ("High load", Color.liftGold)
        default:
            ("Very high fatigue", Color.liftRed)
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LiftSheetHeader(
                            title: "Daily strain check-in",
                            subtitle: "Log today’s fatigue level so plans can respect your recovery."
                        )

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "Date", eyebrow: "Context")
                                DatePicker(
                                    "Date",
                                    selection: $draft.occurredAt,
                                    displayedComponents: .date
                                )
                                .frame(minHeight: LiftDesign.minimumTouchTarget)
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "How strenuous was today?", eyebrow: "Strain")
                                Text("1 = fully recovered, 10 = drained.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 12) {
                                    Text("1")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                    Slider(
                                        value: Binding(
                                            get: { Double(draft.strain) },
                                            set: { draft.strain = Int($0.rounded()) }
                                        ),
                                        in: 1...10,
                                        step: 1
                                    )
                                    Text("10")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                }

                                HStack(spacing: 8) {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    Text("\(draft.strain)")
                                        .font(.subheadline.weight(.black).monospacedDigit())
                                        .foregroundStyle(Color.liftText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(strainDescriptor.color.opacity(0.16))
                                        .clipShape(Capsule())
                                }
                                Text(strainDescriptor.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(strainDescriptor.color)
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "Notes", eyebrow: "Optional")
                                Text("Add context: sleep, travel, stress, soreness, or recovery habits.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                TextEditor(text: $draft.notes)
                                    .frame(minHeight: 130)
                                    .scrollContentBackground(.hidden)
                                    .padding(10)
                                    .background(Color.liftField)
                                    .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(18)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Strain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
}

struct InjuryEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: InjuryEntry
    let onSave: (InjuryEntry) -> Void

    private var isValid: Bool {
        !draft.area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var painDescriptor: (title: String, color: Color) {
        switch draft.intensity {
        case 1...3:
            ("Low pain", Color.liftGreen)
        case 4...6:
            ("Moderate pain", Color.liftBlue)
        case 7...8:
            ("High pain", Color.liftGold)
        default:
            ("Severe pain", Color.liftRed)
        }
    }

    init(entry: InjuryEntry, onSave: @escaping (InjuryEntry) -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LiftSheetHeader(
                            title: "Injury check-in",
                            subtitle: "Track pain and recovery status to improve tomorrow’s training guidance."
                        )

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "Date", eyebrow: "Context")
                                DatePicker(
                                    "Date",
                                    selection: $draft.occurredAt,
                                    displayedComponents: .date
                                )
                                .frame(minHeight: LiftDesign.minimumTouchTarget)
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "Injury details", eyebrow: "Body area")
                                Text("Required fields")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Body area")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                    TextField("e.g. Right shoulder", text: $draft.area)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color.liftField)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    draft.area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                    ? Color.liftRed
                                                    : Color.liftSeparator
                                                )
                                        )
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Description")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                    TextField("Where and what happened", text: $draft.description)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color.liftField)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                    ? Color.liftRed
                                                    : Color.liftSeparator
                                                )
                                        )
                                }

                                if draft.area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Body area and description are required.")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.liftRed)
                                }
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSectionHeader(title: "Pain level", eyebrow: "Intensity")
                                Text("1 = mild discomfort, 10 = severe / blocking.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)

                                HStack(spacing: 12) {
                                    Text("1")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                    Slider(
                                        value: Binding(
                                            get: { Double(draft.intensity) },
                                            set: { draft.intensity = Int($0.rounded()) }
                                        ),
                                        in: 1...10,
                                        step: 1
                                    )
                                    Text("10")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftMuted)
                                }

                                HStack(spacing: 8) {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    Text("\(draft.intensity)")
                                        .font(.subheadline.weight(.black).monospacedDigit())
                                        .foregroundStyle(Color.liftText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(painDescriptor.color.opacity(0.16))
                                        .clipShape(Capsule())
                                }
                                Text(painDescriptor.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(painDescriptor.color)
                            }
                        }

                        LiftCard {
                            VStack(alignment: .leading, spacing: 10) {
                                CompactSectionHeader(title: "Status", eyebrow: "Recovery")
                                Picker("Status", selection: $draft.status) {
                                    Text("Active").tag(RecoveryStatus.active)
                                    Text("Improving").tag(RecoveryStatus.improving)
                                    Text("Resolved").tag(RecoveryStatus.resolved)
                                }
                                .pickerStyle(.segmented)
                                .tint(Color.liftBlue)
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(18)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                    .foregroundStyle(isValid ? Color.liftBlue : Color.liftMuted)
                }
            }
        }
    }
}
