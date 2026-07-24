import PhotosUI
import SwiftUI

struct ForumRichComposerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var communityID: UUID?
    @State private var gymID: UUID?
    @State private var kind: ForumPostKind = .discussion
    @State private var title = ""
    @State private var bodyText = ""
    @State private var tag: String?
    @State private var imageItems: [PhotosPickerItem] = []
    @State private var videoItem: PhotosPickerItem?
    @State private var attachments: [ForumAttachment] = []
    @State private var pollOptions = ["", ""]
    @State private var pollCloseDays: Int?
    @State private var selectedLiftID: UUID?
    @State private var selectedWorkoutID: UUID?
    @State private var linkText = ""
    @State private var mediaError: String?
    @State private var confirmCancel = false

    private var selectedCommunity: ForumCommunity? {
        communityID.flatMap(appState.forumCommunity)
    }

    private var validLink: URL? {
        guard let url = URL(string: linkText.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    private var canPost: Bool {
        let canUseDestination = communityID.map(appState.canContributeToForumCommunity) ??
            gymID.map(appState.isGymJoined) ?? false
        guard canUseDestination, (5...140).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count),
              bodyText.count <= 10_000 else { return false }
        switch kind {
        case .poll: return (2...6).contains(pollOptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.count)
        case .media: return !attachments.isEmpty
        case .liftShare: return selectedLiftID != nil
        case .workoutShare: return selectedWorkoutID != nil
        case .link: return validLink != nil
        case .discussion: return true
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        destinationSection
                        postTypeSection
                        contentSection
                        typeSpecificSection
                        if let mediaError { Text(mediaError).font(.caption).foregroundStyle(Color.liftRed) }
                        Text("Forum posts are explicit. LiftRank never publishes a lift or workout here automatically.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                        Color.clear.frame(height: 30)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if title.isEmpty && bodyText.isEmpty && attachments.isEmpty { dismiss() }
                        else { confirmCancel = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Post", action: submit).disabled(!canPost) }
            }
            .confirmationDialog("Discard this post?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { discardMedia(); dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .onAppear(perform: loadPreset)
            .onChange(of: imageItems) { _, items in Task { await loadImages(items) } }
            .onChange(of: videoItem) { _, item in Task { await loadVideo(item) } }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactSectionHeader(title: "Community", eyebrow: "Destination")
            if let gymID, let gym = appState.gyms.first(where: { $0.id == gymID }) {
                HStack {
                    Image(systemName: "building.2.fill").foregroundStyle(Color.liftBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gym.name).foregroundStyle(Color.liftText)
                        Text("Gym discussion").font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    Spacer(); Image(systemName: "lock.fill").foregroundStyle(Color.liftMuted)
                }
                .padding(.horizontal, 13).frame(minHeight: 48).liftSurface(radius: 11)
            } else {
                Menu {
                    ForEach(appState.joinedForumCommunities) { community in Button(community.name) { communityID = community.id; tag = nil } }
                } label: {
                    HStack {
                        Image(systemName: selectedCommunity?.symbolName ?? "person.3.fill").foregroundStyle(Color.liftBlue)
                        Text(selectedCommunity?.name ?? "Choose a joined community").foregroundStyle(Color.liftText)
                        Spacer(); Image(systemName: "chevron.up.chevron.down").foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 13).frame(minHeight: 48).liftSurface(radius: 11)
                }
            }
            if appState.joinedForumCommunities.isEmpty && gymID == nil {
                Text("Join a public community in Explore before posting.").font(.caption).foregroundStyle(Color.liftGold)
            }
        }
    }

    private var postTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactSectionHeader(title: "Post type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ForumPostKind.allCases) { option in
                        Button { kind = option; clearIncompatibleMedia(for: option) } label: {
                            Label(option.rawValue, systemImage: option.symbolName)
                                .font(.caption.weight(.bold)).foregroundStyle(kind == option ? .white : Color.liftMuted)
                                .padding(.horizontal, 12).frame(minHeight: 38)
                                .background(kind == option ? Color.liftBlue : Color.liftCard)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title (5–140 characters)", text: $title)
                .font(.headline).padding(.horizontal, 13).frame(minHeight: 48).background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            Text("\(title.count)/140").font(.caption2).foregroundStyle(title.count > 140 ? Color.liftRed : Color.liftMuted).frame(maxWidth: .infinity, alignment: .trailing)
            TextEditor(text: $bodyText)
                .frame(minHeight: 150).padding(8).scrollContentBackground(.hidden).background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty { Text("Add details, context, or a question…").foregroundStyle(Color.liftMuted).padding(.horizontal, 13).padding(.vertical, 17).allowsHitTesting(false) }
                }
            HStack {
                Text("\(bodyText.count)/10,000").font(.caption2).foregroundStyle(bodyText.count > 10_000 ? Color.liftRed : Color.liftMuted)
                Spacer()
                if let selectedCommunity, !selectedCommunity.availableTags.isEmpty {
                    Menu(tag ?? "Add tag") {
                        Button("No tag") { tag = nil }
                        ForEach(selectedCommunity.availableTags, id: \.self) { option in Button(option) { tag = option } }
                    }
                    .font(.caption.weight(.bold))
                }
            }
        }
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch kind {
        case .discussion: EmptyView()
        case .media: mediaPicker
        case .poll: pollEditor
        case .liftShare: liftPicker
        case .workoutShare: workoutPicker
        case .link: linkEditor
        }
    }

    private var mediaPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Media", eyebrow: "Up to four images or one video")
            HStack(spacing: 10) {
                PhotosPicker(selection: $imageItems, maxSelectionCount: 4, matching: .images) {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    Label("Add Video", systemImage: "video.fill")
                }
                .buttonStyle(.bordered)
            }
            ForEach(attachments) { attachment in
                HStack {
                    Image(systemName: attachment.mediaType == .image ? "photo.fill" : "video.fill").foregroundStyle(Color.liftBlue)
                    Text(attachment.localURL.lastPathComponent).font(.caption).lineLimit(1)
                    Spacer(); Button(role: .destructive) { removeAttachment(attachment) } label: { Image(systemName: "trash") }
                }
                .padding(10).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var pollEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            CompactSectionHeader(title: "Poll options", eyebrow: "2–6 choices")
            ForEach(pollOptions.indices, id: \.self) { index in
                HStack {
                    TextField("Option \(index + 1)", text: $pollOptions[index])
                    if pollOptions.count > 2 { Button(role: .destructive) { pollOptions.remove(at: index) } label: { Image(systemName: "minus.circle.fill") } }
                }
                .padding(.horizontal, 12).frame(minHeight: 44).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if pollOptions.count < 6 { Button("Add option") { pollOptions.append("") }.font(.caption.weight(.bold)) }
            Menu(pollCloseDays.map { "Closes in \($0) day\($0 == 1 ? "" : "s")" } ?? "No closing date") {
                Button("No closing date") { pollCloseDays = nil }
                ForEach([1, 3, 7], id: \.self) { days in Button("\(days) day\(days == 1 ? "" : "s")") { pollCloseDays = days } }
            }
            .buttonStyle(.bordered)
        }
    }

    private var liftPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactSectionHeader(title: "Select a lift", eyebrow: "Existing submissions")
            Picker("Lift", selection: $selectedLiftID) {
                Text("Choose a lift").tag(UUID?.none)
                ForEach(appState.currentUserLifts) { lift in
                    Text("\(lift.exerciseName) — \(MeasurementFormatting.liftSetText(weightKilograms: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))").tag(UUID?.some(lift.id))
                }
            }
            .pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).liftSurface(radius: 11)
        }
    }

    private var workoutPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactSectionHeader(title: "Select a workout", eyebrow: "Completed workouts")
            Picker("Workout", selection: $selectedWorkoutID) {
                Text("Choose a workout").tag(UUID?.none)
                ForEach(appState.completedWorkouts) { workout in
                    Text("\(workout.name) — \(LiftTimeFormatter.shortDate(workout.completedAt))").tag(UUID?.some(workout.id))
                }
            }
            .pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).liftSurface(radius: 11)
        }
    }

    private var linkEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactSectionHeader(title: "Link", eyebrow: "HTTP or HTTPS")
            TextField("https://example.com", text: $linkText).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(minHeight: 46).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
            if !linkText.isEmpty && validLink == nil { Text("Enter a valid HTTP or HTTPS address.").font(.caption).foregroundStyle(Color.liftRed) }
        }
    }

    private func loadPreset() {
        gymID = appState.forumComposerGymID
        communityID = gymID == nil ? (appState.forumComposerCommunityID ?? appState.joinedForumCommunities.first?.id) : nil
        if let liftID = appState.forumComposerLiftID {
            kind = .liftShare; selectedLiftID = liftID
            if let lift = appState.lifts.first(where: { $0.id == liftID }) { title = "\(lift.exerciseName) PR — \(MeasurementFormatting.formatDisplayedWeight(lift.weight, unit: lift.unit))" }
        } else if let workoutID = appState.forumComposerWorkoutID {
            kind = .workoutShare; selectedWorkoutID = workoutID
            if let workout = appState.completedWorkouts.first(where: { $0.id == workoutID }) { title = "Completed \(workout.name)" }
        }
    }

    private func submit() {
        let didCreate: Bool
        if let gymID {
            didCreate = appState.createForumGymPost(
                gymID: gymID, kind: kind, title: title, body: bodyText,
                attachments: attachments, pollOptions: pollOptions, pollCloseDays: pollCloseDays,
                liftID: selectedLiftID, workoutID: selectedWorkoutID, linkURL: validLink
            )
        } else if let communityID {
            didCreate = appState.createForumPost(
                communityID: communityID, kind: kind, title: title, body: bodyText, tag: tag,
                attachments: attachments, pollOptions: pollOptions, pollCloseDays: pollCloseDays,
                liftID: selectedLiftID, workoutID: selectedWorkoutID, linkURL: validLink
            )
        } else {
            didCreate = false
        }
        if didCreate { dismiss() }
    }

    private func clearIncompatibleMedia(for kind: ForumPostKind) {
        guard kind != .media else { return }
        discardMedia(); imageItems = []; videoItem = nil
    }

    private func loadImages(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run {
            appState.removeForumMedia(attachments.filter { $0.mediaType == .image })
            attachments.removeAll { $0.mediaType == .image }
            videoItem = nil
        }
        do {
            var loaded: [ForumAttachment] = []
            for item in items.prefix(4) {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                loaded.append(try await MainActor.run { try appState.persistForumMedia(data, fileExtension: ext, mediaType: .image) })
            }
            await MainActor.run { attachments = loaded; mediaError = nil }
        } catch { await MainActor.run { mediaError = "One or more images could not be stored." } }
    }

    private func loadVideo(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
            let attachment = try await MainActor.run { try appState.persistForumMedia(data, fileExtension: ext, mediaType: .video) }
            await MainActor.run {
                discardMedia(); attachments = [attachment]; imageItems = []; mediaError = nil
            }
        } catch { await MainActor.run { mediaError = "The selected video could not be stored." } }
    }

    private func removeAttachment(_ attachment: ForumAttachment) {
        appState.removeForumMedia(at: attachment.localURL)
        attachments.removeAll { $0.id == attachment.id }
    }

    private func discardMedia() {
        appState.removeForumMedia(attachments)
        attachments = []
    }
}
