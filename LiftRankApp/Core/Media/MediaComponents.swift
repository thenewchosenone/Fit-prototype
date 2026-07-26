import ImageIO
import Foundation
import SwiftUI
import UIKit

protocol ProfilePhotoStore: AnyObject {
    func thumbnail(for avatarPath: String?) -> UIImage?
    func image(for avatarPath: String?) -> UIImage?
    func fileURLs(for avatarPath: String?) -> ProfilePhotoFileURLs?
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

    private init() {}

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
        cache.setObject(full, forKey: "\(relative)-full" as NSString)
        cache.setObject(thumb, forKey: "\(relative)-thumb" as NSString)
        return relative
    }

    func cache(fullImageData: Data, thumbnailData: Data?, avatarPath: String) throws {
        let directory = try directoryURL().appendingPathComponent(avatarPath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try fullImageData.write(to: directory.appendingPathComponent("avatar-full.jpg"), options: .atomic)
        try (thumbnailData ?? fullImageData).write(to: directory.appendingPathComponent("avatar-thumb.jpg"), options: .atomic)
        if let full = UIImage(data: fullImageData) {
            cache.setObject(full, forKey: "\(avatarPath)-full" as NSString)
        }
        if let thumb = UIImage(data: thumbnailData ?? fullImageData) {
            cache.setObject(thumb, forKey: "\(avatarPath)-thumb" as NSString)
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
        cache.setObject(image, forKey: cacheKey)
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

final class BundledDemoMediaLibrary {
    static let shared = BundledDemoMediaLibrary()

    private init() {}

    func url(for mediaID: String?) -> URL? {
        guard let mediaID else { return nil }
        return Bundle.main.url(forResource: mediaID, withExtension: "gif", subdirectory: "DemoMedia")
            ?? Bundle.main.url(forResource: mediaID, withExtension: "gif")
    }
}

struct LoopingGIFView: UIViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            context.coordinator.animation = GIFAnimationDecoder.decode(url: url)
        }

        guard let animation = context.coordinator.animation else {
            uiView.image = nil
            uiView.animationImages = nil
            uiView.stopAnimating()
            return
        }

        if reduceMotion {
            uiView.stopAnimating()
            uiView.animationImages = nil
            uiView.image = animation.frames.first
            return
        }

        if uiView.animationImages == nil {
            uiView.image = animation.frames.first
            uiView.animationImages = animation.frames
            uiView.animationDuration = animation.duration
            uiView.animationRepeatCount = 0
        }

        if isPlaying {
            if !uiView.isAnimating {
                uiView.startAnimating()
            }
        } else {
            uiView.stopAnimating()
        }
    }

    final class Coordinator {
        var loadedURL: URL?
        fileprivate var animation: GIFAnimation?
    }
}

private struct GIFAnimation {
    let frames: [UIImage]
    let duration: TimeInterval
}

private enum GIFAnimationDecoder {
    static func decode(url: URL) -> GIFAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        var frames: [UIImage] = []
        frames.reserveCapacity(frameCount)
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDuration(source: source, index: index)
        }

        guard !frames.isEmpty else { return nil }
        return GIFAnimation(frames: frames, duration: max(duration, 0.1))
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay > 0.01 ? delay : 0.1
    }
}

struct DemoMediaCard: View {
    let title: String
    let subtitle: String
    let mediaID: String
    var badge: String = "Demo Media"

    @State private var isPlaying = true
    @State private var showingFullscreen = false

    var body: some View {
        if let url = BundledDemoMediaLibrary.shared.url(for: mediaID) {
            LiftCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.headline.weight(.bold))
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Text(badge.uppercased())
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(Color.liftBlue)
                    }

                    Button {
                        showingFullscreen = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            LoopingGIFView(url: url, isPlaying: $isPlaying)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.48))
                                .clipShape(Circle())
                                .padding(10)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) demo media")

                    HStack {
                        Button(isPlaying ? "Pause" : "Play") {
                            isPlaying.toggle()
                        }
                        .buttonStyle(LiftSecondaryButtonStyle())
                        Spacer()
                        Text("Silent looping preview")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingFullscreen) {
                DemoMediaFullScreenView(title: title, subtitle: subtitle, url: url, isPlaying: $isPlaying)
            }
        }
    }
}

private struct DemoMediaFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    let url: URL
    @Binding var isPlaying: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(.top, 24)

                LoopingGIFView(url: url, isPlaying: $isPlaying)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding()

                Text("Demo Media")
                    .font(.caption.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(Color.liftBlue)
                    .padding(.bottom, 28)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("Close demo media")
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
