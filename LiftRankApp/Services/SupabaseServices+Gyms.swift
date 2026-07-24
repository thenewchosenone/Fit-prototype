import Foundation
import Supabase

@MainActor
final class SupabaseGymService: GymService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func gyms() async throws -> [Gym] {
        do {
            let rows: [GymDTO] = try await client.from("gyms").select("id,name,city,region").eq("status", value: "active").order("name").execute().value
            return rows.map { Gym(id: $0.id, name: $0.name, city: $0.city ?? "", state: $0.region ?? "", memberCount: 0, verifiedLiftCount: 0) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func memberships() async throws -> [GymMembershipRecord] {
        do {
            let rows: [MembershipDTO] = try await client.from("gym_memberships").select().is("left_at", value: nil).execute().value
            return rows.map { GymMembershipRecord(userID: $0.userID, gymID: $0.gymID, isPrimary: $0.isPrimary, joinedAt: $0.joinedAt, leftAt: $0.leftAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

@MainActor
final class SupabaseGymMembershipService: GymMembershipService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool {
        do {
            try await client.rpc("join_gym", params: JoinGymParameters(targetGymID: gym.id, makePrimary: false)).execute()
            return true
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func leave(_ gym: Gym) async throws {
        do { try await client.rpc("leave_gym", params: ["target_gym_id": gym.id]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func setPrimary(_ gym: Gym) async throws {
        do { try await client.rpc("set_primary_gym", params: ["target_gym_id": gym.id]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct GymDTO: Codable {
    let id: UUID
    let name: String
    let city: String?
    let region: String?

    enum CodingKeys: String, CodingKey { case id, name, city, region }
}

private struct MembershipDTO: Codable {
    let userID: UUID
    let gymID: UUID
    let isPrimary: Bool
    let joinedAt: Date
    let leftAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id", gymID = "gym_id", isPrimary = "is_primary"
        case joinedAt = "joined_at", leftAt = "left_at"
    }
}

private struct JoinGymParameters: Encodable {
    let targetGymID: UUID
    let makePrimary: Bool

    enum CodingKeys: String, CodingKey { case targetGymID = "target_gym_id", makePrimary = "make_primary" }
}
