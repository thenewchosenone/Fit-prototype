import AVKit
import Foundation
import SwiftUI
import UIKit

protocol ProfilePhotoStore: AnyObject {
    func thumbnail(for avatarPath: String?) -> UIImage?
    func image(for avatarPath: String?) -> UIImage?
    func fileURLs(for avatarPath: String?) -> ProfilePhotoFileURLs?
    func pendingUploadPath(userID: UUID, mode: AccountMode) -> String?
    func pendingUploadPathWithoutBlockingUI(userID: UUID, mode: AccountMode) async -> String?
    func hasThumbnailWithoutBlockingUI(for avatarPath: String?) async -> Bool
    func markUploadComplete(avatarPath: String?)
    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) async throws -> String
    func cache(fullImageData: Data, thumbnailData: Data?, avatarPath: String) async throws
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
    private lazy var directory = Self.makeDirectoryURL()
    private var missingVariants = Set<String>()

    private init() {
        cache.countLimit = 8
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func thumbnail(for avatarPath: String?) -> UIImage? {
        loadVariant("thumb", avatarPath: avatarPath)
    }

    func cachedThumbnail(for avatarPath: String?) -> UIImage? {
        cachedVariant("thumb", avatarPath: avatarPath)
    }

    @MainActor
    func loadThumbnail(for avatarPath: String?) async -> UIImage? {
        await loadVariant("thumb", avatarPath: avatarPath)
    }

    func image(for avatarPath: String?) -> UIImage? {
        loadVariant("full", avatarPath: avatarPath)
    }

    func cachedImage(for avatarPath: String?) -> UIImage? {
        cachedVariant("full", avatarPath: avatarPath)
    }

    @MainActor
    func loadImage(for avatarPath: String?) async -> UIImage? {
        await loadVariant("full", avatarPath: avatarPath)
    }

    func fileURLs(for avatarPath: String?) -> ProfilePhotoFileURLs? {
        guard let avatarPath,
              let fullImageURL = fileURL(for: avatarPath, variant: "full"),
              let thumbnailURL = fileURL(for: avatarPath, variant: "thumb") else { return nil }
        return ProfilePhotoFileURLs(fullImageURL: fullImageURL, thumbnailURL: thumbnailURL)
    }

    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) async throws -> String {
        let relative = Self.avatarPath(userID: userID, mode: mode)
        let directory = try directoryURL().appendingPathComponent(relative, isDirectory: true)
        let prepared = try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let full = image.resizedSquare(to: 1024)
            let thumb = image.resizedSquare(to: 256)
            guard let fullData = full.jpegData(compressionQuality: 0.88),
                  let thumbData = thumb.jpegData(compressionQuality: 0.86) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try fullData.write(to: directory.appendingPathComponent("avatar-full.jpg"), options: .atomic)
            try thumbData.write(to: directory.appendingPathComponent("avatar-thumb.jpg"), options: .atomic)
            if mode == .authenticated {
                try Data("pending".utf8).write(
                    to: directory.appendingPathComponent("pending-upload"),
                    options: .atomic
                )
            }
            return (full, thumb)
        }.value
        let (full, thumb) = prepared
        cache.setObject(full, forKey: "\(relative)-full" as NSString, cost: full.memoryCost)
        cache.setObject(thumb, forKey: "\(relative)-thumb" as NSString, cost: thumb.memoryCost)
        missingVariants.remove("\(relative)-full")
        missingVariants.remove("\(relative)-thumb")
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

    func pendingUploadPathWithoutBlockingUI(userID: UUID, mode: AccountMode) async -> String? {
        guard mode == .authenticated else { return nil }
        let avatarPath = Self.avatarPath(userID: userID, mode: mode)
        guard let directory = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true) else {
            return nil
        }
        return await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("pending-upload").path),
                  FileManager.default.fileExists(atPath: directory.appendingPathComponent("avatar-full.jpg").path),
                  FileManager.default.fileExists(atPath: directory.appendingPathComponent("avatar-thumb.jpg").path)
            else { return nil }
            return avatarPath
        }.value
    }

    @MainActor
    func hasThumbnailWithoutBlockingUI(for avatarPath: String?) async -> Bool {
        if cachedThumbnail(for: avatarPath) != nil { return true }
        return await loadThumbnail(for: avatarPath) != nil
    }

    func markUploadComplete(avatarPath: String?) {
        guard let avatarPath,
              let directory = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
        else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("pending-upload"))
    }

    func cache(fullImageData: Data, thumbnailData: Data?, avatarPath: String) async throws {
        let directory = try directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
        let images = try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try fullImageData.write(to: directory.appendingPathComponent("avatar-full.jpg"), options: .atomic)
            let thumbnailData = thumbnailData ?? fullImageData
            try thumbnailData.write(to: directory.appendingPathComponent("avatar-thumb.jpg"), options: .atomic)
            return (UIImage(data: fullImageData), UIImage(data: thumbnailData))
        }.value
        if let full = images.0 {
            cache.setObject(full, forKey: "\(avatarPath)-full" as NSString, cost: full.memoryCost)
            missingVariants.remove("\(avatarPath)-full")
        }
        if let thumb = images.1 {
            cache.setObject(thumb, forKey: "\(avatarPath)-thumb" as NSString, cost: thumb.memoryCost)
            missingVariants.remove("\(avatarPath)-thumb")
        }
    }

    func remove(avatarPath: String?) {
        guard let avatarPath else { return }
        guard let url = try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true) else { return }
        try? FileManager.default.removeItem(at: url)
        cache.removeObject(forKey: "\(avatarPath)-full" as NSString)
        cache.removeObject(forKey: "\(avatarPath)-thumb" as NSString)
        missingVariants.insert("\(avatarPath)-full")
        missingVariants.insert("\(avatarPath)-thumb")
    }

    func clearMemoryCache() {
        cache.removeAllObjects()
        missingVariants.removeAll()
    }

    func removeNamespace(_ mode: AccountMode) {
        guard let url = try? directoryURL().appendingPathComponent(mode.rawValue, isDirectory: true) else { return }
        try? FileManager.default.removeItem(at: url)
        clearMemoryCache()
    }

    private func loadVariant(_ variant: String, avatarPath: String?) -> UIImage? {
        guard let avatarPath else { return nil }
        let variantKey = "\(avatarPath)-\(variant)"
        let cacheKey = variantKey as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard !missingVariants.contains(variantKey) else { return nil }
        guard let url = fileURL(for: avatarPath, variant: variant),
              let image = UIImage(contentsOfFile: url.path) else {
            missingVariants.insert(variantKey)
            return nil
        }
        cache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        return image
    }

    private func cachedVariant(_ variant: String, avatarPath: String?) -> UIImage? {
        guard let avatarPath else { return nil }
        return cache.object(forKey: "\(avatarPath)-\(variant)" as NSString)
    }

    @MainActor
    private func loadVariant(_ variant: String, avatarPath: String?) async -> UIImage? {
        guard let avatarPath else { return nil }
        let variantKey = "\(avatarPath)-\(variant)"
        let cacheKey = variantKey as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        guard !missingVariants.contains(variantKey) else { return nil }
        guard let path = fileURL(for: avatarPath, variant: variant)?.path else {
            missingVariants.insert(variantKey)
            return nil
        }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(contentsOfFile: path) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }.value
        guard let image else {
            missingVariants.insert(variantKey)
            return nil
        }
        cache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        return image
    }

    private func fileURL(for avatarPath: String, variant: String) -> URL? {
        let suffix = variant == "thumb" ? "avatar-thumb.jpg" : "avatar-full.jpg"
        return try? directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
            .appendingPathComponent(suffix)
    }

    private func directoryURL() throws -> URL {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        return directory
    }

    private static func makeDirectoryURL() -> URL? {
        guard let root = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let directory = root.appendingPathComponent("LiftRank/ProfilePhotos", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return nil
        }
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

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
            .task(id: url) {
                player?.pause()
                player = nil
                await Task.yield()
                guard !Task.isCancelled else { return }
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
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
