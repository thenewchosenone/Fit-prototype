import SwiftUI

struct WorkoutProgramTemplateDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let sourceTemplate: WorkoutProgramTemplate
    let editingPlanID: UUID?
    @State private var trainingDays: Int
    @State private var method: WorkoutProgressionMethod
    @State private var startDate = Date.now
    @State private var scheduledWeekdays: [Int]
    @State private var trainingMaxInputs: [String: String] = [:]
    @State private var startingNewCycle = false
    @State private var didStart = false
    @State private var editingExisting = false
    @State private var expandedSessionIndices: Set<Int> = [0]

    init(template: WorkoutProgramTemplate, editingPlanID: UUID? = nil) {
        self.sourceTemplate = template
        self.editingPlanID = editingPlanID
        _editingExisting = State(initialValue: editingPlanID != nil)
        _trainingDays = State(initialValue: template.daysPerWeek)
        _method = State(initialValue: template.defaultProgression)
        _scheduledWeekdays = State(initialValue: template.sessions.map(\.dayIndex))
    }

    private var scheduleVariants: [WorkoutProgramTemplate] {
        WorkoutProgramCatalog.scheduleVariants(for: sourceTemplate)
    }

    private var template: WorkoutProgramTemplate {
        scheduleVariants.first { $0.daysPerWeek == trainingDays } ?? sourceTemplate
    }

    private var progressionMethods: [WorkoutProgressionMethod] {
        template.availableProgressionMethods
    }

    private var canStart: Bool {
        appState.activeWorkout == nil && !didStart && Set(scheduledWeekdays).count == scheduledWeekdays.count &&
            (method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy { parsedTrainingMaxKilograms[$0, default: 0] > 0 })
    }

    private var parsedTrainingMaxKilograms: [String: Double] {
        trainingMaxInputs.reduce(into: [:]) { result, pair in
            guard let value = Double(pair.value), value > 0 else { return }
            result[pair.key] = appState.currentProfile.preferredUnit == .pounds
                ? RankingCalculator.poundsToKilograms(value)
                : value
        }
    }

    private var existingPlan: WorkoutPlan? {
        if let editingPlanID { return appState.workoutPlans.first { $0.id == editingPlanID } }
        return appState.workoutPlans.filter { plan in
            appState.workoutPlanProgressionSettings.contains { settings in
                settings.planID == plan.id && scheduleVariants.contains { $0.id == settings.sourceTemplateID }
            }
        }.max { $0.createdAt < $1.createdAt }
    }

    private func preview(_ base: WorkoutProgramExerciseTemplate, sessionIndex: Int, exerciseIndex: Int) -> WorkoutExercisePrescription? {
        appState.programPreviewPrescription(
            base,
            templateID: template.id, sessionIndex: sessionIndex, exerciseIndex: exerciseIndex,
            method: method, trainingMaxKilograms: parsedTrainingMaxKilograms
        )
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview
                        if let existingPlan, !startingNewCycle, !editingExisting {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("You already have this program").font(.headline)
                                    Text("Resume keeps your schedule and progress.")
                                        .font(.caption).foregroundStyle(Color.liftMuted)
                                    DisclosureGroup("Other setup options") {
                                    Button("Edit existing setup") {
                                        guard let settings = appState.workoutPlanProgressionSettings.first(where: { $0.planID == existingPlan.id }) else { return }
                                        startDate = settings.startedAt
                                        trainingDays = settings.scheduledWeekdays.count
                                        scheduledWeekdays = settings.scheduledWeekdays
                                        method = settings.method
                                        trainingMaxInputs = settings.trainingMaxKilograms.mapValues {
                                            MeasurementFormatting.convert($0, from: .kilograms, to: appState.currentProfile.preferredUnit).formatted(.number.grouping(.never).precision(.fractionLength(1)))
                                        }
                                        editingExisting = true
                                    }
                                    .disabled(appState.activeWorkout != nil)
                                    Button("Set up a new cycle") { startingNewCycle = true }
                                        .disabled(appState.activeWorkout != nil)
                                    }
                                }
                            }
                        } else {
                            setup
                        }
                        if appState.activeWorkout != nil {
                            Text("Finish or discard your active workout before changing programs.")
                                .font(.caption).foregroundStyle(Color.liftGold)
                        }
                        sessionPreview
                        DisclosureGroup("12-week structure") { phaseSummary }
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("training.programPreview.screen")
                .safeAreaInset(edge: .bottom) {
                    Button(editingExisting ? "Save setup changes" : (existingPlan != nil && !startingNewCycle ? "Resume existing program" : "Start new 12-week cycle")) {
                        if editingExisting, let existingPlan {
                            if appState.updateWorkoutProgramSetup(planID: existingPlan.id, startDate: startDate, scheduledWeekdays: scheduledWeekdays, method: method, trainingMaxKilograms: parsedTrainingMaxKilograms) { dismiss() }
                            return
                        }
                        if let existingPlan, !startingNewCycle, !editingExisting {
                            if appState.selectWorkoutPlan(existingPlan.id) { dismiss() }
                            return
                        }
                        guard !didStart else { return }
                        didStart = true
                        if appState.startWorkoutProgram(
                            template: template,
                            startDate: startDate,
                            scheduledWeekdays: scheduledWeekdays,
                            method: method,
                            trainingMaxKilograms: parsedTrainingMaxKilograms
                        ) != nil {
                            dismiss()
                        } else { didStart = false }
                    }
                    .buttonStyle(LiftPrimaryButtonStyle())
                    .disabled(appState.activeWorkout != nil || didStart || ((existingPlan == nil || startingNewCycle || editingExisting) && !canStart))
                    .accessibilityIdentifier("training.programPreview.start")
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(editingPlanID == nil ? "Program Preview" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if scheduleVariants.count > 1, let existingPlan,
                   let settings = appState.workoutPlanProgressionSettings.first(where: { $0.planID == existingPlan.id }) {
                    trainingDays = settings.scheduledWeekdays.count
                    scheduledWeekdays = settings.scheduledWeekdays
                    method = settings.method
                }
                if let editingPlanID,
                   let settings = appState.workoutPlanProgressionSettings.first(where: { $0.planID == editingPlanID }) {
                    startDate = settings.startedAt
                    trainingDays = settings.scheduledWeekdays.count
                    scheduledWeekdays = settings.scheduledWeekdays
                    method = settings.method
                    trainingMaxInputs = settings.trainingMaxKilograms.mapValues {
                        MeasurementFormatting.convert($0, from: .kilograms, to: appState.currentProfile.preferredUnit).formatted(.number.grouping(.never).precision(.fractionLength(1)))
                    }
                }
                seedTrainingMaxesIfNeeded()
            }
            .onChange(of: method) { _, value in
                if value == .percentage { seedTrainingMaxesIfNeeded() }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(template.name)
                .font(.title2.weight(.bold))
            Text(template.summary)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    metadataChip(template.category.rawValue)
                    metadataChip(template.level.rawValue)
                    metadataChip("\(template.daysPerWeek) days/week")
                }
            } else {
                HStack(spacing: 8) {
                    metadataChip(template.category.rawValue)
                    metadataChip(template.level.rawValue)
                    metadataChip("\(template.daysPerWeek) days/week")
                }
            }
        }
    }

    private var setup: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Program setup").font(.headline)
                if scheduleVariants.count > 1 {
                    if editingExisting {
                        Text("This cycle uses \(trainingDays) training days per week. Start a new cycle to change the number of days; you can reschedule weekdays below.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                    } else {
                        Picker("Days per week", selection: Binding(
                            get: { trainingDays },
                            set: { days in
                                guard let variant = scheduleVariants.first(where: { $0.daysPerWeek == days }) else { return }
                                trainingDays = days
                                scheduledWeekdays = variant.sessions.map(\.dayIndex)
                                expandedSessionIndices = [0]
                            }
                        )) {
                            ForEach(scheduleVariants) { variant in
                                Text("\(variant.daysPerWeek) days").tag(variant.daysPerWeek)
                            }
                        }
                        .accessibilityIdentifier("training.programPreview.daysPerWeek")
                        Text("The split and working sets change to fit your schedule. Preview the training days below before starting.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                    }
                }
                if editingExisting {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cycle start date")
                            DatePicker("Cycle start date", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    } else {
                        DatePicker("Cycle start date", selection: $startDate, displayedComponents: .date)
                    }
                    Text("Schedule changes affect unrecorded sessions. Saved workouts keep their performed dates. Progression changes apply from the current program week onward.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                } else {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start date")
                            DatePicker("Start date", selection: $startDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                                .labelsHidden()
                        }
                    } else {
                        DatePicker("Start date", selection: $startDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    }
                }
                Text("Weeks advance every seven days from this date. Missed workouts stay available. Use the session queue in Plans to train in order instead.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progression").font(LiftTypography.compactEmphasis).foregroundStyle(Color.liftMuted)
                    ForEach(progressionMethods) { option in
                        ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                    }
                    Text(method.guidance)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training days").font(LiftTypography.compactEmphasis).foregroundStyle(Color.liftMuted)
                    ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(session.name)
                                        .font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Picker("Day for \(session.name)", selection: weekdayBinding(index)) {
                                        ForEach(1...7, id: \.self) { weekday in
                                            Text(Calendar.current.weekdayName(for: weekday)).tag(weekday)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            } else {
                                HStack {
                                    Text(session.name).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Picker("Day for \(session.name)", selection: weekdayBinding(index)) {
                                        ForEach(1...7, id: \.self) { weekday in
                                            Text(Calendar.current.weekdayName(for: weekday)).tag(weekday)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                }
                if Set(scheduledWeekdays).count != scheduledWeekdays.count {
                    Text("Choose a different day for each session.").font(.caption).foregroundStyle(Color.liftGold)
                }
                if method == .percentage { trainingMaxFields }
            }
        }
    }

    private var trainingMaxFields: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Training maxes")
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(Color.liftMuted)
            Text("A training max (TM) sets your program’s weights. Suggested values use 90% of your best recorded or estimated one-rep max (1RM). Review them before starting.")
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            ForEach(template.requiredTrainingMaxExerciseIDs, id: \.self) { exerciseID in
                HStack {
                    Text(exerciseName(exerciseID))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    TextField("Required", text: trainingMaxBinding(exerciseID))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 88)
                        .padding(9)
                        .background(Color.liftScrim)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(appState.currentProfile.preferredUnit.shortLabel)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        }
    }

    private var phaseSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(WorkoutProgramCatalog.phaseSummary(for: template), id: \.self) { title in
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var sessionPreview: some View {
        let exerciseCount = template.sessions.reduce(0) { $0 + $1.exercises.count }
        let workingSetCount = template.sessions.enumerated().reduce(0) { total, item in
            total + item.element.exercises.enumerated().reduce(0) { $0 + (preview($1.element, sessionIndex: item.offset, exerciseIndex: $1.offset)?.sets ?? 0) }
        }
        let allExpanded = expandedSessionIndices.count == template.sessions.count
        let previewHeading = VStack(alignment: .leading, spacing: 3) {
            Text("Week 1 preview")
                .font(LiftTypography.sectionTitle)
            Text("Tap a training day to view its exercises")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        let expandButton = Button(allExpanded ? "Collapse" : "Expand all") {
            toggleAllSessions(expand: !allExpanded)
        }
        .font(LiftTypography.compactEmphasis)
        .foregroundStyle(Color.liftAccentText)
        .frame(minHeight: 44)
        .buttonStyle(.plain)

        return VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    previewHeading
                    expandButton
                }
            } else {
                HStack {
                    previewHeading
                    Spacer()
                    expandButton
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    weeklyMetric(value: "\(template.daysPerWeek)", label: "DAYS")
                    weeklyMetric(value: "\(exerciseCount)", label: "EXERCISES")
                    weeklyMetric(value: "\(workingSetCount)", label: "SETS")
                }
            } else {
                HStack(spacing: 8) {
                    weeklyMetric(value: "\(template.daysPerWeek)", label: "DAYS")
                    weeklyMetric(value: "\(exerciseCount)", label: "EXERCISES")
                    weeklyMetric(value: "\(workingSetCount)", label: "SETS")
                }
            }

            ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                weeklySessionCard(session, index: index)
            }
        }
    }

    private func weeklyMetric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.liftText)
            Text(label)
                .font(dynamicTypeSize.isAccessibilitySize ? .caption.weight(.bold) : .system(size: 9, weight: .bold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 0.7)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.liftOverlay.opacity(0.75), lineWidth: 1)
        }
    }

    private func weeklySessionCard(_ session: WorkoutProgramSessionTemplate, index: Int) -> some View {
        let isExpanded = expandedSessionIndices.contains(index)
        let setCount = session.exercises.enumerated().reduce(0) { $0 + (preview($1.element, sessionIndex: index, exerciseIndex: $1.offset)?.sets ?? 0) }
        let weekday = Calendar.current.weekdayName(for: scheduledWeekdays[index])

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleSession(index)
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(weekday)
                                    .font(LiftTypography.rowEmphasis)
                                    .foregroundStyle(Color.liftAccentText)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(LiftTypography.compactEmphasis)
                                    .foregroundStyle(isExpanded ? Color.liftAccentText : Color.liftMuted)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            Text(session.name)
                                .font(LiftTypography.cardTitle)
                                .foregroundStyle(Color.liftText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(session.exercises.count) exercises · \(setCount) working sets")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    } else {
                        HStack(spacing: 12) {
                            VStack(spacing: 1) {
                                Text(String(weekday.prefix(3)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.4)
                            }
                            .foregroundStyle(Color.liftAccentText)
                            .frame(width: 46, height: 42)
                            .background(Color.liftBlue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.name)
                                    .font(LiftTypography.rowEmphasis)
                                    .foregroundStyle(Color.liftText)
                                Text("\(session.exercises.count) exercises · \(setCount) working sets")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }

                            Spacer(minLength: 6)

                            Image(systemName: "chevron.down")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(isExpanded ? Color.liftAccentText : Color.liftMuted)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 100 : 66, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(weekday), \(session.name), \(session.exercises.count) exercises, \(setCount) working sets")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                Divider()
                    .overlay(Color.liftSeparator)
                    .padding(.horizontal, 12)

                VStack(spacing: 0) {
                    ForEach(Array(session.exercises.enumerated()), id: \.offset) { exerciseIndex, prescription in
                        let generated = preview(prescription, sessionIndex: index, exerciseIndex: exerciseIndex)
                        let exercise = templateExercise(for: prescription)
                        let setRepText = "\(generated?.sets ?? prescription.sets) × \(generated?.reps ?? prescription.reps)"
                        let targetText: String? = {
                            if let load = generated?.targetLoadKilograms {
                                return "\(MeasurementFormatting.formatDisplayedWeight(load, unit: appState.currentProfile.preferredUnit)) · \(Int(((generated?.trainingMaxPercentage ?? 0) * 100).rounded()))% TM"
                            } else if let percentage = generated?.trainingMaxPercentage {
                                return "\(Int((percentage * 100).rounded()))% TM"
                            } else if !ExerciseTrackingKind(exercise.trackingType).usesDuration, let rir = generated?.targetRIR {
                                return "\(rir) reps in reserve"
                            }
                            return nil
                        }()
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(exercise.name)
                                        .font(LiftTypography.cardTitle)
                                        .foregroundStyle(Color.liftText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(exercise.resolvedMuscleProfile.primaryDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.liftMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(setRepText)
                                            .font(.headline.weight(.bold).monospacedDigit())
                                            .foregroundStyle(Color.liftAccentText)
                                        Spacer(minLength: 8)
                                        if let targetText {
                                            Text(targetText)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.trailing)
                                        }
                                    }
                                }
                            } else {
                                HStack(spacing: 12) {
                                    ExerciseCatalogIcon(exercise: exercise)
                                        .frame(width: 40, height: 40)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(exercise.name)
                                            .font(LiftTypography.compactEmphasis)
                                            .foregroundStyle(Color.liftText)
                                            .lineLimit(1)
                                        Text(exercise.resolvedMuscleProfile.primaryDescription)
                                            .font(.caption2)
                                            .foregroundStyle(Color.liftMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 6)

                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(setRepText)
                                            .font(.caption2.weight(.bold).monospacedDigit())
                                            .foregroundStyle(Color.liftAccentText)
                                            .padding(.horizontal, 9)
                                            .frame(minHeight: 28)
                                            .background(Color.liftBlue.opacity(0.10))
                                            .clipShape(Capsule())
                                        if let targetText {
                                            Text(targetText).font(.caption2)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 7)
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 120 : 68, alignment: .leading)

                        if exerciseIndex < session.exercises.count - 1 {
                            Divider()
                                .overlay(Color.liftSeparator)
                                .padding(.leading, 64)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isExpanded ? Color.liftBlue.opacity(0.28) : Color.liftOverlay, lineWidth: 1)
        }
    }

    private func toggleSession(_ index: Int) {
        let update = {
            if expandedSessionIndices.contains(index) {
                expandedSessionIndices.remove(index)
            } else {
                expandedSessionIndices.insert(index)
            }
        }
        if reduceMotion { update() } else { withAnimation(.snappy, update) }
    }

    private func toggleAllSessions(expand: Bool) {
        let update = {
            expandedSessionIndices = expand ? Set(template.sessions.indices) : []
        }
        if reduceMotion { update() } else { withAnimation(.snappy, update) }
    }

    private func templateExercise(for prescription: WorkoutProgramExerciseTemplate) -> TrainingExerciseCatalogItem {
        appState.trainingExerciseLibrary.first { $0.id == prescription.exerciseID } ?? TrainingExerciseCatalogItem(
            id: prescription.exerciseID,
            name: prescription.exerciseID,
            bodyPart: "Full body",
            workoutCategory: "Strength",
            defaultSets: prescription.sets,
            defaultReps: prescription.reps,
            symbolName: "figure.strengthtraining.functional",
            equipment: "Equipment",
            muscleProfile: ExerciseMuscleProfileResolver.profile(
                name: prescription.exerciseID,
                bodyPart: "Full body"
            )
        )
    }

    private func seedTrainingMaxesIfNeeded() {
        let suggestions = appState.suggestedTrainingMaxKilograms(for: template)
        for exerciseID in template.requiredTrainingMaxExerciseIDs {
            guard trainingMaxInputs[exerciseID, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let kilograms = suggestions[exerciseID] else { continue }
            let displayed = appState.currentProfile.preferredUnit == .pounds
                ? RankingCalculator.kilogramsToPounds(kilograms)
                : kilograms
            trainingMaxInputs[exerciseID] = String(format: "%.1f", displayed)
        }
    }

    private func trainingMaxBinding(_ exerciseID: String) -> Binding<String> {
        Binding(get: { trainingMaxInputs[exerciseID, default: ""] }, set: { trainingMaxInputs[exerciseID] = $0 })
    }

    private func weekdayBinding(_ index: Int) -> Binding<Int> {
        Binding(get: { scheduledWeekdays[index] }, set: { scheduledWeekdays[index] = $0 })
    }

    private func exerciseName(_ id: String) -> String {
        appState.trainingExerciseLibrary.first { $0.id == id }?.name ?? id
    }

    private func metadataChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftAccentText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.liftBlue.opacity(0.13))
            .clipShape(Capsule())
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
    }
}

struct WorkoutProgramProgressionEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let settings: WorkoutPlanProgressionSettings
    let template: WorkoutProgramTemplate
    @State private var method: WorkoutProgressionMethod
    @State private var inputs: [String: String]

    init(settings: WorkoutPlanProgressionSettings, template: WorkoutProgramTemplate) {
        self.settings = settings
        self.template = template
        _method = State(initialValue: settings.method)
        _inputs = State(initialValue: settings.trainingMaxKilograms.mapValues { kilograms in
            let value = settings.preferredUnit == .pounds ? RankingCalculator.kilogramsToPounds(kilograms) : kilograms
            return String(format: "%.1f", value)
        })
    }

    private var parsed: [String: Double] {
        inputs.reduce(into: [:]) { result, pair in
            if let value = Double(pair.value), value > 0 {
                result[pair.key] = settings.preferredUnit == .pounds ? RankingCalculator.poundsToKilograms(value) : value
            }
        }
    }

    private var canSave: Bool {
        method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy { parsed[$0, default: 0] > 0 }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Changes apply to unstarted sessions in the current and future weeks. Recorded or skipped sessions, substitutions, exercise order, and the active workout stay unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        ForEach(template.availableProgressionMethods) { option in
                            ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                        }
                        Text(method.guidance).font(.caption).foregroundStyle(Color.liftMuted)
                        if method == .percentage {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Training maxes · \(settings.preferredUnit.shortLabel)").font(.headline)
                                    ForEach(template.requiredTrainingMaxExerciseIDs, id: \.self) { id in
                                        HStack {
                                            Text(appState.trainingExerciseLibrary.first { $0.id == id }?.name ?? id)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            TextField("Required", text: Binding(
                                                get: { inputs[id, default: ""] },
                                                set: { inputs[id] = $0 }
                                            ))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 88)
                                            .padding(9)
                                            .background(Color.liftScrim)
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Change Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if appState.changeProgression(for: settings.planID, method: method, trainingMaxKilograms: parsed) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
