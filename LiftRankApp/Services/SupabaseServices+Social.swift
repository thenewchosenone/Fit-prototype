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

private struct WorkoutShareLikeParameters: Encodable {
    let targetShareID: UUID
    let liked: Bool
    enum CodingKeys: String, CodingKey { case targetShareID = "target_share_id", liked }
}

private struct WorkoutShareCommentParameters: Encodable {
    let targetShareID: UUID
    let commentBody: String
    enum CodingKeys: String, CodingKey {
        case targetShareID = "target_share_id"
        case commentBody = "comment_body"
    }
}

private struct WorkoutShareReportParameters: Encodable {
    let targetShareID: UUID
    let reportReason: String
    let reportNote: String
    enum CodingKeys: String, CodingKey {
        case targetShareID = "target_share_id"
        case reportReason = "report_reason"
        case reportNote = "report_note"
    }
}

private struct BlockDTO: Codable {
    let blockerID: UUID
    let blockedID: UUID
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case blockerID = "blocker_id", blockedID = "blocked_id", createdAt = "created_at" }
}
private struct ActivityDTO: Codable {
    let id: UUID
    let userID: UUID
    let username: String
    let displayName: String
    let title: String
    let detail: String
    let liftID: UUID?
    let workoutID: UUID?
    let createdAt: Date
    let isLiked: Bool
    let isSaved: Bool
    let likeCount: Int
    let commentCount: Int
    enum CodingKeys: String, CodingKey {
        case id, username, title, detail
        case userID = "user_id", displayName = "display_name", liftID = "lift_id", workoutID = "workout_id"
        case createdAt = "created_at", isLiked = "is_liked", isSaved = "is_saved"
        case likeCount = "like_count", commentCount = "comment_count"
    }
}

private struct ActivityCommentDTO: Codable {
    let id: UUID
    let activityID: UUID
    let authorID: UUID
    let authorName: String
    let body: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, body
        case activityID = "activity_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case createdAt = "created_at"
    }
    var comment: ActivityComment {
        ActivityComment(id: id, activityID: activityID, authorID: authorID, authorName: authorName, body: body, createdAt: createdAt)
    }
}

@MainActor
final class SupabaseSocialService: SocialService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func feed() async throws -> [ActivityItem] {
        do {
            let rows: [ActivityDTO] = try await client.rpc("get_followed_activity").execute().value
            return rows.map { row in
                let profile = UserProfile(
                    id: row.userID, username: row.username, displayName: row.displayName,
                    ageGroup: "Hidden", sexCategory: .open, heightInches: 0, bodyweightPounds: 0,
                    preferredUnit: .pounds, city: "", state: "", primaryGymID: UUID(), primaryGymName: "Hidden",
                    yearsExperience: 0, experienceLevel: .beginner, profileImageName: "person.crop.circle", followers: 0, following: 0,
                    hideExactAge: true, hideBodyweight: true, hideCity: true, hideGym: true, hideLiftVideos: false
                )
                return ActivityItem(
                    id: row.id, profile: profile, title: row.title, detail: row.detail,
                    liftID: row.liftID, workoutID: row.workoutID, createdAt: row.createdAt,
                    isLiked: row.isLiked, isSaved: row.isSaved,
                    likeCount: row.likeCount, commentCount: row.commentCount
                )
            }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
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
    func comments(activityID: UUID) async throws -> [ActivityComment] {
        do {
            let rows: [ActivityCommentDTO] = try await client.rpc(
                "get_workout_share_comments", params: ["target_share_id": activityID]
            ).execute().value
            return rows.map(\.comment)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func setActivityLiked(activityID: UUID, isLiked: Bool) async throws {
        do {
            try await client.rpc(
                "set_workout_share_liked",
                params: WorkoutShareLikeParameters(targetShareID: activityID, liked: isLiked)
            ).execute()
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func addActivityComment(activityID: UUID, body: String) async throws -> ActivityComment {
        do {
            let row: ActivityCommentDTO = try await client.rpc(
                "add_workout_share_comment",
                params: WorkoutShareCommentParameters(targetShareID: activityID, commentBody: body)
            ).single().execute().value
            return row.comment
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func shareWorkout(snapshotID: UUID, title: String, detail: String) async throws -> ActivityItem {
        do {
            try await client.rpc("share_completed_workout", params: [
                "target_workout_id": snapshotID.uuidString, "share_title": title, "share_detail": detail
            ]).execute()
            guard let item = try await feed().first(where: { $0.workoutID == snapshotID }) else {
                throw LiftRankServiceError.server("Shared workout could not be loaded.")
            }
            return item
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func removeWorkoutShare(activityID: UUID) async throws {
        do { try await client.rpc("remove_workout_share", params: ["target_share_id": activityID]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func reportActivity(activityID: UUID, reason: CommunityReportReason, note: String) async throws {
        do {
            try await client.rpc(
                "report_workout_share",
                params: WorkoutShareReportParameters(
                    targetShareID: activityID,
                    reportReason: reason.rawValue,
                    reportNote: note
                )
            ).execute()
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func block(userID: UUID) async throws { try await rpc("block_user", userID) }
    func unblock(userID: UUID) async throws { try await rpc("unblock_user", userID) }
    func blocks() async throws -> [UserBlockRecord] {
        do {
            let rows: [BlockDTO] = try await client.from("user_blocks").select().order("created_at", ascending: false).execute().value
            return rows.map { .init(blockerID: $0.blockerID, blockedID: $0.blockedID, createdAt: $0.createdAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    private func rpc(_ name: String, _ userID: UUID) async throws {
        do { try await client.rpc(name, params: ["target_user_id": userID]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}
