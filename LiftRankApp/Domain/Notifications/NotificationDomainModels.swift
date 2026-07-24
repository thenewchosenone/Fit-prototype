import Foundation

enum NotificationDestinationKind: String, Codable, CaseIterable, Identifiable {
    case home
    case leaderboard
    case lift
    case messageThread
    case friendRequests
    case gym
    case workoutTracker
    case workoutShare
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

    private enum CodingKeys: String, CodingKey {
        case kind, targetID, exerciseID, gymID, rankingType, trackerStartsOnProgress
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decodeIfPresent(NotificationDestinationKind.self, forKey: .kind) ?? .home
        targetID = try values.decodeIfPresent(UUID.self, forKey: .targetID)
        exerciseID = try values.decodeIfPresent(String.self, forKey: .exerciseID)
        gymID = try values.decodeIfPresent(UUID.self, forKey: .gymID)
        rankingType = try values.decodeIfPresent(RankingType.self, forKey: .rankingType)
        trackerStartsOnProgress = try values.decodeIfPresent(Bool.self, forKey: .trackerStartsOnProgress) ?? false
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
