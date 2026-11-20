import SwiftUI

enum TopLiftCardDestination: Identifiable {
    case submitted(LiftSubmission)
    case exerciseHistory(id: String, name: String)
    case totalStrength(PowerliftingBreakdown)

    var id: String {
        switch self {
        case .submitted(let lift): "submitted-\(lift.id)"
        case .exerciseHistory(let id, _): "history-\(id)"
        case .totalStrength: "total-strength"
        }
    }

    var title: String {
        switch self {
        case .submitted(let lift): lift.exerciseName
        case .exerciseHistory(_, let name): "\(name) history"
        case .totalStrength: "Total strength"
        }
    }
}

struct TopLiftCardDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrefill: LiftSubmissionPrefill?
    let destination: TopLiftCardDestination

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    content
                        .padding(16)
                }
            }
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
        .sheet(item: $selectedPrefill) { prefill in
            SubmitLiftView(prefill: prefill)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .submitted(let lift):
            submittedLiftDetails(lift)
        case .exerciseHistory(let id, let name):
            exerciseLiftHistory(id: id, name: name)
        case .totalStrength(let breakdown):
            totalStrengthDetails(breakdown)
        }
    }

    private func submittedLiftDetails(_ lift: LiftSubmission) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LiftCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(MeasurementFormatting.recordedLiftSetText(
                        weight: lift.weight,
                        unit: lift.unit,
                        repetitions: lift.repetitions
                    ))
                    .font(LiftTypography.sectionTitle)
                    Text("Performed \(LiftTimeFormatter.shortDateTime(lift.performedAt))")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                    VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
                }
            }
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(lift.isActualOneRepMax ? "Actual 1RM" : "Estimated 1RM", MeasurementFormatting.formatBodyweight(lift.estimatedOneRepMax, preferredUnit: appState.currentProfile.preferredUnit))
                    detailRow("Created", LiftTimeFormatter.shortDateTime(lift.createdAt))
                    detailRow("Equipment", lift.equipmentType.rawValue)
                    if !lift.variation.isEmpty { detailRow("Variation", lift.variation) }
                    detailRow("Visibility", lift.visibility.rawValue)
                    if !lift.caption.isEmpty { detailRow("Note", lift.caption) }
                }
            }
        }
    }

    private func exerciseLiftHistory(id: String, name: String) -> some View {
        let exerciseIDs = appState.trainingExerciseLibrary
            .filter { $0.rankingExerciseID == id || $0.id == id }
            .map(\.id)
        let entries = exerciseIDs.flatMap { exerciseID in
            let submissionExerciseID = MockData.exercises.first(where: { $0.id == exerciseID })?.id
                ?? appState.trainingExerciseLibrary.first(where: { $0.id == exerciseID })?.rankingExerciseID
                ?? id
            return appState.exerciseHistory(for: exerciseID).flatMap { history in
                history.sets.compactMap { workoutSet -> HistoricalLiftSet? in
                    guard let weight = workoutSet.weight, weight > 0,
                          let reps = workoutSet.reps, reps > 0,
                          let exercise = history.workout.exercises.first(where: { $0.id == workoutSet.prescriptionID }) else {
                        return nil
                    }
                    return HistoricalLiftSet(
                        workoutID: history.workout.id,
                        workoutName: history.workout.name,
                        exerciseName: exercise.exerciseName,
                        submissionExerciseID: submissionExerciseID,
                        workoutSet: workoutSet,
                        estimatedOneRepMaxKilograms: history.estimatedOneRepMaxKilograms(for: workoutSet)
                    )
                }
            }
        }
        .sorted { $0.workoutSet.performedAt > $1.workoutSet.performedAt }

        return VStack(alignment: .leading, spacing: 12) {

            if entries.isEmpty {
                LiftEmptyState(
                    title: "No past workout lifts found",
                    message: "You can start a new \(name.lowercased()) submission instead.",
                    symbolName: "dumbbell"
                )
            } else {
                let workoutIDs = entries.reduce(into: [UUID]()) { ids, entry in
                    if !ids.contains(entry.workoutID) { ids.append(entry.workoutID) }
                }
                ForEach(workoutIDs, id: \.self) { workoutID in
                    let sets = entries.filter { $0.workoutID == workoutID }.sorted { $0.workoutSet.setNumber < $1.workoutSet.setNumber }
                    LiftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if let first = sets.first {
                                Text(first.workoutName).font(.headline)
                                Text(LiftTimeFormatter.shortDateTime(first.workoutSet.performedAt)).font(.caption).foregroundStyle(Color.liftMuted)
                            }
                            ForEach(sets) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(entry.exerciseName) · Set \(entry.workoutSet.setNumber)").font(.subheadline.weight(.semibold))
                                    Text(MeasurementFormatting.normalizedLiftSetText(
                                        weightKilograms: MeasurementFormatting.normalizeToKilograms(entry.workoutSet.weight ?? 0, unit: entry.workoutSet.recordedUnit),
                                        preferredUnit: appState.currentProfile.preferredUnit,
                                        repetitions: entry.workoutSet.reps ?? 0,
                                        format: MeasurementFormatting.workoutLoadText
                                    )).monospacedDigit()
                                    if let estimated = entry.estimatedOneRepMaxKilograms {
                                        Text("Est. 1RM · \(MeasurementFormatting.formatDisplayedWeight(estimated, unit: appState.currentProfile.preferredUnit))").font(.caption).foregroundStyle(Color.liftMuted)
                                    }
                                    DisclosureGroup("Recorded values") {
                                        Text(MeasurementFormatting.recordedLiftSetText(weight: entry.workoutSet.weight ?? 0, unit: entry.workoutSet.recordedUnit, repetitions: entry.workoutSet.reps ?? 0, format: MeasurementFormatting.workoutLoadText))
                                    }.font(.caption)
                                    Button("Review submission") {
                                        selectedPrefill = LiftSubmissionPrefill(id: entry.workoutSet.id, exerciseID: entry.submissionExerciseID, weight: entry.workoutSet.weight, unit: entry.workoutSet.recordedUnit, repetitions: entry.workoutSet.reps, performedAt: entry.workoutSet.performedAt)
                                    }.frame(minHeight: 44)
                                    if entry.id != sets.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }

            Button("Submit a new \(name.lowercased()) lift") {
                selectedPrefill = LiftSubmissionPrefill(exerciseID: id)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftLime)
            .foregroundStyle(Color.liftOnAccent)
        }
    }

    private func totalStrengthDetails(_ breakdown: PowerliftingBreakdown) -> some View {
        let unit = appState.currentProfile.preferredUnit
        return VStack(alignment: .leading, spacing: 12) {
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(MeasurementFormatting.formatDisplayedWeight(breakdown.totalKilograms, unit: unit))
                        .font(.title2.weight(.bold))
                    Text("Sum of submitted one-rep-max squat, bench, and deadlift records.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    totalRow("Squat", kilograms: breakdown.squatKilograms, unit: unit)
                    totalRow("Bench", kilograms: breakdown.benchKilograms, unit: unit)
                    totalRow("Deadlift", kilograms: breakdown.deadliftKilograms, unit: unit)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Color.liftMuted)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func totalRow(_ title: String, kilograms: Double?, unit: UnitSystem) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(kilograms.map { MeasurementFormatting.formatDisplayedWeight($0, unit: unit) } ?? "Not included")
                .foregroundStyle(kilograms == nil ? Color.liftMuted : Color.liftText)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
    }
}

private struct HistoricalLiftSet: Identifiable {
    let workoutID: UUID
    let workoutName: String
    let exerciseName: String
    let submissionExerciseID: String
    let workoutSet: WorkoutSetLog
    let estimatedOneRepMaxKilograms: Double?

    var id: UUID { workoutSet.id }
}

private extension ExerciseHistoryEntry {
    func estimatedOneRepMaxKilograms(for set: WorkoutSetLog) -> Double? {
        guard let weight = set.weight, let reps = set.reps else { return nil }
        let kilograms = set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
        return RankingCalculator.epleyOneRepMax(weight: kilograms, repetitions: reps)
    }
}
