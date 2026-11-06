import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UserNotifications

struct TrainingTrackerView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
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
    @State var showingPlanSwitcher = false
    @State var showingCreatePlan = false
    @State var showingProgramImport = false
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
    @State var programLibrarySearch = ""
    @State var programLibraryCategory = "All"
    @State var programLibraryDays = 0
    @State var programLibraryEquipment = "All"
    @State var showingProgressionEditor = false
    @State var selectedCompletedWorkout: CompletedWorkout?
    @State var focusedWorkoutSetID: UUID?
    @State var didOpenUITestFocusedWorkoutSet = false
    @State var workoutHistoryMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State var selectedWorkoutHistoryDate: Date?
    @State var selectedProgressExerciseID: String?
    @State var showingProgressExercisePicker = false
    @State var selectedProgressCategory: TrackerProgressCategory = .consistency
    @AppStorage("liftrank.progress.exercise") var storedProgressExerciseID = ""
    @AppStorage("liftrank.rescheduleSuggestions.enabled") var rescheduleSuggestionsEnabled = true
    @State var rescheduleError: String?
    @State var movedWorkoutMessage: String?
    @State var strengthGoalTargetDraft = ""
    @State var strengthGoalExerciseID: String?
    @State var strengthGoalsRevision = 0
    @State var showingTrainingRecap = false
    @State var showingProgressExplanation = false
    @State var showingStrengthGoalEditor = false
    @State var savingStrengthGoal = false
    @State var strengthGoalError: String?
    @State var showAllMuscleSetRows = false
    @State var selectedBodyweightEntry: BodyweightEntry?
    @State var showAllMuscleVolumeRows = false
    @State var muscleWorkloadFilter: MuscleWorkloadFilter = .logged
    @State var selectedProgressMuscle: ExerciseMuscleRegion?
    @State var selectedProgressMuscleDate = Date.now
    @State var didOpenProgress = false
    @State var selectedExerciseWeightTrendDate: Date?
    @State var selectedExerciseStrengthTrendDate: Date?
    @State var selectedPlateauInsight: PlateauInsight?
    @State var selectedVolumeWeek: VolumeWeekSelection = .thisWeek
    @State var activityHeatmapPeriod = 90
    @State var activityHeatmapMeasure = "Time"
    @State var selectedStrengthTrendPeriod = "3M"
    @State var selectedBodyProgressPeriod = "1Y"
    @AppStorage("liftrank.dismissedPlateauInsights") var dismissedPlateauInsightIDs = ""
    let isEmbeddedInTab: Bool
    let isActiveTab: Bool

    init(startOnProgress: Bool = false, isEmbeddedInTab: Bool = false, isActiveTab: Bool = true) {
        _segment = State(initialValue: startOnProgress ? .progress : .today)
        self.isEmbeddedInTab = isEmbeddedInTab
        self.isActiveTab = isActiveTab
    }

    var body: some View { featureBody }
}
