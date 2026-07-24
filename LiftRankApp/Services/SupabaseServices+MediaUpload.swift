import Foundation
import Supabase

private struct MediaDTO: Codable {
    let id: UUID; let ownerID: UUID; let storagePath: String; let contentType: String; let byteCount: Int; let createdAt: Date
    enum CodingKeys: String, CodingKey { case id; case ownerID = "owner_id", storagePath = "storage_path", contentType = "content_type", byteCount = "byte_count", createdAt = "created_at" }
}
@MainActor
final class SupabaseMediaUploadService: MediaUploadService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func upload(localURL: URL?) async throws -> URL? { guard let localURL else { return nil }; let asset = try await uploadLiftVideo(localURL: localURL, liftID: UUID(), progress: { _ in }); return try await signedPlaybackURL(assetID: asset.id) }
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset {
        do {
            let userID = try await client.auth.session.user.id
            let assetID = UUID(); let path = "\(userID.uuidString)/\(liftID.uuidString)/\(assetID.uuidString).mov"
            _ = try await client.storage.from("lift-videos").upload(path, fileURL: localURL, options: FileOptions(cacheControl: "3600", contentType: "video/quicktime", upsert: false))
            progress(0.9)
            let size = (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let dto: MediaDTO = try await client.rpc("complete_lift_media_upload", params: CompleteMediaParameters(assetID: assetID, liftID: liftID, storagePath: path, contentType: "video/quicktime", byteCount: size)).single().execute().value
            progress(1)
            return .init(id: dto.id, ownerID: dto.ownerID, storagePath: dto.storagePath, contentType: dto.contentType, byteCount: dto.byteCount, createdAt: dto.createdAt)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func signedPlaybackURL(assetID: UUID) async throws -> URL {
        do { let dto: MediaDTO = try await client.rpc("get_lift_media_for_playback", params: ["asset_id": assetID]).single().execute().value; return try await client.storage.from("lift-videos").createSignedURL(path: dto.storagePath, expiresIn: 300) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct CompleteMediaParameters: Encodable {
    let assetID: UUID; let liftID: UUID; let storagePath: String; let contentType: String; let byteCount: Int
    enum CodingKeys: String, CodingKey {
        case assetID = "target_asset_id", liftID = "target_lift_id"
        case storagePath = "uploaded_storage_path", contentType = "uploaded_content_type", byteCount = "uploaded_byte_count"
    }
}
