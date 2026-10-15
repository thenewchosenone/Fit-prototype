import Foundation

enum NotificationDestinationKind: String, Codable, CaseIterable, Identifiable {
    case home
    case leaderboard
    case lift
    case gym
    case workoutTracker
    case profile
    case forumPost

    var id: String { rawValue }
}

struct NotificationDestination: Codable, Hashable {
    var kind: NotificationDestinationKind
    var targetID: UUID?
    var commentID: UUID?
    var exerciseID: String?
    var gymID: UUID?
    var rankingType: RankingType?
    var trackerStartsOnProgress: Bool

    static let home = NotificationDestination(kind: .home)

    init(
        kind: NotificationDestinationKind,
        targetID: UUID? = nil,
        commentID: UUID? = nil,
        exerciseID: String? = nil,
        gymID: UUID? = nil,
        rankingType: RankingType? = nil,
        trackerStartsOnProgress: Bool = false
    ) {
        self.kind = kind
        self.targetID = targetID
        self.commentID = commentID
        self.exerciseID = exerciseID
        self.gymID = gymID
        self.rankingType = rankingType
        self.trackerStartsOnProgress = trackerStartsOnProgress
    }

    private enum CodingKeys: String, CodingKey {
        case kind, targetID, commentID, exerciseID, gymID, rankingType, trackerStartsOnProgress
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try values.decodeIfPresent(String.self, forKey: .kind)
        kind = NotificationDestinationKind(rawValue: rawKind ?? "") ?? .home
        targetID = try values.decodeIfPresent(UUID.self, forKey: .targetID)
        commentID = try values.decodeIfPresent(UUID.self, forKey: .commentID)
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
