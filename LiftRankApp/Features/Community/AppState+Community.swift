import Foundation

@MainActor
extension AppState {
    func joinChallenge(_ challenge: Challenge) {
        Haptics.light()
        repository.setChallengeJoined(challenge, joined: true)
    }

    func unjoinChallenge(_ challenge: Challenge) {
        Haptics.warning()
        repository.setChallengeJoined(challenge, joined: false)
    }

    func thread(for challenge: Challenge) -> CommunityThread? {
        communityStore.thread(for: challenge)
    }

    func currentThread(_ thread: CommunityThread) -> CommunityThread {
        communityStore.currentThread(thread)
    }

    func replies(for thread: CommunityThread) -> [CommunityThreadReply] {
        communityStore.replies(for: thread)
    }

    func isThreadLiked(_ thread: CommunityThread) -> Bool {
        thread.votes[currentProfile.id] == .up
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        voteThread(thread, vote: thread.votes[currentProfile.id] == .up ? nil : .up)
        Haptics.light()
    }

    func threadVote(for thread: CommunityThread) -> CommunityVote? {
        currentThread(thread).votes[currentProfile.id]
    }

    func replyVote(for reply: CommunityThreadReply) -> CommunityVote? {
        repository.communityThreadReplies.first { $0.id == reply.id }?.votes[currentProfile.id]
    }

    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) {
        repository.voteThread(thread, vote: vote)
        Haptics.light()
    }

    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) {
        repository.voteReply(reply, vote: vote)
        Haptics.light()
    }

    func threads(for challenge: Challenge) -> [CommunityThread] {
        communityStore.threads(for: challenge)
    }

    func addReply(to thread: CommunityThread, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = currentThread(thread)
        guard !cleanBody.isEmpty, !resolved.isLocked, resolved.removedAt == nil else {
            Haptics.warning()
            return
        }
        repository.addReply(to: resolved, body: cleanBody, author: currentProfile)
        Haptics.success()
    }

    func reportCommunity(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String = "") {
        repository.reportCommunity(targetType: targetType, targetID: targetID, reason: reason, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        Haptics.warning()
    }

    func moderateThread(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String? = nil) {
        repository.moderateThread(thread, operation: operation, reason: reason)
        Haptics.warning()
    }

    func resolveCommunityReport(_ report: CommunityReport) {
        repository.resolveCommunityReport(report)
        Haptics.success()
    }

    // MARK: - Multi-community forum

    func forumCommunity(_ id: UUID) -> ForumCommunity? {
        communityStore.community(id)
    }

    func forumPost(_ id: UUID) -> ForumPost? {
        communityStore.post(id)
    }

    func forumMembership(for communityID: UUID) -> ForumMembership? {
        communityStore.membership(for: communityID)
    }

    func isJoinedToForumCommunity(_ communityID: UUID) -> Bool {
        communityStore.isJoined(to: communityID)
    }

    func canContributeToForumCommunity(_ communityID: UUID) -> Bool {
        communityStore.canContribute(to: communityID)
    }

    func canReadForumCommunity(_ communityID: UUID) -> Bool {
        communityStore.canRead(communityID)
    }

    func canModerateForumCommunity(_ communityID: UUID) -> Bool {
        communityStore.canModerate(communityID)
    }

    func setForumCommunityArchived(_ archived: Bool, communityID: UUID) {
        communityStore.setArchived(archived, communityID: communityID)
        Haptics.warning()
    }

    func forumFeed(
        communityID: UUID? = nil,
        sort: ForumFeedSort = .hot,
        topRange: ForumTopRange = .week,
        query: String = "",
        includeAllReadable: Bool = false
    ) -> [ForumPost] {
        communityStore.feed(
            communityID: communityID,
            sort: sort,
            topRange: topRange,
            query: query,
            includeAllReadable: includeAllReadable
        )
    }

    func forumHotScore(_ post: ForumPost, referenceDate: Date = .now) -> Double {
        communityStore.hotScore(post, referenceDate: referenceDate)
    }

    func forumSearchCommunities(query: String, category: String? = nil) -> [ForumCommunity] {
        communityStore.searchCommunities(query: query, category: category)
    }

    func forumComments(for postID: UUID, sort: ForumCommentSort = .best) -> [ForumComment] {
        communityStore.comments(for: postID, sort: sort)
    }

    func forumReplies(to commentID: UUID, postID: UUID) -> [ForumComment] {
        communityStore.replies(to: commentID, postID: postID)
    }

    @discardableResult
    func joinForumCommunity(_ communityID: UUID, note: String = "") -> ForumMembershipStatus? {
        let result = communityStore.join(communityID, note: note)
        if isAuthenticated, !isDemoMode {
            Task { await communityStore.syncJoin(communityID, note: note) }
        }
        result == .joined ? Haptics.success() : Haptics.light()
        return result
    }

    func leaveForumCommunity(_ communityID: UUID) {
        let community = communityStore.leave(communityID)
        if isAuthenticated, !isDemoMode, let community {
            Task { await communityStore.syncLeave(community) }
        }
        Haptics.light()
    }

    func setForumNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID) {
        communityStore.setNotificationLevel(level, communityID: communityID)
        Haptics.light()
    }

    func beginForumComposer(communityID: UUID? = nil, gymID: UUID? = nil, liftID: UUID? = nil, workoutID: UUID? = nil) {
        forumComposerCommunityID = communityID ?? joinedForumCommunities.first?.id
        forumComposerGymID = gymID
        forumComposerLiftID = liftID
        forumComposerWorkoutID = workoutID
        selectedTab = 3
        showingForumComposer = true
    }

    func clearForumComposerPreset() {
        forumComposerCommunityID = nil
        forumComposerGymID = nil
        forumComposerLiftID = nil
        forumComposerWorkoutID = nil
    }

    @discardableResult
    func createForumPost(
        communityID: UUID,
        kind: ForumPostKind,
        title: String,
        body: String,
        tag: String?,
        attachments: [ForumAttachment] = [],
        pollOptions: [String] = [],
        pollCloseDays: Int? = nil,
        liftID: UUID? = nil,
        workoutID: UUID? = nil,
        linkURL: URL? = nil
    ) -> Bool {
        let post = communityStore.createPost(
            destination: .community(communityID),
            kind: kind,
            title: title,
            body: body,
            tag: tag,
            attachments: attachments,
            pollOptions: pollOptions,
            pollCloseDays: pollCloseDays,
            liftID: liftID,
            workoutID: workoutID,
            linkURL: linkURL
        )
        if let post, isAuthenticated, !isDemoMode {
            Task {
                await communityStore.syncCreatedPost(post)
                if kind == .workoutShare { await track(.workoutShared, properties: ["workout_id": workoutID?.uuidString ?? "unknown"]) }
            }
        }
        post == nil ? Haptics.warning() : Haptics.success()
        return post != nil
    }

    @discardableResult
    func createForumGymPost(
        gymID: UUID,
        kind: ForumPostKind,
        title: String,
        body: String,
        attachments: [ForumAttachment] = [],
        pollOptions: [String] = [],
        pollCloseDays: Int? = nil,
        liftID: UUID? = nil,
        workoutID: UUID? = nil,
        linkURL: URL? = nil
    ) -> Bool {
        let post = communityStore.createPost(
            destination: .gym(gymID),
            kind: kind,
            title: title,
            body: body,
            attachments: attachments,
            pollOptions: pollOptions,
            pollCloseDays: pollCloseDays,
            liftID: liftID,
            workoutID: workoutID,
            linkURL: linkURL
        )
        if let post, isAuthenticated, !isDemoMode {
            Task {
                await communityStore.syncCreatedPost(post)
                if kind == .workoutShare { await track(.workoutShared, properties: ["workout_id": workoutID?.uuidString ?? "unknown"]) }
            }
        }
        post == nil ? Haptics.warning() : Haptics.success()
        return post != nil
    }

    func canContributeToForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canContributeToForumCommunity(communityID) }
        if let gymID = post.destination.gymID { return repository.joinedGymIDs.contains(gymID) }
        return false
    }

    func voteForumPost(_ postID: UUID, vote: CommunityVote?) {
        let post = communityStore.vote(on: postID, selection: vote)
        if isAuthenticated, !isDemoMode, let post {
            Task { await communityStore.syncVote(on: post, selection: vote) }
        }
        Haptics.light()
    }

    func toggleForumPostSaved(_ postID: UUID) {
        let post = communityStore.toggleSaved(postID: postID)
        if isAuthenticated, !isDemoMode, let post {
            Task { await communityStore.syncSavedState(of: post) }
        }
        Haptics.light()
    }

    func toggleForumPostWatched(_ postID: UUID) {
        let post = communityStore.toggleWatched(postID: postID)
        if isAuthenticated, !isDemoMode, let post {
            Task { await communityStore.syncWatchedState(of: post) }
        }
        Haptics.light()
    }

    func voteInForumPoll(postID: UUID, optionID: UUID) {
        let post = communityStore.voteInPoll(postID: postID, optionID: optionID)
        if isAuthenticated, !isDemoMode, let post {
            Task { await communityStore.syncPollVote(on: post, optionID: optionID) }
        }
        Haptics.light()
    }

    @discardableResult
    func addForumComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment? {
        let comment = communityStore.addComment(postID: postID, parentCommentID: parentCommentID, body: body)
        if isAuthenticated, !isDemoMode, let post = repository.forumPosts.first(where: { $0.id == postID }) {
            Task {
                await communityStore.syncComment(
                    on: post,
                    parentCommentID: parentCommentID,
                    body: body
                )
            }
        }
        comment == nil ? Haptics.warning() : Haptics.success()
        return comment
    }

    func voteForumComment(_ commentID: UUID, vote: CommunityVote?) {
        let comment = communityStore.vote(onComment: commentID, selection: vote)
        if isAuthenticated, !isDemoMode, let comment {
            Task { await communityStore.syncVote(on: comment, selection: vote) }
        }
        Haptics.light()
    }

    func deleteForumPost(_ postID: UUID) {
        communityStore.deletePost(postID)
        Haptics.warning()
    }

    func updateForumPost(_ post: ForumPost, title: String, body: String) {
        communityStore.update(post, title: title, body: body)
        Haptics.success()
    }

    func deleteForumComment(_ commentID: UUID) {
        communityStore.deleteComment(commentID)
        Haptics.warning()
    }

    @discardableResult
    func reportForumContent(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String = ""
    ) -> Bool {
        let submitted = communityStore.report(
            targetType: targetType,
            targetID: targetID,
            communityID: communityID,
            reason: reason,
            note: note
        )
        if submitted, isAuthenticated, !isDemoMode {
            Task {
                await communityStore.syncReport(
                    targetType: targetType,
                    targetID: targetID,
                    communityID: communityID,
                    reason: reason,
                    note: note
                )
            }
        }
        submitted ? Haptics.success() : Haptics.warning()
        return submitted
    }

    func moderateForumPost(_ postID: UUID, action: ForumModerationActionKind, reason: String = "") {
        let post = communityStore.moderate(postID: postID, action: action, reason: reason)
        if isAuthenticated, !isDemoMode, let post {
            Task { await communityStore.syncModeration(of: post, action: action, reason: reason) }
        }
        Haptics.warning()
    }

    func moderateForumComment(_ commentID: UUID, action: ForumModerationActionKind, reason: String = "") {
        communityStore.moderate(commentID: commentID, action: action, reason: reason)
        Haptics.warning()
    }

    func resolveForumReport(_ reportID: UUID, dismiss: Bool) {
        communityStore.resolveReport(reportID, dismiss: dismiss)
        Haptics.success()
    }

    func resolveForumJoinRequest(_ requestID: UUID, approved: Bool) {
        communityStore.resolveJoinRequest(requestID, approved: approved)
        Haptics.success()
    }

    func openForumNotification(_ notification: ForumNotification) {
        communityStore.markNotificationRead(notification.id)
        selectedCommunitySegment = "Inbox"
        if let postID = notification.postID {
            communityPath = [.post(postID)]
        } else if let communityID = notification.communityID {
            communityPath = [.community(communityID)]
        }
        selectedTab = 3
        Haptics.light()
    }

    func openForumPost(_ postID: UUID) {
        communityPath.append(.post(postID))
    }

    func openForumCommunity(_ communityID: UUID) {
        communityPath.append(.community(communityID))
    }

    func persistForumMedia(_ data: Data, fileExtension: String, mediaType: ForumMediaType) throws -> ForumAttachment {
        let url = try repository.persistForumMedia(data, fileExtension: fileExtension)
        return ForumAttachment(id: UUID(), mediaType: mediaType, localURL: url, createdAt: .now)
    }

    func removeForumMedia(at localURL: URL) {
        repository.removeForumMedia(at: localURL)
    }

    func removeForumMedia(_ attachments: [ForumAttachment]) {
        attachments.forEach { repository.removeForumMedia(at: $0.localURL) }
    }

    @discardableResult
    func createForumCommunity(
        name: String,
        summary: String,
        details: String,
        category: String,
        visibility: ForumCommunityVisibility,
        rules: [String]
    ) -> Bool {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return repository.createForumCommunity(ForumCommunity(
            id: UUID(), slug: slug, name: name, summary: summary, details: details,
            category: category, symbolName: "person.3.fill", accentHex: "3568FF",
            visibility: visibility, rules: rules, availableTags: [],
            staffOwnerID: currentProfile.id, memberCount: 1, postCount: 0,
            createdAt: .now, archivedAt: nil
        ))
    }

    func currentActivity(_ activity: ActivityItem) -> ActivityItem {
        communityStore.currentActivity(activity)
    }

    func comments(for activity: ActivityItem) -> [ActivityComment] {
        communityStore.comments(for: activity)
    }

    func toggleActivityLike(_ activity: ActivityItem) {
        if isAuthenticated && !isDemoMode {
            Task {
                do {
                    try await communityStore.setLiked(activity, isLiked: !activity.isLiked)
                    Haptics.light()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            repository.toggleActivityLike(activity)
            Haptics.light()
        }
    }

    func toggleActivitySave(_ activity: ActivityItem) {
        repository.toggleActivitySave(activity)
        Haptics.light()
    }

    func addComment(to activity: ActivityItem, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else {
            Haptics.warning()
            return
        }
        if isAuthenticated && !isDemoMode {
            Task {
                do {
                    try await communityStore.addRemoteComment(to: activity, body: cleanBody)
                    Haptics.success()
                } catch {
                    accountMessage = userMessage(error)
                    Haptics.warning()
                }
            }
        } else {
            repository.addComment(to: activity, body: cleanBody)
            Haptics.success()
        }
    }

    func refreshComments(for activity: ActivityItem) async {
        guard isAuthenticated && !isDemoMode else { return }
        do { try await communityStore.refreshComments(for: activity) }
        catch { accountMessage = userMessage(error) }
    }

    func createThread(title: String, body: String, kind: CommunityThreadKind = .general, challengeID: UUID? = nil, gymID: UUID? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            Haptics.warning()
            return
        }
        repository.addThread(
            CommunityThread(
                id: UUID(),
                title: cleanTitle,
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                authorID: currentProfile.id,
                authorName: currentProfile.displayName,
                kind: kind,
                challengeID: challengeID,
                gymID: gymID,
                replyCount: 0,
                likeCount: 0,
                createdAt: .now
            )
        )
        Haptics.success()
    }

    func requestGym(name: String, city: String, state: String, note: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            Haptics.warning()
            return
        }
        repository.requestGym(
            GymRequest(
                id: UUID(),
                name: cleanName,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                state: state.trimmingCharacters(in: .whitespacesAndNewlines),
                requestedBy: currentProfile.id,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: .now
            )
        )
        Haptics.success()
    }

}
