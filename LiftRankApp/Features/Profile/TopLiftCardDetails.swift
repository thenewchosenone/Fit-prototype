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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
                    .font(.title3.weight(.bold))
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
            Text("Choose a past workout set to prefill a lift submission. Review it and add any required evidence before submitting.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)

            if entries.isEmpty {
                LiftEmptyState(
                    title: "No past workout lifts found",
                    message: "You can start a new \(name.lowercased()) submission instead.",
                    symbolName: "dumbbell"
                )
            } else {
                ForEach(entries) { entry in
                    LiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.exerciseName)
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text("\(entry.workoutName) · \(LiftTimeFormatter.shortDateTime(entry.workoutSet.performedAt))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Text(MeasurementFormatting.recordedLiftSetText(
                                weight: entry.workoutSet.weight ?? 0,
                                unit: entry.workoutSet.recordedUnit,
                                repetitions: entry.workoutSet.reps ?? 0
                            ))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            if let estimated = entry.estimatedOneRepMaxKilograms {
                                Text("\(entry.workoutSet.reps == 1 ? "1RM" : "Est. 1RM") \(MeasurementFormatting.formatDisplayedWeight(estimated, unit: appState.currentProfile.preferredUnit))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Button("Submit this set") {
                                selectedPrefill = LiftSubmissionPrefill(
                                    id: entry.workoutSet.id,
                                    exerciseID: entry.submissionExerciseID,
                                    weight: entry.workoutSet.weight,
                                    unit: entry.workoutSet.recordedUnit,
                                    repetitions: entry.workoutSet.reps,
                                    performedAt: entry.workoutSet.performedAt
                                )
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                            .frame(minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                        }
                    }
                }
            }

            Button("Submit a new \(name.lowercased()) lift") {
                selectedPrefill = LiftSubmissionPrefill(exerciseID: id)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftBlue)
        }
    }

    private func totalStrengthDetails(_ breakdown: PowerliftingBreakdown) -> some View {
        let unit = appState.currentProfile.preferredUnit
        return VStack(alignment: .leading, spacing: 12) {
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(MeasurementFormatting.formatDisplayedWeight(breakdown.totalKilograms, unit: unit))
                        .font(.title2.weight(.black))
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
