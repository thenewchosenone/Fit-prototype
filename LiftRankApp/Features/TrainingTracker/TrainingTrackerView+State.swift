import Foundation

extension TrainingTrackerView {
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
        appState.selectedWorkoutPlan?.name ?? "Workout Plan"
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
        guard let selectedWeek else { return nil }
        let todayName = Calendar.current.weekdayName(for: .now)
        return appState.sessions(for: selectedWeek).first { $0.day == todayName }
    }

    var filteredLibraryResults: [ExerciseSearchResult] {
        appState.searchExercises(query: librarySearch, filters: libraryFilters)
    }
}
