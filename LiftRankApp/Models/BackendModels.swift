import Foundation

enum AccountMode: String, Codable {
    case authenticated
    case demo
}

struct AccountSession: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let expiresAt: Date?
}

enum AccountStatus: Equatable {
    case restoring
    case signedOut
    case needsOnboarding
    case needsLegalAcceptance
    case authenticated
    case demo
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
    var bodyweightAudience: PrivacyAudience = .privateProfile
    var locationAudience: PrivacyAudience = .friends
    var gymAudience: PrivacyAudience = .publicProfile
    var friendListAudience: PrivacyAudience = .friends
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

    var displayDetail: String {
        [region, countryName].filter { !$0.isEmpty }.joined(separator: ", ")
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
}

struct GymMembershipRecord: Equatable, Identifiable {
    var id: String { "\(userID.uuidString):\(gymID.uuidString)" }
    let userID: UUID
    let gymID: UUID
    let isPrimary: Bool
    let joinedAt: Date
    let leftAt: Date?
}

enum FriendRelationshipState: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
}

struct FriendRelationshipRecord: Equatable, Identifiable {
    let id: UUID
    let userLowID: UUID
    let userHighID: UUID
    let requestedBy: UUID
    let status: FriendRelationshipState
    let createdAt: Date
    let respondedAt: Date?
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
    case duplicateRelationship
    case networkUnavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing: "Account services are not configured on this build."
        case .invalidCredentials: "We couldn't sign you in. Check your details and try again."
        case .sessionExpired: "Your session expired. Please sign in again."
        case .usernameUnavailable: "That username is already taken."
        case .invalidInput(let message): message
        case .permissionDenied: "You don't have permission to do that."
        case .gymLimitReached: "You can belong to no more than three active gyms."
        case .primaryGymRequired: "Choose another primary gym before leaving this one."
        case .duplicateRelationship: "A friendship or request already exists."
        case .networkUnavailable: "LiftRank couldn't reach the server. Check your connection and try again."
        case .server(let message): message
        }
    }
}
