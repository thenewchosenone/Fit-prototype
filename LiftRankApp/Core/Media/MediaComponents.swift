import AVKit
import Foundation
import SwiftUI
import UIKit

protocol ProfilePhotoStore: AnyObject {
    func thumbnail(for avatarPath: String?) -> UIImage?
    func image(for avatarPath: String?) -> UIImage?
    func fileURLs(for avatarPath: String?) -> ProfilePhotoFileURLs?
    func pendingUploadPath(userID: UUID, mode: AccountMode) -> String?
    func markUploadComplete(avatarPath: String?)
    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) throws -> String
    func cache(fullImageData: Data, thumbnailData: Data?, avatarPath: String) throws
    func remove(avatarPath: String?)
    func clearMemoryCache()
    func removeNamespace(_ mode: AccountMode)
}

struct ProfilePhotoFileURLs {
    var fullImageURL: URL
    var thumbnailURL: URL
}

final class LocalProfilePhotoStore: ProfilePhotoStore {
    static let shared = LocalProfilePhotoStore()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 8
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func thumbnail(for avatarPath: String?) -> UIImage? {
        loadVariant("thumb", avatarPath: avatarPath)
    }

    func image(for avatarPath: String?) -> UIImage? {
        loadVariant("full", avatarPath: avatarPath)
    }

    func fileURLs(for avatarPath: String?) -> ProfilePhotoFileURLs? {
        guard let avatarPath,
              let fullImageURL = fileURL(for: avatarPath, variant: "full"),
              let thumbnailURL = fileURL(for: avatarPath, variant: "thumb") else { return nil }
        return ProfilePhotoFileURLs(fullImageURL: fullImageURL, thumbnailURL: thumbnailURL)
    }

    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) throws -> String {
        let relative = Self.avatarPath(userID: userID, mode: mode)
        let directory = try directoryURL().appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let full = image.resizedSquare(to: 1024)
        let thumb = image.resizedSquare(to: 256)
        let fullURL = directory.appendingPathComponent("avatar-full.jpg")
        let thumbURL = directory.appendingPathComponent("avatar-thumb.jpg")
        guard let fullData = full.jpegData(compressionQuality: 0.88),
              let thumbData = thumb.jpegData(compressionQuality: 0.86) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try fullData.write(to: fullURL, options: .atomic)
        try thumbData.write(to: thumbURL, options: .atomic)
        if mode == .authenticated {
            try Data("pending".utf8).write(
                to: directory.appendingPathComponent("pending-upload"),
                options: .atomic
            )
        }
        cache.setObject(full, forKey: "\(relative)-full" as NSString, cost: full.memoryCost)
        cache.setObject(thumb, forKey: "\(relative)-thumb" as NSString, cost: thumb.memoryCost)
        return relative
    }

    func pendingUploadPath(userID: UUID, mode: AccountMode) -> String? {
        guard mode == .authenticated else { return nil }
        let avatarPath = Self.avatarPath(userID: userID, mode: mode)
        guard let directory = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true),
              FileManager.default.fileExists(atPath: directory.appendingPathComponent("pending-upload").path),
              FileManager.default.fileExists(atPath: directory.appendingPathComponent("avatar-full.jpg").path),
              FileManager.default.fileExists(atPath: directory.appendingPathComponent("avatar-thumb.jpg").path)
        else { return nil }
        return avatarPath
    }

    func markUploadComplete(avatarPath: String?) {
        guard let avatarPath,
              let directory = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
        else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("pending-upload"))
    }

    func cache(fullImageData: Data, thumbnailData: Data?, avatarPath: String) throws {
        let directory = try directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try fullImageData.write(to: directory.appendingPathComponent("avatar-full.jpg"), options: .atomic)
        try (thumbnailData ?? fullImageData).write(to: directory.appendingPathComponent("avatar-thumb.jpg"), options: .atomic)
        if let full = UIImage(data: fullImageData) {
            cache.setObject(full, forKey: "\(avatarPath)-full" as NSString, cost: full.memoryCost)
        }
        if let thumb = UIImage(data: thumbnailData ?? fullImageData) {
            cache.setObject(thumb, forKey: "\(avatarPath)-thumb" as NSString, cost: thumb.memoryCost)
        }
    }

    func remove(avatarPath: String?) {
        guard let avatarPath else { return }
        guard let url = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true) else { return }
        try? FileManager.default.removeItem(at: url)
        cache.removeObject(forKey: "\(avatarPath)-full" as NSString)
        cache.removeObject(forKey: "\(avatarPath)-thumb" as NSString)
    }

    func clearMemoryCache() {
        cache.removeAllObjects()
    }

    func removeNamespace(_ mode: AccountMode) {
        guard let url = try? directoryURL().appendingPathComponent(mode.rawValue, isDirectory: true) else { return }
        try? FileManager.default.removeItem(at: url)
        clearMemoryCache()
    }

    private func loadVariant(_ variant: String, avatarPath: String?) -> UIImage? {
        guard let avatarPath else { return nil }
        let cacheKey = "\(avatarPath)-\(variant)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard let url = fileURL(for: avatarPath, variant: variant),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        return image
    }

    private func fileURL(for avatarPath: String, variant: String) -> URL? {
        let suffix = variant == "thumb" ? "avatar-thumb.jpg" : "avatar-full.jpg"
        return try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
            .appendingPathComponent(suffix)
    }

    private func directoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("LiftRank/ProfilePhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func avatarPath(userID: UUID, mode: AccountMode) -> String {
        let accountPath = "\(userID.uuidString.lowercased())/avatar"
        switch mode {
        case .authenticated:
            return accountPath
        case .demo:
            return "demo/\(accountPath)"
        }
    }
}

private extension UIImage {
    var memoryCost: Int { Int(size.width * scale * size.height * scale * 4) }
}

struct ManagedVideoPlayer: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var loadedURL: URL?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                loadPlayerIfNeeded()
            }
            .onChange(of: url) { _, _ in
                loadPlayerIfNeeded()
            }
            .onDisappear {
                player?.pause()
                player = nil
                loadedURL = nil
            }
    }

    private func loadPlayerIfNeeded() {
        guard loadedURL != url else { return }
        player?.pause()
        player = AVPlayer(url: url)
        loadedURL = url
    }
}

private extension UIImage {
    func resizedSquare(to dimension: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: dimension, height: dimension))
        let side = min(size.width, size.height)
        let cropOrigin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: side, height: side))

        return renderer.image { _ in
            let scale = dimension / side
            let drawRect = CGRect(
                x: -cropRect.minX * scale,
                y: -cropRect.minY * scale,
                width: size.width * scale,
                height: size.height * scale
            )
            self.draw(in: drawRect)
        }
    }
}
