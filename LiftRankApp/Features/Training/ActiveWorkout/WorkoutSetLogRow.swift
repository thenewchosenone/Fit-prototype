import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false
    @State private var dragOffset: CGFloat = 0

    let actionTitle: String
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    private let actionWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                isOpen = false
                dragOffset = 0
                onDelete()
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash.fill")
                    Text("Delete")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.liftRed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)

            content()
                .contentShape(Rectangle())
                .offset(x: displayedOffset)
                .simultaneousGesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityAction(named: actionTitle, onDelete)
    }

    private var displayedOffset: CGFloat {
        min(0, max(-actionWidth, (isOpen ? -actionWidth : 0) + dragOffset))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                let projectedOffset = (isOpen ? -actionWidth : 0) + value.predictedEndTranslation.width
                animate { isOpen = projectedOffset < -(actionWidth * 0.45) }
                dragOffset = 0
            }
    }

    private func animate(_ changes: @escaping () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappy(duration: 0.22), changes)
        }
    }
}

struct WorkoutSetLogRow: View {
    @EnvironmentObject private var appState: AppState
    @FocusState.Binding var focusedInput: WorkoutSetInputFocus?
    @State private var draft: WorkoutSetLog
    @State private var repsText: String
    @State private var weightText: String
    @State private var showValidation = false
    @State private var showingDetails = false
    @State private var pendingPersistTask: Task<Void, Never>?
    @State private var isDeleting = false
    let previousLog: WorkoutSetLog?
    let trackingKind: ExerciseTrackingKind
    var onCompleted: (() -> Void)?

    init(
        log: WorkoutSetLog,
        trackingKind: ExerciseTrackingKind = .weightReps,
        previousLog: WorkoutSetLog? = nil,
        focusedInput: FocusState<WorkoutSetInputFocus?>.Binding,
        onCompleted: (() -> Void)? = nil
    ) {
        _focusedInput = focusedInput
        _draft = State(initialValue: log)
        _repsText = State(initialValue: log.reps.map(String.init) ?? "")
        _weightText = State(initialValue: log.weight.map(Self.formatWeight) ?? "")
        self.previousLog = previousLog
        self.trackingKind = trackingKind
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
                    Text(previousSummary)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(previousLog == nil ? Color.liftMuted : Color.liftBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(previousLog == nil)
                .accessibilityLabel("Use previous values for set \(draft.setNumber)")

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
                        .foregroundStyle(draft.isComplete ? Color.liftOnAccent : Color.liftBlue)
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
                    Text("Optional details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    OptionalIntegerInputField(title: "RPE", value: Binding(
                        get: { draft.rpe },
                        set: {
                            draft.rpe = $0
                            appState.updateSetLog(draft)
                        }
                    ), presentation: .inset)
                        .frame(maxWidth: 150)

                    Button {
                        draft.isWarmup.toggle()
                        appState.updateSetLog(draft)
                    } label: {
                        Image(systemName: draft.isWarmup ? "flame.fill" : "flame")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.isWarmup ? Color.liftGold : Color.liftMuted)
                    .accessibilityLabel(draft.isWarmup ? "Mark as working set" : "Mark as warmup set")

                    Button(role: .destructive) {
                        isDeleting = true
                        cancelPendingPersist()
                        appState.deleteSetLog(draft)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption.weight(.bold))
                    }
                }
            }

            if !draft.isWarmup {
                HStack(spacing: 6) {
                    Text("RPE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 34, alignment: .leading)
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button {
                            cancelPendingPersist()
                            draft.rpe = draft.rpe == value ? nil : value
                            appState.updateSetLog(draft)
                            Haptics.light()
                        } label: {
                            Text("\(value)")
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(draft.rpe == value ? Color.liftOnAccent : rpeTint(value))
                                .frame(width: 30, height: 28)
                                .background(draft.rpe == value ? rpeTint(value) : rpeTint(value).opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Set RPE to \(value)")
                        .accessibilityAddTraits(draft.rpe == value ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                    Button {
                        showingDetails.toggle()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 30, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More set options")
                }
                .padding(.top, 1)
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
                .stroke(draft.isComplete ? Color.liftGreen.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
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
                appState.updateSetLog(draft)
            } label: {
                Label(draft.isWarmup ? "Mark Working Set" : "Mark Warmup Set", systemImage: "flame")
            }
            Button(role: .destructive) {
                isDeleting = true
                cancelPendingPersist()
                appState.deleteSetLog(draft)
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
            return "\(reps) × \(RankingCalculator.format(previousLog.weight ?? 0))"
        case .bodyweightReps, .repsOnly:
            return "\(reps) reps"
        case .assistedBodyweight:
            return "\(reps) × \(RankingCalculator.format(previousLog.weight ?? 0)) assist"
        case .time:
            return MeasurementFormatting.shortClockText(TimeInterval(reps))
        case .weightTime:
            return "\(MeasurementFormatting.shortClockText(TimeInterval(reps))) × \(RankingCalculator.format(previousLog.weight ?? 0))"
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
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
            weightText = MeasurementFormatting.formatWeight(weight)
            draft.weight = weight
        }
        appState.updateSetLog(draft)
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
        let triggerTimer = appState.applyWorkoutSetCompletion(draft, isComplete: completing, source: .manual)
        draft.isComplete = completing
        draft.performedAt = .now
        draft.completionSource = completing ? .manual : nil
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
                appState.updateSetLog(snapshot)
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
        appState.updateSetLog(draft)
        if appState.attemptAutomaticCompletion(before: draft) {
            onCompleted?()
        }
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
