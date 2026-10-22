import SwiftUI

struct ProgramSessionCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedWorkout: CompletedWorkout?
    @State private var focusedSetID: UUID?
    @State private var showsExercises = false
    @State private var replacingPrescription: WorkoutExercisePrescription?
    let session: WorkoutSession
    let prescriptions: [WorkoutExercisePrescription]
    let completedPrescriptionCount: Int
    let catalogByID: [String: TrainingExerciseCatalogItem]
    let onStart: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(session.day) · \(session.name)")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Menu {
                            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) { day in
                                Button(day) { appState.changeWorkoutDay(session, to: day) }
                            }
                        } label: {
                            Label("Change day", systemImage: "calendar")
                                .font(.caption.weight(.semibold))
                        }
                        .disabled(appState.activeWorkout != nil)
                        .accessibilityHint("Changes this workout in the selected week. Saved workout history is preserved.")
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Menu {
                        Button(action: onAddExercise) {
                            Label("Add Exercise", systemImage: "plus")
                        }
                        .disabled(appState.activeWorkout != nil)
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete Workout Day")
                        }
                        .disabled(appState.activeWorkout != nil)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftAccentText)
                            .frame(width: 44, height: 44)
                    }
                }

                Button(action: onStart) {
                    Label(hasSavedWorkout ? "Repeat workout" : "Start workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())
                .accessibilityHint(hasSavedWorkout ? "Starts a new workout attempt. Saved workout history remains available." : "Starts this scheduled workout.")
                if hasSavedWorkout {
                    Text("Repeating starts a new workout; saved history remains.")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                    if let workout = appState.completedWorkouts
                        .filter({ $0.sourceSessionID == session.id })
                        .max(by: { $0.completedAt < $1.completedAt }) {
                        Button("Review saved workout") { selectedWorkout = workout }
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if prescriptions.isEmpty {
                    Text("No exercises added yet.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    Button {
                        withAnimation(.snappy) { showsExercises.toggle() }
                    } label: {
                        HStack {
                            Text("\(prescriptions.count) exercises · \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftText)
                            Spacer()
                            Text(showsExercises ? "Hide" : "Show")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftAccentText)
                            Image(systemName: showsExercises ? "chevron.up" : "chevron.down")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftAccentText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(prescriptions.count) exercises, \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                    .accessibilityValue(showsExercises ? "Expanded" : "Collapsed")
                }

                if showsExercises {
                    VStack(spacing: 0) {
                        ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, prescription in
                            HStack(spacing: 12) {
                                ExerciseCatalogIcon(exercise: catalogExercise(for: prescription))
                                    .frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prescription.exerciseName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(prescription.sets) × \(prescription.reps) • \(prescription.bodyPart)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(1)
                                    if let kilograms = prescription.targetLoadKilograms {
                                        Text("Suggested weight: \(MeasurementFormatting.convert(kilograms, from: .kilograms, to: appState.currentProfile.preferredUnit).formatted(.number.precision(.fractionLength(0...1)))) \(appState.currentProfile.preferredUnit.shortLabel)")
                                            .font(.caption2).foregroundStyle(Color.liftAccentText)
                                    } else if !ExerciseTrackingKind(catalogExercise(for: prescription).trackingType).usesDuration, let rir = prescription.targetRIR {
                                        Text("Target: \(rir) reps in reserve").font(.caption2).foregroundStyle(Color.liftMuted)
                                    }
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        replacingPrescription = prescription
                                    } label: {
                                        Label("Replace throughout plan", systemImage: "arrow.triangle.swap")
                                    }
                                    .disabled(appState.activeWorkout != nil)
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Options for \(prescription.exerciseName)")
                            }
                            .padding(.vertical, 7)
                            .frame(minHeight: 66)

                            if index < prescriptions.count - 1 {
                                Divider()
                                    .overlay(Color.liftOverlay)
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }

            }
        }
        .sheet(item: $selectedWorkout) { workout in
            CompletedWorkoutDetailView(workout: workout, focusedSetID: $focusedSetID)
                .environmentObject(appState)
        }
        .sheet(item: $replacingPrescription) { prescription in
            ProgramAddExercisePickerView(session: session, replacingPrescription: prescription)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private var statusText: String {
        if let outcome = session.outcome { return outcome == .rest ? "Marked as rest" : "Skipped" }
        if appState.isFullyCompletedPlanSession(session) { return "All planned sets completed" }
        if appState.completedWorkouts.contains(where: { $0.sourceSessionID == session.id }) {
            return "Shortened session saved · \(completedPrescriptionCount)/\(prescriptions.count) exercises completed"
        }
        return "\(completedPrescriptionCount) of \(prescriptions.count) exercises completed"
    }

    private var hasSavedWorkout: Bool {
        appState.completedWorkouts.contains { $0.sourceSessionID == session.id }
    }

    private func catalogExercise(for prescription: WorkoutExercisePrescription) -> TrainingExerciseCatalogItem {
        catalogByID[prescription.exerciseID] ?? TrainingExerciseCatalogItem(
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
