import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum ForumSort: String, CaseIterable, Identifiable {
    case top, new, discussed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .top: return "Top posts"
        case .new: return "New posts"
        case .discussed: return "Most discussed"
        }
    }
}

private enum ForumFeed: String, CaseIterable, Identifiable {
    case all = "All"
    case friends = "Friends"
    case forYou = "Recommended"
    case following = "My communities"

    var id: String { rawValue }
}

private enum ForumCommentSort: String, CaseIterable, Identifiable {
    case best, new

    var id: String { rawValue }
    var title: String {
        switch self {
        case .best: return "Best"
        case .new: return "New"
        }
    }
    var icon: String {
        switch self {
        case .best: return "arrow.up"
        case .new: return "sparkles"
        }
    }
}

struct ForumView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var groups: [ForumCommunity] = []
    @State private var posts: [ForumPost] = []
    @State private var selectedGroupID: UUID?
    @State private var joinedGroupIDs: Set<UUID> = []
    @State private var membershipStatuses: [UUID: String] = [:]
    @State private var showingComposer = false
    @State private var sort: ForumSort = .top
    @State private var feed: ForumFeed = .all
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePosts = false
    @State private var remotePostOffset = 0
    @State private var message: String?
    @State private var requestedPost: ForumPost?
    @State private var publishedPost: ForumPost?
    @State private var requestedCommentID: UUID?
    @State private var showingCommunityDirectory = false

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                forumFeedPicker
                if feed == .friends {
                    FriendTrainingActivityView()
                } else {
                    discussionFeed
                }
            }
        }
        .navigationTitle(feed == .friends ? "Feed" : selectedGroup?.name ?? "Feed")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingComposer, onDismiss: {
            if let publishedPost { requestedCommentID = nil; requestedPost = publishedPost; self.publishedPost = nil }
        }) {
            ForumComposerView(groups: groups, selectedGroupID: selectedGroupID, membershipStatuses: membershipStatuses) { post in
                publishedPost = post
                await loadPosts()
            }.environmentObject(appState)
        }
        .sheet(isPresented: $showingCommunityDirectory) {
                ForumCommunityDirectoryView(
                    groups: groups,
                    joinedGroupIDs: $joinedGroupIDs,
                    membershipStatuses: $membershipStatuses,
                    selectedGroupID: $selectedGroupID,
                onMembershipChanged: { group in await toggleMembership(group) },
                onCommunitySelected: {
                    showingCommunityDirectory = false
                    feed = .all
                    Task { await loadPosts() }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New discussion")
            }
        }
        .sheet(item: $requestedPost, onDismiss: { Task { await loadPosts() } }) { post in
            NavigationStack {
                ForumThreadView(post: post, highlightedCommentID: requestedCommentID, isPresentedAsSheet: true)
                    .environmentObject(appState)
            }
        }
        .onChange(of: appState.router.forumPostToOpen) { _, postID in
            guard postID != nil else { return }
            Task { await openRequestedPostIfNeeded() }
        }
        .task { await load() }
    }

    private var forumHeader: some View {
        HStack(spacing: 12) {
            if let selectedGroup {
                Text(selectedGroup.summary).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(2)
                Spacer()
                Button(joinedGroupIDs.contains(selectedGroup.id) ? "Leave" : (membershipStatuses[selectedGroup.id] ?? "Join")) {
                    Task { await toggleMembership(selectedGroup) }
                }
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .disabled(["Pending", "Banned"].contains(membershipStatuses[selectedGroup.id] ?? ""))
            }
        }
        .padding(.horizontal, 16)
    }

    private var discussionFeed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                forumHeader
                forumFeedControls
                if let message {
                    HStack {
                        Text(message).font(.caption).foregroundStyle(Color.liftRed)
                        Button("Retry") { Task { await load() } }
                    }.padding(16)
                }
                if isLoading { ProgressView().frame(maxWidth: .infinity).padding(40) }
                else if sortedPosts.isEmpty {
                    LiftEmptyState(
                        title: searchText.isEmpty ? emptyFeedTitle : "No matching discussions",
                        message: searchText.isEmpty ? emptyFeedMessage : "Try another search or load more discussions.",
                        actionTitle: !searchText.isEmpty ? "Clear search" : feed == .following ? "Browse communities" : "New discussion",
                        action: {
                            if !searchText.isEmpty { searchText = "" }
                            else if feed == .following { showingCommunityDirectory = true }
                            else { showingComposer = true }
                        }
                    )
                }
                else {
                    ForEach(sortedPosts) { post in
                        ForumPostCard(post: post, community: groups.first { $0.id == post.communityID }, onCommunitySelected: {
                            selectedGroupID = post.communityID
                            feed = .all
                            Task { await loadPosts() }
                        }, onPostDeleted: {
                            posts.removeAll { $0.id == post.id }
                        }).environmentObject(appState)
                    }
                }
                if hasMorePosts {
                    Button {
                        Task { await loadMorePosts() }
                    } label: {
                        if isLoadingMore {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Load more discussions")
                                .font(LiftTypography.rowEmphasis)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .disabled(isLoadingMore)
                }
            }
        }
        .searchable(text: $searchText, prompt: hasMorePosts ? "Search loaded discussions" : "Search discussions")
        .refreshable { await load() }
    }

    private var forumFeedPicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Picker("Feed", selection: $feed) {
                    ForEach(ForumFeed.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.liftAccentText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("forum.feed")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(ForumFeed.allCases) { option in
                            Button(option.rawValue) { feed = option }
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(feed == option ? Color.liftOnAccent : Color.liftMuted)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(feed == option ? Color.liftLime : Color.clear, in: Capsule())
                                .accessibilityAddTraits(feed == option ? .isSelected : [])
                        }
                    }
                    .padding(4)
                    .background(Color.liftSurfaceElevated, in: Capsule())
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var forumFeedControls: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 12))) {
            Button { showingCommunityDirectory = true } label: {
                Label(selectedGroup?.name ?? "All communities", systemImage: "chevron.down")
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Browse communities")
            .accessibilityValue(selectedGroup?.name ?? "All communities")
            .accessibilityIdentifier("forum.community")
            Spacer(minLength: 0)
            Menu {
                Picker("Sort discussions", selection: $sort) {
                    ForEach(ForumSort.allCases) { option in Text(option.title).tag(option) }
                }
                if hasMorePosts { Text("Applies to loaded discussions") }
            } label: {
                Label(sort.title, systemImage: "line.3.horizontal.decrease")
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Sort discussions")
            .accessibilityValue(sort.title)
            .accessibilityIdentifier("forum.sort")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.liftTextSecondary)
        .padding(.horizontal, 16)
    }

    private var selectedGroup: ForumCommunity? { groups.first { $0.id == selectedGroupID } }

    private var emptyFeedTitle: String {
        switch feed {
        case .friends: return "No friend activity yet"
        case .all: return "No discussions yet"
        case .forYou: return "Your feed is empty"
        case .following: return joinedGroupIDs.isEmpty ? "Join your first community" : "No discussions in your communities"
        }
    }

    private var emptyFeedMessage: String {
        switch feed {
        case .friends:
            return "Shared training from your friends appears here."
        case .all:
            return selectedGroup == nil ? "Choose a community and start a discussion." : "Start this community’s first discussion."
        case .forYou:
            return "Join communities to personalize this feed, or browse pinned recommendations."
        case .following:
            return "Join a community to see its discussions here."
        }
    }

    private var sortedPosts: [ForumPost] {
        let source = filteredPosts
        switch sort {
        case .top: return source.sorted { lhs, rhs in lhs.isPinned != rhs.isPinned ? lhs.isPinned : lhs.voteCount != rhs.voteCount ? lhs.voteCount > rhs.voteCount : lhs.createdAt > rhs.createdAt }
        case .new: return source.sorted { $0.createdAt > $1.createdAt }
        case .discussed: return source.sorted { lhs, rhs in lhs.commentCount != rhs.commentCount ? lhs.commentCount > rhs.commentCount : lhs.createdAt > rhs.createdAt }
        }
    }

    private var filteredPosts: [ForumPost] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return feedPosts }
        return feedPosts.filter { post in
            post.title.localizedCaseInsensitiveContains(query) ||
            post.body.localizedCaseInsensitiveContains(query) ||
            (groups.first { $0.id == post.communityID }?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var feedPosts: [ForumPost] {
        let visiblePosts = posts.filter { !appState.isBlocked($0.authorID) }
        switch feed {
        case .friends:
            return []
        case .all:
            return visiblePosts
        case .forYou:
            return visiblePosts.filter { post in
                guard let communityID = post.communityID else { return false }
                return joinedGroupIDs.contains(communityID) || post.isPinned
            }
        case .following:
            return visiblePosts.filter { post in
                guard let communityID = post.communityID else { return false }
                return joinedGroupIDs.contains(communityID)
            }
        }
    }

    private func load() async {
        do {
            groups = try await appState.forumStore.communities()
            membershipStatuses = try await appState.forumStore.communityMembershipStatuses()
            joinedGroupIDs = Set(try await appState.forumStore.joinedCommunityIDs())
            await loadPosts()
            await openRequestedPostIfNeeded()
        }
        catch { message = error.localizedDescription; isLoading = false }
    }

    private func openRequestedPostIfNeeded() async {
        guard let postID = appState.router.forumPostToOpen else { return }
        let commentID = appState.router.forumCommentToOpen
        defer {
            appState.router.forumPostToOpen = nil
            appState.router.forumCommentToOpen = nil
        }
        if let post = posts.first(where: { $0.id == postID }) {
            requestedCommentID = commentID
            requestedPost = post
            return
        }
        if let thread = try? await appState.forumStore.thread(postID: postID) {
            requestedCommentID = commentID
            requestedPost = thread.post
        } else {
            message = "This discussion is no longer available or you do not have access to it."
        }
    }

    private func loadPosts() async {
        do {
            let remotePosts = try await appState.forumStore.posts(communityID: selectedGroupID, limit: 50, offset: 0)
            remotePostOffset = remotePosts.count
            hasMorePosts = remotePosts.count == 50
#if DEBUG
            posts = remotePosts + (appState.isDemoMode ? ForumDemoContent.posts(for: groups, communityID: selectedGroupID) : [])
#else
            posts = remotePosts
#endif
            message = nil
            isLoading = false
        }
        catch { message = error.localizedDescription; isLoading = false }
    }

    private func loadMorePosts() async {
        guard hasMorePosts, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let remotePosts = try await appState.forumStore.posts(communityID: selectedGroupID, limit: 50, offset: remotePostOffset)
            let existingIDs = Set(posts.map(\.id))
            posts.append(contentsOf: remotePosts.filter { !existingIDs.contains($0.id) })
            message = nil
            remotePostOffset += remotePosts.count
            hasMorePosts = remotePosts.count == 50
        } catch { message = error.localizedDescription }
    }

    private func toggleMembership(_ group: ForumCommunity) async {
        do {
            if joinedGroupIDs.contains(group.id) {
                try await appState.forumStore.leave(communityID: group.id)
                joinedGroupIDs.remove(group.id)
                membershipStatuses[group.id] = "Left"
            } else {
                let status = try await appState.forumStore.join(communityID: group.id, requestNote: "")
                membershipStatuses[group.id] = status
                if status == "Joined" || status == "Muted" {
                    joinedGroupIDs.insert(group.id)
                }
            }
        } catch { message = error.localizedDescription }
    }
}

private struct ForumCommunityDirectoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""
    @State private var changingMembershipID: UUID?
    let groups: [ForumCommunity]
    @Binding var joinedGroupIDs: Set<UUID>
    @Binding var membershipStatuses: [UUID: String]
    @Binding var selectedGroupID: UUID?
    let onMembershipChanged: (ForumCommunity) async -> Void
    let onCommunitySelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Button {
                            selectedGroupID = nil
                            onCommunitySelected()
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text("All communities")
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if selectedGroupID == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .semibold))
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityAddTraits(selectedGroupID == nil ? .isSelected : [])
                        ForEach(groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) }) { group in
                            communityRow(group)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .searchable(text: $query, prompt: "Search communities")
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
    }

    private func communityRow(_ group: ForumCommunity) -> some View {
        let isJoined = joinedGroupIDs.contains(group.id)
        let membershipStatus = membershipStatuses[group.id]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                Circle()
                    .fill(Color.liftLime.opacity(0.18))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(LiftTypography.cardTitle)
                    Text(group.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftAccentText)
                    Text(group.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            if let membershipStatus { Text(membershipStatus).font(.caption).foregroundStyle(Color.liftMuted) }
            if !group.details.isEmpty {
                DisclosureGroup("About community") {
                    Text(group.details).font(.caption).foregroundStyle(Color.liftMuted)
                }
            }

            HStack(spacing: 10) {
                Button {
                    selectedGroupID = group.id
                    onCommunitySelected()
                } label: {
                    Text("View discussions")
                        .font(LiftTypography.rowEmphasis)
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())

                Button {
                    Task { changingMembershipID = group.id; await onMembershipChanged(group); changingMembershipID = nil }
                } label: {
                    Text(isJoined ? "Leave" : (membershipStatus == "Pending" ? "Requested" : membershipStatus == "Banned" ? "Unavailable" : "Join"))
                        .font(LiftTypography.rowEmphasis)
                        .frame(minWidth: 70, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .tint(isJoined ? Color.liftMuted : Color.liftAccentText)
                .disabled(membershipStatus == "Pending" || membershipStatus == "Banned" || changingMembershipID != nil)
            }
        }
        .padding(16)
        .liftSurface(radius: 16)
    }
}

#if DEBUG
private enum ForumDemoContent {
    private static let authorID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

    static func posts(for groups: [ForumCommunity], communityID: UUID?) -> [ForumPost] {
        groups
            .filter { communityID == nil || $0.id == communityID }
            .enumerated()
            .flatMap { index, group in
                [
                    ForumPost(
                        id: demoID(group.id, offset: 1), communityID: group.id, gymID: nil, authorID: authorID,
                        kind: "Discussion", title: title(for: group, index: index), body: body(for: group),
                        tag: "demo", liftID: nil, isPinned: index == 0, isLocked: false,
                        createdAt: Date().addingTimeInterval(TimeInterval(-(index + 1) * 3600))
                    ),
                    ForumPost(
                        id: demoID(group.id, offset: 2), communityID: group.id, gymID: nil, authorID: authorID,
                        kind: "Question", title: "What should new members know about \(group.name)?",
                        body: "Share the practical lessons, routines, and resources that helped you make progress.",
                        tag: "demo", liftID: nil, isPinned: false, isLocked: false,
                        createdAt: Date().addingTimeInterval(TimeInterval(-(index + 2) * 7200))
                    )
                ]
            }
    }

    static func thread(for post: ForumPost) -> ForumThread {
        ForumThread(
            post: post,
            comments: [
                ForumComment(
                    id: demoID(post.id, offset: 3), postID: post.id, authorID: authorID, parentCommentID: nil,
                    body: "I’m focusing on consistent training days and tracking my working sets this block. What are your goals?",
                    createdAt: post.createdAt.addingTimeInterval(1800)
                ),
                ForumComment(
                    id: demoID(post.id, offset: 4), postID: post.id, authorID: authorID, parentCommentID: nil,
                    body: "I’m keeping a few main lifts consistent so I can compare my progress from week to week.",
                    createdAt: post.createdAt.addingTimeInterval(3600)
                ),
                ForumComment(
                    id: demoID(post.id, offset: 5), postID: post.id, authorID: authorID,
                    parentCommentID: demoID(post.id, offset: 3),
                    body: "Same here. Having a regular schedule makes it easier to see what’s working.",
                    createdAt: post.createdAt.addingTimeInterval(2700)
                )
            ]
        )
    }

    private static func title(for group: ForumCommunity, index: Int) -> String {
        switch index % 4 {
        case 0: return "How are you approaching your next training block?"
        case 1: return "Form checks and small wins from this week"
        case 2: return "Share your favorite resources for getting stronger"
        default: return "What are you working toward this month?"
        }
    }

    private static func body(for group: ForumCommunity) -> String {
        "A sample conversation for \(group.name). Talk through your goals, ask for feedback, and keep the advice practical."
    }

    private static func demoID(_ base: UUID, offset: UInt8) -> UUID {
        var bytes = base.uuid
        bytes.15 = bytes.15 &+ offset
        return UUID(uuid: bytes)
    }
}
#endif

private struct ForumComposerView: View {
    @EnvironmentObject private var appState: AppState
    let groups: [ForumCommunity]
    let didPublish: (ForumPost) async -> Void
    @State private var membershipStatuses: [UUID: String]
    @State private var isJoining = false
    @Environment(\.dismiss) private var dismiss
    @State private var groupID: UUID?
    @State private var title = ""
    @State private var draftBody = ""
    @State private var error: String?
    @State private var isPublishing = false
    @State private var draftID = UUID()
    @State private var pickerItem: PhotosPickerItem?
    @State private var media: ForumMediaDraft?
    @State private var isPreparingMedia = false
    @State private var confirmingDiscard = false

    init(groups: [ForumCommunity], selectedGroupID: UUID?, membershipStatuses: [UUID: String], didPublish: @escaping (ForumPost) async -> Void) {
        self.groups = groups
        self.didPublish = didPublish
        _membershipStatuses = State(initialValue: membershipStatuses)
        _groupID = State(initialValue: selectedGroupID)
    }

    private var hasDraft: Bool {
        !title.isEmpty || !draftBody.isEmpty || media != nil || isPreparingMedia
    }

    var body: some View {
        NavigationStack {
            Form {
                if isPublishing { ProgressView(media == nil ? "Publishing…" : "Uploading attachment and publishing…") }
                Section("Community") {
                    Picker("Community", selection: $groupID) {
                        Text("Choose a community").tag(UUID?.none)
                        ForEach(groups) { group in Text(group.name).tag(Optional(group.id)) }
                    }
                }
                if let group = groups.first(where: { $0.id == groupID }) {
                    Label("\(group.name) · \(group.visibility)", systemImage: "person.3").font(.caption)
                    if let status = membershipStatuses[group.id], ["Pending", "Muted", "Banned"].contains(status) {
                        Text("Posting unavailable · \(status)").font(.caption).foregroundStyle(Color.liftMuted)
                    }
                }
                if let groupID, membershipStatuses[groupID] != "Joined" {
                    Button(isJoining ? "Joining…" : "Join community to post") {
                        Task {
                            isJoining = true
                            defer { isJoining = false }
                            do { membershipStatuses[groupID] = try await appState.forumStore.join(communityID: groupID, requestNote: ""); error = nil }
                            catch { self.error = error.localizedDescription }
                        }
                    }.disabled(isJoining || ["Pending", "Banned", "Muted"].contains(membershipStatuses[groupID] ?? ""))
                }
                Section("Discussion") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("forum.composer.title")
                    TextField("Share the training context", text: $draftBody, axis: .vertical)
                        .lineLimit(5...12)
                        .accessibilityIdentifier("forum.composer.body")
                }
                Section("Photo or video · Optional") {
                    if let media {
                        ForumMediaView(
                            attachment: ForumAttachment(kind: media.kind, storagePath: media.fileURL.path),
                            localURL: media.fileURL
                        )
                        Button("Remove attachment", role: .destructive) {
                            removeMedia()
                            pickerItem = nil
                        }
                            .accessibilityIdentifier("forum.composer.removeMedia")
                    }
                    if isPreparingMedia {
                        ProgressView("Preparing attachment…")
                    } else {
                        PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                            Label(media == nil ? "Add photo or video" : "Replace attachment", systemImage: "photo.on.rectangle")
                        }
                        .accessibilityIdentifier("forum.composer.addMedia")
                    }
                    Text("Photos up to 10 MB · Videos up to 2 minutes and 50 MB")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                }
                DisclosureGroup("Posting rules") {
                    Text("Keep posts about training. No harassment, hate, threats, explicit content, or spam. Only share media you have permission to post.")
                    Link("Contact support", destination: URL(string: "mailto:support@liftrivals.com")!)
                }
                if title.count > 180 || draftBody.count > 10_000 {
                    Text("Use a title up to 180 characters and a discussion up to 10,000 characters.")
                        .font(.caption).foregroundStyle(Color.liftRed)
                }
                if appState.isDemoMode {
                    Text("Demo post · this session only")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                } else if let group = groups.first(where: { $0.id == groupID }) {
                    Label("\(group.visibility) community · \(group.name)", systemImage: group.visibility == "Invite Only" ? "lock" : "person.3")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                }
                if let error { Text(error).foregroundStyle(Color.liftRed) }
            }
            .disabled(isPublishing)
            .navigationTitle("New discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasDraft { confirmingDiscard = true } else { dismiss() }
                    }.disabled(isPublishing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await publish() } } label: {
                        if isPublishing { ProgressView() } else { Text("Publish") }
                    }
                    .disabled(isPublishing || isPreparingMedia || groupID == nil || membershipStatuses[groupID ?? UUID()] != "Joined" || title.count > 180 || draftBody.count > 10_000 || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: pickerItem) { await prepareSelectedMedia() }
            .confirmationDialog("Discard this post?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard post", role: .destructive) {
                    removeMedia()
                    pickerItem = nil
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasDraft || isPublishing)
        }
    }

    private func removeMedia() {
        if let media { try? FileManager.default.removeItem(at: media.fileURL) }
        media = nil
    }

    @MainActor
    private func prepareSelectedMedia() async {
        guard let pickerItem else { return }
        isPreparingMedia = true
        error = nil
        defer { isPreparingMedia = false }
        do {
            guard let file = try await pickerItem.loadTransferable(type: ForumPickedFile.self) else {
                throw LiftRankServiceError.invalidInput("The selected media could not be opened.")
            }
            defer { try? FileManager.default.removeItem(at: file.url) }
            let kind: ForumAttachment.Kind = pickerItem.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) ? .video : .photo
            let prepared = try await ForumMediaPreparation.prepare(file.url, kind: kind)
            guard !Task.isCancelled else {
                try? FileManager.default.removeItem(at: prepared.fileURL)
                return
            }
            removeMedia()
            media = prepared
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
            self.pickerItem = nil
        }
    }

    private func publish() async {
        guard let groupID else { return }
        guard !isPublishing else { return }
        isPublishing = true
        defer { isPublishing = false }
        do {
            let created = try await appState.forumStore.createPost(ForumPostDraft(id: draftID, communityID: groupID, kind: "Discussion", title: title, body: draftBody, tag: nil, liftID: nil, media: media))
            await didPublish(created)
            removeMedia()
            dismiss()
        } catch let publishError { error = publishError.localizedDescription }
    }
}

private struct ForumPostCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let post: ForumPost
    let community: ForumCommunity?
    let onCommunitySelected: () -> Void
    let onPostDeleted: () -> Void
    @State private var displayedPost: ForumPost
    @State private var author: UserProfile?
    @State private var isVoting = false
    @State private var error: String?

    init(post: ForumPost, community: ForumCommunity?, onCommunitySelected: @escaping () -> Void, onPostDeleted: @escaping () -> Void) {
        self.post = post
        self.community = community
        self.onCommunitySelected = onCommunitySelected
        self.onPostDeleted = onPostDeleted
        _displayedPost = State(initialValue: post)
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(action: onCommunitySelected) {
                        Text(community?.name ?? "Community")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftText)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(community == nil)
                    Spacer(minLength: 4)
                    Text(LiftTimeFormatter.relativeNoSeconds(from: displayedPost.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                postPreview
                ForEach(displayedPost.attachments) { attachment in
                    ForumMediaView(attachment: attachment, compact: true)
                }
                postActions
                if let error { Text(error).font(.caption).foregroundStyle(Color.liftRed) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider().overlay(Color.liftSurfaceBorder)
        }
        .buttonStyle(.plain)
        .onChange(of: post) { _, updated in displayedPost = updated }
        .task(id: post.authorID) {
            guard post.tag != "demo", post.authorID != appState.currentProfile.id else { return }
            do { author = try await appState.profileStore.publicProfile(userID: post.authorID) }
            catch { author = nil }
        }
    }

    private func discussionDestination(opensComments: Bool) -> some View {
        ForumThreadView(
            post: displayedPost,
            highlightedCommentID: nil,
            opensComments: opensComments,
            onPostChange: { displayedPost = $0 },
            onPostDeleted: onPostDeleted
        ).environmentObject(appState)
    }

    private var postPreview: some View {
        NavigationLink {
            discussionDestination(opensComments: false)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(authorLabel)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                if displayedPost.isPinned || displayedPost.isLocked || displayedPost.kind == "Question" {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { postBadges }
                        VStack(alignment: .leading, spacing: 8) { postBadges }
                    }
                }
                Text(displayedPost.title)
                    .font(LiftTypography.cardTitle)
                    .foregroundStyle(Color.liftText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(displayedPost.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftTextSecondary)
                    .lineLimit(2)
                if let tag = displayedPost.tag, tag != "demo" {
                    Text(tag).font(.caption.weight(.semibold)).foregroundStyle(Color.liftAccentText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("forum.post.\(post.id)")
    }

    @ViewBuilder private var postBadges: some View {
        if displayedPost.kind == "Question" { forumBadge("Question", icon: "questionmark.circle") }
        if displayedPost.isPinned { forumBadge("Pinned", icon: "pin.fill") }
        if displayedPost.isLocked { forumBadge("Locked", icon: "lock.fill") }
    }

    private var commentCount: Int { displayedPost.tag == "demo" ? 3 : displayedPost.commentCount }

    private var postActions: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
            ForumVoteControls(score: displayedPost.voteCount, vote: displayedPost.currentUserVote, isDisabled: isVoting || (appState.isDemoMode && post.tag == "demo")) { direction in
                Task { await toggleVote(direction) }
            }
            NavigationLink {
                discussionDestination(opensComments: true)
            } label: {
                Label("\(commentCount)", systemImage: "bubble.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("\(commentCount) \(commentCount == 1 ? "comment" : "comments")")
            .accessibilityIdentifier("forum.post.comments.\(post.id)")
            Spacer(minLength: 0)
            ShareLink(item: "\(displayedPost.title)\n\n\(displayedPost.body)", subject: Text(displayedPost.title)) {
                Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Share discussion text")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.liftTextSecondary)
    }

    private var authorLabel: String {
        if post.tag == "demo" { return "lift_rank_member" }
        if post.authorID == appState.currentProfile.id {
            return appState.currentProfile.username.isEmpty ? "You" : "@\(appState.currentProfile.username)"
        }
        if let profile = author ?? appState.profileStore.profile(id: post.authorID) {
            if !profile.username.isEmpty { return "@\(profile.username)" }
            if !profile.displayName.isEmpty { return profile.displayName }
        }
        return "Unavailable author"
    }

    private func toggleVote(_ direction: Int) async {
        guard !isVoting else { return }
        isVoting = true
        defer { isVoting = false }
        let viewerID = appState.currentProfile.id
        do {
            let updated = try await appState.forumStore.toggleVote(on: displayedPost, direction: direction)
            guard viewerID == appState.currentProfile.id else { return }
            displayedPost = updated
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func forumBadge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liftAccentText)
    }
}

private struct ForumVoteControls: View {
    let score: Int
    let vote: Int?
    let isDisabled: Bool
    let onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            voteButton(direction: 1, icon: "arrow.up", label: "Upvote discussion")
            Text("\(score)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel("\(score) votes")
            voteButton(direction: -1, icon: "arrow.down", label: "Downvote discussion")
        }
        .background(Color.liftSurfaceElevated, in: Capsule())
    }

    private func voteButton(direction: Int, icon: String, label: String) -> some View {
        Button { onVote(direction) } label: {
            Image(systemName: vote == direction ? "\(icon).circle.fill" : icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(vote == direction ? Color.liftAccentText : Color.liftTextSecondary)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(vote == direction ? (direction == 1 ? "Remove upvote" : "Remove downvote") : label)
        .accessibilityAddTraits(vote == direction ? .isSelected : [])
    }
}

private struct ForumThreadView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let post: ForumPost
    let highlightedCommentID: UUID?
    var isPresentedAsSheet = false
    var opensComments = false
    var onPostChange: ((ForumPost) -> Void)? = nil
    var onPostDeleted: (() -> Void)? = nil
    @State private var thread: ForumThread?
    @FocusState private var replyFocused: Bool
    @State private var didScrollToInitialTarget = false
    @State private var reply = ""
    @State private var replyingTo: UUID?
    @State private var error: String?
    @State private var isWatching = false
    @State private var isLoadingThread = true
    @State private var draftOwnerID: UUID?
    @State private var isUpdatingReaction = false
    @State private var feedback: String?
    @State private var confirmingReplyDiscard = false
    @State private var confirmingEditDiscard = false
    @State private var originalEdit: [String] = []
    @State private var communityName: String?
    @State private var authors: [UUID: UserProfile] = [:]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var editHasChanges: Bool { [editTitle, editBody] != originalEdit }
    private var editTooLong: Bool { editTitle.count > 180 || editBody.count > (editingCommentID == nil ? 10000 : 5000) }
    @State private var commentVoteValues: [UUID: Int] = [:]
    @State private var collapsedCommentIDs: Set<UUID> = []
    @State private var commentSort: ForumCommentSort = .best
    @State private var showingReportReasons = false
    @State private var reportTargetCommentID: UUID?
    @State private var isSubmittingReply = false
    @State private var showingEditSheet = false
    @State private var showingDeletePostConfirmation = false
    @State private var deletingCommentID: UUID?
    @State private var blockingAuthorID: UUID?
    @State private var isBlockingAuthor = false
    @State private var editingCommentID: UUID?
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var isSavingEdit = false

    private var isDemoReadOnly: Bool { appState.isDemoMode && post.tag == "demo" }

    private var threadContent: some View {
        AppBackground {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    if let thread {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                forumAvatar
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(authorDisplayName(for: post.authorID, isDemo: isDemoReadOnly))
                                        .font(.subheadline.weight(.semibold))
                                    Text(LiftTimeFormatter.relativeNoSeconds(from: post.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                if isDemoReadOnly {
                                    Label("Demo preview", systemImage: "eye")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.liftAccentText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.liftLime.opacity(0.12), in: Capsule())
                                } else {
                                    Menu {
                                        if post.authorID == appState.currentProfile.id {
                                            Button("Edit discussion", systemImage: "pencil") { beginEditingPost() }
                                            Button("Delete discussion", systemImage: "trash", role: .destructive) {
                                                showingDeletePostConfirmation = true
                                            }
                                            .accessibilityIdentifier("forum.discussion.delete")
                                            Divider()
                                        }
                                        Button("Report discussion", role: .destructive) { showingReportReasons = true }
                                        if post.authorID != appState.currentProfile.id {
                                            Button("Block author", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                                                blockingAuthorID = post.authorID
                                            }
                                            .disabled(isBlockingAuthor)
                                        }
                                        Link("Contact support", destination: URL(string: "mailto:support@liftrivals.com")!)
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(Color.liftMuted)
                                                .frame(minWidth: 44, minHeight: 44)
                                                .accessibilityLabel("Discussion actions")
                                                .accessibilityIdentifier("forum.discussion.actions")
                                    }
                                }
                            }
                            Text(thread.post.title)
                                .font(.title2.weight(.bold))
                            Text(thread.post.body)
                                .font(.body)
                                .foregroundStyle(Color.liftTextSecondary)
                            ForEach(thread.post.attachments) { attachment in
                                ForumMediaView(attachment: attachment)
                            }
                            discussionActions(for: thread.post)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liftBackground)

                        HStack {
                            Text("\(thread.comments.count) \(thread.comments.count == 1 ? "comment" : "comments")")
                                .font(LiftTypography.cardTitle)
                            Spacer()
                            Menu {
                                ForEach(ForumCommentSort.allCases) { option in
                                    Button { commentSort = option } label: {
                                        Label(option.title, systemImage: option.icon)
                                    }
                                }
                            } label: {
                                Label(commentSort.title, systemImage: commentSort.icon)
                                    .font(LiftTypography.compactEmphasis)
                                    .foregroundStyle(Color.liftAccentText)
                            }
                            .accessibilityLabel("Comment sort")
                        }
                        .id("forum.comments")
                        .padding(.horizontal, 16)
                        if thread.comments.isEmpty {
                            Text("Be the first to comment.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .padding(.horizontal, 16)
                        } else {
                            ForEach(displayComments(from: thread.comments), id: \.comment.id) { row in
                                forumComment(
                                    row.comment,
                                    depth: row.depth,
                                    hasReplies: thread.comments.contains { $0.parentCommentID == row.comment.id }
                                )
                                    .id(row.comment.id)
                            }
                        }
                    } else if isLoadingThread {
                        ProgressView().frame(maxWidth: .infinity).padding(40)
                    } else {
                        LiftEmptyState(title: "Discussion unavailable", message: error ?? "It may have been removed or its access changed.", actionTitle: "Retry", action: { Task { await load() } })
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(Color.liftRed) }
                }
                    .padding(16)
                }
                .onChange(of: thread?.comments.count) { _, _ in
                    scrollToHighlightedComment(using: proxy)
                }
                .task {
                    scrollToHighlightedComment(using: proxy)
                }
            }
        }
    }

    var body: some View {
        threadContent
        .navigationTitle(communityName ?? "Discussion")
        .navigationBarBackButtonHidden(!reply.isEmpty || isSubmittingReply)
        .toolbar {
            if isPresentedAsSheet || !reply.isEmpty || isSubmittingReply {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPresentedAsSheet ? "Close" : "Back", systemImage: isPresentedAsSheet ? "xmark" : "chevron.left") {
                        if reply.isEmpty { dismiss() } else { confirmingReplyDiscard = true }
                    }
                    .disabled(isSubmittingReply)
                }
            }
        }
        .interactiveDismissDisabled(!reply.isEmpty || isSubmittingReply)
        .confirmationDialog("Leave this reply?", isPresented: $confirmingReplyDiscard, titleVisibility: .visible) {
            Button("Keep draft & leave") { dismiss() }
            Button("Discard reply", role: .destructive) { reply = ""; replyingTo = nil; saveReplyDraft(); dismiss() }
            Button("Keep writing", role: .cancel) {}
        }
        .onChange(of: appState.currentProfile.id) {
            reply = ""
            thread = nil
            authors = [:]
            dismiss()
        }
        .onChange(of: reply) { saveReplyDraft() }
        .onChange(of: replyingTo) { saveReplyDraft() }
        .onChange(of: thread?.post) { _, updated in
            if let updated { onPostChange?(updated) }
        }
        .safeAreaInset(edge: .top) {
            if let feedback {
                HStack { Label(feedback, systemImage: "checkmark.circle"); Spacer(); Button("Dismiss") { self.feedback = nil } }
                    .font(.caption).padding(12).background(Color.liftCard)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(reportDialogTitle, isPresented: $showingReportReasons, titleVisibility: .visible) {
            Button("Spam or promotion", role: .destructive) { Task { await report(reason: "spam") } }
            Button("Harassment or abuse", role: .destructive) { Task { await report(reason: "harassment") } }
            Button("Inappropriate content", role: .destructive) { Task { await report(reason: "inappropriate_content") } }
            Button("Off-topic or misleading", role: .destructive) { Task { await report(reason: "off_topic") } }
            Button("Cancel", role: .cancel) { reportTargetCommentID = nil }
        }
        .confirmationDialog("Block this author?", isPresented: Binding(
            get: { blockingAuthorID != nil },
            set: { if !$0 { blockingAuthorID = nil } }
        ), titleVisibility: .visible) {
            Button("Block author", role: .destructive) {
                guard let authorID = blockingAuthorID else { return }
                Task { await blockAuthor(authorID) }
            }
            Button("Cancel", role: .cancel) { blockingAuthorID = nil }
        } message: {
            Text("Their posts and replies will be hidden.")
        }
        .confirmationDialog("Delete this discussion?", isPresented: $showingDeletePostConfirmation, titleVisibility: .visible) {
            Button("Delete discussion", role: .destructive) { Task { await deletePost() } }
                .accessibilityIdentifier("forum.discussion.delete.confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The discussion will be removed from the forum.")
        }
        .confirmationDialog("Delete this comment?", isPresented: Binding(
            get: { deletingCommentID != nil },
            set: { if !$0 { deletingCommentID = nil } }
        ), titleVisibility: .visible) {
            Button("Delete comment", role: .destructive) {
                guard let commentID = deletingCommentID else { return }
                Task { await deleteComment(commentID: commentID) }
            }
                .accessibilityIdentifier("forum.comment.delete.confirm")
            Button("Cancel", role: .cancel) { deletingCommentID = nil }
        } message: {
            Text("The comment will be removed from the discussion.")
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                Form {
                    if editingCommentID == nil {
                        TextField("Title", text: $editTitle)
                            .accessibilityIdentifier("forum.edit.title")
                    }
                    TextField(editingCommentID == nil ? "Discussion" : "Comment", text: $editBody, axis: .vertical)
                        .lineLimit(5...12)
                        .accessibilityIdentifier("forum.edit.body")
                    if editTooLong { Text("Title: 180 characters. Discussion: 10,000. Comment: 5,000.").foregroundStyle(Color.liftRed) }
                    if editingCommentID == nil && !(thread?.post.attachments.isEmpty ?? true) {
                        Text("The existing attachment stays with this post. Only text can be edited.").font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    if let error { Text(error).foregroundStyle(Color.liftRed) }
                }
                .interactiveDismissDisabled(editHasChanges || isSavingEdit)
                .confirmationDialog("Discard edits?", isPresented: $confirmingEditDiscard, titleVisibility: .visible) {
                    Button("Discard edits", role: .destructive) { showingEditSheet = false }
                    Button("Keep editing", role: .cancel) {}
                }
                .navigationTitle(editingCommentID == nil ? "Edit discussion" : "Edit comment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { if editHasChanges { confirmingEditDiscard = true } else { showingEditSheet = false } }.disabled(isSavingEdit)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await saveEdit() } }
                            .disabled(isSavingEdit || editTooLong || editBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (editingCommentID == nil && editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if thread?.post.isLocked == true {
                Text("This discussion is locked. New replies are unavailable.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.liftBackground)
            } else if thread != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if isDemoReadOnly {
                        Text("Demo forum is read-only. Sign in to post, reply, vote, or report.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.liftBackground)
                    } else if let replyingTo,
                       let parent = thread?.comments.first(where: { $0.id == replyingTo }) {
                        HStack(spacing: 6) {
                            Text("Replying to \(authorDisplayName(for: parent.authorID, isDemo: isDemoReadOnly))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                            Spacer()
                            Button("Cancel") { self.replyingTo = nil }
                                .font(.caption.weight(.semibold))
                        }
                    }
                    if !isDemoReadOnly {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField(replyingTo == nil ? "Write a comment…" : "Write a reply…", text: $reply, axis: .vertical)
                            .focused($replyFocused)
                            .lineLimit(1...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("forum.reply.body")
                        Button { Task { await submitReply() } } label: {
                            if isSubmittingReply {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .accessibilityLabel("Submit comment")
                        .accessibilityIdentifier("forum.reply.submit")
                        .disabled(isSubmittingReply || reply.count > 5000 || reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(Color.liftAccentText)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    if reply.count > 4500 { Text("\(reply.count)/5000").font(.caption).foregroundStyle(reply.count > 5000 ? Color.liftRed : Color.liftMuted) }
                    if let error { Text(error).font(.caption).foregroundStyle(Color.liftRed) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.liftBackground)
            }
        }
        .task { await load() }
    }

    private func discussionActions(for post: ForumPost) -> some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 9))) {
            ForumVoteControls(score: post.voteCount, vote: post.currentUserVote, isDisabled: isDemoReadOnly || isUpdatingReaction) { direction in
                Task { await toggleVote(direction) }
            }

            Spacer()
            Menu {
            ShareLink(
                item: "\(post.title)\n\n\(post.body)",
                subject: Text(post.title),
                message: Text("Text from a Lift Rivals discussion")
            ) {
                Label("Share discussion text", systemImage: "text.quote")
            }
            } label: { Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44) }
            .accessibilityLabel("Share options")
            Button { Task { await toggleWatch() } } label: {
                Label(isWatching ? "Watching" : "Watch", systemImage: isWatching ? "bell.fill" : "bell").font(.caption).frame(minHeight: 44)
            }
            .foregroundStyle(Color.liftMuted)
            .disabled(isDemoReadOnly || isUpdatingReaction)
        }
    }

    private func scrollToHighlightedComment(using proxy: ScrollViewProxy) {
        guard !didScrollToInitialTarget, let thread else { return }
        let target: AnyHashable
        if let highlightedCommentID, thread.comments.contains(where: { $0.id == highlightedCommentID }) {
            target = highlightedCommentID
        } else if opensComments {
            target = "forum.comments"
        } else { return }
        didScrollToInitialTarget = true
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(target, anchor: .top) }
        }
    }

    private var reportDialogTitle: String {
        let target = reportTargetCommentID == nil ? "discussion" : "comment"
        return "Why are you reporting this \(target)?"
    }

    private var forumAvatar: some View {
        Group {
            if let profile = authors[post.authorID] ?? appState.profileStore.profile(id: post.authorID) {
                ProfileAvatar(profile: profile, size: 38)
            } else {
                Image(systemName: "person.crop.circle.fill").font(.title).foregroundStyle(Color.liftMuted).frame(width: 38, height: 38)
            }
        }
    }

    private func authorDisplayName(for authorID: UUID, isDemo: Bool) -> String {
        if isDemo { return "lift_rank_member" }
        if authorID == appState.currentProfile.id {
            return appState.currentProfile.username.isEmpty ? "You" : "@\(appState.currentProfile.username)"
        }
        if let profile = authors[authorID] ?? appState.profileStore.profile(id: authorID) {
            if !profile.username.isEmpty { return "@\(profile.username)" }
            if !profile.displayName.isEmpty { return profile.displayName }
        }
        return "Unavailable author"
    }

    private func forumComment(_ comment: ForumComment, depth: Int, hasReplies: Bool) -> some View {
        let isCollapsed = collapsedCommentIDs.contains(comment.id)
        let indentation = CGFloat(min(depth, 3) * (dynamicTypeSize.isAccessibilitySize ? 6 : 12))
        return HStack(alignment: .top, spacing: 10) {
            if let profile = authors[comment.authorID] ?? appState.profileStore.profile(id: comment.authorID) {
                ProfileAvatar(profile: profile, size: 30)
            } else { Image(systemName: "person.crop.circle").foregroundStyle(Color.liftMuted).frame(width: 30, height: 30) }
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    if isCollapsed { collapsedCommentIDs.remove(comment.id) }
                    else { collapsedCommentIDs.insert(comment.id) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(authorDisplayName(for: comment.authorID, isDemo: isDemoReadOnly))
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftText)
                            Text(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))
                                .font(.caption2)
                                .foregroundStyle(Color.liftMuted)
                        }
                        if comment.authorID == post.authorID {
                            Text("OP").font(.caption.weight(.bold)).foregroundStyle(Color.liftAccentText)
                                .accessibilityLabel("Original poster")
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(isCollapsed ? "Expand" : "Collapse") \(hasReplies ? "thread" : "comment") by \(authorDisplayName(for: comment.authorID, isDemo: isDemoReadOnly))")
                .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
                .accessibilityIdentifier("forum.comment.toggle.\(comment.id)")
                if isCollapsed {
                    Text("Comment collapsed").font(.caption).foregroundStyle(Color.liftMuted)
                } else {
                Text(comment.body)
                    .font(.body)
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
                    Button("Reply", systemImage: "arrowshape.turn.up.left") {
                        replyingTo = comment.id
                        replyFocused = true
                    }.frame(minHeight: 44)
                        .disabled(isDemoReadOnly || isUpdatingReaction || thread?.post.isLocked == true)
                    Button { Task { await toggleCommentVote(comment) } } label: {
                        Label("\(comment.voteCount)", systemImage: commentVoteValues[comment.id] == 1 ? "arrow.up.circle.fill" : "arrow.up")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(commentVoteValues[comment.id] == 1 ? "Remove comment upvote, \(comment.voteCount) votes" : "Upvote comment, \(comment.voteCount) votes")
                    .disabled(isDemoReadOnly || isUpdatingReaction)
                    Button { Task { await toggleCommentDownvote(comment) } } label: {
                        Image(systemName: commentVoteValues[comment.id] == -1 ? "arrow.down.circle.fill" : "arrow.down")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(commentVoteValues[comment.id] == -1 ? "Remove comment downvote" : "Downvote comment")
                    .disabled(isDemoReadOnly || isUpdatingReaction)
                    Spacer(minLength: 0)
                    Menu {
                        if comment.authorID == appState.currentProfile.id && !isDemoReadOnly {
                            Button("Edit comment", systemImage: "pencil") { beginEditingComment(comment) }
                            Button("Delete comment", systemImage: "trash", role: .destructive) { deletingCommentID = comment.id }
                                .accessibilityIdentifier("forum.comment.delete")
                        }
                        Button("Report", systemImage: "flag") {
                            reportTargetCommentID = comment.id
                            showingReportReasons = true
                        }
                        .disabled(isDemoReadOnly || isUpdatingReaction)
                        if comment.authorID != appState.currentProfile.id && !isDemoReadOnly {
                            Button("Block author", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                                blockingAuthorID = comment.authorID
                            }
                            .disabled(isBlockingAuthor)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(minWidth: LiftDesign.minimumTouchTarget, minHeight: LiftDesign.minimumTouchTarget)
                    }
                    .accessibilityLabel("Comment actions")
                    .accessibilityIdentifier("forum.comment.actions")
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                }
            }
        }
        .padding(.leading, indentation + 16)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .leading) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.liftSurfaceBorder)
                    .frame(width: 2)
                    .padding(.leading, indentation + 8)
            }
        }
    }

    private func displayComments(from comments: [ForumComment]) -> [(comment: ForumComment, depth: Int)] {
        let comments = comments.filter { !appState.isBlocked($0.authorID) }
        var rows: [(comment: ForumComment, depth: Int)] = []
        let byParent = Dictionary(grouping: comments, by: \.parentCommentID)
        let commentIDs = Set(comments.map(\.id))

        func append(_ comment: ForumComment, depth: Int) {
            rows.append((comment, depth))
            guard !collapsedCommentIDs.contains(comment.id) else { return }
            for child in sortedComments(byParent[comment.id, default: []]) {
                append(child, depth: depth + 1)
            }
        }

        let roots = comments.filter { $0.parentCommentID == nil || !commentIDs.contains($0.parentCommentID!) }
        for comment in sortedComments(roots) {
            append(comment, depth: 0)
        }
        return rows
    }

    private func sortedComments(_ comments: [ForumComment]) -> [ForumComment] {
        switch commentSort {
        case .best:
            return comments.sorted {
                $0.voteCount != $1.voteCount
                    ? $0.voteCount > $1.voteCount
                    : $0.createdAt < $1.createdAt
            }
        case .new:
            return comments.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func saveReplyDraft() {
        guard let draftOwnerID, draftOwnerID == appState.currentProfile.id else { return }
        appState.forumStore.replyDrafts[draftOwnerID, default: [:]][post.id] = reply.isEmpty ? nil : (reply, replyingTo)
    }

    private func load() async {
        let viewerID = appState.currentProfile.id
        if draftOwnerID == nil { draftOwnerID = viewerID }
        guard draftOwnerID == viewerID else { return }
        isLoadingThread = true
        error = nil
        defer { isLoadingThread = false }
        if reply.isEmpty, let draft = appState.forumStore.replyDrafts[appState.currentProfile.id]?[post.id] {
            reply = draft.body
            replyingTo = draft.parentID
        }
        do {
            let loadedThread = try await appState.forumStore.thread(postID: post.id)
            guard viewerID == appState.currentProfile.id else { return }
            thread = loadedThread
            isWatching = thread?.isWatching ?? false
            commentVoteValues = Dictionary(uniqueKeysWithValues: (thread?.comments ?? []).compactMap { comment in
                comment.currentUserVote.map { (comment.id, $0) }
            })
            if let groupID = post.communityID {
                do { communityName = try await appState.forumStore.communities().first { $0.id == groupID }?.name }
                catch { communityName = "Community unavailable" }
            }
            let authorIDs = Set(([post.authorID] + (thread?.comments.map(\.authorID) ?? [])))
            for authorID in authorIDs where authors[authorID] == nil {
                do {
                    let profile = try await appState.profileStore.publicProfile(userID: authorID)
                    guard appState.currentProfile.id == viewerID else { return }
                    authors[authorID] = profile
                } catch { /* The discussion remains readable with an unavailable-author label. */ }
            }
#if DEBUG
            if thread == nil, isDemoReadOnly { thread = ForumDemoContent.thread(for: post) }
#endif
        } catch let loadError {
#if DEBUG
            if isDemoReadOnly { thread = ForumDemoContent.thread(for: post) }
            else { error = loadError.localizedDescription }
#else
            error = loadError.localizedDescription
#endif
        }
    }

    private func toggleVote(_ direction: Int) async {
        guard !isUpdatingReaction, let current = thread?.post else { return }
        isUpdatingReaction = true
        defer { isUpdatingReaction = false }
        let viewerID = appState.currentProfile.id
        do {
            let updated = try await appState.forumStore.toggleVote(on: current, direction: direction)
            guard viewerID == appState.currentProfile.id else { return }
            thread?.post = updated
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func toggleCommentVote(_ comment: ForumComment) async {
        guard !isUpdatingReaction else { return }
        isUpdatingReaction = true
        defer { isUpdatingReaction = false }
        let previousValue = commentVoteValues[comment.id]
        let nextValue: Int? = previousValue == 1 ? nil : 1
        do {
            try await appState.forumStore.vote(commentID: comment.id, value: nextValue)
            if let nextValue { commentVoteValues[comment.id] = nextValue }
            else { commentVoteValues.removeValue(forKey: comment.id) }
            updateCommentVoteCount(comment, previousValue: previousValue, nextValue: nextValue)
        } catch let voteError { error = voteError.localizedDescription }
    }

    private func toggleCommentDownvote(_ comment: ForumComment) async {
        guard !isUpdatingReaction else { return }
        isUpdatingReaction = true
        defer { isUpdatingReaction = false }
        let previousValue = commentVoteValues[comment.id]
        let nextValue: Int? = previousValue == -1 ? nil : -1
        do {
            try await appState.forumStore.vote(commentID: comment.id, value: nextValue)
            if let nextValue { commentVoteValues[comment.id] = nextValue }
            else { commentVoteValues.removeValue(forKey: comment.id) }
            updateCommentVoteCount(comment, previousValue: previousValue, nextValue: nextValue)
        } catch let voteError { error = voteError.localizedDescription }
    }

    private func updateCommentVoteCount(_ comment: ForumComment, previousValue: Int?, nextValue: Int?) {
        guard let thread else { return }
        let oldContribution = previousValue ?? 0
        let newContribution = nextValue ?? 0
        let updatedComments = thread.comments.map { existing in
            guard existing.id == comment.id else { return existing }
            return ForumComment(
                id: existing.id,
                postID: existing.postID,
                authorID: existing.authorID,
                parentCommentID: existing.parentCommentID,
                body: existing.body,
                createdAt: existing.createdAt,
                voteCount: existing.voteCount + newContribution - oldContribution,
                currentUserVote: nextValue
            )
        }
        self.thread = ForumThread(post: thread.post, comments: updatedComments, isWatching: isWatching)
    }

    private func toggleWatch() async {
        guard !isUpdatingReaction else { return }
        isUpdatingReaction = true
        defer { isUpdatingReaction = false }
        let nextValue = !isWatching
        do {
            try await appState.forumStore.watch(postID: post.id, watched: nextValue)
            isWatching = nextValue
            error = nil
        } catch let watchError { error = watchError.localizedDescription }
    }

    private func blockAuthor(_ authorID: UUID) async {
        guard !isBlockingAuthor else { return }
        isBlockingAuthor = true
        defer { isBlockingAuthor = false; blockingAuthorID = nil }
        do {
            try await appState.accountSocialStore.setBlocked(authorID, blocked: true)
            error = nil
            if authorID == post.authorID {
                saveReplyDraft()
                dismiss()
            } else {
                feedback = "Author blocked."
            }
        } catch { self.error = appState.userMessage(error) }
    }

    private func report(reason: String) async {
        do {
            let targetType = reportTargetCommentID == nil ? "post" : "comment"
            let targetID = reportTargetCommentID ?? post.id
            try await appState.forumStore.report(targetType: targetType, targetID: targetID, communityID: post.communityID, reason: reason, note: "")
            error = nil
            feedback = "Report sent for moderator review."
            reportTargetCommentID = nil
        } catch let reportError { error = reportError.localizedDescription }
    }

    private func submitReply() async {
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draftOwnerID == appState.currentProfile.id, !isDemoReadOnly, !trimmedReply.isEmpty, trimmedReply.count <= 5000, !isSubmittingReply, thread?.post.isLocked != true else { return }
        isSubmittingReply = true
        defer { isSubmittingReply = false }

        do {
            _ = try await appState.forumStore.createComment(postID: post.id, body: trimmedReply, parentCommentID: replyingTo)
            reply = ""
            replyingTo = nil
            replyFocused = false
            saveReplyDraft()
            await load()
        } catch let submitError { error = submitError.localizedDescription }
    }

    private func beginEditingPost() {
        guard let current = thread?.post, current.authorID == appState.currentProfile.id else { return }
        error = nil
        editingCommentID = nil
        editTitle = current.title
        editBody = current.body
        originalEdit = [editTitle, editBody]
        showingEditSheet = true
    }

    private func beginEditingComment(_ comment: ForumComment) {
        guard comment.authorID == appState.currentProfile.id else { return }
        error = nil
        editingCommentID = comment.id
        editTitle = ""
        editBody = comment.body
        originalEdit = [editTitle, editBody]
        showingEditSheet = true
    }

    private func saveEdit() async {
        let body = editBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !editTooLong, !isSavingEdit else { return }
        isSavingEdit = true
        defer { isSavingEdit = false }
        do {
            if let editingCommentID {
                let updated = try await appState.forumStore.updateComment(commentID: editingCommentID, body: body)
                if let thread {
                    self.thread = ForumThread(post: thread.post, comments: thread.comments.map { $0.id == editingCommentID ? updated : $0 })
                }
            } else {
                let title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                let updated = try await appState.forumStore.updatePost(postID: post.id, title: title, body: body)
                if let thread { self.thread = ForumThread(post: updated, comments: thread.comments) }
            }
            showingEditSheet = false
        } catch let saveError {
            error = saveError.localizedDescription
        }
    }

    private func deletePost() async {
        do {
            try await appState.forumStore.deletePost(postID: post.id)
            onPostDeleted?()
            dismiss()
        } catch let deleteError { error = deleteError.localizedDescription }
    }

    private func deleteComment(commentID: UUID) async {
        do {
            try await appState.forumStore.deleteComment(commentID: commentID)
            self.deletingCommentID = nil
            await load()
        } catch let deleteError { error = deleteError.localizedDescription }
    }
}

private struct FriendTrainingActivityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activities: [FriendTrainingActivity] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var profileError: String?
    @State private var selectedProfile: UserProfile?

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Button("Friends and requests", systemImage: "person.2") {
                        appState.router.sheet = .friendRequests
                    }
                    .frame(minHeight: 44)
                    Button("Activity sharing settings", systemImage: "slider.horizontal.3") { appState.showingSettings = true }
                        .font(.subheadline).frame(minHeight: 44)
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(32)
                    } else if let loadError {
                        LiftEmptyState(title: "Friend activity unavailable", message: loadError,
                                       actionTitle: "Retry", action: { Task { await load() } })
                    } else if activities.isEmpty {
                        LiftEmptyState(title: "No friend activity yet",
                                       message: "When friends choose to share a workout start or new top lift, it appears here.")
                    } else {
                        if let profileError {
                            Text(profileError).font(.caption).foregroundStyle(Color.liftRed)
                        }
                        ForEach(activities) { activity in
                            Button {
                                Task { await openProfile(activity.ownerID) }
                            } label: {
                                LiftCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: activity.kind == .workoutStarted ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                                            .foregroundStyle(Color.liftAccentText)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(activity.displayName) \(activity.kind == .workoutStarted ? "started a workout" : "shared a new top lift")")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.liftText)
                                            if let lift = activity.lift {
                                                Text(lift.exerciseName)
                                                    .font(LiftTypography.cardTitle)
                                                    .foregroundStyle(Color.liftText)
                                                Text(MeasurementFormatting.recordedLiftSetText(
                                                    weight: MeasurementFormatting.displayWeight(lift.normalizedWeightKilograms, unit: appState.currentProfile.preferredUnit),
                                                    unit: appState.currentProfile.preferredUnit,
                                                    repetitions: lift.repetitions, includeRepLabel: true
                                                ))
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(Color.liftAccentText)
                                                .accessibilityIdentifier("feed.friendActivity.liftWeight")
                                                VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus, compact: true)
                                                if !lift.caption.isEmpty {
                                                    Text(lift.caption).font(.subheadline).foregroundStyle(Color.liftText)
                                                }
                                            } else if activity.kind == .workoutStarted {
                                                Text("Workout started · Session details are private")
                                                    .font(.subheadline).foregroundStyle(Color.liftMuted)
                                            }
                                            Text(activity.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this athlete's profile")
                        }
                    }
                }
                .padding(LiftDesign.screenHorizontalPadding)
                .padding(.bottom, 86)
            }
            .refreshable { await load() }
        }
        .task { await load() }
        .sheet(item: $selectedProfile) { profile in
            NavigationStack { ProfileView(profile: profile, surface: .public) }
                .environmentObject(appState)
        }
    }

    private func load() async {
        let viewerID = appState.currentProfile.id
        isLoading = true
        loadError = nil
        do {
            let loaded = try await appState.profileStore.friendTrainingActivity()
            guard appState.currentProfile.id == viewerID else { return }
            activities = loaded.filter { !appState.isBlocked($0.ownerID) }
        } catch {
            guard appState.currentProfile.id == viewerID else { return }
            loadError = appState.userMessage(error)
        }
        isLoading = false
    }

    private func openProfile(_ userID: UUID) async {
        let viewerID = appState.currentProfile.id
        profileError = nil
        do {
            let profile = try await appState.profileStore.publicProfile(userID: userID)
            guard appState.currentProfile.id == viewerID else { return }
            guard let profile else {
                profileError = "This athlete's profile is unavailable."
                return
            }
            selectedProfile = profile
        } catch {
            guard appState.currentProfile.id == viewerID else { return }
            profileError = appState.userMessage(error)
        }
    }
}
