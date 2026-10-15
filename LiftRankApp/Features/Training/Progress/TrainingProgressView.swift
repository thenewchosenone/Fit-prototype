import Charts
import SwiftUI

enum TrackerProgressCategory: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case muscle = "Muscle"
    case consistency = "Consistency"

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
            progressSyncStatus
            Picker("Progress category", selection: $selectedProgressCategory) {
                ForEach(TrackerProgressCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tracker.progress.category")

            if appState.currentProfile.trainingFocus == nil && !dismissedTrainingFocusPrompt {
                HStack(spacing: 8) {
                    Button("Set training focus") {
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

            if selectedProgressCategory == .consistency {
                let weekCompletion = selectedWeek.map(appState.weekCompletion(for:))
                let historyPresentation = appState.workoutHistoryPresentation(
                    displayedMonth: workoutHistoryMonth,
                    selectedDate: selectedWorkoutHistoryDate
                )
                progressOverviewCard
                WeeklyTrainingDayGoalCard(summary: appState.homeWeeklySummary())
                programConsistencySection(weekCompletion: weekCompletion)
                recoveryInsightSection

                if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                    strainAndInjurySection
                }

                workoutHistorySection(presentation: historyPresentation)
            }

            if selectedProgressCategory == .strength {
                let exerciseOptions = appState.progressExerciseOptions()
                let bodyweightEntries = selectedBodyweightEntries
                let bodyweightReadings = bodyweightEntries
                    .compactMap { entry in entry.actual.map { (date: entry.targetDate, pounds: $0) } }
                    .sorted { $0.date < $1.date }
                recentStrengthProgressSection
                strengthProgressSection

                if !exerciseOptions.isEmpty {
                    exerciseProgressSection(options: exerciseOptions)
                        .id("tracker-strength-exercise")
                }

                trainingAttentionSection

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text("Bodyweight")
                            .font(.title3.weight(.black))
                        Spacer()
                        Picker("Bodyweight range", selection: $selectedProgressRange) {
                            ForEach(ProgressTimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .font(.caption.weight(.semibold))
                        .accessibilityLabel("Bodyweight chart range")
                        Button {
                            logBodyweightEntry()
                        } label: {
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

                    if let latest = bodyweightReadings.last {
                        HStack(spacing: 6) {
                            Text("Latest · \(MeasurementFormatting.formatBodyweight(latest.pounds, preferredUnit: appState.currentProfile.preferredUnit)) · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption.weight(.semibold))
                            if bodyweightReadings.count > 1, let previous = bodyweightReadings.dropLast().last {
                                let delta = latest.pounds - previous.pounds
                                let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
                                Text("· \(sign)\(MeasurementFormatting.formatBodyweight(abs(delta), preferredUnit: appState.currentProfile.preferredUnit)) since \(previous.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                    }

                    bodyweightChart(entries: bodyweightEntries)
                        .padding(12)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.liftOverlay, lineWidth: 1)
                        }

                    bodyweightTable(entries: bodyweightEntries)
                }
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
            if let category = appState.router.progressCategory {
                selectedProgressCategory = category
                appState.router.progressCategory = nil
            }
            if selectedProgressCategory == .strength { syncProgressExerciseSelection() }
            if selectedProgressCategory == .consistency { syncWorkoutHistorySelection() }
            Task { await appState.synchronizeCompletedWorkoutHistory(force: false) }
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
                    ("Progress uses history saved on this device", "\(pendingCount) workout\(pendingCount == 1 ? "" : "s") saved on this device; sync when you’re online.", "iphone.and.arrow.forward", .orange)
                case .syncing:
                    ("Refreshing workout history", "Keep this screen open while Progress updates.", "arrow.triangle.2.circlepath", .liftAccentText)
                case .stale:
                    ("Progress may be out of date", "Refresh to update your Progress stats.", "clock.arrow.circlepath", .orange)
                case .needsAttention:
                    ("Progress may be incomplete", "Workout history could not refresh. Retry to update Progress.", "exclamationmark.triangle.fill", .orange)
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
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
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
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var trainingAttentionSection: some View {
        let insights = appState.trainingProgressStore.strengthAttentionInsights(
            summary: appState.strengthTierSummary,
            referenceDate: Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970 / 60) * 60)
        )
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
                            .lineLimit(1)
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
                        Text("Week \(week.weekNumber) · \(week.title)")
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
            if completedCount == prescriptions.count {
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
        return calendar.date(byAdding: .day, value: dayOffset, to: cycleStart)
    }

    private func consistencyMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
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

    private var recoveryInsightSection: some View {
        let summaries = Array(appState.recoverySummaries().prefix(4))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recently trained muscles")
                    .font(.headline.weight(.bold))
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
                        withAnimation(.snappy) { segment = .today }
                    } label: {
                        Label("Start a workout", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
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
                                .foregroundStyle(summary.hoursSinceTraining < 48 ? Color.liftGold : Color.liftMuted)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.muscle.displayName)
                                    .font(.caption.weight(.bold))
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
                    Text("Gold means under 48 hours since logged primary work; gray means 48 hours or more. Time alone does not confirm recovery. Soreness, sleep, stress, and readiness are not measured.")
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

    private var recentStrengthProgressSection: some View {
        let trends = appState.trainingProgressStore.recentStrengthTrends()
        let improving = trends.filter { $0.status == .improving }.count
        let declining = trends.filter { $0.status == .declining }.count
        let steady = trends.filter { $0.status == .steady }.count
        let muscles = Set(trends.flatMap(\.primaryMuscles)).sorted { $0.displayName < $1.displayName }
        let selectableExerciseIDs = Set(appState.progressExerciseOptions().map(\.id))
        let coverage = appState.trainingProgressStore.muscleAttentionInsights(trainingFocus: appState.currentProfile.trainingFocus)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Am I getting stronger?").font(.headline.weight(.bold))
            Text("Last 14 calendar days compared with the preceding 14")
                .font(.caption).foregroundStyle(Color.liftMuted)
            if improving + declining + steady == 0 {
                Text("More comparable history needed")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("\(improving) improving · \(steady) steady · \(declining) declining")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Each lift needs at least two logged training days in each period. Changes over 1% are marked improving or declining; smaller changes are steady.")
                .font(.caption).foregroundStyle(Color.liftMuted)
            if !trends.isEmpty {
                Text("Lift performance by primary muscle").font(.subheadline.weight(.bold))
                ForEach(muscles) { muscle in
                    let lifts = trends.filter { $0.primaryMuscles.contains(muscle) }
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(lifts) { trend in
                                Button {
                                    selectedProgressExerciseID = trend.exerciseID
                                    selectedExerciseStrengthTrendDate = nil
                                    selectedExerciseWeightTrendDate = nil
                                    strengthExerciseScrollRequest = UUID()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trend.exerciseName).font(.subheadline.weight(.semibold))
                                        HStack {
                                            Text(trend.status.rawValue)
                                            if let change = trend.changeFraction {
                                                Text(change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())))
                                                    .monospacedDigit()
                                            }
                                        }
                                        .foregroundStyle(trend.status == .declining ? Color.orange : Color.liftAccentText)
                                        if trend.changeFraction != nil, let earlier = trend.earlierAverageKilograms, let recent = trend.recentAverageKilograms {
                                            Text("Average daily best estimated 1RM: \(MeasurementFormatting.formatDisplayedWeight(earlier, unit: appState.currentProfile.preferredUnit)) → \(MeasurementFormatting.formatDisplayedWeight(recent, unit: appState.currentProfile.preferredUnit))")
                                        }
                                        if trend.status == .insufficient {
                                            Text(trend.recentDayCount < 2
                                                 ? "Log this lift on \(2 - trend.recentDayCount) more day(s) this period. Two days in each period are needed."
                                                 : "Recent history is ready. The preceding period needs two logged days; keep logging to build the next comparison.")
                                        }
                                        Text("\(trend.earlierDayCount) earlier days · \(trend.recentDayCount) recent days")
                                            .foregroundStyle(Color.liftMuted)
                                        Text(selectableExerciseIDs.contains(trend.exerciseID) ? "Tap to select this exercise below" : "Exercise is no longer available in the library")
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!selectableExerciseIDs.contains(trend.exerciseID))
                                .accessibilityIdentifier("tracker.strength.trend.\(trend.exerciseID)")
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(muscle.displayName)
                            Text("\(lifts.filter { $0.status == .improving }.count) improving · \(lifts.filter { $0.status == .steady }.count) steady · \(lifts.filter { $0.status == .declining }.count) declining · \(lifts.filter { $0.status == .insufficient }.count) need logs")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.liftAccentText)
                }
            }
            DisclosureGroup("How trends are calculated") {
                Text("These are exercise performance signals, not direct measurements of muscle strength or growth. Each period averages the best estimated 1RM per logged day for the same exercise. Only completed weighted working sets of 1–10 reps count. Known deload/recovery weeks are excluded. Effort, technique, and equipment setup can affect estimates. A lift can appear under multiple primary muscles; the totals above count each lift once.")
                    .font(.caption).foregroundStyle(Color.liftMuted).padding(.top, 6)
            }
            .font(.caption.weight(.semibold))
            .tint(Color.liftAccentText)
            Divider()
            Text("Training coverage").font(.subheadline.weight(.bold))
            if !coverage.isEmpty {
                ForEach(coverage) { insight in
                    Text(insight.title).font(.caption.weight(.semibold))
                    Text(insight.evidence).font(.caption).foregroundStyle(Color.liftMuted)
                    Text(insight.nextStep).font(.caption).foregroundStyle(Color.liftMuted)
                }
            } else {
                Text("Review primary and secondary sets to see which muscles received less work. A missing signal does not establish that training is balanced.")
                    .font(.caption).foregroundStyle(Color.liftMuted)
            }
            Text("Less logged work is different from declining lift performance.")
                .font(.caption2).foregroundStyle(Color.liftMuted)
            Button("Review muscle workload") { selectedProgressCategory = .muscle }
                .font(.caption.weight(.semibold))
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .foregroundStyle(Color.liftAccentText)
                .accessibilityIdentifier("tracker.progress.reviewMuscleWorkload")
        }
        .padding(14)
        .liftSurface(radius: 12)
    }

    private var strengthProgressSection: some View {
        let summary = appState.strengthTierSummary
        let keyLifts = ["bench", "squat", "deadlift"].compactMap { exerciseID in
            summary.liftProgress.first { $0.exerciseID == exerciseID }
        }
        let completeMaxes = keyLifts.compactMap(\.estimatedOneRepMaxKilograms)
        let highestMax = max(1, completeMaxes.max() ?? 1)
        let threeLiftTotal = completeMaxes.count == 3 ? completeMaxes.reduce(0, +) : nil
        let latestBodyweight = appState.trainingProgressStore.strengthBodyweightPounds()
        let bodyweightKilograms = MeasurementFormatting.normalizeToKilograms(latestBodyweight, unit: .pounds)
        let relativeTotal = threeLiftTotal.flatMap { bodyweightKilograms > 0 ? $0 / bodyweightKilograms : nil }
        let supplementalLifts = progressExerciseOptions
            .filter { !["bench", "squat", "deadlift"].contains($0.rankingExerciseID ?? $0.id) }
            .compactMap { exercise in
                appState.exerciseRecords(for: exercise.id).bestEstimatedOneRepMaxKilograms.map { (exercise, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3).map(\.0)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Strength records · all time")
                    .font(.headline.weight(.bold))
                Text("Estimated one-rep max, calculated from completed working sets of up to 10 reps.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Text("Bars compare your three lifts with your strongest; tiers use bodyweight-based standards.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            }

            if completeMaxes.isEmpty && supplementalLifts.isEmpty {
                LiftEmptyState(
                    title: "No strength data yet",
                    message: "Complete a working set for bench press, squat, or deadlift to start your strength profile.",
                    symbolName: "figure.strengthtraining.traditional",
                    actionTitle: "Start a workout",
                    action: { withAnimation(.snappy) { segment = .today } },
                    compact: true
                )
            } else {
                strengthLiftCards(keyLifts, highestMax: highestMax)
                strengthSummaryMetrics(threeLiftTotal: threeLiftTotal, relativeTotal: relativeTotal)

                if !supplementalLifts.isEmpty {
                    Text("Other tracked lifts · all time")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                    supplementalLiftCards(Array(supplementalLifts))
                    .accessibilityElement(children: .contain)
                }

                if appState.currentProfile.primaryGymID != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                   !appState.currentProfile.primaryGymName.isEmpty {
                    let gymID = appState.currentProfile.primaryGymID
                    Button {
                        appState.leaderboardFilters = LeaderboardFilters(
                            exerciseID: nil,
                            rankingType: .total,
                            gymID: gymID
                        )
                        appState.verifiedOnly = true
                        appState.leaderboardFocusRequestID = UUID()
                        appState.selectedTab = 1
                    } label: {
                        Label("Compare 3-lift total at \(appState.currentProfile.primaryGymName)", systemImage: "trophy")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
                            .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tracker.progress.compareAtGym")
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

    @ViewBuilder
    private func strengthLiftCards(_ lifts: [LiftTierProgress], highestMax: Double) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(lifts, id: \.exerciseID) { lift in strengthLiftCard(lift, highestMax: highestMax) }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(lifts, id: \.exerciseID) { lift in strengthLiftCard(lift, highestMax: highestMax) }
            }
        }
    }

    private func strengthLiftCard(_ lift: LiftTierProgress, highestMax: Double) -> some View {
        let liftMax = lift.estimatedOneRepMaxKilograms ?? 0
        let tierLabel = lift.estimatedOneRepMaxKilograms == nil ? "No data" : lift.currentTier.label
        return VStack(alignment: .leading, spacing: 8) {
            Text(lift.exerciseName.uppercased())
                .font(.caption.weight(.black))
                .tracking(0.4)
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
            Text(lift.estimatedOneRepMaxKilograms.map {
                MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
            } ?? "—")
                .font(.headline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.liftOverlay)
                    Capsule().fill(Color.liftAccentText)
                        .frame(width: geometry.size.width * CGFloat(liftMax / highestMax))
                }
            }
            .frame(height: 5)
            Text(tierLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(10)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func strengthSummaryMetrics(threeLiftTotal: Double?, relativeTotal: Double?) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { strengthSummaryCards(threeLiftTotal: threeLiftTotal, relativeTotal: relativeTotal) }
        } else {
            HStack(spacing: 10) { strengthSummaryCards(threeLiftTotal: threeLiftTotal, relativeTotal: relativeTotal) }
        }
    }

    @ViewBuilder
    private func strengthSummaryCards(threeLiftTotal: Double?, relativeTotal: Double?) -> some View {
        volumeSummary(
            title: "THREE-LIFT TOTAL",
            value: threeLiftTotal.map {
                MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
            } ?? "—",
            detail: threeLiftTotal == nil ? "Log all three lifts" : "Squat + bench press + deadlift",
            symbol: "sum"
        )
        volumeSummary(
            title: "RELATIVE TOTAL",
            value: relativeTotal.map { String(format: "%.2f×", $0) } ?? "—",
            detail: relativeTotal == nil ? "Needs total and bodyweight" : "of bodyweight",
            symbol: "scalemass"
        )
    }

    @ViewBuilder
    private func supplementalLiftCards(_ lifts: [TrainingExerciseCatalogItem]) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(lifts, id: \.id) { lift in supplementalLiftCard(lift) }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(lifts, id: \.id) { lift in supplementalLiftCard(lift) }
            }
        }
    }

    private func supplementalLiftCard(_ lift: TrainingExerciseCatalogItem) -> some View {
        let record = appState.exerciseRecords(for: lift.id)
        return VStack(alignment: .leading, spacing: 4) {
            Text(lift.name)
                .font(.caption.weight(.black))
                .foregroundStyle(Color.liftMuted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            Text(record.bestEstimatedOneRepMaxKilograms.map {
                MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
            } ?? "—")
                .font(.subheadline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .background(Color.liftCardRaised.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func volumeSummary(
        title: String,
        value: String,
        detail: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
                .frame(width: 30, height: 30)
                .background(Color.liftBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.black))
                    .tracking(0.5)
                    .foregroundStyle(Color.liftMuted)
                Text(value)
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(1)
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
        let now = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -27, to: Calendar.current.startOfDay(for: now))!
        let recoveryIDs = Set(appState.trainingProgressStore.completedWorkouts
            .filter { $0.completedAt >= start && $0.completedAt <= now && appState.trainingProgressStore.isRecoveryWorkout($0) }
            .map(\.id))
        let setPoints = (exercise.map { appState.exerciseProgressPoints(for: $0.id) } ?? [])
            .filter { $0.date >= start && $0.date <= now && !($0.workoutID.map { recoveryIDs.contains($0) } ?? false) }
        let chartPoints = ExerciseProgressSeries.dailyHighest(from: setPoints)
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
        let latestEstimatedMax = estimatedMaxPoints.last.map(ExerciseProgressSeries.estimatedOneRepMax)
        let strengthIncrease = startingEstimatedMax.flatMap { start in
            latestEstimatedMax.map { $0 - start }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let exercise {
                    ExerciseCatalogIcon(exercise: exercise)
                        .frame(width: 42, height: 42)
                }
            Text("Exercise progress · last 28 days")
                .font(.subheadline.weight(.bold))
                Spacer()
                Button {
                    showingProgressExercisePicker = true
                } label: {
                    Label(exercise?.name ?? "Exercise", systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
                }
                .accessibilityIdentifier("tracker.progress.exercisePicker")
                .sheet(isPresented: $showingProgressExercisePicker) {
                    ProgressExercisePickerSheet(options: options, selectedID: selectedProgressExerciseID) { exerciseID in
                        selectedProgressExerciseID = exerciseID
                        selectedExerciseWeightTrendDate = nil
                        selectedExerciseStrengthTrendDate = nil
                    }
                }
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
            } else {
                if estimatedMaxPoints.isEmpty {
                    Text("Estimated strength needs a completed weighted working set of 1–10 reps. Higher-rep sets still appear in load and volume records.")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                }
                if estimatedMaxPoints.count == 1,
                   let currentEstimatedMax = estimatedMaxPoints.first.map(ExerciseProgressSeries.estimatedOneRepMax) {
                    progressMetric(
                        title: "CURRENT EST. 1RM",
                        value: MeasurementFormatting.formatDisplayedWeight(currentEstimatedMax, unit: appState.currentProfile.preferredUnit),
                        symbol: "scalemass.fill"
                    )
                    Text("Log this exercise in another workout to see an estimated 1RM trend.")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                } else if let startingEstimatedMax, let latestEstimatedMax, let strengthIncrease {
                    HStack(spacing: 10) {
                        progressMetric(
                            title: "STARTING EST. 1RM",
                            value: MeasurementFormatting.formatDisplayedWeight(startingEstimatedMax, unit: appState.currentProfile.preferredUnit),
                            symbol: "flag.fill"
                        )
                        progressMetric(
                            title: "LATEST EST. 1RM",
                            value: MeasurementFormatting.formatDisplayedWeight(latestEstimatedMax, unit: appState.currentProfile.preferredUnit),
                            symbol: "arrow.up.right"
                        )
                        progressMetric(
                            title: "CHANGE",
                            value: (strengthIncrease >= 0 ? "+" : "") + MeasurementFormatting.formatDisplayedWeight(strengthIncrease, unit: appState.currentProfile.preferredUnit),
                            symbol: "chart.line.uptrend.xyaxis"
                        )
                    }

                    Text("Change compares the first and latest eligible days in this 28-day window. The summary above compares averages across its two halves. Known recovery weeks are excluded.")
                        .font(.caption2).foregroundStyle(Color.liftMuted)
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
                    Text("Best sets by rep range · last 28 days")
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
                            title: "ALL-TIME SET VOLUME",
                            value: MeasurementFormatting.formatDisplayedWeight(bestSetVolume, unit: appState.currentProfile.preferredUnit),
                            symbol: "square.stack.3d.up.fill"
                        )
                        progressMetric(
                            title: "ALL-TIME SESSION VOLUME",
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
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.3)
                .foregroundStyle(Color.liftMuted)
                .lineLimit(2)
            Text(value)
                .font(.caption.weight(.black).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
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
                let values = chartPoints.flatMap { [$0.actual, $0.average] }
                let minimum = values.min() ?? 0
                let maximum = values.max() ?? minimum
                let padding = max(5, (maximum - minimum) * 0.15)
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
                .chartYScale(domain: max(0, minimum - padding)...(maximum + padding))
                .chartYAxisLabel(appState.currentProfile.preferredUnit.shortLabel, position: .trailing)
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
        return VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                Text("Bodyweight history")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Color.liftCardRaised.opacity(0.7))
            } else {
                HStack {
                    Text("Entry").frame(width: 48, alignment: .leading)
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
                    if dynamicTypeSize.isAccessibilitySize {
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
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
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
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Entry \(row.week)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
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
                                .font(.subheadline)
                                .foregroundStyle(Color.liftText)
                            }
                        }
                        .foregroundStyle(Color.liftText)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 88 : 56, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Entry \(row.week), \(row.targetDate.formatted(date: .abbreviated, time: .omitted)), \(formattedBodyweight), edit")

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
            .filter { $0.targetDate <= .now && ($0.actual.map { $0.isFinite && $0 > 0 } ?? false) }
            .sorted { $0.targetDate < $1.targetDate }
            .map { $0 }
    }

    private var selectedBodyweightEntries: [BodyweightEntry] {
        let startDate = selectedProgressRange.startDate()
        return recentBodyweightEntries.filter { $0.targetDate >= startDate }
    }

    private func logBodyweightEntry() {
        selectedBodyweightEntry = BodyweightEntry.draftForToday(
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

private struct ProgressExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let options: [TrainingExerciseCatalogItem]
    let selectedID: String?
    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filteredOptions: [TrainingExerciseCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
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
                        ExerciseCatalogIcon(exercise: exercise)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name).foregroundStyle(Color.liftText)
                            Text("\(exercise.equipment) · \(exercise.resolvedMuscleProfile.primaryDescription)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
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
            .navigationTitle("Choose exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
