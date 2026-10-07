import Foundation

struct WorkoutSetEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var weight: Double?
    var reps: Int?
    var rpe: Int?
}

struct WorkoutPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var goal: String = "Build strength and muscle"
    var notes: String = ""
    var isActive: Bool = true
    var queueEnabled: Bool = false
    var queuedSessionIDs: [UUID] = []

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, goal, notes, isActive, queueEnabled, queuedSessionIDs
    }

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        goal: String = "Build strength and muscle",
        notes: String = "",
        isActive: Bool = true,
        queueEnabled: Bool = false,
        queuedSessionIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.goal = goal
        self.notes = notes
        self.isActive = isActive
        self.queueEnabled = queueEnabled
        self.queuedSessionIDs = queuedSessionIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? "Build strength and muscle"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        queueEnabled = try container.decodeIfPresent(Bool.self, forKey: .queueEnabled) ?? false
        queuedSessionIDs = try container.decodeIfPresent([UUID].self, forKey: .queuedSessionIDs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(goal, forKey: .goal)
        try container.encode(notes, forKey: .notes)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(queueEnabled, forKey: .queueEnabled)
        try container.encode(queuedSessionIDs, forKey: .queuedSessionIDs)
    }
}

enum WorkoutProgressionMethod: String, CaseIterable, Codable, Hashable, Identifiable {
    case rirRepRange = "RIR + Rep Range"
    case percentage = "Percentage"
    case fixed = "Fixed Sets + Reps"

    var id: String { rawValue }
}

enum WorkoutProgramCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case bodybuilding = "Bodybuilding"
    case powerlifting = "Powerlifting"
    case cablesOnly = "Cables Only"
    case freeWeightsOnly = "Free Weights Only"
    case general = "General"

    var id: String { rawValue }
}

enum WorkoutProgramLevel: String, CaseIterable, Codable, Hashable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case intermediateAdvanced = "Intermediate–Advanced"

    var id: String { rawValue }
}

struct WorkoutProgramExerciseTemplate: Codable, Hashable {
    var exerciseID: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var notes: String = ""
    var substitutionExerciseIDs: [String] = []
}

struct WorkoutProgramSessionTemplate: Codable, Hashable {
    var dayIndex: Int
    var name: String
    var exercises: [WorkoutProgramExerciseTemplate]
}

struct WorkoutProgramTemplate: Identifiable, Codable, Hashable {
    var id: String
    var version: Int
    var name: String
    var summary: String
    var category: WorkoutProgramCategory
    var level: WorkoutProgramLevel
    var daysPerWeek: Int
    var defaultProgression: WorkoutProgressionMethod
    var sessions: [WorkoutProgramSessionTemplate]
    var requiredTrainingMaxExerciseIDs: [String]
}

struct WorkoutPlanProgressionSettings: Identifiable, Codable, Hashable {
    var id: UUID { planID }
    var planID: UUID
    var sourceTemplateID: String
    var sourceTemplateVersion: Int
    var startedAt: Date
    var scheduledWeekdays: [Int]
    var method: WorkoutProgressionMethod
    var preferredUnit: UnitSystem
    var trainingMaxKilograms: [String: Double]
}

struct WorkoutPhase: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var name: String
    var order: Int
    var goal: String
    var durationWeeks: Int
}

struct WorkoutWeek: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var phaseID: UUID
    var weekNumber: Int
    var title: String
    var notes: String
}

enum WorkoutSessionOutcome: String, Codable, Hashable {
    case skipped
    case rest
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID
    var weekID: UUID
    var day: String
    var name: String
    var order: Int
    var notes: String
    var outcome: WorkoutSessionOutcome? = nil
}

struct WorkoutExercisePrescription: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var exerciseID: String
    var exerciseName: String
    var bodyPart: String
    var equipment: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var order: Int
    var notes: String
    var substitutionExerciseIDs: [String]? = nil
    var muscleProfile: ExerciseMuscleProfile? = nil
    var targetRIR: Int? = nil
    var trainingMaxPercentage: Double? = nil
    var targetLoadKilograms: Double? = nil
}

enum WorkoutSource: String, Codable, Hashable {
    case planned
    case freestyle
    case legacyImport
}

struct WorkoutExerciseSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var sourcePrescriptionID: UUID?
    var exerciseID: String
    var exerciseName: String
    var bodyPart: String
    var equipment: String
    var targetSets: Int
    var targetReps: String
    var restSeconds: Int
    var order: Int
    var notes: String
    var substitutionExerciseIDs: [String]? = nil
    var rankingExerciseID: String?
    var muscleProfile: ExerciseMuscleProfile? = nil
    var targetRIR: Int? = nil
    var trainingMaxPercentage: Double? = nil
    var targetLoadKilograms: Double? = nil
    var substitutedFromExerciseID: String? = nil
    var substitutedFromExerciseName: String? = nil
    var demonstrationMediaID: String? = nil
    var trackingType: String? = nil
}

struct ActiveWorkoutState: Identifiable, Codable, Hashable {
    var id: UUID
    var source: WorkoutSource
    var sourceSessionID: UUID?
    var sourcePlanID: UUID?
    var sourceWeekID: UUID?
    var name: String
    var dayLabel: String
    var startedAt: Date
    var historyDate: Date? = nil
    var pausedAt: Date?
    var accumulatedPausedTime: TimeInterval
    var gymID: UUID?
    var bodyweight: Double?
    var unit: UnitSystem
    var exercises: [WorkoutExerciseSnapshot]
    var automaticRestTimerEnabled: Bool
    var restTimerEndsAt: Date?
    var restTimerExerciseID: UUID?

    func elapsedDuration(at date: Date = .now) -> TimeInterval {
        let effectiveEnd = pausedAt ?? date
        let currentPause = pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return max(0, effectiveEnd.timeIntervalSince(startedAt) - accumulatedPausedTime - currentPause)
    }
}

enum WorkoutSetCompletionSource: String, Codable, Hashable {
    case manual
    case automatic
}

struct WorkoutSetLog: Identifiable, Codable, Hashable {
    var id: UUID
    var prescriptionID: UUID
    var performedAt: Date
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var rpe: Int?
    var isWarmup: Bool
    var isComplete: Bool
    var workoutID: UUID? = nil
    var recordedUnit: UnitSystem = .pounds
    var completionSource: WorkoutSetCompletionSource? = nil
    var hasTriggeredRestTimer = false
    var suppressAutoCompletion = false

    var volume: Double {
        guard isComplete else { return 0 }
        return (weight ?? 0) * Double(reps ?? 0)
    }

    func volume(in unit: UnitSystem) -> Double {
        guard isComplete, let weight, let reps else { return 0 }
        return MeasurementFormatting.convert(weight, from: recordedUnit, to: unit) * Double(reps)
    }
}

struct CompletedWorkout: Identifiable, Codable, Hashable {
    var id: UUID
    var source: WorkoutSource
    var sourceSessionID: UUID?
    var sourcePlanID: UUID?
    var name: String
    var dayLabel: String
    var startedAt: Date
    var completedAt: Date
    var duration: TimeInterval
    var effort: Int
    var notes: String
    var gymID: UUID?
    var bodyweight: Double?
    var unit: UnitSystem
    var exercises: [WorkoutExerciseSnapshot]
    var sets: [WorkoutSetLog]
    var linkedSubmissionIDs: [UUID]

    var completedWorkingSets: [WorkoutSetLog] {
        sets.filter { $0.isComplete && !$0.isWarmup }
    }

    var totalVolume: Double {
        completedWorkingSets.reduce(0) { total, set in
            guard trackingKind(for: set) == .weightReps else { return total }
            return total + set.volume(in: unit)
        }
    }

    private func trackingKind(for set: WorkoutSetLog) -> ExerciseTrackingKind {
        guard let exercise = exercises.first(where: { $0.id == set.prescriptionID }) else { return .weightReps }
        let rawTrackingType = exercise.trackingType ??
            MockData.trainingExerciseLibrary.first(where: { $0.id == exercise.exerciseID })?.trackingType
        return ExerciseTrackingKind(rawTrackingType ?? "Weight + Reps")
    }
}

struct WorkoutPlanDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerID: UUID
    var revision: Int
    var name: String
    var payload: Data
    var updatedAt: Date
    var conflictOfRevision: Int? = nil
    var isConflictCopy: Bool = false
    var isSeededDemoData: Bool = false
}

struct WorkoutPlanSyncPayload: Codable, Hashable {
    var plan: WorkoutPlan
    var phases: [WorkoutPhase]
    var weeks: [WorkoutWeek]
    var sessions: [WorkoutSession]
    var prescriptions: [WorkoutExercisePrescription]
    var progression: WorkoutPlanProgressionSettings?
}

enum WorkoutSyncResult: Codable, Hashable {
    case saved(WorkoutPlanDocument)
    case conflict(server: WorkoutPlanDocument, localCopy: WorkoutPlanDocument)
}

struct CompletedWorkoutSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerID: UUID
    var payload: Data
    var completedAt: Date
    var uploadedAt: Date? = nil
    var isSeededDemoData: Bool = false
}

enum WorkoutPRSubmissionState: String, Codable, Hashable {
    case pending
    case uploading
    case failed
    case submitted
}

struct WorkoutPRCandidate: Identifiable, Codable, Hashable {
    var id: UUID { setID }
    var completedWorkoutID: UUID
    var setID: UUID
    var exerciseSnapshotID: UUID
    var rankingExerciseID: String
    var exerciseName: String
    var weight: Double
    var repetitions: Int
    var unit: UnitSystem
    var previousBestKilograms: Double?

    var normalizedKilograms: Double {
        unit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight)
    }
}

struct PendingWorkoutPRSubmission: Identifiable, Codable, Hashable {
    var id: UUID
    var candidate: WorkoutPRCandidate
    var localVideoURL: URL
    var state: WorkoutPRSubmissionState
    var attemptCount: Int
    var lastError: String?
    var submissionID: UUID?
    var updatedAt: Date
}

struct WorkoutPreferences: Codable, Hashable {
    var automaticallySubmitVideoBackedPRs = false
    var didExplainAutomaticPRs = false
    var defaultRestTimerEnabled = true
    var weeklyTrainingDayGoal: Int? = nil
}

struct WorkoutPersistenceSnapshot: Codable, Hashable {
    static let seedCleanupVersion = 10
    static let currentVersion = 11

    var schemaVersion: Int
    var currentProfile: UserProfile? = nil
    var profiles: [UserProfile]? = nil
    var gyms: [Gym]? = nil
    var gymRequests: [GymRequest]? = nil
    var joinedGymIDs: Set<UUID>? = nil
    var plans: [WorkoutPlan]
    var phases: [WorkoutPhase]
    var weeks: [WorkoutWeek]
    var sessions: [WorkoutSession]
    var prescriptions: [WorkoutExercisePrescription]
    var setLogs: [WorkoutSetLog]
    var feedback: [WorkoutFeedback]
    var customExercises: [TrainingExerciseCatalogItem]
    var legacyEntries: [WorkoutExerciseEntry]
    var bodyweightEntries: [BodyweightEntry]
    var strainEntries: [StrainEntry]? = nil
    var injuryEntries: [InjuryEntry]? = nil
    var activeWorkout: ActiveWorkoutState?
    var completedWorkouts: [CompletedWorkout]
    var pendingPRSubmissions: [PendingWorkoutPRSubmission]
    var preferences: WorkoutPreferences
    var planProgressionSettings: [WorkoutPlanProgressionSettings]? = nil
    var achievementUnlocks: [AchievementUnlock]? = nil
    var rankingHistory: [RankingHistorySnapshot]? = nil
    var pendingCompletedWorkoutUploads: [CompletedWorkoutSnapshot]? = nil
    var deletedCompletedWorkoutIDs: Set<UUID>? = nil
    var workoutPlanSyncRevisions: [UUID: Int]? = nil
    var workoutPlanLastSyncedPayloads: [UUID: Data]? = nil
    var pendingRemoteWorkoutPlanDeletions: Set<UUID>? = nil
}
