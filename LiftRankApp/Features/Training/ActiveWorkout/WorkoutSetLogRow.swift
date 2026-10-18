import SwiftUI
import UIKit

struct WorkoutSetLogRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState.Binding var focusedInput: WorkoutSetInputFocus?
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
    let showsEffortControls: Bool
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
        showsEffortControls: Bool = false,
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
        self.showsEffortControls = showsEffortControls
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
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    private static func formatWeight(_ value: Double) -> String {
        RankingCalculator.format(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            setEntryInputs

            if showingDetails {
                HStack(spacing: 10) {
                    Button {
                        draft.isWarmup.toggle()
                        persistDraft()
                    } label: {
                        Label(draft.isWarmup ? "Warm-up set" : "Working set", systemImage: draft.isWarmup ? "flame.fill" : "dumbbell.fill")
                            .font(LiftTypography.compactEmphasis)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.isWarmup ? Color.liftGold : Color.liftMuted)
                    .accessibilityLabel(draft.isWarmup ? "Mark as working set" : "Mark as warm-up set")

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        isDeleting = true
                        cancelPendingPersist()
                        onDelete(draft)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(LiftTypography.compactEmphasis)
                    }
                }
            }

            if showingDetails || (showsEffortControls && !draft.isWarmup) {
                setOptionsControls
            } else if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    if let rpe = draft.rpe, !draft.isWarmup {
                        Text("RPE \(rpe)").font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    setOptionsButton
                }
            } else if let rpe = draft.rpe, !draft.isWarmup {
                Text("RPE \(rpe)").font(.caption).foregroundStyle(Color.liftMuted)
            }

            if (showingDetails || showsEffortControls) && !draft.isWarmup {
                Text("RPE rates set effort out of 10. A 10 means you could not complete another rep.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }

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
                Label(showingDetails ? "Hide set effort (RPE)" : "Add set effort (RPE)", systemImage: "slider.horizontal.3")
            }
            Button {
                cancelPendingPersist()
                draft.isWarmup.toggle()
                persistDraft()
            } label: {
                Label(draft.isWarmup ? "Mark Working Set" : "Mark Warm-up Set", systemImage: "flame")
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
        let weight = MeasurementFormatting.formatRecordedWeight(
            MeasurementFormatting.convert(previousLog.weight ?? 0, from: previousLog.recordedUnit, to: draft.recordedUnit),
            unit: draft.recordedUnit
        )
        switch trackingKind {
        case .weightReps:
            return "\(reps) × \(weight)"
        case .bodyweightReps, .repsOnly:
            return "\(reps) reps"
        case .assistedBodyweight:
            return "\(reps) × \(weight) assist"
        case .time:
            return MeasurementFormatting.shortClockText(TimeInterval(reps))
        case .weightTime:
            return "\(MeasurementFormatting.shortClockText(TimeInterval(reps))) × \(weight)"
        }
    }

    @ViewBuilder
    private var setEntryInputs: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    setNumberBadge
                    previousValuesButton
                }
                HStack(spacing: 8) {
                    repsInput
                    if trackingKind.requiresWeight { weightInput }
                    completionButton
                }
            }
        } else {
            HStack(spacing: 6) {
                setNumberBadge
                previousValuesButton
                repsInput
                if trackingKind.requiresWeight { weightInput }
                completionButton
                setOptionsButton
            }
        }
    }

    private var setNumberBadge: some View {
        Text("\(draft.setNumber)")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftText)
            .frame(
                width: dynamicTypeSize.isAccessibilitySize ? 56 : 34,
                height: dynamicTypeSize.isAccessibilitySize ? 56 : LiftDesign.minimumTouchTarget
            )
            .background(draft.isComplete ? Color.liftGreen : Color.liftCardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var previousValuesButton: some View {
        Button {
            usePreviousValues()
        } label: {
            Text(dynamicTypeSize.isAccessibilitySize
                 ? (previousLog == nil ? "No previous set" : "Prev · \(previousSummary)")
                 : (previousLog == nil ? "—" : previousSummary))
                .font(.caption.weight(.bold).monospacedDigit())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(previousLog == nil ? Color.liftMuted : Color.liftAccentText)
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 56 : LiftDesign.minimumTouchTarget)
                .background(Color.liftScrim)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(previousLog == nil)
        .accessibilityIdentifier("workout.set.\(draft.setNumber).previousValues")
        .accessibilityLabel(previousLog == nil ? "No previous set values" : "Use previous workout values: \(previousSummary)")
    }

    private var repsInput: some View {
        compactField(trackingKind.usesDuration ? "Sec" : "Reps", text: $repsText, width: 56, field: .reps)
            .keyboardType(.numberPad)
            .onChange(of: repsText) { _, _ in
                draft.reps = parsedReps
                invalidateCompletedSetWithoutRequiredInputs()
                schedulePersistIfIdle()
            }
    }

    private var weightInput: some View {
        compactField(weightPlaceholder, text: $weightText, width: 64, field: .weight)
            .keyboardType(.decimalPad)
            .onChange(of: weightText) { _, _ in
                draft.weight = parsedWeight
                invalidateCompletedSetWithoutRequiredInputs()
                schedulePersistIfIdle()
            }
    }

    private var completionButton: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: draft.isComplete ? "checkmark" : "circle")
                .font(LiftTypography.rowEmphasis)
                .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftAccentText)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 56 : LiftDesign.minimumTouchTarget,
                    height: dynamicTypeSize.isAccessibilitySize ? 56 : LiftDesign.minimumTouchTarget
                )
                .background(draft.isComplete ? Color.liftGreen : Color.liftBlue.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(!draft.isComplete && !hasRequiredInputs ? 0.55 : 1)
        .accessibilityLabel(draft.isComplete ? "Mark set incomplete" : "Complete set")
    }

    @ViewBuilder
    private var setOptionsControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                if !draft.isWarmup {
                    Text("Effort (RPE)")
                        .font(LiftTypography.compactEmphasis)
                        .foregroundStyle(Color.liftMuted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        rpeButtons
                    }
                }
                setOptionsButton
            }
            .padding(.top, 1)
        } else {
            HStack(spacing: 6) {
                if !draft.isWarmup {
                    Text("Effort")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 40, alignment: .leading)
                    rpeButtons
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 1)
        }
    }

    @ViewBuilder
    private var rpeButtons: some View {
        ForEach([6, 7, 8, 9, 10], id: \.self) { value in
            Button {
                cancelPendingPersist()
                draft.rpe = draft.rpe == value ? nil : value
                persistDraft()
                Haptics.light()
            } label: {
                Text("\(value)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(draft.rpe == value ? Color.liftOnAccent : Color.liftText)
                    .frame(
                        maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : LiftDesign.minimumTouchTarget,
                        minHeight: dynamicTypeSize.isAccessibilitySize ? 48 : LiftDesign.minimumTouchTarget
                    )
                    .background(draft.rpe == value ? rpeTint(value) : rpeTint(value).opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set effort to \(value) out of 10, RPE")
            .accessibilityAddTraits(draft.rpe == value ? .isSelected : [])
        }
    }

    private var setOptionsButton: some View {
        Button {
            showingDetails.toggle()
        } label: {
            Image(systemName: showingDetails ? "checkmark" : "ellipsis")
                .frame(width: LiftDesign.minimumTouchTarget)
                .font(.caption.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Color.liftMuted)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showingDetails ? "Hide set options" : "Show set options")
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
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : width,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 56 : LiftDesign.minimumTouchTarget
            )
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
