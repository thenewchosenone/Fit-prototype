import Charts
import SwiftUI
import UniformTypeIdentifiers

enum TrackerProgressCategory: String, CaseIterable, Identifiable {
    case consistency = "Consistency"
    case strength = "Strength"
    case muscle = "Muscle"
    case body = "Body"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .consistency: "Progress"
        case .strength: "Exercise progress"
        case .muscle: "Muscle workload"
        case .body: "Bodyweight"
        }
    }
}

extension TrainingFocus {
    var startingCategory: TrackerProgressCategory {
        switch self {
        case .bodybuilding: .muscle
        case .powerlifting: .strength
        case .generalFitness, .mixed: .consistency
        }
    }
}

extension TrainingTrackerView {
    var progress: some View {
        return LazyVStack(alignment: .leading, spacing: 18) {
            progressSyncStatus
            if selectedProgressCategory == .consistency {
                recentTrainingSummary
                recentExerciseProgress
                progressDestination(.muscle, subtitle: "Weekly working sets and when you last trained each muscle", symbol: "figure.strengthtraining.traditional")
                progressDestination(.body, subtitle: bodyweightOverviewText, symbol: "scalemass")
                NavigationLink {
                    AppBackground {
                        ScrollView {
                            workoutHistorySection(presentation: appState.workoutHistoryPresentation(
                                displayedMonth: workoutHistoryMonth, selectedDate: selectedWorkoutHistoryDate
                            ))
                            .padding(16)
                        }
                    }
                    .navigationTitle("Workout history")
                    .toolbar(.visible, for: .navigationBar)
                } label: {
                    Label("Workout history", systemImage: "calendar")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("tracker.progress.history")
                NavigationLink {
                    AppBackground {
                        ScrollView { activityHeatmapSection.padding(16) }
                    }
                    .navigationTitle("Training pattern")
                    .toolbar(.visible, for: .navigationBar)
                } label: {
                    Label("Long-term training pattern", systemImage: "square.grid.3x3")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("tracker.progress.pattern")
            }

            if selectedProgressCategory == .strength {
                exerciseProgressSection(options: exerciseTrendOptions)
                    .id("tracker-strength-exercise")
            }

            if selectedProgressCategory == .muscle {
                muscleProgress
            }

            if selectedProgressCategory == .body {
                bodyProgressSection
            }
        }
        .sheet(isPresented: $showingTrainingRecap) {
            TrainingRecapView().environmentObject(appState)
        }
        .sheet(isPresented: $showingStrengthGoalEditor) { strengthGoalEditor }
        .alert("About exercise progress", isPresented: $showingProgressExplanation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Charts cover the last 30 days. Change compares the first and latest eligible training days in that period. Latest and Previous show the actual sets behind the two most recent points. Weighted exercises use estimated one-rep max from working sets of 1–10 reps; this is an estimate, not a lifted weight. Bodyweight exercises use best reps. Warmups and recovery/deload workouts are excluded.")
        }
        .onAppear {
            if !didOpenProgress {
                selectedProgressCategory = .consistency
                didOpenProgress = true
            }
            if let category = appState.router.progressCategory {
                selectedProgressCategory = category
                appState.router.progressCategory = nil
            }
            if selectedProgressCategory == .strength { syncProgressExerciseSelection() }
            if selectedProgressCategory == .consistency { syncWorkoutHistorySelection() }
            Task {
                await appState.synchronizeCompletedWorkoutHistory(force: false)
                await refreshStrengthGoalTargets()
            }
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            if selectedProgressCategory == .strength { syncProgressExerciseSelection() }
            if selectedProgressCategory == .consistency { syncWorkoutHistorySelection() }
        }
        .onChange(of: appState.router.progressCategory) { _, requested in
            if let requested {
                selectedProgressCategory = requested
                appState.router.progressCategory = nil
            }
        }
        .onChange(of: selectedProgressCategory) { _, category in
            if category == .strength { syncProgressExerciseSelection() }
            if category == .consistency { syncWorkoutHistorySelection() }
        }
        .onChange(of: appState.currentProfile.id) {
            selectedProgressCategory = .consistency
        }
        .onChange(of: selectedProgressExerciseID) { _, exerciseID in
            storedProgressExerciseID = exerciseID ?? ""
        }
    }

    private var recentTrainingSummary: some View {
        let end = Calendar.current.dateInterval(of: .day, for: .now)!.end
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let previousStart = Calendar.current.date(byAdding: .day, value: -30, to: start) ?? start
        let current = appState.trainingProgressStore.trainingRecap(in: DateInterval(start: start, end: end))
        let previous = appState.trainingProgressStore.trainingRecap(in: DateInterval(start: previousStart, end: start))
        return LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 30 days").font(LiftTypography.cardTitle)
                    .accessibilityIdentifier("tracker.progress.trainingSummary")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 10) {
                    ForEach([("Workouts", current.workoutCount), ("Days trained", current.trainingDayCount), ("Working sets", current.workingSetCount), ("Exercises", current.exerciseCount)], id: \.0) { metric in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(metric.1.formatted()).font(.headline.monospacedDigit())
                            Text(metric.0).font(.caption).foregroundStyle(Color.liftMuted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if previous.workoutCount > 0 {
                    let workoutChange = current.workoutCount - previous.workoutCount
                    let setChange = current.workingSetCount - previous.workingSetCount
                    Text("Vs prior 30 days: \(workoutChange.formatted(.number.sign(strategy: .always()))) workouts, \(setChange.formatted(.number.sign(strategy: .always()))) working sets.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                } else {
                    Text(current.workoutCount == 0 ? "Save a workout to start seeing your training history here." : "A comparison will appear once you have history in the previous 30 days.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                }
                Button("View training recap") { showingTrainingRecap = true }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("tracker.progress.recaps")
            }
        }
    }

    @ViewBuilder
    private var progressSyncStatus: some View {
        if appState.isAuthenticated && !appState.isDemoMode {
            let state = appState.workoutSyncStore.historySyncState
            if state != .synced {
                let pendingCount = appState.workoutSyncStore.pendingCompletedWorkoutUploads.count
                let copy: (String, String, String, Color) = switch state {
                case .local:
                    ("Progress uses history saved on this device", "\(pendingCount) workout\(pendingCount == 1 ? "" : "s") saved on this device; sync when you’re online.", "iphone.and.arrow.forward", .orange)
                case .syncing:
                    ("Refreshing workout history", "Keep this screen open while Progress updates.", "arrow.triangle.2.circlepath", .liftAccentText)
                case .stale:
                    ("Progress may be out of date", "Refresh to update your Progress stats.", "clock.arrow.circlepath", .orange)
                case .needsAttention:
                    ("Progress may be incomplete", appState.workoutSyncStore.unreadableRemoteWorkoutCount > 0
                     ? "\(appState.workoutSyncStore.unreadableRemoteWorkoutCount) saved workout\(appState.workoutSyncStore.unreadableRemoteWorkoutCount == 1 ? "" : "s") could not load. Retry to update Progress."
                     : "Workout history could not refresh. Retry to update Progress.", "exclamationmark.triangle.fill", .orange)
                case .synced:
                    ("", "", "", .clear)
                }
                let canRetry = state == .local || state == .stale || state == .needsAttention
                let content = HStack(spacing: 10) {
                    Image(systemName: copy.2)
                        .foregroundStyle(copy.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.0)
                            .font(LiftTypography.rowEmphasis)
                        Text(copy.1)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer(minLength: 4)
                    if canRetry {
                        Text("Retry")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                    }
                }
                if canRetry {
                    Button {
                        Task { await appState.synchronizeCompletedWorkoutHistory(force: true) }
                    } label: {
                        content
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.liftOverlay, lineWidth: 1)
                    }
                    .accessibilityLabel("Retry Progress history refresh")
                    .accessibilityValue(copy.1)
                } else {
                    content
                        .padding(12)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.liftOverlay, lineWidth: 1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(copy.0)
                        .accessibilityValue(copy.1)
                }
            }
        }
    }

    private func progressDestination(_ category: TrackerProgressCategory, subtitle: String, symbol: String) -> some View {
        Button { selectedProgressCategory = category } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(category.title, systemImage: symbol).font(LiftTypography.cardTitle)
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.liftAccentText)
            }
            .foregroundStyle(Color.liftText)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(18)
            .liftSurface(radius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tracker.progress.category.\(category.rawValue.lowercased())")
    }

    private var bodyweightOverviewText: String {
        guard let entry = appState.bodyweightEntries.filter({ ($0.actual ?? 0) > 0 && $0.targetDate <= .now }).max(by: { $0.targetDate < $1.targetDate }), let value = entry.actual else {
            return "Log a measurement to start your trend"
        }
        return "\(MeasurementFormatting.formatBodyweight(value, preferredUnit: appState.currentProfile.preferredUnit)) · \(entry.targetDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var recentExerciseProgress: some View {
        let recentIDs = appState.trainingProgressStore.recentExerciseIDs(limit: 20)
        let options = Dictionary(uniqueKeysWithValues: exerciseTrendOptions.map { ($0.id, $0) })
        let ids = recentIDs.reduce(into: [String]()) { result, id in
            if options[id] != nil && !result.contains(id) && result.count < 3 { result.append(id) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise progress").font(LiftTypography.cardTitle)
                    .accessibilityIdentifier("tracker.progress.summary")
                Button { showingProgressExplanation = true } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("About exercise progress")
                Spacer(minLength: 0)
                Button("View all") { selectedProgressCategory = .strength }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("tracker.progress.category.strength")
            }
            if ids.isEmpty {
                Text("Your recent exercises will appear here after you save working sets.")
                    .font(.subheadline).foregroundStyle(Color.liftMuted)
            }
            Text("Last 30 days · best eligible set per training day")
                .font(.caption).foregroundStyle(Color.liftMuted)
            ForEach(ids, id: \.self) { id in
                if let exercise = options[id] {
                    Button {
                        selectedProgressExerciseID = id
                        selectedExerciseStrengthTrendDate = nil
                        selectedExerciseWeightTrendDate = nil
                        selectedProgressCategory = .strength
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(exercise.name).font(.subheadline.weight(.medium))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            ExerciseProgressComparison(exercise: exercise, points: appState.trainingProgressStore.recentExerciseTrend(for: exercise.id, days: 30))
                        }
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.liftText)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tracker.progress.recentExercise.\(id)")
                    if id != ids.last { Divider().overlay(Color.liftOverlay) }
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var activityHeatmapSection: some View {
        WorkoutActivityHeatmap(
            workouts: appState.completedWorkouts,
            period: $activityHeatmapPeriod,
            measure: $activityHeatmapMeasure,
            unit: appState.currentProfile.preferredUnit,
            catalog: appState.trainingExerciseLibrary
        )
    }

    private var bodyProgressSection: some View {
        let entries = appState.bodyweightEntries
            .filter { ($0.actual ?? 0) > 0 && $0.targetDate <= .now }
            .sorted { $0.targetDate < $1.targetDate }
        let dayLimit = ["1M": 30, "3M": 90, "1Y": 365][selectedBodyProgressPeriod]
        let cutoff = dayLimit.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) } ?? .distantPast
        let history = entries.filter { $0.targetDate >= cutoff }
        let unit = appState.currentProfile.preferredUnit
        return VStack(alignment: .leading, spacing: 18) {
            (dynamicTypeSize.isAccessibilitySize
             ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
             : AnyLayout(HStackLayout(spacing: 12))) {
                Text("Bodyweight trend")
                    .font(LiftTypography.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    selectedBodyweightEntry = BodyweightEntry.draftForToday(
                        entries: appState.bodyweightEntries,
                        currentBodyweightPounds: appState.currentProfile.bodyweightPounds
                    )
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .foregroundStyle(Color.liftAccentText)
                .accessibilityLabel("Log bodyweight")
            }
            VStack(alignment: .leading, spacing: 4) {
                if let latest = history.last, let value = latest.actual {
                    Text(MeasurementFormatting.formatBodyweight(value, preferredUnit: unit))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                    Text("Latest · \(latest.targetDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    Text(entries.isEmpty
                         ? "Log your first dated measurement to start your trend."
                         : "No measurements in this period. Choose a wider range or log a measurement.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            Picker("Bodyweight period", selection: $selectedBodyProgressPeriod) {
                Text("1M").tag("1M")
                Text("3M").tag("3M")
                Text("1Y").tag("1Y")
                Text("All").tag("All")
            }
            .pickerStyle(.segmented)
            if history.count > 1 {
                Chart(history, id: \.id) { entry in
                    if let value = entry.actual {
                        LineMark(
                            x: .value("Date", entry.targetDate),
                            y: .value("Bodyweight", MeasurementFormatting.convert(value, from: .pounds, to: unit))
                        )
                        .foregroundStyle(Color.liftAccentText)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        PointMark(
                            x: .value("Date", entry.targetDate),
                            y: .value("Bodyweight", MeasurementFormatting.convert(value, from: .pounds, to: unit))
                        )
                        .foregroundStyle(Color.liftAccentText)
                        .symbolSize(24)
                    }
                }
                .chartYAxisLabel(unit.shortLabel, position: .trailing)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                            .foregroundStyle(Color.liftMuted.opacity(0.25))
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(Color.liftMuted) } }
                .accessibilityRepresentation {
                    VStack(alignment: .leading) {
                        ForEach(history, id: \.id) { entry in
                            if let value = entry.actual {
                                Text("\(entry.targetDate.formatted(date: .abbreviated, time: .omitted)), bodyweight \(MeasurementFormatting.formatBodyweight(value, preferredUnit: unit))")
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else if let onlyEntry = history.first {
                Text("One measurement in this period (\(onlyEntry.targetDate.formatted(date: .abbreviated, time: .omitted))). Add another to see a trend.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(18)
        .liftSurface(radius: 20)
    }

    var trainingRecencySection: some View {
        let summaries = Array(appState.recoverySummaries().prefix(4))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recently trained muscles")
                    .font(LiftTypography.cardTitle)
                Spacer()
                Text("last 7 days")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }

            if summaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete working sets to see when each muscle was last trained.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { segment = .today }
                    } label: {
                        Label("Start a workout", systemImage: "play.fill")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(summaries, id: \.muscle) { summary in
                    Button {
                        focusedWorkoutSetID = nil
                        selectedCompletedWorkout = mostRecentWorkout(for: summary.muscle)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .foregroundStyle(Color.liftMuted)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.muscle.displayName)
                                    .font(LiftTypography.compactEmphasis)
                                Text("\(summary.setCount) working sets · \(recoveryAgeText(summary.hoursSinceTraining))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        .foregroundStyle(Color.liftText)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .disabled(mostRecentWorkout(for: summary.muscle) == nil)
                    .accessibilityLabel("\(summary.muscle.displayName), \(summary.setCount) working sets, \(recoveryAgeText(summary.hoursSinceTraining))")
                    .accessibilityHint("Opens the most recent workout for this muscle")
                }
                DisclosureGroup("How to read training recency") {
                    Text("Dates describe logged primary work. Time since a workout does not measure recovery or readiness.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 4)
                }
                .font(.caption.weight(.semibold))
                .tint(Color.liftAccentText)
            }
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private func recoveryAgeText(_ hours: Int) -> String {
        if hours < 1 { return "trained just now" }
        if hours < 24 { return "trained \(hours)h ago" }
        let days = hours / 24
        return "trained \(days)d ago"
    }

    private func strengthGoalOverview(exercise: TrainingExerciseCatalogItem, latestEstimate: ExerciseProgressPoint?) -> some View {
        let target = strengthGoalTargetsKilograms[exercise.id]
        let unit = appState.currentProfile.preferredUnit
        let latest = latestEstimate.map(ExerciseProgressSeries.estimatedOneRepMax)
        return VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack {
                Text("Estimated 1RM goal").font(LiftTypography.rowEmphasis)
                Spacer()
                Button(target == nil ? "Add goal" : "Edit goal") {
                    strengthGoalExerciseID = exercise.id
                    loadStrengthGoalTargetDraft()
                    showingStrengthGoalEditor = true
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            if let strengthGoalError {
                Text(strengthGoalError).foregroundStyle(Color.liftRed)
                Button("Retry goal sync") { Task { await refreshStrengthGoalTargets() } }
                    .frame(minHeight: 44)
            }
            if let target {
                Text("Target \(MeasurementFormatting.formatDisplayedWeight(target, unit: unit))")
                    .font(.headline.monospacedDigit())
                if let latest, let latestEstimate {
                    Text("Latest in this period: \(MeasurementFormatting.formatDisplayedWeight(latest, unit: unit)) · \(latestEstimate.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                    ProgressView(value: min(1, max(0, latest / target)))
                        .tint(Color.liftAccentText)
                        .accessibilityLabel("Estimated 1RM goal progress")
                } else {
                    Text("No eligible estimate in this period.").font(.caption).foregroundStyle(Color.liftMuted)
                }
            } else {
                Text("Set a personal target for \(exercise.name).")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
        }
    }

    private func mostRecentWorkout(for muscle: ExerciseMuscleRegion) -> CompletedWorkout? {
        appState.trainingHistoryWorkouts.filter { workout in
            workout.exercises.contains { exercise in
                let profile = exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(
                    name: exercise.exerciseName,
                    bodyPart: exercise.bodyPart
                )
                guard profile.primary.contains(where: { $0.trainingSummaryRegion == muscle }) else { return false }
                return workout.sets.contains {
                    $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup
                }
            }
        }.max { $0.completedAt < $1.completedAt }
    }

    private func workoutHistorySection(presentation: WorkoutHistoryCalendarPresentation) -> some View {
        WorkoutHistoryCalendar(
            presentation: presentation,
            displayedMonth: $workoutHistoryMonth,
            selectedDate: $selectedWorkoutHistoryDate
        ) { workout in
            focusedWorkoutSetID = nil
            selectedCompletedWorkout = workout
        } onLogWorkout: { date in
            workoutDateToLog = date
            showingWorkoutDatePicker = true
        }
    }

    private var strengthGoalEditor: some View {
        NavigationStack {
            if let exercise = progressExerciseOptions.first(where: { $0.id == strengthGoalExerciseID }) {
                let estimate = ExerciseProgressSeries.dailyHighestEstimatedOneRepMax(
                    from: appState.exerciseProgressPoints(for: exercise.id)
                ).last.map(ExerciseProgressSeries.estimatedOneRepMax)
                ScrollViewReader { goalScroll in
                    Form {
                        Section("Exercise") {
                            Text(exercise.name)
                                .font(.headline)
                            if let estimate {
                                LabeledContent("Latest estimated 1RM", value: MeasurementFormatting.formatDisplayedWeight(estimate, unit: appState.currentProfile.preferredUnit))
                            } else {
                                Text("No logged estimate yet")
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .listRowBackground(Color.liftCard)
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                if let strengthGoalError {
                                    Text(strengthGoalError)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftRed)
                                } else if !strengthGoalTargetDraft.isEmpty && strengthGoalDraftKilograms == nil {
                                    Text("Enter a target greater than zero.")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftRed)
                                }
                                HStack(spacing: 12) {
                                    TextField("Target weight", text: $strengthGoalTargetDraft)
                                        .font(.title2.monospacedDigit())
                                        .keyboardType(.decimalPad)
                                        .disabled(savingStrengthGoal)
                                        .accessibilityLabel("Target weight")
                                    Text(appState.currentProfile.preferredUnit.shortLabel)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .frame(minHeight: LiftDesign.minimumTouchTarget)
                            }
                            .id("strength.goal.target")
                        } header: {
                            Text("Target estimated 1RM")
                        } footer: {
                            Text("The weight you aim to lift for one repetition.")
                        }
                        .listRowBackground(Color.liftCard)
                        if strengthGoalTargetsKilograms[exercise.id] != nil {
                            Section {
                                Button("Remove goal", role: .destructive) {
                                    var targets = strengthGoalTargetsKilograms
                                    targets.removeValue(forKey: exercise.id)
                                    saveStrengthGoalTargets(targets)
                                }
                                .disabled(savingStrengthGoal)
                            }
                            .listRowBackground(Color.liftCard)
                        }
                    }
                    .onChange(of: strengthGoalTargetDraft) {
                        DispatchQueue.main.async { goalScroll.scrollTo("strength.goal.target", anchor: .bottom) }
                    }
                    .onChange(of: strengthGoalError) {
                        DispatchQueue.main.async { goalScroll.scrollTo("strength.goal.target", anchor: .bottom) }
                    }
                }
                .foregroundStyle(Color.liftText)
                .scrollContentBackground(.hidden)
                .background(Color.liftBackground)
                .interactiveDismissDisabled(savingStrengthGoal)
                .navigationTitle("Strength goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingStrengthGoalEditor = false }.disabled(savingStrengthGoal)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(savingStrengthGoal ? "Saving…" : "Save") {
                            guard let target = strengthGoalDraftKilograms else { return }
                            var targets = strengthGoalTargetsKilograms
                            targets[exercise.id] = target
                            saveStrengthGoalTargets(targets)
                        }
                        .disabled(savingStrengthGoal || strengthGoalDraftKilograms == nil)
                    }
                }
                .tint(Color.liftAccentText)
            }
        }
    }

    private func exerciseProgressSection(
        options: [TrainingExerciseCatalogItem]
    ) -> some View {
        let exerciseID = selectedProgressExerciseID ?? options.first?.id
        let exercise = options.first { $0.id == exerciseID }
        let now = Date.now
        let periodDays = ["1M": 30, "3M": 90, "1Y": 365][selectedStrengthTrendPeriod]
        let start = periodDays.flatMap { Calendar.current.date(byAdding: .day, value: -$0 + 1, to: Calendar.current.startOfDay(for: now)) } ?? .distantPast
        let recoveryIDs = Set(appState.trainingProgressStore.completedWorkouts
            .filter { $0.completedAt >= start && $0.completedAt <= now && appState.trainingProgressStore.isRecoveryWorkout($0) }
            .map(\.id))
        let setPoints = (exercise.map { appState.exerciseProgressPoints(for: $0.id) } ?? [])
            .filter { $0.date >= start && $0.date <= now && !($0.workoutID.map { recoveryIDs.contains($0) } ?? false) }
        let usesRepetitions = exercise.map { [.bodyweightReps, .repsOnly].contains(ExerciseTrackingKind($0.trackingType)) } ?? false
        let repetitionPoints = ExerciseProgressSeries.dailyHighestRepetitions(from:
            (exercise.map { appState.trainingProgressStore.repetitionProgressPoints(for: $0.id) } ?? [])
                .filter { $0.date >= start && $0.date <= now && !($0.workoutID.map { recoveryIDs.contains($0) } ?? false) }
        )
        let chartPoints = ExerciseProgressSeries.dailyHighest(from: setPoints)
        let estimatedMaxPoints = ExerciseProgressSeries.dailyHighestEstimatedOneRepMax(from: setPoints)

        return VStack(alignment: .leading, spacing: 12) {
            AnyView(VStack(alignment: .leading, spacing: 4) {
                Button {
                    showingProgressExercisePicker = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(exercise?.name ?? "Exercise")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                        .font(LiftTypography.sectionTitle)
                        .foregroundStyle(Color.liftText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tracker.progress.exercisePicker")
                .sheet(isPresented: $showingProgressExercisePicker) {
                    ProgressExercisePickerSheet(options: options, selectedID: selectedProgressExerciseID, title: "Choose exercise", preferredIDs: Set(appState.trainingProgressStore.recentExerciseIDs(limit: 20)), goalIDs: Set(strengthGoalTargetsKilograms.keys)) { exerciseID in
                        selectedProgressExerciseID = exerciseID
                        selectedExerciseWeightTrendDate = nil
                        selectedExerciseStrengthTrendDate = nil
                    }
                }
            })
            Picker("Exercise progress period", selection: $selectedStrengthTrendPeriod) {
                Text("1M").tag("1M")
                Text("3M").tag("3M")
                Text("1Y").tag("1Y")
                Text("All").tag("All")
            }
            .pickerStyle(.segmented)

            if usesRepetitions {
                if let best = repetitionPoints.map(\.reps).max() {
                    Text("Best set · \(best) reps")
                        .font(LiftTypography.sectionTitle)
                    Chart(repetitionPoints) { point in
                        BarMark(x: .value("Day", point.date, unit: .day), y: .value("Reps", point.reps))
                            .foregroundStyle(Color.liftAccentText)
                            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue("\(point.reps) reps")
                    }
                    .frame(height: 180)
                    Text("Best completed working set each day. Warm-ups and recovery workouts are excluded. The record and chart use the same selected date range.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    ForEach(repetitionPoints.suffix(5).reversed()) { point in
                        Button {
                            selectedCompletedWorkout = appState.trainingProgressStore.completedWorkouts.first { $0.id == point.workoutID }
                            focusedWorkoutSetID = point.id
                        } label: {
                            HStack {
                                Text(point.date, format: .dateTime.month(.abbreviated).day())
                                Spacer()
                                Text("\(point.reps) reps")
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Complete a working set to see your rep record and daily trend.")
                        .foregroundStyle(Color.liftMuted)
                }
            } else if chartPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete sets for this exercise to build its trend.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { segment = .today }
                    } label: {
                        Label("Log this exercise", systemImage: "play.fill")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                StrengthExerciseCharts(
                    chartPoints: chartPoints,
                    estimatedMaxPoints: estimatedMaxPoints,
                    preferredUnit: appState.currentProfile.preferredUnit,
                    selectedExerciseStrengthTrendDate: $selectedExerciseStrengthTrendDate,
                    selectedExerciseWeightTrendDate: $selectedExerciseWeightTrendDate
                )
                StrengthSelectedPerformance(
                    chartPoints: chartPoints,
                    estimatedMaxPoints: estimatedMaxPoints,
                    selectedExerciseStrengthTrendDate: selectedExerciseStrengthTrendDate,
                    selectedExerciseWeightTrendDate: selectedExerciseWeightTrendDate,
                    selectedCompletedWorkout: $selectedCompletedWorkout,
                    focusedWorkoutSetID: $focusedWorkoutSetID
                )
                DisclosureGroup {
                    StrengthExerciseRecords(
                    exerciseID: exerciseID,
                    setPoints: setPoints,
                    periodTitle: selectedStrengthTrendPeriod == "All" ? "all time" : "last \(selectedStrengthTrendPeriod)",
                    selectedCompletedWorkout: $selectedCompletedWorkout,
                    focusedWorkoutSetID: $focusedWorkoutSetID
                    )
                } label: {
                    Text("Records and source workouts")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .tint(Color.liftAccentText)
            }
            if let exercise, ExerciseTrackingKind(exercise.trackingType) == .weightReps {
                strengthGoalOverview(exercise: exercise, latestEstimate: estimatedMaxPoints.last)
            }
        }
        .padding(18)
        .liftSurface(radius: 20)
    }

    var strainAndInjurySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Strain & injuries")
                .font(LiftTypography.cardTitle)

            if let latestStrain = appState.latestStrainEntry {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(LiftTypography.compactEmphasis)
                        .foregroundStyle(Color.liftAccentText)
                        .frame(width: 30, height: 30)
                        .background(Color.liftBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest strain: \(latestStrain.strain)/10")
                            .font(LiftTypography.rowEmphasis)
                            .foregroundStyle(Color.liftText)
                        if !latestStrain.notes.isEmpty {
                            Text(latestStrain.notes)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Text(latestStrain.occurredAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(12)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            let recent = recentStrainEntries
            if !recent.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 10) {
                            Text(entry.occurredAt, format: .dateTime.month().day())
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color.liftMuted)
                            Text("Strain")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftText)
                            Spacer()
                            Text("\(entry.strain)/10")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.liftAccentText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)

                        if index < recent.count - 1 {
                            Divider()
                                .overlay(Color.liftSeparator)
                                .padding(.leading, 90)
                        }
                    }
                }
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            let activeInjuries = appState.activeInjuries
            if activeInjuries.isEmpty {
                Text("No active injuries tracked.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(activeInjuries) { injury in
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(Color.liftGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(injury.area): \(injury.description)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftText)
                                Text("Pain \(injury.intensity)/10")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer()
                            Text(injury.status == .resolved ? "Resolved" : "Active")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(injury.status == .resolved ? Color.liftGreen : Color.liftGold)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private var completedTrainingHistoryWorkouts: [CompletedWorkout] {
        appState.trainingHistoryWorkouts
    }

    private var strengthGoalTargetsKilograms: [String: Double] {
        _ = strengthGoalsRevision
        guard let value = UserDefaults.standard.string(forKey: strengthGoalStorageKey),
              let data = value.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private var strengthGoalStorageKey: String {
        "liftrank.strengthGoalTargetsKg.\(appState.currentProfile.id.uuidString)"
    }

    private func cacheStrengthGoalTargets(_ targets: [String: Double]) throws {
        let data = try JSONEncoder().encode(targets)
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: strengthGoalStorageKey)
        strengthGoalsRevision += 1
    }

    private func refreshStrengthGoalTargets() async {
        guard appState.isAuthenticated && !appState.isDemoMode, !savingStrengthGoal else { return }
        let userID = appState.currentProfile.id
        let revision = strengthGoalsRevision
        do {
            let remote = try await appState.fetchStrengthGoalTargets()
            guard appState.currentProfile.id == userID, !savingStrengthGoal, strengthGoalsRevision == revision else { return }
            if let remote {
                try cacheStrengthGoalTargets(remote)
            } else if !strengthGoalTargetsKilograms.isEmpty {
                try await appState.saveStrengthGoalTargets(strengthGoalTargetsKilograms)
            }
            strengthGoalError = nil
        } catch {
            guard appState.currentProfile.id == userID else { return }
            strengthGoalError = "Goals couldn’t sync. Your saved goals are still on this device. Try again when connected."
        }
    }

    private func saveStrengthGoalTargets(_ targets: [String: Double]) {
        guard !savingStrengthGoal else { return }
        savingStrengthGoal = true
        strengthGoalError = nil
        let userID = appState.currentProfile.id
        Task {
            defer { savingStrengthGoal = false }
            do {
                if appState.isAuthenticated && !appState.isDemoMode {
                    try await appState.saveStrengthGoalTargets(targets)
                }
                guard appState.currentProfile.id == userID else { return }
                try cacheStrengthGoalTargets(targets)
                showingStrengthGoalEditor = false
            } catch {
                guard appState.currentProfile.id == userID else { return }
                strengthGoalError = "Goal couldn’t be saved. Your entry is still here. Check your connection and try again."
            }
        }
    }

    private func loadStrengthGoalTargetDraft() {
        strengthGoalError = nil
        guard let exerciseID = strengthGoalExerciseID,
              let target = strengthGoalTargetsKilograms[exerciseID] else {
            strengthGoalTargetDraft = ""
            return
        }
        strengthGoalTargetDraft = MeasurementFormatting.convert(target, from: .kilograms, to: appState.currentProfile.preferredUnit)
            .formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    private var strengthGoalDraftKilograms: Double? {
        let normalized = strengthGoalTargetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return MeasurementFormatting.normalizeToKilograms(value, unit: appState.currentProfile.preferredUnit)
    }

    private var exerciseTrendOptions: [TrainingExerciseCatalogItem] {
        appState.trainingExerciseLibrary.filter {
            [.weightReps, .bodyweightReps, .repsOnly].contains(ExerciseTrackingKind($0.trackingType))
        }.sorted { $0.name < $1.name }
    }

    private var progressExerciseOptions: [TrainingExerciseCatalogItem] {
        appState.progressExerciseOptions()
    }

    private func syncWorkoutHistorySelection() {
        guard let mostRecent = completedTrainingHistoryWorkouts.max(by: { $0.completedAt < $1.completedAt }) else {
            selectedWorkoutHistoryDate = Calendar.current.startOfDay(for: .now)
            workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
            return
        }
        if selectedWorkoutHistoryDate == nil {
            selectedWorkoutHistoryDate = Calendar.current.startOfDay(for: mostRecent.completedAt)
            workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: mostRecent.completedAt)?.start ?? mostRecent.completedAt
        }
    }

    private func syncProgressExerciseSelection() {
        let options = exerciseTrendOptions
        let optionIDs = Set(options.map(\.id))
        if let selectedProgressExerciseID, optionIDs.contains(selectedProgressExerciseID) {
            return
        }
        if selectedProgressExerciseID == nil, optionIDs.contains(storedProgressExerciseID) {
            selectedProgressExerciseID = storedProgressExerciseID
            return
        }
        let recentExerciseIDs = appState.trainingHistoryWorkouts.flatMap { $0.exercises.map(\.exerciseID) }
        selectedProgressExerciseID = recentExerciseIDs.first {
            optionIDs.contains($0) && (!appState.exerciseProgressPoints(for: $0).isEmpty || !appState.trainingProgressStore.repetitionProgressPoints(for: $0).isEmpty)
        } ?? options.first?.id
    }

    private var recentStrainEntries: [StrainEntry] {
        appState.strainEntries
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(5)
            .map { $0 }
    }
}

// Separate bodies prevent the combined exercise builder from exhausting the device stack.
private struct StrengthExerciseCharts: View {
    @State private var selectedMetric = "Estimated 1RM"
    let chartPoints: [ExerciseProgressPoint]
    let estimatedMaxPoints: [ExerciseProgressPoint]
    let preferredUnit: UnitSystem
    @Binding var selectedExerciseStrengthTrendDate: Date?
    @Binding var selectedExerciseWeightTrendDate: Date?

    var body: some View {
        let startingEstimatedMax = estimatedMaxPoints.first.map(ExerciseProgressSeries.estimatedOneRepMax)
        let latestEstimatedMax = estimatedMaxPoints.last.map(ExerciseProgressSeries.estimatedOneRepMax)
        let strengthIncrease = startingEstimatedMax.flatMap { start in
            latestEstimatedMax.map { $0 - start }
        }

        VStack(alignment: .leading, spacing: 12) {
            Picker("Trend metric", selection: $selectedMetric) {
                Text("Estimated 1RM").tag("Estimated 1RM")
                Text("Logged weight").tag("Logged weight")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tracker.strength.trendMetric")
            .onChange(of: selectedMetric) {
                selectedExerciseStrengthTrendDate = nil
                selectedExerciseWeightTrendDate = nil
            }
            if selectedMetric == "Estimated 1RM" {
            if estimatedMaxPoints.isEmpty {
                Text("Estimated strength needs a completed weighted working set of 1–10 reps. Higher-rep sets still appear in load and volume records.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
            if estimatedMaxPoints.count == 1,
               let currentEstimatedMax = estimatedMaxPoints.first.map(ExerciseProgressSeries.estimatedOneRepMax) {
                ExerciseProgressMetric(
                    title: "Current estimated 1RM",
                    value: MeasurementFormatting.formatDisplayedWeight(currentEstimatedMax, unit: preferredUnit),
                    symbol: "scalemass.fill"
                )
                Text("Log this exercise in another workout to see an estimated 1RM trend.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            } else if let latestEstimatedMax, let strengthIncrease {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest estimated 1RM")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Text(MeasurementFormatting.formatDisplayedWeight(latestEstimatedMax, unit: preferredUnit))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                    Text((strengthIncrease >= 0 ? "+" : "") + MeasurementFormatting.formatDisplayedWeight(strengthIncrease, unit: preferredUnit) + " since start")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(strengthIncrease > 0 ? Color.liftAccentText : strengthIncrease < 0 ? Color.orange : Color.liftMuted)
                    if let first = estimatedMaxPoints.first, let last = estimatedMaxPoints.last {
                        Text("\(first.date.formatted(date: .abbreviated, time: .omitted)) – \(last.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Text("Estimated 1RM trend")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 2)

                Chart(estimatedMaxPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Estimated 1RM", MeasurementFormatting.displayWeight(ExerciseProgressSeries.estimatedOneRepMax(point), unit: preferredUnit))
                    )
                    .foregroundStyle(Color.liftAccentText)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Estimated 1RM", MeasurementFormatting.displayWeight(ExerciseProgressSeries.estimatedOneRepMax(point), unit: preferredUnit))
                    )
                    .foregroundStyle(Color.liftAccentText)
                    .symbolSize(24)
                }
                .frame(height: 190)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .chartXScale(range: .plotDimension(padding: 12))
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel(preferredUnit.shortLabel, position: .trailing)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                            .foregroundStyle(Color.liftMuted.opacity(0.25))
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                        .foregroundStyle(Color.liftMuted)
                } }
                .accessibilityRepresentation {
                    VStack(alignment: .leading) {
                        ForEach(estimatedMaxPoints) { point in
                            Button {
                                selectedExerciseStrengthTrendDate = point.date
                            } label: {
                                Text("\(point.date.formatted(date: .abbreviated, time: .omitted)), estimated one-rep max \(MeasurementFormatting.formatDisplayedWeight(ExerciseProgressSeries.estimatedOneRepMax(point), unit: preferredUnit))")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .accessibilityIdentifier("tracker.strength.estimatedMaxChart")
                .chartXSelection(value: $selectedExerciseStrengthTrendDate)
                .chartGesture { proxy in
                    SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) }
                }
                .onChange(of: selectedExerciseStrengthTrendDate) { _, selection in
                    if selection != nil { selectedExerciseWeightTrendDate = nil }
                }
            }

            } else {
            if let latest = chartPoints.last {
                Text(MeasurementFormatting.formatRecordedWeight(MeasurementFormatting.convert(latest.weight, from: latest.unit, to: preferredUnit), unit: preferredUnit) + " × \(latest.reps) reps")
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                Text("Latest logged set · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Text("Logged weight trend")
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(Color.liftMuted)
                .padding(.top, 2)
            Text(chartPoints.count == 1
                ? "One workout logged; record this exercise again to compare sessions."
                : "Tap a point to view its workout.")
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)

            Chart(chartPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", MeasurementFormatting.convert(point.weight, from: point.unit, to: preferredUnit))
                )
                .foregroundStyle(Color.liftAccentText)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", MeasurementFormatting.convert(point.weight, from: point.unit, to: preferredUnit))
                )
                .foregroundStyle(Color.liftAccentText)
                .symbolSize(24)
            }
            .frame(height: 190)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .chartXScale(range: .plotDimension(padding: 12))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel(preferredUnit.shortLabel, position: .trailing)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                        .foregroundStyle(Color.liftMuted.opacity(0.25))
                    AxisValueLabel().foregroundStyle(Color.liftMuted)
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                    .foregroundStyle(Color.liftMuted)
            } }
            .accessibilityRepresentation {
                VStack(alignment: .leading) {
                    ForEach(chartPoints) { point in
                        Button {
                            selectedExerciseWeightTrendDate = point.date
                        } label: {
                            Text("\(point.date.formatted(date: .abbreviated, time: .omitted)), best logged set \(MeasurementFormatting.formatRecordedWeight(point.weight, unit: point.unit)) for \(point.reps) reps")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityIdentifier("tracker.strength.weightChart")
            .chartXSelection(value: $selectedExerciseWeightTrendDate)
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) }
            }
            .onChange(of: selectedExerciseWeightTrendDate) { _, selection in
                if selection != nil { selectedExerciseStrengthTrendDate = nil }
            }
            }

            DisclosureGroup {
                if let startingEstimatedMax {
                    Text("Starting estimate: \(MeasurementFormatting.formatDisplayedWeight(startingEstimatedMax, unit: preferredUnit)) · \(estimatedMaxPoints.count) logged training days")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text("Estimated 1RM is calculated from completed weighted working sets of 1–10 reps. Change compares the first and latest eligible training days in the selected range, using the dates shown above. Recovery/deload workouts are excluded here and remain available in Library history.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 6)
            } label: {
                Text("About this trend")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            .tint(Color.liftAccentText)
        }
    }
}

private struct StrengthSelectedPerformance: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let chartPoints: [ExerciseProgressPoint]
    let estimatedMaxPoints: [ExerciseProgressPoint]
    let selectedExerciseStrengthTrendDate: Date?
    let selectedExerciseWeightTrendDate: Date?
    @Binding var selectedCompletedWorkout: CompletedWorkout?
    @Binding var focusedWorkoutSetID: UUID?

    var body: some View {
        let selectedStrengthTrendPoint = selectedExerciseStrengthTrendDate.flatMap { selection in
            estimatedMaxPoints.min {
                abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
            }
        }
        let selectedWeightTrendPoint = selectedExerciseWeightTrendDate.flatMap { selection in
            chartPoints.min {
                abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
            }
        }
        Group {
            if let selectedPoint = selectedWeightTrendPoint ?? selectedStrengthTrendPoint,
               let workoutID = selectedPoint.workoutID,
               let workout = appState.trainingHistoryWorkouts.first(where: { $0.id == workoutID }) {
                if let set = workout.sets.first(where: { $0.id == selectedPoint.id }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected performance")
                            .font(LiftTypography.compactEmphasis)
                        Text(LiftTimeFormatter.shortDateNoTime(workout.completedAt))
                            .font(.caption2)
                            .foregroundStyle(Color.liftMuted)
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                         : AnyLayout(HStackLayout(spacing: 10))) {
                            if let weight = set.weight {
                                Text(MeasurementFormatting.formatDisplayedWeight(
                                    MeasurementFormatting.normalizeToKilograms(weight, unit: set.recordedUnit),
                                    unit: appState.currentProfile.preferredUnit
                                ))
                                    .font(.caption.weight(.bold).monospacedDigit())
                            }
                            if let reps = set.reps {
                                Text("× \(reps) reps")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                            }
                            if let weight = set.weight, let reps = set.reps {
                                Text("\(MeasurementFormatting.formatRecordedVolume(weight * Double(reps), recordedUnit: set.recordedUnit, preferredUnit: appState.currentProfile.preferredUnit)) volume")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.liftScrim)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                Button {
                    selectedCompletedWorkout = workout
                    focusedWorkoutSetID = selectedPoint.id
                } label: {
                    Label(
                        "View workout · \(LiftTimeFormatter.shortDateNoTime(workout.completedAt))",
                        systemImage: "arrow.up.right.square"
                    )
                    .font(LiftTypography.compactEmphasis)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftAccentText)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .accessibilityHint("Opens the workout containing this exercise performance")
            }
        }
    }
}

private struct StrengthExerciseRecords: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exerciseID: String?
    let setPoints: [ExerciseProgressPoint]
    let periodTitle: String
    @Binding var selectedCompletedWorkout: CompletedWorkout?
    @Binding var focusedWorkoutSetID: UUID?

    var body: some View {
        let prs = MeasurementFormatting.bestPRsByReps(from: setPoints)
        let records = exerciseID.map { appState.exerciseRecords(for: $0) }
        let repRangeProgressions = ExerciseProgressSeries.repRangeProgressions(from: setPoints)
        Group {
            if !prs.isEmpty {
                Text("Best sets by rep range · \(periodTitle)")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                    ForEach(prs.prefix(4), id: \.reps) { pr in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(pr.reps)-rep PR")
                                .font(.caption2)
                                .foregroundStyle(Color.liftMuted)
                            Text("\(RankingCalculator.format(pr.weight)) \(pr.unit.shortLabel)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.liftText)
                            let source = setPoints.filter { $0.reps == pr.reps }.max {
                                MeasurementFormatting.normalizeToKilograms($0.weight, unit: $0.unit) < MeasurementFormatting.normalizeToKilograms($1.weight, unit: $1.unit)
                            }
                            recordSource(source?.workoutID)

                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(Color.liftScrim)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }

            if let records,
               let bestSetVolume = records.bestSetVolumeKilograms,
               let bestSessionVolume = records.bestSessionVolumeKilograms {
                (dynamicTypeSize.isAccessibilitySize
                 ? AnyLayout(VStackLayout(spacing: 8))
                 : AnyLayout(HStackLayout(alignment: .top, spacing: 8))) {
                    VStack(alignment: .leading) {
                        ExerciseProgressMetric(
                            title: "Best set volume · all time",
                            value: MeasurementFormatting.formatDisplayedWeight(bestSetVolume, unit: appState.currentProfile.preferredUnit) + " × reps",
                            symbol: "square.stack.3d.up.fill"
                        )
                        recordSource(records.setVolumeWorkoutID)
                    }
                    VStack(alignment: .leading) {
                        ExerciseProgressMetric(
                            title: "Best session volume · all time",
                            value: MeasurementFormatting.formatDisplayedWeight(bestSessionVolume, unit: appState.currentProfile.preferredUnit) + " × reps",
                            symbol: "chart.bar.fill"
                        )
                        recordSource(records.sessionVolumeWorkoutID)
                    }
                }
                .accessibilityElement(children: .contain)
            }

            if !repRangeProgressions.isEmpty {
                Text("Rep-range progression")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 2)
                ForEach(repRangeProgressions.suffix(4).reversed()) { progression in
                    let workout = appState.trainingHistoryWorkouts.first { $0.id == progression.workoutID }
                    Button {
                        if let workout {
                            focusedWorkoutSetID = nil
                            selectedCompletedWorkout = workout
                        }
                    } label: {
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                         : AnyLayout(HStackLayout(alignment: .center, spacing: 12))) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LiftTimeFormatter.shortDateNoTime(progression.date))
                                    .font(LiftTypography.compactEmphasis)
                                    .foregroundStyle(Color.liftText)
                                Text("Target \(progression.targetReps) reps")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                                Text("\(progression.inRangeSetCount)/\(progression.totalSetCount) sets in range")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color.liftMuted)
                                if let bestWeight = progression.bestInRangeWeight {
                                    Text("Best \(RankingCalculator.format(bestWeight)) \(appState.currentProfile.preferredUnit.shortLabel)")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(Color.liftText)
                                }
                            }
                            if !dynamicTypeSize.isAccessibilitySize {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .padding(9)
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                        .background(Color.liftScrim)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(workout == nil)
                    .accessibilityLabel("View workout from \(LiftTimeFormatter.shortDateNoTime(progression.date)), target \(progression.targetReps) reps, \(progression.inRangeSetCount) of \(progression.totalSetCount) sets in range")
                    .accessibilityHint("Opens the workout and its logged sets")
                }
            }
        }
    }
    @ViewBuilder
    private func recordSource(_ workoutID: UUID?) -> some View {
        if let workoutID, let workout = appState.trainingHistoryWorkouts.first(where: { $0.id == workoutID }) {
            Button {
                focusedWorkoutSetID = nil
                selectedCompletedWorkout = workout
            } label: {
                Label("\(workout.completedAt.formatted(date: .abbreviated, time: .omitted)) · View workout", systemImage: "arrow.up.right")
                    .font(.caption2).frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            .buttonStyle(.plain).foregroundStyle(Color.liftAccentText)
        }
    }

}

private struct ExerciseProgressMetric: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(Color.liftAccentText)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.85)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(9)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ProgressExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let options: [TrainingExerciseCatalogItem]
    let selectedID: String?
    var title = "Choose exercise"
    var preferredIDs: Set<String> = []
    var goalIDs: Set<String> = []
    var onCancel: () -> Void = {}
    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filteredOptions: [TrainingExerciseCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return options.sorted {
                if preferredIDs.contains($0.id) != preferredIDs.contains($1.id) { return preferredIDs.contains($0.id) }
                return $0.name < $1.name
            }
        }
        return options.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                $0.equipment.localizedCaseInsensitiveContains(query) ||
                $0.resolvedMuscleProfile.primaryDescription.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredOptions) { exercise in
                Button {
                    onSelect(exercise.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name).foregroundStyle(Color.liftText)
                            Text("\(exercise.equipment) · \(exercise.resolvedMuscleProfile.primaryDescription)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        if goalIDs.contains(exercise.id) {
                            Text("Goal set").font(.caption).foregroundStyle(Color.liftMuted)
                        }
                        if exercise.id == selectedID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.liftAccentText)
                        }
                    }
                }
                .listRowBackground(Color.liftCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.liftBackground)
            .searchable(text: $searchText, prompt: "Search exercises")
            .overlay {
                if filteredOptions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel(); dismiss() } }
            }
        }
    }
}

private struct ExerciseProgressComparison: View {
    @EnvironmentObject private var appState: AppState
    let exercise: TrainingExerciseCatalogItem
    let points: [ExerciseProgressPoint]
    var periodLabel = "last 30 days"

    @ViewBuilder var body: some View {
        let usesRepetitions = [.bodyweightReps, .repsOnly].contains(ExerciseTrackingKind(exercise.trackingType))
        let unit = appState.currentProfile.preferredUnit
        if let latest = points.last {
            let value = usesRepetitions ? "\(latest.reps) reps" : MeasurementFormatting.formatDisplayedWeight(ExerciseProgressSeries.estimatedOneRepMax(latest), unit: unit)
            Text("\(usesRepetitions ? "Best reps" : "Estimated 1RM"): \(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            if points.count > 1, let first = points.first {
                let before = usesRepetitions ? Double(first.reps) : ExerciseProgressSeries.estimatedOneRepMax(first)
                let after = usesRepetitions ? Double(latest.reps) : ExerciseProgressSeries.estimatedOneRepMax(latest)
                let change = (after - before) / before * 100
                Text("\(change == 0 ? "No change" : String(format: "%+.1f%%", change)) since \(first.date.formatted(.dateTime.month(.abbreviated).day())) · \(points.count) training days")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                    .accessibilityIdentifier("tracker.progress.change.\(exercise.id)")
                let values = points.map { usesRepetitions ? Double($0.reps) : MeasurementFormatting.convert(ExerciseProgressSeries.estimatedOneRepMax($0), from: .kilograms, to: unit) }
                let low = values.min() ?? 0
                let high = values.max() ?? 0
                let padding = max(1, (high - low) * 0.15)
                Chart(points) { point in
                    let amount = usesRepetitions ? Double(point.reps) : MeasurementFormatting.convert(ExerciseProgressSeries.estimatedOneRepMax(point), from: .kilograms, to: unit)
                    LineMark(x: .value("Date", point.date), y: .value(usesRepetitions ? "Reps" : "Estimated 1RM", amount))
                    PointMark(x: .value("Date", point.date), y: .value(usesRepetitions ? "Reps" : "Estimated 1RM", amount))
                        .symbolSize(18)
                }
                .foregroundStyle(Color.liftAccentText)
                .chartYScale(domain: max(0, low - padding)...(high + padding))
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .leading, values: low == high ? [low] : [low, high]) }
                .frame(height: 54)
                .accessibilityLabel("\(usesRepetitions ? "Best reps" : "Estimated one-rep max in \(unit.shortLabel)") trend, \(periodLabel)")
                HStack {
                    Text(first.date.formatted(.dateTime.month(.abbreviated).day()))
                    Spacer()
                    Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                }
                .font(.caption2).foregroundStyle(Color.liftMuted)
            } else {
                Text("First entry this period · log another session to compare")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Latest · \(latest.date.formatted(.dateTime.month(.abbreviated).day())): \(progressSetText(latest, usesRepetitions: usesRepetitions))")
                if let previous = points.dropLast().last {
                    Text("Previous · \(previous.date.formatted(.dateTime.month(.abbreviated).day())): \(progressSetText(previous, usesRepetitions: usesRepetitions))")
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .font(.caption.monospacedDigit())
        } else {
            Text("No eligible sets in the \(periodLabel)")
                .font(.subheadline.weight(.semibold))
            Text(usesRepetitions ? "Log working sets to start your trend." : "Log a weighted set of 1–10 reps to estimate strength.")
                .font(.caption).foregroundStyle(Color.liftMuted)
        }
    }
    private func progressSetText(_ point: ExerciseProgressPoint, usesRepetitions: Bool) -> String {
        if usesRepetitions { return "\(point.reps) reps" }
        let unit = appState.currentProfile.preferredUnit
        let weight = MeasurementFormatting.convert(point.weight, from: point.unit, to: unit)
        return "\(MeasurementFormatting.formatRecordedWeight(weight, unit: unit, format: MeasurementFormatting.workoutLoadText)) × \(point.reps)"
    }

}

private struct TrainingRecapView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period = "Month"
    @State private var selectedDate = Date.now
    @State private var showingExport = false
    @State private var exportDocument = WorkoutHistoryCSVDocument(text: "")
    @State private var exportError: String?

    private var component: Calendar.Component {
        switch period { case "Week": .weekOfYear; case "Year": .year; default: .month }
    }
    private var interval: DateInterval? { Calendar.current.dateInterval(of: component, for: selectedDate) }
    private var periodTitle: String {
        if period == "Week", let interval { return dateRange(interval) }
        return selectedDate.formatted(period == "Year" ? .dateTime.year() : .dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Recap period", selection: $period) {
                            Text("Week").tag("Week")
                            Text("Month").tag("Month")
                            Text("Year").tag("Year")
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Button { movePeriod(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                                .accessibilityLabel("Previous period")
                            Spacer()
                            Text(periodTitle).font(LiftTypography.cardTitle)
                            Spacer()
                            Button { movePeriod(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                                .accessibilityLabel("Next period")
                                .disabled(interval.map { $0.end > .now } ?? true)
                        }
                        if let interval {
                            let recap = appState.trainingProgressStore.trainingRecap(in: interval)
                            if recap.workoutCount == 0 {
                                ContentUnavailableView("No workouts recorded", systemImage: "calendar", description: Text("Choose another \(period.lowercased()) to review your training."))
                            } else {
                                summary(recap, interval: interval)
                                exerciseChanges(interval: interval)
                                comparison(recap, interval: interval)
                                mostTrained(recap)
                            }
                        }
                        Button {
                            exportDocument = WorkoutHistoryCSVDocument(text: appState.trainingProgressStore.workoutHistoryCSV())
                            exportError = nil
                            showingExport = true
                        } label: {
                            Label("Export all workout history (CSV)", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 44)
                        }
                        .disabled(appState.completedWorkouts.isEmpty)
                        Text("Includes all dates and saved sets, including warm-ups and unfinished sets.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                        if let exportError { Text(exportError).font(.caption).foregroundStyle(Color.liftRed) }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Training recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
            .fileExporter(isPresented: $showingExport, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "Lift-Rivals-All-Workout-History") { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
            }
        }
    }

    private func summary(_ recap: TrainingRecapSummary, interval: DateInterval) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(interval.end > .now ? "Training so far" : "Training summary").font(LiftTypography.cardTitle)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach([("Workouts", recap.workoutCount), ("Days trained", recap.trainingDayCount), ("Working sets", recap.workingSetCount), ("Exercises", recap.exerciseCount)], id: \.0) { metric in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(metric.1.formatted()).font(.headline.monospacedDigit())
                            Text(metric.0).font(.caption).foregroundStyle(Color.liftMuted)
                        }.accessibilityElement(children: .combine)
                    }
                }
                Text("Days trained counts each date once, even with multiple workouts. Warm-ups and unfinished sets are excluded.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                Divider()
                let unit = appState.currentProfile.preferredUnit
                let volume = MeasurementFormatting.convert(recap.volumeKilograms, from: .kilograms, to: unit)
                LabeledContent("Lifting volume", value: "\(Int(volume.rounded()).formatted()) \(unit.shortLabel)")
                    .font(.subheadline.weight(.semibold))
                Text("Weight × reps, totaled across this period’s working sets. Excludes bodyweight, assisted, and timed exercises.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                DisclosureGroup("More training details") {
                    VStack(spacing: 8) {
                        LabeledContent("Average workout", value: MeasurementFormatting.shortDurationText(recap.averageWorkoutDuration))
                        LabeledContent("Sets per workout", value: recap.averageSetsPerWorkout.formatted(.number.precision(.fractionLength(0...1))))
                        LabeledContent("Training time", value: "\(Int(recap.duration / 3600))h \(Int(recap.duration / 60) % 60)m")
                    }.font(.subheadline).padding(.top, 8)
                }
            }
        }
    }

    private func exerciseChanges(interval: DateInterval) -> some View {
        let trends = appState.trainingProgressStore.recapExerciseTrends(in: interval)
        return LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exercise changes").font(LiftTypography.cardTitle)
                Text("First to latest training day in this \(period.lowercased()). Estimates use working sets of 1–10 reps; bodyweight exercises use best reps. Recovery and deload workouts are excluded.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                if trends.isEmpty {
                    Text("Record eligible sets on two different days for the same exercise to see changes here.")
                        .font(.subheadline)
                }
                ForEach(Array(trends.prefix(3)), id: \.exercise.id) { trend in
                    Text(trend.exercise.name).font(.subheadline.weight(.semibold))
                    ExerciseProgressComparison(exercise: trend.exercise, points: trend.points, periodLabel: "selected \(period.lowercased())")
                    Divider()
                }
                if trends.count > 3 {
                    NavigationLink("View all \(trends.count) exercise trends") {
                        AppBackground {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(periodTitle).font(LiftTypography.cardTitle)
                                    ForEach(trends, id: \.exercise.id) { trend in
                                        Text(trend.exercise.name).font(.headline)
                                        ExerciseProgressComparison(exercise: trend.exercise, points: trend.points, periodLabel: "selected \(period.lowercased())")
                                        Divider()
                                    }
                                }.padding(18)
                            }
                        }.navigationTitle("Exercise changes")
                    }.frame(minHeight: 44)
                }
            }
        }
    }

    @ViewBuilder private func comparison(_ recap: TrainingRecapSummary, interval: DateInterval) -> some View {
        if let previousStart = Calendar.current.date(byAdding: component, value: -1, to: interval.start) {
            let elapsed = min(interval.end, Date.now).timeIntervalSince(interval.start)
            let previousEnd = interval.end <= .now ? interval.start : min(previousStart.addingTimeInterval(max(0, elapsed)), interval.start)
            let previousInterval = DateInterval(start: previousStart, end: previousEnd)
            let previous = appState.trainingProgressStore.trainingRecap(in: previousInterval)
            if previous.workoutCount > 0 {
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Activity comparison").font(LiftTypography.cardTitle)
                        Text("\(dateRange(previousInterval)) → \(dateRange(DateInterval(start: interval.start, end: min(interval.end, .now))))")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                        if interval.end > .now { Text("Same elapsed portion of each period").font(.caption).foregroundStyle(Color.liftMuted) }
                        ForEach([("Workouts", previous.workoutCount, recap.workoutCount), ("Days trained", previous.trainingDayCount, recap.trainingDayCount), ("Working sets", previous.workingSetCount, recap.workingSetCount)], id: \.0) { metric in
                            LabeledContent(metric.0, value: "\(metric.1) → \(metric.2) (\((metric.2 - metric.1).formatted(.number.sign(strategy: .always()))))")
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Text("No recorded workouts in \(dateRange(previousInterval)) to compare.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
        }
    }

    private func mostTrained(_ recap: TrainingRecapSummary) -> some View {
        let names = recap.exerciseSetCounts.keys.sorted {
            let left = recap.exerciseSetCounts[$0, default: 0], right = recap.exerciseSetCounts[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }
        return LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top \(min(5, names.count)) exercises by working sets").font(LiftTypography.cardTitle)
                ForEach(Array(names.prefix(5)), id: \.self) { name in
                    LabeledContent(name, value: "\(recap.exerciseSetCounts[name, default: 0]) sets").font(.subheadline)
                }
                if names.count > 5 {
                    NavigationLink("View all \(names.count) exercises") {
                        List(names, id: \.self) { name in
                            LabeledContent(name, value: "\(recap.exerciseSetCounts[name, default: 0]) sets")
                        }.navigationTitle(periodTitle)
                    }.frame(minHeight: 44)
                }
            }
        }
    }

    private func dateRange(_ interval: DateInterval) -> String {
        let end = max(interval.start, interval.end.addingTimeInterval(-1))
        return "\(interval.start.formatted(.dateTime.month(.abbreviated).day().year())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func movePeriod(_ amount: Int) {
        guard let start = interval?.start, let date = Calendar.current.date(byAdding: component, value: amount, to: start) else { return }
        selectedDate = min(date, .now)
    }
}

private struct WorkoutHistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let value = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = value
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
