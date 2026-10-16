import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UserNotifications

struct TrainingTrackerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState var isLibrarySearchFocused: Bool
    @State var segment: TrackerSegment
    @State var selectedWeekID: UUID?
    @State var selectedSessionForAdd: WorkoutSession?
    @State var selectedSessionToRun: WorkoutSession?
    @State var pendingSessionToStart: WorkoutSession?
    @State var pendingFreestyleStart = false
    @State var pendingWorkoutHistoryDate: Date?
    @State var workoutDateToLog = Date.now
    @State var showingWorkoutDatePicker = false
    @State var showingActiveWorkout = false
    @State var showingWorkoutConflict = false
    @State var showingCreatePlan = false
    @State var showingDeletePlan = false
    @State var showingRenamePlan = false
    @State var renamePlanName = ""
    @State var planDetailTab = "Weeks"
    @State var librarySearch = ""
    @State var libraryFilters = ExerciseLibraryFilterSelection()
    @State var showingLibraryFilters = false
    @State var selectedLibraryExercise: TrainingExerciseCatalogItem?
    @State var showingCreateLibraryExercise = false
    @State var selectedProgramTemplate: WorkoutProgramTemplate?
    @State var isProgramLibraryExpanded = false
    @State var showingProgressionEditor = false
    @State var selectedCompletedWorkout: CompletedWorkout?
    @State var focusedWorkoutSetID: UUID?
    @State var didOpenUITestFocusedWorkoutSet = false
    @State var workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State var selectedWorkoutHistoryDate: Date?
    @State var selectedProgressExerciseID: String?
    @State var strengthExerciseScrollRequest = UUID()
    @State var showingProgressExercisePicker = false
    @State var selectedProgressCategory: TrackerProgressCategory = .consistency
    @State var showAllMuscleSetRows = false
    @State var showAllMuscleVolumeRows = false
    @State var muscleWorkloadFilter: MuscleWorkloadFilter = .logged
    @State var selectedProgressMuscle: ExerciseMuscleRegion?
    @State var selectedProgressMuscleDate = Date.now
    @State var didLoadTrainingFocus = false
    @State var dismissedTrainingFocusPrompt = false
    @State var selectedExerciseWeightTrendDate: Date?
    @State var selectedExerciseStrengthTrendDate: Date?
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
