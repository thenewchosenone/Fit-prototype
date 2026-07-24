import Foundation
import Supabase

@MainActor
final class SupabaseMessagingService: MessagingService {
    private struct SendParameters: Encodable {
        let targetThreadID: UUID
        let messageBody: String
        enum CodingKeys: String, CodingKey { case targetThreadID = "target_thread_id", messageBody = "message_body" }
    }
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func createOrGetThread(with userID: UUID) async throws -> DirectMessageThread { do { let row:MessageThreadDTO=try await client.rpc("create_or_get_message_thread",params:["target_user_id":userID]).single().execute().value;return row.thread } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func threads() async throws -> [DirectMessageThread] { do { let rows: [MessageThreadDTO] = try await client.rpc("get_message_threads").execute().value; return rows.map(\.thread) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func messages(for thread: DirectMessageThread) async throws -> [DirectMessage] { do { let rows: [MessageDTO] = try await client.rpc("get_thread_messages", params: ["target_thread_id": thread.id]).execute().value; return rows.map(\.message) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func sendMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessage? { do { let row: MessageDTO = try await client.rpc("send_message", params: SendParameters(targetThreadID: thread.id, messageBody: body)).single().execute().value; return row.message } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func deleteMessage(_ message: DirectMessage) async throws { try await rpc("delete_message", id: message.id) }
    func deleteThread(_ thread: DirectMessageThread) async throws { try await rpc("hide_message_thread", id: thread.id) }
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws { do { try await client.rpc("report_message", params: ["target_message_id": message.id.uuidString, "report_reason": reason.rawValue, "report_note": note]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    private func rpc(_ name: String, id: UUID) async throws { do { try await client.rpc(name, params: ["target_id": id]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct MessageThreadDTO: Decodable {
    let id: UUID; let participantIDs: [UUID]; let createdAt: Date; let updatedAt: Date
    enum CodingKeys: String, CodingKey { case id; case participantIDs = "participant_ids", createdAt = "created_at", updatedAt = "updated_at" }
    var thread: DirectMessageThread { .init(id: id, participantIDs: participantIDs, createdAt: createdAt, updatedAt: updatedAt) }
}
private struct MessageDTO: Decodable {
    let id: UUID; let threadID: UUID; let senderID: UUID; let body: String; let createdAt: Date; let isRead: Bool; let isReported: Bool
    enum CodingKeys: String, CodingKey { case id, body; case threadID = "thread_id", senderID = "sender_id", createdAt = "created_at", isRead = "is_read", isReported = "is_reported" }
    var message: DirectMessage { .init(id: id, threadID: threadID, senderID: senderID, body: body, createdAt: createdAt, isRead: isRead, isReported: isReported) }
}
