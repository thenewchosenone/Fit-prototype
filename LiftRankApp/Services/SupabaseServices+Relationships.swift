import Foundation
import Supabase

@MainActor
final class SupabaseFriendRelationshipService: FriendRelationshipService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func relationships() async throws -> [FriendRelationshipRecord] {
        do {
            let rows: [RelationshipDTO] = try await client.from("friend_relationships").select().order("created_at", ascending: false).execute().value
            return rows.map { FriendRelationshipRecord(id: $0.id, userLowID: $0.userLowID, userHighID: $0.userHighID, requestedBy: $0.requestedBy, status: $0.status, createdAt: $0.createdAt, respondedAt: $0.respondedAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func request(userID: UUID) async throws { try await rpc("request_friendship", RelationshipTargetParameters(targetUserID: userID)) }
    func respond(relationshipID: UUID, accept: Bool) async throws { try await rpc("respond_to_friendship", RelationshipResponseParameters(relationshipID: relationshipID, acceptRequest: accept)) }
    func cancel(relationshipID: UUID) async throws { try await rpc("cancel_friendship", RelationshipIDParameters(relationshipID: relationshipID)) }
    func remove(relationshipID: UUID) async throws { try await rpc("remove_friendship", RelationshipIDParameters(relationshipID: relationshipID)) }

    private func rpc<Parameters: Encodable>(_ name: String, _ params: Parameters) async throws {
        do { try await client.rpc(name, params: params).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct RelationshipDTO: Codable {
    let id: UUID
    let userLowID: UUID
    let userHighID: UUID
    let requestedBy: UUID
    let status: FriendRelationshipState
    let createdAt: Date
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userLowID = "user_low_id", userHighID = "user_high_id"
        case requestedBy = "requested_by", createdAt = "created_at", respondedAt = "responded_at"
    }
}

private struct RelationshipTargetParameters: Encodable {
    let targetUserID: UUID
    enum CodingKeys: String, CodingKey { case targetUserID = "target_user_id" }
}

private struct RelationshipIDParameters: Encodable {
    let relationshipID: UUID
    enum CodingKeys: String, CodingKey { case relationshipID = "relationship_id" }
}

private struct RelationshipResponseParameters: Encodable {
    let relationshipID: UUID
    let acceptRequest: Bool

    enum CodingKeys: String, CodingKey { case relationshipID = "relationship_id", acceptRequest = "accept_request" }
}
