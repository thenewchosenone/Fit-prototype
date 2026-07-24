import SwiftUI

struct ActiveWorkoutAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []

    private var existingIDs: Set<String> {
        Set(appState.activeWorkout?.exercises.map(\.exerciseID) ?? [])
    }

    private var results: [ExerciseSearchResult] {
        appState.searchExercises(query: searchText)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.liftMuted)
                        TextField("Search exercises", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(16)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { result in
                                let exercise = result.exercise
                                let isExisting = existingIDs.contains(exercise.id)
                                let isSelected = selectedIDs.contains(exercise.id)
                                Button {
                                    guard !isExisting else { return }
                                    if isSelected { selectedIDs.remove(exercise.id) }
                                    else { selectedIDs.insert(exercise.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        ExerciseCatalogIcon(exercise: exercise)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(Color.liftText)
                                            if let reason = result.reasonLabel {
                                                Text(reason)
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(Color.liftBlue)
                                            }
                                            Text("\(exercise.bodyPart) • \(exercise.equipment) • \(exercise.defaultSets) × \(exercise.defaultReps)")
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Image(systemName: isExisting || isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(isExisting ? Color.liftGreen : isSelected ? Color.liftBlue : Color.liftMuted)
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isExisting)

                                Divider().overlay(Color.white.opacity(0.06))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedIDs.isEmpty ? "Add" : "Add \(selectedIDs.count)") {
                        let selected = appState.trainingExerciseLibrary.filter { selectedIDs.contains($0.id) }
                        appState.addExercisesToActiveWorkout(selected)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }
}
