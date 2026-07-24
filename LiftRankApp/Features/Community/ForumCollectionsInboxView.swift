import SwiftUI

enum ForumCollectionMode { case saved, watched }

struct ForumCollectionView: View {
    @EnvironmentObject private var appState: AppState
    let mode: ForumCollectionMode

    private var posts: [ForumPost] {
        appState.forumPosts.filter {
            mode == .saved ? $0.savedByUserIDs.contains(appState.currentProfile.id) : $0.watchedByUserIDs.contains(appState.currentProfile.id)
        }
    }

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if posts.isEmpty {
                        LiftEmptyState(
                            title: mode == .saved ? "No saved posts" : "No watched posts",
                            message: "Use the post actions to keep important discussions here.",
                            symbolName: mode == .saved ? "bookmark" : "bell"
                        ).padding(.top, 50)
                    } else {
                        ForEach(posts) { ForumPostCard(postID: $0.id) }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(mode == .saved ? "Saved Posts" : "Watched Posts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ForumGymDirectoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""

    private var gyms: [Gym] {
        let clean = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.gyms.filter {
            clean.isEmpty || $0.name.localizedCaseInsensitiveContains(clean) ||
                $0.city.localizedCaseInsensitiveContains(clean) || $0.state.localizedCaseInsensitiveContains(clean)
        }
    }

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.liftMuted)
                        TextField("Search name, city, or state", text: $search)
                    }
                    .padding(.horizontal, 12).frame(minHeight: 44).background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                    Text("Gym memberships are independent from forum communities. You can join up to \(AppState.maximumJoinedGyms).")
                        .font(.caption).foregroundStyle(Color.liftMuted).frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(gyms) { gym in
                        Button { appState.communityPath.append(.gym(gym.id)) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "building.2.fill").foregroundStyle(Color.liftBlue)
                                    .frame(width: 42, height: 42).background(Color.liftBlue.opacity(0.12)).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(gym.name).font(.subheadline.weight(.bold)).foregroundStyle(Color.liftText)
                                    Text("\(gym.city), \(gym.state) • \(gym.memberCount) members • \(gym.verifiedLiftCount) verified lifts")
                                        .font(.caption).foregroundStyle(Color.liftMuted).lineLimit(2)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.liftMuted)
                            }
                            .padding(13).liftSurface(radius: 13)
                        }
                        .buttonStyle(.plain)
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(16)
            }
        }
        .navigationTitle("Gyms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Request") { appState.showingRequestGym = true } } }
    }
}

enum ForumInboxSegment: String, CaseIterable, Identifiable {
    case activity = "Activity"
    case messages = "Messages"
    case requests = "Requests"
    var id: String { rawValue }
}

struct ForumInboxView: View {
    @EnvironmentObject private var appState: AppState
    @State private var segment: ForumInboxSegment = .activity
    @State private var deleteThread: DirectMessageThread?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inbox section", selection: $segment) {
                ForEach(ForumInboxSegment.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    switch segment {
                    case .activity: activity
                    case .messages: messages
                    case .requests: requests
                    }
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("Delete this conversation?", isPresented: Binding(
            get: { deleteThread != nil }, set: { if !$0 { deleteThread = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Conversation", role: .destructive) {
                if let deleteThread { appState.deleteMessageThread(deleteThread) }
                deleteThread = nil
            }
            Button("Cancel", role: .cancel) { deleteThread = nil }
        } message: { Text("This removes the conversation and all messages from this device.") }
    }

    @ViewBuilder
    private var activity: some View {
        let notifications = appState.forumNotifications.sorted { $0.createdAt > $1.createdAt }
        if notifications.isEmpty {
            LiftEmptyState(title: "No forum activity", message: "Replies, mentions, watched-post updates, and moderation decisions appear here.", symbolName: "bell")
                .padding(.top, 40)
        } else {
            ForEach(notifications) { notification in
                Button { appState.openForumNotification(notification) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: notificationSymbol(notification.kind))
                            .foregroundStyle(notification.isRead ? Color.liftMuted : Color.liftBlue)
                            .frame(width: 38, height: 38)
                            .background((notification.isRead ? Color.liftMuted : Color.liftBlue).opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(notification.title).font(.subheadline.weight(.bold)).foregroundStyle(Color.liftText)
                                Spacer()
                                Text(LiftTimeFormatter.relativeNoSeconds(from: notification.createdAt))
                                    .font(.caption2).foregroundStyle(Color.liftMuted)
                            }
                            Text(notification.message).font(.caption).foregroundStyle(Color.liftMuted).multilineTextAlignment(.leading)
                        }
                        if !notification.isRead { Circle().fill(Color.liftBlue).frame(width: 7, height: 7).padding(.top, 6) }
                    }
                    .padding(13).liftSurface(radius: 13)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var messages: some View {
        if !appState.incomingFriendRequests.isEmpty {
            CompactSectionHeader(title: "Friend requests")
            ForEach(appState.incomingFriendRequests) { request in
                if let profile = appState.profile(id: request.fromUserID) {
                    HStack(spacing: 12) {
                        ProfileAvatar(profile: profile, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.displayName).font(.subheadline.weight(.bold))
                            Text("@\(profile.username) wants to connect").font(.caption).foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Button("Decline", role: .destructive) { appState.declineFriendRequest(request) }.buttonStyle(.bordered)
                        Button("Accept") { appState.acceptFriendRequest(request) }.buttonStyle(.borderedProminent)
                    }
                    .font(.caption.weight(.bold)).padding(13).liftSurface(radius: 13)
                }
            }
        }

        if !appState.friends.isEmpty {
            CompactSectionHeader(title: "Friends", eyebrow: "Start a conversation")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.friends) { profile in
                        Button { appState.openMessageThread(with: profile) } label: {
                            VStack(spacing: 6) {
                                ProfileAvatar(profile: profile, size: 44)
                                Text(profile.displayName).font(.caption2.weight(.semibold)).foregroundStyle(Color.liftText).lineLimit(1)
                            }
                            .frame(width: 74).padding(.vertical, 10).liftSurface(radius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        CompactSectionHeader(title: "Conversations")
        if appState.messageThreads.isEmpty {
            LiftEmptyState(title: "No messages", message: "Only accepted friends can start a direct conversation.", symbolName: "message")
        } else {
            VStack(spacing: 0) {
                ForEach(appState.messageThreads.sorted { $0.updatedAt > $1.updatedAt }) { thread in
                    let profile = appState.otherParticipant(in: thread)
                    Button { appState.selectedMessageThread = thread } label: {
                        HStack(spacing: 12) {
                            if let profile { ProfileAvatar(profile: profile, size: 42) }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(profile?.displayName ?? "Conversation").font(.subheadline.weight(.bold)).foregroundStyle(Color.liftText)
                                    Spacer(); Text(LiftTimeFormatter.relativeNoSeconds(from: thread.updatedAt)).font(.caption2).foregroundStyle(Color.liftMuted)
                                }
                                Text(appState.lastMessage(in: thread)?.body ?? "No messages yet")
                                    .font(.caption).foregroundStyle(Color.liftMuted).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.liftMuted)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Delete Conversation", role: .destructive) { deleteThread = thread } }
                    if thread.id != appState.messageThreads.sorted(by: { $0.updatedAt > $1.updatedAt }).last?.id {
                        Divider().overlay(Color.liftSeparator).padding(.leading, 54)
                    }
                }
            }
            .padding(.horizontal, 13).liftSurface(radius: 14)
        }
    }

    @ViewBuilder
    private var requests: some View {
        let mine = appState.forumJoinRequests.filter { $0.userID == appState.currentProfile.id && $0.status == "Pending" }
        let staff = appState.forumJoinRequests.filter {
            $0.status == "Pending" && appState.canModerateForumCommunity($0.communityID)
        }
        if mine.isEmpty && staff.isEmpty && appState.outgoingFriendRequests.isEmpty {
            LiftEmptyState(title: "No pending requests", message: "Restricted-community and friend requests appear here.", symbolName: "person.badge.clock")
                .padding(.top, 40)
        }
        if !mine.isEmpty {
            CompactSectionHeader(title: "My membership requests")
            ForEach(mine) { request in requestRow(request, staffControls: false) }
        }
        if !staff.isEmpty {
            CompactSectionHeader(title: "Community approvals", eyebrow: "Moderator")
            ForEach(staff) { request in requestRow(request, staffControls: true) }
        }
        if !appState.outgoingFriendRequests.isEmpty {
            CompactSectionHeader(title: "Sent friend requests")
            ForEach(appState.outgoingFriendRequests) { request in
                HStack {
                    Text(appState.profile(id: request.toUserID)?.displayName ?? "Lifter").font(.subheadline.weight(.semibold))
                    Spacer(); Text("Pending").font(.caption).foregroundStyle(Color.liftGold)
                    Button("Cancel", role: .destructive) { appState.cancelFriendRequest(request) }.buttonStyle(.bordered)
                }
                .padding(13).liftSurface(radius: 13)
            }
        }
    }

    private func requestRow(_ request: ForumJoinRequest, staffControls: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape.fill").foregroundStyle(Color.liftBlue)
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.forumCommunity(request.communityID)?.name ?? "Community").font(.subheadline.weight(.bold))
                Text(staffControls ? (appState.profile(id: request.userID)?.displayName ?? "Member") : "Awaiting staff review")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                if !request.note.isEmpty { Text(request.note).font(.caption2).foregroundStyle(Color.liftMuted).lineLimit(2) }
            }
            Spacer()
            if staffControls {
                Button("Decline", role: .destructive) { appState.resolveForumJoinRequest(request.id, approved: false) }.buttonStyle(.bordered)
                Button("Approve") { appState.resolveForumJoinRequest(request.id, approved: true) }.buttonStyle(.borderedProminent)
            }
        }
        .font(.caption.weight(.bold)).padding(13).liftSurface(radius: 13)
    }

    private func notificationSymbol(_ kind: ForumNotificationKind) -> String {
        switch kind {
        case .reply: return "arrowshape.turn.up.left.fill"
        case .mention: return "at"
        case .watchedPost: return "bell.badge.fill"
        case .moderation: return "shield.fill"
        case .membership: return "person.badge.checkmark.fill"
        }
    }
}
