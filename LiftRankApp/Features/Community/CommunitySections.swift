import AVKit
import SwiftUI

extension CommunityView {
    var communityHeader: some View {
        HStack {
            Text("Community")
                .font(.title2.weight(.black))
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .accessibilityIdentifier("community-header")
    }

    var communityTabBar: some View {
        HStack(spacing: 28) {
            ForEach(["Feed", "Messages", "Gyms"], id: \.self) { segment in
                Button {
                    Haptics.light()
                    appState.selectedCommunitySegment = segment
                } label: {
                    VStack(spacing: 9) {
                        HStack(spacing: 5) {
                            Text(segment)
                                .font(.subheadline.weight(appState.selectedCommunitySegment == segment ? .bold : .medium))
                            if segment == "Messages" && !appState.incomingFriendRequests.isEmpty {
                                Circle()
                                    .fill(Color.liftRed)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        Rectangle()
                            .fill(appState.selectedCommunitySegment == segment ? Color.liftBlue : .clear)
                            .frame(height: 2)
                    }
                    .foregroundStyle(appState.selectedCommunitySegment == segment ? .white : Color.liftMuted)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(appState.selectedCommunitySegment == segment ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
        .accessibilityIdentifier("community-tabs")
    }

    var feed: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                topicRail
                    .padding(.bottom, 2)
                ForEach(feedItems) { item in
                    switch item {
                    case .thread(let thread):
                        editorialThreadCard(thread)
                    case .activity(let activity):
                        editorialActivityCard(activity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 92)
        }
        .scrollIndicators(.hidden)
    }

    var feedItems: [CommunityFeedItem] {
        CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: selectedTopic
        )
    }

    var topicRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommunityTopic.allCases) { topic in
                    Button {
                        Haptics.light()
                        selectedTopic = topic
                    } label: {
                        Label(topic.rawValue, systemImage: topic.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedTopic == topic ? .white : Color.liftMuted)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 42)
                            .background(selectedTopic == topic ? Color.liftBlue : Color.liftCardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTopic == topic ? .isSelected : [])
                }
            }
        }
    }

    func editorialThreadCard(_ thread: CommunityThread) -> some View {
        let currentThread = appState.currentThread(thread)
        let profile = appState.profile(id: currentThread.authorID)
        return VStack(alignment: .leading, spacing: 13) {
            authorHeader(profile: profile, fallbackName: currentThread.authorName, date: currentThread.createdAt)
            Button {
                appState.selectedCommunityThread = currentThread
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(currentThread.kind.rawValue, systemImage: currentThread.kind == .gym ? "building.2.fill" : "bubble.left.and.bubble.right.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                    if currentThread.isLocked {
                        Label("Locked", systemImage: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftGold)
                    }
                    Text(currentThread.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftText)
                    if !currentThread.body.isEmpty {
                        Text(currentThread.body)
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            HStack(spacing: 22) {
                voteControls(for: currentThread)
                Button {
                    appState.selectedCommunityThread = currentThread
                } label: {
                    Label("\(currentThread.replyCount)", systemImage: "bubble.left")
                }
                ShareLink(item: "\(currentThread.title)\n\(currentThread.body)") {
                    Image(systemName: "square.and.arrow.up")
                }
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        communityReportTarget = CommunityReportDraft(id: currentThread.id, type: .thread, title: currentThread.title)
                    } label: {
                        Label("Report Thread", systemImage: "flag")
                    }
                    if appState.isForumStaff {
                        Button(currentThread.isLocked ? "Unlock Thread" : "Lock Thread") {
                            appState.moderateThread(currentThread, operation: currentThread.isLocked ? .unlock : .lock)
                        }
                        Button(role: .destructive) {
                            appState.moderateThread(currentThread, operation: .remove, reason: "Removed from community feed.")
                        } label: {
                            Label("Remove Thread", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
            .buttonStyle(.plain)
        }
        .communityPostStyle()
    }

    func editorialActivityCard(_ activity: ActivityItem) -> some View {
        let currentActivity = appState.currentActivity(activity)
        let lift = currentActivity.liftID.flatMap { id in appState.lifts.first { $0.id == id } }
        let commentCount = appState.comments(for: currentActivity).count
        return VStack(alignment: .leading, spacing: 13) {
            authorHeader(profile: currentActivity.profile, fallbackName: currentActivity.profile.displayName, date: currentActivity.createdAt)
            Button {
                appState.selectedActivity = currentActivity
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentActivity.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.liftText)
                    Text(currentActivity.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(3)
                    if let lift { liftSummaryPanel(lift) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            HStack(spacing: 22) {
                Button { appState.toggleActivityLike(currentActivity) } label: {
                    Label(currentActivity.isLiked ? "Supported" : "Support", systemImage: currentActivity.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundStyle(currentActivity.isLiked ? Color.liftBlue : Color.liftMuted)
                }
                Button { appState.selectedActivity = currentActivity } label: {
                    Label("\(commentCount)", systemImage: "bubble.left")
                }
                Button { appState.toggleActivitySave(currentActivity) } label: {
                    Image(systemName: currentActivity.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(currentActivity.isSaved ? Color.liftBlue : Color.liftMuted)
                }
                ShareLink(item: "\(currentActivity.title)\n\(currentActivity.detail)") {
                    Image(systemName: "square.and.arrow.up")
                }
                Spacer()
                Button { appState.showingReportLift = true } label: { Image(systemName: "ellipsis") }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
            .buttonStyle(.plain)
        }
        .communityPostStyle()
    }

    @ViewBuilder
    func liftSummaryPanel(_ lift: LiftSubmission) -> some View {
        if let url = lift.localVideoURL ?? lift.remoteVideoURL, lift.visibility != .privateLift {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 14) {
                Image(systemName: liftSymbol(lift))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 58, height: 58)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(lift.exerciseName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftText)
                    Text(MeasurementFormatting.liftSetText(weightKilograms: lift.weight, unit: lift.unit, repetitions: lift.repetitions))
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.liftText)
                    Text("\(lift.resolvedEvidenceStatus.displayName) • \(gymName(for: lift))")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.liftBackground.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    func authorHeader(profile: UserProfile?, fallbackName: String, date: Date) -> some View {
        HStack(spacing: 10) {
            if let profile {
                Button { appState.selectedProfile = profile } label: { ProfileAvatar(profile: profile, size: 44) }
                    .buttonStyle(.plain)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.liftMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(profile?.displayName ?? fallbackName)
                        .font(.subheadline.weight(.bold))
                    if profile != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.liftBlue)
                    }
                    Text("• \(LiftTimeFormatter.relativeNoSeconds(from: date))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                if let profile {
                    Text("@\(profile.username) • \(profile.followers) followers")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            Spacer()
            if let profile { friendAction(for: profile) }
        }
    }

    @ViewBuilder
    func friendAction(for profile: UserProfile) -> some View {
        if profile.id != appState.currentProfile.id {
            let request = appState.friendRequest(with: profile)
            Button {
                if request?.status == .accepted {
                    appState.openMessageThread(with: profile)
                } else if request?.status == .pending, request?.fromUserID == appState.currentProfile.id, let request {
                    appState.cancelFriendRequest(request)
                } else if request?.status == .pending, request?.toUserID == appState.currentProfile.id, let request {
                    appState.acceptFriendRequest(request)
                } else if appState.canSendFriendRequest(to: profile) {
                    appState.sendFriendRequest(to: profile)
                }
            } label: {
                Text(request?.status == .accepted ? "Message" : appState.friendActionTitle(for: profile))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(request?.status == .pending ? Color.liftCardRaised : Color.liftBlue)
                    .foregroundStyle(request?.status == .pending ? Color.liftMuted : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(request?.status == .pending && request?.fromUserID == appState.currentProfile.id ? "Double tap to cancel this friend request" : "")
        }
    }

    func liftSymbol(_ lift: LiftSubmission) -> String {
        switch lift.exerciseID {
        case "bench": return "figure.strengthtraining.traditional"
        case "squat": return "figure.strengthtraining.functional"
        case "deadlift": return "dumbbell.fill"
        default: return "figure.strengthtraining.traditional"
        }
    }

    func gymName(for lift: LiftSubmission) -> String {
        appState.gyms.first(where: { $0.id == lift.gymID })?.name ?? "Gym"
    }

    var messages: some View {
        VStack(alignment: .leading, spacing: 18) {
            if appState.incomingFriendRequests.isEmpty && appState.outgoingFriendRequests.isEmpty && appState.friends.isEmpty {
                emptySocialCard(title: "No friend activity yet", message: "Open a lifter profile from the leaderboard to add a friend or start a message.")
            }
            if !appState.incomingFriendRequests.isEmpty {
                SectionHeader(title: "Friend Requests")
                ForEach(appState.incomingFriendRequests) { request in
                    friendRequestCard(request)
                }
            }
            if !appState.outgoingFriendRequests.isEmpty {
                SectionHeader(title: "Sent Requests")
                ForEach(appState.outgoingFriendRequests) { request in
                    if let profile = appState.profile(id: request.toUserID) {
                        HStack(spacing: 12) {
                            ProfileAvatar(profile: profile, size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.displayName)
                                    .font(.subheadline.weight(.bold))
                                Text("Request pending")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer(minLength: 8)
                            Button("Cancel", role: .destructive) {
                                appState.cancelFriendRequest(request)
                            }
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .buttonStyle(.bordered)
                            .tint(Color.liftRed)
                        }
                        .compactSocialCardStyle()
                    }
                }
            }
            if !appState.friends.isEmpty {
                SectionHeader(title: "Start a conversation")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.friends) { profile in
                            friendChip(profile)
                        }
                    }
                }
            }

            HStack {
                Text("Inbox")
                    .font(.title3.weight(.black))
                Spacer()
                Text("\(appState.messageThreads.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.liftBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Capsule())
            }

            if appState.messageThreads.isEmpty {
                emptySocialCard(title: "No messages", message: "Message a lifter from their profile to start a conversation.")
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedMessageThreads) { thread in
                        messageThreadCard(thread)
                        if thread.id != sortedMessageThreads.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.07))
                                .padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }

    var sortedMessageThreads: [DirectMessageThread] {
        appState.messageThreads.sorted { $0.updatedAt > $1.updatedAt }
    }

    var gyms: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Community gyms")
                        .font(.title3.weight(.black))
                    Text("Join up to \(AppState.maximumJoinedGyms) gyms and compare verified lifts")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Text("\(appState.joinedGymCount)/\(AppState.maximumJoinedGyms)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.liftBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.liftMuted)
                TextField("Search gyms or cities", text: $gymSearch)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                if !gymSearch.isEmpty {
                    Button { gymSearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(12)
            .background(Color.liftCardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !appState.gymRequests.isEmpty {
                SectionHeader(title: "Recent gym requests")
                ForEach(appState.gymRequests.prefix(3)) { request in
                    LiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Submitted", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGreen)
                                Spacer()
                                Text(request.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Text(request.name)
                                .font(.headline)
                            Text("\(request.city), \(request.state)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                }
            }
            ForEach(filteredCommunityGyms) { gym in
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(gym.name)
                                    .font(.headline)
                                Text("\(gym.city), \(gym.state)")
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer()
                            Button("Open") {
                                appState.selectedGym = gym
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.liftBlue)
                        }
                        HStack {
                            metric("Members", "\(gym.memberCount)")
                            metric("Verified lifts", "\(gym.verifiedLiftCount)")
                            metric("Membership", appState.isGymJoined(gym) ? "Joined" : "Open")
                        }
                    }
                }
            }
            PrimaryButton(title: "Request New Gym", symbolName: "plus") {
                Haptics.light()
                appState.showingRequestGym = true
            }
        }
    }

    var filteredCommunityGyms: [Gym] {
        let query = gymSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.gyms }
        return appState.gyms.filter {
            $0.name.lowercased().contains(query) ||
            $0.city.lowercased().contains(query) ||
            $0.state.lowercased().contains(query)
        }
    }

    func action(_ label: String, _ symbol: String) -> some View {
        Button {
            Haptics.light()
        } label: {
            Image(systemName: symbol)
                .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Color.liftMuted)
    }

    func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func friendRequestCard(_ request: FriendRequest) -> some View {
        Group {
            if let profile = appState.profile(id: request.fromUserID) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                    ProfileAvatar(profile: profile, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.subheadline.weight(.bold))
                        Text("@\(profile.username) wants to connect")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    }
                    HStack(spacing: 10) {
                        Spacer()
                        Button("Decline") {
                            appState.declineFriendRequest(request)
                        }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 92, minHeight: 40)
                        .buttonStyle(.bordered)
                        .tint(Color.liftRed)
                        Button("Accept") {
                            appState.acceptFriendRequest(request)
                        }
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 92, minHeight: 40)
                        .buttonStyle(LiftCompactProminentButtonStyle())
                    }
                }
                .compactSocialCardStyle()
                .accessibilityIdentifier("friend-request-card")
            }
        }
    }

    func friendChip(_ profile: UserProfile) -> some View {
        Button {
            appState.openMessageThread(with: profile)
        } label: {
            VStack(spacing: 7) {
                ProfileAvatar(profile: profile, size: 48)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.liftGreen)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle().stroke(Color.liftCard, lineWidth: 2)
                            }
                    }
                Text(profile.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftText)
                    .lineLimit(1)
            }
            .frame(width: 68)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Message \(profile.displayName)")
    }

    func messageThreadCard(_ thread: DirectMessageThread) -> some View {
        let profile = appState.otherParticipant(in: thread)
        let lastMessage = appState.lastMessage(in: thread)
        return Button {
            appState.selectedMessageThread = thread
        } label: {
            HStack(spacing: 12) {
                if let profile {
                    ProfileAvatar(profile: profile, size: 46)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.liftMuted)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile?.displayName ?? "Unknown lifter")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftText)
                        Spacer()
                        Text(LiftTimeFormatter.relativeNoSeconds(from: thread.updatedAt))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(1)
                    }
                    Text(lastMessage?.body ?? "Start the conversation")
                        .font(.subheadline)
                        .foregroundStyle(lastMessage == nil ? Color.liftBlue : Color.liftMuted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("inbox-thread-row")
        .contextMenu {
            Button(role: .destructive) {
                conversationDeleteTarget = thread
            } label: {
                Label("Delete Conversation", systemImage: "trash")
            }
        }
    }

    func emptySocialCard(title: String, message: String) -> some View {
        LiftEmptyState(title: title, message: message, symbolName: "person.2.slash")
    }

    func threadCard(_ thread: CommunityThread) -> some View {
        let currentThread = appState.currentThread(thread)
        return LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    appState.selectedCommunityThread = currentThread
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(currentThread.kind.rawValue, systemImage: currentThread.kind == .gym ? "building.2.fill" : "bubble.left.and.bubble.right.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftBlue)
                            Spacer()
                            Text(LiftTimeFormatter.relativeNoSeconds(from: currentThread.createdAt))
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Text(currentThread.title)
                            .font(.headline)
                            .foregroundStyle(Color.liftText)
                        if !currentThread.body.isEmpty {
                            Text(currentThread.body)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)
                HStack {
                    Button {
                        appState.selectedCommunityThread = currentThread
                    } label: {
                        Label("\(currentThread.replyCount)", systemImage: "bubble.left")
                    }
                    .buttonStyle(.plain)
                    voteControls(for: currentThread)
                    Spacer()
                    Text(currentThread.authorName)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            }
        }
    }

    func voteControls(for thread: CommunityThread) -> some View {
        HStack(spacing: 7) {
            Button {
                appState.voteThread(thread, vote: appState.threadVote(for: thread) == .up ? nil : .up)
            } label: {
                Image(systemName: appState.threadVote(for: thread) == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
            }
            Text("\(thread.voteScore)")
                .font(.caption.weight(.black))
                .foregroundStyle(thread.voteScore < 0 ? Color.liftRed : Color.liftGreen)
            Button {
                appState.voteThread(thread, vote: appState.threadVote(for: thread) == .down ? nil : .down)
            } label: {
                Image(systemName: appState.threadVote(for: thread) == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.liftMuted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thread score \(thread.voteScore)")
    }
}

extension CommunityView {
    var featureBody: some View {
        AppBackground {
            VStack(spacing: 0) {
                communityHeader
                communityTabBar
                if appState.selectedCommunitySegment == "Feed" {
                    feed
                } else {
                    ScrollView {
                        Group {
                            if appState.selectedCommunitySegment == "Messages" {
                                messages
                            } else {
                                gyms
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 108)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("community-section-scroll")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                if appState.selectedCommunitySegment == "Feed" {
                    Button {
                        Haptics.light()
                        appState.showingCreateThread = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Color.liftBlue)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(Color.white.opacity(0.12), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start a community thread")
                    .padding(.trailing, 20)
                    .padding(.bottom, 18)
                }
            }
            .confirmationDialog(
                "Delete this conversation?",
                isPresented: Binding(
                    get: { conversationDeleteTarget != nil },
                    set: { if !$0 { conversationDeleteTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Conversation", role: .destructive) {
                    if let conversationDeleteTarget {
                        appState.deleteMessageThread(conversationDeleteTarget)
                    }
                    conversationDeleteTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    conversationDeleteTarget = nil
                }
            } message: {
                Text("This removes the conversation and all of its messages from your inbox.")
            }
            .sheet(item: $communityReportTarget) { target in
                ReportCommunityView(target: target)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
        }
    }
}
