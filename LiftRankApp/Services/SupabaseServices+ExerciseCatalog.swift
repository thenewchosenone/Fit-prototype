import Foundation
import Supabase

@MainActor
final class SupabaseExerciseCatalogService: ExerciseCatalogService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func activeExercises() async throws -> [CatalogExercise] {
        do {
            let rows: [ExerciseDTO] = try await client.from("exercises").select("id,display_name,status,ranking_movement").eq("status", value: "active").order("display_name").execute().value
            return rows.map { CatalogExercise(id: $0.id, displayName: $0.displayName, status: $0.status, rankingMovement: $0.rankingMovement, metadata: [:]) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func resolve(identifier: String) async throws -> CatalogExercise? {
        do {
            let row: ExerciseDTO = try await client.rpc("resolve_exercise_identifier", params: ["identifier": identifier]).single().execute().value
            return CatalogExercise(id: row.id, displayName: row.displayName, status: row.status, rankingMovement: row.rankingMovement, metadata: [:])
        } catch {
            if String(describing: error).lowercased().contains("0 rows") { return nil }
            throw SupabaseServiceErrorMapper.map(error)
        }
    }
}

private struct ExerciseDTO: Codable {
    let id: String
    let displayName: String
    let status: String
    let rankingMovement: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case displayName = "display_name", rankingMovement = "ranking_movement"
    }
}
