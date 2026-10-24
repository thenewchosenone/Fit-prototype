import Charts
import SwiftUI

enum TrackerProgressCategory: String, CaseIterable, Identifiable {
    case consistency = "Consistency"
    case strength = "Strength"
    case muscle = "Muscle"
    case body = "Body"

    var id: String { rawValue }
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

private struct BodyweightChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let actual: Double
    let average: Double
}

extension TrainingTrackerView {
    var progress: some View {
        return LazyVStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress")
                    .font(.title3.weight(.black))
                Spacer()
                if let focus = appState.currentProfile.trainingFocus {
                    Label(focus.title, systemImage: focus.symbol)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }

            progressSyncStatus
            if appState.currentProfile.trainingFocus == nil && !dismissedTrainingFocusPrompt {
                HStack {
                    Button("Choose a training focus in Settings") {
                        appState.router.sheet = .settings(.training)
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    Spacer()
                    NativeIconButton(symbolName: "xmark", accessibilityLabel: "Dismiss training focus suggestion") {
                        dismissedTrainingFocusPrompt = true
                    }
                }
            }

            Picker("Progress category", selection: $selectedProgressCategory) {
                ForEach(TrackerProgressCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tracker.progress.category")

            if selectedProgressCategory == .strength {
                trainingAttentionSection
            }

            if selectedProgressCategory == .consistency {
                let weekCompletion = selectedWeek.map(appState.weekCompletion(for:))
                let historyPresentation = appState.workoutHistoryPresentation(
                    displayedMonth: workoutHistoryMonth,
                    selectedDate: selectedWorkoutHistoryDate
                )
                progressOverviewCard
                activityHeatmapSection
                programConsistencySection(weekCompletion: weekCompletion)
                muscleProgressLinkSection

                if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                    strainAndInjurySection
                }

                workoutHistorySection(presentation: historyPresentation)
            }

            if selectedProgressCategory == .strength {
                let exerciseOptions = appState.progressExerciseOptions()
                strengthProgressSection

                if !exerciseOptions.isEmpty {
                    exerciseProgressSection(options: exerciseOptions)
                }
            }

            if selectedProgressCategory == .body {
                bodyProgressSection
            }

            if selectedProgressCategory == .muscle {
                muscleProgress
            }
        }
        .onAppear {
            if !didLoadTrainingFocus {
                loadTrainingFocus()
                didLoadTrainingFocus = true
            }
            if selectedProgressCategory == .strength { syncProgressExerciseSelection() }
            if selectedProgressCategory == .consistency { syncWorkoutHistorySelection() }
            Task { await appState.synchronizeCompletedWorkoutHistory(force: false) }
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            if selectedProgressCategory == .strength { syncProgressExerciseSelection() }
            if selectedProgressCategory == .consistency { syncWorkoutHistorySelection() }
        }
        .onChange(of: selectedProgressCategory) { _, category in
            if category == .strength { syncProgressExerciseSelection() }
            if category == .consistency { syncWorkoutHistorySelection() }
        }
        .onChange(of: appState.currentProfile.id) {
            loadTrainingFocus()
        }
        .onChange(of: appState.currentProfile.trainingFocus) {
            loadTrainingFocus()
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
                    ("Analytics use device-saved history", "\(pendingCount) workout\(pendingCount == 1 ? "" : "s") safe locally; sync when a connection is available.", "iphone.and.arrow.forward", .orange)
                case .syncing:
                    ("Refreshing workout history", "Keep this screen open while Progress updates.", "arrow.triangle.2.circlepath", .liftAccentText)
                case .stale:
                    ("Analytics may be stale", "Refresh to make Progress metrics current.", "clock.arrow.circlepath", .orange)
                case .needsAttention:
                    ("Analytics may be incomplete", "Workout history could not refresh. Retry to update Progress.", "exclamationmark.triangle.fill", .orange)
                case .synced:
                    ("", "", "", .clear)
                }
                let canRetry = state == .local || state == .stale || state == .needsAttention
                let content = HStack(spacing: 10) {
                    Image(systemName: copy.2)
                        .foregroundStyle(copy.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.0)
                            .font(.subheadline.weight(.bold))
                        Text(copy.1)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer(minLength: 4)
                    if canRetry {
                        Text("Retry")
                            .font(.caption.weight(.bold))
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

    private var progressOverviewCard: some View {
        let summary = appState.homeWeeklySummary()
        let workouts = appState.completedWorkouts
        let month = Calendar.current.dateComponents([.year, .month], from: .now)
        let thisMonthCount = workouts.filter {
            let components = Calendar.current.dateComponents([.year, .month], from: $0.completedAt)
            return components.year == month.year && components.month == month.month
        }.count
        let weekStreak = weeklyWorkoutStreak(workouts: workouts)
        let priorWeeks = (1...4).map { offset in
            appState.homeWeeklySummary(
                referenceDate: Calendar.current.date(byAdding: .day, value: -7 * offset, to: .now) ?? .now
            )
        }
        let baselineVolume = appState.trainingProgressStore.hasFourFullWeeksOfHistory()
            ? priorWeeks.map(\.volume).reduce(0, +) / Double(priorWeeks.count)
            : 0
        let recovery = appState.recoverySummaries().filter { $0.hoursSinceTraining < 48 }.count
        let trend = priorWeeks.reversed().map(\.volume) + [summary.volume]
        let peakVolume = max(1, trend.max() ?? 1)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftAccentText)
                    Text(summary.completedWorkoutCount == 0
                         ? "Log a workout to start your weekly snapshot."
                         : "Your training at a glance")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 8)
                if recovery > 0 {
                    Label("\(recovery) recently trained", systemImage: "clock")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftGold)
                }
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(summary.completedWorkoutCount)")
                        .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.liftAccentText)
                    Text("workout\(summary.completedWorkoutCount == 1 ? "" : "s") completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(Array(trend.enumerated()), id: \.offset) { index, value in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(index == trend.count - 1 ? Color.liftAccentText : Color.liftAccentText.opacity(0.3))
                                .frame(width: 12, height: max(4, CGFloat(value / peakVolume) * 42))
                        }
                    }
                    .frame(height: 42, alignment: .bottom)
                    Text("5-WEEK VOLUME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            HStack(spacing: 10) {
                progressOverviewMetric("WORKING SETS", value: "\(summary.completedSetCount)", symbol: "checkmark.circle.fill")
                progressOverviewMetric(
                    "VOLUME LOAD",
                    value: MeasurementFormatting.formatRecordedWeight(
                        summary.volume,
                        unit: appState.currentProfile.preferredUnit,
                        format: { Int($0.rounded()).formatted() }
                    ),
                    symbol: "scalemass.fill"
                )
            }
            HStack(spacing: 10) {
                progressOverviewMetric("THIS MONTH", value: "\(thisMonthCount)", symbol: "calendar")
                progressOverviewMetric("ALL WORKOUTS", value: "\(workouts.count)", symbol: "dumbbell.fill")
                progressOverviewMetric("WEEK STREAK", value: "\(weekStreak)", symbol: "flame.fill")
            }
            if summary.completedWorkoutCount > 0 || baselineVolume > 0 {
                Text(progressBaselineText(summary: summary, baselineVolume: baselineVolume))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(18)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func weeklyWorkoutStreak(workouts: [CompletedWorkout], now: Date = .now) -> Int {
        let calendar = Calendar.current
        let dates = Set(workouts.map { calendar.startOfDay(for: $0.completedAt) })
        var streak = 0
        for offset in 0..<53 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: now),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { break }
            if dates.contains(where: interval.contains) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var activityHeatmapSection: some View {
        WorkoutActivityHeatmap(
            workouts: appState.completedWorkouts,
            period: $activityHeatmapPeriod,
            measure: $activityHeatmapMeasure,
            unit: appState.currentProfile.preferredUnit
        )
    }

    private var bodyProgressSection: some View {
        let entries = appState.bodyweightEntries
            .filter { ($0.actual ?? 0) > 0 }
            .sorted { $0.targetDate < $1.targetDate }
        let dayLimit = ["1M": 30, "3M": 90, "1Y": 365][selectedBodyProgressPeriod]
        let cutoff = dayLimit.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) } ?? .distantPast
        let history = entries.filter { $0.targetDate >= cutoff }
        let unit = appState.currentProfile.preferredUnit
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bodyweight trend")
                        .font(.headline.weight(.bold))
                    if let latest = history.last, let value = latest.actual {
                        Text(MeasurementFormatting.formatBodyweight(value, preferredUnit: unit))
                            .font(.title2.weight(.semibold).monospacedDigit())
                    } else {
                        Text("Log bodyweight to start tracking your trend.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Spacer()
                Button(action: logBodyweightEntry) {
                    Label("Log", systemImage: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftOnAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.liftBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log bodyweight")
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
                        PointMark(
                            x: .value("Date", entry.targetDate),
                            y: .value("Bodyweight", MeasurementFormatting.convert(value, from: .pounds, to: unit))
                        )
                        .foregroundStyle(Color.liftGreen)
                    }
                }
                .chartYAxisLabel(unit.shortLabel, position: .trailing)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(Color.liftMuted) } }
                .frame(height: 180)
            } else {
                Text("Add another weigh-in in this period to see a trend.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            bodyweightTable(entries: history)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private func progressBaselineText(summary: HomeWeeklySummary, baselineVolume: Double) -> String {
        guard appState.trainingProgressStore.hasFourFullWeeksOfHistory() else {
            return "Building your baseline. Comparisons begin after four full weeks of logging."
        }
        if summary.completedWorkoutCount == 0 {
            guard baselineVolume > 0 else { return "Log a workout to start your weekly snapshot." }
            return "No completed workouts this week. Log one to compare against your prior four-week average."
        }
        guard baselineVolume > 0 else { return "No volume load logged in the prior four weeks to compare." }
        let difference = summary.volume - baselineVolume
        let percentage = Int((abs(difference) / baselineVolume * 100).rounded())
        if percentage == 0 { return "Volume is in line with your prior four-week average." }
        return "Volume is \(percentage)% \(difference > 0 ? "above" : "below") your prior four-week average."
    }

    private func progressOverviewMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var trainingAttentionSection: some View {
        let insights = appState.strengthAttentionInsights
        let nextWorkout = appState.scheduledPlanSessions(on: .now).first
            ?? appState.nextScheduledWorkout().map { (week: $0.week, session: $0.session) }
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .foregroundStyle(Color.liftAccentText)
                    Text("What needs attention")
                        .font(.headline.weight(.bold))
                }
                Text("Signals from your logged lifts, with a step to consider next.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)

                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(insight.title)
                            .font(.subheadline.weight(.bold))
                        Text(insight.evidence)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Label(insight.nextStep, systemImage: "arrow.turn.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.liftCardRaised.opacity(0.62))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                Button {
                    if let nextWorkout { selectedWeekID = nextWorkout.week.id }
                    withAnimation(.snappy) { segment = .plans }
                } label: {
                    HStack {
                        Text(nextWorkout.map { "Next planned: \($0.session.name)" } ?? "Review your workout plan")
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.liftOverlay, lineWidth: 1)
            }
        }
    }

    private func programConsistencySection(weekCompletion: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let week = selectedWeek {
                let completion = weekCompletion ?? 0
                let presentation = appState.programWeekPresentation(for: week)
                let weekTitle = week.title.hasPrefix("Week \(week.weekNumber)")
                    ? week.title
                    : "Week \(week.weekNumber) · \(week.title)"
                HStack(alignment: .center) {
                    ZStack {
                        Circle()
                            .stroke(Color.liftOverlay, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(max(completion, 0), 1))
                            .stroke(Color.liftGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(completion * 100))%")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Program consistency")
                            .font(.subheadline.weight(.bold))
                        Text(weekTitle)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Program consistency, \(Int(completion * 100)) percent complete")

                HStack(spacing: 0) {
                    consistencyMetric(
                        "Sessions",
                        value: "\(presentation.completedSessionCount)/\(presentation.sessions.count)",
                        symbol: "calendar"
                    )
                    consistencyMetricDivider
                    consistencyMetric(
                        "Exercises",
                        value: "\(presentation.completedPrescriptionCount)/\(presentation.plannedPrescriptionCount)",
                        symbol: "list.bullet"
                    )
                    consistencyMetricDivider
                    consistencyMetric(
                        "Sets",
                        value: "\(presentation.completedSetCount)/\(presentation.plannedSetCount)",
                        symbol: "checkmark.circle"
                    )
                }

                let statusCounts = programSessionStatusCounts(week: week, presentation: presentation)
                let visibleStatuses = statusCounts.filter { $0.count > 0 }
                if !visibleStatuses.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(visibleStatuses, id: \.label) { status in
                                Label("\(status.count) \(status.label)", systemImage: status.symbol)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(status.color)
                                    .padding(.horizontal, 8)
                                    .frame(height: 28)
                                    .background(status.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(visibleStatuses.map { "\($0.label) \($0.count)" }.joined(separator: ", "))
                }

                if let rir = presentation.rirSummary {
                    Label(
                        "Target RIR \(RankingCalculator.format(rir.target)) · estimated RIR \(RankingCalculator.format(rir.estimated)) · \(rir.setCount) sets",
                        systemImage: "scope"
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.liftMuted)
                }
            } else {
                Text("Program consistency")
                    .font(.subheadline.weight(.bold))
                Text("Choose a workout program to compare planned and completed sessions.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Button("Browse workout programs") {
                    isProgramLibraryExpanded = true
                    withAnimation(.snappy) { segment = .plans }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftGreen)
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

    private func programSessionStatusCounts(week: WorkoutWeek, presentation: ProgramWeekPresentation) -> [(label: String, count: Int, symbol: String, color: Color)] {
        var completed = 0
        var backfilled = 0
        var shortened = 0
        var inProgress = 0
        var missed = 0
        var skipped = 0
        var rest = 0
        var upcoming = 0

        for session in presentation.sessions {
            let prescriptions = presentation.prescriptionsBySessionID[session.id] ?? []
            guard !prescriptions.isEmpty else { continue }
            if session.outcome == .skipped {
                skipped += 1
                continue
            }
            if session.outcome == .rest {
                rest += 1
                continue
            }
            let completedCount = prescriptions.filter { presentation.completedPrescriptionIDs.contains($0.id) }.count
            let savedWorkout = appState.completedWorkouts.first { workout in
                workout.sourceSessionID == session.id && workout.sourcePlanID == appState.selectedWorkoutPlanID
            }
            if presentation.completedSessionIDs.contains(session.id) {
                let scheduled = scheduledDate(for: week, session: session)
                if let scheduled, let savedWorkout,
                   !Calendar.current.isDate(savedWorkout.completedAt, inSameDayAs: scheduled) {
                    backfilled += 1
                } else {
                    completed += 1
                }
            } else if let savedWorkout, !savedWorkout.completedWorkingSets.isEmpty {
                shortened += 1
            } else if completedCount > 0 {
                inProgress += 1
            } else if let date = scheduledDate(for: week, session: session), date < Calendar.current.startOfDay(for: .now) {
                missed += 1
            } else {
                upcoming += 1
            }
        }

        return [
            ("Completed", completed, "checkmark.circle.fill", Color.liftGreen),
            ("Different day", backfilled, "arrow.uturn.backward.circle.fill", Color.liftBlue),
            ("Shortened", shortened, "minus.circle.fill", Color.liftGold),
            ("In progress", inProgress, "circle.lefthalf.filled", Color.liftBlue),
            ("Missed", missed, "exclamationmark.circle.fill", Color.liftGold),
            ("Skipped", skipped, "forward.end.circle.fill", Color.liftGold),
            ("Rest", rest, "bed.double.fill", Color.liftBlue),
            ("Upcoming", upcoming, "clock.fill", Color.liftMuted)
        ]
    }

    private func scheduledDate(for week: WorkoutWeek, session: WorkoutSession) -> Date? {
        let calendar = Calendar.current
        let cycleStart: Date
        if let settings = selectedProgramSettings {
            guard let start = calendar.date(
                byAdding: .weekOfYear,
                value: week.weekNumber - 1,
                to: calendar.startOfDay(for: settings.startedAt)
            ) else { return nil }
            cycleStart = start
        } else {
            guard week.id == appState.currentSelectedProgramWeek?.id,
                  let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return nil }
            cycleStart = start
        }

        guard let weekdayIndex = calendar.weekdaySymbols.firstIndex(where: {
            $0.caseInsensitiveCompare(session.day) == .orderedSame
        }) else { return nil }
        let targetWeekday = weekdayIndex + 1
        let cycleWeekday = calendar.component(.weekday, from: cycleStart)
        let dayOffset = (targetWeekday - cycleWeekday + 7) % 7
        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) else { return nil }
        if let settings = selectedProgramSettings,
           date < calendar.startOfDay(for: settings.startedAt) {
            return nil
        }
        return date
    }

    private func consistencyMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 9)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var consistencyMetricDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 28)
    }

    private var muscleProgressLinkSection: some View {
        Button {
            withAnimation(.snappy) { selectedProgressCategory = .muscle }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Color.liftAccentText)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muscle workload")
                        .font(.subheadline.weight(.bold))
                    Text("See trained muscles, weekly sets, and workload trends.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(14)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var strengthProgressSection: some View {
        let summary = appState.strengthTierSummary
        let keyLifts = ["bench", "squat", "deadlift"].compactMap { exerciseID in
            summary.liftProgress.first { $0.exerciseID == exerciseID }
        }
        let completeMaxes = keyLifts.compactMap(\.estimatedOneRepMaxKilograms)
        let highestMax = max(1, completeMaxes.max() ?? 1)
        let threeLiftTotal = completeMaxes.count == 3 ? completeMaxes.reduce(0, +) : nil
        let latestBodyweight = recentBodyweightEntries.last?.actual ?? appState.currentProfile.bodyweightPounds
        let bodyweightKilograms = MeasurementFormatting.normalizeToKilograms(latestBodyweight, unit: .pounds)
        let relativeTotal = threeLiftTotal.flatMap { bodyweightKilograms > 0 ? $0 / bodyweightKilograms : nil }
        let supplementalLifts = progressExerciseOptions
            .filter { !["bench", "squat", "deadlift"].contains($0.rankingExerciseID ?? $0.id) }
            .filter { appState.exerciseRecords(for: $0.id).bestEstimatedOneRepMaxKilograms != nil }
            .sorted {
                (appState.exerciseRecords(for: $0.id).bestEstimatedOneRepMaxKilograms ?? 0)
                    > (appState.exerciseRecords(for: $1.id).bestEstimatedOneRepMaxKilograms ?? 0)
            }
            .prefix(3)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Strength")
                    .font(.headline.weight(.bold))
                Text("Estimated 1RM from completed working sets · Epley, up to 10 reps")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }

            if keyLifts.isEmpty {
                LiftEmptyState(
                    title: "No strength data yet",
                    message: "Complete a working set for bench press, squat, or deadlift to start your strength profile.",
                    symbolName: "figure.strengthtraining.traditional",
                    actionTitle: "Start a workout",
                    action: { withAnimation(.snappy) { segment = .today } },
                    compact: true
                )
            } else {
                let strengthColumns = Array(
                    repeating: GridItem(.flexible(), alignment: .leading),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                )
                LazyVGrid(columns: strengthColumns, alignment: .leading, spacing: 8) {
                    ForEach(keyLifts, id: \.exerciseID) { lift in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lift.exerciseName.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(lift.estimatedOneRepMaxKilograms.map {
                                MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                            } ?? "—")
                                .font(.headline.weight(.black).monospacedDigit())
                                .fixedSize(horizontal: false, vertical: true)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.liftOverlay)
                                    Capsule().fill(Color.liftAccentText)
                                        .frame(width: geometry.size.width * CGFloat((lift.estimatedOneRepMaxKilograms ?? 0) / highestMax))
                                }
                            }
                            .frame(height: 5)
                            Text(lift.estimatedOneRepMaxKilograms == nil ? "No data" : lift.currentTier.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .padding(10)
                        .background(Color.liftCardRaised.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                let totalColumns = Array(
                    repeating: GridItem(.flexible(), alignment: .leading),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                )
                LazyVGrid(columns: totalColumns, alignment: .leading, spacing: 10) {
                    volumeSummary(
                        title: "THREE-LIFT TOTAL",
                        value: threeLiftTotal.map {
                            MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                        } ?? "—",
                        detail: threeLiftTotal == nil ? "Log all three lifts" : "",
                        symbol: "sum"
                    )
                    volumeSummary(
                        title: "RELATIVE TOTAL",
                        value: relativeTotal.map {
                            MeasurementFormatting.localizedDecimalText($0, minimumFractionDigits: 2, maximumFractionDigits: 2) + "×"
                        } ?? "—",
                        detail: relativeTotal == nil ? "Needs total and bodyweight" : "of bodyweight",
                        symbol: "scalemass"
                    )
                }

                if !supplementalLifts.isEmpty {
                    Text("Other tracked lifts")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                    let supplementalColumns = Array(
                        repeating: GridItem(.flexible(), alignment: .leading),
                        count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                    )
                    LazyVGrid(columns: supplementalColumns, alignment: .leading, spacing: 8) {
                        ForEach(supplementalLifts, id: \.id) { lift in
                            let record = appState.exerciseRecords(for: lift.id)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lift.name)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(record.bestEstimatedOneRepMaxKilograms.map {
                                    MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                                } ?? "—")
                                    .font(.subheadline.weight(.black).monospacedDigit())
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.liftCardRaised.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .accessibilityElement(children: .contain)
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

    private func volumeSummary(
        title: String,
        value: String,
        detail: String,
        symbol: String
    ) -> some View {
        let label = title == "RELATIVE TOTAL" && value != "—"
            ? "Relative total, \(value.replacingOccurrences(of: "×", with: " times bodyweight"))"
            : [title.capitalized, value, detail].filter { !$0.isEmpty }.joined(separator: ", ")

        return HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
                .frame(width: 30, height: 30)
                .background(Color.liftBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title == "THREE-LIFT TOTAL" ? "3-LIFT TOTAL" : title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                Text(value)
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.liftOverlay.opacity(0.75), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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

    private func exerciseProgressSection(
        options: [TrainingExerciseCatalogItem]
    ) -> some View {
        let exerciseID = selectedProgressExerciseID ?? options.first?.id
        let exercise = options.first { $0.id == exerciseID }
        let setPoints = exercise.map { appState.exerciseProgressPoints(for: $0.id) } ?? []
        let chartPoints = ExerciseProgressSeries.dailyHighest(from: setPoints)
        let recordedSessionCount = Set(setPoints.compactMap(\.workoutID)).count
        let estimatedMaxPoints = ExerciseProgressSeries.dailyHighestEstimatedOneRepMax(from: setPoints)
        let repRangeProgressions = ExerciseProgressSeries.repRangeProgressions(from: setPoints)
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
        let prs = MeasurementFormatting.bestPRsByReps(from: setPoints)
        let records = exercise.map { appState.exerciseRecords(for: $0.id) }
        let startingEstimatedMax = estimatedMaxPoints.first.map(ExerciseProgressSeries.estimatedOneRepMax)
        let bestEstimatedMax = estimatedMaxPoints.map(ExerciseProgressSeries.estimatedOneRepMax).max()
        let strengthIncrease = startingEstimatedMax.flatMap { start in
            bestEstimatedMax.map { $0 - start }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let exercise {
                    ExerciseCatalogIcon(exercise: exercise)
                        .frame(width: 42, height: 42)
                }
            Text("Exercise progress")
                .font(.subheadline.weight(.bold))
                Spacer()
                Menu {
                    ForEach(options) { option in
                        Button(option.name) {
                            selectedProgressExerciseID = option.id
                            selectedExerciseWeightTrendDate = nil
                            selectedExerciseStrengthTrendDate = nil
                        }
                    }
                } label: {
                    Label(exercise?.name ?? "Exercise", systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tracker.progress.exercisePicker")
            }

            if chartPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete sets for this exercise to build its trend.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        withAnimation(.snappy) { segment = .today }
                    } label: {
                        Label("Log this exercise", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .buttonStyle(.plain)
                }
            } else if recordedSessionCount < 3 {
                if let bestPoint = chartPoints.max(by: {
                    MeasurementFormatting.normalizeToKilograms($0.weight, unit: $0.unit) <
                        MeasurementFormatting.normalizeToKilograms($1.weight, unit: $1.unit)
                }) {
                    progressMetric(
                        title: "BEST LOGGED SET",
                        value: "\(MeasurementFormatting.formatDisplayedWeight(MeasurementFormatting.normalizeToKilograms(bestPoint.weight, unit: bestPoint.unit), unit: appState.currentProfile.preferredUnit)) × \(bestPoint.reps)",
                        symbol: "dumbbell.fill"
                    )
                }
                Text("Log this exercise in at least 3 workouts to see meaningful weight and estimated 1RM trends.\n\(recordedSessionCount) of 3 workouts logged.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            } else {
                if let startingEstimatedMax, let bestEstimatedMax, let strengthIncrease {
                    HStack(spacing: 10) {
                        progressMetric(
                            title: "STARTING EST. 1RM",
                            value: MeasurementFormatting.formatDisplayedWeight(startingEstimatedMax, unit: appState.currentProfile.preferredUnit),
                            symbol: "flag.fill"
                        )
                        progressMetric(
                            title: "BEST EST. 1RM",
                            value: MeasurementFormatting.formatDisplayedWeight(bestEstimatedMax, unit: appState.currentProfile.preferredUnit),
                            symbol: "arrow.up.right"
                        )
                        progressMetric(
                            title: "INCREASE",
                            value: (strengthIncrease >= 0 ? "+" : "") + MeasurementFormatting.formatDisplayedWeight(strengthIncrease, unit: appState.currentProfile.preferredUnit),
                            symbol: "chart.line.uptrend.xyaxis"
                        )
                    }

                    Text("Estimated 1RM trend")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 2)

                    Chart(estimatedMaxPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Estimated 1RM", ExerciseProgressSeries.estimatedOneRepMax(point))
                        )
                        .foregroundStyle(Color.liftAccentText)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Estimated 1RM", ExerciseProgressSeries.estimatedOneRepMax(point))
                        )
                        .foregroundStyle(Color.liftGreen)
                    }
                    .frame(height: 150)
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .chartXSelection(value: $selectedExerciseStrengthTrendDate)
                    .onChange(of: selectedExerciseStrengthTrendDate) { _, selection in
                        if selection != nil { selectedExerciseWeightTrendDate = nil }
                    }
                }

                Text("Weight trend")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 2)
                Text(chartPoints.count == 1
                    ? "One workout logged; record this exercise again to compare sessions."
                    : "Tap a chart point to open its workout.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)

                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftAccentText)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftGreen)
                }
                .frame(height: 150)
                .chartYAxis { AxisMarks(position: .trailing) }
                .chartXSelection(value: $selectedExerciseWeightTrendDate)
                .onChange(of: selectedExerciseWeightTrendDate) { _, selection in
                    if selection != nil { selectedExerciseStrengthTrendDate = nil }
                }

                if let selectedPoint = selectedWeightTrendPoint ?? selectedStrengthTrendPoint,
                   let workoutID = selectedPoint.workoutID,
                   let workout = appState.trainingHistoryWorkouts.first(where: { $0.id == workoutID }) {
                    if let set = workout.sets.first(where: { $0.id == selectedPoint.id }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected performance")
                                .font(.caption.weight(.bold))
                            Text(LiftTimeFormatter.shortDateNoTime(workout.completedAt))
                                .font(.caption2)
                                .foregroundStyle(Color.liftMuted)
                            HStack(spacing: 10) {
                                if let weight = set.weight {
                                    Text(MeasurementFormatting.formatRecordedWeight(weight, unit: set.recordedUnit))
                                        .font(.caption.weight(.black).monospacedDigit())
                                }
                                if let reps = set.reps {
                                    Text("× \(reps) reps")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                }
                                if let weight = set.weight, let reps = set.reps {
                                    Text("· \(MeasurementFormatting.formatRecordedVolume(weight * Double(reps), recordedUnit: set.recordedUnit, preferredUnit: appState.currentProfile.preferredUnit)) volume")
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
                        .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.liftAccentText)
                    .accessibilityHint("Opens the workout containing this exercise performance")
                }

                if !prs.isEmpty {
                    Text("Personal records by rep range")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 2)
                    HStack(spacing: 8) {
                        ForEach(prs.prefix(4), id: \.reps) { pr in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(pr.reps)-rep PR")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                                Text("\(RankingCalculator.format(pr.weight)) \(pr.unit.shortLabel)")
                                    .font(.caption.weight(.black).monospacedDigit())
                                    .foregroundStyle(Color.liftText)
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
                    HStack(spacing: 8) {
                        progressMetric(
                            title: "BEST SET VOLUME",
                            value: MeasurementFormatting.formatDisplayedWeight(bestSetVolume, unit: appState.currentProfile.preferredUnit),
                            symbol: "square.stack.3d.up.fill"
                        )
                        progressMetric(
                            title: "BEST SESSION VOLUME",
                            value: MeasurementFormatting.formatDisplayedWeight(bestSessionVolume, unit: appState.currentProfile.preferredUnit),
                            symbol: "chart.bar.fill"
                        )
                    }
                    .accessibilityElement(children: .contain)
                }

                if !repRangeProgressions.isEmpty {
                    Text("Rep-range progression")
                        .font(.caption.weight(.bold))
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
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(LiftTimeFormatter.shortDateNoTime(progression.date))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                    Text("Target \(progression.targetReps) reps")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(progression.inRangeSetCount)/\(progression.totalSetCount) sets in range")
                                        .font(.caption2.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(Color.liftMuted)
                                    if let bestWeight = progression.bestInRangeWeight {
                                        Text("Best \(RankingCalculator.format(bestWeight)) \(appState.currentProfile.preferredUnit.shortLabel)")
                                            .font(.caption.weight(.black).monospacedDigit())
                                            .foregroundStyle(Color.liftText)
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(9)
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
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private func progressMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.caption.weight(.black).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(9)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var strainAndInjurySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Strain & injuries")
                .font(.headline.weight(.bold))

            if let latestStrain = appState.latestStrainEntry {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftAccentText)
                        .frame(width: 30, height: 30)
                        .background(Color.liftBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest strain: \(latestStrain.strain)/10")
                            .font(.subheadline.weight(.bold))
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
                                .font(.caption.weight(.black).monospacedDigit())
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
                                .font(.caption.weight(.bold))
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
        let options = progressExerciseOptions
        let optionIDs = Set(options.map(\.id))
        guard let selectedProgressExerciseID else {
            self.selectedProgressExerciseID = options.first?.id
            return
        }
        if !optionIDs.contains(selectedProgressExerciseID) {
            self.selectedProgressExerciseID = options.first?.id
        }
    }

    private func bodyweightChart(entries: [BodyweightEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let actualEntries = entries
                .filter { $0.actual != nil }
                .sorted { $0.targetDate < $1.targetDate }
            let chartPoints = actualEntries
                .enumerated()
                .map { index, entry in
                    let actual = entry.actual ?? 0
                    let start = max(0, index - 2)
                    let window = actualEntries[start...index].compactMap(\.actual)
                    return BodyweightChartPoint(
                        id: entry.id,
                        date: entry.targetDate,
                        actual: actual,
                        average: window.reduce(0, +) / Double(window.count)
                    )
                }
            if !chartPoints.isEmpty {
                Chart(chartPoints) { point in
                    let actual = MeasurementFormatting.displayBodyweightValue(
                        point.actual,
                        preferredUnit: appState.currentProfile.preferredUnit
                    )
                    let average = MeasurementFormatting.displayBodyweightValue(
                        point.average,
                        preferredUnit: appState.currentProfile.preferredUnit
                    )
                    LineMark(x: .value("Date", point.date), y: .value("Bodyweight", actual))
                        .foregroundStyle(Color.liftAccentText)
                    PointMark(x: .value("Date", point.date), y: .value("Bodyweight", actual))
                        .foregroundStyle(Color.liftGreen)
                    LineMark(x: .value("Date", point.date), y: .value("3-entry average", average))
                        .foregroundStyle(Color.liftMuted)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .trailing) {
                        AxisGridLine().foregroundStyle(Color.liftSeparator)
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.liftMuted)
                    }
                }
                if chartPoints.count == 1 {
                    Text("One entry logged; add another bodyweight check-in to compare your trend.")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
                HStack(spacing: 14) {
                    Label("Logged", systemImage: "circle.fill")
                        .foregroundStyle(Color.liftAccentText)
                    Label("3-entry average", systemImage: "minus")
                        .foregroundStyle(Color.liftMuted)
                }
                .font(.caption2.weight(.semibold))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "scalemass.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Color.liftAccentText)
                    Text("No bodyweight logged yet")
                        .font(.headline.weight(.bold))
                    Text("Add today’s bodyweight to start seeing your trend here.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Button {
                        logBodyweightEntry()
                    } label: {
                        Text("Log bodyweight")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Color.liftOnAccent)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Color.liftBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            }
        }
    }

    private func bodyweightTable(entries: [BodyweightEntry]) -> some View {
        let usesAccessibilityLayout = dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: 0) {
            if !usesAccessibilityLayout {
                HStack {
                    Text("Week").frame(width: 48, alignment: .leading)
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Weight").frame(width: 76, alignment: .trailing)
                    Text("").frame(width: 28)
                }
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.liftMuted)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.liftCardRaised.opacity(0.7))
            }

            if entries.isEmpty {
                Group {
                    if usesAccessibilityLayout {
                        Text("Log bodyweight to fill this table")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: 8) {
                            Text("--").frame(width: 48, alignment: .leading)
                            Text("Log bodyweight to fill this table")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("--").frame(width: 76, alignment: .trailing)
                            Image(systemName: "minus")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.clear)
                                .frame(width: 28)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .padding(.horizontal, 12)
                .frame(minHeight: 52)
            } else {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, row in
                    let formattedBodyweight = MeasurementFormatting.formatBodyweightOrDash(
                        row.actual,
                        preferredUnit: appState.currentProfile.preferredUnit
                    )

                    Button {
                        selectedBodyweightEntry = row
                    } label: {
                        Group {
                            if usesAccessibilityLayout {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Week \(row.week)")
                                        Spacer()
                                        Text(formattedBodyweight)
                                            .font(.subheadline.weight(.semibold).monospacedDigit())
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    Text(row.targetDate, style: .date)
                                    if !row.notes.isEmpty {
                                        Text("Has notes")
                                            .font(.caption2)
                                            .foregroundStyle(Color.liftAccentText)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack(spacing: 8) {
                                    Text("\(row.week)")
                                        .frame(width: 48, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.targetDate, style: .date)
                                            .lineLimit(1)
                                        if !row.notes.isEmpty {
                                            Text("Has notes")
                                                .font(.caption2)
                                                .foregroundStyle(Color.liftAccentText)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(formattedBodyweight)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .frame(width: 76, alignment: .trailing)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                        .frame(width: 28)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.liftText)
                        .padding(.horizontal, 12)
                        .frame(minHeight: usesAccessibilityLayout ? 76 : 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Week \(row.week), \(LiftTimeFormatter.shortDateNoTime(row.targetDate)), \(formattedBodyweight), edit")

                    if index < entries.count - 1 {
                        Divider()
                            .overlay(Color.liftOverlay)
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private var recentBodyweightEntries: [BodyweightEntry] {
        return appState.bodyweightEntries
            .sorted { $0.targetDate < $1.targetDate }
            .map { $0 }
    }

    private var selectedBodyweightEntries: [BodyweightEntry] {
        let startDate = selectedProgressRange.startDate()
        return recentBodyweightEntries.filter { $0.targetDate >= startDate }
    }

    private func logBodyweightEntry() {
        selectedBodyweightEntry = BodyweightEntry.draftForCurrentWeek(
            entries: appState.bodyweightEntries,
            currentBodyweightPounds: appState.currentProfile.bodyweightPounds
        )
    }

    private var recentStrainEntries: [StrainEntry] {
        appState.strainEntries
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(5)
            .map { $0 }
    }
}
