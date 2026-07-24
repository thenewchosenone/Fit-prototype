import Charts
import SwiftUI

extension TrainingTrackerView {
    var progress: some View {
        let totals = appState.weeklyVolumeByBodyPart()
        let maxVolume = max(1, totals.values.max() ?? 1)
        let totalVolume = totals.values.reduce(0, +)
        let rankedTotals = totals
            .map { (bodyPart: $0.key, value: $0.value) }
            .sorted {
                if $0.value == $1.value { return $0.bodyPart < $1.bodyPart }
                return $0.value > $1.value
            }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.weight(.black))

            if !appState.strainEntries.isEmpty || !appState.injuryEntries.isEmpty {
                strainAndInjurySection
            }

            workoutHistorySection

            if !progressExerciseOptions.isEmpty {
                exerciseProgressSection
            }

            if let week = selectedWeek {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(week.title) completion")
                                .font(.subheadline.weight(.bold))
                            Text("\(Int(appState.weekCompletion(for: week) * 100))% of exercises completed")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Text("\(Int(appState.weekCompletion(for: week) * 100))%")
                            .font(.headline.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.liftGreen)
                    }
                    ProgressView(value: appState.weekCompletion(for: week))
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
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.liftBlue)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(Color.liftBlue.opacity(0.12))
                        .clipShape(Capsule())
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

            VStack(alignment: .leading, spacing: 8) {
                if recentBodyweightEntries.contains(where: { $0.actual != nil }) {
                    Chart(recentBodyweightEntries) { row in
                        if let actual = row.actual {
                            let displayValue = MeasurementFormatting.displayBodyweightValue(
                                actual,
                                preferredUnit: appState.currentProfile.preferredUnit
                            )
                            LineMark(x: .value("Week", row.week), y: .value("Bodyweight", displayValue))
                                .foregroundStyle(Color.liftBlue)
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
                            .foregroundStyle(Color.liftBlue)
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
            .padding(12)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            bodyweightTable
        }
        .onAppear {
            if selectedProgressExerciseID == nil {
                selectedProgressExerciseID = progressExerciseOptions.first?.id
            }
            syncWorkoutHistorySelection()
        }
        .onChange(of: appState.completedWorkouts.count) {
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
                .foregroundStyle(Color.liftBlue)
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

    private var workoutHistorySection: some View {
        WorkoutHistoryCalendar(
            workouts: completedTrainingHistoryWorkouts,
            displayedMonth: $workoutHistoryMonth,
            selectedDate: $selectedWorkoutHistoryDate
        ) { workout in
            selectedCompletedWorkout = workout
        }
    }

    private var exerciseProgressSection: some View {
        let exerciseID = selectedProgressExerciseID ?? progressExerciseOptions.first?.id
        let exercise = progressExerciseOptions.first { $0.id == exerciseID }
        let setPoints = exercise.map { exerciseProgressPoints(for: $0.id) } ?? []
        let chartPoints = ExerciseProgressSeries.dailyHighest(from: setPoints)
        let prs = MeasurementFormatting.bestPRsByReps(from: setPoints)

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
                    ForEach(progressExerciseOptions) { option in
                        Button(option.name) { selectedProgressExerciseID = option.id }
                    }
                } label: {
                    Label(exercise?.name ?? "Exercise", systemImage: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
            }

            if chartPoints.isEmpty {
                Text("Complete sets for this exercise to build its trend.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftBlue)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.liftGreen)
                }
                .frame(height: 150)
                .chartYAxis { AxisMarks(position: .trailing) }

                if !prs.isEmpty {
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

    private var strainAndInjurySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Strain & injuries")
                .font(.headline.weight(.bold))

            if let latestStrain = appState.latestStrainEntry {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftBlue)
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
                                .foregroundStyle(Color.liftBlue)
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

            if activeInjuryEntries.isEmpty {
                Text("No active injuries tracked.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(activeInjuryEntries) { injury in
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
        appState.completedWorkouts.filter { !$0.completedWorkingSets.isEmpty }
    }

    private var progressExerciseOptions: [TrainingExerciseCatalogItem] {
        let IDs = Set(completedTrainingHistoryWorkouts.flatMap { $0.exercises.map(\.exerciseID) })
        return appState.trainingExerciseLibrary.filter { IDs.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private func exerciseProgressPoints(for exerciseID: String) -> [ExerciseProgressPoint] {
        WorkoutProgressPresentation.progressPoints(
            from: completedTrainingHistoryWorkouts,
            exerciseID: exerciseID,
            preferredUnit: appState.currentProfile.preferredUnit
        )
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

    private var bodyweightTable: some View {
        VStack(spacing: 0) {
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

            ForEach(Array(recentBodyweightEntries.enumerated()), id: \.offset) { index, row in
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
                                    .foregroundStyle(Color.liftBlue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                Text(MeasurementFormatting.formatBodyweightOrDash(row.actual, preferredUnit: appState.currentProfile.preferredUnit))
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
                .accessibilityLabel("Week \(row.week), \(MeasurementFormatting.formatBodyweightOrDash(row.actual, preferredUnit: appState.currentProfile.preferredUnit)), edit")

                if index < recentBodyweightEntries.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.07))
                        .padding(.leading, 68)
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

    private var activeInjuryEntries: [InjuryEntry] {
        appState.injuryEntries
            .filter { $0.status != .resolved }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private var recentStrainEntries: [StrainEntry] {
        appState.strainEntries
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(5)
            .map { $0 }
    }
}
