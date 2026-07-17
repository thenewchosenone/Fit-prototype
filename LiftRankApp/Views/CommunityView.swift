import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
            .filter { ($0.kind == .general || $0.kind == .gym) && $0.removedAt == nil }
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
            .liftSurface()
    }

    func compactSocialCardStyle() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liftSurface(radius: 14)
    }
}

struct CommunityReportDraft: Identifiable {
    var id: UUID
    var type: CommunityReportTargetType
    var title: String
}

struct LegacyCommunityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var conversationDeleteTarget: DirectMessageThread?
    @State private var selectedTopic: CommunityTopic = .all
    @State private var gymSearch = ""
    @State private var communityReportTarget: CommunityReportDraft?

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
        LiftEmptyState(title: title, message: message, symbolName: "person.2.slash")
    }

    private func threadCard(_ thread: CommunityThread) -> some View {
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
                    voteControls(for: currentThread)
                    Spacer()
                    Text(currentThread.authorName)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private func voteControls(for thread: CommunityThread) -> some View {
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

struct CommunityThreadDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let thread: CommunityThread
    @State private var replyText = ""
    @State private var reportTarget: CommunityReportDraft?

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
                                    if currentThread.isLocked {
                                        Label("Locked", systemImage: "lock.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.liftGold)
                                    }
                                    Text(currentThread.title)
                                        .font(.title2.bold())
                                    if !currentThread.body.isEmpty {
                                        Text(currentThread.body)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    HStack {
                                        Button {
                                            appState.voteThread(currentThread, vote: appState.threadVote(for: currentThread) == .up ? nil : .up)
                                        } label: {
                                            Label("Up", systemImage: appState.threadVote(for: currentThread) == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftGreen)
                                        Text("\(currentThread.voteScore)")
                                            .font(.headline.weight(.black))
                                            .foregroundStyle(currentThread.voteScore < 0 ? Color.liftRed : Color.liftGreen)
                                        Button {
                                            appState.voteThread(currentThread, vote: appState.threadVote(for: currentThread) == .down ? nil : .down)
                                        } label: {
                                            Label("Down", systemImage: appState.threadVote(for: currentThread) == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftRed)
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
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            reportTarget = CommunityReportDraft(id: currentThread.id, type: .thread, title: currentThread.title)
                        } label: {
                            Label("Report Thread", systemImage: "flag")
                        }
                        if appState.isForumStaff {
                            Button(currentThread.isLocked ? "Unlock Thread" : "Lock Thread") {
                                appState.moderateThread(currentThread, operation: currentThread.isLocked ? .unlock : .lock)
                            }
                            if currentThread.removedAt == nil {
                                Button(role: .destructive) {
                                    appState.moderateThread(currentThread, operation: .remove, reason: "Removed from community.")
                                } label: {
                                    Label("Remove Thread", systemImage: "trash")
                                }
                            } else {
                                Button("Restore Thread") {
                                    appState.moderateThread(currentThread, operation: .restore)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportCommunityView(target: target)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
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
                HStack(spacing: 10) {
                    Button {
                        appState.voteReply(reply, vote: appState.replyVote(for: reply) == .up ? nil : .up)
                    } label: {
                        Image(systemName: appState.replyVote(for: reply) == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    }
                    Text("\(reply.voteScore)")
                        .font(.caption.weight(.black))
                    Button {
                        appState.voteReply(reply, vote: appState.replyVote(for: reply) == .down ? nil : .down)
                    } label: {
                        Image(systemName: appState.replyVote(for: reply) == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        reportTarget = CommunityReportDraft(id: reply.id, type: .reply, title: "Reply by \(reply.authorName)")
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .buttonStyle(.plain)
            }
        }
    }

    private var commentComposer: some View {
        HStack(spacing: 10) {
            TextField(currentThread.isLocked ? "This thread is locked" : "Add a comment", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            Button {
                appState.addReply(to: currentThread, body: replyText)
                replyText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liftBlue)
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .disabled(currentThread.isLocked || currentThread.removedAt != nil || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                                            Label(currentActivity.isLiked ? "Supported" : "Support", systemImage: currentActivity.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftBlue)
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
                .background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            Button {
                appState.addComment(to: currentActivity, body: commentText)
                commentText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
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

struct ReportCommunityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let target: CommunityReportDraft
    @State private var reason: CommunityReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Content") {
                        Text(target.title)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Section("Reason") {
                        Picker("Reason", selection: $reason) {
                            ForEach(CommunityReportReason.allCases) { reason in
                                Text(reason.rawValue).tag(reason)
                            }
                        }
                    }
                    Section("Optional note") {
                        TextField("Add context for moderators", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report \(target.type.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.reportCommunity(targetType: target.type, targetID: target.id, reason: reason, note: note)
                        dismiss()
                    }
                }
            }
        }
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
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
                    if joined && !isPrimaryGym {
                        Button {
                            appState.setPrimaryGym(gym)
                        } label: {
                            Label("Make Primary Gym", systemImage: "star")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.liftBlue)
                    }
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
                    SectionHeader(
                        title: "Gym discussion",
                        actionTitle: joined ? "New post" : nil,
                        action: joined ? { appState.beginForumComposer(gymID: gym.id) } : nil
                    )
                    let gymPosts = appState.forumPosts
                        .filter { $0.destination.gymID == gym.id }
                        .sorted { $0.isPinned != $1.isPinned ? $0.isPinned : $0.createdAt > $1.createdAt }
                    if gymPosts.isEmpty {
                        LiftEmptyState(
                            title: "No gym discussions yet",
                            message: joined ? "Start the first local discussion." : "Join this gym to start a discussion.",
                            symbolName: "bubble.left.and.bubble.right"
                        )
                    } else {
                        ForEach(gymPosts) { ForumPostCard(postID: $0.id) }
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

// MARK: - Multi-community forum experience

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                header
                tabs
                Group {
                    switch appState.selectedCommunitySegment {
                    case "Explore": ForumExploreView()
                    case "Inbox": ForumInboxView()
                    default: ForumHomeView()
                    }
                }
                .environmentObject(appState)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ForumRoute.self) { route in
                switch route {
                case .community(let id): ForumCommunityDetailView(communityID: id)
                case .post(let id): ForumPostDetailView(postID: id)
                case .gym(let id):
                    if let gym = appState.gyms.first(where: { $0.id == id }) { GymDetailView(gym: gym) }
                    else { ContentUnavailableView("Gym unavailable", systemImage: "building.2") }
                case .gyms: ForumGymDirectoryView()
                case .saved: ForumCollectionView(mode: .saved)
                case .watched: ForumCollectionView(mode: .watched)
                case .moderation: ForumModerationCenterView()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Community")
                    .font(.title2.weight(.black))
                Text("Strength forums")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Spacer()
            if appState.isForumStaff {
                Button { appState.communityPath.append(.moderation) } label: {
                    Image(systemName: "shield.lefthalf.filled")
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Forum moderation")
            }
            Button { appState.beginForumComposer() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Create a forum post")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["Home", "Explore", "Inbox"], id: \.self) { tab in
                Button {
                    appState.selectedCommunitySegment = tab
                    Haptics.light()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Text(tab)
                                .font(.subheadline.weight(appState.selectedCommunitySegment == tab ? .bold : .medium))
                            if tab == "Inbox", appState.unreadForumNotificationCount + appState.incomingFriendRequests.count > 0 {
                                Text("\(appState.unreadForumNotificationCount + appState.incomingFriendRequests.count)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.liftRed)
                                    .clipShape(Capsule())
                            }
                        }
                        Rectangle()
                            .fill(appState.selectedCommunitySegment == tab ? Color.liftBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(appState.selectedCommunitySegment == tab ? .white : Color.liftMuted)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.liftSeparator).frame(height: 1) }
    }
}

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
            Button { appState.communityPath.append(.saved) } label: {
                Label("Saved", systemImage: "bookmark.fill")
            }
            Button { appState.communityPath.append(.watched) } label: {
                Label("Watched", systemImage: "bell.badge.fill")
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
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(Color.liftCardRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ForumPostCard: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    var opensDetail = true
    @State private var reportTarget: ForumReportDraft?
    @State private var editingPost: ForumPost?
    @State private var confirmDelete = false

    private var post: ForumPost? { appState.forumPost(postID) }

    var body: some View {
        if let post {
            VStack(alignment: .leading, spacing: 12) {
                postHeader(post)
                Button {
                    if opensDetail { appState.openForumPost(post.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(post.removedAt == nil ? post.title : "Post removed")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(post.removedAt == nil ? .white : Color.liftMuted)
                            .multilineTextAlignment(.leading)
                        if post.removedAt == nil {
                            if !post.body.isEmpty {
                                Text(post.body)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(opensDetail ? 4 : nil)
                                    .multilineTextAlignment(.leading)
                            }
                            postPayload(post)
                        } else {
                            Text("The author or a moderator removed this content.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                footer(post)
            }
            .padding(14)
            .liftSurface(radius: 14)
            .sheet(item: $reportTarget) { target in
                ForumReportSheet(target: target, communityID: post.destination.communityID)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .sheet(item: $editingPost) { post in
                ForumEditPostView(post: post)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Post", role: .destructive) { appState.deleteForumPost(post.id) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The discussion structure stays visible, but the text and media are removed.")
            }
        }
    }

    private func postHeader(_ post: ForumPost) -> some View {
        HStack(spacing: 9) {
            if let author = appState.profile(id: post.authorID) {
                ProfileAvatar(profile: author, size: 36)
            } else {
                Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Color.liftMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(post.authorName).font(.caption.weight(.bold))
                    Text("• \(LiftTimeFormatter.relativeNoSeconds(from: post.createdAt))")
                        .font(.caption2).foregroundStyle(Color.liftMuted)
                    if post.editedAt != nil { Text("edited").font(.caption2).foregroundStyle(Color.liftMuted) }
                }
                HStack(spacing: 5) {
                    if let communityID = post.destination.communityID, let community = appState.forumCommunity(communityID) {
                        Button(community.name) { appState.openForumCommunity(community.id) }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                    } else if let gymID = post.destination.gymID {
                        Text(appState.gyms.first(where: { $0.id == gymID })?.name ?? "Gym discussion")
                            .font(.caption2.weight(.semibold)).foregroundStyle(Color.liftBlue)
                    }
                    if let tag = post.tag {
                        Text(tag).font(.caption2.weight(.bold)).foregroundStyle(Color.liftMuted)
                    }
                }
            }
            Spacer()
            if post.isPinned { Image(systemName: "pin.fill").foregroundStyle(Color.liftGold).accessibilityLabel("Pinned") }
            Menu {
                if post.authorID == appState.currentProfile.id, post.removedAt == nil {
                    Button("Edit Post") { editingPost = post }
                    Button("Delete Post", role: .destructive) { confirmDelete = true }
                }
                Button("Report Post", role: .destructive) {
                    reportTarget = ForumReportDraft(id: post.id, type: .post, title: post.title)
                }
                if let communityID = post.destination.communityID, appState.canModerateForumCommunity(communityID) {
                    Divider()
                    Button(post.isPinned ? "Unpin" : "Pin") {
                        appState.moderateForumPost(post.id, action: post.isPinned ? .unpin : .pin)
                    }
                    Button(post.isLocked ? "Unlock" : "Lock") {
                        appState.moderateForumPost(post.id, action: post.isLocked ? .unlock : .lock)
                    }
                    Button(post.removedAt == nil ? "Remove" : "Restore", role: post.removedAt == nil ? .destructive : nil) {
                        appState.moderateForumPost(post.id, action: post.removedAt == nil ? .remove : .restore)
                    }
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 36, height: 36)
            }
            .foregroundStyle(Color.liftMuted)
        }
    }

    @ViewBuilder
    private func postPayload(_ post: ForumPost) -> some View {
        if let attachment = post.attachments.first {
            if attachment.mediaType == .image, let image = UIImage(contentsOfFile: attachment.localURL.path) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(maxWidth: .infinity, minHeight: 170, maxHeight: 260)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Label("Attached video", systemImage: "play.rectangle.fill")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.liftBlue)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.liftBackground).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        if let poll = post.poll { ForumPollView(postID: post.id, poll: poll) }
        if let liftID = post.liftID, let lift = appState.lifts.first(where: { $0.id == liftID }) {
            ForumLiftShareView(lift: lift)
        }
        if let workoutID = post.workoutID, let workout = appState.completedWorkouts.first(where: { $0.id == workoutID }) {
            ForumWorkoutShareView(workout: workout)
        }
        if let link = post.linkURL {
            Link(destination: link) {
                HStack(spacing: 10) {
                    Image(systemName: "link.circle.fill").font(.title2).foregroundStyle(Color.liftBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.host() ?? "Website").font(.subheadline.weight(.bold))
                        Text(link.absoluteString).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(1)
                    }
                    Spacer(); Image(systemName: "arrow.up.right")
                }
                .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func footer(_ post: ForumPost) -> some View {
        HStack(spacing: 16) {
            ForumVoteControl(
                score: post.voteScore,
                selection: post.votes[appState.currentProfile.id],
                enabled: appState.canContributeToForumPost(post),
                onVote: { appState.voteForumPost(post.id, vote: $0) }
            )
            Button { if opensDetail { appState.openForumPost(post.id) } } label: {
                Label("\(post.commentCount)", systemImage: "bubble.left")
            }
            Button { appState.toggleForumPostSaved(post.id) } label: {
                Image(systemName: post.savedByUserIDs.contains(appState.currentProfile.id) ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(post.savedByUserIDs.contains(appState.currentProfile.id) ? Color.liftBlue : Color.liftMuted)
            }
            Button { appState.toggleForumPostWatched(post.id) } label: {
                Image(systemName: post.watchedByUserIDs.contains(appState.currentProfile.id) ? "bell.fill" : "bell")
                    .foregroundStyle(post.watchedByUserIDs.contains(appState.currentProfile.id) ? Color.liftBlue : Color.liftMuted)
            }
            Spacer()
            if post.isLocked { Label("Locked", systemImage: "lock.fill").font(.caption2.weight(.bold)) }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.liftMuted)
        .buttonStyle(.plain)
    }
}

private struct ForumVoteControl: View {
    let score: Int
    let selection: CommunityVote?
    let enabled: Bool
    let onVote: (CommunityVote?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onVote(selection == .up ? nil : .up) } label: {
                Image(systemName: selection == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .foregroundStyle(selection == .up ? Color.liftGreen : Color.liftMuted)
            }
            Text("\(score)").font(.caption.weight(.black)).foregroundStyle(.white).monospacedDigit()
            Button { onVote(selection == .down ? nil : .down) } label: {
                Image(systemName: selection == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(selection == .down ? Color.liftRed : Color.liftMuted)
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vote score \(score)")
    }
}

private struct ForumPollView: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    let poll: ForumPoll

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(poll.options) { option in
                let isSelected = option.voterIDs.contains(appState.currentProfile.id)
                Button { appState.voteInForumPoll(postID: postID, optionID: option.id) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.liftBlue : Color.liftMuted)
                        Text(option.text).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text("\(option.voterIDs.count)").font(.caption.monospacedDigit()).foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(isSelected ? Color.liftBlue.opacity(0.14) : Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(poll.isClosed)
            }
            Text(poll.isClosed ? "Poll closed • \(poll.totalVotes) votes" : "\(poll.totalVotes) votes • You can change your vote")
                .font(.caption2).foregroundStyle(Color.liftMuted)
        }
    }
}

private struct ForumLiftShareView: View {
    let lift: LiftSubmission

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2).foregroundStyle(Color.liftGold)
                .frame(width: 46, height: 46).background(Color.liftGold.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(lift.exerciseName).font(.subheadline.weight(.bold))
                Text("\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) × \(lift.repetitions)")
                    .font(.headline.weight(.black))
                Text(lift.verificationStatus.rawValue).font(.caption2).foregroundStyle(Color.liftMuted)
            }
            Spacer()
        }
        .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct ForumWorkoutShareView: View {
    let workout: CompletedWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title2).foregroundStyle(Color.liftBlue)
                .frame(width: 46, height: 46).background(Color.liftBlue.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name).font(.subheadline.weight(.bold))
                Text("\(workout.completedWorkingSets.count) working sets • \(Int(workout.duration / 60)) min")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                Text("\(RankingCalculator.format(workout.totalVolume)) \(workout.unit.shortLabel) volume")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.liftBlue)
            }
            Spacer()
        }
        .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

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
                            Text(community.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
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

struct ForumCommunityDetailView: View {
    @EnvironmentObject private var appState: AppState
    let communityID: UUID
    @State private var selectedTab = "Posts"
    @State private var sort: ForumFeedSort = .hot
    @State private var topRange: ForumTopRange = .week
    @State private var requestNote = ""
    @State private var showingRequest = false

    private var community: ForumCommunity? { appState.forumCommunity(communityID) }
    private var canReadPosts: Bool { appState.repository.canReadForumCommunity(communityID) }

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
                                    appState.repository.setForumCommunityArchived(community.id, archived: community.archivedAt == nil)
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
                                    Text(gym.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
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
                                Text(notification.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
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
                                Text(profile.displayName).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
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
                                    Text(profile?.displayName ?? "Conversation").font(.subheadline.weight(.bold)).foregroundStyle(.white)
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

struct ForumPostDetailView: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    @State private var sort: ForumCommentSort = .best
    @State private var draft = ""
    @State private var replyingTo: ForumComment?
    @State private var collapsedCommentIDs: Set<UUID> = []

    private var post: ForumPost? { appState.forumPost(postID) }
    private var roots: [ForumComment] {
        appState.forumComments(for: postID, sort: sort).filter { $0.parentCommentID == nil }
    }

    var body: some View {
        AppBackground {
            if let post {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForumPostCard(postID: post.id, opensDetail: false)
                        HStack {
                            Text("Comments").font(.headline.weight(.bold))
                            Text("\(post.commentCount)").font(.caption.weight(.black)).foregroundStyle(Color.liftBlue)
                            Spacer()
                            Menu(sort.rawValue) {
                                ForEach(ForumCommentSort.allCases) { option in Button(option.rawValue) { sort = option } }
                            }
                            .font(.caption.weight(.bold))
                        }
                        if roots.isEmpty {
                            LiftEmptyState(title: "Start the discussion", message: "Be the first member to comment.", symbolName: "bubble.left")
                        } else {
                            ForEach(roots) { comment in
                                ForumCommentBranch(
                                    comment: comment,
                                    replies: appState.forumReplies(to: comment.id, postID: post.id),
                                    isCollapsed: collapsedCommentIDs.contains(comment.id),
                                    onCollapse: {
                                        if !collapsedCommentIDs.insert(comment.id).inserted { collapsedCommentIDs.remove(comment.id) }
                                    },
                                    onReply: { replyingTo = $0 }
                                )
                            }
                        }
                        Color.clear.frame(height: 86)
                    }
                    .padding(16)
                }
                .safeAreaInset(edge: .bottom) { composer(post) }
                .navigationTitle(appState.forumCommunity(post.destination.communityID ?? UUID())?.name ?? "Discussion")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Post unavailable", systemImage: "text.bubble")
            }
        }
    }

    private func composer(_ post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.authorName)").font(.caption).foregroundStyle(Color.liftBlue)
                    Spacer(); Button { self.replyingTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField(post.isLocked ? "Comments are locked" : "Add a comment", text: $draft, axis: .vertical)
                    .lineLimit(1...5).padding(.horizontal, 12).frame(minHeight: 44).background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(post.isLocked || !canComment(post))
                Button {
                    if appState.addForumComment(postID: post.id, parentCommentID: replyingTo?.id, body: draft) != nil {
                        draft = ""; replyingTo = nil
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Color.liftBlue).frame(width: 44, height: 44)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || post.isLocked || !canComment(post))
            }
            if !canComment(post), let communityID = post.destination.communityID {
                Button("Join this community to comment") { _ = appState.joinForumCommunity(communityID) }
                    .font(.caption.weight(.bold)).foregroundStyle(Color.liftBlue)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9).background(.ultraThinMaterial)
    }

    private func canComment(_ post: ForumPost) -> Bool {
        appState.canContributeToForumPost(post)
    }
}

private struct ForumCommentBranch: View {
    @EnvironmentObject private var appState: AppState
    let comment: ForumComment
    let replies: [ForumComment]
    let isCollapsed: Bool
    let onCollapse: () -> Void
    let onReply: (ForumComment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForumCommentRow(comment: comment, onReply: onReply, onCollapse: onCollapse, replyCount: replies.count)
            if !isCollapsed {
                ForEach(replies) { reply in
                    ForumCommentRow(comment: reply, onReply: onReply)
                        .padding(.leading, 24)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.liftSeparator).frame(width: 2).padding(.leading, 9) }
                }
            }
        }
    }
}

private struct ForumCommentRow: View {
    @EnvironmentObject private var appState: AppState
    let comment: ForumComment
    let onReply: (ForumComment) -> Void
    var onCollapse: (() -> Void)?
    var replyCount = 0
    @State private var reportTarget: ForumReportDraft?
    @State private var confirmDelete = false

    private var post: ForumPost? { appState.forumPost(comment.postID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(comment.authorName).font(.caption.weight(.bold))
                Text("• \(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))").font(.caption2).foregroundStyle(Color.liftMuted)
                if comment.editedAt != nil { Text("edited").font(.caption2).foregroundStyle(Color.liftMuted) }
                Spacer()
                Menu {
                    Button("Report Comment", role: .destructive) {
                        reportTarget = ForumReportDraft(id: comment.id, type: .comment, title: "Comment by \(comment.authorName)")
                    }
                    if comment.authorID == appState.currentProfile.id {
                        Button("Delete Comment", role: .destructive) { confirmDelete = true }
                    }
                    if let communityID = post?.destination.communityID,
                       appState.canModerateForumCommunity(communityID) {
                        Divider()
                        Button(comment.removedAt == nil ? "Remove Comment" : "Restore Comment", role: comment.removedAt == nil ? .destructive : nil) {
                            appState.moderateForumComment(comment.id, action: comment.removedAt == nil ? .remove : .restore)
                        }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 32, height: 32) }
            }
            Text(comment.removedAt == nil ? comment.body : "[comment removed]")
                .font(.subheadline).foregroundStyle(comment.removedAt == nil ? .white : Color.liftMuted)
            HStack(spacing: 15) {
                ForumVoteControl(
                    score: comment.voteScore,
                    selection: comment.votes[appState.currentProfile.id],
                    enabled: post.map(appState.canContributeToForumPost) ?? false,
                    onVote: { appState.voteForumComment(comment.id, vote: $0) }
                )
                if comment.removedAt == nil {
                    Button("Reply") { onReply(comment) }
                }
                if let onCollapse, replyCount > 0 {
                    Button("\(replyCount) replies") { onCollapse() }
                }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
        }
        .padding(12).background(Color.liftCard.opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $reportTarget) { target in
            ForumReportSheet(target: target, communityID: post?.destination.communityID)
                .environmentObject(appState).presentationDetents([.medium])
        }
        .confirmationDialog("Delete this comment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Comment", role: .destructive) { appState.deleteForumComment(comment.id) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct ForumReportDraft: Identifiable {
    let id: UUID
    let type: ForumReportTargetType
    let title: String
}

struct ForumReportSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let target: ForumReportDraft
    let communityID: UUID?
    @State private var reason: CommunityReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(target.title).font(.subheadline.weight(.semibold))
                    Picker("Reason", selection: $reason) {
                        ForEach(CommunityReportReason.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Optional details", text: $note, axis: .vertical).lineLimit(3...6)
                } header: { Text("Report \(target.type.rawValue.lowercased())") }
            }
            .scrollContentBackground(.hidden)
            .background(Color.liftBackground)
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        if appState.reportForumContent(
                            targetType: target.type, targetID: target.id,
                            communityID: communityID, reason: reason, note: note
                        ) { dismiss() }
                    }
                }
            }
        }
    }
}

struct ForumEditPostView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let post: ForumPost
    @State private var title: String
    @State private var bodyText: String

    init(post: ForumPost) {
        self.post = post
        _title = State(initialValue: post.title)
        _bodyText = State(initialValue: post.body)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("5–140 characters", text: $title)
                    Text("\(title.count)/140").font(.caption).foregroundStyle(Color.liftMuted)
                }
                Section("Body") {
                    TextEditor(text: $bodyText).frame(minHeight: 160)
                    Text("\(bodyText.count)/10,000").font(.caption).foregroundStyle(Color.liftMuted)
                }
            }
            .scrollContentBackground(.hidden).background(Color.liftBackground)
            .navigationTitle("Edit Post").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { appState.updateForumPost(post, title: title, body: bodyText); dismiss() }
                        .disabled(!(5...140).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count) || bodyText.count > 10_000)
                }
            }
        }
    }
}

struct ForumCommunityEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""
    @State private var details = ""
    @State private var category = "Training"
    @State private var visibility: ForumCommunityVisibility = .publicOpen
    @State private var rules = ["Be constructive", "No spam"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Community name", text: $name)
                    TextField("Short summary", text: $summary)
                    TextField("Full description", text: $details, axis: .vertical).lineLimit(3...7)
                    TextField("Category", text: $category)
                }
                Section("Access") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(ForumCommunityVisibility.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Rules") {
                    ForEach(rules.indices, id: \.self) { index in TextField("Rule \(index + 1)", text: $rules[index]) }
                    Button("Add Rule") { if rules.count < 10 { rules.append("") } }
                }
            }
            .scrollContentBackground(.hidden).background(Color.liftBackground)
            .navigationTitle("New Community").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if appState.createForumCommunity(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            visibility: visibility,
                            rules: rules.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        ) { dismiss() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || summary.isEmpty)
                }
            }
        }
    }
}

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
            gymID.map { appState.repository.joinedGymIDs.contains($0) } ?? false
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
                        Text(gym.name).foregroundStyle(.white)
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
                        Text(selectedCommunity?.name ?? "Choose a joined community").foregroundStyle(.white)
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
                    Text("\(lift.exerciseName) — \(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) × \(lift.repetitions)").tag(UUID?.some(lift.id))
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
                    Text("\(workout.name) — \(workout.completedAt.formatted(date: .abbreviated, time: .omitted))").tag(UUID?.some(workout.id))
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
            if let lift = appState.lifts.first(where: { $0.id == liftID }) { title = "\(lift.exerciseName) PR — \(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel)" }
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
        await MainActor.run { attachments.filter { $0.mediaType == .image }.forEach { appState.repository.removeForumMedia(at: $0.localURL) }; attachments.removeAll { $0.mediaType == .image }; videoItem = nil }
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
        appState.repository.removeForumMedia(at: attachment.localURL)
        attachments.removeAll { $0.id == attachment.id }
    }

    private func discardMedia() {
        attachments.forEach { appState.repository.removeForumMedia(at: $0.localURL) }
        attachments = []
    }
}

struct ForumModerationCenterView: View {
    @EnvironmentObject private var appState: AppState
    @State private var segment = "Reports"

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Picker("Moderation section", selection: $segment) {
                        Text("Reports").tag("Reports"); Text("Requests").tag("Requests"); Text("Audit").tag("Audit")
                    }
                    .pickerStyle(.segmented)
                    if segment == "Reports" { reports }
                    else if segment == "Requests" { requests }
                    else { audit }
                    Color.clear.frame(height: 60)
                }
                .padding(16)
            }
        }
        .navigationTitle("Forum Moderation").navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var reports: some View {
        let openReports = appState.forumReports.filter { $0.status == .open }
        if openReports.isEmpty { LiftEmptyState(title: "Queue clear", message: "There are no open forum reports.", symbolName: "checkmark.shield.fill") }
        ForEach(openReports) { report in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(report.targetType.rawValue, systemImage: "flag.fill").foregroundStyle(Color.liftRed)
                    Spacer(); Text(report.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Color.liftMuted)
                }
                Text(report.reason.rawValue).font(.headline)
                if !report.note.isEmpty { Text(report.note).font(.subheadline).foregroundStyle(Color.liftMuted) }
                HStack {
                    Button("Dismiss") { appState.resolveForumReport(report.id, dismiss: true) }.buttonStyle(.bordered)
                    Button("Resolve") { appState.resolveForumReport(report.id, dismiss: false) }.buttonStyle(.borderedProminent)
                    if report.targetType == .post {
                        Button("Remove", role: .destructive) { appState.moderateForumPost(report.targetID, action: .remove, reason: "Removed after report") }.buttonStyle(.bordered)
                    }
                }
                .font(.caption.weight(.bold))
            }
            .padding(14).liftSurface(radius: 13)
        }
    }

    @ViewBuilder
    private var requests: some View {
        let pending = appState.forumJoinRequests.filter { $0.status == "Pending" && appState.canModerateForumCommunity($0.communityID) }
        if pending.isEmpty { LiftEmptyState(title: "No membership requests", message: "Restricted-community requests appear here.", symbolName: "person.badge.checkmark") }
        ForEach(pending) { request in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.profile(id: request.userID)?.displayName ?? "Member").font(.subheadline.weight(.bold))
                    Text(appState.forumCommunity(request.communityID)?.name ?? "Community").font(.caption).foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button("Decline", role: .destructive) { appState.resolveForumJoinRequest(request.id, approved: false) }.buttonStyle(.bordered)
                Button("Approve") { appState.resolveForumJoinRequest(request.id, approved: true) }.buttonStyle(.borderedProminent)
            }
            .font(.caption.weight(.bold)).padding(13).liftSurface(radius: 13)
        }
    }

    @ViewBuilder
    private var audit: some View {
        if appState.forumModerationActions.isEmpty { LiftEmptyState(title: "No audit history", message: "Moderator actions are recorded here.", symbolName: "list.bullet.clipboard") }
        ForEach(appState.forumModerationActions) { action in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.fill").foregroundStyle(Color.liftBlue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.kind.rawValue).font(.subheadline.weight(.bold))
                    Text(action.reason.isEmpty ? "No reason supplied" : action.reason).font(.caption).foregroundStyle(Color.liftMuted)
                    Text(action.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(Color.liftMuted)
                }
                Spacer()
            }
            .padding(13).liftSurface(radius: 13)
        }
    }
}
