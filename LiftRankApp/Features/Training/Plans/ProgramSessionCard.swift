import SwiftUI

struct ProgramSessionCard: View {
    @EnvironmentObject private var appState: AppState
    let session: WorkoutSession
    let week: WorkoutWeek
    let onStart: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            let prescriptions = appState.prescriptions(for: session)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(session.day) · \(session.name)")
                            .font(.headline)
                        Text("\(prescriptions.count) exercises - \(appState.completedPrescriptionCount(for: session)) complete")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete Workout Day")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, prescription in
                        HStack(spacing: 11) {
                            ExerciseCatalogIcon(exercise: catalogExercise(for: prescription))
                                .frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prescription.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(prescription.sets) × \(prescription.reps) • \(prescription.bodyPart)")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 52)

                        if index < prescriptions.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 49)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onAddExercise) {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)

                    Button(action: onStart) {
                        Label("Start", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                }
            }
        }
    }

    private func catalogExercise(for prescription: WorkoutExercisePrescription) -> TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == prescription.exerciseID } ?? TrainingExerciseCatalogItem(
            id: prescription.exerciseID,
            name: prescription.exerciseName,
            bodyPart: prescription.bodyPart,
            workoutCategory: prescription.bodyPart,
            defaultSets: prescription.sets,
            defaultReps: prescription.reps,
            symbolName: "figure.strengthtraining.traditional",
            equipment: prescription.equipment,
            muscleProfile: prescription.muscleProfile
        )
    }
}
