import SwiftUI

struct ForumCommunityDetailView: View {
    @EnvironmentObject private var appState: AppState
    let communityID: UUID
    @State private var selectedTab = "Posts"
    @State private var sort: ForumFeedSort = .hot
    @State private var topRange: ForumTopRange = .week
    @State private var requestNote = ""
    @State private var showingRequest = false

    private var community: ForumCommunity? { appState.forumCommunity(communityID) }
    private var canReadPosts: Bool { appState.canReadForumCommunity(communityID) }

    var body: some View {
        AppBackground {
            if let community {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        identity(community)
                        Picker("Community section", selection: $selectedTab) {
                            Text("Posts").tag("Posts"); Text("About").tag("About")
                        }
                        .pickerStyle(.segmented)

                        if selectedTab == "About" || !canReadPosts {
                            about(community)
                        } else {
                            HStack {
                                Menu(sort.rawValue) {
                                    ForEach(ForumFeedSort.allCases) { option in Button(option.rawValue) { sort = option } }
                                }
                                if sort == .top {
                                    Menu(topRange.rawValue) {
                                        ForEach(ForumTopRange.allCases) { option in Button(option.rawValue) { topRange = option } }
                                    }
                                }
                                Spacer()
                            }
                            .font(.caption.weight(.bold)).buttonStyle(.bordered)
                            ForEach(appState.forumFeed(communityID: community.id, sort: sort, topRange: topRange)) { post in
                                ForumPostCard(postID: post.id)
                            }
                        }
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .navigationTitle(community.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if appState.canContributeToForumCommunity(community.id) {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { appState.beginForumComposer(communityID: community.id) } label: { Image(systemName: "square.and.pencil") }
                        }
                    }
                    if appState.isForumStaff {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(community.archivedAt == nil ? "Archive Community" : "Restore Community", role: community.archivedAt == nil ? .destructive : nil) {
                                    appState.setForumCommunityArchived(community.archivedAt == nil, communityID: community.id)
                                }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
                .sheet(isPresented: $showingRequest) {
                    NavigationStack {
                        Form {
                            Section("Why would you like to join?") { TextEditor(text: $requestNote).frame(minHeight: 120) }
                        }
                        .navigationTitle("Request Membership")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingRequest = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Send") { _ = appState.joinForumCommunity(community.id, note: requestNote); showingRequest = false }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            } else {
                ContentUnavailableView("Community unavailable", systemImage: "person.3")
            }
        }
    }

    private func identity(_ community: ForumCommunity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: community.symbolName)
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(Color.liftBlue)
                    .frame(width: 62, height: 62).background(Color.liftBlue.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name).font(.title2.weight(.black))
                    Text(community.summary).font(.subheadline).foregroundStyle(Color.liftMuted)
                    Text("\(community.memberCount.formatted()) members • \(community.postCount) posts")
                        .font(.caption).foregroundStyle(Color.liftMuted)
                }
            }
            HStack(spacing: 10) {
                if appState.isJoinedToForumCommunity(community.id) {
                    Menu {
                        ForEach(ForumNotificationLevel.allCases) { level in
                            Button(level.rawValue) { appState.setForumNotificationLevel(level, communityID: community.id) }
                        }
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    .buttonStyle(.bordered)
                    Menu("Joined") {
                        Button("Leave Community", role: .destructive) { appState.leaveForumCommunity(community.id) }
                    }
                    .buttonStyle(.borderedProminent)
                } else if appState.forumMembership(for: community.id)?.status == .pending {
                    Label("Request pending", systemImage: "clock.fill").font(.subheadline.weight(.bold)).foregroundStyle(Color.liftGold)
                } else {
                    Button(community.visibility == .restricted ? "Request to Join" : "Join Community") {
                        if community.visibility == .restricted { showingRequest = true }
                        else { _ = appState.joinForumCommunity(community.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(community.visibility == .inviteOnly)
                }
            }
            .font(.caption.weight(.bold))
        }
        .padding(16).liftSurface()
    }

    private func about(_ community: ForumCommunity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !canReadPosts {
                Label("Join to read and participate", systemImage: "lock.fill")
                    .font(.headline).foregroundStyle(Color.liftGold)
            }
            Text(community.details).font(.body).foregroundStyle(Color.liftMuted)
            CompactSectionHeader(title: "Rules")
            ForEach(Array(community.rules.enumerated()), id: \.offset) { index, rule in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)").font(.caption.weight(.black)).foregroundStyle(Color.liftBlue)
                        .frame(width: 26, height: 26).background(Color.liftBlue.opacity(0.12)).clipShape(Circle())
                    Text(rule).font(.subheadline)
                }
            }
            CompactSectionHeader(title: "Moderators")
            ForEach(appState.forumMemberships.filter {
                $0.communityID == community.id && $0.role.authority >= ForumMemberRole.moderator.authority
            }) { membership in
                Text(appState.profile(id: membership.userID)?.displayName ?? membership.role.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16).liftSurface()
    }
}
