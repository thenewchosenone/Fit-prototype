import Foundation

struct ForumCommentThreadItem: Identifiable, Equatable {
    let comment: ForumComment
    let depth: Int
    let descendantCount: Int

    var id: UUID { comment.id }
}

enum ForumCommentThreadBuilder {
    static func flattened(
        comments: [ForumComment],
        collapsedCommentIDs: Set<UUID> = []
    ) -> [ForumCommentThreadItem] {
        let commentIDs = Set(comments.map(\.id))
        let childrenByParent = Dictionary(grouping: comments.filter {
            guard let parentID = $0.parentCommentID else { return false }
            return commentIDs.contains(parentID)
        }, by: { $0.parentCommentID! })
        let roots = comments.filter {
            guard let parentID = $0.parentCommentID else { return true }
            return !commentIDs.contains(parentID)
        }

        func descendantCount(for commentID: UUID, path: Set<UUID>) -> Int {
            guard !path.contains(commentID) else { return 0 }
            let nextPath = path.union([commentID])
            return (childrenByParent[commentID] ?? []).reduce(0) { total, child in
                total + 1 + descendantCount(for: child.id, path: nextPath)
            }
        }

        var result: [ForumCommentThreadItem] = []
        var visited: Set<UUID> = []

        func append(_ comment: ForumComment, depth: Int, path: Set<UUID>) {
            guard !visited.contains(comment.id), !path.contains(comment.id) else { return }
            visited.insert(comment.id)
            result.append(ForumCommentThreadItem(
                comment: comment,
                depth: depth,
                descendantCount: descendantCount(for: comment.id, path: path)
            ))
            guard !collapsedCommentIDs.contains(comment.id) else { return }
            let nextPath = path.union([comment.id])
            for child in childrenByParent[comment.id] ?? [] {
                append(child, depth: depth + 1, path: nextPath)
            }
        }

        for root in roots { append(root, depth: 0, path: []) }
        return result
    }
}


@MainActor
final class CommunityStore {
    private let repository: any CommunityRepository
    private var socialService: (any SocialService)?
    private var communityService: (any CommunityService)?
    private let calendar: Calendar
    private let now: () -> Date
    private let makeUUID: () -> UUID

    init(
        repository: any CommunityRepository,
        socialService: (any SocialService)? = nil,
        communityService: (any CommunityService)? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        makeUUID: @escaping () -> UUID = UUID.init
    ) {
        self.repository = repository
        self.socialService = socialService
        self.communityService = communityService
        self.calendar = calendar
        self.now = now
        self.makeUUID = makeUUID
    }

    func updateServices(
        socialService: any SocialService,
        communityService: any CommunityService
    ) {
        self.socialService = socialService
        self.communityService = communityService
    }

    func refreshProductionData(loadActivity: Bool = true, loadCommunities: Bool = true) async {
        // Clear seeded content before requesting production data so failures
        // produce an honest empty state instead of a demo fallback.
        repository.activities = []
        repository.forumCommunities = []
        repository.forumMemberships = []
        repository.forumPosts = []
        repository.forumComments = []

        if loadActivity, let socialService {
            repository.activities = (try? await socialService.feed()) ?? []
        }
        guard loadCommunities, let communityService else { return }
        repository.forumCommunities = (try? await communityService.communities()) ?? []
        repository.forumPosts = (try? await communityService.posts(in: nil)) ?? []
        for post in repository.forumPosts {
            repository.forumComments.append(
                contentsOf: (try? await communityService.comments(for: post)) ?? []
            )
        }
    }

    var threads: [CommunityThread] { repository.communityThreads }
    var threadReplies: [CommunityThreadReply] { repository.communityThreadReplies }
    var reports: [CommunityReport] { repository.communityReports }
    var activityComments: [ActivityComment] { repository.activityComments }
    var communities: [ForumCommunity] { repository.visibleForumCommunities(for: nil) }
    var memberships: [ForumMembership] { repository.forumMemberships }
    var posts: [ForumPost] { repository.forumPosts }
    var comments: [ForumComment] { repository.forumComments }
    var joinRequests: [ForumJoinRequest] { repository.forumJoinRequests }
    var forumReports: [ForumReport] { repository.forumReports }
    var moderationActions: [ForumModerationAction] { repository.forumModerationActions }

    var notifications: [ForumNotification] {
        repository.forumNotifications.filter { $0.userID == repository.currentProfile.id }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var isStaff: Bool { repository.isForumStaff(nil) }

    var joinedCommunities: [ForumCommunity] {
        communities.filter { repository.forumMembership(communityID: $0.id, userID: nil)?.isActive == true }
    }

    func thread(for challenge: Challenge) -> CommunityThread? {
        repository.communityThreads.first { $0.challengeID == challenge.id }
    }

    func currentThread(_ thread: CommunityThread) -> CommunityThread {
        repository.communityThreads.first { $0.id == thread.id } ?? thread
    }

    func replies(for thread: CommunityThread) -> [CommunityThreadReply] {
        repository.communityThreadReplies
            .filter { $0.threadID == thread.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func threads(for challenge: Challenge) -> [CommunityThread] {
        repository.communityThreads.filter { $0.challengeID == challenge.id }
    }

    func community(_ id: UUID) -> ForumCommunity? {
        repository.forumCommunities.first { $0.id == id }
    }

    func post(_ id: UUID) -> ForumPost? {
        repository.forumPosts.first { $0.id == id }
    }

    func membership(for communityID: UUID) -> ForumMembership? {
        repository.forumMembership(communityID: communityID, userID: nil)
    }

    func isJoined(to communityID: UUID) -> Bool {
        membership(for: communityID)?.isActive == true
    }

    func canContribute(to communityID: UUID) -> Bool {
        repository.canContributeToForumCommunity(communityID, userID: nil)
    }

    func canRead(_ communityID: UUID) -> Bool {
        repository.canReadForumCommunity(communityID, userID: nil)
    }

    func canModerate(_ communityID: UUID) -> Bool {
        repository.canModerateForumCommunity(communityID, userID: nil)
    }

    func setArchived(_ archived: Bool, communityID: UUID) {
        repository.setForumCommunityArchived(communityID, archived: archived)
    }

    @discardableResult
    func join(_ communityID: UUID, note: String = "") -> ForumMembershipStatus? {
        repository.joinForumCommunity(communityID, note: note)
    }

    func syncJoin(_ communityID: UUID, note: String) async {
        guard let communityService, let community = community(communityID) else { return }
        _ = try? await communityService.join(community: community, note: note)
    }

    @discardableResult
    func leave(_ communityID: UUID) -> ForumCommunity? {
        let community = community(communityID)
        repository.leaveForumCommunity(communityID)
        return community
    }

    func syncLeave(_ community: ForumCommunity) async {
        try? await communityService?.leave(community: community)
    }

    func setNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID) {
        repository.setForumNotificationLevel(level, communityID: communityID)
    }

    @discardableResult
    func createPost(
        destination: ForumDestination,
        kind: ForumPostKind,
        title: String,
        body: String,
        tag: String? = nil,
        attachments: [ForumAttachment] = [],
        pollOptions: [String] = [],
        pollCloseDays: Int? = nil,
        liftID: UUID? = nil,
        workoutID: UUID? = nil,
        linkURL: URL? = nil
    ) -> ForumPost? {
        let timestamp = now()
        let poll: ForumPoll? = kind == .poll ? ForumPoll(
            id: makeUUID(),
            options: pollOptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { ForumPollOption(id: makeUUID(), text: $0, voterIDs: []) },
            closesAt: pollCloseDays.flatMap { calendar.date(byAdding: .day, value: $0, to: timestamp) }
        ) : nil
        let post = ForumPost(
            id: makeUUID(),
            destination: destination,
            authorID: repository.currentProfile.id,
            authorName: repository.currentProfile.displayName,
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            tag: destination.communityID == nil ? nil : tag,
            attachments: attachments,
            poll: poll,
            liftID: liftID,
            workoutID: workoutID,
            linkURL: linkURL,
            challengeID: nil,
            createdAt: timestamp,
            editedAt: nil,
            commentCount: 0,
            votes: [:],
            savedByUserIDs: [],
            watchedByUserIDs: [],
            isPinned: false,
            isLocked: false,
            removedAt: nil,
            removalReason: nil
        )
        return repository.createForumPost(post) ? post : nil
    }

    func syncCreatedPost(_ post: ForumPost) async {
        _ = try? await communityService?.createPost(post)
    }

    @discardableResult
    func vote(on postID: UUID, selection: CommunityVote?) -> ForumPost? {
        let post = post(postID)
        repository.voteForumPost(postID, vote: selection)
        return post
    }

    func syncVote(on post: ForumPost, selection: CommunityVote?) async {
        try? await communityService?.vote(post: post, vote: selection)
    }

    @discardableResult
    func toggleSaved(postID: UUID) -> ForumPost? {
        let post = post(postID)
        repository.toggleForumPostSaved(postID)
        return post
    }

    func syncSavedState(of post: ForumPost) async {
        try? await communityService?.toggleSaved(post: post)
    }

    @discardableResult
    func toggleWatched(postID: UUID) -> ForumPost? {
        let post = post(postID)
        repository.toggleForumPostWatched(postID)
        return post
    }

    func syncWatchedState(of post: ForumPost) async {
        try? await communityService?.toggleWatched(post: post)
    }

    @discardableResult
    func voteInPoll(postID: UUID, optionID: UUID) -> ForumPost? {
        let post = post(postID)
        repository.voteInForumPoll(postID: postID, optionID: optionID)
        return post
    }

    func syncPollVote(on post: ForumPost, optionID: UUID) async {
        try? await communityService?.vote(pollPost: post, optionID: optionID)
    }

    @discardableResult
    func addComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment? {
        repository.addForumComment(postID: postID, parentCommentID: parentCommentID, body: body)
    }

    func syncComment(on post: ForumPost, parentCommentID: UUID?, body: String) async {
        _ = try? await communityService?.addComment(
            to: post,
            parentCommentID: parentCommentID,
            body: body
        )
    }

    @discardableResult
    func vote(onComment commentID: UUID, selection: CommunityVote?) -> ForumComment? {
        let comment = repository.forumComments.first { $0.id == commentID }
        repository.voteForumComment(commentID, vote: selection)
        return comment
    }

    func syncVote(on comment: ForumComment, selection: CommunityVote?) async {
        try? await communityService?.vote(comment: comment, vote: selection)
    }

    func deletePost(_ postID: UUID) {
        repository.softDeleteForumPost(postID)
    }

    func update(_ post: ForumPost, title: String, body: String) {
        var updated = post
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        repository.updateForumPost(updated)
    }

    func deleteComment(_ commentID: UUID) {
        repository.softDeleteForumComment(commentID)
    }

    @discardableResult
    func report(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String = ""
    ) -> Bool {
        repository.reportForumContent(
            targetType: targetType,
            targetID: targetID,
            communityID: communityID,
            reason: reason,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func syncReport(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String
    ) async {
        _ = try? await communityService?.report(
            targetType: targetType,
            targetID: targetID,
            communityID: communityID,
            reason: reason,
            note: note
        )
    }

    @discardableResult
    func moderate(postID: UUID, action: ForumModerationActionKind, reason: String = "") -> ForumPost? {
        let post = post(postID)
        repository.moderateForumPost(postID, action: action, reason: reason)
        return post
    }

    func syncModeration(of post: ForumPost, action: ForumModerationActionKind, reason: String) async {
        try? await communityService?.moderate(post: post, action: action, reason: reason)
    }

    func moderate(commentID: UUID, action: ForumModerationActionKind, reason: String = "") {
        repository.moderateForumComment(commentID, action: action, reason: reason)
    }

    func resolveReport(_ reportID: UUID, dismiss: Bool) {
        repository.resolveForumReport(reportID, dismiss: dismiss)
    }

    func resolveJoinRequest(_ requestID: UUID, approved: Bool) {
        repository.resolveForumJoinRequest(requestID, approved: approved)
    }

    func markNotificationRead(_ notificationID: UUID) {
        repository.markForumNotificationRead(notificationID)
    }

    func feed(
        communityID: UUID? = nil,
        sort: ForumFeedSort = .hot,
        topRange: ForumTopRange = .week,
        query: String = "",
        includeAllReadable: Bool = false
    ) -> [ForumPost] {
        if let communityID, !repository.canReadForumCommunity(communityID, userID: nil) { return [] }
        let joinedIDs = Set(joinedCommunities.map(\.id))
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cutoff: Date? = {
            guard sort == .top else { return nil }
            let days: Int?
            switch topRange {
            case .day: days = 1
            case .week: days = 7
            case .month: days = 30
            case .all: days = nil
            }
            return days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now()) }
        }()

        var result = repository.forumPosts.filter { post in
            if let selectedCommunityID = communityID {
                guard post.destination.communityID == selectedCommunityID else { return false }
            } else if !includeAllReadable {
                guard let destinationCommunityID = post.destination.communityID,
                      joinedIDs.contains(destinationCommunityID) else { return false }
            } else if let destinationCommunityID = post.destination.communityID,
                      !repository.canReadForumCommunity(destinationCommunityID, userID: nil) {
                return false
            }
            if let cutoff, post.createdAt < cutoff { return false }
            guard !cleanQuery.isEmpty else { return true }
            let communityName = post.destination.communityID.flatMap { community($0)?.name } ?? "Gym"
            return post.title.lowercased().contains(cleanQuery) ||
                post.body.lowercased().contains(cleanQuery) ||
                post.tag?.lowercased().contains(cleanQuery) == true ||
                communityName.lowercased().contains(cleanQuery)
        }

        result.sort { left, right in
            if left.isPinned != right.isPinned { return left.isPinned }
            switch sort {
            case .new:
                return left.createdAt > right.createdAt
            case .top:
                if left.voteScore != right.voteScore { return left.voteScore > right.voteScore }
                if left.commentCount != right.commentCount { return left.commentCount > right.commentCount }
                return left.createdAt > right.createdAt
            case .hot:
                let leftScore = hotScore(left)
                let rightScore = hotScore(right)
                if leftScore != rightScore { return leftScore > rightScore }
                return left.createdAt > right.createdAt
            }
        }
        return result
    }

    func hotScore(_ post: ForumPost, referenceDate: Date? = nil) -> Double {
        let ageHours = max(0, (referenceDate ?? now()).timeIntervalSince(post.createdAt) / 3_600)
        return Double(post.voteScore * 2) + log2(Double(post.commentCount) + 1) * 3 - ageHours / 24
    }

    func searchCommunities(query: String, category: String? = nil) -> [ForumCommunity] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return communities.filter { community in
            let categoryMatches = category == nil || category == "All" || community.category == category
            let queryMatches = cleanQuery.isEmpty || community.name.lowercased().contains(cleanQuery) ||
                community.summary.lowercased().contains(cleanQuery) ||
                community.category.lowercased().contains(cleanQuery) ||
                (repository.canReadForumCommunity(community.id, userID: nil) && repository.forumPosts.contains {
                    $0.destination.communityID == community.id &&
                    ($0.title.lowercased().contains(cleanQuery) || $0.body.lowercased().contains(cleanQuery))
                })
            return categoryMatches && queryMatches
        }
        .sorted { lhs, rhs in
            let lhsJoined = isJoined(to: lhs.id)
            let rhsJoined = isJoined(to: rhs.id)
            if lhsJoined != rhsJoined { return lhsJoined }
            return lhs.memberCount > rhs.memberCount
        }
    }

    func comments(for postID: UUID, sort: ForumCommentSort = .best) -> [ForumComment] {
        var result = repository.forumComments.filter { $0.postID == postID }
        result.sort { lhs, rhs in
            if lhs.parentCommentID == nil && rhs.parentCommentID != nil { return true }
            if lhs.parentCommentID != nil && rhs.parentCommentID == nil { return false }
            switch sort {
            case .best:
                if lhs.voteScore != rhs.voteScore { return lhs.voteScore > rhs.voteScore }
                return lhs.createdAt < rhs.createdAt
            case .new: return lhs.createdAt > rhs.createdAt
            case .old: return lhs.createdAt < rhs.createdAt
            }
        }
        return result
    }

    func replies(to commentID: UUID, postID: UUID) -> [ForumComment] {
        repository.forumComments
            .filter { $0.postID == postID && $0.parentCommentID == commentID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func currentActivity(_ activity: ActivityItem) -> ActivityItem {
        repository.activities.first { $0.id == activity.id } ?? activity
    }

    func comments(for activity: ActivityItem) -> [ActivityComment] {
        repository.activityComments
            .filter { $0.activityID == activity.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func refreshComments(for activity: ActivityItem) async throws {
        guard let socialService else { return }
        let remote = try await socialService.comments(activityID: activity.id)
        repository.replaceActivityComments(for: activity.id, with: remote)
        if let index = repository.activities.firstIndex(where: { $0.id == activity.id }) {
            repository.activities[index].commentCount = remote.count
        }
    }

    func setLiked(_ activity: ActivityItem, isLiked: Bool) async throws {
        guard let socialService else { return }
        try await socialService.setActivityLiked(activityID: activity.id, isLiked: isLiked)
        guard let index = repository.activities.firstIndex(where: { $0.id == activity.id }) else { return }
        let delta = isLiked == repository.activities[index].isLiked ? 0 : (isLiked ? 1 : -1)
        repository.activities[index].isLiked = isLiked
        repository.activities[index].likeCount = max(0, repository.activities[index].likeCount + delta)
    }

    func addRemoteComment(to activity: ActivityItem, body: String) async throws {
        guard let socialService else { return }
        let comment = try await socialService.addActivityComment(activityID: activity.id, body: body)
        repository.appendActivityComment(comment)
        if let index = repository.activities.firstIndex(where: { $0.id == activity.id }) {
            repository.activities[index].commentCount = comments(for: activity).count
        }
    }
}
