import Foundation
import Supabase

private struct LegalAcceptanceDTO: Codable {
    let id: UUID
    let userID: UUID
    let documentKind: String
    let documentVersion: String
    let acceptedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case documentKind = "document_kind"
        case documentVersion = "document_version"
        case acceptedAt = "accepted_at"
    }
}

private struct LegalAcceptanceInsertDTO: Encodable {
    let userID: UUID
    let documentKind: String
    let documentVersion: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case documentKind = "document_kind"
        case documentVersion = "document_version"
    }
}

@MainActor
final class SupabaseLegalAcceptanceService: LegalAcceptanceService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func acceptances() async throws -> [LegalAcceptanceRecord] {
        do {
            let rows: [LegalAcceptanceDTO] = try await client
                .from("legal_acceptances")
                .select()
                .execute()
                .value

            return rows.map {
                LegalAcceptanceRecord(
                    id: $0.id,
                    userID: $0.userID,
                    documentKind: $0.documentKind,
                    documentVersion: $0.documentVersion,
                    acceptedAt: $0.acceptedAt
                )
            }
        } catch {
            throw SupabaseServiceErrorMapper.map(error)
        }
    }

    func accept(documents: [LegalDocument]) async throws {
        guard !documents.isEmpty else { return }

        do {
            let userID = try await client.auth.session.user.id
            let accepted = try await acceptances()
            let acceptedKeys = Set(accepted.map { "\($0.documentKind):\($0.documentVersion)" })
            let rows = documents
                .filter { !acceptedKeys.contains("\($0.kind.rawValue):\($0.version)") }
                .map {
                    LegalAcceptanceInsertDTO(
                        userID: userID,
                        documentKind: $0.kind.rawValue,
                        documentVersion: $0.version
                    )
                }

            guard !rows.isEmpty else { return }

            try await client
                .from("legal_acceptances")
                .insert(rows)
                .execute()
        } catch {
            throw SupabaseServiceErrorMapper.map(error)
        }
    }
}

struct SupabaseAccountDeletionService: AccountDeletionService {
    let client: SupabaseClient

    func deleteAccount() async throws {
        do {
            try await client.functions.invoke("delete-account")
        } catch {
            throw SupabaseServiceErrorMapper.map(error)
        }
    }
}
