import SwiftUI

struct WorkoutProgramTemplateDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let template: WorkoutProgramTemplate
    @State private var method: WorkoutProgressionMethod
    @State private var startDate = Date.now
    @State private var scheduledWeekdays: [Int]
    @State private var trainingMaxInputs: [String: String] = [:]
    @State private var expandedSessionIndices: Set<Int> = [0]

    init(template: WorkoutProgramTemplate) {
        self.template = template
        _method = State(initialValue: template.defaultProgression)
        _scheduledWeekdays = State(initialValue: template.sessions.map(\.dayIndex))
    }

    private var canStart: Bool {
        method != .percentage || template.requiredTrainingMaxExerciseIDs.allSatisfy { parsedTrainingMaxKilograms[$0, default: 0] > 0 }
    }

    private var parsedTrainingMaxKilograms: [String: Double] {
        trainingMaxInputs.reduce(into: [:]) { result, pair in
            guard let value = Double(pair.value), value > 0 else { return }
            result[pair.key] = appState.currentProfile.preferredUnit == .pounds
                ? RankingCalculator.poundsToKilograms(value)
                : value
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview
                        setup
                        phaseSummary
                        sessionPreview
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Button("Start 12-Week Program") {
                        if appState.startWorkoutProgram(
                            template: template,
                            startDate: startDate,
                            scheduledWeekdays: scheduledWeekdays,
                            method: method,
                            trainingMaxKilograms: parsedTrainingMaxKilograms
                        ) != nil {
                            dismiss()
                        }
                    }
                    .buttonStyle(LiftPrimaryButtonStyle())
                    .disabled(!canStart)
                    .accessibilityIdentifier("training.programPreview.start")
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Program Preview")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("training.programPreview.screen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { seedTrainingMaxesIfNeeded() }
            .onChange(of: method) { _, value in
                if value == .percentage { seedTrainingMaxesIfNeeded() }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(template.name)
                .font(.title2.weight(.black))
            Text(template.summary)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 8) {
                metadataChip(template.category.rawValue)
                metadataChip(template.level.rawValue)
                metadataChip("\(template.daysPerWeek) days/week")
            }
        }
    }

    private var setup: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Program setup").font(.headline)
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progression").font(.caption.weight(.bold)).foregroundStyle(Color.liftMuted)
                    ForEach(WorkoutProgressionMethod.allCases) { option in
                        ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training days").font(.caption.weight(.bold)).foregroundStyle(Color.liftMuted)
                    ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
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
                if method == .percentage { trainingMaxFields }
            }
        }
    }

    private var trainingMaxFields: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Training maxes")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            Text("Suggested values use 90% of your best LiftRank 1RM or estimated 1RM. Review them before starting.")
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
                        .background(Color.black.opacity(0.18))
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
            Text("12-week structure").font(.headline)
            ForEach(["Weeks 1–3 · Foundation", "Week 4 · Deload", "Weeks 5–7 · Progressive overload", "Week 8 · Deload", "Weeks 9–11 · Intensification", "Week 12 · Recovery and optional performance check"], id: \.self) { title in
                Label(title, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var sessionPreview: some View {
        let exerciseCount = template.sessions.reduce(0) { $0 + $1.exercises.count }
        let workingSetCount = template.sessions.reduce(0) { total, session in
            total + session.exercises.reduce(0) { $0 + $1.sets }
        }
        let allExpanded = expandedSessionIndices.count == template.sessions.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly workouts")
                        .font(.title3.weight(.black))
                    Text("Tap a training day to view its exercises")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button(allExpanded ? "Collapse" : "Expand all") {
                    toggleAllSessions(expand: !allExpanded)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                weeklyMetric(value: "\(template.daysPerWeek)", label: "DAYS")
                weeklyMetric(value: "\(exerciseCount)", label: "EXERCISES")
                weeklyMetric(value: "\(workingSetCount)", label: "SETS")
            }

            ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                weeklySessionCard(session, index: index)
            }
        }
    }

    private func weeklyMetric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
                .foregroundStyle(Color.liftText)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private func weeklySessionCard(_ session: WorkoutProgramSessionTemplate, index: Int) -> some View {
        let isExpanded = expandedSessionIndices.contains(index)
        let setCount = session.exercises.reduce(0) { $0 + $1.sets }
        let weekday = Calendar.current.weekdayName(for: scheduledWeekdays[index])

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleSession(index)
            } label: {
                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        Text(String(weekday.prefix(3)).uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(0.4)
                    }
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 46, height: 42)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftText)
                        Text("\(session.exercises.count) exercises · \(setCount) working sets")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isExpanded ? Color.liftBlue : Color.liftMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
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
                        let exercise = templateExercise(for: prescription)
                        HStack(spacing: 11) {
                            ExerciseCatalogIcon(exercise: exercise)
                                .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftText)
                                    .lineLimit(1)
                                Text(exercise.resolvedMuscleProfile.primaryDescription)
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 6)

                            Text("\(prescription.sets) × \(prescription.reps)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.liftBlue)
                                .padding(.horizontal, 9)
                                .frame(minHeight: 28)
                                .background(Color.liftBlue.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)

                        if exerciseIndex < session.exercises.count - 1 {
                            Divider()
                                .overlay(Color.liftSeparator)
                                .padding(.leading, 59)
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
                .stroke(isExpanded ? Color.liftBlue.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
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
            symbolName: "dumbbell.fill",
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
            .foregroundStyle(Color.liftBlue)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.liftBlue.opacity(0.13))
            .clipShape(Capsule())
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
                        Text("Changes apply only to uncompleted future weeks. Completed weeks, substitutions, exercise order, and the active workout stay unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        ForEach(WorkoutProgressionMethod.allCases) { option in
                            ProgramChoiceRow(title: option.rawValue, isSelected: method == option) { method = option }
                        }
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
                                            .background(Color.black.opacity(0.18))
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
