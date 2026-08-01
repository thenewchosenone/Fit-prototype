import Foundation
import Supabase

@MainActor
final class SupabaseNotificationService: NotificationService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func notifications() async throws -> [NotificationItem] { do { let rows:[NotificationDTO]=try await client.from("notifications").select().order("created_at",ascending:false).limit(100).execute().value;return rows.map(\.notification) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func markRead(notificationID: UUID) async throws { do { try await client.from("notifications").update(["read_at": Date().ISO8601Format()]).eq("id", value: notificationID).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func registerDevice(_ registration: PushDeviceRegistration) async throws { do { try await client.rpc("register_device_token", params: DeviceTokenParameters(registration:registration)).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func revokeDevice(deviceID: String) async throws { do { try await client.rpc("revoke_device_token", params: ["target_device_id": deviceID]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct NotificationDTO:Decodable{let id:UUID;let title:String;let body:String;let kind:String;let destination:NotificationDestination;let readAt:Date?;let createdAt:Date;enum CodingKeys:String,CodingKey{case id,title,body,kind,destination;case readAt="read_at",createdAt="created_at"};var notification:NotificationItem{.init(id:id,title:title,message:body,kind:kind,createdAt:createdAt,isRead:readAt != nil,destination:destination)}}
private struct DeviceTokenParameters:Encodable{let id:UUID;let deviceID:String;let token:String;let environment:String;enum CodingKeys:String,CodingKey{case id,token,environment;case deviceID="target_device_id"};init(registration:PushDeviceRegistration){id=registration.id;deviceID=registration.deviceID;token=registration.token;environment=registration.environment}}
