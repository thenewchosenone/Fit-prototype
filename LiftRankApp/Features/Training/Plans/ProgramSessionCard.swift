import SwiftUI

struct ProgramSessionCard: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var appState: AppState
    @State private var selectedWorkout: CompletedWorkout?
    @State private var editingPrescription: WorkoutExercisePrescription?
    @State private var focusedSetID: UUID?
    @State private var showsExercises = false
    @State private var showingScheduleError = false
    @State private var showingActiveWorkoutNotice = false
    @Binding var selectedWeekID: UUID?
    @State private var showingSchedulePicker = false
    @State private var showingDateError = false
    @State private var duplicatesSchedule = true
    @State private var scheduleDate = Date.now
    let session: WorkoutSession
    let prescriptions: [WorkoutExercisePrescription]
    let completedPrescriptionCount: Int
    let catalogByID: [String: TrainingExerciseCatalogItem]
    let onStart: () -> Void
    let onResume: () -> Void
    let onAddExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.selectedPlanIsFlexible ? session.name : "\(session.day) · \(session.name)")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        if isActiveSession, let workout = appState.activeWorkout {
                            Text("\(hasSavedWorkout ? "Repeat" : "Workout") · \((workout.historyDate ?? workout.startedAt).formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(Color.liftAccentText)
                        } else if let date = appState.scheduledDate(for: session) {
                            Text("Planned for \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Menu {
                        if appState.selectedPlanIsFlexible {
                            Button("Duplicate workout", systemImage: "doc.on.doc") {
                                if let slot = availableDays.first {
                                    showingScheduleError = !appState.duplicateWorkoutSession(session, day: slot)
                                }
                            }
                            .disabled(appState.activeWorkout != nil || availableDays.isEmpty)
                        } else if appState.selectedPlanQueueEnabled {
                            Menu("Copy to unused weekday", systemImage: "doc.on.doc") {
                                ForEach(availableDays, id: \.self) { day in
                                    Button(day) { showingScheduleError = !appState.duplicateWorkoutSession(session, day: day) }
                                }
                            }
                            .disabled(appState.activeWorkout != nil || availableDays.isEmpty)
                            Menu("Move to unused weekday", systemImage: "calendar") {
                                ForEach(availableDays, id: \.self) { day in
                                    Button(day) { showingScheduleError = !appState.rescheduleWorkoutSession(session, day: day) }
                                }
                            }
                            .disabled(!appState.canEditWorkoutSession(session) || availableDays.isEmpty)
                        } else {
                            Button("Copy planned workout…", systemImage: "doc.on.doc") { openSchedulePicker(duplicate: true) }
                                .disabled(appState.activeWorkout != nil)
                            Button("Move planned workout…", systemImage: "calendar") { openSchedulePicker(duplicate: false) }
                                .disabled(!appState.canEditWorkoutSession(session))
                        }
                        if hasSavedWorkout {
                            Button("Add exercise to plan", action: addExercise)
                            Divider()
                        }
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete Workout Day")
                        }
                        .disabled(appState.activeWorkout != nil)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(appState.selectedPlanIsFlexible ? "Options for \(session.name)" : "Options for \(session.name), \(session.day)")
                }

                if hasSavedWorkout && !isActiveSession {
                    if let workout = savedAttempts.first {
                        Button { selectedWorkout = workout } label: {
                            Label("Review latest · \(workout.completedAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if savedAttempts.count > 1 {
                        Menu("All \(savedAttempts.count) saved attempts") {
                            ForEach(savedAttempts) { workout in
                                let count = workout.completedWorkingSets.count
                                Button("\(workout.completedAt.formatted(date: .abbreviated, time: .shortened)) · \(count) \(count == 1 ? "set" : "sets")") {
                                    selectedWorkout = workout
                                }
                            }
                        }
                    }
                    Button("Repeat today", systemImage: "arrow.clockwise", action: onStart)
                        .disabled(appState.activeWorkout != nil || prescriptions.isEmpty)
                    Text("Starts a new attempt using this plan’s exercises. Saved attempts stay unchanged.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    (dynamicTypeSize.isAccessibilitySize
                     ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                     : AnyLayout(HStackLayout(spacing: 10))) {
                        Button(action: addExercise) {
                            Label("Add exercise", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftAccentText)
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                        Button(action: isActiveSession ? onResume : onStart) {
                            Label(isActiveSession ? "Resume" : "Start", systemImage: "play.fill")
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(LiftCompactProminentButtonStyle())
                        .accessibilityLabel(isActiveSession ? "Resume workout" : "Start workout")
                        .disabled(!isActiveSession && prescriptions.isEmpty)
                    }
                }

                if prescriptions.isEmpty {
                    Text("Add exercises to make this workout ready to start.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { showsExercises.toggle() }
                    } label: {
                        HStack {
                            Text("Workout: \(prescriptions.count) exercises · \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftText)
                            Spacer()
                            Text(showsExercises ? "Hide" : "Show")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftAccentText)
                            Image(systemName: showsExercises ? "chevron.up" : "chevron.down")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftMuted)
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
                                    if let rest = prescription.supersetRestSeconds {
                                        Label("Superset · \(rest) sec between rounds", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                            .font(.caption2)
                                            .foregroundStyle(Color.liftAccentText)
                                    }
                                }
                                Spacer()
                                Button {
                                    editingPrescription = prescription
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit \(prescription.exerciseName) prescription")
                                Menu {
                                    if index > 0 {
                                        Menu("Superset with \(prescriptions[index - 1].exerciseName)") {
                                            ForEach([30, 45, 60, 90, 120], id: \.self) { seconds in
                                                Button("Rest \(seconds) seconds between rounds") {
                                                    _ = appState.setWorkoutSuperset(
                                                        sessionID: session.id,
                                                        exerciseIDs: [prescriptions[index - 1].id, prescription.id],
                                                        restSeconds: seconds
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    if prescription.supersetGroup != nil {
                                        Button("Remove superset", role: .destructive) {
                                            appState.removeWorkoutSuperset(sessionID: session.id, exerciseID: prescription.id)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(width: 40, height: 40)
                                }
                                .disabled(!appState.canEditWorkoutSession(session))
                                .accessibilityLabel("Superset options for \(prescription.exerciseName)")
                                .accessibilityHint("Available for unstarted workouts")
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
        .sheet(isPresented: $showingSchedulePicker) {
            NavigationStack {
                Form {
                    if let range = appState.workoutScheduleDateRange(for: session) {
                        Section(session.name) {
                            DatePicker("Workout date", selection: $scheduleDate, in: range, displayedComponents: .date)
                            Text(scheduleDate.formatted(date: .complete, time: .omitted))
                            Text(duplicatesSchedule
                                 ? "Copies the planned exercises to this date. Saved attempts stay unchanged."
                                 : "Changes this unstarted workout’s scheduled date.")
                            Text("Choose a date in this plan or the following week. A new week is added if needed. Dates with another planned workout are unavailable.")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }
                    }
                }
                .navigationTitle(duplicatesSchedule ? "Copy workout" : "Move workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingSchedulePicker = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(duplicatesSchedule ? "Copy" : "Move") {
                            if appState.scheduleWorkoutSession(session, on: scheduleDate, duplicate: duplicatesSchedule) {
                                if let start = appState.workoutScheduleDateRange(for: session)?.lowerBound {
                                    let days = Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: scheduleDate)).day ?? 0
                                    selectedWeekID = appState.selectedPlanWeeks.first { $0.weekNumber == days / 7 + 1 }?.id
                                }
                                showingSchedulePicker = false
                            } else { showingDateError = true }
                        }
                    }
                }
                .alert("Date unavailable", isPresented: $showingDateError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Choose a date without another planned workout. Finish any active workout before changing the schedule.")
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            CompletedWorkoutDetailView(workout: workout, focusedSetID: $focusedSetID)
                .environmentObject(appState)
        }
        .sheet(item: $editingPrescription) { prescription in
            WorkoutPrescriptionEditorView(
                prescription: prescription,
                preferredUnit: appState.currentProfile.preferredUnit,
                availableExercises: Array(catalogByID.values)
            ) { updated, scope in
                appState.updateWorkoutPrescription(updated, scope: scope)
            }
        }
        .alert("Workout in progress", isPresented: $showingActiveWorkoutNotice) {
            Button("Resume workout") { appState.router.cover = .activeWorkout }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Finish or discard the active workout before editing this plan. To add an exercise to your current workout, resume it and use Add exercise there.")
        }
        .alert("Schedule couldn’t change", isPresented: $showingScheduleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.selectedPlanIsFlexible ? "This workout could not be duplicated. Check that this training week has room for another workout." : "Choose an unused day in this week. Moving a workout is available only before it has been started.")
        }
    }

    private func addExercise() {
        if appState.activeWorkout != nil { showingActiveWorkoutNotice = true }
        else { onAddExercise() }
    }

    private var availableDays: [String] {
        let occupied = Set(appState.workoutSessions.filter { $0.weekID == session.weekID }.map { $0.day.lowercased() })
        return [2, 3, 4, 5, 6, 7, 1].map { Calendar.current.weekdayName(for: $0) }
            .filter { !occupied.contains($0.lowercased()) }
    }

    private var statusText: String {
        if isActiveSession {
            let progress = appState.activeWorkoutDisplayState
            return "In progress · \(progress.completedExercises)/\(progress.exercises.count) exercises · \(progress.completedWorkingSets)/\(progress.plannedWorkingSets) sets"
        }
        if let workout = savedAttempts.first {
            let loggedExercises = Set(workout.completedWorkingSets.map(\.prescriptionID)).count
            let sets = workout.completedWorkingSets.count
            return "Latest attempt · \(loggedExercises)/\(workout.exercises.count) exercises logged · \(sets) \(sets == 1 ? "set" : "sets")"
        }
        if let outcome = session.outcome { return outcome == .rest ? "Marked as rest" : "Skipped" }
        if prescriptions.isEmpty { return "Ready to build" }
        if appState.isFullyCompletedPlanSession(session) { return "All planned sets completed" }
        return "\(completedPrescriptionCount) of \(prescriptions.count) exercises completed"
    }

    private var savedAttempts: [CompletedWorkout] {
        appState.completedWorkouts.filter { $0.sourceSessionID == session.id }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private var hasSavedWorkout: Bool { !savedAttempts.isEmpty }

    private func openSchedulePicker(duplicate: Bool) {
        guard let range = appState.workoutScheduleDateRange(for: session) else { showingScheduleError = true; return }
        duplicatesSchedule = duplicate
        scheduleDate = min(max(Calendar.current.startOfDay(for: .now), range.lowerBound), range.upperBound)
        showingSchedulePicker = true
    }

    private var isActiveSession: Bool {
        appState.activeWorkout?.sourceSessionID == session.id
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

private struct WorkoutPrescriptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let prescription: WorkoutExercisePrescription
    let preferredUnit: UnitSystem
    let availableExercises: [TrainingExerciseCatalogItem]
    let onSave: (WorkoutExercisePrescription, WorkoutPrescriptionEditScope) -> Int
    @State private var setsText: String
    @State private var reps: String
    @State private var restText: String
    @State private var rirSelection: Int
    @State private var loadText: String
    @State private var substitutionIDs: [String]
    @State private var scope: WorkoutPrescriptionEditScope = .thisWorkout
    @State private var confirmingDiscard = false
    private var hasDraftChanges: Bool {
        let originalLoad = prescription.targetLoadKilograms.map {
            MeasurementFormatting.convert($0, from: .kilograms, to: preferredUnit)
                .formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
        } ?? ""
        return setsText != String(prescription.sets) || reps != prescription.reps
            || restText != String(prescription.restSeconds) || rirSelection != (prescription.targetRIR ?? -1)
            || loadText != originalLoad || substitutionIDs != (prescription.substitutionExerciseIDs ?? [])
            || scope != .thisWorkout
    }
    @State private var showingNoChangesMessage = false
    @State private var showingSubstitutionPicker = false

    init(
        prescription: WorkoutExercisePrescription,
        preferredUnit: UnitSystem,
        availableExercises: [TrainingExerciseCatalogItem],
        onSave: @escaping (WorkoutExercisePrescription, WorkoutPrescriptionEditScope) -> Int
    ) {
        self.prescription = prescription
        self.preferredUnit = preferredUnit
        self.availableExercises = availableExercises
        self.onSave = onSave
        _setsText = State(initialValue: String(prescription.sets))
        _reps = State(initialValue: prescription.reps)
        _restText = State(initialValue: String(prescription.restSeconds))
        _rirSelection = State(initialValue: prescription.targetRIR ?? -1)
        _loadText = State(initialValue: prescription.targetLoadKilograms.map { kilograms in
            MeasurementFormatting.convert(kilograms, from: .kilograms, to: preferredUnit).formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
        } ?? "")
        _substitutionIDs = State(initialValue: prescription.substitutionExerciseIDs ?? [])
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section(prescription.exerciseName) {
                        LabeledContent("Working sets") {
                            TextField("Sets", text: $setsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Rep range or target") {
                            TextField("Reps", text: $reps)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Rest seconds") {
                            TextField("Seconds", text: $restText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Target RIR", selection: $rirSelection) {
                            Text("Not set").tag(-1)
                            ForEach(0...5, id: \.self) { value in
                                Text("\(value) reps in reserve").tag(value)
                            }
                        }
                        TextField("Suggested load (\(preferredUnit.shortLabel))", text: $loadText)
                            .keyboardType(.decimalPad)
                        Button("Add equipment substitution") { showingSubstitutionPicker = true }
                            .sheet(isPresented: $showingSubstitutionPicker) {
                                ProgressExercisePickerSheet(
                                    options: availableExercises.filter { $0.id != prescription.exerciseID && !substitutionIDs.contains($0.id) },
                                    selectedID: nil,
                                    title: "Choose substitution",
                                    preferredIDs: Set(availableExercises.filter { $0.bodyPart == prescription.bodyPart && $0.equipment != prescription.equipment }.map(\.id))
                                ) { substitutionIDs.append($0) }
                            }
                        ForEach(substitutionIDs, id: \.self) { exerciseID in
                            HStack {
                                Text(availableExercises.first(where: { $0.id == exerciseID })?.name ?? exerciseID)
                                Spacer()
                                Button("Remove", systemImage: "minus.circle") {
                                    substitutionIDs.removeAll { $0 == exerciseID }
                                }
                                .labelStyle(.iconOnly)
                                .accessibilityLabel("Remove substitution")
                            }
                        }
                    }
                    Section("Apply edit to") {
                        Picker("Scope", selection: $scope) {
                            ForEach(WorkoutPrescriptionEditScope.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        Text("Only unstarted workouts change. Workouts with logged sets and completed history stay as saved.")
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if hasDraftChanges { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .alert("No unstarted workouts changed", isPresented: $showingNoChangesMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a scope that includes an unstarted workout.")
            }
        }
        .interactiveDismissDisabled(hasDraftChanges)
        .alert("Discard changes?", isPresented: $confirmingDiscard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }

    private var isValid: Bool {
        guard let sets = Int(setsText), (1...30).contains(sets),
              let rest = Int(restText), (0...3600).contains(rest),
              !reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return loadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(loadText).map { $0.isFinite && $0 >= 0 } ?? false)
    }

    private func save() {
        guard isValid, let sets = Int(setsText), let rest = Int(restText) else { return }
        var edited = prescription
        edited.sets = sets
        edited.reps = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.restSeconds = rest
        edited.targetRIR = rirSelection < 0 ? nil : rirSelection
        edited.substitutionExerciseIDs = substitutionIDs.isEmpty ? nil : substitutionIDs
        edited.targetLoadKilograms = Double(loadText).map {
            MeasurementFormatting.convert($0, from: preferredUnit, to: .kilograms)
        }
        if onSave(edited, scope) > 0 {
            dismiss()
        } else {
            showingNoChangesMessage = true
        }
    }
}
