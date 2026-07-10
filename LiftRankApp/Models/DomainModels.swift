import Foundation
import SwiftData

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case pounds
    case kilograms
    var id: String { rawValue }
    var shortLabel: String { self == .pounds ? "lb" : "kg" }
}

enum SexCategory: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case open = "Open"
    var id: String { rawValue }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case novice = "Novice"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case veteran = "Veteran"
    var id: String { rawValue }
}

enum VerificationStatus: String, Codable, CaseIterable, Identifiable {
    case selfReported = "Self Reported"
    case videoSubmitted = "Video Submitted"
    case communityVerified = "Community Verified"
    case moderatorVerified = "Moderator Verified"
    case competitionVerified = "Competition Verified"
    case rejected = "Rejected"
    var id: String { rawValue }
    var isDefaultLeaderboardEligible: Bool {
        self == .communityVerified || self == .moderatorVerified || self == .competitionVerified
    }
}

enum LiftVisibility: String, Codable, CaseIterable, Identifiable {
    case publicLift = "Public"
    case followers = "Followers"
    case privateLift = "Private"
    var id: String { rawValue }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case raw = "Raw"
    case equipped = "Equipped"
    var id: String { rawValue }
}

enum RankingType: String, Codable, CaseIterable, Identifiable {
    case absolute = "Absolute"
    case poundForPound = "Pound-for-pound"
    case total = "Total"
    case relativeTotal = "Relative total"
    case mostImproved = "Most improved"
    var id: String { rawValue }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let isPowerlift: Bool
}

struct TrainingExerciseCatalogItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var bodyPart: String
    var workoutCategory: String
    var defaultSets: Int
    var defaultReps: String
    var symbolName: String
    var secondaryMuscles: [String] = []
    var equipment: String = "Bodyweight"
    var movementType: String = "Strength"
    var trackingType: String = "Weight + Reps"
    var defaultRestSeconds: Int = 120
    var searchAliases: [String] = []

    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }
        return name.lowercased().contains(normalizedQuery) ||
            bodyPart.lowercased().contains(normalizedQuery) ||
            equipment.lowercased().contains(normalizedQuery) ||
            searchAliases.contains { $0.lowercased().contains(normalizedQuery) }
    }
}

enum ExerciseBodyRegion: String, CaseIterable, Hashable {
    case neck
    case shoulders
    case chest
    case back
    case arms
    case core
    case glutes
    case upperLegs
    case lowerLegs
    case fullBody
}

enum ExerciseBodyRegionResolver {
    static func regions(for bodyPart: String) -> [ExerciseBodyRegion] {
        let value = bodyPart.lowercased()
        var regions: [ExerciseBodyRegion] = []

        func include(_ region: ExerciseBodyRegion, when condition: Bool) {
            if condition && !regions.contains(region) {
                regions.append(region)
            }
        }

        include(.neck, when: value.contains("neck"))
        include(.shoulders, when: value.contains("shoulder") || value.contains("delt") || value.contains("rotator"))
        include(.chest, when: value.contains("chest") || value.contains("pec"))
        include(.back, when: value.contains("back") || value.contains("lat") || value.contains("trap"))
        include(.arms, when: value.contains("bicep") || value.contains("tricep") || value.contains("arm") || value.contains("forearm") || value.contains("grip"))
        include(.core, when: value.contains("core") || value.contains("abdominal") || value.contains("oblique"))
        include(.glutes, when: value.contains("glute"))
        include(.upperLegs, when: value.contains("quad") || value.contains("hamstring") || value.contains("adductor") || value.contains("upper leg"))
        include(.lowerLegs, when: value.contains("calf") || value.contains("calves") || value.contains("tibialis") || value.contains("lower leg"))
        include(.fullBody, when: value.contains("full body"))

        return regions.isEmpty ? [.fullBody] : regions
    }
}

struct WeightClass: Identifiable, Codable, Hashable {
    let id: String
    let sexCategory: SexCategory
    let name: String
    let minKilograms: Double?
    let maxKilograms: Double?
}

struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var username: String
    var displayName: String
    var ageGroup: String
    var sexCategory: SexCategory
    var heightInches: Double
    var bodyweightPounds: Double
    var preferredUnit: UnitSystem
    var city: String
    var state: String
    var primaryGymID: UUID
    var primaryGymName: String
    var yearsExperience: Int
    var experienceLevel: ExperienceLevel
    var profileImageName: String
    var followers: Int
    var following: Int
    var hideExactAge: Bool
    var hideBodyweight: Bool
    var hideCity: Bool
    var hideGym: Bool
    var hideLiftVideos: Bool
}

struct Gym: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var city: String
    var state: String
    var memberCount: Int
    var verifiedLiftCount: Int
}

struct LiftSubmission: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var exerciseID: String
    var exerciseName: String
    var weight: Double
    var unit: UnitSystem
    var normalizedWeightKilograms: Double
    var repetitions: Int
    var isActualOneRepMax: Bool
    var estimatedOneRepMax: Double
    var bodyweightAtLift: Double
    var bodyweightMultiple: Double
    var equipmentType: EquipmentType
    var variation: String
    var gymID: UUID
    var performedAt: Date
    var localVideoURL: URL?
    var remoteVideoURL: URL?
    var caption: String
    var verificationStatus: VerificationStatus
    var visibility: LiftVisibility
    var createdAt: Date
    var updatedAt: Date
}

struct LeaderboardEntry: Identifiable, Hashable {
    var id: UUID { lift.id }
    let rank: Int
    let profile: UserProfile
    let lift: LiftSubmission
    let rankMovement: Int
    let score: Double
    let powerliftingBreakdown: PowerliftingBreakdown?
}

struct PowerliftingBreakdown: Hashable {
    let squatKilograms: Double?
    let benchKilograms: Double?
    let deadliftKilograms: Double?

    var totalKilograms: Double {
        (squatKilograms ?? 0) + (benchKilograms ?? 0) + (deadliftKilograms ?? 0)
    }
}

struct Follow: Identifiable, Codable, Hashable {
    let id: UUID
    let followerID: UUID
    let followedID: UUID
}

enum FriendRequestStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"

    var id: String { rawValue }
}

struct FriendRequest: Identifiable, Codable, Hashable {
    let id: UUID
    var fromUserID: UUID
    var toUserID: UUID
    var status: FriendRequestStatus
    var createdAt: Date
    var respondedAt: Date?
}

struct Comment: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let liftID: UUID
    var text: String
    let createdAt: Date
}

struct Reaction: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let targetID: UUID
    var kind: String
}

struct Challenge: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var startDate: Date
    var endDate: Date
    var goal: String
    var eligibility: String
    var participantCount: Int
    var progress: Double
    var isJoined: Bool
}

struct ChallengeParticipant: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let challengeID: UUID
    var progress: Double
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var symbolName: String
}

struct UserAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let achievementID: UUID
    var unlockedAt: Date?
}

struct NotificationItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var message: String
    var kind: String
    var createdAt: Date
    var isRead: Bool
}

struct Report: Identifiable, Codable, Hashable {
    let id: UUID
    let liftID: UUID
    let reason: String
    let createdAt: Date
}

struct DirectMessageThread: Identifiable, Codable, Hashable {
    let id: UUID
    var participantIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
}

struct DirectMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var threadID: UUID
    var senderID: UUID
    var body: String
    var createdAt: Date
    var isRead: Bool
    var isReported: Bool
}

enum MessageReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "Spam"
    case offensive = "Offensive"
    case harassment = "Harassment"
    case other = "Other"

    var id: String { rawValue }
}

struct MessageReport: Identifiable, Codable, Hashable {
    let id: UUID
    var messageID: UUID
    var reporterID: UUID
    var reason: MessageReportReason
    var note: String
    var createdAt: Date
}

enum CommunityThreadKind: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case challenge = "Challenge"
    case gym = "Gym"
    var id: String { rawValue }
}

struct CommunityThread: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var authorID: UUID
    var authorName: String
    var kind: CommunityThreadKind
    var challengeID: UUID?
    var gymID: UUID?
    var replyCount: Int
    var likeCount: Int
    var createdAt: Date
}

struct CommunityThreadReply: Identifiable, Codable, Hashable {
    var id: UUID
    var threadID: UUID
    var authorID: UUID
    var authorName: String
    var body: String
    var createdAt: Date
}

struct GymRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var city: String
    var state: String
    var requestedBy: UUID
    var note: String
    var createdAt: Date
}

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

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID
    var weekID: UUID
    var day: String
    var name: String
    var order: Int
    var notes: String
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

    var volume: Double {
        guard isComplete else { return 0 }
        return (weight ?? 0) * Double(reps ?? 0)
    }
}

struct WorkoutSummary: Identifiable, Hashable {
    var id: UUID
    var sessionID: UUID
    var workoutName: String
    var completedExercises: Int
    var totalExercises: Int
    var totalSets: Int
    var totalVolume: Double
    var bestSet: WorkoutSetLog?
}

struct WorkoutFeedback: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var completedAt: Date
    var effort: Int
    var notes: String
}

struct WorkoutExerciseEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var planID: UUID
    var week: Int
    var date: Date
    var day: String
    var workout: String
    var exercise: String
    var muscleGroup: String
    var targetSets: Int
    var targetReps: String
    var sets: [WorkoutSetEntry]
    var isDone: Bool
    var notes: String

    var bestSet: WorkoutSetEntry? {
        sets.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

    var volume: Double {
        sets.reduce(0) { total, set in
            total + ((set.weight ?? 0) * Double(set.reps ?? 0))
        }
    }

    var estimatedMax: Double {
        guard let bestSet, let weight = bestSet.weight else { return 0 }
        return RankingCalculator.epleyOneRepMax(weight: weight, repetitions: bestSet.reps ?? 1)
    }
}

struct BodyweightEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var week: Int
    var targetDate: Date
    var actual: Double?
    var notes: String
}

struct StrengthBalance: Hashable {
    var score: Int
    var label: String
    var weakest: String
    var volumes: [String: Double]
}

struct WorkoutDaySummary: Identifiable, Hashable {
    var id: String { "\(day)-\(workout)" }
    var day: String
    var workout: String
    var exercises: Int
    var completed: Int
}

struct ActivityItem: Identifiable, Hashable {
    let id: UUID
    let profile: UserProfile
    let title: String
    let detail: String
    var liftID: UUID? = nil
    let createdAt: Date
    var isLiked: Bool
    var isSaved: Bool
}

struct ActivityComment: Identifiable, Hashable {
    let id: UUID
    let activityID: UUID
    let authorID: UUID
    let authorName: String
    var body: String
    let createdAt: Date
}

struct LeaderboardFilters: Hashable {
    var exerciseID: String?
    var rankingType: RankingType = .total
    var repetitionCount: Int?
    var sexCategory: SexCategory?
    var ageGroup: String?
    var weightClassID: String?
    var experienceLevel: ExperienceLevel?
    var gymID: UUID?
    var city: String?
    var state: String?
    var country: String?
    var verificationLevel: VerificationStatus?
    var timeRange: String = "All time"
}

@Model
final class PersistentLiftRecord {
    var id: UUID
    var exerciseID: String
    var exerciseName: String
    var weight: Double
    var repetitions: Int
    var performedAt: Date

    init(id: UUID, exerciseID: String, exerciseName: String, weight: Double, repetitions: Int, performedAt: Date) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.weight = weight
        self.repetitions = repetitions
        self.performedAt = performedAt
    }
}

@Model
final class PersistentSettings {
    var id: UUID
    var preferredUnitRawValue: String
    var privateProfile: Bool
    var hideBodyweight: Bool
    var hideExactAge: Bool
    var hideLocation: Bool
    var allowComments: Bool

    init() {
        id = UUID()
        preferredUnitRawValue = UnitSystem.pounds.rawValue
        privateProfile = false
        hideBodyweight = false
        hideExactAge = false
        hideLocation = false
        allowComments = true
    }
}

@Model
final class PersistentWorkoutRecord {
    var id: UUID
    var exercise: String
    var workout: String
    var weight: Double
    var reps: Int
    var rpe: Int
    var performedAt: Date

    init(id: UUID, exercise: String, workout: String, weight: Double, reps: Int, rpe: Int, performedAt: Date) {
        self.id = id
        self.exercise = exercise
        self.workout = workout
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
    }
}
