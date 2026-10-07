import SwiftUI

struct WorkoutSetLogRow: View {
    @FocusState.Binding var focusedInput: WorkoutSetInputFocus?
    @State private var draft: WorkoutSetLog
    @State private var repsText: String
    @State private var weightText: String
    @State private var lastPersistedDraft: WorkoutSetLog
    @State private var showValidation = false
    @State private var showingDetails = false
    @State private var pendingPersistTask: Task<Void, Never>?
    @State private var isDeleting = false
    let previousLog: WorkoutSetLog?
    let trackingKind: ExerciseTrackingKind
    let onDelete: (WorkoutSetLog) -> Void
    let onApplyCompletion: (WorkoutSetLog, Bool) -> Bool
    let onAttemptAutomaticCompletion: (WorkoutSetLog) -> Bool
    let onUpdate: (WorkoutSetLog) -> Void
    var onCompleted: (() -> Void)?

    init(
        log: WorkoutSetLog,
        trackingKind: ExerciseTrackingKind = .weightReps,
        previousLog: WorkoutSetLog? = nil,
        focusedInput: FocusState<WorkoutSetInputFocus?>.Binding,
        onDelete: @escaping (WorkoutSetLog) -> Void,
        onApplyCompletion: @escaping (WorkoutSetLog, Bool) -> Bool,
        onAttemptAutomaticCompletion: @escaping (WorkoutSetLog) -> Bool,
        onUpdate: @escaping (WorkoutSetLog) -> Void,
        onCompleted: (() -> Void)? = nil
    ) {
        _focusedInput = focusedInput
        _draft = State(initialValue: log)
        _repsText = State(initialValue: log.reps.map(String.init) ?? "")
        _weightText = State(initialValue: log.weight.map(Self.formatWeight) ?? "")
        _lastPersistedDraft = State(initialValue: log)
        self.previousLog = previousLog
        self.trackingKind = trackingKind
        self.onDelete = onDelete
        self.onApplyCompletion = onApplyCompletion
        self.onAttemptAutomaticCompletion = onAttemptAutomaticCompletion
        self.onUpdate = onUpdate
        self.onCompleted = onCompleted
    }

    private var hasRequiredInputs: Bool {
        parsedReps != nil && (!trackingKind.requiresWeight || parsedWeight != nil)
    }

    private var parsedReps: Int? {
        let trimmed = repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private var parsedWeight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    private static func formatWeight(_ value: Double) -> String {
        RankingCalculator.format(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(draft.setNumber)")
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftText)
                    .frame(width: 34, height: 38)
                    .background(draft.isComplete ? Color.liftGreen : Color.liftCardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    usePreviousValues()
                } label: {
                    Text(previousLog == nil ? "No previous" : "Prev · \(previousSummary)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                        .foregroundStyle(previousLog == nil ? Color.liftMuted : Color.liftAccentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.liftScrim)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(previousLog == nil)
                .accessibilityLabel(previousLog == nil ? "No previous set values" : "Use previous workout values: \(previousSummary)")

                compactField(trackingKind.usesDuration ? "Sec" : "Reps", text: $repsText, width: 64, field: .reps)
                    .keyboardType(.numberPad)
                    .onChange(of: repsText) { _, _ in
                        draft.reps = parsedReps
                        schedulePersistIfIdle()
                    }

                if trackingKind.requiresWeight {
                    compactField(weightPlaceholder, text: $weightText, width: 72, field: .weight)
                        .keyboardType(.decimalPad)
                        .onChange(of: weightText) { _, _ in
                            draft.weight = parsedWeight
                            schedulePersistIfIdle()
                        }
                }

                Button {
                    toggleCompletion()
                } label: {
                    Image(systemName: draft.isComplete ? "checkmark" : "circle")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftAccentText)
                        .frame(width: 38, height: 38)
                        .background(draft.isComplete ? Color.liftGreen : Color.liftBlue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(!draft.isComplete && !hasRequiredInputs ? 0.55 : 1)
                .accessibilityLabel(draft.isComplete ? "Mark set incomplete" : "Complete set")
            }

            if showingDetails {
                HStack(spacing: 10) {
                    Button {
                        draft.isWarmup.toggle()
                        persistDraft()
                    } label: {
                        Label(draft.isWarmup ? "Warm-up set" : "Working set", systemImage: draft.isWarmup ? "flame.fill" : "dumbbell.fill")
                            .font(.caption.weight(.bold))
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.isWarmup ? Color.liftGold : Color.liftMuted)
                    .accessibilityLabel(draft.isWarmup ? "Mark as working set" : "Mark as warmup set")

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        isDeleting = true
                        cancelPendingPersist()
                        onDelete(draft)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption.weight(.bold))
                    }
                }
            }

            HStack(spacing: 6) {
                if !draft.isWarmup {
                    Text("RPE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 34, alignment: .leading)
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button {
                            cancelPendingPersist()
                            draft.rpe = draft.rpe == value ? nil : value
                            persistDraft()
                            Haptics.light()
                        } label: {
                            Text("\(value)")
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(draft.rpe == value ? Color.liftOnAccent : Color.liftText)
                                .frame(width: 30, height: 28)
                                .background(draft.rpe == value ? rpeTint(value) : rpeTint(value).opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Set RPE to \(value)")
                        .accessibilityAddTraits(draft.rpe == value ? .isSelected : [])
                    }
                }
                Spacer(minLength: 0)
                Button {
                    showingDetails.toggle()
                } label: {
                    Label(showingDetails ? "Done" : "Set options", systemImage: showingDetails ? "checkmark" : "ellipsis.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showingDetails ? "Hide set options" : "Show set options")
            }
            .padding(.top, 1)

            if showValidation && !hasRequiredInputs {
                Label(trackingKind.valueHint, systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftRed)
            }
        }
        .padding(10)
        .background(draft.isComplete ? Color.liftGreen.opacity(0.07) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(draft.isComplete ? Color.liftGreen.opacity(0.35) : Color.liftOverlay, lineWidth: 1)
        }
        .contextMenu {
            Button {
                showingDetails.toggle()
            } label: {
                Label(showingDetails ? "Hide RPE" : "Add RPE", systemImage: "slider.horizontal.3")
            }
            Button {
                cancelPendingPersist()
                draft.isWarmup.toggle()
                persistDraft()
            } label: {
                Label(draft.isWarmup ? "Mark Working Set" : "Mark Warmup Set", systemImage: "flame")
            }
            Button(role: .destructive) {
                isDeleting = true
                cancelPendingPersist()
                onDelete(draft)
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
        .onDisappear {
            if !isDeleting {
                persistImmediately()
            }
        }
        .onChange(of: focusedInput) { oldValue, newValue in
            guard isInputFocus(oldValue), !isInputFocus(newValue), !isDeleting else { return }
            persistImmediately()
        }
    }

    private var previousSummary: String {
        guard let previousLog else { return "—" }
        let reps = previousLog.reps ?? 0
        switch trackingKind {
        case .weightReps:
            return "\(reps) × \(MeasurementFormatting.formatRecordedWeight(previousLog.weight ?? 0, unit: previousLog.recordedUnit))"
        case .bodyweightReps, .repsOnly:
            return "\(reps) reps"
        case .assistedBodyweight:
            return "\(reps) × \(MeasurementFormatting.formatRecordedWeight(previousLog.weight ?? 0, unit: previousLog.recordedUnit)) assist"
        case .time:
            return MeasurementFormatting.shortClockText(TimeInterval(reps))
        case .weightTime:
            return "\(MeasurementFormatting.shortClockText(TimeInterval(reps))) × \(MeasurementFormatting.formatRecordedWeight(previousLog.weight ?? 0, unit: previousLog.recordedUnit))"
        }
    }

    private var weightPlaceholder: String {
        trackingKind == .assistedBodyweight ? "Assist" : draft.recordedUnit.shortLabel.capitalized
    }

    private func compactField(_ placeholder: String, text: Binding<String>, width: CGFloat, field: WorkoutSetInputField) -> some View {
        TextField(placeholder, text: text)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .accessibilityIdentifier("workout.set.\(draft.setNumber).\(field.rawValue)")
            .focused($focusedInput, equals: WorkoutSetInputFocus(logID: draft.id, field: field))
            .frame(width: width, height: 38)
            .background(Color.liftScrim)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.liftOverlay, lineWidth: 1)
            }
    }

    private func usePreviousValues() {
        cancelPendingPersist()
        guard let previousLog else { return }
        if let reps = previousLog.reps {
            repsText = String(reps)
            draft.reps = reps
        }
        if let weight = previousLog.weight {
            let currentUnitWeight = MeasurementFormatting.convert(
                weight,
                from: previousLog.recordedUnit,
                to: draft.recordedUnit
            )
            weightText = MeasurementFormatting.formatWeight(currentUnitWeight)
            draft.weight = currentUnitWeight
        }
        persistDraft()
        Haptics.light()
    }

    private func toggleCompletion() {
        cancelPendingPersist()
        guard draft.isComplete || hasRequiredInputs else {
            showValidation = true
            return
        }
        showValidation = false
        let completing = !draft.isComplete
        let triggerTimer = onApplyCompletion(draft, completing)
        draft.isComplete = completing
        draft.performedAt = .now
        draft.completionSource = completing ? .manual : nil
        lastPersistedDraft = draft
        if completing {
            Haptics.success()
            if triggerTimer { onCompleted?() }
        }
    }

    private func schedulePersist() {
        cancelPendingPersist()
        let snapshot = draft
        pendingPersistTask = Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persistSnapshot(snapshot)
                pendingPersistTask = nil
            }
        }
    }

    private func schedulePersistIfIdle() {
        guard !isInputFocus(focusedInput) else { return }
        schedulePersist()
    }

    private func isInputFocus(_ focus: WorkoutSetInputFocus?) -> Bool {
        focus?.logID == draft.id
    }

    private func persistImmediately() {
        cancelPendingPersist()
        persistDraft()
    }

    private func cancelPendingPersist() {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
    }

    private func persistDraft() {
        guard draft != lastPersistedDraft else { return }
        persistSnapshot(draft)
        if onAttemptAutomaticCompletion(draft) {
            onCompleted?()
        }
    }

    private func persistSnapshot(_ snapshot: WorkoutSetLog) {
        guard snapshot != lastPersistedDraft else { return }
        onUpdate(snapshot)
        lastPersistedDraft = snapshot
    }

    private func rpeTint(_ value: Int) -> Color {
        switch value {
        case ..<7: .liftGreen
        case 7: .liftBlue
        case 8: .liftGold
        case 9: .orange
        default: .liftRed
        }
    }

}
