import Foundation

enum AccountMode: String, Codable {
    case authenticated
    case demo
}

struct AccountSession: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let expiresAt: Date?
    var isGuest: Bool = false
}

enum AccountStatus: Equatable {
    case restoring
    case signedOut
    case needsOnboarding
    case needsLegalAcceptance
    case authenticated
    case demo
    case guest
    case configurationRequired
    case failure(String)
}

enum PrivacyAudience: String, Codable, CaseIterable, Identifiable {
    case publicProfile = "public"
    case friends
    case gym
    case privateProfile = "private"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .publicProfile: return "Public"
        case .friends: return "Friends"
        case .gym: return "Gym"
        case .privateProfile: return "Private"
        }
    }
}

struct ProfilePrivacySettings: Codable, Equatable {
    var profileAudience: PrivacyAudience = .publicProfile
    var ageBandAudience: PrivacyAudience = .publicProfile
    var divisionAudience: PrivacyAudience = .publicProfile
    var bodyweightAudience: PrivacyAudience = .publicProfile
    var locationAudience: PrivacyAudience = .publicProfile
    var gymAudience: PrivacyAudience = .publicProfile
    var friendListAudience: PrivacyAudience = .friends
    var showLiftVideos: Bool = true
    var workoutStatsAudience: PrivacyAudience? = nil
    var shareWorkoutStartsWithFriends: Bool? = nil
    var sharePRsWithFriends: Bool? = nil
    var gymOvertakeAlerts: Bool? = nil
}

// Only the account preferences owned by Settings; never a full profile snapshot.
struct ProfileSettingsSnapshot: Equatable {
    let fields: [String: String?]

    init(preferredUnit: UnitSystem, trainingFocus: TrainingFocus?, privacy: ProfilePrivacySettings) {
        fields = [
            "preferred_unit": preferredUnit.shortLabel,
            "training_focus": trainingFocus?.rawValue,
            "profile_audience": privacy.profileAudience.rawValue,
            "age_band_audience": privacy.ageBandAudience.rawValue,
            "division_audience": privacy.divisionAudience.rawValue,
            "bodyweight_audience": privacy.bodyweightAudience.rawValue,
            "location_audience": privacy.locationAudience.rawValue,
            "gym_audience": privacy.gymAudience.rawValue,
            "friend_list_audience": privacy.friendListAudience.rawValue,
            "show_lift_videos": String(privacy.showLiftVideos),
            "workout_stats_audience": (privacy.workoutStatsAudience ?? .privateProfile).rawValue,
            "share_workout_starts_with_friends": String(privacy.shareWorkoutStartsWithFriends ?? false),
            "share_prs_with_friends": String(privacy.sharePRsWithFriends ?? false),
            "gym_overtake_alerts": String(privacy.gymOvertakeAlerts ?? false)
        ]
    }

    func changes(from baseline: Self) -> [String: String?] {
        fields.filter { baseline.fields[$0.key] != .some($0.value) }
    }
}

struct SharedWorkoutStats: Equatable {
    let workoutCount: Int
    let recentWorkoutCount: Int
    let latestWorkoutAt: Date?
}

enum FriendTrainingActivityKind: String, Codable, Hashable {
    case workoutStarted = "workout_started"
    case topLift = "top_lift"
}

struct FriendTrainingActivity: Identifiable {
    let id: UUID
    let ownerID: UUID
    let displayName: String
    let kind: FriendTrainingActivityKind
    let sourceID: UUID
    let occurredAt: Date
    var lift: LiftSubmission? = nil
}

struct FriendRequest: Identifiable {
    let id: UUID
    let userID: UUID
    let displayName: String
    let isIncoming: Bool
    let isAccepted: Bool
}

struct PendingFriendActivityShare: Codable, Hashable {
    let ownerID: UUID
    let kind: FriendTrainingActivityKind
    let sourceID: UUID
}

struct ProfileDraft: Equatable {
    var username: String
    var displayName: String
    var bio: String
    var avatarPath: String? = nil
    var preferredUnit: UnitSystem
    var birthDate: Date?
    var sexCategory: SexCategory?
    var heightCentimeters: Double?
    var bodyweightPounds: Double?
    var cityID: UUID? = nil
    var city: String
    var region: String
    var countryCode: String
    var yearsExperience: Int?
    var experienceLevel: ExperienceLevel?
    var privacy: ProfilePrivacySettings
    var completesOnboarding: Bool
    var trainingFocus: TrainingFocus? = nil
    var updatesPrimaryGym: Bool = false
    var primaryGymID: UUID? = nil
}

struct LocationCitySuggestion: Equatable, Identifiable, Hashable {
    let canonicalID: UUID?
    let city: String
    let region: String
    let countryCode: String
    let countryName: String
    let population: Int?

    var id: String {
        canonicalID?.uuidString ?? "\(countryCode)|\(region)|\(city)"
    }

}

struct AuthenticatedProfile: Equatable {
    let id: UUID
    var username: String
    var displayName: String
    var bio: String
    var avatarPath: String?
    var onboardingCompleted: Bool
    var preferredUnit: UnitSystem
    var birthDate: Date?
    var sexCategory: SexCategory?
    var heightCentimeters: Double?
    var bodyweightPounds: Double?
    var city: String?
    var region: String?
    var countryCode: String?
    var cityID: UUID? = nil
    var yearsExperience: Int?
    var experienceLevel: ExperienceLevel?
    var privacy: ProfilePrivacySettings
    var trainingFocus: TrainingFocus? = nil
}

struct PublicProfileCard: Equatable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let avatarPath: String?
    let ageBand: String?
    let sexCategory: SexCategory?
    let city: String?
    let region: String?
    let countryCode: String?
    let primaryGymID: UUID?
    let primaryGymName: String?
    let bodyweightPounds: Double?
    let bodyweightLastUpdatedAt: Date?
}

struct GymMembershipRecord: Equatable, Identifiable {
    var id: String { "\(userID.uuidString):\(gymID.uuidString)" }
    let userID: UUID
    let gymID: UUID
    let isPrimary: Bool
    let joinedAt: Date
    let leftAt: Date?
}

struct CatalogExercise: Equatable, Identifiable {
    let id: String
    let displayName: String
    let status: String
    let rankingMovement: String?
    let metadata: [String: String]
}

enum LiftRankServiceError: LocalizedError, Equatable {
    case configurationMissing
    case invalidCredentials
    case sessionExpired
    case usernameUnavailable
    case invalidInput(String)
    case permissionDenied
    case gymLimitReached
    case primaryGymRequired
    case networkUnavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing: "Account services are not configured on this build."
        case .invalidCredentials: "Email or password is incorrect. Check both and try again."
        case .sessionExpired: "Your session expired. Please sign in again."
        case .usernameUnavailable: "That username is already taken."
        case .invalidInput(let message): message
        case .permissionDenied: "You don't have permission to do that."
        case .gymLimitReached: "You can belong to no more than three active gyms."
        case .primaryGymRequired: "Choose another primary gym before leaving this one."
        case .networkUnavailable: "Lift Rivals couldn't reach the server. Check your connection and try again."
        case .server(let message): message
        }
    }
}
