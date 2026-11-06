import SwiftUI

struct ActiveWorkoutSubstitutePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let exercise: WorkoutExerciseSnapshot
    @State private var pendingSubstitute: TrainingExerciseCatalogItem?

    private var hasUnfinishedInput: Bool {
        appState.setLogs(for: exercise).contains {
            !$0.isComplete && ($0.weight != nil || $0.reps != nil || $0.rpe != nil)
        }
    }

    private var sourceExercise: TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID } ?? exercise.fallbackCatalogExercise
    }

    private var activeExerciseIDs: Set<String> {
        Set(appState.activeWorkout?.exercises.map(\.exerciseID) ?? []).subtracting([exercise.exerciseID])
    }

    private var recommendations: [ExerciseSubstitutionRecommendation] {
        appState.substitutionRecommendations(for: sourceExercise, limit: 12)
    }

    var body: some View {
        let recommendations = recommendations
        let activeExerciseIDs = activeExerciseIDs
        return NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LiftSheetHeader(
                            title: "Find a substitute",
                            subtitle: "Replace \(exercise.exerciseName) in this workout only."
                        )

                        if recommendations.isEmpty {
                            LiftEmptyState(
                                title: "No substitutes found",
                                message: "Try adding a different exercise from the library.",
                                symbolName: "arrow.triangle.2.circlepath"
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                                    let substitute = recommendation.exercise
                                    let alreadyInWorkout = activeExerciseIDs.contains(substitute.id)
                                    Button {
                                        guard !alreadyInWorkout else { return }
                                        if hasUnfinishedInput {
                                            pendingSubstitute = substitute
                                        } else {
                                            _ = appState.substituteActiveWorkoutExercise(exercise, with: substitute)
                                            dismiss()
                                        }
                                    } label: {
                                        HStack(spacing: 13) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(substitute.name)
                                                    .font(LiftTypography.rowEmphasis)
                                                    .foregroundStyle(Color.liftText)
                                                Text(recommendation.reasons.joined(separator: " • "))
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                                    .lineLimit(2)
                                                if alreadyInWorkout {
                                                    Text("Already in this workout")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(Color.liftGold)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: alreadyInWorkout ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                                .font(LiftTypography.cardTitle)
                                                .foregroundStyle(alreadyInWorkout ? Color.liftMuted : Color.liftAccentText)
                                        }
                                        .padding(14)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(alreadyInWorkout)
                                    .accessibilityIdentifier("activeWorkout.substitute.\(substitute.id)")

                                    if index < recommendations.count - 1 {
                                        Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                                    }
                                }
                            }
                            .liftSurface()
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Substitute")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Clear unfinished set entries?",
                isPresented: Binding(get: { pendingSubstitute != nil }, set: { if !$0 { pendingSubstitute = nil } }),
                titleVisibility: .visible
            ) {
                Button("Clear entries and substitute") {
                    if let pendingSubstitute {
                        _ = appState.substituteActiveWorkoutExercise(exercise, with: pendingSubstitute)
                        dismiss()
                    }
                    pendingSubstitute = nil
                }
                Button("Keep editing", role: .cancel) { pendingSubstitute = nil }
            } message: {
                Text("Unfinished weight, reps, and effort for \(exercise.exerciseName) will be cleared. Completed sets stay in this workout.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

