import SwiftUI

struct ForumHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCommunityID: UUID?
    @State private var sort: ForumFeedSort = .hot
    @State private var topRange: ForumTopRange = .week
    @State private var search = ""
    @State private var showingSearch = false

    private var posts: [ForumPost] {
        appState.forumFeed(communityID: selectedCommunityID, sort: sort, topRange: topRange, query: search)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                quickActions
                filterBar
                if showingSearch { searchField }
                if appState.joinedForumCommunities.isEmpty {
                    LiftEmptyState(
                        title: "Build your Home feed",
                        message: "Join communities in Explore to see their posts here.",
                        symbolName: "person.3.sequence.fill",
                        actionTitle: "Explore communities"
                    ) { appState.selectedCommunitySegment = "Explore" }
                    .padding(.top, 32)
                } else if posts.isEmpty {
                    LiftEmptyState(
                        title: "No posts found",
                        message: search.isEmpty ? "This community is quiet for now." : "Try a different search.",
                        symbolName: "text.bubble",
                        actionTitle: search.isEmpty ? "Create post" : "Clear search"
                    ) {
                        if search.isEmpty { appState.beginForumComposer(communityID: selectedCommunityID) }
                        else { search = "" }
                    }
                    .padding(.top, 32)
                } else {
                    ForEach(posts) { post in ForumPostCard(postID: post.id) }
                }
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Menu {
                Button { appState.communityPath.append(.saved) } label: {
                    Label("Saved posts", systemImage: "bookmark.fill")
                }
                Button { appState.communityPath.append(.watched) } label: {
                    Label("Watched posts", systemImage: "bell.badge.fill")
                }
            } label: {
                Label("My posts", systemImage: "tray.full.fill")
            }
            Spacer()
            Button { showingSearch.toggle() } label: {
                Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                    .frame(width: 44, height: 44)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .accessibilityLabel(showingSearch ? "Close search" : "Search posts")
        }
        .font(.caption.weight(.bold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 10))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("All joined communities") { selectedCommunityID = nil }
                    ForEach(appState.joinedForumCommunities) { community in
                        Button(community.name) { selectedCommunityID = community.id }
                    }
                } label: {
                    ForumFilterLabel(title: selectedCommunityID.flatMap { appState.forumCommunity($0)?.name } ?? "All joined", symbol: "person.3.fill")
                }
                Menu {
                    ForEach(ForumFeedSort.allCases) { option in Button(option.rawValue) { sort = option } }
                } label: {
                    ForumFilterLabel(title: sort.rawValue, symbol: "arrow.up.arrow.down")
                }
                if sort == .top {
                    Menu {
                        ForEach(ForumTopRange.allCases) { range in Button(range.rawValue) { topRange = range } }
                    } label: {
                        ForumFilterLabel(title: topRange.rawValue, symbol: "calendar")
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.liftMuted)
            TextField("Search joined communities", text: $search)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 44)
        .background(Color.liftField)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct ForumFilterLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.liftText)
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(Color.liftCardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
