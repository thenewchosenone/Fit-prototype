import SwiftUI

enum MuscleWorkloadFilter: String, CaseIterable, Identifiable {
    case logged = "Logged work"
    case noPrimary = "No primary sets"
    case all = "All muscles"

    var id: String { rawValue }
}

extension TrainingTrackerView {
    var muscleProgress: some View {
        let referenceDate = selectedVolumeWeek.referenceDate
        let weeks = appState.weeklyWorkingSetsByMuscle(referenceDate: referenceDate)
        return VStack(alignment: .leading, spacing: 14) {
            muscleFatigueMap
            if let week = weeks.last {
                if week.hasHistory {
                    muscleWorkloadList(week: week, weeks: weeks)
                    muscleVolumeDetails(referenceDate: referenceDate)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        musclePeriodHeader
                        Text("No working sets logged for this week")
                            .font(LiftTypography.rowEmphasis)
                        Text("Muscle workload uses completed workouts. Earlier weeks stay unknown until history is available.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Button(selectedVolumeWeek == .lastWeek ? "View this week" : "Start a workout") {
                            if selectedVolumeWeek == .lastWeek {
                                selectedVolumeWeek = .thisWeek
                            } else {
                                withAnimation(.snappy) { segment = .today }
                            }
                        }
                        .font(LiftTypography.rowEmphasis)
                        .foregroundStyle(Color.liftAccentText)
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                    }
                    .padding(14)
                    .liftSurface(radius: 12)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Muscle progress is temporarily unavailable")
                        .font(LiftTypography.rowEmphasis)
                    Text("Check the workout history sync status above, then try this section again.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(14)
                .liftSurface(radius: 12)
            }
        }
        .onChange(of: selectedVolumeWeek) {
            showAllMuscleSetRows = false
            showAllMuscleVolumeRows = false
        }
    }

    @ViewBuilder
    private var muscleFatigueMap: some View {
        let scores = appState.trainingProgressStore.muscleFatigueScores()
        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Muscle fatigue estimate")
                        .font(LiftTypography.cardTitle)
                    Spacer()
                    Text("Recent work")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(scores, id: \.muscle) { item in
                        Button {
                            selectedProgressMuscleDate = .now
                            selectedProgressMuscle = item.muscle
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text(item.muscle.displayName)
                                        .lineLimit(1)
                                    Spacer(minLength: 2)
                                    Text("\(Int(item.score.rounded()))%")
                                        .monospacedDigit()
                                }
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.liftCardRaised)
                                        Capsule()
                                            .fill(item.score >= 65 ? Color.orange : Color.liftAccentText)
                                            .frame(width: geometry.size.width * min(1, item.score / 100))
                                    }
                                }
                                .frame(height: 5)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftText)
                            .padding(9)
                            .background(Color.liftCardRaised.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.muscle.displayName), estimated recent training signal \(Int(item.score.rounded())) percent")
                        .accessibilityHint("Opens this muscle's logged workload")
                    }
                }
                DisclosureGroup("How to read this estimate") {
                    Text("This is an estimate from completed sets, effort when logged, and time since training. It is not a measurement of recovery or readiness.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 4)
                }
                .font(.caption.weight(.semibold))
                .tint(Color.liftAccentText)
            }
            .padding(14)
            .liftSurface(radius: 12)
        }
    }

    private var musclePeriodHeader: some View {
        let layout = dynamicTypeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Text("Muscle workload")
                .font(LiftTypography.cardTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Picker("Muscle period", selection: $selectedVolumeWeek) {
                    ForEach(VolumeWeekSelection.allCases) { week in
                        Text(week.rawValue).tag(week)
                    }
                }
            } label: {
                Label(selectedVolumeWeek.rawValue, systemImage: "chevron.up.chevron.down")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            .accessibilityLabel("Muscle period")
            .accessibilityIdentifier("tracker.muscle.period")
            .accessibilityValue(selectedVolumeWeek.rawValue)
        }
    }

    @ViewBuilder
    private func muscleAttention(referenceDate: Date) -> some View {
        let insights = appState.trainingProgressStore.muscleAttentionInsights(
            referenceDate: referenceDate, includeReferenceWeek: selectedVolumeWeek == .lastWeek,
            trainingFocus: appState.currentProfile.trainingFocus
        )
        if let first = insights.first {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text(first.evidence)
                        .foregroundStyle(Color.liftMuted)
                    Text(first.nextStep)
                    ForEach(Array(insights.dropFirst())) { insight in
                        Text(insight.title).fontWeight(.semibold)
                        Text(insight.evidence)
                        Text(insight.nextStep)
                    }
                    Text("Selected comparisons: quads/hamstrings, biceps/triceps, and front/rear delts. Signals require at least two full logged weeks, at least 8 sets in the higher group, a 6-set difference, and twice as many primary sets. Indirect work is excluded. These describe training emphasis, not muscle size or strength.")
                        .foregroundStyle(Color.liftMuted)
                    Text("These are differences in logged work, not missed program targets. A lower primary-set count alone does not mean you need more training. Review your program and training priorities before changing volume.")
                        .foregroundStyle(Color.liftMuted)
                    Button("Review workout plan") {
                        withAnimation(.snappy) { segment = .plans }
                    }
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .padding(.top, 8)
            } label: {
                Label(first.title, systemImage: "scope")
                    .font(.caption.weight(.semibold))
            }
            .font(.caption)
            .tint(Color.liftAccentText)
            .frame(minHeight: LiftDesign.minimumTouchTarget)
        }
    }

    private func muscleWorkloadList(week: MuscleTrainingWeek, weeks: [MuscleTrainingWeek]) -> some View {
        let muscles = Set(ExerciseMuscleRegion.allCases.map(\.trainingSummaryRegion))
            .filter { muscle in
                muscle != .fullBody || weeks.contains {
                    $0.counts[muscle, default: 0] > 0 || $0.secondaryCounts[muscle, default: 0] > 0
                }
            }
        let noPrimaryCount = muscles.filter { week.counts[$0, default: 0] == 0 }.count
        let rows = muscles.filter { muscle in
            switch muscleWorkloadFilter {
            case .logged: weeks.contains { $0.counts[muscle, default: 0] > 0 || $0.secondaryCounts[muscle, default: 0] > 0 }
            case .noPrimary: week.counts[muscle, default: 0] == 0
            case .all: true
            }
        }.sorted {
            if muscleWorkloadFilter != .all {
                let firstMuscle = $0
                let secondMuscle = $1
                let first = weeks.reduce(0) { $0 + $1.counts[firstMuscle, default: 0] }
                let second = weeks.reduce(0) { $0 + $1.counts[secondMuscle, default: 0] }
                if first != second { return first > second }
            }
            return $0.displayName < $1.displayName
        }
        let peak = max(1, weeks.flatMap { $0.counts.values }.max() ?? 0)
        let comparison = appState.trainingProgressStore.completedMuscleSetComparison(weeks: weeks)
        let rowLayout = dynamicTypeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 10) {
            musclePeriodHeader
            Text("\(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))–\(week.weekEnd.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day())) · \(selectedVolumeWeek == .thisWeek ? "In progress" : "Completed week")")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            Text("\(week.completedSetCount) working set\(week.completedSetCount == 1 ? "" : "s") · \(week.trainingDayCount) training day\(week.trainingDayCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            if !week.hasFullHistory {
                Text("First logged week · earlier days may be untracked")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Text("Four-week primary sets")
                .font(.subheadline.weight(.semibold))
            Menu {
                Picker("Muscle filter", selection: $muscleWorkloadFilter) {
                    ForEach(MuscleWorkloadFilter.allCases) { filter in
                        Text(filter == .noPrimary ? "No primary sets (\(noPrimaryCount))" : filter.rawValue).tag(filter)
                    }
                }
            } label: {
                Label(muscleWorkloadFilter == .noPrimary ? "No primary sets (\(noPrimaryCount))" : muscleWorkloadFilter.rawValue,
                      systemImage: "chevron.up.chevron.down")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            .accessibilityLabel("Muscle filter")
            .accessibilityIdentifier("tracker.muscle.filter")
            .accessibilityValue(muscleWorkloadFilter.rawValue)

            if dynamicTypeSize < .xxxLarge {
                HStack(spacing: 8) {
                    Text("MUSCLE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(weeks, id: \.weekStart) { comparisonWeek in
                        VStack(spacing: 1) {
                            Text(comparisonWeek.weekStart.formatted(.dateTime.month(.abbreviated)))
                            Text(comparisonWeek.weekStart.formatted(.dateTime.day()))
                        }
                        .frame(width: LiftDesign.minimumTouchTarget)
                        .foregroundStyle(comparisonWeek.weekStart == week.weekStart ? Color.liftAccentText : Color.liftMuted)
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Primary working sets, four weeks ending with the selected week. Column dates are week starts.")
            }

            if let comparison {
                Text("Set changes: \(comparison.laterWeek.formatted(.dateTime.month(.abbreviated).day())) vs \(comparison.earlierWeek.formatted(.dateTime.month(.abbreviated).day())) · completed weeks")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            }
            if rows.isEmpty {
                Text("No logged work for this filter. Choose All muscles to review the full list.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            ForEach(Array(rows.prefix(showAllMuscleSetRows ? rows.count : 5))) { muscle in
                let primary = week.counts[muscle, default: 0]
                let secondary = week.secondaryCounts[muscle, default: 0]
                let days = week.trainingDays[muscle, default: 0]
                rowLayout {
                    Button {
                        selectedProgressMuscleDate = week.weekStart
                        selectedProgressMuscle = muscle
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(muscle.displayName).font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                if primary > 0 {
                                    Text("\(days) day\(days == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                if secondary > 0 {
                                    Text("\(secondary) secondary")
                                        .font(.caption2.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(Color.liftBlue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.liftBlue.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                if primary == 0 && secondary == 0 {
                                    Text("No work logged")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                            if let change = comparison?.changes[muscle] {
                                Text("Last completed week: \(change > 0 ? "+" : "")\(change) set\(abs(change) == 1 ? "" : "s")")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Color.liftMuted)
                                    .accessibilityLabel("Change between the two latest completed weeks: \(change) primary sets")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tracker.muscle.\(muscle.rawValue)")
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Shows contributing exercises for the selected week. Tap an individual weekly bar to open that week instead.")
                    HStack(spacing: 8) {
                        ForEach(weeks, id: \.weekStart) { comparisonWeek in
                            Button {
                                selectedProgressMuscleDate = comparisonWeek.weekStart
                                selectedProgressMuscle = muscle
                            } label: {
                                muscleWeekComparison(week: comparisonWeek, muscle: muscle, peak: peak)
                                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!comparisonWeek.hasHistory)
                            .accessibilityIdentifier("tracker.muscleWeek.\(muscle.rawValue).\(comparisonWeek.weekStart.timeIntervalSince1970)")
                            .accessibilityHint("Opens the exercises and sets logged for this muscle in this week")
                        }
                    }
                }
                .foregroundStyle(Color.liftText)
                .padding(.vertical, 4)
                if muscle != rows.prefix(showAllMuscleSetRows ? rows.count : 5).last {
                    Divider().overlay(Color.liftOverlay)
                        .accessibilityHidden(true)
                }
            }
            if rows.count > 5 {
                Button(showAllMuscleSetRows ? "Show fewer muscles" : "Show all \(rows.count) muscles") {
                    showAllMuscleSetRows.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liftAccentText)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
            muscleAttention(referenceDate: selectedVolumeWeek.referenceDate)
            Text("\(selectedVolumeWeek.rawValue) highlighted\(selectedVolumeWeek == .thisWeek ? " · still in progress" : ""). Days and secondary sets: selected week.")
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            if comparison == nil {
                Text("Set changes appear after two full logged weeks are complete.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            }
            if weeks.contains(where: { !$0.hasFullHistory }) {
                Text("— before your first log · * first logged week, partial history")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            }
            DisclosureGroup("How sets are counted") {
                Text("Each completed non-warmup set counts once for every primary muscle listed for its exercise. Secondary sets are shown separately and are not added to primary sets. Upper and lower chest work is combined under Chest. Training days count distinct dates with primary work. Logged work includes any of the four displayed weeks; No primary sets applies to the selected week. Muscle totals can exceed your workout’s set count. These are logged workloads; personal targets and muscle growth are not measured.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 4)
            }
            .font(.caption.weight(.semibold))
            .tint(Color.liftAccentText)
        }
        .padding(14)
        .liftSurface(radius: 12)
        .onChange(of: muscleWorkloadFilter) { showAllMuscleSetRows = false }
    }

    private func muscleWeekComparison(week: MuscleTrainingWeek, muscle: ExerciseMuscleRegion, peak: Int) -> some View {
        let count = week.counts[muscle, default: 0]
        let isSelected = Calendar.current.isDate(week.weekStart, equalTo: selectedVolumeWeek.referenceDate, toGranularity: .weekOfYear)
        return VStack(spacing: 4) {
            if dynamicTypeSize >= .xxxLarge {
                Text(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            }
            Text(week.hasHistory ? "\(count)\(week.hasFullHistory ? "" : "*")" : "—")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(isSelected ? Color.liftAccentText : Color.liftText)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(Color.liftOverlay)
                if week.hasHistory && count > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? Color.liftAccentText : Color.liftAccentText.opacity(0.45))
                        .frame(height: 28 * Double(count) / Double(peak))
                }
            }
            .frame(width: 18, height: 28)
        }
        .frame(width: dynamicTypeSize >= .xxxLarge ? nil : LiftDesign.minimumTouchTarget)
        .frame(maxWidth: dynamicTypeSize >= .xxxLarge ? .infinity : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(week.weekStart.formatted(.dateTime.month(.abbreviated).day())): \(week.hasHistory ? "\(count) primary set\(count == 1 ? "" : "s")\(week.hasFullHistory ? "" : ", partial first week")" : "no earlier logs, workload unknown")\(isSelected ? ", selected week" : "")")
    }

    private func muscleVolumeDetails(referenceDate: Date) -> some View {
        let totals = appState.weeklyVolumeByBodyPart(referenceDate: referenceDate)
        let total = totals.values.reduce(0, +)
        let groups = totals.filter { $0.value > 0 }.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }
        var displayedGroups = Array(groups.prefix(showAllMuscleVolumeRows ? groups.count : 5))
        if !showAllMuscleVolumeRows && groups.count > 5 {
            displayedGroups.append((key: "Other groups", value: groups.dropFirst(5).reduce(0) { $0 + $1.value }))
        }
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(Int(total.rounded()).formatted()) \(appState.currentProfile.preferredUnit.shortLabel) × reps")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("Share of \(selectedVolumeWeek.rawValue.lowercased())’s recorded weight × reps")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Text("A smaller share does not mean a muscle is underdeveloped.")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
                if groups.isEmpty {
                    Text("No measurable volume load this week. Bodyweight-only and timed sets can still appear in your working-set counts.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                ForEach(displayedGroups, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.key).font(.subheadline)
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text((group.value / total).formatted(.percent.precision(.fractionLength(0))))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Color.liftAccentText)
                                Text(Int(group.value.rounded()).formatted())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        GeometryReader { geometry in
                            Capsule().fill(Color.liftOverlay)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.liftAccentText)
                                        .frame(width: geometry.size.width * group.value / max(total, 1))
                                }
                        }
                        .frame(height: 5)
                        .accessibilityHidden(true)
                    }
                }
                if groups.count > 5 {
                    Button(showAllMuscleVolumeRows ? "Show fewer groups" : "Show all \(groups.count) groups") {
                        showAllMuscleVolumeRows.toggle()
                    }
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                DisclosureGroup("How volume is counted") {
                    Text("Completed non-warmup weight × reps, divided evenly among each exercise’s primary muscles. Each muscle appears once, and the estimated shares add up to the selected week’s total. Percentages show each muscle’s share of volume, not change versus earlier weeks or a measure of muscle development. Bodyweight-only and timed sets are excluded.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 4)
                }
                .font(.caption.weight(.semibold))
                .tint(Color.liftAccentText)
            }
        } label: {
            Text("Estimated volume by muscle")
                .font(.headline)
        }
        .padding(14)
        .liftSurface(radius: 12)
    }
}

struct MuscleTrainingDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkout: CompletedWorkout?
    @State private var showingHistory = false
    let muscle: ExerciseMuscleRegion
    let referenceDate: Date

    var body: some View {
        let weeks = showingHistory ? appState.weeklyWorkingSetsByMuscle(referenceDate: referenceDate) : []
        let contributions = appState.trainingProgressStore.muscleContributions(
            for: muscle, referenceDate: referenceDate,
            customTrainingExercisesRevision: appState.repository.customTrainingExercisesRevision
        )
        let selectedWeek = Calendar.current.dateInterval(of: .weekOfYear, for: referenceDate)
        let peak = max(1, weeks.map { $0.counts[muscle, default: 0] }.max() ?? 0)
        return NavigationStack {
            AppBackground {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Text("Contributing exercises")
                            .font(.headline)
                        if let selectedWeek {
                            Text("\(selectedWeek.start.formatted(.dateTime.month(.abbreviated).day()))–\(selectedWeek.end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day().year()))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                                .accessibilityIdentifier("tracker.muscleDetail.week")
                        }
                        if contributions.isEmpty {
                            Text("No logged primary or secondary work for this muscle in the selected week.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                        ForEach(contributions) { contribution in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(contribution.exercise.exerciseName)
                                    .font(LiftTypography.rowEmphasis)
                                Text("\(contribution.sets.count) \(contribution.isPrimary ? "primary" : "secondary") set\(contribution.sets.count == 1 ? "" : "s") · \(contribution.workout.completedAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                ForEach(contribution.sets) { set in
                                    HStack {
                                        Text("Set \(set.setNumber)")
                                        Spacer()
                                        Text(MeasurementFormatting.workoutSetText(set: set, trackingKind: contribution.trackingKind))
                                            .monospacedDigit()
                                    }
                                    .font(.caption)
                                }
                                Button {
                                    selectedWorkout = contribution.workout
                                } label: {
                                    Label("Open workout · \(contribution.workout.name)", systemImage: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                                }
                                .foregroundStyle(Color.liftAccentText)
                            }
                            .padding(14)
                            .liftSurface(radius: 12)
                        }
                        DisclosureGroup("Four-week workload", isExpanded: $showingHistory) {
                            if showingHistory {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(weeks, id: \.weekStart) { week in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))–\(week.weekEnd.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))")
                                                .font(.subheadline.weight(.semibold))
                                            Text(historyText(week))
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                            if week.hasHistory {
                                                GeometryReader { geometry in
                                                    Capsule().fill(Color.liftOverlay)
                                                        .overlay(alignment: .leading) {
                                                            Capsule().fill(Color.liftAccentText)
                                                                .frame(width: geometry.size.width * Double(week.counts[muscle, default: 0]) / Double(peak))
                                                        }
                                                }
                                                .frame(height: 5)
                                                .accessibilityHidden(true)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 12)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(Color.liftAccentText)
                        .padding(14)
                        .liftSurface(radius: 12)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(muscle.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $selectedWorkout) { workout in
                CompletedWorkoutDetailView(workout: workout)
                    .environmentObject(appState)
            }
        }
    }

    private func historyText(_ week: MuscleTrainingWeek) -> String {
        guard week.hasHistory else { return "No earlier logs · workload unknown" }
        let secondary = week.secondaryCounts[muscle, default: 0]
        let days = week.trainingDays[muscle, default: 0]
        let counts = "\(week.counts[muscle, default: 0]) primary · \(secondary) secondary set\(secondary == 1 ? "" : "s") · \(days) day\(days == 1 ? "" : "s")"
        if week.weekEnd > .now {
            return "\(counts) · In progress\(week.hasFullHistory ? "" : " · First logged week")"
        }
        if !week.hasFullHistory { return "\(counts) · First logged week (partial history)" }
        return counts
    }
}
