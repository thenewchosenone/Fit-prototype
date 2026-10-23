import SwiftUI
import UIKit

struct WorkoutSetLogRow: View {
    @FocusState.Binding var focusedInput: WorkoutSetInputFocus?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: WorkoutSetLog
    @State private var repsText: String
    @State private var weightText: String
    @State private var lastPersistedDraft: WorkoutSetLog
    @State private var showValidation = false
    @State private var showingDetails = false
    @State private var pendingPersistTask: Task<Void, Never>?
    @State private var isDeleting = false
    let log: WorkoutSetLog
    let previousLog: WorkoutSetLog?
    let trackingKind: ExerciseTrackingKind
    let onDelete: (WorkoutSetLog) -> Void
    let onApplyCompletion: (WorkoutSetLog, Bool) -> Bool
    let onAttemptAutomaticCompletion: (WorkoutSetLog) -> Bool
    let onUpdate: (WorkoutSetLog) -> Void
    let onPersistImmediately: () -> Void
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
        onPersistImmediately: @escaping () -> Void,
        onCompleted: (() -> Void)? = nil
    ) {
        _focusedInput = focusedInput
        _draft = State(initialValue: log)
        _repsText = State(initialValue: log.reps.map(String.init) ?? "")
        _weightText = State(initialValue: log.weight.map(Self.formatWeight) ?? "")
        _lastPersistedDraft = State(initialValue: log)
        self.log = log
        self.previousLog = previousLog
        self.trackingKind = trackingKind
        self.onDelete = onDelete
        self.onApplyCompletion = onApplyCompletion
        self.onAttemptAutomaticCompletion = onAttemptAutomaticCompletion
        self.onUpdate = onUpdate
        self.onPersistImmediately = onPersistImmediately
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
        guard let value = MeasurementFormatting.parseLocalizedDecimal(trimmed), value >= 0 else { return nil }
        return value
    }

    private static func formatWeight(_ value: Double) -> String {
        MeasurementFormatting.localizedDecimalText(value, maximumFractionDigits: 1)
    }

    private var setNumberBadge: some View {
        Text("\(draft.setNumber)")
            .font(.subheadline.weight(.black).monospacedDigit())
            .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftText)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 44 : 34, height: dynamicTypeSize.isAccessibilitySize ? 44 : 38)
            .background(draft.isComplete ? Color.liftGreen : Color.liftCardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var previousValuesButton: some View {
        Button {
            usePreviousValues()
        } label: {
            Text(previousLog == nil ? "No previous" : "Prev · \(previousSummary)")
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(previousLog == nil ? Color.liftMuted : Color.liftAccentText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 38)
                .background(Color.liftScrim)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(previousLog == nil)
        .accessibilityLabel(previousLog == nil ? "No previous set values" : "Use previous workout values: \(previousSummary)")
    }

    private var repsInput: some View {
        compactField(
            trackingKind.usesDuration ? "Sec" : "Reps",
            text: $repsText,
            width: dynamicTypeSize.isAccessibilitySize ? 112 : 64,
            field: .reps
        )
        .keyboardType(.numberPad)
        .onChange(of: repsText) { _, _ in
            draft.reps = parsedReps
            invalidateCompletedSetWithoutRequiredInputs()
            schedulePersistIfIdle()
        }
    }

    @ViewBuilder
    private var weightInput: some View {
        if trackingKind.requiresWeight {
            compactField(
                weightPlaceholder,
                text: $weightText,
                width: dynamicTypeSize.isAccessibilitySize ? 136 : 72,
                field: .weight
            )
            .keyboardType(.decimalPad)
            .onChange(of: weightText) { _, _ in
                draft.weight = parsedWeight
                invalidateCompletedSetWithoutRequiredInputs()
                schedulePersistIfIdle()
            }
        }
    }

    private var completionButton: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: draft.isComplete ? "checkmark" : "circle")
                .font(.subheadline.weight(.black))
                .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftAccentText)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 48 : 38, height: dynamicTypeSize.isAccessibilitySize ? 48 : 38)
                .background(draft.isComplete ? Color.liftGreen : Color.liftBlue.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(!draft.isComplete && !hasRequiredInputs ? 0.55 : 1)
        .accessibilityLabel(draft.isComplete ? "Mark set incomplete" : "Complete set")
    }

    private var rpeMenu: some View {
        Menu {
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button {
                    cancelPendingPersist()
                    draft.rpe = draft.rpe == value ? nil : value
                    persistDraft()
                    Haptics.light()
                } label: {
                    if draft.rpe == value {
                        Label("RPE \(value)", systemImage: "checkmark")
                    } else {
                        Text("RPE \(value)")
                    }
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 2) {
                        Text("RPE")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.liftMuted)
                        Text(draft.rpe.map { String($0) } ?? "—")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.liftText)
                    }
                    .frame(minWidth: 88, minHeight: 88)
                } else {
                    HStack(spacing: 4) {
                        Text("RPE")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.liftMuted)
                        Text(draft.rpe.map { String($0) } ?? "—")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.liftText)
                    }
                    .frame(width: 64, height: 44)
                }
            }
            .background(Color.liftCardRaised)
            .clipShape(Capsule())
        }
        .accessibilityLabel(draft.rpe.map { "RPE \($0)" } ?? "Choose RPE")
        .accessibilityHint("Choose a value from 6 to 10. Select the current value again to clear it.")
    }

    private var setOptionsButton: some View {
        Button {
            showingDetails.toggle()
        } label: {
            Label(showingDetails ? "Done" : "Set options", systemImage: showingDetails ? "checkmark" : "ellipsis.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showingDetails ? "Hide set options" : "Show set options")
    }

    @ViewBuilder
    private var setRowActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                if !draft.isWarmup { rpeMenu }
                setOptionsButton
            }
        } else {
            HStack(spacing: 6) {
                if !draft.isWarmup { rpeMenu }
                Spacer(minLength: 0)
                setOptionsButton
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        setNumberBadge
                        Spacer(minLength: 0)
                        completionButton
                    }
                    previousValuesButton
                    HStack(spacing: 8) {
                        repsInput
                        weightInput
                        Spacer(minLength: 0)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    setNumberBadge
                    previousValuesButton
                    repsInput
                    weightInput
                    completionButton
                }
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

            setRowActions
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            cancelPendingPersist()
            persistDraft()
            onPersistImmediately()
        }
        .onChange(of: log) { _, updated in
            guard updated.id == draft.id, !isDeleting else { return }
            let editingThisSet = isInputFocus(focusedInput)
            var refreshed = updated
            if editingThisSet {
                refreshed.reps = draft.reps
                refreshed.weight = draft.weight
                refreshed.rpe = draft.rpe
            }
            draft = refreshed
            if !editingThisSet {
                repsText = updated.reps.map(String.init) ?? ""
                weightText = updated.weight.map(Self.formatWeight) ?? ""
            }
            lastPersistedDraft = updated
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
            .frame(width: width)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 38)
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

    private func invalidateCompletedSetWithoutRequiredInputs() {
        guard draft.isComplete, !hasRequiredInputs else { return }
        draft.isComplete = false
        draft.completionSource = nil
        draft.hasTriggeredRestTimer = false
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
