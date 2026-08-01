import Foundation
import Supabase

// MARK: - Leaderboard feed service

private struct LeaderboardParameters: Encodable {
    let exerciseID: String?
    let rankingType: String
    let gymID: UUID?
    let city: String?
    let region: String?
    let country: String?
    let ageBand: String?
    let sexCategory: String?
    let weightMinKG: Double?
    let weightMaxKG: Double?
    let verifiedOnly: Bool
    let timeRange: String

    enum CodingKeys: String, CodingKey {
        case exerciseID = "exercise_id"
        case rankingType = "ranking_type"
        case gymID = "gym_id"
        case city
        case region
        case country
        case ageBand = "age_band"
        case sexCategory = "sex_category"
        case weightMinKG = "weight_min_kg"
        case weightMaxKG = "weight_max_kg"
        case verifiedOnly = "verified_only"
        case timeRange = "time_range"
    }
}

private struct RankedLiftIDDTO: Codable {
    let rank: Int
    let liftID: UUID
    let userID: UUID
    let rankMovement: Int
    let score: Double
    let bodyweightVisible: Bool

    enum CodingKeys: String, CodingKey {
        case rank
        case score
        case liftID = "lift_id"
        case userID = "user_id"
        case rankMovement = "rank_movement"
        case bodyweightVisible = "bodyweight_visible"
    }
}

@MainActor
final class SupabaseLeaderboardService: LeaderboardService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        do {
            let weightClass = filters.weightClassID.flatMap { id in WeightClassCatalog.all.first { $0.id == id } }
            let params = LeaderboardParameters(
                exerciseID: filters.exerciseID,
                rankingType: filters.rankingType.rawValue,
                gymID: filters.gymID,
                city: filters.city,
                region: filters.state,
                country: filters.country,
                ageBand: filters.ageGroup,
                sexCategory: filters.sexCategory?.rawValue,
                weightMinKG: weightClass?.minKilograms,
                weightMaxKG: weightClass?.maxKilograms,
                verifiedOnly: verifiedOnly,
                timeRange: filters.timeRange
            )

            let rows: [RankedLiftIDDTO] = try await client
                .rpc("get_ranked_lift_ids", params: params)
                .limit(200)
                .execute()
                .value
            let submissions = try await SupabaseLiftService(client: client).submissions(ids: rows.map(\.liftID))
            let lifts = Dictionary(uniqueKeysWithValues: submissions.map { ($0.id, $0) })

            var entries: [LeaderboardEntry] = []
            for row in rows {
                guard let lift = lifts[row.liftID] else { continue }
                let card = try await SupabaseProfileService(client: client).profileCard(userID: row.userID)
                let profile = SupabaseProfileMapper.leaderboard(
                    card: card,
                    bodyweightPounds: lift.bodyweightAtLift,
                    fallbackGymID: lift.gymID,
                    bodyweightVisible: row.bodyweightVisible
                )
                entries.append(
                    LeaderboardEntry(
                        rank: row.rank,
                        profile: profile,
                        lift: lift,
                        rankMovement: row.rankMovement,
                        score: row.score,
                        powerliftingBreakdown: nil
                    )
                )
            }
            return entries
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}
