import Foundation
import Supabase

final class SupabaseWorkoutSyncService: WorkoutSyncService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func plans() async throws -> [WorkoutPlanDocument] {
        do {
            let pageSize = 100
            var rows: [WorkoutPlanDocumentDTO] = []
            var offset = 0
            while true {
                let page: [WorkoutPlanDocumentDTO] = try await client.from("workout_plan_documents")
                    .select()
                    .order("updated_at", ascending: false)
                    .order("id")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute().value
                rows.append(contentsOf: page)
                guard page.count == pageSize else { break }
                offset += pageSize
            }
            return rows.compactMap(\.document)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        guard !document.isSeededDemoData else { throw LiftRankServiceError.invalidInput("Demo data cannot be synced.") }
        do {
            let userID = try await client.auth.session.user.id
            let next = WorkoutPlanDocumentDTO(document: document, ownerID: userID, revision: max(1, expectedRevision + 1))
            if expectedRevision == 0 {
                do {
                    let saved: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents").insert(next).select().single().execute().value
                    guard let value = saved.document else { throw LiftRankServiceError.server("The saved plan could not be read.") }
                    return .saved(value)
                } catch {
                    return try await preserveConflict(document, expectedRevision: expectedRevision, ownerID: userID)
                }
            }

            let updated: [WorkoutPlanDocumentDTO] = try await client
                .from("workout_plan_documents")
                .update(next)
                .eq("owner_id", value: userID)
                .eq("id", value: document.id)
                .eq("revision", value: expectedRevision)
                .select()
                .execute()
                .value
            guard let saved = updated.first?.document else {
                return try await preserveConflict(document, expectedRevision: expectedRevision, ownerID: userID)
            }
            return .saved(saved)
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func deletePlan(id: UUID) async throws {
        do {
            let userID = try await client.auth.session.user.id
            try await client.from("workout_plan_documents")
                .delete()
                .eq("owner_id", value: userID)
                .eq("id", value: id)
                .execute()
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        do {
            let pageSize = 200
            var rows: [CompletedWorkoutSnapshotDTO] = []
            var offset = 0
            while true {
                var query = client.from("completed_workout_snapshots").select()
                if let since { query = query.gt("completed_at", value: since) }
                let page: [CompletedWorkoutSnapshotDTO] = try await query
                    .order("completed_at", ascending: true)
                    .order("id")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute().value
                rows.append(contentsOf: page)
                guard page.count == pageSize else { break }
                offset += pageSize
            }
            return rows.compactMap(\.snapshot)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        guard !snapshot.isSeededDemoData else { return }
        do {
            let userID = try await client.auth.session.user.id
            let row = CompletedWorkoutSnapshotDTO(snapshot: snapshot, ownerID: userID)
            try await client.from("completed_workout_snapshots").upsert(row, onConflict: "owner_id,id").execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func deleteCompletedWorkout(id: UUID) async throws {
        do {
            let userID = try await client.auth.session.user.id
            try await client.from("completed_workout_snapshots")
                .delete()
                .eq("owner_id", value: userID)
                .eq("id", value: id)
                .execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    private func preserveConflict(_ document: WorkoutPlanDocument, expectedRevision: Int, ownerID: UUID) async throws -> WorkoutSyncResult {
        let serverRow: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents")
            .select().eq("owner_id", value: ownerID).eq("id", value: document.id).single().execute().value
        guard let server = serverRow.document else { throw LiftRankServiceError.server("The server plan could not be read.") }
        var localCopy = document
        localCopy.id = UUID()
        localCopy.name = "\(document.name) (Conflict copy)"
        localCopy.revision = 1
        localCopy.conflictOfRevision = expectedRevision
        localCopy.isConflictCopy = true
        localCopy.updatedAt = .now
        let copyRow = WorkoutPlanDocumentDTO(document: localCopy, ownerID: ownerID, revision: 1)
        let inserted: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents").insert(copyRow).select().single().execute().value
        guard let savedCopy = inserted.document else { throw LiftRankServiceError.server("The conflict copy could not be read.") }
        return .conflict(server: server, localCopy: savedCopy)
    }
}

private struct WorkoutPlanDocumentDTO: Codable {
    let id: UUID
    let ownerID: UUID
    let revision: Int
    let name: String
    let payload: String
    let conflictOfRevision: Int?
    let isConflictCopy: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, revision, name, payload
        case ownerID = "owner_id"
        case conflictOfRevision = "conflict_of_revision"
        case isConflictCopy = "is_conflict_copy"
        case updatedAt = "updated_at"
    }

    init(document: WorkoutPlanDocument, ownerID: UUID, revision: Int) {
        id = document.id; self.ownerID = ownerID; self.revision = revision; name = document.name
        payload = document.payload.base64EncodedString(); conflictOfRevision = document.conflictOfRevision
        isConflictCopy = document.isConflictCopy; updatedAt = document.updatedAt
    }

    var document: WorkoutPlanDocument? {
        guard let data = Data(base64Encoded: payload) else { return nil }
        return WorkoutPlanDocument(id: id, ownerID: ownerID, revision: revision, name: name, payload: data, updatedAt: updatedAt, conflictOfRevision: conflictOfRevision, isConflictCopy: isConflictCopy)
    }
}

private struct CompletedWorkoutSnapshotDTO: Codable {
    let id: UUID
    let ownerID: UUID
    let payload: String
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, payload
        case ownerID = "owner_id"
        case completedAt = "completed_at"
    }

    init(snapshot: CompletedWorkoutSnapshot, ownerID: UUID) {
        id = snapshot.id; self.ownerID = ownerID; payload = snapshot.payload.base64EncodedString(); completedAt = snapshot.completedAt
    }

    var snapshot: CompletedWorkoutSnapshot? {
        guard let data = Data(base64Encoded: payload) else { return nil }
        return CompletedWorkoutSnapshot(id: id, ownerID: ownerID, payload: data, completedAt: completedAt)
    }
}
