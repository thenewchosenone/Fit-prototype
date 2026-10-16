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

    func loadTrainingFocus() {
        selectedProgressCategory = appState.currentProfile.trainingFocus?.startingCategory ?? .consistency
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
        session.outcome == .rest || appState.isFullyCompletedPlanSession(session)
    }

}
