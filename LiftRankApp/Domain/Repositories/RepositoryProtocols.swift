import Combine
import Foundation

@MainActor
protocol ActiveWorkoutRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var activeWorkout: ActiveWorkoutState? { get }
    var workoutSetLogs: [WorkoutSetLog] { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var workoutPreferences: WorkoutPreferences { get set }

    @discardableResult
    func startWorkout(
        session: WorkoutSession,
        planID: UUID?,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem,
        at startedAt: Date
    ) -> ActiveWorkoutState?

    @discardableResult
    func startFreestyleWorkout(
        name: String,
        gymID: UUID?,
        bodyweight: Double?,
        unit: UnitSystem,
        at startedAt: Date
    ) -> ActiveWorkoutState?

    func pauseActiveWorkout(at date: Date)
    func resumeActiveWorkout(at date: Date)
    func clearActiveWorkoutDraft()
    func updateActiveRestTimer(endsAt: Date?, exerciseID: UUID?)
    func discardActiveWorkout()
    func deleteCompletedWorkout(_ workout: CompletedWorkout)
    func updateCompletedWorkout(_ workout: CompletedWorkout)
    func removeExerciseFromActiveWorkout(_ exercise: WorkoutExerciseSnapshot)
    func setAutomaticRestTimerEnabledForActiveWorkout(_ enabled: Bool)
    func updateWorkoutSetLog(_ log: WorkoutSetLog)

    @discardableResult
    func addWorkoutSetLog(
        prescriptionID: UUID,
        setNumber: Int?,
        workoutID: UUID?,
        unit: UnitSystem
    ) -> WorkoutSetLog

    func deleteWorkoutSetLog(_ log: WorkoutSetLog)
    func addExercisesToActiveWorkout(_ exercises: [TrainingExerciseCatalogItem])

    @discardableResult
    func substituteActiveWorkoutExercise(
        currentExerciseID: UUID,
        substitute: TrainingExerciseCatalogItem
    ) -> WorkoutExerciseSnapshot?

    @discardableResult
    func updateSourcePlanFromActiveWorkout() -> Bool

    @discardableResult
    func finishActiveWorkout(effort: Int, notes: String, at completedAt: Date) -> CompletedWorkout?

    @discardableResult
    func reorderActiveWorkout(exerciseIDs: [UUID]) -> Bool

    @discardableResult
    func moveActiveWorkoutExercise(_ exerciseID: UUID, direction: Int) -> Bool

    @discardableResult
    func applyWorkoutSetCompletion(
        logID: UUID,
        isComplete: Bool,
        source: WorkoutSetCompletionSource
    ) -> WorkoutSetLog?

    func persistWorkoutSnapshot()
}

@MainActor
protocol ProgramRepository: AnyObject {
    var workoutPlans: [WorkoutPlan] { get }
    var workoutPhases: [WorkoutPhase] { get }
    var workoutWeeks: [WorkoutWeek] { get }
    var workoutSessions: [WorkoutSession] { get }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get }

    func currentProgramWeek(planID: UUID, at date: Date) -> WorkoutWeek?
    func addWorkoutPlan(_ plan: WorkoutPlan)
    func updateWorkoutPlan(_ plan: WorkoutPlan)
    func duplicateWorkoutPlan(_ plan: WorkoutPlan) -> WorkoutPlan
    func deleteWorkoutPlan(_ plan: WorkoutPlan)

    @discardableResult
    func addWorkoutWeek(planID: UUID, phaseID: UUID?, title: String?) -> WorkoutWeek
    func cloneWorkoutWeek(_ week: WorkoutWeek) -> WorkoutWeek
    func deleteWorkoutWeek(_ week: WorkoutWeek)

    @discardableResult
    func addWorkoutSession(weekID: UUID, day: String, name: String) -> WorkoutSession
    func deleteWorkoutSession(_ session: WorkoutSession)
    func cancelWorkoutSession(_ session: WorkoutSession)

    @discardableResult
    func addWorkoutPrescription(_ prescription: WorkoutExercisePrescription) -> WorkoutExercisePrescription
    func deleteWorkoutPrescription(_ prescription: WorkoutExercisePrescription)

    @discardableResult
    func startWorkoutProgram(
        template: WorkoutProgramTemplate,
        startDate: Date,
        scheduledWeekdays: [Int],
        method: WorkoutProgressionMethod,
        preferredUnit: UnitSystem,
        trainingMaxKilograms: [String: Double]
    ) -> WorkoutPlan

    @discardableResult
    func changeWorkoutProgramProgression(
        planID: UUID,
        method: WorkoutProgressionMethod,
        trainingMaxKilograms: [String: Double],
        at date: Date
    ) -> Bool
}

@MainActor
protocol TrainingProgressRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var trainingExerciseCatalog: [TrainingExerciseCatalogItem] { get }
    var workoutWeeks: [WorkoutWeek] { get }
    var workoutSessions: [WorkoutSession] { get }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get }
    var workoutSetLogs: [WorkoutSetLog] { get }
    var workoutEntries: [WorkoutExerciseEntry] { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var bodyweightEntries: [BodyweightEntry] { get }
    var strainEntries: [StrainEntry] { get }
    var injuryEntries: [InjuryEntry] { get }

    func updateBodyweight(_ entry: BodyweightEntry)
    func updateStrainEntry(_ entry: StrainEntry)
    func deleteStrainEntry(_ entryID: UUID)
    func updateInjuryEntry(_ entry: InjuryEntry)
    func deleteInjuryEntry(_ entryID: UUID)
    func clearTrainingHealthEntries()
}

@MainActor
protocol ExerciseRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var customTrainingExercises: [TrainingExerciseCatalogItem] { get }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem)
    func clearCustomTrainingExercises()
}

@MainActor
protocol CompetitionRepository: AnyObject {
    var lifts: [LiftSubmission] { get set }
    var profiles: [UserProfile] { get }
    var currentProfile: UserProfile { get }
    var joinedGymIDs: Set<UUID> { get }
    var achievementUnlocks: [AchievementUnlock] { get set }
    var rankingHistory: [RankingHistorySnapshot] { get set }
    func refreshAchievementUnlocks(now: Date)
}

@MainActor
protocol ProfileRepository: AnyObject {
    var currentProfile: UserProfile { get set }
    var profiles: [UserProfile] { get set }
    var gyms: [Gym] { get set }
    var joinedGymIDs: Set<UUID> { get set }
    var profileChanges: AnyPublisher<Void, Never> { get }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool
    func leaveGym(_ gym: Gym)
}

@MainActor
protocol NotificationRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var notifications: [NotificationItem] { get set }
    var notificationChanges: AnyPublisher<Void, Never> { get }
}

@MainActor
protocol WorkoutRepository: ActiveWorkoutRepository, TrainingProgressRepository {}

@MainActor
protocol WorkoutSyncRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot] { get set }
    var deletedCompletedWorkoutIDs: Set<UUID> { get set }
    var completedWorkouts: [CompletedWorkout] { get set }
    var workoutPlans: [WorkoutPlan] { get set }
    var workoutPhases: [WorkoutPhase] { get set }
    var workoutWeeks: [WorkoutWeek] { get set }
    var workoutSessions: [WorkoutSession] { get set }
    var workoutPrescriptions: [WorkoutExercisePrescription] { get set }
    var workoutPlanProgressionSettings: [WorkoutPlanProgressionSettings] { get set }
    var workoutPlanSyncRevisions: [UUID: Int] { get set }
    var workoutPlanLastSyncedPayloads: [UUID: Data] { get set }
    var pendingRemoteWorkoutPlanDeletions: Set<UUID> { get set }

    func clearAccountScopedWorkoutHistory()
    func persistWorkoutSnapshot()
}

@MainActor
protocol WorkoutPRSubmissionRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var completedWorkouts: [CompletedWorkout] { get }
    var pendingWorkoutPRSubmissions: [PendingWorkoutPRSubmission] { get }
    var workoutPreferences: WorkoutPreferences { get set }

    func upsertPendingPRSubmission(_ pending: PendingWorkoutPRSubmission)
    func clearPendingPRSubmissions()
    func linkSubmission(_ submissionID: UUID, to workoutID: UUID)
    func persistWorkoutSnapshot()
}

@MainActor
protocol AccountSocialRepository: AnyObject {
    var currentProfile: UserProfile { get }
    var gymRequests: [GymRequest] { get set }
}
