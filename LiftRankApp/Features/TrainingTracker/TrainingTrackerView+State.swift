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

    enum ProgressTimeRange: String, CaseIterable, Identifiable {
        case fourWeeks = "4 weeks"
        case eightWeeks = "8 weeks"
        case twelveWeeks = "12 weeks"
        case sixMonths = "6 months"
        case oneYear = "1 year"

        var id: String { rawValue }

        func startDate(from date: Date = .now, calendar: Calendar = .current) -> Date {
            switch self {
            case .fourWeeks:
                return calendar.date(byAdding: .weekOfYear, value: -4, to: date) ?? date
            case .eightWeeks:
                return calendar.date(byAdding: .weekOfYear, value: -8, to: date) ?? date
            case .twelveWeeks:
                return calendar.date(byAdding: .weekOfYear, value: -12, to: date) ?? date
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: date) ?? date
            case .oneYear:
                return calendar.date(byAdding: .year, value: -1, to: date) ?? date
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
        appState.scheduledWorkout()
    }

    var missedScheduledWorkout: (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        appState.missedScheduledWorkout()
    }

    var nextScheduledWorkout: (week: WorkoutWeek, session: WorkoutSession, date: Date)? {
        appState.nextScheduledWorkout()
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

    func isWorkoutSessionComplete(_ session: WorkoutSession) -> Bool {
        let prescriptionCount = appState.prescriptions(for: session).count
        return prescriptionCount > 0 && appState.completedPrescriptionCount(for: session) >= prescriptionCount
    }

}
