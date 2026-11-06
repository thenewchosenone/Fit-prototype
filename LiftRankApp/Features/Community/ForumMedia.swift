import AVKit
import CoreTransferable
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ForumPickedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copy(received.file)
        }
        FileRepresentation(importedContentType: .image) { received in
            try copy(received.file)
        }
    }

    private static func copy(_ source: URL) throws -> ForumPickedFile {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension)
        try FileManager.default.copyItem(at: source, to: destination)
        return ForumPickedFile(url: destination)
    }
}

enum ForumMediaPreparation {
    static func prepare(_ source: URL, kind: ForumAttachment.Kind) async throws -> ForumMediaDraft {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension(kind == .photo ? "jpg" : "mp4")
        do {
            if kind == .photo {
                try await Task.detached(priority: .userInitiated) {
                    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2048
                          ] as CFDictionary),
                          let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.88) else {
                        throw LiftRankServiceError.invalidInput("This photo could not be opened. Choose another photo.")
                    }
                    try data.write(to: destination, options: .atomic)
                }.value
            } else {
                let asset = AVURLAsset(url: source)
                let duration = try await asset.load(.duration).seconds
                guard duration.isFinite, duration > 0, duration <= 120,
                      !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
                    throw LiftRankServiceError.invalidInput("Choose a video up to 2 minutes long.")
                }
                guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
                    throw LiftRankServiceError.invalidInput("This video could not be prepared. Choose another video.")
                }
                exporter.outputURL = destination
                exporter.outputFileType = .mp4
                exporter.metadata = []
                exporter.shouldOptimizeForNetworkUse = true
                await withCheckedContinuation { continuation in
                    exporter.exportAsynchronously { continuation.resume() }
                }
                guard exporter.status == .completed else {
                    throw exporter.error ?? CocoaError(.fileWriteUnknown)
                }
            }
            let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= (kind == .photo ? 10 : 50) * 1_024 * 1_024 else {
                throw LiftRankServiceError.invalidInput("Choose a photo under 10 MB or a video under 50 MB.")
            }
            return ForumMediaDraft(kind: kind, fileURL: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}

struct ForumMediaView: View {
    @EnvironmentObject private var appState: AppState
    let attachment: ForumAttachment
    var localURL: URL? = nil
    var interactive = true
    var compact = false
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: String?
    @State private var retryID = UUID()
    @State private var showsViewer = false

    var body: some View {
        Group {
            if interactive {
                Button { showsViewer = true } label: { preview }
                    .buttonStyle(.plain)
                    .disabled(isLoading || error != nil)
                    .accessibilityLabel(attachment.kind == .photo ? "Open photo" : "Play video")
            } else {
                preview
                    .accessibilityLabel(attachment.kind == .photo ? "Photo attached" : "Video attached")
            }
        }
        .accessibilityIdentifier("forum.media.\(attachment.kind.rawValue)")
        .overlay(alignment: .bottom) {
            if error != nil, interactive {
                Button("Retry media") { retryID = UUID() }
                    .buttonStyle(.bordered)
                    .padding()
            }
        }
        .task(id: "\(attachment.id)|\(retryID)") { await load() }
        .fullScreenCover(isPresented: $showsViewer) {
            ForumMediaViewer(attachment: attachment, localURL: localURL, photo: image)
                .environmentObject(appState)
        }
    }

    private var preview: some View {
        ZStack {
            Color.liftSurfaceElevated
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView("Loading media…")
            } else if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding()
            } else {
                Text("Video preview unavailable")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding()
            }
            if attachment.kind == .video, !isLoading, error == nil {
                Image(systemName: interactive ? "play.circle.fill" : "video.fill")
                    .font(.system(size: interactive ? 48 : 28))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(compact ? 1.6 : image.map { max(0.8, min(1.8, $0.size.width / $0.size.height)) } ?? 1.6, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        image = nil
        defer { isLoading = false }
        do {
            let url: URL
            if let localURL { url = localURL }
            else { url = try await appState.forumStore.mediaURL(for: attachment) }
            if attachment.kind == .photo {
                let data: Data
                if url.isFileURL {
                    data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
                } else {
                    let (download, response) = try await URLSession.shared.data(from: url)
                    guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    data = download
                }
                guard let loaded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                guard !Task.isCancelled else { return }
                image = loaded
            } else {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 720, height: 720)
                do {
                    let frame = try await generator.image(at: .zero)
                    guard !Task.isCancelled else { return }
                    image = UIImage(cgImage: frame.image)
                } catch {
                    // A thumbnail failure does not prevent opening the video player.
                    image = nil
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Media unavailable"
        }
    }
}

private struct ForumMediaViewer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let attachment: ForumAttachment
    let localURL: URL?
    let photo: UIImage?
    @State private var videoURL: URL?
    @State private var error: String?
    @State private var retryID = UUID()
    @State private var scale = 1.0
    @State private var baseScale = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let photo, attachment.kind == .photo {
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: photo).resizable().scaledToFit()
                                .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                                .accessibilityLabel("Discussion photo")
                        }
                        .simultaneousGesture(MagnificationGesture()
                            .onChanged { scale = min(max(baseScale * Double($0), 1), 4) }
                            .onEnded { _ in baseScale = scale })
                        .onTapGesture(count: 2) { scale = scale == 1 ? 2 : 1; baseScale = scale }
                    }
                } else if let videoURL {
                    ManagedVideoPlayer(url: videoURL, playsOnOpen: true, retryPlayback: { retryID = UUID() })
                        .accessibilityIdentifier("forum.media.player")
                } else if let error {
                    VStack(spacing: 16) {
                        Text(error)
                        Button("Retry") { retryID = UUID() }
                    }.foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle(attachment.kind == .photo ? "Photo" : "Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) }

            }
            .task(id: retryID) {
                guard attachment.kind == .video else { return }
                videoURL = nil
                error = nil
                do {
                    if let localURL { videoURL = localURL }
                    else { videoURL = try await appState.forumStore.mediaURL(for: attachment) }
                } catch { self.error = "This video is no longer available. Try again." }
            }
        }
    }
}
