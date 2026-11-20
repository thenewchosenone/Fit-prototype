import SwiftUI

struct WorkoutActivityHeatmap: View {
    let workouts: [CompletedWorkout]
    @Binding var period: Int
    @Binding var measure: String
    let unit: UnitSystem
    let catalog: [TrainingExerciseCatalogItem]

    private var startDate: Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -(period - 1), to: .now) ?? .now)
    }

    private var dailyValues: [Date: Double] {
        WorkoutHistoryCalendarData.activityValues(
            workouts: workouts, startDate: startDate, endDate: .now,
            measure: measure, catalog: catalog
        )
    }

    private var days: [Date?] {
        let calendar = Calendar.current
        let leading = (calendar.component(.weekday, from: startDate) - calendar.firstWeekday + 7) % 7
        let dates = (0..<period).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
        let cells = Array(repeating: Optional<Date>.none, count: leading) + dates.map(Optional.some)
        let trailing = (7 - cells.count % 7) % 7
        return cells + Array(repeating: Optional<Date>.none, count: trailing)
    }

    private var weekdayLabels: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let start = max(0, Calendar.current.firstWeekday - 1)
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        let values = dailyValues
        let peak = max(values.values.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training pattern")
                    .font(LiftTypography.cardTitle)
                Spacer()
                Menu {
                    Picker("Activity period", selection: $period) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                    }
                } label: {
                    Label(period == 365 ? "1 year" : "\(period) days", systemImage: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .foregroundStyle(Color.liftAccentText)
                .accessibilityLabel("Activity period")
                .accessibilityValue(period == 365 ? "1 year" : "\(period) days")
            }
            Picker("Activity measure", selection: $measure) {
                Text("Time").tag("Time")
                Text("Volume").tag("Volume")
            }
            .pickerStyle(.segmented)

            GeometryReader { geometry in
                let columns = days.count / 7
                let cellWidth = max(12, (geometry.size.width - 20 - CGFloat(max(0, columns - 1)) * 4) / CGFloat(max(1, columns)))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 4) {
                            Color.clear.frame(width: 16, height: 18)
                            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                                Text(label).font(.caption2).foregroundStyle(Color.liftMuted)
                                    .frame(width: 16, height: 18)
                            }
                        }
                        ForEach(0..<columns, id: \.self) { column in
                            let columnDays = Array(days[(column * 7)..<((column + 1) * 7)])
                            let firstDate = columnDays.compactMap { $0 }.first
                            let previousDate = column > 0 ? days[(column - 1) * 7..<column * 7].compactMap { $0 }.first : nil
                            let startsMonth = firstDate.map { Calendar.current.component(.month, from: $0) } != previousDate.map { Calendar.current.component(.month, from: $0) }
                            VStack(spacing: 4) {
                                Text(startsMonth ? firstDate?.formatted(.dateTime.month(.abbreviated)) ?? "" : "")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(Color.liftMuted)
                                    .fixedSize().frame(width: cellWidth, height: 18, alignment: .leading)
                                ForEach(Array(columnDays.enumerated()), id: \.offset) { _, date in
                                    if let date {
                                        let amount = values[Calendar.current.startOfDay(for: date)] ?? 0
                                        let intensity = Int((amount / peak * 100).rounded())
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(amount == 0 ? Color.liftCardRaised : Color.liftAccentText.opacity(0.22 + 0.78 * min(1, amount / peak)))
                                            .frame(width: cellWidth, height: 18)
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(activityValue(amount)), \(intensity) percent of highest day in this period")
                                    } else { Color.clear.frame(width: cellWidth, height: 18) }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 174)

            HStack {
                Text("\(startDate.formatted(date: .abbreviated, time: .omitted))–\(Date.now.formatted(date: .abbreviated, time: .omitted)) · \(measure == "Time" ? "minutes trained" : "volume (\(unit.shortLabel) × reps)")")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption2)
            .foregroundStyle(Color.liftMuted)
            Text("Based on saved workouts. An empty day means no activity was logged.")
                .font(.caption2).foregroundStyle(Color.liftMuted)
            HStack(spacing: 5) {
                Text("Less")
                ForEach([0, 25, 50, 75, 100], id: \.self) { threshold in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(threshold == 0 ? Color.liftCardRaised : Color.liftAccentText.opacity(0.22 + 0.78 * Double(threshold) / 100))
                        .frame(width: 12, height: 12)
                }
                Text("More")
            }
            .font(.caption2)
            .foregroundStyle(Color.liftMuted)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Logged activity: 0, 25, 50, 75, and 100 percent of the highest day in this period")
        }
        .padding(18)
        .liftSurface(radius: 20)
    }

    private func activityValue(_ value: Double) -> String {
        if measure == "Time" { return "\(Int(value.rounded())) minutes logged" }
        let displayed = MeasurementFormatting.convert(value, from: .kilograms, to: unit)
        return "\(Int(displayed.rounded())) \(unit.shortLabel) × reps volume"
    }
}

struct WorkoutHistoryCalendarDay: Identifiable, Equatable {
    let id: Int
    let date: Date?
    let workoutCount: Int
}

struct WorkoutHistoryCalendarPresentation {
    let workoutCount: Int
    let currentMonth: Date
    let firstBrowsableMonth: Date
    let lastBrowsableMonth: Date
    let calendarDays: [WorkoutHistoryCalendarDay]
    let selectedWorkouts: [CompletedWorkout]
    let mostRecentWorkoutDateByMonth: [Date: Date]
}

enum WorkoutHistoryCalendarData {
    static func activityValues(
        workouts: [CompletedWorkout], startDate: Date, endDate: Date,
        measure: String, catalog: [TrainingExerciseCatalogItem], calendar: Calendar = .current
    ) -> [Date: Double] {
        var values: [Date: Double] = [:]
        for workout in workouts where workout.completedAt >= startDate && workout.completedAt <= endDate && !workout.completedWorkingSets.isEmpty {
            let amount = measure == "Time"
                ? max(0, workout.duration / 60)
                : workout.totalVolume(in: .kilograms, catalog: catalog)
            values[calendar.startOfDay(for: workout.completedAt), default: 0] += amount
        }
        return values
    }

    static func workoutStreaks(
        completedWorkoutDates: [Date],
        referenceDate: Date,
        minimumTrainingDaysPerWeek: Int = 3,
        calendar: Calendar = .current
    ) -> (current: Int, longest: Int) {
        guard minimumTrainingDaysPerWeek > 0,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return (0, 0)
        }

        let trainingDaysByWeek = Dictionary(grouping: completedWorkoutDates.filter { $0 <= referenceDate }) {
            calendar.dateInterval(of: .weekOfYear, for: $0)?.start ?? calendar.startOfDay(for: $0)
        }.mapValues { dates in
            Set(dates.map { calendar.startOfDay(for: $0) }).count
        }
        let qualifyingWeeks = Set(trainingDaysByWeek.compactMap { week, dayCount in
            dayCount >= minimumTrainingDaysPerWeek ? week : nil
        })
        guard !qualifyingWeeks.isEmpty else { return (0, 0) }

        let orderedWeeks = qualifyingWeeks.sorted()
        var longest = 1
        var run = 1
        for index in 1..<orderedWeeks.count {
            let previousWeek = orderedWeeks[index - 1]
            let currentWeek = orderedWeeks[index]
            if calendar.date(byAdding: .weekOfYear, value: 1, to: previousWeek) == currentWeek {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }

        var cursor = qualifyingWeeks.contains(currentWeek.start)
            ? currentWeek.start
            : calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start)
        var current = 0
        while let week = cursor, qualifyingWeeks.contains(week) {
            current += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
        }
        return (current, longest)
    }

    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDay = calendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: 1,
            hour: 12
        )) else {
            return calendar.startOfDay(for: date)
        }
        return calendar.startOfDay(for: firstDay)
    }

    static func days(
        in month: Date,
        workouts: [CompletedWorkout],
        calendar: Calendar = .current
    ) -> [WorkoutHistoryCalendarDay] {
        let counts = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.completedAt) }
            .mapValues(\.count)
        return days(in: month, workoutCountsByDay: counts, calendar: calendar)
    }

    static func days(
        in month: Date,
        workoutCountsByDay: [Date: Int],
        calendar: Calendar = .current
    ) -> [WorkoutHistoryCalendarDay] {
        let monthStart = monthStart(for: month, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7

        var result = (0..<leadingCount).map {
            WorkoutHistoryCalendarDay(id: 7 + $0, date: nil, workoutCount: 0)
        }
        let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)
        for day in dayRange {
            guard let date = calendar.date(from: DateComponents(
                year: monthComponents.year,
                month: monthComponents.month,
                day: day,
                hour: 12
            )) else { continue }
            result.append(
                WorkoutHistoryCalendarDay(
                    id: 7 + result.count,
                    date: date,
                    workoutCount: workoutCountsByDay[calendar.startOfDay(for: date), default: 0]
                )
            )
        }
        let trailingCount = (7 - (result.count % 7)) % 7
        for _ in 0..<trailingCount {
            result.append(WorkoutHistoryCalendarDay(id: 7 + result.count, date: nil, workoutCount: 0))
        }
        return result
    }

    static func workouts(
        on date: Date?,
        from workouts: [CompletedWorkout],
        calendar: Calendar = .current
    ) -> [CompletedWorkout] {
        guard let date else { return [] }
        return workouts
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }
}

struct WorkoutHistoryCalendar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presentation: WorkoutHistoryCalendarPresentation
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let onSelectWorkout: (CompletedWorkout) -> Void
    let onLogWorkout: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let monthStart = WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
        let weekdaySymbols = WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar)
        let monthTitle = Text(LiftTimeFormatter.shortMonthAndYear(monthStart))
            .font(LiftTypography.cardTitle)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout calendar")
                        .font(LiftTypography.rowEmphasis)
                    Text("\(presentation.workoutCount) lifetime workouts")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                if monthStart != presentation.currentMonth {
                    Button("Today") {
                        displayedMonth = presentation.currentMonth
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftAccentText)
                    .frame(minHeight: 44)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                monthTitle
            }
            HStack(spacing: 8) {
                monthButton(symbol: "chevron.left", label: "Previous month", disabled: monthStart <= presentation.firstBrowsableMonth) {
                    moveMonth(by: -1)
                }
                if dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                } else {
                    monthTitle
                }
                monthButton(symbol: "chevron.right", label: "Next month", disabled: monthStart >= presentation.lastBrowsableMonth) {
                    moveMonth(by: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(Color.liftMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(presentation.calendarDays) { day in
                    calendarDay(day)
                }
            }
            // Calendar cells reuse stable positional IDs; invalidate the grid when
            // the month changes so leading days (for example September 1–5) cannot
            // retain the previous month's rendered state.
            .id(monthStart)

            Divider().overlay(Color.liftOverlay)

            selectedDayHistory(presentation.selectedWorkouts)
        }
        .padding(16)
        .liftSurface(radius: 20)
    }

    private func calendarDay(_ day: WorkoutHistoryCalendarDay) -> some View {
        let isSelected: Bool
        if let date = day.date, let selectedDate {
            isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        } else {
            isSelected = false
        }
        let isToday = day.date.map(calendar.isDateInToday) ?? false
        return Button {
            selectedDate = day.date.map(calendar.startOfDay)
        } label: {
            VStack(spacing: 2) {
                Text(day.date.map { String(calendar.component(.day, from: $0)) } ?? "")
                    .font(.caption.weight(isSelected || day.workoutCount > 0 ? .bold : .medium).monospacedDigit())
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.liftOnAccent : day.date == nil ? Color.clear : Color.liftText)
                Circle()
                    .fill(day.workoutCount > 0 ? (isSelected ? Color.liftOnAccent : Color.liftAccentText) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 64 : LiftDesign.minimumTouchTarget)
            .background(isSelected ? Color.liftLime : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.liftAccentText.opacity(0.75), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectedDayHistory(_ selectedWorkouts: [CompletedWorkout]) -> some View {
        if let selectedDate {
            VStack(alignment: .leading, spacing: 0) {
                Text(LiftTimeFormatter.shortDateNoTime(selectedDate))
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.bottom, 4)

                if selectedWorkouts.isEmpty {
                    Text("No completed workouts")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.top, 8)
                } else {
                    ForEach(Array(selectedWorkouts.enumerated()), id: \.element.id) { index, workout in
                        Button {
                            onSelectWorkout(workout)
                        } label: {
                            Group {
                                if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(workout.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftText)
                                            .fixedSize(horizontal: false, vertical: true)
                                        HStack {
                                            Text("\(workout.completedWorkingSets.count) sets • \(LiftTimeFormatter.shortDateCompactTime(workout.completedAt))")
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(LiftTypography.compactEmphasis)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(workout.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.liftText)
                                                .lineLimit(1)
                                            Text("\(workout.completedWorkingSets.count) sets • \(LiftTimeFormatter.shortDateCompactTime(workout.completedAt))")
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Text(MeasurementFormatting.shortDurationText(workout.duration))
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(Color.liftAccentText)
                                        Image(systemName: "chevron.right")
                                            .font(LiftTypography.compactEmphasis)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 88 : 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens completed workout details")

                        if index < selectedWorkouts.count - 1 {
                            Divider().overlay(Color.liftOverlay)
                        }
                    }
                }

                Button {
                    onLogWorkout(selectedDate)
                } label: {
                    Label("Log workout for this day", systemImage: "plus.circle.fill")
                        .font(LiftTypography.rowEmphasis)
                        .foregroundStyle(Color.liftAccentText)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: .now))
                .opacity(calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: .now) ? 0.45 : 1)
            }
        } else {
            Text("Select a date to review past workouts.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 4)
        }
    }

    private func moveMonth(by offset: Int) {
        let monthStart = WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
        guard let destination = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        let normalized = WorkoutHistoryCalendarData.monthStart(for: destination, calendar: calendar)
        guard normalized >= presentation.firstBrowsableMonth,
              normalized <= presentation.lastBrowsableMonth else { return }
        displayedMonth = normalized
        selectedDate = presentation.mostRecentWorkoutDateByMonth[normalized].map(calendar.startOfDay)
    }

    private func monthButton(
        symbol: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(LiftTypography.compactEmphasis)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.liftMuted.opacity(0.3) : Color.liftMuted)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func accessibilityLabel(for day: WorkoutHistoryCalendarDay) -> String {
        guard let date = day.date else { return "Empty calendar day" }
        let workoutText = day.workoutCount == 1 ? "1 completed workout" : "\(day.workoutCount) completed workouts"
        return "\(LiftTimeFormatter.shortDateNoTime(date)), \(workoutText)"
    }

}
