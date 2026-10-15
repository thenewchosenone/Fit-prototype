import Foundation
import Supabase

private struct AnalyticsEventInsertDTO: Encodable {
    let id: UUID
    let userID: UUID
    let name: String
    let properties: [String: String]
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case properties
        case occurredAt = "occurred_at"
    }
}

struct SupabaseAnalyticsService: AnalyticsService {
    let client: SupabaseClient
    func track(_ event: AnalyticsEventRecord) async {
        let row = AnalyticsEventInsertDTO(
            id: event.id,
            userID: event.userID,
            name: event.name.rawValue,
            properties: event.properties,
            occurredAt: event.occurredAt
        )
        _ = try? await client.from("analytics_events").insert(row).execute()
    }
}
