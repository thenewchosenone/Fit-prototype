import Charts
import SwiftUI

enum TrackerProgressCategory: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case muscle = "Muscle"
    case consistency = "Consistency"

    var id: String { rawValue }
}

private struct BodyweightChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let actual: Double
    let average: Double
}

extension TrainingTrackerView {
    var progress: some View {
        let volumeWeek = selectedVolumeWeek
        let totals = appState.weeklyVolumeByBodyPart(referenceDate: volumeWeek.referenceDate)
        let maxVolume = max(1, totals.values.max() ?? 1)
        let totalVolume = totals.values.reduce(0, +)
        let rankedTotals = totals
            .map { (bodyPart: $0.key, value: $0.value) }
            .sorted {
                if $0.value == $1.value { return $0.bodyPart < $1.bodyPart }
                return $0.value > $1.value
            }
        let bodyweightEntries = selectedBodyweightEntries
        let weekCompletion = selectedWeek.map(appState.weekCompletion(for:))
        let historyPresentation = appState.workoutHistoryPresentation(
            displayedMonth: workoutHistoryMonth,
            selectedDate: selectedWorkoutHistoryDate
        )
        let exerciseOptions = appState.progressExerciseOptions()

        return LazyVStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.weight(.black))

            progressSyncStatus
            progressOverviewCard

            Picker("Progress category", selection: $selectedProgressCategory) {
                ForEach(TrackerProgressCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tracker.progress.category")

            if selectedProgressCategory == .consistency {
                WeeklyTrainingDayGoalCard(summary: appState.homeWeeklySummary())
                programConsistencySection(weekCompletion: weekCompletion)
                recoveryInsightSection

                if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                    strainAndInjurySection
                }

                workoutHistorySection(presentation: historyPresentation)
            }

            if selectedProgressCategory == .strength {
                strengthProgressSection

                if !exerciseOptions.isEmpty {
                    exerciseProgressSection(options: exerciseOptions)
                }

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
                weeklyMuscleSetSection

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weekly volume load by primary muscles")
                                .font(.headline.weight(.bold))
                            Text("Weight × reps from completed working sets, grouped by each exercise’s primary muscles")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer(minLength: 8)
                        Button {
                            selectedVolumeWeek = volumeWeek == .thisWeek ? .lastWeek : .thisWeek
                        } label: {
                            Text(volumeWeek.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(Color.liftAccentText)
                                .padding(.horizontal, 9)
                                .frame(height: 26)
                                .background(Color.liftBlue.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Volume period")
                        .accessibilityValue(volumeWeek.rawValue)
                    }

                    if totals.values.allSatisfy({ $0 == 0 }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Complete workout sets to build volume insights.")
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
                        .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 10) {
                            volumeSummary(
                                title: "VOLUME LOAD",
                                value: Int(totalVolume).formatted(),
                                detail: appState.currentProfile.preferredUnit.shortLabel,
                                symbol: "sum"
                            )
                            volumeSummary(
                                title: "TOP FOCUS",
                                value: rankedTotals.first?.bodyPart ?? "—",
                                detail: rankedTotals.first.map {
                                    "\(Int(($0.value / max(totalVolume, 1)) * 100))% of volume"
                                } ?? "No volume",
                                symbol: "scope"
                            )
                        }

                        VStack(spacing: 13) {
                            ForEach(Array(rankedTotals.enumerated()), id: \.element.bodyPart) { index, item in
                                volumeBodyPartRow(
                                    bodyPart: item.bodyPart,
                                    value: item.value,
                                    maxVolume: maxVolume,
                                    totalVolume: totalVolume,
                                    index: index
                                )
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(16)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.liftOverlay, lineWidth: 1)
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        .onAppear {
            syncProgressExerciseSelection()
            syncWorkoutHistorySelection()
            Task { await appState.synchronizeCompletedWorkoutHistory(force: false) }
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            syncProgressExerciseSelection()
            syncWorkoutHistorySelection()
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
        let priorWeeks = (1...4).map { offset in
            appState.homeWeeklySummary(
                referenceDate: Calendar.current.date(byAdding: .day, value: -7 * offset, to: .now) ?? .now
            )
        }
        let baselineVolume = priorWeeks.map(\.volume).reduce(0, +) / Double(priorWeeks.count)
        let recovery = appState.recoverySummaries().filter { $0.hoursSinceTraining < 48 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.headline.weight(.bold))
                    Text(summary.completedWorkoutCount == 0
                         ? "Log a workout to start your weekly snapshot."
                         : "Your training snapshot across completed working sets.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer(minLength: 8)
                if recovery > 0 {
                    Label("\(recovery) recovering", systemImage: "bed.double.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftGold)
                }
            }

            HStack(spacing: 0) {
                progressOverviewMetric("Workouts", value: "\(summary.completedWorkoutCount)")
                progressOverviewDivider
                progressOverviewMetric("Working sets", value: "\(summary.completedSetCount)")
                progressOverviewDivider
                progressOverviewMetric(
                    "Volume",
                    value: MeasurementFormatting.formatDisplayedWeight(summary.volume, unit: appState.currentProfile.preferredUnit)
                )
            }
            Text(progressBaselineText(summary: summary, baselineVolume: baselineVolume))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func progressBaselineText(summary: HomeWeeklySummary, baselineVolume: Double) -> String {
        if summary.completedWorkoutCount == 0 {
            guard baselineVolume > 0 else { return "Log a workout to start your weekly snapshot." }
            return "No completed workouts this week. Log one to compare against your four-week baseline."
        }
        guard baselineVolume > 0 else { return "Four-week volume baseline will appear after more training data." }
        let difference = summary.volume - baselineVolume
        let percentage = Int((abs(difference) / baselineVolume * 100).rounded())
        if percentage == 0 { return "Volume is in line with your four-week baseline." }
        return "Volume is \(percentage)% \(difference > 0 ? "above" : "below") your four-week baseline."
    }

    private func progressOverviewMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var progressOverviewDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 30)
    }

    private func programConsistencySection(weekCompletion: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let week = selectedWeek {
                let completion = weekCompletion ?? 0
                let presentation = appState.programWeekPresentation(for: week)
                HStack(alignment: .center) {
                    ZStack {
                        Circle()
                            .stroke(Color.liftOverlay, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: min(max(completion, 0), 1))
                            .stroke(Color.liftGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(completion * 100))%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 52, height: 52)

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
            ("Backfilled", backfilled, "arrow.uturn.backward.circle.fill", Color.liftBlue),
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
                Text("Recovery context")
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
                            Image(systemName: summary.hoursSinceTraining < 48 ? "bed.double.fill" : "checkmark.circle.fill")
                                .foregroundStyle(summary.hoursSinceTraining < 48 ? Color.liftGold : Color.liftGreen)
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

    private var weeklyMuscleSetSection: some View {
        let weeks = appState.weeklyWorkingSetsByMuscle()
        let muscles = Set(weeks.flatMap { $0.counts.keys })
        let ranked = muscles.map { muscle in
            let counts = weeks.map { $0.counts[muscle, default: 0] }
            return (
                muscle: muscle,
                total: counts.reduce(0, +),
                frequency: counts.filter { $0 > 0 }.count,
                counts: counts
            )
        }
        .sorted {
            if $0.total == $1.total { return $0.muscle.displayName < $1.muscle.displayName }
            return $0.total > $1.total
        }

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Four-week working sets by muscle")
                    .font(.headline.weight(.bold))
                Text("Completed non-warmup sets by primary muscle · count and training frequency")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }

            if ranked.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete working sets to compare muscle training across four weeks.")
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
                .padding(.vertical, 6)
            } else {
                HStack {
                    Text("MUSCLE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        Text(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))
                            .frame(width: 39)
                    }
                }
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(Color.liftMuted)

                ForEach(ranked, id: \.muscle) { item in
                    Button {
                        focusedWorkoutSetID = nil
                        selectedCompletedWorkout = mostRecentWorkout(for: item.muscle)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.muscle.displayName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                let weeklyCount = item.counts.last ?? 0
                                let target = muscleTargetStatus(weeklyCount)
                                Text("\(target.label) · \(weeklyCount) this week")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(target.color)
                            }

                            HStack(alignment: .bottom, spacing: 0) {
                                Color.clear.frame(maxWidth: .infinity)
                                ForEach(Array(item.counts.enumerated()), id: \.offset) { _, count in
                                    muscleWeekBar(count: count)
                                }
                            }
                        }
                        .foregroundStyle(Color.liftText)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.muscle.displayName), \(item.total) working sets across four weeks, trained in \(item.frequency) of four weeks, \(muscleTargetStatus(item.counts.last ?? 0).label) at \(item.counts.last ?? 0) sets this week")
                    .accessibilityHint("Opens a recent workout that trained this muscle")
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

    private var strengthProgressSection: some View {
        let summary = appState.strengthTierSummary
        let keyLifts = ["bench", "squat", "deadlift"].compactMap { exerciseID in
            summary.liftProgress.first { $0.exerciseID == exerciseID }
        }
        let completeMaxes = keyLifts.compactMap(\.estimatedOneRepMaxKilograms)
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
                HStack(spacing: 8) {
                    ForEach(keyLifts, id: \.exerciseID) { lift in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lift.exerciseName.uppercased())
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(1)
                            Text(lift.estimatedOneRepMaxKilograms.map {
                                MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                            } ?? "—")
                                .font(.subheadline.weight(.black).monospacedDigit())
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(lift.estimatedOneRepMaxKilograms == nil ? "No data" : lift.currentTier.label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 67, alignment: .leading)
                        .padding(.horizontal, 9)
                        .background(Color.liftCardRaised.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
                    volumeSummary(
                        title: "THREE-LIFT TOTAL",
                        value: threeLiftTotal.map {
                            MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                        } ?? "—",
                        detail: threeLiftTotal == nil ? "Log all three lifts" : appState.currentProfile.preferredUnit.shortLabel,
                        symbol: "sum"
                    )
                    volumeSummary(
                        title: "RELATIVE TOTAL",
                        value: relativeTotal.map { String(format: "%.2f×", $0) } ?? "—",
                        detail: relativeTotal == nil ? "Needs total and bodyweight" : "of bodyweight",
                        symbol: "scalemass"
                    )
                }

                if !supplementalLifts.isEmpty {
                    Text("Other tracked lifts")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                    HStack(spacing: 8) {
                        ForEach(supplementalLifts, id: \.id) { lift in
                            let record = appState.exerciseRecords(for: lift.id)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lift.name)
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(1)
                                Text(record.bestEstimatedOneRepMaxKilograms.map {
                                    MeasurementFormatting.formatDisplayedWeight($0, unit: appState.currentProfile.preferredUnit)
                                } ?? "—")
                                    .font(.subheadline.weight(.black).monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .padding(.horizontal, 9)
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

    private func muscleWeekBar(count: Int) -> some View {
        let barHeight = count > 0 ? 5 + min(count, 12) * 2 : 4
        let barColor: Color = count > 0 ? .liftGreen : .liftOverlay
        return VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 14, height: CGFloat(barHeight))
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.liftText)
        }
        .frame(width: 39, height: 31, alignment: .bottom)
    }

    private func muscleTargetStatus(_ weeklySetCount: Int) -> (label: String, color: Color) {
        switch weeklySetCount {
        case 0..<8:
            return ("Below target", .liftGold)
        case 8...20:
            return ("In range", .liftGreen)
        default:
            return ("Above target", .liftPurple)
        }
    }

    private func mostRecentWorkout(for muscle: ExerciseMuscleRegion) -> CompletedWorkout? {
        appState.trainingHistoryWorkouts.filter { workout in
            workout.exercises.contains { exercise in
                let profile = exercise.muscleProfile ?? ExerciseMuscleProfileResolver.profile(
                    name: exercise.exerciseName,
                    bodyPart: exercise.bodyPart
                )
                guard profile.primary.contains(muscle) else { return false }
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
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color.liftMuted)
                Text(value)
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
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

    private func volumeBodyPartRow(
        bodyPart: String,
        value: Double,
        maxVolume: Double,
        totalVolume: Double,
        index: Int
    ) -> some View {
        let tint = volumeTint(for: bodyPart)
        let share = value / max(totalVolume, 1)
        let barWidth = min(max(share, 0), 1)

        return HStack(spacing: 11) {
            Text("\(index + 1)")
                .font(.caption2.weight(.black).monospacedDigit())
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(bodyPart)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text("\(Int(share * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liftMuted)
                    Spacer(minLength: 0)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.liftOverlay)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.62), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(7, geometry.size.width * barWidth))
                    }
                }
                .frame(height: 7)
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text(Int(value).formatted())
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.liftText)
                Text(appState.currentProfile.preferredUnit.shortLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(width: 58, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(index + 1), \(bodyPart), \(Int(value).formatted()) \(appState.currentProfile.preferredUnit.shortLabel), \(Int(share * 100)) percent of weekly volume")
    }

    private func volumeTint(for bodyPart: String) -> Color {
        let name = bodyPart.lowercased()
        if name.contains("quad") || name.contains("calf") { return .liftGreen }
        if name.contains("hamstring") || name.contains("glute") { return .liftPurple }
        if name.contains("lat") || name.contains("back") { return .cyan }
        if name.contains("shoulder") { return .indigo }
        if name.contains("arm") || name.contains("bicep") || name.contains("tricep") { return .mint }
        return .liftBlue
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
            } else {
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
                } else if let startingEstimatedMax, let bestEstimatedMax, let strengthIncrease {
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
        return VStack(spacing: 0) {
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

            if entries.isEmpty {
                HStack(spacing: 8) {
                    Text("--")
                        .frame(width: 48, alignment: .leading)
                    Text("Log bodyweight to fill this table")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("--")
                        .frame(width: 76, alignment: .trailing)
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.clear)
                        .frame(width: 28)
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
                        .padding(.horizontal, 12)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Week \(row.week), \(formattedBodyweight), edit")

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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
