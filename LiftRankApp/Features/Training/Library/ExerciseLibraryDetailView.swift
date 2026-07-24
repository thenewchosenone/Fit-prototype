import Charts
import SwiftUI

struct ExerciseLibraryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let exercise: TrainingExerciseCatalogItem
    @State private var selectedTab: ExerciseDetailTab = .about
    @State private var chartMetric: ExerciseChartMetric = .estimatedMax
    @State private var selectedWorkout: CompletedWorkout?
    @State private var showsChartTable = false

    private enum ExerciseDetailTab: String, CaseIterable, Identifiable {
        case about = "About"
        case history = "History"
        case records = "Records"
        case charts = "Charts"
        var id: String { rawValue }
    }

    private enum ExerciseChartMetric: String, CaseIterable, Identifiable {
        case estimatedMax = "Est. 1RM"
        case volume = "Volume"
        case heaviest = "Heaviest"
        var id: String { rawValue }
    }

    private var profile: ExerciseMuscleProfile { exercise.resolvedMuscleProfile }
    private var trackingKind: ExerciseTrackingKind { ExerciseTrackingKind(exercise.trackingType) }
    private var splitProfile: ExerciseMuscleProfile {
        ExerciseMuscleProfile(primary: profile.primary, secondary: profile.secondary, orientation: .split)
    }
    private var substitutes: [ExerciseSubstitutionRecommendation] {
        appState.substitutionRecommendations(for: exercise, limit: 5)
    }
    private var demoMediaID: String? {
        exercise.demonstrationMediaID
    }
    private var history: [ExerciseHistoryEntry] { appState.exerciseHistory(for: exercise.id) }
    private var records: ExerciseRecords { appState.exerciseRecords(for: exercise.id) }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let demoMediaID,
                       BundledDemoMediaLibrary.shared.url(for: demoMediaID) != nil {
                        DemoMediaCard(
                            title: exercise.name,
                            subtitle: "\(exercise.equipment) • \(exercise.movementPattern.rawValue)",
                            mediaID: demoMediaID,
                            badge: "Exercise Demo"
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ExerciseMuscleMap(profile: splitProfile, displayStyle: .hero)
                                .frame(height: 230)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(anatomyAccessibilityLabel)
                            Text("Muscles worked")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        .padding(14)
                        .liftSurface()
                    }

                    detailTabs
                    selectedTabContent
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $selectedWorkout) { workout in
            CompletedWorkoutDetailView(workout: workout)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private var detailTabs: some View {
        HStack(spacing: 4) {
            ForEach(ExerciseDetailTab.allCases) { tab in
                Button(tab.rawValue) {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                }
                .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                .foregroundStyle(selectedTab == tab ? Color.liftText : Color.liftMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selectedTab == tab ? Color.liftCardRaised : Color.clear)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.liftCard)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .about: aboutTab
        case .history: historyTab
        case .records: recordsTab
        case .charts: chartsTab
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                compactFact("Muscle group", profile.primaryDescription, symbol: "figure.arms.open")
                compactFact("Equipment", exercise.equipment, symbol: "dumbbell.fill")
            }

            musclesWorkedSection

            if let guidance = exercise.guidance {
                VStack(alignment: .leading, spacing: 14) {
                    Text(guidance.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                    Text("How to perform")
                        .font(.headline)
                    ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.liftBackground)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .clipShape(Circle())
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    if !guidance.cues.isEmpty {
                        Divider().overlay(Color.liftSeparator)
                        Label(guidance.cues.joined(separator: " • "), systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftGold)
                    }
                }
                .padding(16)
                .liftSurface()
            } else {
                LiftCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Technique guidance in review")
                            .font(.headline)
                        Text("Use the anatomy, movement details, and your coach’s guidance for this exercise.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
            }

            VStack(spacing: 0) {
                detailRow("Movement", exercise.movementType)
                Divider().overlay(Color.liftSeparator)
                detailRow("Pattern", exercise.movementPattern.rawValue)
                Divider().overlay(Color.liftSeparator)
                detailRow("Difficulty", exercise.difficulty.title)
                Divider().overlay(Color.liftSeparator)
                detailRow("Tracking", exercise.trackingType)
                Divider().overlay(Color.liftSeparator)
                detailRow("Ranking", exercise.rankingEligibilityLabel)
                Divider().overlay(Color.liftSeparator)
                detailRow("Default", "\(exercise.defaultSets) sets × \(exercise.defaultReps)")
            }
            .padding(.horizontal, 14)
            .liftSurface()

            if !substitutes.isEmpty { substitutesSection }
        }
    }

    private var historyTab: some View {
        Group {
            if history.isEmpty {
                LiftEmptyState(
                    title: "No history yet",
                    message: "Complete this exercise in a workout to see its history here.",
                    symbolName: "clock"
                )
                .padding(.vertical, 44)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                        Button { selectedWorkout = entry.workout } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.workout.completedAt, style: .date)
                                        .font(.subheadline.weight(.bold))
                                    Text("\(entry.sets.count) working sets • \(entry.workout.name)")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(bestSetText(entry))
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                    Text("Best set")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < history.count - 1 {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                        }
                    }
                }
                .liftSurface()
            }
        }
    }

    private var recordsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal records")
                .font(.headline)
            VStack(spacing: 0) {
                if trackingKind == .weightReps {
                    recordRow("Best estimated 1RM", weightText(records.bestEstimatedOneRepMaxKilograms), symbol: "trophy.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Best session volume", volumeText(records.bestSessionVolumeKilograms), symbol: "chart.bar.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Best set volume", volumeText(records.bestSetVolumeKilograms), symbol: "square.stack.3d.up.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Heaviest weight", weightText(records.heaviestWeightKilograms), symbol: "dumbbell.fill")
                } else {
                    recordRow(trackingKind.usesDuration ? "Best duration" : "Best reps", repOrDurationText(records.mostRepetitions), symbol: "trophy.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Completed sets", "\(history.flatMap(\.sets).count)", symbol: "checkmark.circle.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow(trackingKind.usesDuration ? "Total duration" : "Total reps", repOrDurationText(history.flatMap(\.sets).compactMap(\.reps).reduce(0, +)), symbol: "sum")
                }
            }
            .padding(.horizontal, 14)
            .liftSurface()
            Text(recordsFootnote)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
    }

    private var chartsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Chart metric", selection: $chartMetric) {
                ForEach(chartMetricOptions) { Text(chartMetricTitle($0)).tag($0) }
            }
            .pickerStyle(.segmented)

            if chartEntries.isEmpty {
                LiftEmptyState(
                    title: "Not enough data",
                    message: trackingKind == .weightReps ? "Complete weighted working sets to build this chart." : "Complete working sets to build this chart.",
                    symbolName: "chart.xyaxis.line"
                )
                .padding(.vertical, 44)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Chart(chartEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.workout.completedAt),
                            y: .value(chartMetricTitle(chartMetric), chartValue(entry))
                        )
                        .foregroundStyle(Color.liftBlue)
                        PointMark(
                            x: .value("Date", entry.workout.completedAt),
                            y: .value(chartMetricTitle(chartMetric), chartValue(entry))
                        )
                        .foregroundStyle(Color.liftGold)
                    }
                    .frame(height: 220)
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .accessibilityLabel("\(exercise.name) \(chartMetricTitle(chartMetric)) chart with \(chartEntries.count) workouts")

                    DisclosureGroup("Show data table", isExpanded: $showsChartTable) {
                        VStack(spacing: 0) {
                            ForEach(chartEntries.suffix(8)) { entry in
                                HStack {
                                    Text(entry.workout.completedAt, style: .date)
                                    Spacer()
                                    Text(chartDisplayValue(entry))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                }
                                .font(.caption)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.liftBlue)
                }
                .padding(14)
                .liftSurface()
            }
        }
    }

    private var chartEntries: [ExerciseHistoryEntry] {
        history.reversed().filter { chartValue($0) > 0 }
    }

    private var chartMetricOptions: [ExerciseChartMetric] {
        trackingKind == .weightReps ? ExerciseChartMetric.allCases : [.estimatedMax]
    }

    private func chartMetricTitle(_ metric: ExerciseChartMetric) -> String {
        guard trackingKind != .weightReps else { return metric.rawValue }
        return trackingKind.usesDuration ? "Best duration" : "Best reps"
    }

    private func chartValue(_ entry: ExerciseHistoryEntry) -> Double {
        guard trackingKind == .weightReps else { return Double(entry.bestRepetitions ?? 0) }
        switch chartMetric {
        case .estimatedMax: return displayWeight(entry.estimatedOneRepMaxKilograms ?? 0)
        case .volume: return displayWeight(entry.sessionVolumeKilograms)
        case .heaviest: return displayWeight(entry.bestWeightKilograms ?? 0)
        }
    }

    private func chartDisplayValue(_ entry: ExerciseHistoryEntry) -> String {
        guard trackingKind == .weightReps else { return repOrDurationText(entry.bestRepetitions) }
        return chartMetric == .volume ? volumeText(entry.sessionVolumeKilograms) : weightText(chartMetric == .estimatedMax ? entry.estimatedOneRepMaxKilograms : entry.bestWeightKilograms)
    }

    private func compactFact(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Color.liftBlue)
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.subheadline.weight(.bold)).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .liftSurface()
    }

    private var substitutesSection: some View {
        NavigationLink {
            SubstituteExerciseListView(sourceExercise: exercise, recommendations: substitutes)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Find a substitute").font(.headline)
                        Text("Browse \(substitutes.count) similar exercises")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }

                HStack(spacing: -7) {
                    ForEach(substitutes.prefix(3)) { recommendation in
                        ExerciseCatalogIcon(exercise: recommendation.exercise)
                            .frame(width: 38, height: 38)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(Color.liftBackground, lineWidth: 2) }
                    }
                    Spacer()
                    Text(substitutes.prefix(2).map(\.exercise.name).joined(separator: " • "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Find a substitute for \(exercise.name), \(substitutes.count) recommendations")
        .accessibilityIdentifier("exercise.findSubstitute")
    }

    private func recordRow(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.liftGold).frame(width: 26)
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.bold).monospacedDigit())
        }
        .frame(minHeight: 56)
    }

    private func bestSetText(_ entry: ExerciseHistoryEntry) -> String {
        guard trackingKind == .weightReps else { return repOrDurationText(entry.bestRepetitions) }
        guard let weight = entry.bestWeightKilograms, let reps = entry.bestRepetitions else { return "—" }
        return "\(RankingCalculator.format(displayWeight(weight))) \(displayUnit) × \(reps)"
    }

    private func weightText(_ kilograms: Double?) -> String {
        guard let kilograms, kilograms > 0 else { return "—" }
        return "\(RankingCalculator.format(displayWeight(kilograms))) \(displayUnit)"
    }

    private func volumeText(_ kilograms: Double?) -> String {
        guard let kilograms, kilograms > 0 else { return "—" }
        return "\(RankingCalculator.format(displayWeight(kilograms))) \(displayUnit)"
    }

    private func repOrDurationText(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        return trackingKind.usesDuration ? MeasurementFormatting.shortClockText(TimeInterval(value)) : "\(value) \(value == 1 ? "rep" : "reps")"
    }

    private var recordsFootnote: String {
        trackingKind == .weightReps
            ? "Records use completed working sets only. Estimated 1RM is informational and is not a recommendation to attempt that weight."
            : "Records use completed working sets only. Time-based exercises store duration in seconds."
    }

    private var musclesWorkedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscles worked")
                .font(.headline)
            muscleChipGroup("Primary", regions: profile.primary, color: Color.liftBlue)
            if !profile.secondary.isEmpty {
                muscleChipGroup("Secondary", regions: profile.secondary, color: Color.liftGreen)
            }
        }
        .padding(14)
        .liftSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(anatomyAccessibilityLabel)
    }

    private func muscleChipGroup(_ title: String, regions: [ExerciseMuscleRegion], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Color.liftMuted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(regions) { region in
                    Text(region.displayName)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(Color.liftText)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(color.opacity(0.16))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(color.opacity(0.35), lineWidth: 1)
                        }
                }
            }
        }
    }

    private func displayWeight(_ kilograms: Double) -> Double {
        appState.currentProfile.preferredUnit == .kilograms ? kilograms : RankingCalculator.kilogramsToPounds(kilograms)
    }

    private var displayUnit: String { appState.currentProfile.preferredUnit.shortLabel }

    private var anatomyAccessibilityLabel: String {
        let secondary = profile.secondary.isEmpty ? "" : "; secondary muscles \(profile.secondaryDescription)"
        return "Muscles worked. Primary muscles \(profile.primaryDescription)\(secondary)."
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 50)
    }
}
