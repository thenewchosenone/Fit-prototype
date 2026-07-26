import SwiftUI

struct WorkoutHistoryCalendarDay: Identifiable, Equatable {
    let id: Int
    let date: Date?
    let workoutCount: Int
}

enum WorkoutHistoryCalendarData {
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func days(
        in month: Date,
        workouts: [CompletedWorkout],
        calendar: Calendar = .current
    ) -> [WorkoutHistoryCalendarDay] {
        let monthStart = monthStart(for: month, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
        let counts = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.completedAt) }
            .mapValues(\.count)

        var result = (0..<leadingCount).map {
            WorkoutHistoryCalendarDay(id: $0, date: nil, workoutCount: 0)
        }
        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            result.append(
                WorkoutHistoryCalendarDay(
                    id: result.count,
                    date: date,
                    workoutCount: counts[calendar.startOfDay(for: date), default: 0]
                )
            )
        }
        let trailingCount = (7 - (result.count % 7)) % 7
        for _ in 0..<trailingCount {
            result.append(WorkoutHistoryCalendarDay(id: result.count, date: nil, workoutCount: 0))
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
    let workouts: [CompletedWorkout]
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let onSelectWorkout: (CompletedWorkout) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthStart: Date {
        WorkoutHistoryCalendarData.monthStart(for: displayedMonth, calendar: calendar)
    }

    private var currentMonth: Date {
        WorkoutHistoryCalendarData.monthStart(for: .now, calendar: calendar)
    }

    private var earliestMonth: Date {
        workouts.map(\.completedAt).min().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        } ?? currentMonth
    }

    private var latestMonth: Date {
        workouts.map(\.completedAt).max().map {
            WorkoutHistoryCalendarData.monthStart(for: $0, calendar: calendar)
        } ?? currentMonth
    }

    private var firstBrowsableMonth: Date { min(earliestMonth, currentMonth) }
    private var lastBrowsableMonth: Date { max(latestMonth, currentMonth) }

    private var calendarDays: [WorkoutHistoryCalendarDay] {
        WorkoutHistoryCalendarData.days(in: monthStart, workouts: workouts, calendar: calendar)
    }

    private var selectedWorkouts: [CompletedWorkout] {
        WorkoutHistoryCalendarData.workouts(on: selectedDate, from: workouts, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout calendar")
                        .font(.subheadline.weight(.bold))
                    Text("\(workouts.count) completed")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                if monthStart != currentMonth {
                    Button("Today") {
                        displayedMonth = currentMonth
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: 44)
                }
            }

            HStack(spacing: 8) {
                monthButton(symbol: "chevron.left", label: "Previous month", disabled: monthStart <= firstBrowsableMonth) {
                    moveMonth(by: -1)
                }
                Text(LiftTimeFormatter.shortMonthAndYear(monthStart))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                monthButton(symbol: "chevron.right", label: "Next month", disabled: monthStart >= lastBrowsableMonth) {
                    moveMonth(by: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    calendarDay(day)
                }
            }

            Divider().overlay(Color.white.opacity(0.07))

            selectedDayHistory
        }
        .padding(14)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
    private var selectedDayHistory: some View {
        if workouts.isEmpty {
            Text("Finish a workout to begin your training history.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 4)
        } else if let selectedDate {
            VStack(alignment: .leading, spacing: 0) {
                Text(LiftTimeFormatter.shortDateNoTime(selectedDate))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                    .padding(.bottom, 4)

                if selectedWorkouts.isEmpty {
                    Text("No completed workouts")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.vertical, 8)
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
                                    .foregroundStyle(Color.liftBlue)
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
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        } else {
            Text("Select a date to review past workouts.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 4)
        }
    }

    private func moveMonth(by offset: Int) {
        guard let destination = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        let normalized = WorkoutHistoryCalendarData.monthStart(for: destination, calendar: calendar)
        guard normalized >= firstBrowsableMonth, normalized <= lastBrowsableMonth else { return }
        displayedMonth = normalized
        selectedDate = workouts
            .filter { calendar.isDate($0.completedAt, equalTo: normalized, toGranularity: .month) }
            .max(by: { $0.completedAt < $1.completedAt })
            .map { calendar.startOfDay(for: $0.completedAt) }
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
