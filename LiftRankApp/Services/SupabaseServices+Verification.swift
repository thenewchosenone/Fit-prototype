import Foundation
import Supabase

private struct ModerateLiftParameters: Encodable {
    let liftID: UUID; let decision: String; let note: String
    enum CodingKeys: String, CodingKey { case liftID = "lift_id", decision, note }
}
@MainActor
final class SupabaseVerificationService: VerificationService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func pendingSubmissions() async throws -> [LiftSubmission] {
        do {
            let ids: [ModerationQueueIDDTO] = try await client.rpc("get_moderation_queue_ids").execute().value
            let all = try await SupabaseLiftService(client: client).submissions()
            let pending = Set(ids.map(\.liftID))
            return all.filter { pending.contains($0.id) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission {
        let decision: LiftModeratorDecision = status == .rejected ? .reject : .uphold
        return try await moderate(liftID: lift.id, decision: decision, note: note ?? "")
    }
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission {
        do {
            try await client.rpc("moderate_lift", params: ModerateLiftParameters(liftID: liftID, decision: decision.rawValue, note: note)).execute()
            guard let lift = try await SupabaseLiftService(client: client).submissions().first(where: { $0.id == liftID }) else {
                throw LiftRankServiceError.server("The moderated lift could not be refreshed.")
            }
            return lift
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct ModerationQueueIDDTO: Decodable {
    let liftID: UUID
    enum CodingKeys: String, CodingKey { case liftID = "lift_id" }
}
