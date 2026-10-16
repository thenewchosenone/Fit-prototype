import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

private func liftSymbol(for exerciseName: String) -> String {
    let normalized = exerciseName.lowercased()
    if normalized.contains("squat") { return "figure.strengthtraining.functional" }
    if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
    if normalized.contains("deadlift") { return "figure.strengthtraining.functional" }
    if normalized.contains("row") { return "figure.rower" }
    if normalized.contains("pulldown") || normalized.contains("pull-down") || normalized.contains("pullover") { return "figure.climbing" }
    if normalized.contains("curl") { return "figure.stand" }
    if normalized.contains("fly") || normalized.contains("rear delt") { return "figure.stand" }
    if normalized.contains("lateral raise") || normalized.contains("front raise") { return "figure.stand" }
    if normalized.contains("lunge") || normalized.contains("step-up") || normalized.contains("step up") { return "figure.walk" }
    if normalized.contains("calf raise") { return normalized.contains("seated") ? "figure.seated.side" : "figure.stand" }
    if normalized.contains("leg press") { return "figure.seated.side" }
    if normalized.contains("hip thrust") || normalized.contains("glute bridge") { return "figure.strengthtraining.functional" }
    if normalized.contains("shrug") { return "figure.stand" }
    if normalized.contains("overhead press") || normalized.contains("shoulder press") || normalized.contains("push press") || normalized.contains("arnold press") || normalized.contains("military press") {
        return "figure.stand"
    }
    if normalized.contains("push-up") || normalized.contains("push up") || normalized.contains("dip") {
        return "figure.strengthtraining.functional"
    }
    if normalized.contains("press") { return "figure.strengthtraining.traditional" }
    return "chart.line.uptrend.xyaxis"
}

private enum MeRoute: Hashable {
    case publicProfile
    case personalProfile
    case awards
    case gyms
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var router: AppRouter
    @State private var mePath: [MeRoute] = []
    @State private var showsMeTabBar = true

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .ignoresSafeArea(.keyboard)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsFloatingTabBar {
                        FloatingTabBar(
                            selection: $router.selectedTab,
                            items: tabItems
                        )
                        .padding(.bottom, 18)
                        .background(
                            Color.liftBackground
                                .ignoresSafeArea(edges: .bottom)
                                .allowsHitTesting(false)
                        )
                    }
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .tint(Color.liftAccentText)
        .onChange(of: mePath) { _, path in
            if path.isEmpty {
                showsMeTabBar = true
            } else {
                showsMeTabBar = false
            }
        }
        .sheet(item: $router.sheet) { destination in
            appSheet(destination)
        }
        .fullScreenCover(item: $router.cover) { destination in
            switch destination {
            case .authentication:
                AuthenticationView().environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch router.selectedTab {
        case .home:
            NavigationStack { HomeView() }
        case .leaderboards:
            NavigationStack { LeaderboardsView() }
        case .track:
            TrainingTrackerView(
                startOnProgress: appState.trainingTrackerStartOnProgress,
                isEmbeddedInTab: true
            )
        case .profile:
            NavigationStack(path: $mePath) {
                meTabContent
            }
        case .forum:
            NavigationStack { ForumView().environmentObject(appState) }
        }
    }

    @ViewBuilder
    private var meTabContent: some View {
        Group {
            if router.selectedTab == .profile {
                MeHubContentView()
            } else {
                AppBackground {
                    Color.clear
                }
            }
        }
        .navigationDestination(for: MeRoute.self) { route in
            switch route {
            case .publicProfile:
                ProfileView(profile: appState.currentProfile, surface: .public, viewerID: UUID())
            case .personalProfile:
                ProfileView(profile: appState.currentProfile, surface: .personal)
            case .awards:
                AwardsView()
            case .gyms:
                GymDirectoryView()
            }
        }
    }

    private var showsFloatingTabBar: Bool {
        router.selectedTab != .profile || showsMeTabBar
    }

    private var tabItems: [FloatingTabItem] {
        var items: [FloatingTabItem] = [
            .init(tab: .home, icon: "house.fill", title: "Home"),
            .init(tab: .leaderboards, icon: "trophy.fill", title: "Rankings"),
            .init(tab: .track, icon: "dumbbell.fill", title: "Track"),
        ]

        items.append(.init(tab: .profile, icon: "person.crop.circle.fill", title: "Me"))
        if appState.features.forum {
            items.insert(.init(tab: .forum, icon: "bubble.left.and.bubble.right.fill", title: "Forum"), at: items.count - 1)
        }

        return items
    }

    @ViewBuilder
    private func appSheet(_ destination: AppSheet) -> some View {
        switch destination {
        case .submitLift:
            SubmitLiftView().environmentObject(appState).presentationDetents([.large])
        case .leaderboardFilters:
            LeaderboardFiltersView().environmentObject(appState).presentationDetents([.large])
        case .editProfile:
            EditProfileView().environmentObject(appState).presentationDetents([.large])
        case .moderatorReview:
            ModeratorReviewView().environmentObject(appState)
        case .settings(let section):
            SettingsView(initialSection: section).environmentObject(appState)
        case .requestGym:
            RequestGymView().environmentObject(appState).presentationDetents([.medium])
        case .recentPR(let lift):
            RecentPRDetailView(lift: lift)
                .environmentObject(appState)
                .presentationDetents([.large])
        case .reportLift(let lift):
            ReportLiftView(lift: lift).environmentObject(appState).presentationDetents([.medium])
        case .reportProfile(let profile):
            ReportProfileView(profile: profile).environmentObject(appState).presentationDetents([.medium])
        case .profile(let profile):
            NavigationStack {
                ProfileView(profile: profile, isCurrentUser: profile.id == appState.currentProfile.id)
            }
            .environmentObject(appState)
        case .gym(let gym):
            NavigationStack { GymDetailView(gym: gym) }.environmentObject(appState)
        }
    }
}

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
    case forYou = "For You"
    case following = "Following"

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

private struct ForumView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var groups: [ForumCommunity] = []
    @State private var posts: [ForumPost] = []
    @State private var selectedGroupID: UUID?
    @State private var joinedGroupIDs: Set<UUID> = []
    @State private var membershipStatuses: [UUID: String] = [:]
    @State private var showingComposer = false
    @State private var showingFeedFilters = false
    @State private var draftSelectedGroupID: UUID?
    @State private var draftSort: ForumSort = .top
    @State private var sort: ForumSort = .top
    @State private var feed: ForumFeed = .all
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePosts = false
    @State private var remotePostOffset = 0
    @State private var message: String?
    @State private var requestedPost: ForumPost?
    @State private var requestedCommentID: UUID?
    @State private var showingCommunityDirectory = false

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    forumHeader
                    forumFeedPicker
                    if isLoading { ProgressView().frame(maxWidth: .infinity).padding(40) }
                    else if let message { LiftEmptyState(title: "Forum unavailable", message: message) }
                    else if feedPosts.isEmpty {
                        LiftEmptyState(
                            title: emptyFeedTitle,
                            message: emptyFeedMessage
                        )
                    }
                    else {
                        ForEach(sortedPosts) { post in
                            ForumPostCard(post: post, community: groups.first { $0.id == post.communityID }).environmentObject(appState)
                        }
                        if hasMorePosts {
                            Button {
                                Task { await loadMorePosts() }
                            } label: {
                                if isLoadingMore {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Text("Load more discussions")
                                        .font(.subheadline.weight(.bold))
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
                .padding(.bottom, 86)
            }
        }
        .navigationTitle(selectedGroup?.name ?? "Forum")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search discussions and communities")
        .sheet(isPresented: $showingComposer) { ForumComposerView(groups: groups, selectedGroupID: selectedGroupID) { await loadPosts() }.environmentObject(appState) }
        .sheet(isPresented: $showingFeedFilters) { forumFilterSheet }
        .sheet(isPresented: $showingCommunityDirectory) {
                ForumCommunityDirectoryView(
                    groups: groups,
                    joinedGroupIDs: $joinedGroupIDs,
                    membershipStatuses: $membershipStatuses,
                    selectedGroupID: $selectedGroupID,
                onMembershipChanged: { group in await toggleMembership(group) },
                onCommunitySelected: {
                    showingCommunityDirectory = false
                    Task { await loadPosts() }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingCommunityDirectory = true } label: { Image(systemName: "square.grid.2x2") }
                    .accessibilityLabel("Browse communities")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New discussion")
            }
        }
        .sheet(item: $requestedPost, onDismiss: { Task { await loadPosts() } }) { post in
            NavigationStack {
                ForumThreadView(post: post, highlightedCommentID: requestedCommentID)
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
                Button(joinedGroupIDs.contains(selectedGroup.id) ? "Joined" : "Join") {
                    Task { await toggleMembership(selectedGroup) }
                }
                .frame(minHeight: LiftDesign.minimumTouchTarget)
            }
        }
        .padding(.horizontal, 16)
    }

    private var forumFeedPicker: some View {
        HStack(spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                Picker("Feed", selection: $feed) {
                    ForEach(ForumFeed.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.liftAccentText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("forum.feed")
            } else {
            HStack(spacing: 4) {
                ForEach(ForumFeed.allCases) { option in
                    Button(option.rawValue) { feed = option }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(feed == option ? Color.liftOnAccent : Color.liftMuted)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(feed == option ? Color.liftLime : Color.clear, in: Capsule())
                }
            }
            .padding(4)
            .background(Color.liftSurfaceElevated, in: Capsule())
            }

            Button {
                draftSelectedGroupID = selectedGroupID
                draftSort = sort
                showingFeedFilters = true
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "slider.horizontal.3")
                    } else {
                        Label(activeForumFilterCount == 0 ? "Filters" : "Filters · \(activeForumFilterCount)", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(Color.liftAccentText)
                .padding(.horizontal, 12)
                .frame(minHeight: LiftDesign.minimumTouchTarget)
                .background(Color.liftSurfaceElevated, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Forum filters. Community: \(selectedGroup?.name ?? "All communities"). Sort: \(sort.title)")
            .accessibilityIdentifier("forum.filters")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.liftBackground)
    }

    private var forumFilterSheet: some View {
        NavigationStack {
            Form {
                Section("Community") {
                    Picker("Community", selection: $draftSelectedGroupID) {
                        Text("All communities").tag(nil as UUID?)
                        ForEach(groups) { group in Text(group.name).tag(Optional(group.id)) }
                    }
                    .accessibilityIdentifier("forum.community")
                }

                Section("Sort discussions") {
                    Picker("Sort", selection: $draftSort) {
                        ForEach(ForumSort.allCases) { option in Text(option.title).tag(option) }
                    }
                    .accessibilityIdentifier("forum.sort")
                }
            }
            .navigationTitle("Forum filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        draftSelectedGroupID = nil
                        draftSort = .top
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let communityChanged = selectedGroupID != draftSelectedGroupID
                        selectedGroupID = draftSelectedGroupID
                        sort = draftSort
                        showingFeedFilters = false
                        if communityChanged { Task { await loadPosts() } }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var selectedGroup: ForumCommunity? { groups.first { $0.id == selectedGroupID } }
    private var activeForumFilterCount: Int { (selectedGroupID == nil ? 0 : 1) + (sort == .top ? 0 : 1) }

    private var emptyFeedTitle: String {
        switch feed {
        case .all: return "No discussions yet"
        case .forYou: return "Your feed is empty"
        case .following: return "No followed communities yet"
        }
    }

    private var emptyFeedMessage: String {
        switch feed {
        case .all:
            return "Start a discussion in this community."
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
        switch feed {
        case .all:
            return posts
        case .forYou:
            return posts.filter { post in
                guard let communityID = post.communityID else { return false }
                return joinedGroupIDs.contains(communityID) || post.isPinned
            }
        case .following:
            return posts.filter { post in
                guard let communityID = post.communityID else { return false }
                return joinedGroupIDs.contains(communityID)
            }
        }
    }

    private func load() async {
        do {
            groups = try await appState.forumStore.communities()
            if let statuses = try? await appState.forumStore.communityMembershipStatuses() {
                membershipStatuses = statuses
            }
            if let memberships = try? await appState.forumStore.joinedCommunityIDs() {
                joinedGroupIDs = Set(memberships)
            }
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
            posts = remotePosts + ForumDemoContent.posts(for: groups, communityID: selectedGroupID)
#else
            posts = remotePosts
#endif
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
            posts.append(contentsOf: remotePosts)
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
                        directoryIntro
                        ForEach(groups) { group in
                            communityRow(group)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var directoryIntro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find training communities")
                .font(.title3.weight(.black))
            Text("Find communities that match your training goals. Join one to see its discussions in Following.")
                .font(.subheadline)
                .foregroundStyle(Color.liftTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liftSurface(radius: 16)
    }

    private func communityRow(_ group: ForumCommunity) -> some View {
        let isJoined = joinedGroupIDs.contains(group.id)
        let membershipStatus = membershipStatuses[group.id]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.liftLime.opacity(0.18))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(Color.liftAccentText)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.headline.weight(.bold))
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

            if !group.details.isEmpty {
                Text(group.details)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Button {
                    selectedGroupID = group.id
                    onCommunitySelected()
                } label: {
                    Text("View discussions")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())

                Button {
                    Task { await onMembershipChanged(group) }
                } label: {
                    Text(isJoined ? (membershipStatus == "Muted" ? "Muted" : "Joined") : (membershipStatus == "Pending" ? "Pending" : "Join"))
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 70, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .tint(isJoined ? Color.liftMuted : Color.liftAccentText)
                .disabled(membershipStatus == "Pending")
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
    let selectedGroupID: UUID?
    let didPublish: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var groupID: UUID?
    @State private var title = ""
    @State private var draftBody = ""
    @State private var error: String?
    @State private var isPublishing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Community") {
                    Picker("Community", selection: $groupID) {
                        Text("Choose a community").tag(UUID?.none)
                        ForEach(groups) { group in Text(group.name).tag(Optional(group.id)) }
                    }
                }
                Section("Discussion") {
                    TextField("Title", text: $title)
                    TextField("Share the training context", text: $draftBody, axis: .vertical)
                        .lineLimit(5...12)
                        .accessibilityIdentifier("forum.composer.body")
                }
                if let error { Text(error).foregroundStyle(Color.liftRed) }
            }
            .navigationTitle("New discussion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await publish() } } label: {
                        if isPublishing { ProgressView() } else { Text("Publish") }
                    }
                    .disabled(isPublishing || groupID == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { groupID = selectedGroupID ?? groups.first?.id }
        }
    }

    private func publish() async {
        guard let groupID else { return }
        guard !isPublishing else { return }
        isPublishing = true
        defer { isPublishing = false }
        do {
            _ = try await appState.forumStore.createPost(ForumPostDraft(communityID: groupID, kind: "Discussion", title: title, body: draftBody, tag: nil, liftID: nil))
            await didPublish()
            dismiss()
        } catch let publishError { error = publishError.localizedDescription }
    }
}

private struct ForumPostCard: View {
    @EnvironmentObject private var appState: AppState
    let post: ForumPost
    let community: ForumCommunity?

    var body: some View {
        NavigationLink {
            ForumThreadView(post: post, highlightedCommentID: nil).environmentObject(appState)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    forumAvatar
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftTextSecondary)
                        HStack(spacing: 5) {
                            Text(LiftTimeFormatter.relativeNoSeconds(from: post.createdAt))
                            Text("•")
                            Text(community?.name ?? "Community")
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                }
                if post.isPinned || post.isLocked || !post.kind.isEmpty {
                    HStack(spacing: 7) {
                        if !post.kind.isEmpty { forumBadge(post.kind, icon: post.kind == "Question" ? "questionmark.circle" : "text.bubble") }
                        if post.isPinned { forumBadge("Pinned", icon: "pin.fill") }
                        if post.isLocked { forumBadge("Locked", icon: "lock.fill") }
                    }
                }
                Text(post.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(post.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftTextSecondary)
                    .lineLimit(2)
                if let tag = post.tag, tag != "demo" {
                    Text(tag.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.liftSurfaceSecondary, in: Capsule())
                }
                HStack(spacing: 9) {
                    forumMetric(
                        icon: post.currentUserVote == 1 ? "arrow.up.circle.fill" : "arrow.up",
                        label: String(post.voteCount) + " votes"
                    )
                    forumMetric(icon: "bubble.left.and.bubble.right", label: String(post.commentCount) + " replies")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.liftBackground)
        }
        .buttonStyle(.plain)
    }

    private var forumAvatar: some View {
        ZStack {
            Circle().fill(Color.liftLime.opacity(0.9))
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftOnAccent)
        }
        .frame(width: 38, height: 38)
    }

    private var authorLabel: String {
        if post.tag == "demo" { return "lift_rank_member" }
        if post.authorID == appState.currentProfile.id {
            return appState.currentProfile.username.isEmpty ? "You" : "@\(appState.currentProfile.username)"
        }
        if let profile = appState.profileStore.profile(id: post.authorID) {
            if !profile.username.isEmpty { return "@\(profile.username)" }
            if !profile.displayName.isEmpty { return profile.displayName }
        }
        return "community member"
    }

    private func forumMetric(icon: String, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.liftMuted)
            .accessibilityElement(children: .combine)
    }

    private func forumBadge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liftAccentText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.liftLime.opacity(0.12), in: Capsule())
    }
}

private struct ForumThreadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let post: ForumPost
    let highlightedCommentID: UUID?
    @State private var thread: ForumThread?
    @State private var reply = ""
    @State private var replyingTo: UUID?
    @State private var error: String?
    @State private var isWatching = false
    @State private var voteValue: Int?
    @State private var commentVoteValues: [UUID: Int] = [:]
    @State private var collapsedCommentIDs: Set<UUID> = []
    @State private var commentSort: ForumCommentSort = .best
    @State private var showingReportReasons = false
    @State private var reportTargetCommentID: UUID?
    @State private var isSubmittingReply = false
    @State private var showingEditSheet = false
    @State private var showingDeletePostConfirmation = false
    @State private var deletingCommentID: UUID?
    @State private var editingCommentID: UUID?
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var isSavingEdit = false

    private var isDemoReadOnly: Bool { post.tag == "demo" }

    var body: some View {
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
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(Color.liftMuted)
                                                .accessibilityLabel("Discussion actions")
                                                .accessibilityIdentifier("forum.discussion.actions")
                                    }
                                }
                            }
                            Text(thread.post.title)
                                .font(.title2.weight(.black))
                            Text(thread.post.body)
                                .font(.body)
                                .foregroundStyle(Color.liftTextSecondary)
                            HStack(spacing: 9) {
                                Button { Task { await toggleVote() } } label: {
                                    threadAction(icon: voteValue == 1 ? "arrow.up.circle.fill" : "arrow.up", label: "\(thread.post.voteCount)")
                                }
                                .buttonStyle(.plain)
                                .disabled(isDemoReadOnly)
                                Button { Task { await toggleDownvote() } } label: {
                                    threadAction(icon: voteValue == -1 ? "arrow.down.circle.fill" : "arrow.down", label: "")
                                }
                                .buttonStyle(.plain)
                                .disabled(isDemoReadOnly)
                                threadAction(icon: "bubble.left", label: "\(thread.comments.count)")
                                Spacer()
                                ShareLink(
                                    item: "\(thread.post.title)\n\n\(thread.post.body)",
                                    subject: Text(thread.post.title),
                                    message: Text("Share this Lift Rivals discussion")
                                ) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .accessibilityLabel("Share discussion")
                                Button { Task { await toggleWatch() } } label: {
                                    Image(systemName: isWatching ? "bell.fill" : "bell")
                                }
                                .foregroundStyle(Color.liftMuted)
                                .disabled(isDemoReadOnly)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liftBackground)

                        HStack {
                            Text("\(thread.comments.count) comments")
                                .font(.headline.weight(.bold))
                            Spacer()
                            Menu {
                                ForEach(ForumCommentSort.allCases) { option in
                                    Button { commentSort = option } label: {
                                        Label(option.title, systemImage: option.icon)
                                    }
                                }
                            } label: {
                                Label(commentSort.title, systemImage: commentSort.icon)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftAccentText)
                            }
                            .accessibilityLabel("Comment sort")
                        }
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
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(40)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(Color.liftRed) }
                }
                    .padding(16)
                    .padding(.bottom, 78)
                }
                .onChange(of: thread?.comments.count) { _, _ in
                    scrollToHighlightedComment(using: proxy)
                }
                .task {
                    scrollToHighlightedComment(using: proxy)
                }
            }
        }
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(reportDialogTitle, isPresented: $showingReportReasons, titleVisibility: .visible) {
            Button("Spam or promotion", role: .destructive) { Task { await report(reason: "spam") } }
            Button("Harassment or abuse", role: .destructive) { Task { await report(reason: "harassment") } }
            Button("Off-topic or misleading", role: .destructive) { Task { await report(reason: "off_topic") } }
            Button("Cancel", role: .cancel) { reportTargetCommentID = nil }
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
                    if let error { Text(error).foregroundStyle(Color.liftRed) }
                }
                .navigationTitle(editingCommentID == nil ? "Edit discussion" : "Edit comment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await saveEdit() } }
                            .disabled(isSavingEdit || editBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (editingCommentID == nil && editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
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
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField(replyingTo == nil ? "Write a comment…" : "Write a reply…", text: $reply, axis: .vertical)
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
                        .disabled(isSubmittingReply || reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(Color.liftAccentText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.liftBackground)
            }
        }
        .task { await load() }
    }

    private func scrollToHighlightedComment(using proxy: ScrollViewProxy) {
        guard let highlightedCommentID,
              thread?.comments.contains(where: { $0.id == highlightedCommentID }) == true else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(highlightedCommentID, anchor: .center) }
        }
    }

    private var reportDialogTitle: String {
        let target = reportTargetCommentID == nil ? "discussion" : "comment"
        return "Why are you reporting this \(target)?"
    }

    private var forumAvatar: some View {
        ZStack {
            Circle().fill(Color.liftLime.opacity(0.9))
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftOnAccent)
        }
        .frame(width: 38, height: 38)
    }

    private func authorDisplayName(for authorID: UUID, isDemo: Bool) -> String {
        if isDemo { return "lift_rank_member" }
        if authorID == appState.currentProfile.id {
            return appState.currentProfile.username.isEmpty ? "You" : "@\(appState.currentProfile.username)"
        }
        if let profile = appState.profileStore.profile(id: authorID) {
            if !profile.username.isEmpty { return "@\(profile.username)" }
            if !profile.displayName.isEmpty { return profile.displayName }
        }
        return "community member"
    }

    private func threadAction(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.subheadline.weight(.semibold))
            if !label.isEmpty { Text(label).font(.caption.weight(.bold)) }
        }
        .foregroundStyle(Color.liftMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.liftSurfaceSecondary.opacity(0.7), in: Capsule())
    }

    private func forumComment(_ comment: ForumComment, depth: Int, hasReplies: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            forumAvatar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(authorDisplayName(for: comment.authorID, isDemo: isDemoReadOnly))
                        .font(.caption.weight(.bold))
                    Text("•")
                                    Text(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                Text(comment.body)
                    .font(.body)
                HStack(spacing: 12) {
                    Button("Reply", systemImage: "arrowshape.turn.up.left") { replyingTo = comment.id }
                        .disabled(isDemoReadOnly)
                    Button { Task { await toggleCommentVote(comment) } } label: {
                        Label("\(comment.voteCount)", systemImage: commentVoteValues[comment.id] == 1 ? "arrow.up.circle.fill" : "arrow.up")
                    }
                    .accessibilityLabel("Upvote comment, \(comment.voteCount) votes")
                    .disabled(isDemoReadOnly)
                    Button { Task { await toggleCommentDownvote(comment) } } label: {
                        Image(systemName: commentVoteValues[comment.id] == -1 ? "arrow.down.circle.fill" : "arrow.down")
                    }
                    .accessibilityLabel("Downvote comment")
                    .disabled(isDemoReadOnly)
                    Spacer(minLength: 0)
                    Menu {
                        if hasReplies {
                            Button(collapsedCommentIDs.contains(comment.id) ? "Expand replies" : "Collapse replies",
                                   systemImage: collapsedCommentIDs.contains(comment.id) ? "chevron.right" : "chevron.down") {
                                if collapsedCommentIDs.contains(comment.id) { collapsedCommentIDs.remove(comment.id) }
                                else { collapsedCommentIDs.insert(comment.id) }
                            }
                        }
                        if comment.authorID == appState.currentProfile.id && !isDemoReadOnly {
                            Button("Edit comment", systemImage: "pencil") { beginEditingComment(comment) }
                            Button("Delete comment", systemImage: "trash", role: .destructive) { deletingCommentID = comment.id }
                                .accessibilityIdentifier("forum.comment.delete")
                        }
                        Button("Report", systemImage: "flag") {
                            reportTargetCommentID = comment.id
                            showingReportReasons = true
                        }
                        .disabled(isDemoReadOnly)
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
        .padding(.leading, CGFloat(min(depth, 3) * 12 + 16))
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.liftSurfaceBorder)
                .frame(width: 2)
                .padding(.leading, 16)
        }
    }

    private func displayComments(from comments: [ForumComment]) -> [(comment: ForumComment, depth: Int)] {
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

    private func load() async {
        do {
            thread = try await appState.forumStore.thread(postID: post.id)
            voteValue = thread?.post.currentUserVote
            commentVoteValues = Dictionary(uniqueKeysWithValues: (thread?.comments ?? []).compactMap { comment in
                comment.currentUserVote.map { (comment.id, $0) }
            })
#if DEBUG
            if thread == nil, post.tag == "demo" { thread = ForumDemoContent.thread(for: post) }
#endif
        } catch let loadError {
#if DEBUG
            if post.tag == "demo" { thread = ForumDemoContent.thread(for: post) }
            else { error = loadError.localizedDescription }
#else
            error = loadError.localizedDescription
#endif
        }
    }

    private func toggleVote() async {
        let nextValue: Int? = voteValue == 1 ? nil : 1
        do {
            try await appState.forumStore.vote(postID: post.id, value: nextValue)
            voteValue = nextValue
        } catch let voteError { error = voteError.localizedDescription }
    }

    private func toggleDownvote() async {
        let nextValue: Int? = voteValue == -1 ? nil : -1
        do {
            try await appState.forumStore.vote(postID: post.id, value: nextValue)
            voteValue = nextValue
        } catch let voteError { error = voteError.localizedDescription }
    }

    private func toggleCommentVote(_ comment: ForumComment) async {
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
        guard var thread else { return }
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
                voteCount: max(0, existing.voteCount + newContribution - oldContribution),
                currentUserVote: nextValue
            )
        }
        thread = ForumThread(post: thread.post, comments: updatedComments)
    }

    private func toggleWatch() async {
        let nextValue = !isWatching
        do {
            try await appState.forumStore.watch(postID: post.id, watched: nextValue)
            isWatching = nextValue
        } catch let watchError { error = watchError.localizedDescription }
    }

    private func report(reason: String) async {
        do {
            let targetType = reportTargetCommentID == nil ? "post" : "comment"
            let targetID = reportTargetCommentID ?? post.id
            try await appState.forumStore.report(targetType: targetType, targetID: targetID, communityID: post.communityID, reason: reason, note: "")
            error = "Thanks. This \(targetType) was reported for moderator review."
            reportTargetCommentID = nil
        } catch let reportError { error = reportError.localizedDescription }
    }

    private func submitReply() async {
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReply.isEmpty, !isSubmittingReply, thread?.post.isLocked != true else { return }
        isSubmittingReply = true
        defer { isSubmittingReply = false }
#if DEBUG
        if post.tag == "demo", var thread {
            let comment = ForumComment(id: UUID(), postID: post.id, authorID: appState.currentProfile.id, parentCommentID: replyingTo, body: trimmedReply, createdAt: Date())
            thread = ForumThread(post: thread.post, comments: thread.comments + [comment])
            self.thread = thread
            reply = ""
            replyingTo = nil
            return
        }
#endif
        do {
            _ = try await appState.forumStore.createComment(postID: post.id, body: trimmedReply, parentCommentID: replyingTo)
            reply = ""
            replyingTo = nil
            await load()
        } catch let submitError { error = submitError.localizedDescription }
    }

    private func beginEditingPost() {
        guard let current = thread?.post, current.authorID == appState.currentProfile.id else { return }
        error = nil
        editingCommentID = nil
        editTitle = current.title
        editBody = current.body
        showingEditSheet = true
    }

    private func beginEditingComment(_ comment: ForumComment) {
        guard comment.authorID == appState.currentProfile.id else { return }
        error = nil
        editingCommentID = comment.id
        editTitle = ""
        editBody = comment.body
        showingEditSheet = true
    }

    private func saveEdit() async {
        let body = editBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSavingEdit else { return }
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

private struct MeHubContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsTrainingDetails = false
    @State private var selectedTopLiftCard: TopLiftCardDestination?

    var body: some View {
        AppBackground {
            ScrollView {
                let profile = appState.currentProfile
                let preferredUnit = profile.preferredUnit
                let tierSummary = appState.strengthTierSummary
                let trainingStats = appState.competitiveStatistics
                let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your profile" : profile.displayName
                let handle = profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add a username in Edit Profile" : "@\(profile.username)"

                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                         : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                            ProfileAvatar(profile: profile, size: 66)
                                .accessibilityIdentifier("me.profileHeader")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.title3.weight(.black))
                                Text(handle)
                                    .font(.caption)
                                    .foregroundStyle(profile.username.isEmpty ? Color.liftAccentText : Color.liftMuted)
                                Text("Tier \(tierSummary.overallTier.label)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGold)
                            }

                            .frame(maxWidth: .infinity, alignment: .leading)

                            (dynamicTypeSize.isAccessibilitySize
                             ? AnyLayout(HStackLayout(spacing: 8))
                             : AnyLayout(VStackLayout(spacing: 8))) {
                                compactHeaderIconButton("gearshape.fill", "Open settings", accessibilityIdentifier: "me.header.settings") {
                                    appState.showingSettings = true
                                }

                                compactHeaderIconButton("pencil", "Edit athlete profile", accessibilityIdentifier: "me.header.editProfile") {
                                    appState.showingEditProfile = true
                                }
                            }
                        }

                        if let bio = profile.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bio).font(.subheadline).lineLimit(3)
                        }

                        NavigationLink(value: MeRoute.publicProfile) {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                Text("View public profile")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftSurfaceElevated.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftAccentText)
                        .accessibilityIdentifier("me.publicProfile")

                        HStack(spacing: 0) {
                            meHeaderStat("Workouts", trainingStats.totalWorkouts.formatted())
                            Divider().frame(height: 28).overlay(Color.liftSeparator)
                            meHeaderStat("PRs", trainingStats.prCount.formatted())
                            Divider().frame(height: 28).overlay(Color.liftSeparator)
                            meHeaderStat("Streak", "\(trainingStats.currentStreak)w")
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liftSurface(radius: 12)

                    DisclosureGroup(isExpanded: $showsTrainingDetails) {
                    if showsTrainingDetails {
                    let bestStrengthLifts = appState.bestStrengthLifts
                    let hasLoggedTopLifts = bestStrengthLifts["bench"] != nil || bestStrengthLifts["squat"] != nil || bestStrengthLifts["deadlift"] != nil
                    CompactSectionHeader(title: "Top submitted lifts")
                        .accessibilityIdentifier("me.section.topLifts")
                    if hasLoggedTopLifts {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            topLiftCardButton("Bench", exerciseID: "bench", lift: bestStrengthLifts["bench"], preferredUnit: preferredUnit)
                            topLiftCardButton("Squat", exerciseID: "squat", lift: bestStrengthLifts["squat"], preferredUnit: preferredUnit)
                            topLiftCardButton("Deadlift", exerciseID: "deadlift", lift: bestStrengthLifts["deadlift"], preferredUnit: preferredUnit)
                            let breakdown = RankingCalculator.powerliftingBreakdown(for: profile.id, lifts: appState.currentUserLifts)
                            Button {
                                selectedTopLiftCard = .totalStrength(breakdown)
                            } label: {
                                topLiftCard("Total strength", value: breakdown.totalKilograms, preferredUnit: preferredUnit, suffix: "total", compact: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View total strength breakdown")
                            .accessibilityHint("Shows the submitted one-rep-max lifts included in your total")
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                appState.showingSubmitSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Submit a new lift")
                                        .font(.subheadline.weight(.bold))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.bold))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.liftBlue.opacity(0.15))
                                .foregroundStyle(Color.liftAccentText)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                                topLiftCardButton("Bench", exerciseID: "bench", lift: nil, preferredUnit: preferredUnit)
                                topLiftCardButton("Squat", exerciseID: "squat", lift: nil, preferredUnit: preferredUnit)
                                topLiftCardButton("Deadlift", exerciseID: "deadlift", lift: nil, preferredUnit: preferredUnit)
                            }
                        }
                    }

                    }
                    }
                    label: {
                        Text("Submitted lift records")
                            .accessibilityIdentifier("me.trainingDetails")
                    }
                    .tint(Color.liftAccentText)

                    CompactSectionHeader(title: "Activity & connections")
                        .accessibilityIdentifier("me.section.awardsHistory")
                    VStack(spacing: 0) {
                        NavigationLink(value: MeRoute.awards) {
                            meRow("Rival tier & awards", "Strength milestones, records, and progress", "trophy.fill", Color.liftGold, badge: tierSummary.overallTier.label)
                        }
                        .accessibilityIdentifier("me.awards")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.personalProfile) {
                            meRow("Submitted lift activity", "Your athlete profile and shared lifts", "chart.xyaxis.line", Color.liftGreen)
                        }
                        .accessibilityIdentifier("me.personalProfile")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        Button {
                            appState.router.progressCategory = appState.currentProfile.trainingFocus?.startingCategory ?? .consistency
                            appState.trainingTrackerStartOnProgress = true
                            appState.requestedTrackerSegment = "Progress"
                            appState.selectedTab = 2
                        } label: {
                            meRow("Training progress", "Workouts, strength, and muscle workload", "chart.line.uptrend.xyaxis", Color.liftBlue)
                        }
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.gyms) {
                            meRow(
                                "Find a gym",
                                appState.gyms.isEmpty
                                    ? "Browse locations and choose your primary gym"
                                    : "Browse locations and manage your primary gym",
                                "building.2.fill",
                                Color.liftBlue,
                                badge: appState.currentProfile.primaryGymName.isEmpty
                                    ? nil
                                    : appState.currentProfile.primaryGymName
                            )
                        }
                        .accessibilityIdentifier("me.gyms")
                    }
                    .buttonStyle(.plain)
                    .liftSurface()

                }
                .padding(14)
                .padding(.bottom, LiftDesign.floatingTabBarContentClearance)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await appState.refreshProductionLifts(force: true)
            }
        }
        .navigationTitle("Me")
        .task {
            await appState.refreshProductionLifts()
        }
        .sheet(item: $selectedTopLiftCard) { destination in
            TopLiftCardDetailSheet(destination: destination)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private func topLiftCardButton(
        _ title: String,
        exerciseID: String,
        lift: LiftSubmission?,
        preferredUnit: UnitSystem
    ) -> some View {
        Button {
            selectedTopLiftCard = lift.map(TopLiftCardDestination.submitted)
                ?? .exerciseHistory(id: exerciseID, name: title)
        } label: {
            topLiftCard(title, lift: lift, preferredUnit: preferredUnit, suffix: "", compact: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lift == nil ? "View past \(title.lowercased()) workout lifts" : "View submitted \(title.lowercased()) lift")
        .accessibilityHint(lift == nil ? "Shows matching workout sets and lets you submit one" : "Shows details for this submitted lift")
    }

    private func topLiftCard(
        _ title: String,
        lift: LiftSubmission?,
        preferredUnit: UnitSystem,
        suffix: String,
        showHelp: Bool = false,
        compact: Bool = false
    ) -> some View {
        topLiftCard(
            title,
            value: lift?.normalizedWeightKilograms,
            preferredUnit: preferredUnit,
            suffix: suffix,
            showHelp: showHelp || lift == nil,
            compact: compact
        )
    }

    private func compactHeaderIconButton(
        _ systemImage: String,
        _ accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.liftCard)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.liftSurfaceBorder, lineWidth: 1))
                .frame(width: LiftDesign.minimumTouchTarget, height: LiftDesign.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func meHeaderStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.black))
            Text(title)
                .font(.caption2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func topLiftCard(_ title: String, value: Double?, preferredUnit: UnitSystem, suffix: String, showHelp: Bool = false, compact: Bool = false) -> some View {
        let minHeight: CGFloat = compact ? 86 : 112
        let verticalPadding: CGFloat = compact ? 9 : 14
        let horizontalPadding: CGFloat = compact ? 10 : 14
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
            Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(
                value.map { "\(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))\(suffix.isEmpty ? "" : " \(suffix)")" } ?? "—"
            )
                .font(.subheadline.weight(.black))
            Text(showHelp ? "No lift submission yet" : "Best submitted lift")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .liftSurface(radius: 12)
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, badge: String? = nil) -> some View {
        meRow(title, subtitle, symbol, tint, badge: badge, isDestructive: false)
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, badge: String? = nil, isDestructive: Bool = false) -> some View {
        let iconColor = isDestructive ? Color.liftRed : tint
        let textColor = isDestructive ? Color.liftRed : Color.liftText
        let chevronColor = isDestructive ? Color.liftRed : Color.liftMuted
        return HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(textColor)
                Text(subtitle).font(.caption).foregroundStyle(Color.liftMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if dynamicTypeSize.isAccessibilitySize, let badge {
                    Text(badge).font(.caption.weight(.black)).foregroundStyle(Color.liftGold)
                }
            }
            Spacer(minLength: 8)
            if let badge, !dynamicTypeSize.isAccessibilitySize {
                Text(badge)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.liftGold)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(chevronColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

struct AwardsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rivalTierShareImage: Image?
    @State private var showsAllUnlockedAwards = false
    @State private var showsAllLockedAwards = false
    @State private var selectedLiftHistory: TopLiftCardDestination?

    var body: some View {
        let tierSummary = appState.strengthTierSummary
        let achievements = appState.achievements
        let unlockedTitles = Set(appState.achievementUnlocks.map(\.title))
        let unlockedAchievements = achievements.filter { unlockedTitles.contains($0.title) }
        let progressAchievements = achievements.filter { !unlockedTitles.contains($0.title) }
        let preferredUnit = appState.currentProfile.preferredUnit
        let bestStrengthLifts = appState.bestStrengthLifts
        let bestBench = bestStrengthLifts["bench"]
        let bestSquat = bestStrengthLifts["squat"]
        let bestDeadlift = bestStrengthLifts["deadlift"]
        let awardEligibleOneRepWeights = RankingCalculator.achievementEligibleOneRepWeights(
            lifts: appState.currentUserLifts,
            completedWorkouts: appState.completedWorkouts
        )
        let awardEligibleBench = awardEligibleOneRepWeights["bench"] ?? 0
        let awardEligibleSquat = awardEligibleOneRepWeights["squat"] ?? 0
        let awardEligibleDeadlift = awardEligibleOneRepWeights["deadlift"] ?? 0
        let totalPowerlifting = awardEligibleBench + awardEligibleSquat + awardEligibleDeadlift
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(appState.currentProfile.bodyweightPounds)
        let bodyweightLogCount = appState.bodyweightEntries.reduce(0) { count, entry in
            count + (entry.actual == nil ? 0 : 1)
        }
        let liftCount = appState.currentUserLifts.count
        let closestAwardProgress = progressAwardItems(
            for: progressAchievements,
            stats: appState.competitiveStatistics,
            tierSummary: tierSummary,
            bestBench: awardEligibleBench,
            bestSquat: awardEligibleSquat,
            bestDeadlift: awardEligibleDeadlift,
            totalPowerlifting: totalPowerlifting,
            liftCount: liftCount,
            bodyweightLogCount: bodyweightLogCount,
            bodyweightKilograms: bodyweightKilograms
        )
        let unlockedCount = unlockedAchievements.count
        let lockedCount = progressAchievements.count
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("\(unlockedCount) earned", systemImage: "medal.fill")
                        Spacer()
                        Text("\(lockedCount) remaining").foregroundStyle(Color.liftMuted)
                    }
                    .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Closest awards")
                        if closestAwardProgress.isEmpty {
                            LiftEmptyState(title: "No progress data yet", message: "Keep training to see your next awards.", symbolName: "chart.xyaxis.line")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Array(closestAwardProgress.prefix(3)), id: \.achievement.id) { item in
                                    awardTile(item.achievement, unlocked: false, status: item.status)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Unlocked awards (\(unlockedCount))")
                        if unlockedAchievements.isEmpty {
                            LiftEmptyState(title: "No awards yet", message: "Complete workouts and log lifts to unlock your first award.", symbolName: "medal.fill")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(showsAllUnlockedAwards ? unlockedAchievements : Array(unlockedAchievements.prefix(8))) { achievement in
                                    awardTile(achievement, unlocked: true)
                                }
                            }
                            if unlockedCount > 8 {
                                Button(showsAllUnlockedAwards ? "Show fewer" : "Show all \(unlockedCount) unlocked awards") {
                                    showsAllUnlockedAwards.toggle()
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RIVAL TIER")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.liftGold)
                                Text(tierSummary.overallTier.label)
                                    .font(.title.weight(.black))
                            }
                            Spacer()
                            Image(systemName: "medal.fill")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.liftGold)
                        }

                        Text(tierSummary.completedRequiredLiftCount == tierSummary.requiredLiftCount
                             ? "Your overall tier is the highest tier reached in all three lifts: squat, bench press, and deadlift."
                             : "Log completed working sets for all three lifts to unlock your starting tier.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)

                        ForEach(tierSummary.liftProgress) { lift in
                            Button {
                                selectedLiftHistory = .exerciseHistory(id: lift.exerciseID, name: lift.exerciseName)
                            } label: {
                                strengthLiftRow(lift, preferredUnit: preferredUnit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View \(lift.exerciseName) workout history")
                            .accessibilityHint("Review a workout set and submit it as a lift")
                        }
                    }
                    .padding(14)
                    .liftSurface(radius: 12)

                    if let rivalTierShareImage {
                        ShareLink(
                            item: rivalTierShareImage,
                            preview: SharePreview(
                                "\(appState.currentProfile.displayName)'s Rival Tier",
                                image: rivalTierShareImage
                            )
                        ) {
                            Label("Share Rival Tier card", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    } else {
                        Button {
                            prepareRivalTierShareImage(summary: tierSummary)
                        } label: {
                            Label("Prepare Rival Tier card", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Personal records")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(["bench", "squat", "deadlift", "total"], id: \.self) { metric in
                                switch metric {
                                case "bench":
                                    personalRecord(
                                        "Bench",
                                        exerciseID: "bench",
                                        best: bestBench,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "bench" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                case "squat":
                                    personalRecord(
                                        "Squat",
                                        exerciseID: "squat",
                                        best: bestSquat,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "squat" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                case "deadlift":
                                    personalRecord(
                                        "Deadlift",
                                        exerciseID: "deadlift",
                                        best: bestDeadlift,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "deadlift" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                default:
                                    totalRecord(preferredUnit: preferredUnit)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Locked awards (\(lockedCount))")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(showsAllLockedAwards ? progressAchievements : Array(progressAchievements.prefix(8))) {
                                awardTile($0, unlocked: false)
                            }
                        }
                        if lockedCount > 8 {
                            Button(showsAllLockedAwards ? "Show fewer" : "Show all \(lockedCount) locked awards") {
                                showsAllLockedAwards.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Awards")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("awards.screen")
        .task {
            await appState.refreshProductionLifts()
        }
        .onAppear {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.competitionStore.liftsRevision) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.bodyweightEntries) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.currentProfile.bodyweightPounds) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: tierSummary) { _, _ in
            rivalTierShareImage = nil
        }
        .sheet(item: $selectedLiftHistory) { destination in
            TopLiftCardDetailSheet(destination: destination)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private func prepareRivalTierShareImage(summary: StrengthTierSummary) {
        let renderer = ImageRenderer(content: RivalTierShareCard(
            profile: appState.currentProfile,
            summary: summary,
            preferredUnit: appState.currentProfile.preferredUnit
        ))
        renderer.scale = 2
        rivalTierShareImage = renderer.uiImage.map(Image.init(uiImage:))
    }

    private func strengthLiftRow(_ lift: LiftTierProgress, preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(lift.exerciseName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(lift.estimatedOneRepMaxKilograms == nil ? "Not logged" : lift.currentTier.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(lift.estimatedOneRepMaxKilograms == nil ? Color.liftMuted : Color.liftGold)
            }
            ProgressView(value: lift.progressToNextTier)
                .tint(.liftGold)
            HStack {
                Text(lift.estimatedOneRepMaxKilograms.map {
                    "Est. 1RM \(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))"
                } ?? "Complete a set of 10 reps or fewer")
                Spacer()
                if let nextTier = lift.nextTier, let threshold = lift.nextThresholdMultiple {
                    Text("\(RankingCalculator.format(threshold))× BW to \(nextTier.label)")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func personalRecord(
        _ title: String,
        exerciseID: String,
        best: LiftSubmission?,
        workoutEstimate: Double?,
        preferredUnit: UnitSystem
    ) -> some View {
        let valueKilograms = best?.normalizedWeightKilograms ?? workoutEstimate
        return Button {
            selectedLiftHistory = .exerciseHistory(id: exerciseID, name: title)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(Color.liftGold)
                Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
                Text(valueKilograms.map {
                    MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit)
                } ?? "—")
                    .font(.headline.weight(.black))
                Text(best != nil ? "Best submitted lift" : workoutEstimate != nil ? "Estimated 1RM from workouts" : "No workout lift yet")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(title) workout history and lift details")
        .accessibilityHint("Review a workout set and submit it as a lift")
    }

    private func totalRecord(preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
            Text("Total").font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(RankingFormatting.threeLiftTotalText(
                totalPounds: appState.powerliftingTotal,
                preferredUnit: preferredUnit
            ))
            .font(.headline.weight(.black))
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardTile(_ achievement: Achievement, unlocked: Bool, status: String? = nil) -> some View {
        let display = MeasurementFormatting.awardDisplay(for: achievement, unit: appState.currentProfile.preferredUnit)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(unlocked ? Color.liftGold : Color.liftMuted)
                .accessibilityHidden(true)
            Text(display.title).font(.subheadline.weight(.bold)).foregroundStyle(unlocked ? Color.liftText : Color.liftMuted).lineLimit(2)
                .accessibilityLabel("\(display.title), \(unlocked ? "earned" : "locked")")
            if let status {
                Text(status).font(.caption2.weight(.semibold)).foregroundStyle(Color.liftMuted)
            } else if !unlocked {
                Text("Keep progressing").font(.caption2).foregroundStyle(Color.liftMuted)
            }
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func progressAwardItems(
        for achievements: [Achievement],
        stats: CompetitiveStatistics,
        tierSummary: StrengthTierSummary,
        bestBench: Double,
        bestSquat: Double,
        bestDeadlift: Double,
        totalPowerlifting: Double,
        liftCount: Int,
        bodyweightLogCount: Int,
        bodyweightKilograms: Double
    ) -> [(achievement: Achievement, progress: Double, status: String)] {
        achievements.compactMap { achievement in
            guard let item = progressAward(
                for: achievement,
                stats: stats,
                tierSummary: tierSummary,
                bestBench: bestBench,
                bestSquat: bestSquat,
                bestDeadlift: bestDeadlift,
                totalPowerlifting: totalPowerlifting,
                liftCount: liftCount,
                bodyweightLogCount: bodyweightLogCount,
                bodyweightKilograms: bodyweightKilograms
            ) else { return nil }
            return (achievement: item.0, progress: item.1, status: item.2)
        }
        .sorted {
            if $0.progress == $1.progress {
                return $0.achievement.title < $1.achievement.title
            }
            return $0.progress > $1.progress
        }
    }

    private func progressAward(
        for achievement: Achievement,
        stats: CompetitiveStatistics,
        tierSummary: StrengthTierSummary,
        bestBench: Double,
        bestSquat: Double,
        bestDeadlift: Double,
        totalPowerlifting: Double,
        liftCount: Int,
        bodyweightLogCount: Int,
        bodyweightKilograms: Double
    ) -> (Achievement, Double, String)? {
        let title = achievement.title
        let preferredUnit = appState.currentProfile.preferredUnit
        let metric: (Double, String)?

        if title == "First Workout" {
            metric = metricProgress(current: Double(stats.totalWorkouts), target: 1, status: "\(stats.totalWorkouts) / 1 workout")
        } else if title.hasSuffix(" Workouts") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.totalWorkouts), target: target, status: "\(stats.totalWorkouts) / \(Int(target)) workouts")
        } else if title == "First Lift Logged" {
            metric = metricProgress(current: Double(liftCount), target: 1, status: "\(liftCount) / 1 lift logged")
        } else if title.contains("Lifts Logged") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(liftCount), target: target, status: "\(liftCount) / \(Int(target)) lifts logged")
        } else if title == "First Verified Lift" {
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: 1, status: "\(stats.verifiedLiftCount) / 1 verified lift")
        } else if title == "Five Verified Lifts" || title == "Ten Verified Lifts" {
            let target = title == "Five Verified Lifts" ? 5.0 : 10.0
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: target, status: "\(stats.verifiedLiftCount) / \(Int(target)) verified lifts")
        } else if title.contains("Verified Lifts") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: target, status: "\(stats.verifiedLiftCount) / \(Int(target)) verified lifts")
        } else if title == "First PR" {
            metric = metricProgress(current: Double(stats.prCount), target: 1, status: "\(stats.prCount) / 1 PR")
        } else if title.contains(" PRs") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.prCount), target: target, status: "\(stats.prCount) / \(Int(target)) PRs")
        } else if title.hasSuffix(" Reps") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.totalWorkingSetRepetitions), target: target, status: "\(stats.totalWorkingSetRepetitions) / \(Int(target)) reps")
        } else if title.hasSuffix(" Training Hours") {
            guard let targetHours = parseLeadingValue(from: title) else { return nil }
            let targetSeconds = targetHours * 60 * 60
            metric = metricProgress(
                current: stats.totalActiveTrainingTime,
                target: targetSeconds,
                status: "\(String(format: "%.1f", min(stats.totalActiveTrainingTime, targetSeconds) / 3600)) / \(Int(targetHours)) hrs"
            )
        } else if title == "Bodyweight Logged" {
            metric = metricProgress(current: Double(bodyweightLogCount), target: 1, status: "\(bodyweightLogCount) / 1 bodyweight log")
        } else if title.hasSuffix(" Bodyweight Logs") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(bodyweightLogCount), target: target, status: "\(bodyweightLogCount) / \(Int(target)) bodyweight logs")
        } else if title.hasSuffix(" Exercises Explored") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = Set(appState.completedWorkouts.flatMap { $0.exercises.map(\.exerciseID) }).count
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) exercises")
        } else if title.hasSuffix(" Gyms Joined") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = appState.joinedGymCount
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) gyms")
        } else if title.hasSuffix(" Programs Started") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = appState.workoutPlans.count
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) programs")
        } else if let liftMilestone = MeasurementFormatting.liftAwardMilestone(for: title) {
            let current = liftMilestone.exercise == "Bench" ? bestBench : (liftMilestone.exercise == "Squat" ? bestSquat : bestDeadlift)
            let target = RankingCalculator.poundsToKilograms(liftMilestone.pounds)
            metric = metricProgress(
                current: current,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let totalPounds = MeasurementFormatting.totalAwardPounds(for: title) {
            let target = RankingCalculator.poundsToKilograms(totalPounds)
            metric = metricProgress(
                current: totalPowerlifting,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(totalPowerlifting, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let volumeKilograms = MeasurementFormatting.volumeAwardKilograms(for: title) {
            metric = metricProgress(
                current: stats.lifetimeWorkingSetVolume,
                target: volumeKilograms,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(stats.lifetimeWorkingSetVolume, volumeKilograms), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: volumeKilograms, unit: preferredUnit))"
            )
        } else if let streakTarget = parseLeadingValue(from: title), title.contains("Week Workout Streak") {
            metric = metricProgress(current: Double(stats.currentStreak), target: streakTarget, status: "\(stats.currentStreak) / \(Int(streakTarget)) weeks")
        } else if title == "Profile Complete" {
            let profile = appState.currentProfile
            let isComplete = !profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            metric = metricProgress(current: isComplete ? 1 : 0, target: 1, status: isComplete ? "Profile complete" : "Profile not complete")
        } else if title.contains("Bodyweight") {
            let multiple = parseLeadingValue(from: title) ?? 1
            let target = bodyweightKilograms * multiple
            let current: Double
            switch true {
            case title.contains("Bench"):
                current = bestBench
            case title.contains("Squat"):
                current = bestSquat
            default:
                current = bestDeadlift
            }
            metric = metricProgress(
                current: current,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if title.hasSuffix(" Rival"), let rivalTier = rivalTier(for: title) {
            let currentTier = tierSummary.overallTier == .unranked ? 0 : tierSummary.overallTier.rawValue
            metric = metricProgress(
                current: Double(currentTier),
                target: Double(rivalTier.rawValue),
                status: "\(tierSummary.overallTier.label) / \(rivalTier.label)"
            )
        } else if title.hasPrefix("Global Top"), let target = parseLeadingValue(from: title), let rank = stats.highestGlobalTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: target)
        } else if title == "Gym Top 10", let rank = stats.highestGymTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 10)
        } else if title == "Gym Record Holder", let rank = stats.highestGymTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 1)
        } else if title == "Global Number One", let rank = stats.highestGlobalTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 1)
        } else {
            return nil
        }

        guard let metric else { return nil }
        return (achievement, metric.0, "\(Int(metric.0 * 100))%  •  \(metric.1)")
    }

    private func metricProgress(current: Double, target: Double, status: String) -> (Double, String)? {
        guard target > 0 else { return nil }
        let progress = min(1, max(0, current / target))
        return (progress, status)
    }

    private func metricRankProgress(currentRank: Double, target: Double) -> (Double, String)? {
        guard currentRank > 0, target > 0 else { return nil }
        let progress = min(1, target / currentRank)
        return (progress, "\(Int(currentRank)) / \(Int(target))")
    }

    private func parseLeadingValue(from title: String) -> Double? {
        let cleaned = title.replacingOccurrences(of: ",", with: "")
        var collected = ""
        var foundStart = false
        var hasDecimal = false
        for scalar in cleaned.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                foundStart = true
                collected.append(Character(scalar))
            } else if scalar == "." && foundStart {
                if hasDecimal { continue }
                hasDecimal = true
                collected.append(".")
            } else if foundStart {
                break
            }
        }
        return Double(collected)
    }

    private func rivalTier(for title: String) -> StrengthTier? {
        let base = title.replacingOccurrences(of: " Rival", with: "")
        return StrengthTier.allCases.first { $0.label == base && $0 != .unranked }
    }
}

private struct RivalTierShareCard: View {
    let profile: UserProfile
    let summary: StrengthTierSummary
    let preferredUnit: UnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIFT RIVALS")
                        .font(.system(size: 18, weight: .black))
                        .tracking(3)
                        .foregroundStyle(Color.liftGold)
                    Text(profile.displayName)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("@\(profile.username)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "medal.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color.liftGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RIVAL TIER")
                    .font(.system(size: 16, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(summary.overallTier.label)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 14) {
                ForEach(summary.liftProgress) { lift in
                    HStack(spacing: 14) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.liftGold)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lift.exerciseName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                            Text(lift.estimatedOneRepMaxKilograms.map {
                                "Est. 1RM \(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))"
                            } ?? "Not logged")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }
                        Spacer()
                        Text(lift.currentTier.label)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.liftGold)
                    }
                    .padding(16)
                    .background(Color.liftOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Spacer()
            Text("TRAIN. PROVE. RISE.")
                .font(.system(size: 15, weight: .black))
                .tracking(2.5)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(42)
        .frame(width: 540, height: 675)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.09, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingPassword = false
    @State private var showingReset = false
    @State private var resetEmail = ""
    @State private var resetError: String?
    @State private var appleNonce = ""
    @State private var confirmationEmail: String?

    private let emailConfirmationMessage = "Check your email to confirm your account, then sign in."
    private let emailResentMessage = "A new confirmation email is on the way."

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 46)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Color.liftAccentText)
                    Text("Lift Rivals").font(.largeTitle.bold())
                    Text("Sign in to save your profile, sync workouts, and connect with other lifters.")
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)

                    if appState.accountStatus == .configurationRequired {
                        Label("Account services are not configured in this development build.", systemImage: "wrench.and.screwdriver.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftGold)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Picker("Account action", selection: $mode) {
                            Text("Sign In").tag("Sign In")
                            Text("Create Account").tag("Create Account")
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            TextField("name@example.com", text: $email)
                                .accessibilityLabel("Email")
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(Color.liftCardRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Password").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            HStack(spacing: 10) {
                                Group {
                                    if showingPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textContentType(mode == "Sign In" ? .password : .newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    showingPassword.toggle()
                                } label: {
                                    Image(systemName: showingPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .accessibilityLabel(showingPassword ? "Hide password" : "Show password")
                            }
                            .padding(14)
                            .background(Color.liftCardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text(
                            mode == "Sign In"
                                ? "Use the email address connected to your account."
                                : "Use a valid email and a password of at least 10 characters."
                        )
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let confirmationEmail {
                            emailConfirmationNotice(for: confirmationEmail)
                        } else if let message = appState.accountMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(
                                    message == "Incorrect password. Check your password and try again."
                                        ? .red
                                        : (message.localizedCaseInsensitiveContains("connection") || message.localizedCaseInsensitiveContains("network")
                                            ? Color.liftGold
                                            : Color.liftMuted)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Please wait…" : mode,
                            symbolName: mode == "Sign In" ? "arrow.right.circle.fill" : "person.badge.plus"
                        ) {
                            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !normalizedEmail.isEmpty else {
                                appState.accountMessage = "Enter your email address."
                                return
                            }
                            guard normalizedEmail.contains("@") else {
                                appState.accountMessage = "Enter a valid email address."
                                return
                            }
                            guard !password.isEmpty else {
                                appState.accountMessage = "Enter your password."
                                return
                            }
                            guard mode == "Sign In" || password.count >= 10 else {
                                appState.accountMessage = "New passwords must contain at least 10 characters."
                                return
                            }
                            Task {
                                if mode == "Sign In" {
                                    await appState.signIn(email: normalizedEmail, password: password)
                                    if appState.isAuthenticated {
                                        appState.selectedTab = 1
                                    }
                                } else {
                                    await appState.signUp(email: normalizedEmail, password: password)
                                    if appState.accountMessage == emailConfirmationMessage {
                                        confirmationEmail = normalizedEmail
                                        password = ""
                                        mode = "Sign In"
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("authentication.email.submit")
                        .disabled(appState.accountOperationInProgress)

#if DEBUG
                        Label("Apple sign-in is enabled in the release build", systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity)
#else
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = AppleNonce.make()
                            appleNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = AppleNonce.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let data = credential.identityToken,
                                      let token = String(data: data, encoding: .utf8),
                                      !appleNonce.isEmpty else {
                                    appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                                    return
                                }
                                let fullName = AppleIdentityStore.displayName(from: credential.fullName)
                                Task {
                                    await appState.signInWithApple(
                                        identityToken: token,
                                        nonce: appleNonce,
                                        appleUserIdentifier: credential.user,
                                        fullName: fullName
                                    )
                                    if appState.isAuthenticated {
                                        appState.selectedTab = 1
                                    }
                                }
                            case .failure(let error):
                                if let authorizationError = error as? ASAuthorizationError,
                                   authorizationError.code == .canceled {
                                    return
                                }
                                appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .disabled(appState.accountOperationInProgress)
#endif

                        Button("Forgot password?") { resetEmail = email; resetError = nil; showingReset = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                    }

                    if AppState.allowsDemoMode {
                        Divider().overlay(Color.liftOverlay)
                        Button {
                            Task { await appState.enterDemoMode() }
                        } label: {
                            Label("Explore demo", systemImage: "person.crop.circle.badge.checkmark")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.liftAccentText)
                        Text("Demo progress stays on this device and does not affect your account.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                Form {
                    Section {
                        Text("Enter your account email and we’ll send a secure reset link. Open it on this device to choose a new password in Lift Rivals.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        TextField("Email", text: $resetEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if let resetError {
                        Text(resetError).foregroundStyle(Color.liftRed)
                            .accessibilityIdentifier("authentication.reset.error")
                    }
                    Section {
                        Button(appState.accountOperationInProgress ? "Sending…" : "Send reset link") {
                            let normalizedEmail = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard normalizedEmail.contains("@") else {
                                resetError = "Enter a valid email address."
                                return
                            }
                            resetError = nil
                            Task {
                                await appState.requestPasswordReset(email: normalizedEmail)
                                if appState.accountMessage == "If an account can receive a reset email, instructions are on the way." {
                                    showingReset = false
                                } else {
                                    resetError = appState.accountMessage
                                }
                            }
                        }
                        .disabled(appState.accountOperationInProgress)
                    }
                }
                .navigationTitle("Reset password")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingReset = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private func emailConfirmationNotice(for email: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Confirmation email sent", systemImage: "envelope.badge.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftAccentText)

            Text("We sent a confirmation link to")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)

            Text(email)
                .font(.subheadline.weight(.bold))
                .textSelection(.enabled)

            Text("Open the email, tap the link, then return here to sign in. Check spam if it does not arrive within a few minutes.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await appState.resendConfirmationEmail(email: email) }
            } label: {
                Label(
                    appState.accountOperationInProgress ? "Sending…" : "Send again",
                    systemImage: "arrow.clockwise"
                )
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.liftAccentText)
            .disabled(appState.accountOperationInProgress)

            if appState.accountMessage == emailResentMessage {
                Text(emailResentMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftAccentText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liftBlue.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liftBlue.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PasswordUpdateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case password
        case confirmation
    }

    private var hasMinimumLength: Bool { password.count >= 10 }
    private var passwordsMatch: Bool { !confirmation.isEmpty && password == confirmation }
    private var canSubmit: Bool { hasMinimumLength && passwordsMatch }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.liftLime.opacity(0.15))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(Color.liftAccentText)
                            }

                            Text("Choose a new password")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                            Text("Your recovery link is verified. Set a new password to secure your Lift Rivals account.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 13) {
                            secureInput(
                                label: "New password",
                                placeholder: "Enter a new password",
                                text: $password,
                                field: .password
                            )
                            secureInput(
                                label: "Confirm new password",
                                placeholder: "Enter it again",
                                text: $confirmation,
                                field: .confirmation
                            )
                        }

                        LiftCard(padding: 15, radius: 18) {
                            VStack(alignment: .leading, spacing: 11) {
                                Text("Password requirements")
                                    .font(.subheadline.weight(.bold))
                                requirementRow(
                                    "At least 10 characters",
                                    isSatisfied: hasMinimumLength,
                                    isError: !password.isEmpty && !hasMinimumLength
                                )
                                requirementRow(
                                    confirmation.isEmpty ? "Confirm your password" : passwordsMatch ? "Passwords match" : "Passwords do not match",
                                    isSatisfied: passwordsMatch,
                                    isError: !confirmation.isEmpty && !passwordsMatch
                                )
                            }
                        }

                        if let message = appState.accountMessage {
                            Label {
                                Text(message)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .foregroundStyle(Color.liftRed)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftRed.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Updating…" : "Update password",
                            symbolName: appState.accountOperationInProgress ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill"
                        ) {
                            Task { await appState.updatePassword(password) }
                        }
                        .disabled(appState.accountOperationInProgress || !canSubmit)
                        .accessibilityIdentifier("authentication.password.update")

                        Text("If this link expires or stops working, request a new reset email from the sign-in screen.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Account recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private func secureInput(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 20)
                SecureField(placeholder, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .password ? .next : .done)
                    .onSubmit {
                        if field == .password { focusedField = .confirmation }
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.liftField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == field ? Color.liftLime.opacity(0.75) : Color.clear, lineWidth: 1.5)
            }
        }
        .onChange(of: text.wrappedValue) { _, _ in
            if appState.accountMessage != nil { appState.accountMessage = nil }
        }
    }

    private func requirementRow(_ title: String, isSatisfied: Bool, isError: Bool) -> some View {
        Label(title, systemImage: isSatisfied ? "checkmark.circle.fill" : isError ? "xmark.circle.fill" : "circle")
            .font(.caption)
            .foregroundStyle(isSatisfied ? Color.liftAccentText : isError ? Color.liftRed : Color.liftMuted)
    }
}

private enum AppleNonce {
    static func make(length: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString }
        for byte in bytes { result.append(alphabet[Int(byte) % alphabet.count]) }
        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
