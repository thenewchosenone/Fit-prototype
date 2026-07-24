import Foundation

struct ActivityItem: Identifiable, Hashable {
    let id: UUID
    let profile: UserProfile
    let title: String
    let detail: String
    var liftID: UUID? = nil
    var workoutID: UUID? = nil
    let createdAt: Date
    var isLiked: Bool
    var isSaved: Bool
    var likeCount: Int = 0
    var commentCount: Int = 0
}

struct ActivityComment: Identifiable, Hashable {
    let id: UUID
    let activityID: UUID
    let authorID: UUID
    let authorName: String
    var body: String
    let createdAt: Date
}
