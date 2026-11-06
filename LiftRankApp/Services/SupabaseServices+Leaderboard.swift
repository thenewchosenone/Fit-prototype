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
    let verifiedOnly: Bool?
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let exerciseID { try container.encode(exerciseID, forKey: .exerciseID) }
        else { try container.encodeNil(forKey: .exerciseID) }
        try container.encode(rankingType, forKey: .rankingType)
        if let gymID { try container.encode(gymID, forKey: .gymID) }
        else { try container.encodeNil(forKey: .gymID) }
        if let city { try container.encode(city, forKey: .city) }
        else { try container.encodeNil(forKey: .city) }
        if let region { try container.encode(region, forKey: .region) }
        else { try container.encodeNil(forKey: .region) }
        if let country { try container.encode(country, forKey: .country) }
        else { try container.encodeNil(forKey: .country) }
        if let ageBand { try container.encode(ageBand, forKey: .ageBand) }
        else { try container.encodeNil(forKey: .ageBand) }
        if let sexCategory { try container.encode(sexCategory, forKey: .sexCategory) }
        else { try container.encodeNil(forKey: .sexCategory) }
        if let weightMinKG { try container.encode(weightMinKG, forKey: .weightMinKG) }
        else { try container.encodeNil(forKey: .weightMinKG) }
        if let weightMaxKG { try container.encode(weightMaxKG, forKey: .weightMaxKG) }
        else { try container.encodeNil(forKey: .weightMaxKG) }
        if let verifiedOnly { try container.encode(verifiedOnly, forKey: .verifiedOnly) }
        try container.encode(timeRange, forKey: .timeRange)
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
            let selfReportedOnly = filters.verificationLevel == .selfReported && !verifiedOnly
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
                verifiedOnly: selfReportedOnly ? nil : verifiedOnly,
                timeRange: filters.timeRange
            )

            let rows: [RankedLiftIDDTO] = try await client
                .rpc(selfReportedOnly ? "get_self_reported_ranked_lift_ids" : "get_ranked_lift_ids", params: params)
                .limit(200)
                .execute()
                .value
            let submissions = try await SupabaseLiftService(client: client).submissions(ids: rows.map(\.liftID))
            let lifts = Dictionary(uniqueKeysWithValues: submissions.map { ($0.id, $0) })

            let profileService = SupabaseProfileService(client: client)
            var seenUsers = Set<UUID>()
            let userIDs = rows.filter { lifts[$0.liftID] != nil }.map(\.userID).filter { seenUsers.insert($0).inserted }
            var cardsByUserID: [UUID: PublicProfileCard] = [:]
            for start in stride(from: 0, to: userIDs.count, by: 8) {
                let batch = Array(userIDs[start..<min(start + 8, userIDs.count)])
                let tasks = batch.map { userID in
                    Task { try await profileService.profileCard(userID: userID) }
                }
                var firstError: Error?
                for (userID, task) in zip(batch, tasks) {
                    do {
                        cardsByUserID[userID] = try await task.value
                    } catch {
                        firstError = firstError ?? error
                    }
                }
                if let firstError { throw firstError }
            }

            var entries: [LeaderboardEntry] = []
            for row in rows {
                guard let lift = lifts[row.liftID], let card = cardsByUserID[row.userID] else { continue }
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
        catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}
