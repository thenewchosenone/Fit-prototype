import Foundation
import Supabase

@MainActor
final class SupabaseGymService: GymService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func gyms() async throws -> [Gym] {
        do {
            let pageSize = 500
            var rows: [GymDTO] = []
            var offset = 0
            while true {
                let page: [GymDTO] = try await client.from("gyms")
                    .select("id,name,city,region")
                    .eq("status", value: "active")
                    .order("name")
                    .order("id")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute().value
                rows.append(contentsOf: page)
                guard page.count == pageSize else { break }
                offset += pageSize
            }
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
import Foundation
import Supabase

@MainActor
final class SupabaseLocationService: LocationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func searchCities(countryCode: String, region: String, query: String, limit: Int) async throws -> [LocationCitySuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        do {
            let params = CitySearchParameters(
                countryCode: countryCode,
                region: region,
                query: trimmedQuery,
                limit: limit
            )
            let rows: [LocationCityDTO] = try await client
                .rpc("search_cities", params: params)
                .execute()
                .value
            return rows.map(\.suggestion)
        } catch {
            throw SupabaseServiceErrorMapper.map(error)
        }
    }
}

@MainActor
final class BundledLocationService: LocationService {
    func searchCities(countryCode: String, region: String, query: String, limit: Int) async throws -> [LocationCitySuggestion] {
        LaunchLocationCatalog.citySuggestions(
            countryCode: countryCode,
            regionName: region,
            query: query,
            limit: limit
        )
    }
}

private struct CitySearchParameters: Encodable {
    let countryCode: String
    let region: String
    let query: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code_filter"
        case region = "region_filter"
        case query = "search_query"
        case limit = "result_limit"
    }
}

private struct LocationCityDTO: Decodable {
    let id: UUID
    let city: String
    let region: String
    let countryCode: String
    let countryName: String
    let population: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case city
        case region
        case countryCode = "country_code"
        case countryName = "country_name"
        case population
    }

    var suggestion: LocationCitySuggestion {
        LocationCitySuggestion(
            canonicalID: id,
            city: city,
            region: region,
            countryCode: countryCode,
            countryName: countryName,
            population: population
        )
    }
}
