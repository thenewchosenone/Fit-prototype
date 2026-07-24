import SwiftUI

struct ForumExploreView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""
    @State private var category = "All"
    @State private var showingCreateCommunity = false

    private var categories: [String] {
        ["All"] + Array(Set(appState.forumCommunities.map(\.category))).sorted()
    }

    private var matches: [ForumCommunity] {
        appState.forumSearchCommunities(query: search, category: category)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                searchField
                categoryBar
                LiftActionRow(
                    title: "Browse gyms",
                    subtitle: "Gym membership and local discussions stay separate",
                    symbolName: "building.2.fill",
                    tint: .liftBlue
                ) { appState.communityPath.append(.gyms) }

                if appState.isForumStaff {
                    LiftActionRow(
                        title: "Create a community",
                        subtitle: "Staff-only community administration",
                        symbolName: "plus.square.fill",
                        tint: .liftGreen
                    ) { showingCreateCommunity = true }
                }

                communitySection("Joined", communities: matches.filter { appState.isJoinedToForumCommunity($0.id) })
                communitySection("Trending", communities: Array(matches.sorted { $0.postCount > $1.postCount }.prefix(4)))
                communitySection("All Communities", communities: matches)
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingCreateCommunity) {
            ForumCommunityEditorView()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.liftMuted)
            TextField("Search communities and posts", text: $search)
                .textInputAutocapitalization(.never)
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") } }
        }
        .padding(.horizontal, 13).frame(minHeight: 44).background(Color.liftField)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { option in
                    Button(option) { category = option }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(category == option ? .white : Color.liftMuted)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(category == option ? Color.liftBlue : Color.liftCard)
                        .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func communitySection(_ title: String, communities: [ForumCommunity]) -> some View {
        if !communities.isEmpty {
            CompactSectionHeader(title: title)
            VStack(spacing: 0) {
                ForEach(communities) { community in
                    ForumCommunityRow(community: community)
                    if community.id != communities.last?.id {
                        Divider().overlay(Color.liftSeparator).padding(.leading, 58)
                    }
                }
            }
            .padding(.horizontal, 12).liftSurface(radius: 14)
        }
    }
}

private struct ForumCommunityRow: View {
    @EnvironmentObject private var appState: AppState
    let community: ForumCommunity

    var body: some View {
        HStack(spacing: 12) {
            Button { appState.openForumCommunity(community.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: community.symbolName)
                        .font(.title3.weight(.semibold)).foregroundStyle(Color.liftBlue)
                        .frame(width: 42, height: 42).background(Color.liftBlue.opacity(0.12)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(community.name).font(.subheadline.weight(.bold)).foregroundStyle(Color.liftText)
                            if community.visibility != .publicOpen {
                                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Color.liftMuted)
                            }
                        }
                        Text(community.summary).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(2)
                        Text("\(community.memberCount.formatted()) members")
                            .font(.caption2).foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if appState.isJoinedToForumCommunity(community.id) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.liftGreen).frame(width: 40, height: 40)
                    .accessibilityLabel("Joined")
            } else {
                Button(community.visibility == .restricted ? "Request" : "Join") {
                    _ = appState.joinForumCommunity(community.id)
                }
                .font(.caption.weight(.bold)).buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 9))
                .disabled(community.visibility == .inviteOnly)
            }
        }
        .padding(.vertical, 11)
    }
}
