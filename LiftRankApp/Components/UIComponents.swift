import ImageIO
import Foundation
import SwiftUI
import UIKit

protocol ProfilePhotoStore: AnyObject {
    func thumbnail(for avatarPath: String?) -> UIImage?
    func image(for avatarPath: String?) -> UIImage?
    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) throws -> String
    func remove(avatarPath: String?)
    func clearMemoryCache()
    func removeNamespace(_ mode: AccountMode)
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

    @discardableResult
    func save(image: UIImage, userID: UUID, mode: AccountMode) throws -> String {
        let relative = "\(mode.rawValue)/\(userID.uuidString.lowercased())/avatar"
        let directory = try directoryURL().appendingPathComponent(mode.rawValue, isDirectory: true)
            .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
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

    func remove(avatarPath: String?) {
        guard let avatarPath else { return }
        let parent = avatarPath.split(separator: "/").dropLast().joined(separator: "/")
        guard let url = try? directoryURL().appendingPathComponent(parent, isDirectory: true) else { return }
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
        return try? directoryURL().appendingPathComponent(avatarPath, isDirectory: false)
            .deletingLastPathComponent()
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

extension Color {
    static let liftBackground = Color(red: 0.035, green: 0.043, blue: 0.075)
    static let liftCard = Color(red: 0.085, green: 0.098, blue: 0.15)
    static let liftCardRaised = Color(red: 0.125, green: 0.14, blue: 0.205)
    static let liftMuted = Color(red: 0.60, green: 0.62, blue: 0.70)
    static let liftBlue = Color(red: 0.20, green: 0.38, blue: 1.0)
    static let liftPurple = Color(red: 0.35, green: 0.31, blue: 0.92)
    static let liftGreen = Color(red: 0.08, green: 0.72, blue: 0.55)
    static let liftGold = Color(red: 1.0, green: 0.76, blue: 0.22)
    static let liftSilver = Color(red: 0.72, green: 0.74, blue: 0.78)
    static let liftBronze = Color(red: 0.74, green: 0.46, blue: 0.24)
    static let liftRed = Color(red: 0.92, green: 0.27, blue: 0.38)
    static let liftSeparator = Color.white.opacity(0.075)
    static let liftField = Color(red: 0.065, green: 0.075, blue: 0.12)
}

enum LiftDesign {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 11
    static let compactSpacing: CGFloat = 12
    static let screenHorizontalPadding: CGFloat = 16
    static let minimumTouchTarget: CGFloat = 44
}

private struct LiftSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let raised: Bool

    func body(content: Content) -> some View {
        content
            .background(raised ? Color.liftCardRaised : Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.liftSeparator, lineWidth: 1)
            }
    }
}

extension View {
    func liftSurface(radius: CGFloat = LiftDesign.cardRadius, raised: Bool = false) -> some View {
        modifier(LiftSurfaceModifier(radius: radius, raised: raised))
    }
}

struct AppBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.liftBackground
                .ignoresSafeArea()
            content
        }
        .foregroundStyle(.white)
        .tint(Color.liftBlue)
    }
}

struct LiftCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liftSurface()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var symbolName = "chart.bar.fill"
    var tint = Color.liftBlue

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbolName)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                }
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)
            }
        }
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject private var appState: AppState
    let profile: UserProfile
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let image = LocalProfilePhotoStore.shared.thumbnail(for: profile.avatarPath) ??
                LocalProfilePhotoStore.shared.image(for: profile.avatarPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.liftBlue.opacity(0.16))
                Image(systemName: profile.profileImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.liftBlue)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(profile.displayName) profile photo")
    }
}

struct VerificationBadge: View {
    let status: VerificationStatus

    var color: Color {
        switch status {
        case .selfReported: return Color.liftMuted
        case .videoSubmitted: return Color.liftBlue
        case .videoVerified: return Color.liftGreen
        case .communityVerified: return Color.cyan
        case .competitionVerified: return Color.liftGold
        case .rejected: return Color.liftRed
        }
    }

    var body: some View {
        Label(status.rawValue, systemImage: status == .rejected ? "xmark.seal.fill" : "checkmark.seal.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel("Verification status: \(status.rawValue)")
    }
}

struct FilterChip: View {
    let title: String
    var isActive = true
    var action: (() -> Void)?

    var body: some View {
        Button {
            Haptics.light()
            action?()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if action != nil {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive ? Color.liftBlue.opacity(0.18) : Color.liftCard)
            .foregroundStyle(isActive ? Color.liftBlue : Color.liftMuted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum LiftTimeFormatter {
    static func relativeNoSeconds(from date: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }

        let days = hours / 24
        if days < 7 { return "\(days)d ago" }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func messageTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct CompactSectionHeader: View {
    let title: String
    var eyebrow: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.liftBlue)
                }
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct LiftPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.horizontal, 16)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.55))
            .background(Color.liftBlue.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct LiftSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: LiftDesign.minimumTouchTarget)
            .padding(.horizontal, 14)
            .foregroundStyle(Color.liftBlue.opacity(isEnabled ? 1 : 0.45))
            .background(Color.liftCardRaised.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous)
                    .stroke(Color.liftSeparator, lineWidth: 1)
            }
    }
}

struct PrimaryButton: View {
    let title: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
        }
        .buttonStyle(LiftPrimaryButtonStyle())
    }
}

struct NativeIconButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var badge: Int? = nil
    var tint = Color.white
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: LiftDesign.minimumTouchTarget, height: LiftDesign.minimumTouchTarget)
                    .background(Color.liftCard)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(Color.liftSeparator, lineWidth: 1) }

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.liftRed)
                        .clipShape(Circle())
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct LiftActionRow: View {
    let title: String
    var subtitle: String?
    var symbolName: String
    var tint = Color.liftBlue
    var trailingText: String?
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LiftEmptyState: View {
    let title: String
    let message: String
    var symbolName = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.liftBlue)
                .frame(width: 48, height: 48)
                .background(Color.liftBlue.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liftSurface()
        .accessibilityElement(children: .combine)
    }
}

struct LiftSheetHeader: View {
    let title: String
    var subtitle: String?
    var close: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            Spacer()
            if let close {
                NativeIconButton(symbolName: "xmark", accessibilityLabel: "Close", action: close)
            }
        }
    }
}

enum NumericInputPresentation {
    case card
    case inset
    case formRow

    var background: Color {
        switch self {
        case .card:
            return Color.liftCard
        case .inset, .formRow:
            return Color.liftField
        }
    }

    var padding: CGFloat {
        switch self {
        case .card:
            return 16
        case .inset:
            return 12
        case .formRow:
            return 0
        }
    }
}

struct NumericInputField: View {
    let title: String
    @Binding var value: Double
    var unit: String?
    var precision: ClosedRange<Int> = 0...1
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct IntegerInputField: View {
    let title: String
    @Binding var value: Int
    var unit: String?
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct OptionalNumericInputField: View {
    let title: String
    @Binding var value: Double?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Double?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(Self.format) ?? "")
    }

    var body: some View {
        optionalField(keyboard: .decimalPad)
            .onChange(of: text) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value = trimmed.isEmpty ? nil : Double(trimmed)
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    text = newValue.map(Self.format) ?? ""
                }
            }
    }

    private func optionalField(keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboard)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct OptionalIntegerInputField: View {
    let title: String
    @Binding var value: Int?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: text) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value = trimmed.isEmpty ? nil : Int(trimmed)
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                text = newValue.map(String.init) ?? ""
            }
        }
    }
}
