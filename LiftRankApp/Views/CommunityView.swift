import AVKit
import SwiftUI

enum CommunityTopic: String, CaseIterable, Identifiable {
    case all = "All"
    case bench = "Bench"
    case squat = "Squat"
    case deadlift = "Deadlift"
    case personalRecords = "PRs"
    case gym = "Gym"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "line.3.horizontal"
        case .bench: return "figure.strengthtraining.traditional"
        case .squat: return "figure.strengthtraining.functional"
        case .deadlift: return "dumbbell.fill"
        case .personalRecords: return "trophy.fill"
        case .gym: return "building.2.fill"
        }
    }
}

enum CommunityFeedItem: Identifiable {
    case thread(CommunityThread)
    case activity(ActivityItem)

    var id: String {
        switch self {
        case .thread(let thread): return "thread-\(thread.id.uuidString)"
        case .activity(let activity): return "activity-\(activity.id.uuidString)"
        }
    }

    var createdAt: Date {
        switch self {
        case .thread(let thread): return thread.createdAt
        case .activity(let activity): return activity.createdAt
        }
    }
}

enum CommunityFeedBuilder {
    static func items(
        threads: [CommunityThread],
        activities: [ActivityItem],
        lifts: [LiftSubmission],
        topic: CommunityTopic
    ) -> [CommunityFeedItem] {
        let liftByID = Dictionary(uniqueKeysWithValues: lifts.map { ($0.id, $0) })
        let threadItems = threads
            .filter { $0.kind == .general || $0.kind == .gym }
            .filter { matches(thread: $0, topic: topic) }
            .map(CommunityFeedItem.thread)
        let activityItems = activities
            .filter { !$0.title.localizedCaseInsensitiveContains("started a thread") && !$0.title.localizedCaseInsensitiveContains("replied to") }
            .filter { matches(activity: $0, lift: $0.liftID.flatMap { liftByID[$0] }, topic: topic) }
            .map(CommunityFeedItem.activity)
        return (threadItems + activityItems).sorted { $0.createdAt > $1.createdAt }
    }

    private static func matches(thread: CommunityThread, topic: CommunityTopic) -> Bool {
        let text = "\(thread.title) \(thread.body)".lowercased()
        switch topic {
        case .all: return true
        case .bench: return text.contains("bench")
        case .squat: return text.contains("squat")
        case .deadlift: return text.contains("deadlift") || text.contains("pull")
        case .personalRecords: return text.contains(" pr") || text.contains("record")
        case .gym: return thread.kind == .gym
        }
    }

    private static func matches(activity: ActivityItem, lift: LiftSubmission?, topic: CommunityTopic) -> Bool {
        switch topic {
        case .all: return true
        case .bench: return lift?.exerciseID == "bench"
        case .squat: return lift?.exerciseID == "squat"
        case .deadlift: return lift?.exerciseID == "deadlift"
        case .personalRecords: return lift?.isActualOneRepMax == true
        case .gym: return lift != nil
        }
    }
}

private extension View {
    func communityPostStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    func compactSocialCardStyle() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var conversationDeleteTarget: DirectMessageThread?
    @State private var selectedTopic: CommunityTopic = .all
    @State private var gymSearch = ""

    var body: some View {
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
                            .frame(width: 58, height: 58)
                            .background(Color.liftBlue)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.32), radius: 14, y: 6)
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
        }
    }

    private var communityHeader: some View {
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

    private var communityTabBar: some View {
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

    private var feed: some View {
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

    private var feedItems: [CommunityFeedItem] {
        CommunityFeedBuilder.items(
            threads: appState.communityThreads,
            activities: appState.activities,
            lifts: appState.lifts,
            topic: selectedTopic
        )
    }

    private var topicRail: some View {
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

    private func editorialThreadCard(_ thread: CommunityThread) -> some View {
        let currentThread = appState.currentThread(thread)
        let profile = appState.profile(id: currentThread.authorID)
        let isLiked = appState.isThreadLiked(currentThread)
        return VStack(alignment: .leading, spacing: 13) {
            authorHeader(profile: profile, fallbackName: currentThread.authorName, date: currentThread.createdAt)
            Button {
                appState.selectedCommunityThread = currentThread
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(currentThread.kind.rawValue, systemImage: currentThread.kind == .gym ? "building.2.fill" : "bubble.left.and.bubble.right.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                    Text(currentThread.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
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
                Button {
                    appState.toggleThreadLike(currentThread)
                } label: {
                    Label("\(currentThread.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? Color.liftRed : Color.liftMuted)
                }
                Button {
                    appState.selectedCommunityThread = currentThread
                } label: {
                    Label("\(currentThread.replyCount)", systemImage: "bubble.left")
                }
                ShareLink(item: "\(currentThread.title)\n\(currentThread.body)") {
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

    private func editorialActivityCard(_ activity: ActivityItem) -> some View {
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
                        .foregroundStyle(.white)
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
                    Label(currentActivity.isLiked ? "Liked" : "Like", systemImage: currentActivity.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(currentActivity.isLiked ? Color.liftRed : Color.liftMuted)
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
    private func liftSummaryPanel(_ lift: LiftSubmission) -> some View {
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
                        .foregroundStyle(.white)
                    Text("\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) × \(lift.repetitions)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("\(lift.verificationStatus.rawValue) • \(gymName(for: lift))")
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

    private func authorHeader(profile: UserProfile?, fallbackName: String, date: Date) -> some View {
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
    private func friendAction(for profile: UserProfile) -> some View {
        if profile.id != appState.currentProfile.id {
            let request = appState.friendRequest(with: profile)
            Button {
                if request?.status == .accepted {
                    appState.openMessageThread(with: profile)
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
            .disabled(request?.status == .pending && request?.fromUserID == appState.currentProfile.id)
        }
    }

    private func liftSymbol(_ lift: LiftSubmission) -> String {
        switch lift.exerciseID {
        case "bench": return "figure.strengthtraining.traditional"
        case "squat": return "figure.strengthtraining.functional"
        case "deadlift": return "dumbbell.fill"
        default: return "figure.strengthtraining.traditional"
        }
    }

    private func gymName(for lift: LiftSubmission) -> String {
        appState.gyms.first(where: { $0.id == lift.gymID })?.name ?? "Gym"
    }

    private var messages: some View {
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

    private var sortedMessageThreads: [DirectMessageThread] {
        appState.messageThreads.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var gyms: some View {
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

    private var filteredCommunityGyms: [Gym] {
        let query = gymSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.gyms }
        return appState.gyms.filter {
            $0.name.lowercased().contains(query) ||
            $0.city.lowercased().contains(query) ||
            $0.state.lowercased().contains(query)
        }
    }

    private func action(_ label: String, _ symbol: String) -> some View {
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

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func friendRequestCard(_ request: FriendRequest) -> some View {
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
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftBlue)
                    }
                }
                .compactSocialCardStyle()
                .accessibilityIdentifier("friend-request-card")
            }
        }
    }

    private func friendChip(_ profile: UserProfile) -> some View {
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(width: 68)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Message \(profile.displayName)")
    }

    private func messageThreadCard(_ thread: DirectMessageThread) -> some View {
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
                            .foregroundStyle(.white)
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

    private func emptySocialCard(title: String, message: String) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func threadCard(_ thread: CommunityThread) -> some View {
        let currentThread = appState.currentThread(thread)
        let isLiked = appState.isThreadLiked(currentThread)
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
                            .foregroundStyle(.white)
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
                    Button {
                        appState.toggleThreadLike(currentThread)
                    } label: {
                        Label("\(currentThread.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? Color.liftRed : Color.liftMuted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(currentThread.authorName)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            }
        }
    }
}

struct CommunityThreadDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let thread: CommunityThread
    @State private var replyText = ""

    private var currentThread: CommunityThread {
        appState.currentThread(thread)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(currentThread.kind.rawValue, systemImage: currentThread.kind == .gym ? "building.2.fill" : "bubble.left.and.bubble.right.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftBlue)
                                    Text(currentThread.title)
                                        .font(.title2.bold())
                                    if !currentThread.body.isEmpty {
                                        Text(currentThread.body)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    HStack {
                                        Button {
                                            appState.toggleThreadLike(currentThread)
                                        } label: {
                                            Label("\(currentThread.likeCount) likes", systemImage: appState.isThreadLiked(currentThread) ? "heart.fill" : "heart")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(appState.isThreadLiked(currentThread) ? Color.liftRed : Color.liftBlue)
                                        Label("\(currentThread.replyCount) comments", systemImage: "bubble.left")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }

                            SectionHeader(title: "Comments")
                            let replies = appState.replies(for: currentThread)
                            if replies.isEmpty {
                                emptyThreadCommentCard
                            } else {
                                ForEach(replies) { reply in
                                    threadReplyCard(reply)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    commentComposer
                }
            }
            .navigationTitle("Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyThreadCommentCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("No comments yet")
                    .font(.headline)
                Text("Start the conversation with a reply.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func threadReplyCard(_ reply: CommunityThreadReply) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(reply.authorName)
                        .font(.headline)
                    Spacer()
                    Text(LiftTimeFormatter.relativeNoSeconds(from: reply.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text(reply.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var commentComposer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                appState.addReply(to: currentThread, body: replyText)
                replyText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftBlue)
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Post comment")
        }
        .padding()
        .background(Color.liftBackground)
    }
}

struct ActivityDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let activity: ActivityItem
    @State private var commentText = ""

    private var currentActivity: ActivityItem {
        appState.currentActivity(activity)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        ProfileAvatar(profile: currentActivity.profile, size: 48)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(currentActivity.title)
                                                .font(.title3.bold())
                                            Text(LiftTimeFormatter.relativeNoSeconds(from: currentActivity.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                    Text(currentActivity.detail)
                                        .foregroundStyle(Color.liftMuted)
                                    HStack {
                                        Button {
                                            appState.toggleActivityLike(currentActivity)
                                        } label: {
                                            Label(currentActivity.isLiked ? "Liked" : "Like", systemImage: currentActivity.isLiked ? "heart.fill" : "heart")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(currentActivity.isLiked ? Color.liftRed : Color.liftBlue)
                                        Button {
                                            appState.toggleActivitySave(currentActivity)
                                        } label: {
                                            Label(currentActivity.isSaved ? "Saved" : "Save", systemImage: currentActivity.isSaved ? "bookmark.fill" : "bookmark")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftBlue)
                                        Label("\(appState.comments(for: currentActivity).count) comments", systemImage: "bubble.left")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }

                            SectionHeader(title: "Comments")
                            let comments = appState.comments(for: currentActivity)
                            if comments.isEmpty {
                                emptyActivityCommentCard
                            } else {
                                ForEach(comments) { comment in
                                    activityCommentCard(comment)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    activityComposer
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyActivityCommentCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("No comments yet")
                    .font(.headline)
                Text("Add the first comment.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activityCommentCard(_ comment: ActivityComment) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(comment.authorName)
                        .font(.headline)
                    Spacer()
                    Text(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text(comment.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var activityComposer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                appState.addComment(to: currentActivity, body: commentText)
                commentText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftBlue)
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Post comment")
        }
        .padding()
        .background(Color.liftBackground)
    }
}

struct DirectMessageThreadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let thread: DirectMessageThread
    @State private var draftMessage = ""
    @State private var reportTarget: DirectMessage?
    @State private var deleteTarget: DirectMessage?
    @State private var showingDeleteConversation = false

    private var currentThread: DirectMessageThread {
        appState.messageThreads.first { $0.id == thread.id } ?? thread
    }

    private var participant: UserProfile? {
        appState.otherParticipant(in: currentThread)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    conversationHeader

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            let messages = appState.messages(for: currentThread)
                            if messages.isEmpty {
                                emptyConversation
                            } else {
                                ForEach(messages) { message in
                                    messageBubble(message)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)

                    composer
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $reportTarget) { message in
                ReportMessageView(message: message)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Delete this message?",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Message", role: .destructive) {
                    if let deleteTarget {
                        appState.deleteMessage(deleteTarget)
                    }
                    deleteTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                Text("This message will be permanently removed from the conversation.")
            }
            .confirmationDialog(
                "Delete this conversation?",
                isPresented: $showingDeleteConversation,
                titleVisibility: .visible
            ) {
                Button("Delete Conversation", role: .destructive) {
                    appState.deleteMessageThread(currentThread)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every message in this conversation from your inbox.")
            }
        }
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close conversation")

            if let participant {
                ProfileAvatar(profile: participant, size: 44)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(participant?.displayName ?? "Messages")
                    .font(.headline.weight(.black))
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.liftGreen)
                        .frame(width: 7, height: 7)
                    Text(participant.map { "@\($0.username)" } ?? "LiftRank member")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }

            Spacer()

            Menu {
                if let participant {
                    Button {
                        appState.selectedProfile = participant
                    } label: {
                        Label("View Profile", systemImage: "person.crop.circle")
                    }
                }
                Button(role: .destructive) {
                    showingDeleteConversation = true
                } label: {
                    Label("Delete Conversation", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Conversation options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.liftBackground.opacity(0.96))
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06))
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                Haptics.light()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Message attachments")

            TextField("Write a message…", text: $draftMessage, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }

            Button {
                appState.sendMessage(in: currentThread, body: draftMessage)
                draftMessage = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftBackground)
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
    }

    private var emptyConversation: some View {
        VStack(spacing: 14) {
            if let participant {
                ProfileAvatar(profile: participant, size: 76)
            }
            Text("Start a conversation")
                .font(.title3.weight(.black))
            Text("Send a message to \(participant?.displayName ?? "this lifter") about training, rankings, or your next gym session.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal, 28)
    }

    private func messageBubble(_ message: DirectMessage) -> some View {
        let isCurrentUser = message.senderID == appState.currentProfile.id
        return HStack(alignment: .bottom) {
            if isCurrentUser { Spacer(minLength: 42) }

            if !isCurrentUser, let participant {
                ProfileAvatar(profile: participant, size: 28)
                    .padding(.bottom, 18)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 5) {
                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(isCurrentUser ? Color.liftBackground : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(isCurrentUser ? Color.liftBlue : Color.liftCardRaised)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: isCurrentUser ? 18 : 5,
                            bottomTrailingRadius: isCurrentUser ? 5 : 18,
                            topTrailingRadius: 18
                        )
                    )

                HStack(spacing: 6) {
                    Text(LiftTimeFormatter.messageTime(message.createdAt))
                    if message.isReported {
                        Label("Reported", systemImage: "flag.fill")
                    }
                    if isCurrentUser {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            }
            .contextMenu {
                Button(role: .destructive) {
                    deleteTarget = message
                } label: {
                    Label("Delete Message", systemImage: "trash")
                }
                if !isCurrentUser {
                    Button(role: .destructive) {
                        reportTarget = message
                    } label: {
                        Label("Report Message", systemImage: "exclamationmark.bubble")
                    }
                }
            }

            if !isCurrentUser { Spacer(minLength: 42) }
        }
    }
}

struct ReportMessageView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let message: DirectMessage
    @State private var reason: MessageReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Reason") {
                        Picker("Reason", selection: $reason) {
                            ForEach(MessageReportReason.allCases) { reason in
                                Text(reason.rawValue).tag(reason)
                            }
                        }
                    }
                    Section("Message") {
                        Text(message.body)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Section("Optional note") {
                        TextField("Add context for moderators", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.reportMessage(message, reason: reason, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GymDetailView: View {
    @EnvironmentObject private var appState: AppState
    let gym: Gym
    @State private var showingMembershipLimit = false

    private var joined: Bool {
        appState.isGymJoined(gym)
    }

    private var isPrimaryGym: Bool {
        appState.isPrimaryGym(gym)
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(gym.name)
                        .font(.largeTitle.bold())
                    Text("\(gym.city), \(gym.state)")
                        .foregroundStyle(Color.liftMuted)
                    PrimaryButton(
                        title: isPrimaryGym ? "Primary Gym" : (joined ? "Leave Gym" : "Join Gym"),
                        symbolName: isPrimaryGym ? "star.fill" : (joined ? "minus.circle" : "plus.circle")
                    ) {
                        if isPrimaryGym {
                            Haptics.light()
                        } else if joined {
                            appState.leaveGym(gym)
                        } else if !appState.joinGym(gym) {
                            showingMembershipLimit = true
                        }
                    }
                    .disabled(isPrimaryGym)
                    Text("You can belong to up to \(AppState.maximumJoinedGyms) gyms. Your primary gym counts toward this limit.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Members", value: "\(gym.memberCount)", subtitle: "Local lifters")
                        MetricCard(title: "Verified lifts", value: "\(gym.verifiedLiftCount)", subtitle: "Approved submissions", tint: .liftGreen)
                        MetricCard(title: "Bench record", value: "365 lb", subtitle: "Andre 4", tint: .liftGold)
                        MetricCard(title: "Squat record", value: "505 lb", subtitle: "Maya 8", tint: .liftGold)
                        MetricCard(title: "Deadlift record", value: "565 lb", subtitle: "Lifter 4", tint: .liftGold)
                        MetricCard(title: "Pound-for-pound", value: "3.1x", subtitle: "Sofia 12", tint: .liftBlue)
                    }
                    SectionHeader(title: "Top lifters")
                    ForEach(appState.leaderboardEntries().prefix(5)) { entry in
                        LeaderboardRow(entry: entry)
                    }
                }
                .padding()
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Gym limit reached", isPresented: $showingMembershipLimit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Leave one of your secondary gyms before joining another. Members can belong to a maximum of \(AppState.maximumJoinedGyms) gyms.")
            }
        }
    }
}

struct CreateThreadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Thread") {
                        TextField("Title", text: $title)
                        TextField("What do you want to discuss?", text: $bodyText, axis: .vertical)
                            .lineLimit(4...8)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Thread")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        appState.createThread(title: title, body: bodyText)
                        dismiss()
                    }
                    .disabled(!canPost)
                }
            }
        }
    }
}

struct RequestGymView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var note = ""
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Gym") {
                        TextField("Gym name", text: $name)
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("Why should this gym be added?", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Request Gym")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.requestGym(name: name, city: city, state: state, note: note)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}
