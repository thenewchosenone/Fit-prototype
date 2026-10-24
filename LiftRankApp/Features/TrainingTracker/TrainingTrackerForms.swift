import SwiftUI

struct CreateWorkoutPlanView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        CreateWorkoutPlanFromHistoryView(
            workouts: appState.completedWorkouts.filter {
                $0.source == .freestyle && !$0.exercisesWithCompletedWorkingSets.isEmpty
            },
            allowsEmptyPlan: true
        )
    }
}

struct CreateWorkoutPlanFromHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @State private var phaseDurationWeeks = 4
    @State private var selectedWorkoutIDs: Set<UUID> = []
    @State private var draftWorkouts: [CompletedWorkout] = []
    @State private var useHistory: Bool
    @State private var isReviewing = false
    @State private var saveError: String?
    private let workouts: [CompletedWorkout]
    private let allowsEmptyPlan: Bool

    init(workouts: [CompletedWorkout], allowsEmptyPlan: Bool = false) {
        self.workouts = workouts.sorted { $0.completedAt > $1.completedAt }
        self.allowsEmptyPlan = allowsEmptyPlan
        _useHistory = State(initialValue: !allowsEmptyPlan || !workouts.isEmpty)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        planSetup
                        if isReviewing {
                            Text("Review your weekly routine")
                                .font(.headline)
                            Text("Rename workouts, choose their days, and adjust the copied working sets. Your recorded workouts stay unchanged.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            ForEach($draftWorkouts) { $workout in
                                reviewCard(workout: $workout)
                            }
                        } else if useHistory {
                            historySelection
                        }
                        if let saveError {
                            Text(saveError)
                                .foregroundStyle(Color.liftRed)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isReviewing ? "Review Plan" : "New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isReviewing ? "Back" : "Cancel") {
                        if isReviewing { isReviewing = false } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(useHistory && !isReviewing ? "Review" : "Create Plan") {
                        saveError = nil
                        if useHistory && !isReviewing {
                            prepareReview()
                        } else if useHistory {
                            if appState.createWorkoutPlan(fromWorkouts: draftWorkouts, name: planName, preserveOrder: true) {
                                dismiss()
                            } else {
                                saveError = "The plan couldn't be created. Finish any active workout and try again."
                            }
                        } else {
                            appState.createWorkoutPlan(
                                name: planName,
                                phaseName: "Base Phase",
                                phaseDurationWeeks: phaseDurationWeeks
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canContinue || appState.activeWorkout != nil)
                    .accessibilityIdentifier("planFromHistory.continue")
                }
            }
        }
    }

    private var planSetup: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plan name").font(.headline)
                TextField("For example, More Volume", text: $planName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.liftScrim)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("planFromHistory.name")
                if allowsEmptyPlan && !isReviewing {
                    Picker("Start with", selection: $useHistory) {
                        Text("Past workouts").tag(true)
                        Text("Empty plan").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                if !isReviewing {
                    Text(useHistory
                         ? "Choose workouts below, then review their names, schedule, and exercises before creating your plan."
                         : "Start with a four-week phase and one workout day. Add exercises and adjust the plan as you go.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        }
    }

    private var historySelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout history").font(.headline)
                Spacer()
                if !workouts.isEmpty {
                    Button("Latest 3") {
                        selectedWorkoutIDs = Set(workouts.prefix(3).map(\.id))
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            Text("\(selectedWorkoutIDs.count) selected · most recent first")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            if workouts.isEmpty {
                Text("Complete a freestyle workout to build a plan from it, or choose Empty plan.")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
            ForEach(workouts) { workout in
                historyCard(workout)
            }
        }
    }

    private func historyCard(_ workout: CompletedWorkout) -> some View {
        let selected = selectedWorkoutIDs.contains(workout.id)
        let exercises = workout.exercisesWithCompletedWorkingSets.sorted { $0.order < $1.order }
        return LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    if selected {
                        selectedWorkoutIDs.remove(workout.id)
                    } else {
                        selectedWorkoutIDs.insert(workout.id)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(selected ? Color.liftAccentText : Color.liftMuted)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(workout.name.isEmpty ? "Freestyle Workout" : workout.name)
                                .font(.headline)
                                .foregroundStyle(Color.liftText)
                            Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Text("\(MeasurementFormatting.shortDurationText(workout.duration)) · \(exercises.count) \(exercises.count == 1 ? "exercise" : "exercises") · \(workout.completedWorkingSets.count) working sets")
                                .font(.caption)
                            Text(exercises.prefix(3).map(\.exerciseName).joined(separator: " · ") + (exercises.count > 3 ? " · +\(exercises.count - 3) more" : ""))
                                .font(.subheadline)
                                .foregroundStyle(Color.liftText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Color.liftMuted)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("planFromHistory.workout.\(workout.id.uuidString)")
                DisclosureGroup("Preview exercises and logged sets") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(exercises) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.exerciseName).font(.subheadline.weight(.semibold))
                                let kind = ExerciseTrackingKind(exercise.trackingType ?? appState.trainingExerciseLibrary.first(where: { $0.id == exercise.exerciseID })?.trackingType ?? "Weight + Reps")
                                ForEach(workout.completedWorkingSets.filter { $0.prescriptionID == exercise.id }.sorted { $0.setNumber < $1.setNumber }) { set in
                                    Text(MeasurementFormatting.workoutSetText(set: set, trackingKind: kind))
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .font(.subheadline)
            }
        }
    }

    private func reviewCard(workout: Binding<CompletedWorkout>) -> some View {
        let index = draftWorkouts.firstIndex { $0.id == workout.wrappedValue.id } ?? 0
        let exerciseCount = workout.wrappedValue.exercises.count
        return LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Workout \(index + 1)").font(.headline)
                    Spacer()
                    Button {
                        draftWorkouts.swapAt(index, index - 1)
                    } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
                    .disabled(index == 0)
                    .accessibilityLabel("Move workout earlier")
                    Button {
                        draftWorkouts.swapAt(index, index + 1)
                    } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }
                    .disabled(index == draftWorkouts.count - 1)
                    .accessibilityLabel("Move workout later")
                }
                Text("From \(workout.wrappedValue.startedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                TextField("Workout name", text: workout.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Workout \(index + 1) name")
                Picker("Scheduled day", selection: workout.dayLabel) {
                    ForEach(Calendar.current.weekdaySymbols, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                DisclosureGroup("\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises") · edit sets, reps, and rest") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(workout.exercises) { exercise in
                            prescriptionEditor(exercise: exercise)
                        }
                    }
                    .padding(.top, 10)
                }
                .font(.subheadline)
            }
        }
    }

    private func prescriptionEditor(exercise: Binding<WorkoutExerciseSnapshot>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.wrappedValue.exerciseName).font(.subheadline.weight(.semibold))
            Stepper("\(exercise.wrappedValue.targetSets) working \(exercise.wrappedValue.targetSets == 1 ? "set" : "sets")", value: exercise.targetSets, in: 1...100)
            HStack {
                Text("Reps / target")
                Spacer()
                TextField("For example, 8–12", text: exercise.targetReps)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                    .accessibilityLabel("\(exercise.wrappedValue.exerciseName) reps or target")
            }
            HStack {
                Text("Rest (seconds)")
                Spacer()
                TextField("Rest", value: exercise.restSeconds, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .accessibilityLabel("\(exercise.wrappedValue.exerciseName) rest seconds")
            }
        }
    }

    private var canContinue: Bool {
        guard !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard useHistory else { return true }
        guard isReviewing else { return !selectedWorkoutIDs.isEmpty }
        return !draftWorkouts.isEmpty && draftWorkouts.allSatisfy { workout in
            !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !workout.exercises.isEmpty &&
            workout.exercises.allSatisfy {
                $0.targetSets > 0 && $0.restSeconds >= 0 &&
                !$0.targetReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    private func prepareReview() {
        let existing = draftWorkouts.filter { selectedWorkoutIDs.contains($0.id) }
        let existingIDs = Set(existing.map(\.id))
        let added = workouts.reversed().filter {
            selectedWorkoutIDs.contains($0.id) && !existingIDs.contains($0.id)
        }.map { original -> CompletedWorkout in
            var draft = original
            draft.exercises = original.exercisesWithCompletedWorkingSets.sorted { $0.order < $1.order }.map { exercise in
                var copy = exercise
                let sets = original.completedWorkingSets.filter { $0.prescriptionID == exercise.id }
                copy.targetSets = sets.count
                if copy.targetReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    copy.targetReps = Array(Set(sets.compactMap(\.reps))).sorted().map(String.init).joined(separator: ", ")
                }
                return copy
            }
            if !Calendar.current.weekdaySymbols.contains(draft.dayLabel) {
                draft.dayLabel = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: original.completedAt) - 1]
            }
            return draft
        }
        draftWorkouts = existing + added
        for index in draftWorkouts.indices {
            if draftWorkouts[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                draftWorkouts[index].name.lowercased() == "freestyle workout" {
                draftWorkouts[index].name = "Workout \(index + 1)"
            }
        }
        isReviewing = true
    }
}

struct BodyweightEntryEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BodyweightEntry
    @State private var isSaving = false
    @State private var saveError: String?
    let onSave: (BodyweightEntry) async throws -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) async throws -> Void) {
        _draft = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 16) {
                    LiftSheetHeader(
                        title: "Week \(draft.week)",
                        subtitle: draft.targetDate.formatted(date: .long, time: .omitted)
                    )

                    OptionalNumericInputField(
                        title: "Actual bodyweight (required)",
                        value: displayedBodyweight,
                        unit: appState.currentProfile.preferredUnit.shortLabel,
                        placeholder: "Enter weight"
                    )
                    Text(bodyweightRangeText)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(Color.liftRed)
                            .accessibilityIdentifier("bodyweight.saveError")
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                        TextField("Optional notes", text: $draft.notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.liftField)
                            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
                    }

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Bodyweight Entry")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task {
                            guard !isSaving else { return }
                            isSaving = true
                            saveError = nil
                            defer { isSaving = false }
                            do {
                                try await onSave(draft)
                                dismiss()
                            } catch {
                                saveError = (error as? LocalizedError)?.errorDescription
                                    ?? "Bodyweight couldn't be saved. Check your connection and try again."
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftAccentText)
                    .disabled((draft.actual ?? 0) < 40 || (draft.actual ?? 0) > 1500 || isSaving)
                    .accessibilityIdentifier("bodyweight.save")
                }
            }
        }
    }

    private var bodyweightRangeText: String {
        let unit = appState.currentProfile.preferredUnit
        guard unit == .kilograms else { return "Enter between 40 and 1500 lb." }
        let minimum = ceil(MeasurementFormatting.convert(40, from: .pounds, to: unit) * 100) / 100
        let maximum = floor(MeasurementFormatting.convert(1500, from: .pounds, to: unit) * 100) / 100
        return "Enter between \(MeasurementFormatting.localizedDecimalText(minimum, maximumFractionDigits: 2)) and \(MeasurementFormatting.localizedDecimalText(maximum, maximumFractionDigits: 2)) kg (40–1500 lb)."
    }

    private var displayedBodyweight: Binding<Double?> {
        Binding(
            get: {
                draft.actual.map {
                    MeasurementFormatting.convert(
                        $0,
                        from: .pounds,
                        to: appState.currentProfile.preferredUnit
                    )
                }
            },
            set: { newValue in
                draft.actual = newValue.map {
                    MeasurementFormatting.convert(
                        $0,
                        from: appState.currentProfile.preferredUnit,
                        to: .pounds
                    )
                }
            }
        )
    }
}
