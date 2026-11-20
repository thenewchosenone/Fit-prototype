import Charts
import SwiftUI

struct ExerciseLibraryDetailView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exercise: TrainingExerciseCatalogItem
    private let machineLoadType: MachineLoadType?
    private let filtersByMachineLoadType: Bool
    @State private var selectedTab: ExerciseDetailTab = .about
    @State private var chartMetric: ExerciseChartMetric = .estimatedMax
    @State private var selectedWorkout: CompletedWorkout?
    @State private var showsChartTable = false
    @State private var chartPeriod = "3M"

    init(
        exercise: TrainingExerciseCatalogItem,
        startsOnHistory: Bool = false,
        machineLoadType: MachineLoadType? = nil,
        filtersByMachineLoadType: Bool = false
    ) {
        self.exercise = exercise
        self.machineLoadType = machineLoadType
        self.filtersByMachineLoadType = filtersByMachineLoadType
        _selectedTab = State(initialValue: startsOnHistory ? .history : .about)
    }

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
    private var history: [ExerciseHistoryEntry] {
        let entries = appState.exerciseHistory(for: exercise.id)
        guard filtersByMachineLoadType else { return entries }
        return entries.filter { entry in
            entry.workout.exercises.first(where: { $0.exerciseID == exercise.id })?.machineLoadType == machineLoadType
        }
    }
    private var records: ExerciseRecords {
        guard filtersByMachineLoadType else { return appState.exerciseRecords(for: exercise.id) }
        let sets = history.flatMap(\.sets).compactMap { set -> (weight: Double, reps: Int, workoutID: UUID?)? in
            guard let weight = set.weight, weight > 0, let reps = set.reps, reps > 0 else { return nil }
            let kilograms = set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
            return (kilograms, reps, set.workoutID)
        }
        let estimatedMaxes = sets.filter { (1...10).contains($0.reps) }.map {
            (value: RankingCalculator.epleyOneRepMax(weight: $0.weight, repetitions: $0.reps), workoutID: $0.workoutID)
        }
        return ExerciseRecords(
            bestEstimatedOneRepMaxKilograms: estimatedMaxes.max { $0.value < $1.value }?.value,
            bestSessionVolumeKilograms: history.map(\.sessionVolumeKilograms).filter { $0 > 0 }.max(),
            bestSetVolumeKilograms: sets.map { $0.weight * Double($0.reps) }.max(),
            heaviestWeightKilograms: sets.map(\.weight).max(),
            mostRepetitions: history.compactMap(\.bestRepetitions).max(),
            estimatedMaxWorkoutID: estimatedMaxes.max { $0.value < $1.value }?.workoutID
        )
    }
    private var repDBImageURL: URL? { RepDBExerciseMedia.imageURL(for: exercise.id) }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(exercise.name)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    detailTabs
                    if filtersByMachineLoadType {
                        Text("\(machineLoadType?.rawValue ?? "Unselected machine setup") history")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    selectedTabContent
                    if selectedTab == .about {
                        DisclosureGroup("Muscles worked") { exerciseMedia }
                    }
                }
                .padding(16)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $selectedWorkout) { workout in
            CompletedWorkoutDetailView(workout: workout)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private var exerciseMedia: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Muscles worked")
                .font(.headline)
            if let repDBImageURL {
                VStack(alignment: .leading, spacing: 6) {
                    AsyncImage(url: repDBImageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Text("Illustration unavailable")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 180)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Link(RepDBExerciseMedia.attribution, destination: URL(string: "https://repdb.co")!)
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ExerciseMuscleMap(profile: splitProfile, displayStyle: .hero)
                    .frame(height: 230)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(anatomyAccessibilityLabel)
                muscleChipGroup("Primary", regions: profile.primary, color: Color.liftBlue)
                if !profile.secondary.isEmpty {
                    muscleChipGroup("Secondary", regions: profile.secondary, color: Color.liftGreen)
                }
            }
            .padding(14)
            .liftSurface()
        }
    }

    private var detailTabs: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(ExerciseDetailTab.allCases) { tab in
                        detailTabButton(tab)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(ExerciseDetailTab.allCases) { tab in
                        detailTabButton(tab)
                    }
                }
            }
        }
        .padding(4)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 18 : 40, style: .continuous))
    }

    private func detailTabButton(_ tab: ExerciseDetailTab) -> some View {
        Button(tab.rawValue) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { selectedTab = tab }
        }
        .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
        .foregroundStyle(selectedTab == tab ? Color.liftText : Color.liftMuted)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(selectedTab == tab ? Color.liftCardRaised : Color.clear)
        .clipShape(Capsule())
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftOnAccent)
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
                        Text("Technique guide unavailable")
                            .font(.headline)
                        Text("Use the anatomy, movement details, and your coach’s guidance for this exercise.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
            }

            DisclosureGroup("Exercise details") {
                VStack(spacing: 0) {
                    detailRow("Pattern", exercise.movementPattern.rawValue)
                    Divider().overlay(Color.liftSeparator)
                    detailRow("Equipment", exercise.equipment)
                    Divider().overlay(Color.liftSeparator)
                    detailRow("Difficulty", exercise.difficulty.title)
                    Divider().overlay(Color.liftSeparator)
                    detailRow("Tracking", exercise.trackingType)
                    Divider().overlay(Color.liftSeparator)
                    detailRow("Ranking", exercise.rankingEligibilityLabel)
                    Divider().overlay(Color.liftSeparator)
                    detailRow("Suggested sets and reps", "\(exercise.defaultSets) sets × \(exercise.defaultReps)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .liftSurface()
            }
            .font(.headline)
            .tint(Color.liftAccentText)

            if !substitutes.isEmpty { substitutesSection }
        }
    }

    private var historyTab: some View {
        let entries = history
        return Group {
            if entries.isEmpty {
                LiftEmptyState(
                    title: "No history yet",
                    message: "Complete this exercise in a workout to see its history here.",
                    symbolName: "clock"
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button { selectedWorkout = entry.workout } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.workout.completedAt, style: .date)
                                        .font(LiftTypography.rowEmphasis)
                                    Text("\(entry.sets.count) working \(entry.sets.count == 1 ? "set" : "sets") • \(entry.workout.name)")
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
                                    .font(LiftTypography.compactEmphasis)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < entries.count - 1 {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                        }
                    }
                }
                .liftSurface()
            }
        }
    }

    private var recordsTab: some View {
        let exerciseRecords = records
        let entries = history
        return VStack(alignment: .leading, spacing: 12) {
            Text("Personal records")
                .font(.headline)
            VStack(spacing: 0) {
                if trackingKind == .weightReps {
                    recordRow("Best estimated 1RM", weightText(exerciseRecords.bestEstimatedOneRepMaxKilograms), symbol: "trophy.fill", workoutID: exerciseRecords.estimatedMaxWorkoutID)
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Best session volume", volumeText(exerciseRecords.bestSessionVolumeKilograms), symbol: "chart.bar.fill", workoutID: exerciseRecords.sessionVolumeWorkoutID)
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Best set volume", volumeText(exerciseRecords.bestSetVolumeKilograms), symbol: "square.stack.3d.up.fill", workoutID: exerciseRecords.setVolumeWorkoutID)
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Heaviest weight", weightText(exerciseRecords.heaviestWeightKilograms), symbol: "dumbbell.fill", workoutID: exerciseRecords.heaviestWeightWorkoutID)
                } else {
                    recordRow(trackingKind.usesDuration ? "Best duration" : "Best reps", repOrDurationText(exerciseRecords.mostRepetitions), symbol: "trophy.fill", workoutID: exerciseRecords.repetitionsWorkoutID)
                    Divider().overlay(Color.liftSeparator)
                    recordRow("Completed sets", "\(entries.flatMap(\.sets).count)", symbol: "checkmark.circle.fill")
                    Divider().overlay(Color.liftSeparator)
                    recordRow(trackingKind.usesDuration ? "Total duration" : "Total reps", repOrDurationText(entries.flatMap(\.sets).compactMap(\.reps).reduce(0, +)), symbol: "sum")
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
        let entries = chartEntries
        return VStack(alignment: .leading, spacing: 14) {
            if !history.isEmpty {
            Picker("Chart metric", selection: $chartMetric) {
                ForEach(chartMetricOptions) { Text(chartMetricTitle($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Chart period", selection: $chartPeriod) {
                ForEach(["1M", "3M", "1Y", "All"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            }
            if entries.isEmpty {
                LiftEmptyState(
                    title: "Not enough data",
                    message: trackingKind == .weightReps ? "Complete weighted working sets to build this chart." : "Complete working sets to build this chart.",
                    symbolName: "chart.xyaxis.line"
                )
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let latest = entries.last, let first = entries.first {
                        Text("Latest \(chartMetricTitle(chartMetric)): \(chartDisplayValue(latest))")
                            .font(.subheadline.weight(.semibold))
                        Text("Includes completed working sets from recovery/deload workouts.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Text("\(first.workout.completedAt.formatted(date: .abbreviated, time: .omitted)) – \(latest.workout.completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Chart(entries) { entry in
                        LineMark(
                            x: .value("Date", entry.workout.completedAt),
                            y: .value(chartMetricTitle(chartMetric), chartValue(entry))
                        )
                        .foregroundStyle(Color.liftAccentText)
                        PointMark(
                            x: .value("Date", entry.workout.completedAt),
                            y: .value(chartMetricTitle(chartMetric), chartValue(entry))
                        )
                        .foregroundStyle(Color.liftGold)
                    }
                    .frame(height: 220)
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .chartYAxisLabel(trackingKind == .weightReps ? (chartMetric == .volume ? "\(displayUnit) × reps" : displayUnit) : (trackingKind.usesDuration ? "seconds" : "reps"), position: .trailing)
                    .chartXScale(range: .plotDimension(padding: 24))
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                    } }
                    .accessibilityLabel("\(exercise.name) \(chartMetricTitle(chartMetric)) chart with \(entries.count) workouts")

                    DisclosureGroup("Show data table", isExpanded: $showsChartTable) {
                        VStack(spacing: 0) {
                            ForEach(entries) { entry in
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
                    .tint(Color.liftAccentText)
                }
                .padding(14)
                .liftSurface()
            }
        }
    }

    private var chartEntries: [ExerciseHistoryEntry] {
        let days = ["1M": 30, "3M": 90, "1Y": 365][chartPeriod]
        let cutoff = days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) } ?? .distantPast
        return history.reversed().filter { chartValue($0) > 0 && $0.workout.completedAt >= cutoff }
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
        case .heaviest: return displayWeight(heaviestWeight(in: entry) ?? 0)
        }
    }

    private func chartDisplayValue(_ entry: ExerciseHistoryEntry) -> String {
        guard trackingKind == .weightReps else { return repOrDurationText(entry.bestRepetitions) }
        return chartMetric == .volume ? volumeText(entry.sessionVolumeKilograms) : weightText(chartMetric == .estimatedMax ? entry.estimatedOneRepMaxKilograms : heaviestWeight(in: entry))
    }

    private func heaviestWeight(in entry: ExerciseHistoryEntry) -> Double? {
        entry.sets.compactMap { set -> Double? in
            guard let weight = set.weight, weight > 0 else { return nil }
            return set.recordedUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
        }.max()
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
                        .font(LiftTypography.compactEmphasis)
                        .foregroundStyle(Color.liftAccentText)
                }

                Text(substitutes.prefix(2).map(\.exercise.name).joined(separator: " • "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .contentShape(Rectangle())
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Find a substitute for \(exercise.name), \(substitutes.count) recommendations")
        .accessibilityIdentifier("exercise.findSubstitute")
    }

    @ViewBuilder
    private func recordRow(_ title: String, _ value: String, symbol: String, workoutID: UUID? = nil) -> some View {
        let row = HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.liftGold).frame(width: 26)
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.bold).monospacedDigit())
        }
        .frame(minHeight: 56)
        if let workoutID, let workout = history.first(where: { $0.workout.id == workoutID })?.workout {
            Button { selectedWorkout = workout } label: {
                VStack(alignment: .leading, spacing: 0) {
                    row
                    HStack {
                        Text(workout.completedAt.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Label("View workout", systemImage: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.liftAccentText)
                    .padding(.bottom, 10)
                }
            }
            .buttonStyle(.plain)
        } else { row }
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
        return "\(RankingCalculator.format(displayWeight(kilograms))) \(displayUnit) × reps"
    }

    private func repOrDurationText(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        return trackingKind.usesDuration ? MeasurementFormatting.shortClockText(TimeInterval(value)) : "\(value) \(value == 1 ? "rep" : "reps")"
    }

    private var recordsFootnote: String {
        trackingKind == .weightReps
            ? "Records use completed working sets only. Estimated 1RM is informational and is not a recommendation to attempt that weight."
            : "Records use completed working sets only. For timed exercises, duration is shown as minutes and seconds."
    }

    private func muscleChipGroup(_ title: String, regions: [ExerciseMuscleRegion], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(LiftTypography.compactEmphasis)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Color.liftMuted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(regions) { region in
                    Text(region.displayName)
                        .font(LiftTypography.compactEmphasis)
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
