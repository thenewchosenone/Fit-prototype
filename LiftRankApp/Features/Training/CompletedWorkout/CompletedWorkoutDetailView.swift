import SwiftUI

struct CompletedWorkoutDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let workout: CompletedWorkout
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workout.name)
                                .font(.title2.weight(.black))
                            Text(LiftTimeFormatter.shortDateTime(workout.completedAt))
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            HStack(spacing: 8) {
                                detailMetric("Duration", durationText, "timer")
                                detailMetric("Sets", "\(workout.completedWorkingSets.count)", "checkmark.circle")
                                detailMetric("Volume", "\(Int(workout.totalVolume))", "scalemass")
                            }
                        }
                        .padding(14)
                        .liftSurface()

                        ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                            let trackingKind = trackingKind(for: exercise)
                            let sets = workout.sets
                                .filter { $0.prescriptionID == exercise.id && $0.isComplete }
                                .sorted { $0.setNumber < $1.setNumber }
                            if !sets.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        ExerciseMuscleMap(profile: exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: exercise.exerciseName, bodyPart: exercise.bodyPart))
                                            .frame(width: 46, height: 46)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(exercise.exerciseName)
                                                .font(.headline.weight(.bold))
                                            Text((exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: exercise.exerciseName, bodyPart: exercise.bodyPart)).primaryDescription)
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                    }
                                    ForEach(sets) { set in
                                        HStack {
                                            Text(set.isWarmup ? "Warmup \(set.setNumber)" : "Set \(set.setNumber)")
                                                .foregroundStyle(set.isWarmup ? Color.liftGold : Color.liftMuted)
                                            Spacer()
                                            Text(MeasurementFormatting.workoutSetText(set: set, trackingKind: trackingKind))
                                                .font(.subheadline.weight(.bold).monospacedDigit())
                                            if let rpe = set.rpe {
                                                Text("@ \(rpe)")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(Color.liftBlue)
                                            }
                                        }
                                        .font(.subheadline)
                                        if set.id != sets.last?.id {
                                            Divider().overlay(Color.white.opacity(0.06))
                                        }
                                    }
                                }
                                .padding(14)
                                .liftSurface()
                            }
                        }

                        if !workout.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.headline.weight(.bold))
                                Text(workout.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(14)
                            .liftSurface()
                        }

                        if !workout.linkedSubmissionIDs.isEmpty {
                            Label("\(workout.linkedSubmissionIDs.count) public lift submission linked. Deleting this history entry will not delete it.", systemImage: "link")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                                .padding(14)
                                .liftSurface()
                        }

                        PrimaryButton(title: "Share to Community", symbolName: "person.3.fill") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                appState.beginForumComposer(workoutID: workout.id)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Workout details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete workout history")
                }
            }
            .confirmationDialog("Delete this workout from history?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete History", role: .destructive) {
                    appState.deleteCompletedWorkout(workout)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The workout snapshot is removed. Any public lift submissions already created remain public.")
            }
        }
    }

    private var durationText: String {
        MeasurementFormatting.shortDurationText(workout.duration)
    }

    private func trackingKind(for exercise: WorkoutExerciseSnapshot) -> ExerciseTrackingKind {
        let catalog = appState.trainingExerciseLibrary.first { $0.id == exercise.exerciseID }
        return ExerciseTrackingKind(catalog?.trackingType ?? "Weight + Reps")
    }

    private func detailMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
