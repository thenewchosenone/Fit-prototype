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
    var bio: String? = nil
    var ageGroup: String
    var sexCategory: SexCategory
    var heightInches: Double
    var bodyweightPounds: Double
    var preferredUnit: UnitSystem
    var city: String
    var state: String
    var cityID: UUID? = nil
    var primaryGymID: UUID
    var primaryGymName: String
    var yearsExperience: Int
    var experienceLevel: ExperienceLevel
    var profileImageName: String
    var avatarPath: String? = nil
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

struct GymRequest: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var city: String
    var state: String
    var createdBy: UUID
    var status: String
    var createdAt: Date
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
    var gymID: UUID?
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
    var hasProtectedEvidence: Bool? = nil

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
        resolvedModerationStatus == .clear
    }

    var requiresCoordinatedRemoval: Bool {
        hasProtectedEvidence == true || videoAssetID != nil || resolvedEvidenceStatus == .videoBacked
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
    var value: LiftVoteValue
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

    static let currentVersion = "2026-08-28"
    static let current: [LegalDocument] = [
        LegalDocument(kind: .privacy, version: currentVersion, title: "Privacy Notice", summary: "How Lift Rivals collects, uses, shares, retains, and protects your information.", sections: [
            .init(title: "1. Information we collect", body: "We collect information you provide, including your email address, account identifiers, username, profile photo, biography, birth date, gender, height, bodyweight, training goals, city and gym selections, friendships, privacy choices, workout history, lift records, discomfort or training-readiness entries, uploaded photos or videos, reports, blocks, and support messages. Sign in with Apple may provide an Apple account identifier, name, and relay or regular email address according to your Apple choices. We also process technical and usage information needed to operate and secure the service, including push-notification tokens, device identifiers, app interactions, IP-derived or user-selected coarse location, diagnostics, authentication events, and timestamps."),
            .init(title: "2. How we use information", body: "We use information to create and secure accounts, synchronize training history, calculate rankings and achievements, provide social and notification features, display content according to visibility choices, investigate reports, enforce community standards, prevent fraud or abuse, respond to support and privacy requests, measure product usage, decide which features to build, and improve reliability. We do not use health or fitness information for targeted advertising."),
            .init(title: "3. Public and community content", body: "Profile details, gym memberships, rankings, public lift submissions, photos, and videos may be visible to other users when you choose or use a public feature. Private or local-only training data is not intentionally published. Do not upload sensitive information that you do not want others to see."),
            .init(title: "4. Sharing and providers", body: "We disclose information to service providers only as needed to operate, secure, and support Lift Rivals; comply with law; protect users; or complete a transaction you request. Supabase provides database, authentication, storage, and server infrastructure. Apple provides distribution, device services, notifications, and optional Sign in with Apple. These providers process information under their agreements and privacy obligations. We do not sell personal information, share it for cross-context behavioral advertising, or use third-party advertising trackers."),
            .init(title: "5. Moderation and safety", body: "Authorized reviewers may access reported content and related account information to investigate safety, integrity, or policy concerns. We may preserve or disclose information when reasonably necessary to comply with law, respond to valid legal process, enforce our terms, or protect users and the public."),
            .init(title: "6. Retention and deletion", body: "We retain account and profile information while your account is active. Account deletion removes the account and associated profile, social, workout, lift, photo, and video data from active systems, subject to processing time and limited retention required for security, fraud prevention, abuse reports, legal obligations, disputes, and disaster-recovery backups. Security and moderation records may be retained for up to three years when reasonably necessary; backups may persist for up to 90 days before deletion through ordinary rotation. De-identified aggregate statistics may be retained when they can no longer reasonably identify you."),
            .init(title: "7. Your choices and rights", body: "You can edit profile information, choose content visibility, block users, report content, revoke device permissions, disable notifications, and permanently delete your account in Settings. You may request access, correction, deletion, or a portable copy of information by emailing support@liftrivals.com. Depending on where you live, you may also have rights to object, restrict processing, appeal a denied request, or withdraw consent. We will not discriminate against you for exercising applicable privacy rights."),
            .init(title: "8. Security and processing", body: "We use administrative and technical safeguards designed to protect information, but no service can guarantee absolute security. Information may be processed in the United States or other locations where our providers operate, subject to applicable protections."),
            .init(title: "9. Teens and children", body: "Lift Rivals is available to users age 13 and older and is not directed to children under 13. Users aged 13 through 17 should review the service with a parent or legal guardian, and guardian authorization must be obtained where required by law. We do not knowingly collect personal information from children under 13. A parent or guardian who believes a child under 13 provided information, or who has a legally recognized request concerning a minor, may contact support@liftrivals.com."),
            .init(title: "10. Changes and contact", body: "We may update this notice as the service changes and will provide additional notice when required. Lift Rivals is operated by Robert Jeanty, doing business as Lift Rivals, 10430 SW 216th Street, Apt 306, Miami, FL 33190, USA. Email support@liftrivals.com with questions or privacy requests.")
        ]),
        LegalDocument(kind: .terms, version: currentVersion, title: "Terms of Use", summary: "The rules for using Lift Rivals and keeping an account in good standing.", sections: [
            .init(title: "1. Eligibility and accounts", body: "You must be at least 13 years old and legally permitted to use the service. If you are under the age of majority where you live, you represent that a parent or legal guardian has reviewed these Terms with you and authorized your use where required by law. Lift Rivals is not directed to children under 13. Provide accurate information, keep your credentials secure, and notify us through Support if you suspect unauthorized access. You are responsible for activity under your account."),
            .init(title: "2. Training and health", body: "Lift Rivals is a fitness tracking and community service, not medical advice or professional coaching. Exercise carries risk of injury. Use appropriate equipment and technique, train within your abilities, stop if you feel unwell, and consult a qualified professional when appropriate."),
            .init(title: "3. Your content", body: "You retain ownership of content you submit. You grant Lift Rivals a non-exclusive, worldwide, royalty-free license to host, process, reproduce, and display that content only as needed to operate, secure, improve, and provide the features you choose. You represent that you have the rights and permissions necessary to submit it."),
            .init(title: "4. Community standards", body: "Do not post illegal, threatening, hateful, harassing, sexually explicit, exploitative, deceptive, infringing, or dangerous content. Do not impersonate others, expose private information, manipulate rankings, automate abuse, distribute malware, or use the service to target or endanger another person."),
            .init(title: "5. Reports and moderation", body: "You can report content and block users. We may review, limit, remove, preserve, or disclose content and account information when reasonably necessary to enforce these Terms, protect the community, investigate abuse, or comply with law. We do not guarantee that all content will be reviewed or removed."),
            .init(title: "6. Rankings and verification", body: "Rankings, achievements, and verification indicators are informational product features, not guarantees of performance or identity. We may correct results, reject submissions, or remove eligibility where records are incomplete, misleading, duplicated, manipulated, or inconsistent with published requirements."),
            .init(title: "7. Service availability and third parties", body: "Features may change, pause, or be discontinued. Apple and other service providers may apply separate terms to their products. Lift Rivals is not responsible for third-party services outside our control."),
            .init(title: "8. Suspension and deletion", body: "You may permanently delete your account from Settings in the app. We may suspend or terminate access for material or repeated violations, security threats, fraud, legal requirements, or harm to users or the service. Provisions that by their nature should survive termination will remain in effect."),
            .init(title: "9. Disclaimers and liability", body: "To the fullest extent permitted by law, the service is provided \"as is\" and \"as available\" without warranties of uninterrupted operation, fitness results, or accuracy. Lift Rivals is not liable for indirect, incidental, special, consequential, exemplary, or punitive damages. To the fullest extent permitted by law, total liability arising from the service will not exceed the greater of US $100 or the amount you paid Lift Rivals during the twelve months before the claim. Nothing in these Terms limits rights or liability that cannot legally be limited."),
            .init(title: "10. Indemnity", body: "To the extent permitted by law, you agree to defend and indemnify Lift Rivals and its operator from claims, losses, and expenses arising from your unlawful use of the service, your content, or your material violation of these Terms. This section does not apply where prohibited by law."),
            .init(title: "11. Intellectual property and complaints", body: "Lift Rivals, its software, branding, and original content are protected by applicable intellectual-property laws. If you believe content infringes your rights, contact support@liftrivals.com with identification of the work, the challenged material, your contact information, and a good-faith statement explaining the claim."),
            .init(title: "12. Governing law and disputes", body: "These Terms are governed by the laws of the State of Florida, without regard to conflict-of-law rules. Unless applicable consumer law requires otherwise, disputes must be brought in a state or federal court with jurisdiction in Miami-Dade County, Florida. Before filing, you agree to contact support@liftrivals.com and attempt an informal resolution for at least 30 days."),
            .init(title: "13. Miscellaneous", body: "These Terms, the Privacy Notice, and any feature-specific rules form the entire agreement concerning the service. If a provision is unenforceable, the remaining provisions remain effective. Failure to enforce a provision is not a waiver. You may not assign these Terms without consent; Lift Rivals may assign them in connection with a business transfer, subject to applicable law."),
            .init(title: "14. Changes and contact", body: "We may update these Terms as the service evolves. We will post the new effective date and request acceptance again when a material change requires it. Lift Rivals is operated by Robert Jeanty, doing business as Lift Rivals, 10430 SW 216th Street, Apt 306, Miami, FL 33190, USA. Email support@liftrivals.com with questions or concerns.")
        ]),
        LegalDocument(kind: .fitnessDisclaimer, version: currentVersion, title: "Fitness Disclaimer", summary: "Strength training carries risk and Lift Rivals does not provide medical advice.", sections: [
            .init(title: "Training risk", body: "Strength training and maximal attempts can cause serious injury. Use appropriate equipment, spotters, progression, and qualified coaching."),
            .init(title: "Not medical advice", body: "Lift Rivals content is general information, not diagnosis, treatment, or individualized medical guidance."),
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
