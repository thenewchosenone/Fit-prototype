import Foundation

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

enum CompetitiveMovement: String, Codable, CaseIterable, Identifiable {
    case barbellBenchPress = "barbell_bench_press"
    case backSquat = "back_squat"
    case conventionalDeadlift = "conventional_deadlift"
    case sumoDeadlift = "sumo_deadlift"
    case standingBarbellOverheadPress = "standing_barbell_overhead_press"
    case dumbbellBenchPress = "dumbbell_bench_press"
    case bentOverBarbellRow = "bent_over_barbell_row"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbellBenchPress: "Barbell Bench Press"
        case .backSquat: "Back Squat"
        case .conventionalDeadlift: "Conventional Deadlift"
        case .sumoDeadlift: "Sumo Deadlift"
        case .standingBarbellOverheadPress: "Standing Barbell Overhead Press"
        case .dumbbellBenchPress: "Dumbbell Bench Press"
        case .bentOverBarbellRow: "Bent-Over Barbell Row"
        }
    }

    var canonicalExerciseID: String {
        switch self {
        case .barbellBenchPress: "barbell-bench-press"
        case .backSquat: "back-squat"
        case .conventionalDeadlift: "conventional-deadlift"
        case .sumoDeadlift: "sumo-deadlift"
        case .standingBarbellOverheadPress: "standing-barbell-overhead-press"
        case .dumbbellBenchPress: "dumbbell-bench-press"
        case .bentOverBarbellRow: "barbell-row"
        }
    }

    var recordsWeightPerHand: Bool { self == .dumbbellBenchPress }

    static func resolve(exerciseID: String) -> CompetitiveMovement? {
        switch exerciseID.lowercased().replacingOccurrences(of: "-", with: "_") {
        case "bench", "barbell_bench_press", "flat_barbell_bench_press": .barbellBenchPress
        case "squat", "back_squat": .backSquat
        case "deadlift", "conventional_deadlift": .conventionalDeadlift
        case "sumo_deadlift": .sumoDeadlift
        case "press", "ohp", "barbell_overhead_press", "standing_barbell_overhead_press": .standingBarbellOverheadPress
        case "dumbbell_bench_press", "flat_dumbbell_bench_press": .dumbbellBenchPress
        case "barbell_row", "bent_over_barbell_row", "bentover_barbell_row": .bentOverBarbellRow
        default: nil
        }
    }
}

enum LiftEvidenceStatus: String, Codable, CaseIterable, Identifiable {
    case selfReported = "self_reported"
    case videoBacked = "video_backed"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfReported: "Self-reported"
        case .videoBacked: "Video-backed"
        }
    }
}

enum LiftModerationStatus: String, Codable, CaseIterable, Identifiable {
    case clear
    case underReview = "under_review"
    case replacementRequested = "replacement_requested"
    case rejected
    var id: String { rawValue }
}

enum LiftReportReason: String, Codable, CaseIterable, Identifiable {
    case incorrectWeight = "Incorrect weight"
    case mismatchedExercise = "Mismatched exercise"
    case unusableVideo = "Unusable or edited video"
    case depth = "Depth"
    case rangeOfMotion = "Range of motion"
    case lockout = "Lockout"
    case other = "Other"
    var id: String { rawValue }
}

enum LiftModeratorDecision: String, Codable, CaseIterable, Identifiable {
    case uphold
    case reject
    case requestReplacement = "request_replacement"
    var id: String { rawValue }
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
