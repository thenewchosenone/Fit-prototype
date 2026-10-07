import SwiftUI

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
    let presentation: WorkoutHistoryCalendarPresentation
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let onSelectWorkout: (CompletedWorkout) -> Void
    let onLogWorkout: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let monthStart = WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
        let weekdaySymbols = WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout calendar")
                        .font(.subheadline.weight(.bold))
                    Text("\(presentation.workoutCount) completed")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                if monthStart != presentation.currentMonth {
                    Button("Today") {
                        displayedMonth = presentation.currentMonth
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                    .frame(minHeight: 44)
                }
            }

            HStack(spacing: 8) {
                monthButton(symbol: "chevron.left", label: "Previous month", disabled: monthStart <= presentation.firstBrowsableMonth) {
                    moveMonth(by: -1)
                }
                Text(LiftTimeFormatter.shortMonthAndYear(monthStart))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                monthButton(symbol: "chevron.right", label: "Next month", disabled: monthStart >= presentation.lastBrowsableMonth) {
                    moveMonth(by: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
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
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                    .foregroundStyle(isSelected ? Color.liftOnAccent : day.date == nil ? Color.clear : Color.liftText)
                Circle()
                    .fill(day.workoutCount > 0 ? (isSelected ? Color.liftOnAccent : Color.liftBlue) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? Color.liftBlue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.liftBlue.opacity(0.75), lineWidth: 1)
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
                    .font(.caption.weight(.bold))
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
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(minHeight: 52)
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
                        .font(.subheadline.weight(.bold))
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
                .font(.caption.weight(.bold))
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
