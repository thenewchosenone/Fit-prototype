import SwiftUI

struct ExerciseLibraryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var applied: ExerciseLibraryFilterSelection
    let exercises: [TrainingExerciseCatalogItem]
    let searchText: String
    @State private var draft: ExerciseLibraryFilterSelection

    init(applied: Binding<ExerciseLibraryFilterSelection>, exercises: [TrainingExerciseCatalogItem], searchText: String) {
        _applied = applied
        self.exercises = exercises
        self.searchText = searchText
        _draft = State(initialValue: applied.wrappedValue)
    }

    private var equipmentOptions: [String] { Set(exercises.map(\.equipment)).sorted() }
    private var movementOptions: [String] { Set(exercises.map(\.movementType)).sorted() }
    private var trackingOptions: [String] { Set(exercises.map(\.trackingType)).sorted() }
    private var resultCount: Int {
        exercises.filter { $0.matchesSearch(searchText) && draft.matches($0) }.count
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            bodyAreaSection
                            muscleSection
                            stringSection("Equipment", options: equipmentOptions, selection: $draft.equipment)
                            stringSection("Movement type", options: movementOptions, selection: $draft.movementTypes)
                            stringSection("Tracking type", options: trackingOptions, selection: $draft.trackingTypes)
                        }
                        .padding(16)
                        .padding(.bottom, 90)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Button("Show \(resultCount) Exercises") {
                            applied = draft
                            dismiss()
                        }
                        .buttonStyle(LiftPrimaryButtonStyle())
                        Button("Reset filters") {
                            draft = ExerciseLibraryFilterSelection()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Exercise Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applied = draft
                        dismiss()
                    }
                }
            }
        }
    }

    private var bodyAreaSection: some View {
        filterSectionTitle("Body area") {
            ForEach(ExerciseLibraryBodyArea.allCases) { area in
                filterToggle(area.rawValue, selected: draft.bodyAreas.contains(area)) {
                    toggle(area, in: &draft.bodyAreas)
                }
            }
        }
    }

    private var muscleSection: some View {
        filterSectionTitle("Primary muscle") {
            ForEach(ExerciseMuscleRegion.allCases.filter { $0 != .fullBody }) { muscle in
                filterToggle(muscle.displayName, selected: draft.primaryMuscles.contains(muscle)) {
                    toggle(muscle, in: &draft.primaryMuscles)
                }
            }
        }
    }

    private func stringSection(_ title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        filterSectionTitle(title) {
            ForEach(options, id: \.self) { option in
                filterToggle(option, selected: selection.wrappedValue.contains(option)) {
                    var updated = selection.wrappedValue
                    if updated.contains(option) { updated.remove(option) } else { updated.insert(option) }
                    selection.wrappedValue = updated
                }
            }
        }
    }

    private func filterSectionTitle<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                content()
            }
        }
    }

    private func filterToggle(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(selected ? .white : Color.liftMuted)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(selected ? Color.liftBlue : Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.liftBlue.opacity(0.65) : Color.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

struct CreateCustomExerciseView: View {
    @EnvironmentObject private var appState: AppState
    let session: WorkoutSession
    let onAdded: () -> Void
    @State private var name = ""
    @State private var muscleGroup = "Chest"
    @State private var equipment = "Dumbbell"
    @State private var trackingType = "Weight + Reps"
    @State private var createdExercise: TrainingExerciseCatalogItem?

    private let muscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Core", "Full Body"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let trackingTypes = ["Weight + Reps", "Bodyweight Reps", "Assisted Bodyweight", "Reps Only", "Time", "Weight + Time"]

    var body: some View {
        AppBackground {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name)
                    Picker("Muscle group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Tracking") {
                    ForEach(trackingTypes, id: \.self) { option in
                        ProgramChoiceRow(title: option, isSelected: trackingType == option) {
                            trackingType = option
                        }
                    }
                }

                Section {
                    Button("Save Exercise") {
                        createdExercise = appState.saveCustomExercise(
                            name: name,
                            bodyPart: muscleGroup,
                            equipment: equipment,
                            trackingType: trackingType
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Create Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $createdExercise) { exercise in
            AddExerciseToWorkoutView(exercise: exercise, session: session, onAdded: onAdded)
                .environmentObject(appState)
        }
    }
}

struct LibraryCustomExerciseView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onSaved: (TrainingExerciseCatalogItem) -> Void
    @State private var name = ""
    @State private var muscleGroup = "Chest"
    @State private var equipment = "Dumbbell"
    @State private var trackingType = "Weight + Reps"

    private let muscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Core", "Full Body"]
    private let equipmentOptions = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Kettlebell", "Band"]
    private let trackingTypes = ["Weight + Reps", "Bodyweight Reps", "Assisted Bodyweight", "Reps Only", "Time", "Weight + Time"]

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Exercise") {
                        TextField("Exercise name", text: $name)
                        Picker("Primary area", selection: $muscleGroup) {
                            ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Equipment", selection: $equipment) {
                            ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Section("Tracking") {
                        Picker("Tracking type", selection: $trackingType) {
                            ForEach(trackingTypes, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let exercise = appState.saveCustomExercise(
                            name: name,
                            bodyPart: muscleGroup,
                            equipment: equipment,
                            trackingType: trackingType
                        ) else { return }
                        dismiss()
                        onSaved(exercise)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AddExerciseToWorkoutView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: TrainingExerciseCatalogItem
    let session: WorkoutSession
    let onAdded: () -> Void
    @State private var sets = 3
    @State private var repGoal = "8-12"
    @State private var restSeconds = 120

    private let repGoals = ["1-5", "6-8", "8-12", "12-15", "15-20"]
    private let restOptions = [60, 90, 120, 180]

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ExerciseCatalogIcon(exercise: exercise)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.title3.bold())
                            Text("\(exercise.bodyPart) • \(exercise.equipment)")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    VStack(alignment: .leading, spacing: 16) {
                        IntegerInputField(title: "Sets", value: $sets, presentation: .inset)
                        Text("Rep goal").font(.headline)
                        FlowChipGroup(options: repGoals, selected: $repGoal)
                        Text("Rest time").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
                            ForEach(restOptions, id: \.self) { seconds in
                                ProgramChoiceChip(title: "\(seconds) sec", isSelected: restSeconds == seconds) {
                                    restSeconds = seconds
                                }
                            }
                        }
                    }
                    .padding(14)
                    .liftSurface()

                    Button("Add to Workout") {
                        appState.addExercise(exercise, to: session, sets: sets, reps: repGoal, restSeconds: restSeconds)
                        onAdded()
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }
                .padding(16)
            }
        }
        .navigationTitle("Configure Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sets = exercise.defaultSets
            if repGoals.contains(exercise.defaultReps) { repGoal = exercise.defaultReps }
            restSeconds = exercise.defaultRestSeconds
        }
    }
}

struct ProgramChoiceRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline).foregroundStyle(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.liftBlue : Color.liftMuted)
            }
            .padding(13)
            .background(isSelected ? Color.liftBlue.opacity(0.18) : Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

struct FlowChipGroup: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                ProgramChoiceChip(title: option, isSelected: selected == option) {
                    selected = option
                }
            }
        }
    }
}

struct ProgramChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.liftMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.liftBlue : Color.black.opacity(0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ProgramAddExercisePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var searchText = ""
    @State private var selectedBodyPart = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var previewExercise: TrainingExerciseCatalogItem?

    private let bodyPartFilters = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

    private var equipmentFilters: [String] {
        ["All"] + Array(Set(appState.trainingExerciseLibrary.map(\.equipment))).sorted()
    }

    private var existingExerciseIDs: Set<String> {
        Set(appState.prescriptions(for: session).map(\.exerciseID))
    }

    private var filteredExercises: [ExerciseSearchResult] {
        appState.searchExercises(query: searchText)
            .filter { selectedBodyPart == "All" || matchesBodyPart($0.exercise, filter: selectedBodyPart) }
            .filter { selectedEquipment == "All" || $0.exercise.equipment == selectedEquipment }
            .sorted { lhs, rhs in
                let lhsExists = existingExerciseIDs.contains(lhs.exercise.id)
                let rhsExists = existingExerciseIDs.contains(rhs.exercise.id)
                if lhsExists != rhsExists { return !lhsExists }
                if lhs.score == rhs.score { return lhs.exercise.name < rhs.exercise.name }
                return lhs.score > rhs.score
            }
    }

    private var selectedExercises: [TrainingExerciseCatalogItem] {
        appState.trainingExerciseLibrary
            .filter { selectedExerciseIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        searchField
                        filterBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text("\(filteredExercises.count) exercises")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                                Spacer()
                                if !selectedExerciseIDs.isEmpty {
                                    Text("\(selectedExerciseIDs.count) selected")
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(Color.liftBlue)
                                }
                            }
                            .padding(.horizontal, 4)

                            if filteredExercises.isEmpty {
                                emptyResults
                            } else {
                                ForEach(filteredExercises) { result in
                                    exerciseRow(result)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    bottomActionBar
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink {
                        CreateCustomExerciseView(session: session) {
                            dismiss()
                        }
                        .environmentObject(appState)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .navigationDestination(item: $previewExercise) { exercise in
                AddExerciseToWorkoutView(exercise: exercise, session: session) {
                    dismiss()
                }
                .environmentObject(appState)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
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
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
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

    private func exerciseRow(_ result: ExerciseSearchResult) -> some View {
        let exercise = result.exercise
        let isExisting = existingExerciseIDs.contains(exercise.id)
        let isSelected = selectedExerciseIDs.contains(exercise.id)

        return HStack(spacing: 12) {
            ExerciseCatalogIcon(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                if let reason = result.reasonLabel {
                    Text(reason)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
                Text("\(exercise.bodyPart) • \(exercise.equipment)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Text("\(exercise.defaultSets) sets × \(exercise.defaultReps)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
            }
            Spacer()

            Button {
                previewExercise = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.headline)
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview and configure \(exercise.name)")

            Button {
                toggleSelection(exercise)
            } label: {
                Image(systemName: isExisting || isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isExisting ? Color.liftGreen : isSelected ? Color.liftBlue : Color.liftMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isExisting)
            .accessibilityLabel(isExisting ? "Already in workout" : isSelected ? "Remove \(exercise.name) from selection" : "Select \(exercise.name)")
        }
        .padding(11)
        .background(isSelected ? Color.liftBlue.opacity(0.09) : Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isSelected ? Color.liftBlue.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
        }
        .opacity(isExisting ? 0.62 : 1)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            NavigationLink {
                CreateCustomExerciseView(session: session) {
                    dismiss()
                }
                .environmentObject(appState)
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 50, height: 50)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Create custom exercise")

            Button {
                appState.addExercises(selectedExercises, to: session)
                dismiss()
            } label: {
                HStack {
                    Text(selectedExerciseIDs.isEmpty ? "Select exercises" : "Add \(selectedExerciseIDs.count) to workout")
                        .font(.headline.weight(.black))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(selectedExerciseIDs.isEmpty ? Color.liftMuted : Color.liftBackground)
                .padding(.horizontal, 17)
                .frame(height: 50)
                .background(selectedExerciseIDs.isEmpty ? Color.liftCard : Color.liftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedExerciseIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Color.liftBlue)
            Text("No exercises found")
                .font(.headline)
            Text("Try another search or clear a filter.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func toggleSelection(_ exercise: TrainingExerciseCatalogItem) {
        if selectedExerciseIDs.contains(exercise.id) {
            selectedExerciseIDs.remove(exercise.id)
        } else {
            selectedExerciseIDs.insert(exercise.id)
        }
        Haptics.light()
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
        default: return bodyPart.contains(filter.lowercased())
        }
    }
}
