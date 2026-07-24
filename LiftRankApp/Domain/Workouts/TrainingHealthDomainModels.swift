import Foundation

struct BodyweightEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var week: Int
    var targetDate: Date
    var actual: Double?
    var notes: String
}

enum RecoveryStatus: String, Codable, Hashable {
    case active
    case improving
    case resolved
}

struct StrainEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var occurredAt: Date
    var strain: Int
    var notes: String

    init(id: UUID = UUID(), occurredAt: Date = .now, strain: Int, notes: String = "") {
        self.id = id
        self.occurredAt = occurredAt
        self.strain = min(10, max(1, strain))
        self.notes = notes
    }
}

struct InjuryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var occurredAt: Date
    var area: String
    var description: String
    var intensity: Int
    var status: RecoveryStatus

    init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        area: String,
        description: String,
        intensity: Int,
        status: RecoveryStatus = .active
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.area = area
        self.description = description
        self.intensity = min(10, max(1, intensity))
        self.status = status
    }
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
