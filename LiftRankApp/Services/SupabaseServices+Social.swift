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
