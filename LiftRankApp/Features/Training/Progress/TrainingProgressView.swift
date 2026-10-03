import Charts
import SwiftUI

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
        let bodyweightEntries = recentBodyweightEntries
        let weekCompletion = selectedWeek.map(appState.weekCompletion(for:))
        let historyPresentation = appState.workoutHistoryPresentation(
            displayedMonth: workoutHistoryMonth,
            selectedDate: selectedWorkoutHistoryDate
        )
        let exerciseOptions = appState.progressExerciseOptions()

        return LazyVStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.weight(.black))

            if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                strainAndInjurySection
            }

            workoutHistorySection(presentation: historyPresentation)

            if !exerciseOptions.isEmpty {
                exerciseProgressSection(options: exerciseOptions)
            }

            if let week = selectedWeek {
                let completion = weekCompletion ?? 0
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(week.title) completion")
                                .font(.subheadline.weight(.bold))
                            Text("\(Int(completion * 100))% of exercises completed")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Text("\(Int(completion * 100))%")
                            .font(.headline.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.liftGreen)
                    }
                    ProgressView(value: completion)
                        .tint(Color.liftGreen)
                }
                .padding(14)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Weekly volume by body part")
                            .font(.headline.weight(.bold))
                        Text("Training load from completed working sets")
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
                    Text("Complete workout sets to build volume insights.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.vertical, 8)
                } else {
                    HStack(spacing: 10) {
                        volumeSummary(
                            title: "TOTAL VOLUME",
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
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            HStack(alignment: .center) {
                Text("Bodyweight")
                    .font(.title3.weight(.black))
                Spacer()
                Button {
                    logBodyweightEntry()
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.black)
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
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            bodyweightTable(entries: bodyweightEntries)
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
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
                            .fill(Color.white.opacity(0.08))
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
            selectedCompletedWorkout = workout
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
        let prs = MeasurementFormatting.bestPRsByReps(from: setPoints)
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
                        Button(option.name) { selectedProgressExerciseID = option.id }
                    }
                } label: {
                    Label(exercise?.name ?? "Exercise", systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
                }
            }

            if chartPoints.isEmpty {
                Text("Complete sets for this exercise to build its trend.")
                    .font(.caption)
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
                }

                Text("Weight trend")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                    .padding(.top, 2)

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
                            .background(Color.black.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
            selectedWorkoutHistoryDate = nil
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
            if entries.contains(where: { $0.actual != nil }) {
                Chart(entries) { row in
                    if let actual = row.actual {
                        let displayValue = MeasurementFormatting.displayBodyweightValue(
                            actual,
                            preferredUnit: appState.currentProfile.preferredUnit
                        )
                        LineMark(x: .value("Week", row.week), y: .value("Bodyweight", displayValue))
                            .foregroundStyle(Color.liftAccentText)
                        PointMark(x: .value("Week", row.week), y: .value("Bodyweight", displayValue))
                            .foregroundStyle(Color.liftGreen)
                    }
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
                            .foregroundStyle(Color.black)
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
                            .overlay(Color.white.opacity(0.07))
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var recentBodyweightEntries: [BodyweightEntry] {
        let limit = 5
        return appState.bodyweightEntries
            .sorted { $0.targetDate < $1.targetDate }
            .suffix(limit)
            .map { $0 }
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
