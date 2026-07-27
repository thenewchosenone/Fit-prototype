import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UserNotifications

struct TrainingTrackerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State var segment: TrackerSegment
    @State var selectedWeekID: UUID?
    @State var selectedSessionForAdd: WorkoutSession?
    @State var selectedSessionToRun: WorkoutSession?
    @State var pendingSessionToStart: WorkoutSession?
    @State var pendingFreestyleStart = false
    @State var showingActiveWorkout = false
    @State var showingWorkoutConflict = false
    @State var showingCreatePlan = false
    @State var showingRenamePlan = false
    @State var renamePlanName = ""
    @State var planDetailTab = "Weeks"
    @State var librarySearch = ""
    @State var libraryFilters = ExerciseLibraryFilterSelection()
    @State var showingLibraryFilters = false
    @State var selectedLibraryExercise: TrainingExerciseCatalogItem?
    @State var showingCreateLibraryExercise = false
    @State var selectedProgramTemplate: WorkoutProgramTemplate?
    @State var isProgramLibraryExpanded = true
    @State var showingProgressionEditor = false
    @State var selectedBodyweightEntry: BodyweightEntry?
    @State var selectedCompletedWorkout: CompletedWorkout?
    @State var workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State var selectedWorkoutHistoryDate: Date?
    @State var selectedProgressExerciseID: String?
    @State var selectedPlateauInsight: PlateauInsight?
    @State var selectedVolumeWeek: VolumeWeekSelection = .thisWeek
    @AppStorage("liftrank.dismissedPlateauInsights") var dismissedPlateauInsightIDs = ""
    let isEmbeddedInTab: Bool

    init(startOnProgress: Bool = false, isEmbeddedInTab: Bool = false) {
        _segment = State(initialValue: startOnProgress ? .progress : .today)
        self.isEmbeddedInTab = isEmbeddedInTab
    }

    var body: some View { featureBody }
}
