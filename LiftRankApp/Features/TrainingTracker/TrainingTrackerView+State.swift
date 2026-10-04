import Foundation

extension TrainingTrackerView {
    enum VolumeWeekSelection: String, CaseIterable, Identifiable {
        case thisWeek = "This week"
        case lastWeek = "Last week"

        var id: String { rawValue }

        var referenceDate: Date {
            switch self {
            case .thisWeek:
                return .now
            case .lastWeek:
                return Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now) ?? .now
            }
        }
    }

    enum TrackerSegment: String, CaseIterable, Hashable {
        case today = "Today"
        case plans = "Plans"
        case library = "Library"
        case progress = "Progress"

        var symbol: String {
            switch self {
            case .today: return "play.fill"
            case .plans: return "folder.fill"
            case .library: return "dumbbell.fill"
            case .progress: return "chart.bar.fill"
            }
        }
    }

    var selectedPlanName: String {
        appState.selectedWorkoutPlan?.name ?? "No plan selected"
    }

    var selectedProgramSettings: WorkoutPlanProgressionSettings? {
        appState.workoutPlanProgressionSettings.first { $0.planID == appState.selectedWorkoutPlanID }
    }

    var selectedWeek: WorkoutWeek? {
        if let selectedWeekID,
           let week = appState.selectedPlanWeeks.first(where: { $0.id == selectedWeekID }) {
            return week
        }
        return appState.currentSelectedProgramWeek ?? appState.selectedPlanWeeks.first
    }

    var primaryScheduledSession: WorkoutSession? {
        todayScheduledWorkout?.session
    }

    var todayScheduledWorkout: (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        let today = Calendar.current.startOfDay(for: .now)
        let todaysWorkouts = scheduledWorkoutRows.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        return todaysWorkouts.first(where: { !isWorkoutSessionComplete($0.session) }) ?? todaysWorkouts.first
    }

    var missedScheduledWorkout: (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        let today = Calendar.current.startOfDay(for: .now)
        return scheduledWorkoutRows
            .filter { $0.date < today && !isWorkoutSessionComplete($0.session) }
            .last
    }

    var nextScheduledWorkout: (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        let today = Calendar.current.startOfDay(for: .now)
        return scheduledWorkoutRows.first { $0.date > today && !isWorkoutSessionComplete($0.session) }
    }

    var selectedProgramIsComplete: Bool {
        let sessions = appState.selectedPlanWeeks.flatMap(appState.sessions(for:))
        return !sessions.isEmpty && sessions.allSatisfy(isWorkoutSessionComplete)
    }

    var currentProgramWeekIsComplete: Bool {
        guard let week = appState.currentSelectedProgramWeek else { return false }
        let sessions = appState.sessions(for: week)
        return !sessions.isEmpty && sessions.allSatisfy(isWorkoutSessionComplete)
    }

    private var scheduledWorkoutRows: [(week: WorkoutWeek, session: WorkoutSession, date: Date)] {
        let calendar = Calendar.current
        let settings = selectedProgramSettings
        let currentWeekID = appState.currentSelectedProgramWeek?.id ?? appState.selectedPlanWeeks.first?.id
        return appState.selectedPlanWeeks.flatMap { week in
            appState.sessions(for: week).compactMap { session in
                guard let weekdayIndex = calendar.weekdaySymbols.firstIndex(where: {
                    $0.caseInsensitiveCompare(session.day) == .orderedSame
                }) else { return nil }

                let cycleStart: Date
                if let settings {
                    guard let start = calendar.date(
                        byAdding: .weekOfYear,
                        value: week.weekNumber - 1,
                        to: calendar.startOfDay(for: settings.startedAt)
                    ) else { return nil }
                    cycleStart = start
                } else {
                    guard week.id == currentWeekID,
                          let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return nil }
                    cycleStart = start
                }

                let targetWeekday = weekdayIndex + 1
                let cycleWeekday = calendar.component(.weekday, from: cycleStart)
                let dayOffset = (targetWeekday - cycleWeekday + 7) % 7
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) else { return nil }
                return (week, session, date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    func isWorkoutSessionComplete(_ session: WorkoutSession) -> Bool {
        let prescriptionCount = appState.prescriptions(for: session).count
        return prescriptionCount > 0 && appState.completedPrescriptionCount(for: session) >= prescriptionCount
    }

}
