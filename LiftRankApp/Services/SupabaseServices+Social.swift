import Foundation
import Supabase

private struct ProfileSearchParameters: Encodable {
    let searchQuery: String
    let resultLimit: Int
    enum CodingKeys: String, CodingKey {
        case searchQuery = "search_query"
        case resultLimit = "result_limit"
    }
}

private struct BlockDTO: Codable {
    let blockerID: UUID
    let blockedID: UUID
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case blockerID = "blocker_id", blockedID = "blocked_id", createdAt = "created_at" }
}

private struct ProfileReportParameters: Encodable {
    let targetUserID: UUID
    let reportReason: String
    let reportNote: String
    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
        case reportReason = "report_reason"
        case reportNote = "report_note"
    }
}

@MainActor
final class SupabaseSocialService: SocialService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] {
        do {
            let rows: [ProfileCardDTO] = try await client.rpc(
                "search_profile_cards",
                params: ProfileSearchParameters(searchQuery: query, resultLimit: max(1, min(limit, 50)))
            ).execute().value
            return rows.map {
                PublicProfileCard(
                    id: $0.id, username: $0.username, displayName: $0.displayName, bio: $0.bio,
                    avatarPath: $0.avatarPath, ageBand: $0.ageBand,
                    sexCategory: $0.sexCategory.flatMap(SexCategory.init(rawValue:)),
                    city: $0.city, region: $0.region, countryCode: $0.countryCode,
                    primaryGymID: $0.primaryGymID, primaryGymName: $0.primaryGymName
                )
            }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func report(userID: UUID, reason: ProfileReportReason, note: String) async throws {
        do {
            try await client.rpc(
                "report_profile",
                params: ProfileReportParameters(
                    targetUserID: userID,
                    reportReason: reason.rawValue,
                    reportNote: note
                )
            ).execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func block(userID: UUID) async throws { try await rpc("block_user", userID) }
    func unblock(userID: UUID) async throws { try await rpc("unblock_user", userID) }
    func blocks() async throws -> [UserBlockRecord] {
        do {
            let rows: [BlockDTO] = try await client.from("user_blocks").select().order("created_at", ascending: false).limit(500).execute().value
            return rows.map { .init(blockerID: $0.blockerID, blockedID: $0.blockedID, createdAt: $0.createdAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    private func rpc(_ name: String, _ userID: UUID) async throws {
        do { try await client.rpc(name, params: ["target_user_id": userID]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct ForumCommunityDTO: Codable {
    let id: UUID
    let slug: String
    let name: String
    let summary: String
    let details: String
    let category: String
    let visibility: String
    let accentHex: String

    enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, details, category, visibility
        case accentHex = "accent_hex"
    }

    var model: ForumCommunity {
        ForumCommunity(id: id, slug: slug, name: name, summary: summary, details: details, category: category, visibility: visibility, accentHex: accentHex)
    }
}

private struct ForumPostDTO: Codable {
    let id: UUID
    let communityID: UUID?
    let gymID: UUID?
    let authorID: UUID
    let kind: String
    let title: String
    let body: String
    let tag: String?
    let liftID: UUID?
    let isPinned: Bool
    let isLocked: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, tag
        case communityID = "community_id"
        case gymID = "gym_id"
        case authorID = "author_id"
        case liftID = "lift_id"
        case isPinned = "is_pinned"
        case isLocked = "is_locked"
        case createdAt = "created_at"
    }

    var model: ForumPost {
        ForumPost(id: id, communityID: communityID, gymID: gymID, authorID: authorID, kind: kind, title: title, body: body, tag: tag, liftID: liftID, isPinned: isPinned, isLocked: isLocked, createdAt: createdAt)
    }
}

private struct ForumCommentDTO: Codable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let parentCommentID: UUID?
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case postID = "post_id"
        case authorID = "author_id"
        case parentCommentID = "parent_comment_id"
        case createdAt = "created_at"
    }

    var model: ForumComment {
        ForumComment(id: id, postID: postID, authorID: authorID, parentCommentID: parentCommentID, body: body, createdAt: createdAt)
    }
}

private struct ForumPostInsert: Encodable {
    let id: UUID
    let communityID: UUID
    let authorID: UUID
    let kind: String
    let title: String
    let body: String
    let tag: String?
    let liftID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, tag
        case communityID = "community_id"
        case authorID = "author_id"
        case liftID = "lift_id"
    }
}

private struct ForumCommentInsert: Encodable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let parentCommentID: UUID?
    let body: String

    enum CodingKeys: String, CodingKey {
        case id, body
        case postID = "post_id"
        case authorID = "author_id"
        case parentCommentID = "parent_comment_id"
    }
}

private struct JoinForumParameters: Encodable {
    let targetCommunityID: UUID
    let requestNote: String
    enum CodingKeys: String, CodingKey {
        case targetCommunityID = "target_community_id"
        case requestNote = "request_note"
    }
}

private struct ForumVoteInsert: Encodable {
    let postID: UUID
    let userID: UUID
    let value: Int
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case value
    }
}

private struct ForumWatchInsert: Encodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey { case postID = "post_id"; case userID = "user_id" }
}

private struct ForumReportInsert: Encodable {
    let id: UUID
    let communityID: UUID?
    let targetType: String
    let targetID: UUID
    let reporterID: UUID
    let reason: String
    let note: String
    enum CodingKeys: String, CodingKey {
        case id, reason, note
        case communityID = "community_id"
        case targetType = "target_type"
        case targetID = "target_id"
        case reporterID = "reporter_id"
    }
}

private struct ForumReportDTO: Codable {
    let id: UUID
    let communityID: UUID?
    let targetType: String
    let targetID: UUID
    let reason: String
    let note: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, reason, note
        case communityID = "community_id"
        case targetType = "target_type"
        case targetID = "target_id"
        case createdAt = "created_at"
    }

    var model: ForumReport { ForumReport(id: id, communityID: communityID, targetType: targetType, targetID: targetID, reason: reason, note: note, createdAt: createdAt) }
}

private struct ModerateForumParameters: Encodable {
    let targetPostID: UUID
    let action: String
    let reason: String
    enum CodingKeys: String, CodingKey {
        case targetPostID = "target_post_id"
        case action, reason
    }
}

@MainActor
final class SupabaseForumService: ForumService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func communities() async throws -> [ForumCommunity] {
        do {
            let rows: [ForumCommunityDTO] = try await client.from("forum_communities")
                .select("id,slug,name,summary,details,category,visibility,accent_hex")
                .is("archived_at", value: nil)
                .neq("visibility", value: "Invite Only")
                .order("category")
                .order("name")
                .execute().value
            return rows.map(\.model)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func posts(communityID: UUID?, limit: Int) async throws -> [ForumPost] {
        do {
            var query = client.from("forum_posts").select("id,community_id,gym_id,author_id,kind,title,body,tag,lift_id,is_pinned,is_locked,created_at").is("removed_at", value: nil)
            if let communityID { query = query.eq("community_id", value: communityID) }
            let rows: [ForumPostDTO] = try await query.order("is_pinned", ascending: false).order("created_at", ascending: false).limit(min(max(limit, 1), 100)).execute().value
            return rows.map(\.model)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func thread(postID: UUID) async throws -> ForumThread? {
        do {
            let post: ForumPostDTO = try await client.from("forum_posts").select("id,community_id,gym_id,author_id,kind,title,body,tag,lift_id,is_pinned,is_locked,created_at").eq("id", value: postID).is("removed_at", value: nil).single().execute().value
            let comments: [ForumCommentDTO] = try await client.from("forum_comments").select("id,post_id,author_id,parent_comment_id,body,created_at").eq("post_id", value: postID).is("removed_at", value: nil).order("created_at").execute().value
            return ForumThread(post: post.model, comments: comments.map(\.model))
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func join(communityID: UUID, requestNote: String) async throws -> String {
        do { return try await client.rpc("join_forum_community", params: JoinForumParameters(targetCommunityID: communityID, requestNote: String(requestNote.prefix(1000)))).execute().value }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func leave(communityID: UUID) async throws {
        do { try await client.rpc("leave_forum_community", params: ["target_community_id": communityID]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func createPost(_ draft: ForumPostDraft) async throws -> ForumPost {
        do {
            let user = try await client.auth.session.user
            let inserted: ForumPostDTO = try await client.from("forum_posts").insert(ForumPostInsert(id: UUID(), communityID: draft.communityID, authorID: user.id, kind: draft.kind, title: String(draft.title.prefix(180)), body: String(draft.body.prefix(10000)), tag: draft.tag, liftID: draft.liftID)).select("id,community_id,gym_id,author_id,kind,title,body,tag,lift_id,is_pinned,is_locked,created_at").single().execute().value
            return inserted.model
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func createComment(postID: UUID, body: String, parentCommentID: UUID?) async throws -> ForumComment {
        do {
            let user = try await client.auth.session.user
            let inserted: ForumCommentDTO = try await client.from("forum_comments").insert(ForumCommentInsert(id: UUID(), postID: postID, authorID: user.id, parentCommentID: parentCommentID, body: String(body.prefix(5000)))).select("id,post_id,author_id,parent_comment_id,body,created_at").single().execute().value
            return inserted.model
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func vote(postID: UUID, value: Int?) async throws {
        do {
            let user = try await client.auth.session.user
            if let value { try await client.from("forum_post_votes").upsert(ForumVoteInsert(postID: postID, userID: user.id, value: value == -1 ? -1 : 1), onConflict: "post_id,user_id").execute() }
            else { try await client.from("forum_post_votes").delete().eq("post_id", value: postID).eq("user_id", value: user.id).execute() }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func watch(postID: UUID, watched: Bool) async throws {
        do {
            let user = try await client.auth.session.user
            if watched { try await client.from("forum_post_watches").upsert(ForumWatchInsert(postID: postID, userID: user.id), onConflict: "post_id,user_id").execute() }
            else { try await client.from("forum_post_watches").delete().eq("post_id", value: postID).eq("user_id", value: user.id).execute() }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func report(targetType: String, targetID: UUID, communityID: UUID?, reason: String, note: String) async throws {
        do {
            let user = try await client.auth.session.user
            try await client.from("forum_reports").insert(ForumReportInsert(id: UUID(), communityID: communityID, targetType: targetType, targetID: targetID, reporterID: user.id, reason: String(reason.prefix(80)), note: String(note.prefix(1000)))).execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func reports() async throws -> [ForumReport] {
        do {
            let rows: [ForumReportDTO] = try await client.from("forum_reports").select("id,community_id,target_type,target_id,reason,note,created_at").eq("status", value: "Open").order("created_at").execute().value
            return rows.map(\.model)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func moderate(postID: UUID, action: String, reason: String) async throws {
        do { try await client.rpc("moderate_forum_post", params: ModerateForumParameters(targetPostID: postID, action: String(action.prefix(40)), reason: String(reason.prefix(1000)))).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}
