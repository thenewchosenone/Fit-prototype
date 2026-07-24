import Foundation

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
    var competitiveMovement: CompetitiveMovement? = nil
    var evidenceStatus: LiftEvidenceStatus? = nil
    var moderationStatus: LiftModerationStatus? = nil
    var videoAssetID: UUID? = nil
    var weightPerHand: Bool? = nil

    var resolvedEvidenceStatus: LiftEvidenceStatus {
        if let evidenceStatus { return evidenceStatus }
        return verificationStatus == .selfReported ? .selfReported : .videoBacked
    }

    var resolvedModerationStatus: LiftModerationStatus {
        moderationStatus ?? (verificationStatus == .rejected ? .rejected : .clear)
    }

    var isLaunchLeaderboardEligible: Bool {
        visibility == .publicLift &&
        repetitions == 1 &&
        isActualOneRepMax &&
        competitiveMovement != nil &&
        resolvedEvidenceStatus == .videoBacked &&
        resolvedModerationStatus != .rejected
    }
}

struct LiftMediaAsset: Identifiable, Codable, Hashable {
    var id: UUID
    var ownerID: UUID
    var storagePath: String
    var contentType: String
    var byteCount: Int
    var createdAt: Date
}

struct LiftReportRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var liftID: UUID
    var reporterID: UUID
    var reason: LiftReportReason
    var note: String
    var isOpen: Bool
    var createdAt: Date
}

struct LiftVoteRecord: Identifiable, Codable, Hashable {
    var id: String { "\(liftID.uuidString):\(voterID.uuidString)" }
    var liftID: UUID
    var voterID: UUID
    var value: CommunityVote
    var createdAt: Date
}

struct LiftModerationActionRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var liftID: UUID
    var actorID: UUID
    var decision: LiftModeratorDecision
    var note: String
    var createdAt: Date
}

struct UserBlockRecord: Identifiable, Codable, Hashable {
    var id: String { "\(blockerID.uuidString):\(blockedID.uuidString)" }
    var blockerID: UUID
    var blockedID: UUID
    var createdAt: Date
}

struct PushDeviceRegistration: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var deviceID: String
    var token: String
    var environment: String
    var updatedAt: Date
}

struct LegalAcceptanceRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var documentKind: String
    var documentVersion: String
    var acceptedAt: Date
}

enum LegalDocumentKind: String, Codable, CaseIterable, Identifiable {
    case privacy
    case terms
    case communityRules = "community_rules"
    case fitnessDisclaimer = "fitness_disclaimer"

    var id: String { rawValue }
}

struct LegalDocumentSection: Hashable {
    let title: String
    let body: String
}

struct LegalDocument: Identifiable, Hashable {
    let kind: LegalDocumentKind
    let version: String
    let title: String
    let summary: String
    let sections: [LegalDocumentSection]

    var id: String { "\(kind.rawValue):\(version)" }

    static let currentVersion = "2026-07-18"
    static let current: [LegalDocument] = [
        LegalDocument(kind: .privacy, version: currentVersion, title: "Privacy Notice", summary: "How LiftRank stores and shares account, training, location, and video data.", sections: [
            .init(title: "Data we use", body: "LiftRank stores account identity, training history, competitive records, privacy choices, gym and location selections, community content, messages, reports, and videos you choose to upload."),
            .init(title: "Visibility", body: "Profile fields can be public, friends-only, gym-only, or private. A public ratio or weight-class ranking may indirectly reveal information about your bodyweight."),
            .init(title: "No advertising tracking", body: "Launch analytics measure signup, activation, workouts, PR submissions, sharing, and return activity. LiftRank does not use advertising identifiers or cross-app tracking.")
        ]),
        LegalDocument(kind: .terms, version: currentVersion, title: "Terms of Use", summary: "The rules for using LiftRank and keeping an account in good standing.", sections: [
            .init(title: "Account responsibility", body: "Provide accurate eligibility and lift information, protect your credentials, and use only an account you are authorized to control."),
            .init(title: "Competitive records", body: "Video-backed means a video is attached; it does not mean LiftRank approved technique. Attempts can be reported, reviewed, or removed from rankings."),
            .init(title: "Account action", body: "Content or accounts may be restricted for abuse, manipulation, unlawful conduct, or repeated violations of the community rules.")
        ]),
        LegalDocument(kind: .communityRules, version: currentVersion, title: "Community Rules", summary: "Standards for posts, messages, reports, and competitive conduct.", sections: [
            .init(title: "Respect athletes", body: "No harassment, threats, hate, sexual exploitation, impersonation, doxxing, or targeted abuse."),
            .init(title: "Keep competition honest", body: "Do not falsify weight, identity, exercise, video, or eligibility information. Use reports for genuine concerns, not retaliation."),
            .init(title: "Keep content safe", body: "No spam, illegal content, dangerous medical claims, or content that violates another person’s privacy or intellectual property.")
        ]),
        LegalDocument(kind: .fitnessDisclaimer, version: currentVersion, title: "Fitness Disclaimer", summary: "Strength training carries risk and LiftRank does not provide medical advice.", sections: [
            .init(title: "Training risk", body: "Strength training and maximal attempts can cause serious injury. Use appropriate equipment, spotters, progression, and qualified coaching."),
            .init(title: "Not medical advice", body: "LiftRank content and community activity are general information, not diagnosis, treatment, or individualized medical guidance."),
            .init(title: "Stop when unsafe", body: "Consult a qualified professional before training when health, injury, pregnancy, medication, or other conditions may affect safety.")
        ])
    ]
}

enum AnalyticsEventName: String, Codable, CaseIterable, Identifiable {
    case signupCompleted = "signup_completed"
    case onboardingCompleted = "onboarding_completed"
    case firstWorkoutStarted = "first_workout_started"
    case workoutCompleted = "workout_completed"
    case prSubmitted = "pr_submitted"
    case videoBackedPRSubmitted = "video_backed_pr_submitted"
    case workoutShared = "workout_shared"
    case weeklyReturn = "weekly_return"
    var id: String { rawValue }
}

struct AnalyticsEventRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var name: AnalyticsEventName
    var occurredAt: Date
    var properties: [String: String]
}
