import AVFoundation
import Foundation
import Supabase

enum LiftVideoPolicy {
    static let maximumDuration: TimeInterval = 30

    static func allows(duration: TimeInterval) -> Bool {
        duration.isFinite && duration >= 0 && duration <= maximumDuration
    }

    static func validateDuration(of url: URL) async throws {
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        guard allows(duration: duration) else { throw LiftVideoPolicyError.tooLong }
    }
}

enum LiftVideoPolicyError: Error {
    case tooLong
}

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
            try await LiftVideoPolicy.validateDuration(of: localURL)
            let userID = try await client.auth.session.user.id
            let assetID = UUID()
            let preparedURL = try await preparedUploadURL(for: localURL)
            defer {
                if preparedURL != localURL { try? FileManager.default.removeItem(at: preparedURL) }
            }
            let isMP4 = preparedURL.pathExtension.lowercased() == "mp4"
            let contentType = isMP4 ? "video/mp4" : "video/quicktime"
            let fileExtension = isMP4 ? "mp4" : "mov"
            let path = "\(userID.uuidString.lowercased())/\(liftID.uuidString.lowercased())/\(assetID.uuidString.lowercased()).\(fileExtension)"
            _ = try await client.storage.from("lift-videos").upload(path, fileURL: preparedURL, options: FileOptions(cacheControl: "3600", contentType: contentType, upsert: false))
            progress(0.9)
            let size = (try? preparedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let dto: MediaDTO = try await client.rpc("complete_lift_media_upload", params: CompleteMediaParameters(assetID: assetID, liftID: liftID, storagePath: path, contentType: contentType, byteCount: size)).single().execute().value
            progress(1)
            return .init(id: dto.id, ownerID: dto.ownerID, storagePath: dto.storagePath, contentType: dto.contentType, byteCount: dto.byteCount, createdAt: dto.createdAt)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func signedPlaybackURL(assetID: UUID) async throws -> URL {
        do { let dto: MediaDTO = try await client.rpc("get_lift_media_for_playback", params: ["asset_id": assetID]).single().execute().value; return try await client.storage.from("lift-videos").createSignedURL(path: dto.storagePath, expiresIn: 300) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    private func preparedUploadURL(for sourceURL: URL) async throws -> URL {
        let fileSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 45 * 1_024 * 1_024 else { return sourceURL }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lift-upload-\(UUID().uuidString.lowercased())")
            .appendingPathExtension("mp4")
        guard let exporter = AVAssetExportSession(
            asset: AVURLAsset(url: sourceURL),
            presetName: AVAssetExportPreset1280x720
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously { continuation.resume() }
        }
        guard exporter.status == .completed else {
            throw exporter.error ?? CocoaError(.fileWriteUnknown)
        }
        return outputURL
    }
}

private struct CompleteMediaParameters: Encodable {
    let assetID: UUID; let liftID: UUID; let storagePath: String; let contentType: String; let byteCount: Int
    enum CodingKeys: String, CodingKey {
        case assetID = "target_asset_id", liftID = "target_lift_id"
        case storagePath = "uploaded_storage_path", contentType = "uploaded_content_type", byteCount = "uploaded_byte_count"
    }
}
