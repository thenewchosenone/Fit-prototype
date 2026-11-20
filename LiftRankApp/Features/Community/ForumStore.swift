import Foundation

@MainActor
final class ForumStore {
    private var service: any ForumService
    var replyDrafts: [UUID: [UUID: (body: String, parentID: UUID?)]] = [:]

    init(service: any ForumService) {
        self.service = service
    }

    func updateService(_ service: any ForumService) {
        self.service = service
    }

    func communities() async throws -> [ForumCommunity] {
        try await service.communities()
    }

    func joinedCommunityIDs() async throws -> [UUID] {
        try await service.joinedCommunityIDs()
    }

    func communityMembershipStatuses() async throws -> [UUID: String] {
        try await service.communityMembershipStatuses()
    }

    func posts(communityID: UUID?, limit: Int, offset: Int = 0) async throws -> [ForumPost] {
        try await service.posts(communityID: communityID, limit: limit, offset: offset)
    }

    func thread(postID: UUID) async throws -> ForumThread? {
        try await service.thread(postID: postID)
    }

    func join(communityID: UUID, requestNote: String) async throws -> String {
        try await service.join(communityID: communityID, requestNote: requestNote)
    }

    func leave(communityID: UUID) async throws {
        try await service.leave(communityID: communityID)
    }

    func createPost(_ draft: ForumPostDraft) async throws -> ForumPost {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.title.count <= 180, draft.body.count <= 10000 else {
            throw LiftRankServiceError.invalidInput("Use a title up to 180 characters and a discussion up to 10,000 characters.")
        }
        return try await service.createPost(draft)
    }

    func mediaURL(for attachment: ForumAttachment) async throws -> URL {
        try await service.mediaURL(for: attachment)
    }

    func createComment(postID: UUID, body: String, parentCommentID: UUID?) async throws -> ForumComment {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && body.count <= 5000 else { throw LiftRankServiceError.invalidInput("Text is empty or exceeds the character limit.") }
        return try await service.createComment(postID: postID, body: body, parentCommentID: parentCommentID)
    }

    func updatePost(postID: UUID, title: String, body: String) async throws -> ForumPost {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 180 && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && body.count <= 10000 else { throw LiftRankServiceError.invalidInput("Text is empty or exceeds the character limit.") }
        return try await service.updatePost(postID: postID, title: title, body: body)
    }

    func updateComment(commentID: UUID, body: String) async throws -> ForumComment {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && body.count <= 5000 else { throw LiftRankServiceError.invalidInput("Text is empty or exceeds the character limit.") }
        return try await service.updateComment(commentID: commentID, body: body)
    }

    func deletePost(postID: UUID) async throws {
        try await service.deletePost(postID: postID)
    }

    func deleteComment(commentID: UUID) async throws {
        try await service.deleteComment(commentID: commentID)
    }

    func toggleVote(on post: ForumPost, direction: Int) async throws -> ForumPost {
        guard direction == 1 || direction == -1 else {
            throw LiftRankServiceError.invalidInput("Choose an upvote or downvote.")
        }
        let nextValue: Int? = post.currentUserVote == direction ? nil : direction
        try await service.vote(postID: post.id, value: nextValue)
        var updated = post
        updated.voteCount += (nextValue ?? 0) - (post.currentUserVote ?? 0)
        updated.currentUserVote = nextValue
        return updated
    }

    func vote(commentID: UUID, value: Int?) async throws {
        try await service.vote(commentID: commentID, value: value)
    }

    func watch(postID: UUID, watched: Bool) async throws {
        try await service.watch(postID: postID, watched: watched)
    }

    func report(targetType: String, targetID: UUID, communityID: UUID?, reason: String, note: String) async throws {
        try await service.report(targetType: targetType, targetID: targetID, communityID: communityID, reason: reason, note: note)
    }
}
