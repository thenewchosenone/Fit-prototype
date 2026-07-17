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
    case videoVerified = "Video Verified"
    case communityVerified = "Community Verified"
    case competitionVerified = "Competition Verified"
    case rejected = "Rejected"
    var id: String { rawValue }
    var isDefaultLeaderboardEligible: Bool {
        self == .videoVerified || self == .communityVerified || self == .competitionVerified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        // Local prototype snapshots may still contain the old reviewer-based label.
        // Preserve those lifts while migrating their user-facing status to evidence-based wording.
        if value == "Moderator Verified" {
            self = .videoVerified
            return
        }

        guard let status = VerificationStatus(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown verification status: \(value)"
            )
        }
        self = status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
    var muscleProfile: ExerciseMuscleProfile? = nil
    var movementPattern: ExerciseMovementPattern = .other
    var difficulty: ExerciseDifficulty = .moderate
    var demonstrationMediaID: String? = nil
    /// Maps only canonical competition-style movements into the public ranking catalog.
    /// A nil value keeps the exercise private to workout progress.
    var rankingExerciseID: String? = nil

    var resolvedMuscleProfile: ExerciseMuscleProfile {
        muscleProfile ?? ExerciseMuscleProfileResolver.profile(name: name, bodyPart: bodyPart)
    }

    func matchesSearch(_ query: String) -> Bool {
        matchResult(for: query) != nil
    }

    func matchResult(for query: String) -> ExerciseSearchResult? {
        ExerciseCatalogSearch.match(exercise: self, query: query)
    }
}

enum ExerciseMovementPattern: String, Codable, CaseIterable, Hashable, Identifiable {
    case horizontalPress = "Horizontal press"
    case verticalPress = "Vertical press"
    case horizontalPull = "Horizontal pull"
    case verticalPull = "Vertical pull"
    case squat = "Squat"
    case hinge = "Hinge"
    case lunge = "Lunge"
    case curl = "Curl"
    case elbowExtension = "Extension"
    case shoulderIsolation = "Shoulder isolation"
    case calf = "Calf"
    case core = "Core"
    case carry = "Carry"
    case other = "Other"

    var id: String { rawValue }
}

enum ExerciseDifficulty: Int, Codable, CaseIterable, Hashable, Identifiable {
    case beginner = 0
    case moderate = 1
    case advanced = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .moderate: "Moderate"
        case .advanced: "Advanced"
        }
    }
}

enum ExerciseSearchMatchKind: String, Codable, Hashable {
    case canonicalExact
    case aliasExact
    case namePrefix
    case nameTokenSet
    case aliasTokenSet
    case equipmentPrimary
    case secondaryPartial
}

struct ExerciseSearchResult: Identifiable, Hashable {
    var id: String { exercise.id }
    let exercise: TrainingExerciseCatalogItem
    let score: Int
    let kind: ExerciseSearchMatchKind
    let matchedAlias: String?

    var reasonLabel: String? {
        guard let matchedAlias else { return nil }
        return "Matched \(matchedAlias)"
    }
}

struct ExerciseSubstitutionRecommendation: Identifiable, Hashable {
    var id: String { exercise.id }
    let exercise: TrainingExerciseCatalogItem
    let score: Double
    let reasons: [String]
}

enum ExerciseCatalogSearch {
    static func search(
        exercises: [TrainingExerciseCatalogItem],
        query: String
    ) -> [ExerciseSearchResult] {
        let cleanQuery = normalize(query)
        let results = exercises.compactMap { match(exercise: $0, query: cleanQuery) }
        return results.sorted {
            if $0.score == $1.score { return $0.exercise.name < $1.exercise.name }
            return $0.score > $1.score
        }
    }

    static func match(exercise: TrainingExerciseCatalogItem, query: String) -> ExerciseSearchResult? {
        let cleanQuery = normalize(query)
        guard !cleanQuery.isEmpty else {
            return ExerciseSearchResult(exercise: exercise, score: 0, kind: .secondaryPartial, matchedAlias: nil)
        }

        let normalizedName = normalize(exercise.name)
        let normalizedAliases = exercise.searchAliases.map(normalize)
        let queryTokens = tokens(from: cleanQuery)
        let nameTokens = tokens(from: normalizedName)
        let aliasTokens = normalizedAliases.map(tokens)
        let primaryMuscles = exercise.resolvedMuscleProfile.primary.map(\.displayName).map(normalize)
        let secondaryMuscles = exercise.resolvedMuscleProfile.secondary.map(\.displayName).map(normalize)
        let metadataTokens = tokens(from: normalize(exercise.equipment)) +
            tokens(from: normalize(exercise.bodyPart)) +
            tokens(from: normalize(exercise.movementPattern.rawValue))

        if normalizedName == cleanQuery {
            return ExerciseSearchResult(exercise: exercise, score: 700, kind: .canonicalExact, matchedAlias: nil)
        }

        if let alias = normalizedAliases.first(where: { $0 == cleanQuery }) {
            return ExerciseSearchResult(exercise: exercise, score: 640, kind: .aliasExact, matchedAlias: alias)
        }

        if normalizedName.hasPrefix(cleanQuery) {
            return ExerciseSearchResult(exercise: exercise, score: 560, kind: .namePrefix, matchedAlias: nil)
        }

        if queryTokens.allSatisfy(nameTokens.contains) {
            return ExerciseSearchResult(exercise: exercise, score: 480, kind: .nameTokenSet, matchedAlias: nil)
        }

        if let aliasIndex = aliasTokens.firstIndex(where: { tokens in
            let joined = tokens.joined(separator: " ")
            return joined.hasPrefix(cleanQuery) || queryTokens.allSatisfy(tokens.contains)
        }) {
            return ExerciseSearchResult(
                exercise: exercise,
                score: 420,
                kind: .aliasTokenSet,
                matchedAlias: normalizedAliases[aliasIndex]
            )
        }

        let primaryMatch = primaryMuscles.contains { queryTokens.allSatisfy(tokens(from: $0).contains) }
        let equipmentMatch = metadataTokens.contains { queryTokens.contains($0) }
        if primaryMatch || equipmentMatch {
            return ExerciseSearchResult(
                exercise: exercise,
                score: primaryMatch ? 340 : 300,
                kind: .equipmentPrimary,
                matchedAlias: nil
            )
        }

        let secondaryMatch = secondaryMuscles.contains { muscle in
            queryTokens.allSatisfy { muscle.contains($0) || $0.contains(muscle) }
        }
        let partialTokenMatch = queryTokens.contains { token in
            normalizedName.contains(token) || normalizedAliases.contains(where: { $0.contains(token) })
        }
        if secondaryMatch || partialTokenMatch {
            return ExerciseSearchResult(exercise: exercise, score: 220, kind: .secondaryPartial, matchedAlias: nil)
        }

        return nil
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func tokens(from value: String) -> [String] {
        normalize(value).split(separator: " ").map(String.init)
    }
}

enum ExerciseMuscleRegion: String, CaseIterable, Codable, Hashable, Identifiable {
    case neck
    case upperChest
    case chest
    case lowerChest
    case frontDelts
    case sideDelts
    case rearDelts
    case biceps
    case triceps
    case forearms
    case traps
    case upperBack
    case lats
    case spinalErectors
    case abs
    case obliques
    case glutes
    case adductors
    case quads
    case hamstrings
    case calves
    case tibialis
    case fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upperChest: "Upper chest"
        case .lowerChest: "Lower chest"
        case .frontDelts: "Front delts"
        case .sideDelts: "Side delts"
        case .rearDelts: "Rear delts"
        case .upperBack: "Upper back"
        case .spinalErectors: "Spinal erectors"
        case .fullBody: "Full body"
        default: rawValue.capitalized
        }
    }

    var isBackFacing: Bool {
        switch self {
        case .rearDelts, .triceps, .traps, .upperBack, .lats, .spinalErectors, .glutes, .hamstrings, .calves:
            true
        default:
            false
        }
    }
}

enum ExerciseMuscleMapOrientation: String, Codable, Hashable {
    case front
    case back
    case split
}

struct ExerciseMuscleProfile: Codable, Hashable {
    var primary: [ExerciseMuscleRegion]
    var secondary: [ExerciseMuscleRegion]
    var orientation: ExerciseMuscleMapOrientation

    var primaryDescription: String {
        primary.map(\.displayName).joined(separator: ", ")
    }

    var secondaryDescription: String {
        secondary.map(\.displayName).joined(separator: ", ")
    }
}

enum ExerciseMuscleProfileResolver {
    static func profile(name: String, bodyPart: String) -> ExerciseMuscleProfile {
        let body = bodyPart.lowercased()
        let movement = name.lowercased()
        var primary: [ExerciseMuscleRegion] = []
        var secondary: [ExerciseMuscleRegion] = []

        func include(_ region: ExerciseMuscleRegion, in list: inout [ExerciseMuscleRegion], when condition: Bool) {
            if condition && !list.contains(region) { list.append(region) }
        }

        include(.neck, in: &primary, when: body.contains("neck"))
        include(.upperChest, in: &primary, when: body.contains("upper chest"))
        include(.lowerChest, in: &primary, when: body.contains("lower chest"))
        include(.chest, in: &primary, when: (body.contains("chest") || body.contains("pec")) && !body.contains("upper chest") && !body.contains("lower chest"))
        include(.rearDelts, in: &primary, when: body.contains("rear delt"))
        include(.sideDelts, in: &primary, when: (body.contains("shoulder") || body.contains("delt")) && (movement.contains("lateral") || movement.contains("upright") || movement.contains("y raise")))
        include(.frontDelts, in: &primary, when: (body.contains("shoulder") || body.contains("delt")) && !body.contains("rear delt") && !primary.contains(.sideDelts))
        include(.biceps, in: &primary, when: body.contains("bicep"))
        include(.triceps, in: &primary, when: body.contains("tricep"))
        include(.forearms, in: &primary, when: body.contains("forearm") || body.contains("grip"))
        include(.traps, in: &primary, when: body.contains("trap"))
        include(.lats, in: &primary, when: body.contains("lat"))
        include(.upperBack, in: &primary, when: (body.contains("back") || body.contains("row")) && !body.contains("lower back") && !body.contains("hamstrings/back") && !primary.contains(.lats))
        include(.spinalErectors, in: &primary, when: body.contains("lower back"))
        include(.abs, in: &primary, when: body.contains("core") || body.contains("abdominal"))
        include(.obliques, in: &primary, when: body.contains("oblique"))
        include(.glutes, in: &primary, when: body.contains("glute"))
        include(.adductors, in: &primary, when: body.contains("adductor"))
        include(.quads, in: &primary, when: body.contains("quad"))
        include(.hamstrings, in: &primary, when: body.contains("hamstring"))
        include(.calves, in: &primary, when: body.contains("calf") || body.contains("calves"))
        include(.tibialis, in: &primary, when: body.contains("tibialis"))
        include(.fullBody, in: &primary, when: body.contains("full body"))

        if movement.contains("deadlift") {
            include(.hamstrings, in: &primary, when: true)
            include(.glutes, in: &primary, when: true)
            include(.spinalErectors, in: &secondary, when: true)
            include(.upperBack, in: &secondary, when: true)
        }
        if movement.contains("squat") || movement.contains("leg press") || movement.contains("lunge") || movement.contains("step-up") {
            include(.quads, in: &primary, when: true)
            include(.glutes, in: &secondary, when: true)
            include(.adductors, in: &secondary, when: true)
        }
        let isLowerBodyPress = movement.contains("leg press") || movement.contains("calf press")
        if (movement.contains("press") && !isLowerBodyPress) || movement.contains("dip") {
            include(.triceps, in: &secondary, when: !primary.contains(.triceps))
            include(.frontDelts, in: &secondary, when: !primary.contains(.frontDelts))
        }
        if movement.contains("row") || movement.contains("pulldown") || movement.contains("pull-up") || movement.contains("pullover") {
            include(.lats, in: &primary, when: !primary.contains(.upperBack))
            include(.biceps, in: &secondary, when: true)
            include(.rearDelts, in: &secondary, when: movement.contains("row"))
        }
        if movement.contains("curl") && !movement.contains("leg curl") {
            include(.biceps, in: &primary, when: true)
            include(.forearms, in: &secondary, when: true)
        }
        if movement.contains("leg curl") || movement.contains("nordic") {
            include(.hamstrings, in: &primary, when: true)
        }
        if movement.contains("hip thrust") || movement.contains("glute") || movement.contains("kickback") {
            include(.glutes, in: &primary, when: true)
            include(.hamstrings, in: &secondary, when: true)
        }
        if movement.contains("carry") {
            primary = [.fullBody]
            secondary = [.forearms, .traps, .abs]
        }

        if primary.isEmpty { primary = [.fullBody] }
        secondary.removeAll { primary.contains($0) }
        let hasFront = primary.contains { !$0.isBackFacing && $0 != .fullBody }
        let hasBack = primary.contains { $0.isBackFacing }
        let orientation: ExerciseMuscleMapOrientation = primary.contains(.fullBody) || (hasFront && hasBack)
            ? .split
            : (hasBack ? .back : .front)
        return ExerciseMuscleProfile(primary: primary, secondary: secondary, orientation: orientation)
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
    var avatarPath: String? = nil
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
    var demoMediaID: String? = nil
    var caption: String
    var verificationStatus: VerificationStatus
    var visibility: LiftVisibility
    var leaderboardEligibleAt: Date = .distantPast
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

enum NotificationDestinationKind: String, Codable, CaseIterable, Identifiable {
    case home
    case leaderboard
    case lift
    case messageThread
    case friendRequests
    case gym
    case workoutTracker
    case profile
    case communityThread
    case forumCommunity
    case forumPost

    var id: String { rawValue }
}

struct NotificationDestination: Codable, Hashable {
    var kind: NotificationDestinationKind
    var targetID: UUID?
    var exerciseID: String?
    var gymID: UUID?
    var rankingType: RankingType?
    var trackerStartsOnProgress: Bool

    static let home = NotificationDestination(kind: .home)

    init(
        kind: NotificationDestinationKind,
        targetID: UUID? = nil,
        exerciseID: String? = nil,
        gymID: UUID? = nil,
        rankingType: RankingType? = nil,
        trackerStartsOnProgress: Bool = false
    ) {
        self.kind = kind
        self.targetID = targetID
        self.exerciseID = exerciseID
        self.gymID = gymID
        self.rankingType = rankingType
        self.trackerStartsOnProgress = trackerStartsOnProgress
    }
}

struct NotificationItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var message: String
    var kind: String
    var createdAt: Date
    var isRead: Bool
    var destination: NotificationDestination = .home
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

enum CommunityVote: Int, Codable, CaseIterable, Identifiable {
    case down = -1
    case up = 1

    var id: Int { rawValue }
}

enum CommunityReportTargetType: String, Codable, CaseIterable, Identifiable {
    case thread = "Thread"
    case reply = "Reply"

    var id: String { rawValue }
}

enum CommunityReportReason: String, Codable, CaseIterable, Identifiable {
    case dangerousAdvice = "Dangerous advice"
    case harassment = "Harassment"
    case misinformation = "Misinformation"
    case spam = "Spam"
    case unsafeSupplements = "Unsafe supplements"
    case other = "Other"

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
    var votes: [UUID: CommunityVote] = [:]
    var isLocked: Bool = false
    var removedAt: Date?
    var removalReason: String?
    var warning: String?

    var voteScore: Int {
        votes.values.reduce(0) { $0 + $1.rawValue }
    }
}

struct CommunityThreadReply: Identifiable, Codable, Hashable {
    var id: UUID
    var threadID: UUID
    var authorID: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var votes: [UUID: CommunityVote] = [:]
    var removedAt: Date?

    var voteScore: Int {
        votes.values.reduce(0) { $0 + $1.rawValue }
    }
}

struct CommunityReport: Identifiable, Codable, Hashable {
    var id: UUID
    var targetType: CommunityReportTargetType
    var targetID: UUID
    var reporterID: UUID
    var reason: CommunityReportReason
    var note: String
    var status: String
    var createdAt: Date
}

// MARK: - Multi-community forum

enum ForumCommunityVisibility: String, Codable, CaseIterable, Identifiable {
    case publicOpen = "Public"
    case restricted = "Restricted"
    case inviteOnly = "Invite Only"

    var id: String { rawValue }
}

enum ForumMemberRole: String, Codable, CaseIterable, Identifiable {
    case member = "Member"
    case moderator = "Moderator"
    case admin = "Admin"
    case staff = "Staff"

    var id: String { rawValue }

    var authority: Int {
        switch self {
        case .member: return 0
        case .moderator: return 1
        case .admin: return 2
        case .staff: return 3
        }
    }
}

enum ForumMembershipStatus: String, Codable, CaseIterable, Identifiable {
    case joined = "Joined"
    case pending = "Pending"
    case invited = "Invited"
    case muted = "Muted"
    case banned = "Banned"
    case declined = "Declined"
    case left = "Left"

    var id: String { rawValue }
}

enum ForumNotificationLevel: String, Codable, CaseIterable, Identifiable {
    case all = "All activity"
    case mentions = "Mentions and replies"
    case off = "Muted"

    var id: String { rawValue }
}

enum ForumPostKind: String, Codable, CaseIterable, Identifiable {
    case discussion = "Discussion"
    case media = "Media"
    case poll = "Poll"
    case liftShare = "Lift"
    case workoutShare = "Workout"
    case link = "Link"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .discussion: return "text.bubble.fill"
        case .media: return "photo.on.rectangle.angled"
        case .poll: return "chart.bar.fill"
        case .liftShare: return "trophy.fill"
        case .workoutShare: return "dumbbell.fill"
        case .link: return "link"
        }
    }
}

enum ForumMediaType: String, Codable, CaseIterable, Identifiable {
    case image
    case video
    var id: String { rawValue }
}

enum ForumDestination: Codable, Hashable {
    case community(UUID)
    case gym(UUID)

    var communityID: UUID? {
        guard case .community(let id) = self else { return nil }
        return id
    }

    var gymID: UUID? {
        guard case .gym(let id) = self else { return nil }
        return id
    }
}

struct ForumCommunity: Identifiable, Codable, Hashable {
    var id: UUID
    var slug: String
    var name: String
    var summary: String
    var details: String
    var category: String
    var symbolName: String
    var accentHex: String
    var visibility: ForumCommunityVisibility
    var rules: [String]
    var availableTags: [String]
    var staffOwnerID: UUID
    var memberCount: Int
    var postCount: Int
    var createdAt: Date
    var archivedAt: Date?
}

struct ForumMembership: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID
    var userID: UUID
    var role: ForumMemberRole
    var status: ForumMembershipStatus
    var notificationLevel: ForumNotificationLevel
    var joinedAt: Date?
    var mutedUntil: Date?
    var bannedAt: Date?
    var restrictionReason: String?
    var invitedBy: UUID?

    var isActive: Bool {
        status == .joined || status == .muted
    }

    var canContribute: Bool {
        if status == .joined { return true }
        if status == .muted, let mutedUntil { return mutedUntil <= .now }
        return false
    }
}

struct ForumAttachment: Identifiable, Codable, Hashable {
    var id: UUID
    var mediaType: ForumMediaType
    var localURL: URL
    var createdAt: Date
}

struct ForumPollOption: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var voterIDs: Set<UUID>
}

struct ForumPoll: Identifiable, Codable, Hashable {
    var id: UUID
    var options: [ForumPollOption]
    var closesAt: Date?

    var isClosed: Bool { closesAt.map { $0 <= .now } ?? false }
    var totalVotes: Int { options.reduce(0) { $0 + $1.voterIDs.count } }
}

struct ForumPost: Identifiable, Codable, Hashable {
    var id: UUID
    var destination: ForumDestination
    var authorID: UUID
    var authorName: String
    var kind: ForumPostKind
    var title: String
    var body: String
    var tag: String?
    var attachments: [ForumAttachment]
    var poll: ForumPoll?
    var liftID: UUID?
    var workoutID: UUID?
    var linkURL: URL?
    var challengeID: UUID?
    var createdAt: Date
    var editedAt: Date?
    var commentCount: Int
    var votes: [UUID: CommunityVote]
    var savedByUserIDs: Set<UUID>
    var watchedByUserIDs: Set<UUID>
    var isPinned: Bool
    var isLocked: Bool
    var removedAt: Date?
    var removalReason: String?

    var voteScore: Int { votes.values.reduce(0) { $0 + $1.rawValue } }
}

struct ForumComment: Identifiable, Codable, Hashable {
    var id: UUID
    var postID: UUID
    var parentCommentID: UUID?
    var authorID: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var editedAt: Date?
    var votes: [UUID: CommunityVote]
    var removedAt: Date?
    var removalReason: String?

    var voteScore: Int { votes.values.reduce(0) { $0 + $1.rawValue } }
}

struct ForumVoteRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var targetType: ForumReportTargetType
    var targetID: UUID
    var userID: UUID
    var vote: CommunityVote
    var updatedAt: Date
}

struct ForumJoinRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID
    var userID: UUID
    var note: String
    var status: String
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedBy: UUID?
}

enum ForumReportTargetType: String, Codable, CaseIterable, Identifiable {
    case post = "Post"
    case comment = "Comment"
    case community = "Community"
    case member = "Member"
    var id: String { rawValue }
}

enum ForumReportStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case resolved = "Resolved"
    case dismissed = "Dismissed"
    var id: String { rawValue }
}

struct ForumReport: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID?
    var targetType: ForumReportTargetType
    var targetID: UUID
    var reporterID: UUID
    var reason: CommunityReportReason
    var note: String
    var status: ForumReportStatus
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedBy: UUID?
}

enum ForumModerationActionKind: String, Codable, CaseIterable, Identifiable {
    case pin = "Pinned"
    case unpin = "Unpinned"
    case lock = "Locked"
    case unlock = "Unlocked"
    case remove = "Removed"
    case restore = "Restored"
    case warn = "Warned"
    case mute = "Muted"
    case ban = "Banned"
    case approve = "Approved"
    case decline = "Declined"
    case archive = "Archived"
    var id: String { rawValue }
}

struct ForumModerationAction: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID?
    var moderatorID: UUID
    var kind: ForumModerationActionKind
    var targetID: UUID
    var reason: String
    var createdAt: Date
}

enum ForumNotificationKind: String, Codable, CaseIterable, Identifiable {
    case reply = "Reply"
    case mention = "Mention"
    case watchedPost = "Watched Post"
    case moderation = "Moderation"
    case membership = "Membership"
    var id: String { rawValue }
}

struct ForumNotification: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var actorID: UUID?
    var kind: ForumNotificationKind
    var title: String
    var message: String
    var communityID: UUID?
    var postID: UUID?
    var commentID: UUID?
    var createdAt: Date
    var isRead: Bool
}

enum ForumFeedSort: String, Codable, CaseIterable, Identifiable {
    case hot = "Hot"
    case new = "New"
    case top = "Top"
    var id: String { rawValue }
}

enum ForumTopRange: String, Codable, CaseIterable, Identifiable {
    case day = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All time"
    var id: String { rawValue }
}

enum ForumCommentSort: String, Codable, CaseIterable, Identifiable {
    case best = "Best"
    case new = "New"
    case old = "Old"
    var id: String { rawValue }
}

enum ForumRoute: Hashable {
    case community(UUID)
    case post(UUID)
    case gym(UUID)
    case gyms
    case saved
    case watched
    case moderation
}

struct ForumPersistenceSnapshot: Codable, Hashable {
    static let currentVersion = 1

    var schemaVersion: Int
    var communities: [ForumCommunity]
    var memberships: [ForumMembership]
    var posts: [ForumPost]
    var comments: [ForumComment]
    var joinRequests: [ForumJoinRequest]
    var reports: [ForumReport]
    var moderationActions: [ForumModerationAction]
    var notifications: [ForumNotification]
    var globalStaffUserIDs: Set<UUID>
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

enum WorkoutProgressionMethod: String, CaseIterable, Codable, Hashable, Identifiable {
    case rirRepRange = "RIR + Rep Range"
    case percentage = "Percentage"
    case fixed = "Fixed Sets + Reps"

    var id: String { rawValue }
}

enum WorkoutProgramCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case bodybuilding = "Bodybuilding"
    case powerlifting = "Powerlifting"
    case general = "General"

    var id: String { rawValue }
}

enum WorkoutProgramLevel: String, CaseIterable, Codable, Hashable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"

    var id: String { rawValue }
}

struct WorkoutProgramExerciseTemplate: Codable, Hashable {
    var exerciseID: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var notes: String = ""
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
    var rankingExerciseID: String?
    var muscleProfile: ExerciseMuscleProfile? = nil
    var targetRIR: Int? = nil
    var trainingMaxPercentage: Double? = nil
    var targetLoadKilograms: Double? = nil
    var substitutedFromExerciseID: String? = nil
    var substitutedFromExerciseName: String? = nil
    var demonstrationMediaID: String? = nil
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
        completedWorkingSets.reduce(0) { $0 + $1.volume }
    }
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
}

struct WorkoutPersistenceSnapshot: Codable, Hashable {
    static let currentVersion = 4

    var schemaVersion: Int
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
    var activeWorkout: ActiveWorkoutState?
    var completedWorkouts: [CompletedWorkout]
    var pendingPRSubmissions: [PendingWorkoutPRSubmission]
    var preferences: WorkoutPreferences
    var planProgressionSettings: [WorkoutPlanProgressionSettings]? = nil
    var achievementUnlocks: [AchievementUnlock]? = nil
    var rankingHistory: [RankingHistorySnapshot]? = nil
}

struct WorkoutCompletionInsights: Hashable {
    var volumeDelta: Double
    var volumeDeltaPercent: Double?
    var setDelta: Int
    var durationDelta: TimeInterval
    var improvedExerciseNames: [String]
    var projectedStatistics: CompetitiveStatistics
    var newlyUnlockedAchievements: [AchievementUnlock]
}

struct CompetitiveStatistics: Codable, Hashable {
    var totalWorkouts: Int = 0
    var lifetimeWorkingSetVolume: Double = 0
    var totalActiveTrainingTime: TimeInterval = 0
    var totalWorkingSetRepetitions: Int = 0
    var prCount: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var verifiedLiftCount: Int = 0
    var currentGlobalTotalRank: Int?
    var highestGlobalTotalRank: Int?
    var currentGymTotalRank: Int?
    var highestGymTotalRank: Int?
    var daysAtNumberOne: Int = 0
    var weeksAtNumberOne: Int = 0
    var biggestRealDailyRankingJump: Int = 0
    var topTenDailyFinishes: Int = 0
    var topHundredDailyFinishes: Int = 0
}

struct AchievementDefinition: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbolName: String
}

struct AchievementUnlock: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let unlockedAt: Date
}

struct RankingHistorySnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let capturedAt: Date
    let globalTotalRank: Int?
    let gymTotalRank: Int?
}

struct LegacyWorkoutRecordValue: Hashable {
    var id: UUID
    var exercise: String
    var workout: String
    var weight: Double
    var reps: Int
    var rpe: Int
    var performedAt: Date
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

extension Calendar {
    func weekdayName(for date: Date = .now) -> String {
        let index = component(.weekday, from: date) - 1
        guard weekdaySymbols.indices.contains(index) else { return "Monday" }
        return weekdaySymbols[index]
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

@Model
final class PersistentWorkoutState {
    var id: UUID
    var schemaVersion: Int
    var updatedAt: Date
    var payload: Data

    init(
        id: UUID = UUID(uuidString: "A9000000-0000-0000-0000-000000000001")!,
        schemaVersion: Int,
        updatedAt: Date = .now,
        payload: Data
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

@Model
final class PersistentForumState {
    var id: UUID
    var schemaVersion: Int
    var updatedAt: Date
    var payload: Data

    init(
        id: UUID = UUID(uuidString: "A9000000-0000-0000-0000-000000000002")!,
        schemaVersion: Int,
        updatedAt: Date = .now,
        payload: Data
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
