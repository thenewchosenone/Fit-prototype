import SwiftUI

struct CreateWorkoutPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @FocusState private var isNameFocused: Bool
    @State private var usesHistory = false
    @State private var scheduleMode: WorkoutScheduleMode = .flexible
    @State private var durationWeeks = 12
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var assignments: [WorkoutPlanSourceAssignment] = []
    @State private var showingReview = false
    @State private var showingDiscardConfirmation = false
    @State private var showingCreationError = false

    private var hasDraftChanges: Bool {
        !planName.isEmpty || usesHistory || scheduleMode != .flexible || !assignments.isEmpty || durationWeeks != 12 || !Calendar.current.isDateInToday(startDate)
    }

    private var recentWorkouts: [CompletedWorkout] {
        appState.completedWorkouts
            .filter { !$0.exercises.isEmpty }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private var conflicts: [Int] {
        Dictionary(grouping: assignments, by: \.weekday)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
    }

    private var canReview: Bool {
        appState.activeWorkout == nil && !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !assignments.isEmpty && conflicts.isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                                .frame(width: 52, height: 52)
                                .background(Color.liftAccentText.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Make it your plan")
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.liftText)
                                Text("A name, a starting point, and your next week of training.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }

                        planNameCard

                        LiftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Schedule", selection: $scheduleMode) {
                                    ForEach(WorkoutScheduleMode.allCases) { Text($0.rawValue).tag($0) }
                                }
                                Text(scheduleMode.explanation)
                                    .font(.subheadline).foregroundStyle(Color.liftMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("How do you want to start?")
                                .font(LiftTypography.cardTitle)
                                .foregroundStyle(Color.liftText)
                            startingOption(
                                title: "Start fresh",
                                subtitle: "Add your own workout days and exercises.",
                                symbol: "plus.square",
                                fromHistory: false
                            )
                            startingOption(
                                title: "Use past workouts",
                                subtitle: "Turn saved sessions into a weekly plan.",
                                symbol: "clock.arrow.circlepath",
                                fromHistory: true
                            )
                        }

                        if usesHistory {
                            historySchedule
                        } else if scheduleMode == .weekdays {
                            LiftCard {
                                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 9) {
                        PrimaryButton(title: usesHistory ? "Review plan" : "Create & activate", symbolName: usesHistory ? "arrow.right" : "plus") {
                            isNameFocused = false
                            if usesHistory {
                                showingReview = true
                            } else if appState.createWorkoutPlan(name: planName, startDate: startDate, schedule: scheduleMode) {
                                dismiss()
                            } else {
                                showingCreationError = true
                            }
                        }
                        .disabled(usesHistory ? !canReview : planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.activeWorkout != nil)
                        Text(usesHistory ? "Review your schedule before activating." : "This becomes your active plan. Saved workouts stay unchanged.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("New plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasDraftChanges { showingDiscardConfirmation = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(hasDraftChanges)
            .alert("Discard this plan draft?", isPresented: $showingDiscardConfirmation) {
                Button("Discard draft", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .sheet(isPresented: $showingReview) {
                WorkoutPlanCreationReviewView(
                    planName: planName.trimmingCharacters(in: .whitespacesAndNewlines),
                    assignments: assignments,
                    durationWeeks: durationWeeks,
                    startDate: startDate,
                    schedule: scheduleMode
                ) {
                    let created = appState.createWorkoutPlanFromHistory(
                        name: planName,
                        assignments: assignments.map { ($0.workout, $0.weekday) },
                        durationWeeks: durationWeeks,
                        startDate: startDate,
                        schedule: scheduleMode
                    )
                    if created { dismiss() }
                    return created
                }
                .environmentObject(appState)
            }
            .onChange(of: usesHistory) { _, enabled in
                if enabled && assignments.isEmpty { seedLatestWorkouts() }
            }
            .alert("Plan couldn’t be created", isPresented: $showingCreationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your entries are still here. Finish or discard any active workout, then try again.")
            }
        }
    }

    private var planNameCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("PLAN NAME")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.liftMuted)
                TextField("Plan name", text: $planName, prompt: Text("e.g. My strength block").foregroundStyle(Color.liftMuted))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.liftText)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false }
                    .padding(14)
                    .background(Color.liftBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isNameFocused ? Color.liftAccentText : Color.liftSurfaceBorder, lineWidth: isNameFocused ? 2 : 1)
                    }
                    .accessibilityLabel("Plan name")
                Text("Need a starting point? Try a name:")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(["Strength block", "Full body", "Upper / Lower"], id: \.self) { suggestion in
                            Button {
                                planName = suggestion
                                isNameFocused = false
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                                    .background(Color.liftAccentText.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.liftAccentText)
                            .accessibilityLabel("Use plan name: \(suggestion)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func startingOption(title: String, subtitle: String, symbol: String, fromHistory: Bool) -> some View {
        let isSelected = usesHistory == fromHistory
        return Button {
            isNameFocused = false
            usesHistory = fromHistory
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.liftAccentText : Color.liftMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.liftAccentText.opacity(0.08) : Color.liftCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.liftAccentText : Color.liftSurfaceBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var historySchedule: some View {
        VStack(alignment: .leading, spacing: 14) {
            LiftCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Program schedule")
                        .font(LiftTypography.cardTitle)
                    Stepper("Duration · \(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
                    if scheduleMode == .weekdays {
                        DatePicker("Start date", selection: $startDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    }
                    Text(scheduleMode == .weekdays ? "Each week repeats this schedule. Unassigned weekdays remain rest days." : "Each training week is a group of workouts. Take as many days as you need; there are no calendar deadlines.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }

            LiftCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(scheduleMode == .weekdays ? "Weekly schedule" : "Workouts in each training week")
                            .font(LiftTypography.cardTitle)
                        Spacer()
                        Text("\(assignments.count) workouts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    ForEach($assignments) { $assignment in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(assignment.workout.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(LiftTimeFormatter.shortDateNoTime(assignment.workout.completedAt)) · \(assignment.workout.exercises.reduce(0) { $0 + ProgramStore.importedSetCount(for: $1, in: assignment.workout) }) planned sets")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer(minLength: 4)
                                Menu {
                                    Button(scheduleMode == .weekdays ? "Duplicate to another day" : "Include another session", systemImage: "plus") {
                                        duplicate(assignment)
                                    }
                                    .disabled(nextAvailableWeekday == nil)
                                    Button("Remove workout", systemImage: "trash", role: .destructive) {
                                        assignments.removeAll { $0.id == assignment.id }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .accessibilityLabel("Options for \(assignment.workout.name)")
                            }
                            if scheduleMode == .weekdays {
                                Picker("Training day", selection: $assignment.weekday) {
                                    ForEach(1...7, id: \.self) { weekday in
                                        Text(Calendar.current.weekdayName(for: weekday)).tag(weekday)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityLabel("Training day for \(assignment.workout.name)")
                            }
                        }
                        .padding(.vertical, 6)
                        if assignment.id != assignments.last?.id {
                            Divider().overlay(Color.liftOverlay)
                        }
                    }

                    Menu {
                        ForEach(recentWorkouts) { workout in
                            Button("\(workout.name) · \(LiftTimeFormatter.shortDateNoTime(workout.completedAt)) · \(workout.completedWorkingSets.count) sets") {
                                guard let weekday = nextAvailableWeekday else { return }
                                assignments.append(WorkoutPlanSourceAssignment(workout: workout, weekday: weekday))
                            }
                            .disabled(nextAvailableWeekday == nil)
                        }
                    } label: {
                        Label("Add workout from history", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftSecondaryButtonStyle())

                    if !conflicts.isEmpty {
                        Label("Schedule conflict: \(conflicts.map { Calendar.current.weekdayName(for: $0) }.joined(separator: ", ")) has more than one workout.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.liftGold)
                    }
                    if assignments.isEmpty {
                        Text(scheduleMode == .weekdays ? "Add at least one saved workout. You can repeat a workout on another weekday from its options menu." : "Add at least one saved workout. You can include another copy from its options menu.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
            }
        }
    }

    private var nextAvailableWeekday: Int? {
        let occupied = Set(assignments.map(\.weekday))
        return ([2, 3, 4, 5, 6, 7, 1]).first { !occupied.contains($0) }
    }

    private func duplicate(_ assignment: WorkoutPlanSourceAssignment) {
        guard let weekday = nextAvailableWeekday else { return }
        assignments.append(WorkoutPlanSourceAssignment(workout: assignment.workout, weekday: weekday))
    }

    private func seedLatestWorkouts() {
        assignments = Array(recentWorkouts.prefix(3)).enumerated().map { index, workout in
            WorkoutPlanSourceAssignment(workout: workout, weekday: index + 2)
        }
    }
}

struct ImportWorkoutPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var shareText = ""
    @State private var confirmingDiscard = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste a shared Lift Rivals program. It will be saved as an inactive, editable copy in My Plans.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                    TextEditor(text: $shareText)
                        .font(.system(.caption, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Import editable copy") {
                        if appState.importWorkoutPlanCopy(from: shareText) {
                            alertMessage = "The program copy is saved in My Plans. Review it before activating."
                        } else {
                            alertMessage = "This shared program could not be imported. Check that the full text was copied."
                        }
                        showingAlert = true
                    }
                    .buttonStyle(LiftPrimaryButtonStyle())
                    .disabled(shareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.activeWorkout != nil)
                }
                .padding(16)
            }
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if !shareText.isEmpty { confirmingDiscard = true } else { dismiss() } }
                }
            }
            .alert("Program import", isPresented: $showingAlert) {
                Button("Done") {
                    if alertMessage.hasPrefix("The program copy") { dismiss() }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .interactiveDismissDisabled(!shareText.isEmpty)
        .alert("Discard changes?", isPresented: $confirmingDiscard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }
}

private struct WorkoutPlanSourceAssignment: Identifiable {
    let id = UUID()
    let workout: CompletedWorkout
    var weekday: Int
}

private struct WorkoutPlanCreationReviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let planName: String
    let assignments: [WorkoutPlanSourceAssignment]
    let durationWeeks: Int
    let startDate: Date
    let schedule: WorkoutScheduleMode
    let onCreate: () -> Bool
    @State private var isCreating = false
    @State private var showingCreationError = false

    private var totalVolume: Double {
        assignments.reduce(0) { total, assignment in
            total + MeasurementFormatting.convert(
                assignment.workout.totalVolume(in: assignment.workout.unit, catalog: appState.trainingExerciseLibrary),
                from: assignment.workout.unit,
                to: appState.currentProfile.preferredUnit
            )
        }
    }

    private var totalWorkingSets: Int {
        assignments.reduce(0) { total, assignment in
            total + assignment.workout.exercises.reduce(0) { $0 + ProgramStore.importedSetCount(for: $1, in: assignment.workout) }
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(planName).font(.title2.bold())
                                Text(schedule == .weekdays ? "Starts \(LiftTimeFormatter.shortDateNoTime(startDate)) · \(durationWeeks) weeks" : "\(schedule.rawValue) · \(durationWeeks) training weeks")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                Text("\(assignments.count) workouts/week · \(durationWeeks * assignments.count) total sessions · \(totalWorkingSets) working sets/week")
                                    .font(.subheadline.weight(.semibold))
                                if schedule == .weekdays {
                                    Text("Week 1 calendar preview")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftAccentText)
                                    ForEach(assignments.sorted { $0.weekday < $1.weekday }) { assignment in
                                        Text("\(firstWeekDate(for: assignment.weekday)) · \(assignment.workout.name)")
                                            .font(.caption)
                                    }
                                    if !restDayNames.isEmpty {
                                        Text("Rest: \(restDayNames.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                } else {
                                    Text(schedule.explanation)
                                        .font(.subheadline).foregroundStyle(Color.liftMuted)
                                    Text("Training weeks group your workouts; finish them at your own pace.")
                                        .font(.caption).foregroundStyle(Color.liftMuted)
                                }
                                Text("Estimated session length: \(averageSessionLength)")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Text("Weekly recorded volume: \(MeasurementFormatting.formatRecordedVolume(totalVolume, recordedUnit: appState.currentProfile.preferredUnit, preferredUnit: appState.currentProfile.preferredUnit))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        LiftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(schedule == .weekdays ? "Training days" : "Workouts")
                                    .font(LiftTypography.cardTitle)
                                ForEach(assignments.sorted { $0.weekday < $1.weekday }) { assignment in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(schedule == .weekdays ? Calendar.current.weekdayName(for: assignment.weekday) + " · " : "")\(assignment.workout.name) · \(assignment.workout.exercises.reduce(0) { $0 + ProgramStore.importedSetCount(for: $1, in: assignment.workout) }) working sets")
                                            .font(.subheadline.weight(.semibold))
                                        ForEach(assignment.workout.exercises.sorted { $0.order < $1.order }) { exercise in
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(exercise.exerciseName) · \(ProgramStore.importedSetCount(for: exercise, in: assignment.workout)) × \(exercise.targetReps)")
                                                    .font(.caption)
                                                if let kilograms = ProgramStore.importedLoadKilograms(for: exercise, in: assignment.workout) {
                                                    Text("Suggested load \(MeasurementFormatting.formatDisplayedWeight(kilograms, unit: appState.currentProfile.preferredUnit)) · from saved workout \(assignment.workout.completedAt.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.caption2)
                                                        .foregroundStyle(Color.liftMuted)
                                                } else {
                                                    Text("Reps from the saved workout · no weighted load recorded")
                                                        .font(.caption2)
                                                        .foregroundStyle(Color.liftMuted)
                                                }
                                            }
                                            .padding(.leading, 10)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        LiftCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Repeat as written", systemImage: "repeat")
                                    .font(LiftTypography.cardTitle)
                                Text("Completed working-set counts repeat each week; an exercise with no completed sets keeps its saved target. Loads do not increase automatically.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Text("Creating this plan activates it and leaves completed workout history intact.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { dismiss() }.labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & activate") {
                        guard !isCreating else { return }
                        isCreating = true
                        if !onCreate() {
                            isCreating = false
                            showingCreationError = true
                        }
                    }
                        .fontWeight(.semibold)
                        .disabled(isCreating || appState.activeWorkout != nil)
                }
            }
            .alert("Plan couldn’t be created", isPresented: $showingCreationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your schedule is still here. Finish or discard any active workout, then try again.")
            }
        }
    }

    private var averageSessionLength: String {
        let seconds = assignments.map { $0.workout.duration }.reduce(0, +) / Double(max(assignments.count, 1))
        return MeasurementFormatting.shortDurationText(seconds)
    }

    private var restDayNames: [String] {
        let scheduled = Set(assignments.map(\.weekday))
        return (1...7).filter { !scheduled.contains($0) }.map { Calendar.current.weekdayName(for: $0) }
    }

    private func firstWeekDate(for weekday: Int) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let startWeekday = calendar.component(.weekday, from: start)
        let offset = (weekday - startWeekday + 7) % 7
        let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

struct BodyweightEntryEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BodyweightEntry
    @State private var showingDeleteConfirmation = false
    private let original: BodyweightEntry
    @State private var confirmingDiscard = false
    private var hasDraftChanges: Bool { draft != original }
    let onSave: (BodyweightEntry) -> Void
    let onDelete: (BodyweightEntry) -> Void

    init(entry: BodyweightEntry, onSave: @escaping (BodyweightEntry) -> Void, onDelete: @escaping (BodyweightEntry) -> Void) {
        original = entry
        _draft = State(initialValue: entry)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Measurement date", selection: $draft.targetDate, in: ...Date.now, displayedComponents: .date)
                        .tint(Color.liftAccentText)
                    if !appState.bodyweightEntries.contains(where: { $0.id == draft.id }), draft.actual != nil {
                        Text("From profile · confirm your measurement")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    OptionalNumericInputField(
                        title: "Bodyweight (required)",
                        value: displayedBodyweight,
                        unit: appState.currentProfile.preferredUnit.shortLabel,
                        placeholder: "Enter weight"
                    )

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
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(appState.bodyweightEntries.contains(where: { $0.id == draft.id }) ? "Edit bodyweight" : "Log bodyweight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasDraftChanges { confirmingDiscard = true } else { dismiss() }
                    }
                }
                if appState.bodyweightEntries.contains(where: { $0.id == draft.id }) {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Entry", role: .destructive) { showingDeleteConfirmation = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.liftAccentText)
                    .disabled((draft.actual ?? 0) <= 0)
                }
            }
            .confirmationDialog("Delete this bodyweight entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    onDelete(draft)
                    dismiss()
                }
            } message: {
                Text("This removes the measurement from your progress history.")
            }
        }
        .interactiveDismissDisabled(hasDraftChanges)
        .alert("Discard changes?", isPresented: $confirmingDiscard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
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
