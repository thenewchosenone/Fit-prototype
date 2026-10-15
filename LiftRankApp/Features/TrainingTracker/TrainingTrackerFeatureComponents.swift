import SwiftUI

struct PlateauInsightDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let insight: PlateauInsight

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Possible plateau", systemImage: "equal.circle.fill")
                                .font(.title3.weight(.black))
                                .foregroundStyle(Color.liftGold)
                            Text(insight.exerciseName)
                                .font(.headline)
                            Text("Estimated strength and total working-set volume have not increased by more than 1% across these three workouts.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(insight.performances.enumerated()), id: \.element.id) { index, performance in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(performance.performedAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                        Text(setDescription(performance))
                                            .font(.subheadline.weight(.bold).monospacedDigit())
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text("EST. 1RM")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Color.liftMuted)
                                        Text(oneRepMaxDescription(performance))
                                            .font(.subheadline.weight(.bold))
                                    }
                                }
                                .padding(14)
                                if index < insight.performances.count - 1 {
                                    Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                                }
                            }
                        }
                        .liftSurface()

                        LiftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Insight, not instruction")
                                    .font(.headline)
                                Text("A plateau can be normal. Review recovery, technique, exercise order, and programming before adding load. Increase weight or repetitions only when your form and readiness support it.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Plateau details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func setDescription(_ performance: PlateauPerformance) -> String {
        return MeasurementFormatting.normalizedLiftSetText(
            weightKilograms: performance.weightKilograms,
            preferredUnit: appState.currentProfile.preferredUnit,
            repetitions: performance.repetitions
        )
    }

    private func oneRepMaxDescription(_ performance: PlateauPerformance) -> String {
        return MeasurementFormatting.formatDisplayedWeight(
            performance.estimatedOneRepMaxKilograms,
            unit: appState.currentProfile.preferredUnit
        )
    }
}
