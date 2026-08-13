import SwiftUI

struct ActiveWorkoutAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedBodyPart = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedIDs: Set<String> = []
    @State private var descriptionExercise: TrainingExerciseCatalogItem?
    @State private var showingCreateExercise = false

    private let bodyPartFilters = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

    private var existingIDs: Set<String> {
        Set(appState.activeWorkout?.exercises.map(\.exerciseID) ?? [])
    }

    private var equipmentFilters: [String] {
        ["All"] + Array(Set(appState.trainingExerciseLibrary.map(\.equipment))).sorted()
    }

    private var results: [ExerciseSearchResult] {
        appState.searchExercises(query: searchText)
            .filter { selectedBodyPart == "All" || matchesBodyPart($0.exercise, filter: selectedBodyPart) }
            .filter { selectedEquipment == "All" || $0.exercise.equipment == selectedEquipment }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        searchField
                        filterBar
                        createExerciseButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { result in
                                let exercise = result.exercise
                                let isExisting = existingIDs.contains(exercise.id)
                                let isSelected = selectedIDs.contains(exercise.id)
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
                                .onTapGesture {
                                    guard !isExisting else { return }
                                    if isSelected { selectedIDs.remove(exercise.id) }
                                    else { selectedIDs.insert(exercise.id) }
                                }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    descriptionExercise = exercise
                                    Haptics.light()
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(isExisting ? "\(exercise.name), already in workout" : isSelected ? "\(exercise.name), selected" : exercise.name)

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
            .alert(item: $descriptionExercise) { exercise in
                Alert(
                    title: Text(exercise.name),
                    message: Text(exerciseDescription(for: exercise)),
                    dismissButton: .default(Text("Done"))
                )
            }
            .sheet(isPresented: $showingCreateExercise) {
                LibraryCustomExerciseView { exercise in
                    appState.addExercisesToActiveWorkout([exercise])
                    dismiss()
                }
                .environmentObject(appState)
                .presentationDetents([.large])
            }
        }
    }

    private var createExerciseButton: some View {
        Button {
            showingCreateExercise = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                Text("Create custom exercise")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.liftBlue)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.liftBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout.addExercise.createCustom")
    }

    private func exerciseDescription(for exercise: TrainingExerciseCatalogItem) -> String {
        guard let guidance = exercise.guidance else {
            return "\(exercise.bodyPart) exercise using \(exercise.equipment)."
        }

        if guidance.cues.isEmpty {
            return guidance.summary
        }

        return "\(guidance.summary)\n\nCues: \(guidance.cues.joined(separator: " • "))"
    }

    private var searchField: some View {
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
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bodyPartFilters, id: \.self) { filter in
                    filterChip(filter, isSelected: selectedBodyPart == filter) {
                        selectedBodyPart = filter
                    }
                }

                Menu {
                    ForEach(equipmentFilters, id: \.self) { equipment in
                        Button(equipment) { selectedEquipment = equipment }
                    }
                } label: {
                    Label(selectedEquipment == "All" ? "Equipment" : selectedEquipment, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selectedEquipment == "All" ? Color.liftCard : Color.liftBlue.opacity(0.18))
                        .foregroundStyle(selectedEquipment == "All" ? Color.liftMuted : Color.liftBlue)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? Color.liftBlue : Color.liftCard)
                .foregroundStyle(isSelected ? Color.liftOnAccent : Color.liftMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func matchesBodyPart(_ exercise: TrainingExerciseCatalogItem, filter: String) -> Bool {
        let bodyPart = exercise.bodyPart.lowercased()
        switch filter {
        case "Back":
            return bodyPart.contains("back") || bodyPart.contains("lat") || bodyPart.contains("trap")
        case "Shoulders":
            return bodyPart.contains("shoulder") || bodyPart.contains("delt") || bodyPart.contains("rotator")
        case "Arms":
            return bodyPart.contains("bicep") || bodyPart.contains("tricep") || bodyPart.contains("arm") || bodyPart.contains("forearm")
        case "Legs":
            return bodyPart.contains("quad") || bodyPart.contains("hamstring") || bodyPart.contains("leg") || bodyPart.contains("calf") || bodyPart.contains("adductor") || bodyPart.contains("tibialis")
        case "Core":
            return bodyPart.contains("core") || bodyPart.contains("oblique")
        default:
            return bodyPart.contains(filter.lowercased())
        }
    }
}
