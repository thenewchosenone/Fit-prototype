import Foundation

@MainActor
final class ForumStore {
    private var service: any ForumService

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
        try await service.createPost(draft)
    }

    func createComment(postID: UUID, body: String, parentCommentID: UUID?) async throws -> ForumComment {
        try await service.createComment(postID: postID, body: body, parentCommentID: parentCommentID)
    }

    func vote(postID: UUID, value: Int?) async throws {
        try await service.vote(postID: postID, value: value)
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
