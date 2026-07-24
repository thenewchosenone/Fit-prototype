import Foundation

extension DemoRepository {
    func addThread(_ thread: CommunityThread) {
        communityThreads.insert(thread, at: 0)
        activities.insert(ActivityItem(id: UUID(), profile: currentProfile, title: "\(currentProfile.displayName) started a thread", detail: thread.title, createdAt: thread.createdAt, isLiked: false, isSaved: false), at: 0)
    }

    func addReply(to thread: CommunityThread, body: String, author: UserProfile) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }),
              !communityThreads[index].isLocked,
              communityThreads[index].removedAt == nil else { return }
        communityThreads[index].replyCount += 1
        communityThreadReplies.append(
            CommunityThreadReply(
                id: UUID(),
                threadID: thread.id,
                authorID: author.id,
                authorName: author.displayName,
                body: body,
                createdAt: .now
            )
        )
        activities.insert(ActivityItem(id: UUID(), profile: author, title: "\(author.displayName) replied to \(thread.title)", detail: body, createdAt: .now, isLiked: false, isSaved: false), at: 0)
    }

    func toggleThreadLike(_ thread: CommunityThread) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        voteThread(thread, vote: communityThreads[index].votes[currentProfile.id] == .up ? nil : .up)
    }

    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) {
        guard let index = communityThreads.firstIndex(where: { $0.id == thread.id }),
              communityThreads[index].removedAt == nil else { return }
        let previousVote = communityThreads[index].votes[currentProfile.id]
        communityThreads[index].votes[currentProfile.id] = vote
        let previousUpvote = previousVote == .up ? 1 : 0
        let nextUpvote = vote == .up ? 1 : 0
        communityThreads[index].likeCount = max(0, communityThreads[index].likeCount + nextUpvote - previousUpvote)
    }

    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) {
        guard let index = communityThreadReplies.firstIndex(where: { $0.id == reply.id }),
              communityThreadReplies[index].removedAt == nil else { return }
        communityThreadReplies[index].votes[currentProfile.id] = vote
    }

    func reportCommunity(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) {
        let duplicate = communityReports.contains { report in
            report.targetType == targetType &&
            report.targetID == targetID &&
            report.reporterID == currentProfile.id &&
            report.status == "Open"
        }
        guard !duplicate else { return }
        communityReports.insert(
            CommunityReport(id: UUID(), targetType: targetType, targetID: targetID, reporterID: currentProfile.id, reason: reason, note: note, status: "Open", createdAt: .now),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Community report submitted", message: "Thanks. Moderators can now review it.", kind: "Community report", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .communityThread, targetID: targetID)), at: 0)
    }

    func moderateThread(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String? = nil) {
        guard isForumStaff(),
              let index = communityThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        switch operation {
        case .lock:
            communityThreads[index].isLocked = true
        case .unlock:
            communityThreads[index].isLocked = false
        case .remove:
            communityThreads[index].removedAt = .now
            communityThreads[index].removalReason = reason ?? "Removed by a moderator."
        case .restore:
            communityThreads[index].removedAt = nil
            communityThreads[index].removalReason = nil
        case .warn:
            communityThreads[index].warning = reason ?? "Moderator warning"
        }
    }

    func resolveCommunityReport(_ report: CommunityReport) {
        guard isForumStaff(),
              let index = communityReports.firstIndex(where: { $0.id == report.id }) else { return }
        communityReports[index].status = "Resolved"
    }

    func toggleActivityLike(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isLiked.toggle()
    }

    func toggleActivitySave(_ activity: ActivityItem) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        activities[index].isSaved.toggle()
    }

    func addComment(to activity: ActivityItem, body: String) {
        appendActivityComment(
            ActivityComment(
                id: UUID(),
                activityID: activity.id,
                authorID: currentProfile.id,
                authorName: currentProfile.displayName,
                body: body,
                createdAt: .now
            )
        )
    }

    func replaceActivityComments(for activityID: UUID, with comments: [ActivityComment]) {
        activityComments.removeAll { $0.activityID == activityID }
        activityComments.append(contentsOf: comments)
    }

    func appendActivityComment(_ comment: ActivityComment) {
        guard !activityComments.contains(where: { $0.id == comment.id }) else { return }
        activityComments.append(comment)
    }

    func requestGym(_ request: GymRequest) {
        gymRequests.insert(request, at: 0)
        let demoGym = Gym(id: UUID(), name: request.name, city: request.city, state: request.state, memberCount: 1, verifiedLiftCount: 0)
        gyms.insert(demoGym, at: 0)
        communityThreads.insert(CommunityThread(id: UUID(), title: "\(request.name) members thread", body: "Use this thread for lift checks, meetups, and gym-specific questions.", authorID: currentProfile.id, authorName: currentProfile.displayName, kind: .gym, challengeID: nil, gymID: demoGym.id, replyCount: 0, likeCount: 0, createdAt: .now), at: 0)
        forumPosts.insert(ForumPost(
            id: UUID(), destination: .gym(demoGym.id), authorID: currentProfile.id,
            authorName: currentProfile.displayName, kind: .discussion,
            title: "Welcome to \(request.name)",
            body: "Use this gym discussion for lift checks, meetups, and equipment updates.",
            tag: nil, attachments: [], poll: nil, liftID: nil, workoutID: nil,
            linkURL: nil, challengeID: nil, createdAt: .now, editedAt: nil,
            commentCount: 0, votes: [:], savedByUserIDs: [], watchedByUserIDs: [],
            isPinned: true, isLocked: false, removedAt: nil, removalReason: nil
        ), at: 0)
        persistForumSnapshot()
        notifications.insert(NotificationItem(id: UUID(), title: "Gym request submitted", message: "\(request.name) is now available as a demo gym.", kind: "Gym request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .gym, targetID: demoGym.id, gymID: demoGym.id)), at: 0)
    }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool {
        guard !joinedGymIDs.contains(gym.id), joinedGymIDs.count < maximumMemberships else {
            return joinedGymIDs.contains(gym.id)
        }
        joinedGymIDs.insert(gym.id)
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount += 1
        }
        return true
    }

    func leaveGym(_ gym: Gym) {
        guard gym.id != currentProfile.primaryGymID, joinedGymIDs.remove(gym.id) != nil else { return }
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index].memberCount = max(0, gyms[index].memberCount - 1)
        }
    }

    func setChallengeJoined(_ challenge: Challenge, joined: Bool) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        let wasJoined = challenges[index].isJoined
        guard wasJoined != joined else { return }
        challenges[index].isJoined = joined
        challenges[index].participantCount += joined ? 1 : -1
        challenges[index].participantCount = max(0, challenges[index].participantCount)
    }

    func sendFriendRequest(to profile: UserProfile) {
        guard profile.id != currentProfile.id else { return }
        if let index = friendRequests.firstIndex(where: { request in
            (request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
            (request.fromUserID == profile.id && request.toUserID == currentProfile.id)
        }) {
            if friendRequests[index].status == .declined {
                friendRequests[index].fromUserID = currentProfile.id
                friendRequests[index].toUserID = profile.id
                friendRequests[index].status = .pending
                friendRequests[index].createdAt = .now
                friendRequests[index].respondedAt = nil
            }
            return
        }
        friendRequests.insert(
            FriendRequest(id: UUID(), fromUserID: currentProfile.id, toUserID: profile.id, status: .pending, createdAt: .now, respondedAt: nil),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request sent", message: "Request sent to \(profile.displayName).", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func respondToFriendRequest(_ request: FriendRequest, status: FriendRequestStatus) {
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else { return }
        friendRequests[index].status = status
        friendRequests[index].respondedAt = .now
        let otherID = request.fromUserID == currentProfile.id ? request.toUserID : request.fromUserID
        let otherName = profiles.first { $0.id == otherID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: status == .accepted ? "Friend request accepted" : "Friend request declined", message: "\(otherName) was updated.", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func cancelFriendRequest(_ request: FriendRequest) {
        guard request.fromUserID == currentProfile.id, request.status == .pending else { return }
        friendRequests.removeAll { $0.id == request.id }
        let otherName = profiles.first { $0.id == request.toUserID }?.displayName ?? "Lifter"
        notifications.insert(NotificationItem(id: UUID(), title: "Friend request canceled", message: "Request to \(otherName) was canceled.", kind: "Friend request", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .friendRequests)), at: 0)
    }

    func messageThread(with profile: UserProfile) -> DirectMessageThread {
        let isFriend = friendRequests.contains { request in
            request.status == .accepted &&
            ((request.fromUserID == currentProfile.id && request.toUserID == profile.id) ||
             (request.fromUserID == profile.id && request.toUserID == currentProfile.id))
        }
        guard isFriend || profile.id == currentProfile.id else {
            return messageThreads.first ?? DirectMessageThread(id: UUID(), participantIDs: [currentProfile.id, profile.id], createdAt: .now, updatedAt: .now)
        }
        if let thread = messageThreads.first(where: { Set($0.participantIDs) == Set([currentProfile.id, profile.id]) }) {
            return thread
        }
        let thread = DirectMessageThread(id: UUID(), participantIDs: [currentProfile.id, profile.id], createdAt: .now, updatedAt: .now)
        messageThreads.insert(thread, at: 0)
        return thread
    }

    func addMessage(to thread: DirectMessageThread, body: String) {
        guard !body.isEmpty else { return }
        let message = DirectMessage(id: UUID(), threadID: thread.id, senderID: currentProfile.id, body: body, createdAt: .now, isRead: true, isReported: false)
        directMessages.append(message)
        if let index = messageThreads.firstIndex(where: { $0.id == thread.id }) {
            messageThreads[index].updatedAt = message.createdAt
        }
    }

    func deleteMessage(_ message: DirectMessage) {
        directMessages.removeAll { $0.id == message.id }
        messageReports.removeAll { $0.messageID == message.id }
        if let latest = directMessages
            .filter({ $0.threadID == message.threadID })
            .max(by: { $0.createdAt < $1.createdAt }),
           let index = messageThreads.firstIndex(where: { $0.id == message.threadID }) {
            messageThreads[index].updatedAt = latest.createdAt
        }
    }

    func deleteMessageThread(_ thread: DirectMessageThread) {
        let messageIDs = Set(directMessages.filter { $0.threadID == thread.id }.map(\.id))
        directMessages.removeAll { $0.threadID == thread.id }
        messageReports.removeAll { messageIDs.contains($0.messageID) }
        messageThreads.removeAll { $0.id == thread.id }
    }

    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) {
        if let index = directMessages.firstIndex(where: { $0.id == message.id }) {
            directMessages[index].isReported = true
        }
        messageReports.insert(
            MessageReport(id: UUID(), messageID: message.id, reporterID: currentProfile.id, reason: reason, note: note, createdAt: .now),
            at: 0
        )
        notifications.insert(NotificationItem(id: UUID(), title: "Message reported", message: "Thanks. We flagged the message for review.", kind: "Message report", createdAt: .now, isRead: false, destination: NotificationDestination(kind: .messageThread, targetID: message.threadID)), at: 0)
    }

    // MARK: - Multi-community forum

    func forumMembership(communityID: UUID, userID: UUID? = nil) -> ForumMembership? {
        let resolvedUserID = userID ?? currentProfile.id
        return forumMemberships.first { $0.communityID == communityID && $0.userID == resolvedUserID }
    }

    func isForumStaff(_ userID: UUID? = nil) -> Bool {
        forumGlobalStaffUserIDs.contains(userID ?? currentProfile.id)
    }

    func canReadForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        guard let community = forumCommunities.first(where: { $0.id == communityID }),
              community.archivedAt == nil else { return false }
        if isForumStaff(userID) || community.visibility == .publicOpen { return true }
        return forumMembership(communityID: communityID, userID: userID)?.isActive == true
    }

    func canContributeToForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        guard let community = forumCommunities.first(where: { $0.id == communityID }),
              community.archivedAt == nil else { return false }
        return forumMembership(communityID: communityID, userID: resolvedUserID)?.canContribute == true
    }

    func canModerateForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        if isForumStaff(resolvedUserID) { return true }
        guard let membership = forumMembership(communityID: communityID, userID: resolvedUserID),
              membership.isActive else { return false }
        return membership.role.authority >= ForumMemberRole.moderator.authority
    }

    func canAdministerForumCommunity(_ communityID: UUID, userID: UUID? = nil) -> Bool {
        let resolvedUserID = userID ?? currentProfile.id
        if isForumStaff(resolvedUserID) { return true }
        guard let membership = forumMembership(communityID: communityID, userID: resolvedUserID),
              membership.isActive else { return false }
        return membership.role.authority >= ForumMemberRole.admin.authority
    }

    func visibleForumCommunities(for userID: UUID? = nil) -> [ForumCommunity] {
        let resolvedUserID = userID ?? currentProfile.id
        return forumCommunities.filter { community in
            guard community.archivedAt == nil else { return isForumStaff(resolvedUserID) }
            guard community.visibility == .inviteOnly else { return true }
            return isForumStaff(resolvedUserID) || forumMembership(communityID: community.id, userID: resolvedUserID) != nil
        }
    }

    @discardableResult
    func joinForumCommunity(_ communityID: UUID, note: String = "") -> ForumMembershipStatus? {
        guard let communityIndex = forumCommunities.firstIndex(where: { $0.id == communityID }),
              forumCommunities[communityIndex].archivedAt == nil else { return nil }
        let userID = currentProfile.id
        let visibility = forumCommunities[communityIndex].visibility
        let existingIndex = forumMemberships.firstIndex { $0.communityID == communityID && $0.userID == userID }
        if let existingIndex, forumMemberships[existingIndex].status == .banned { return .banned }

        switch visibility {
        case .publicOpen:
            let wasActive = existingIndex.map { forumMemberships[$0].isActive } ?? false
            if let existingIndex {
                forumMemberships[existingIndex].status = .joined
                forumMemberships[existingIndex].joinedAt = forumMemberships[existingIndex].joinedAt ?? .now
                forumMemberships[existingIndex].mutedUntil = nil
            } else {
                forumMemberships.append(ForumMembership(
                    id: UUID(), communityID: communityID, userID: userID, role: .member,
                    status: .joined, notificationLevel: .mentions, joinedAt: .now,
                    mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
                ))
            }
            if !wasActive { forumCommunities[communityIndex].memberCount += 1 }
            persistForumSnapshot()
            return .joined

        case .restricted:
            if let existingIndex, forumMemberships[existingIndex].isActive { return forumMemberships[existingIndex].status }
            if let existingIndex {
                forumMemberships[existingIndex].status = .pending
            } else {
                forumMemberships.append(ForumMembership(
                    id: UUID(), communityID: communityID, userID: userID, role: .member,
                    status: .pending, notificationLevel: .mentions, joinedAt: nil,
                    mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
                ))
            }
            if !forumJoinRequests.contains(where: { $0.communityID == communityID && $0.userID == userID && $0.status == "Pending" }) {
                forumJoinRequests.insert(ForumJoinRequest(
                    id: UUID(), communityID: communityID, userID: userID, note: note,
                    status: "Pending", createdAt: .now, resolvedAt: nil, resolvedBy: nil
                ), at: 0)
            }
            persistForumSnapshot()
            return .pending

        case .inviteOnly:
            guard let existingIndex, forumMemberships[existingIndex].status == .invited else { return nil }
            forumMemberships[existingIndex].status = .joined
            forumMemberships[existingIndex].joinedAt = .now
            forumCommunities[communityIndex].memberCount += 1
            persistForumSnapshot()
            return .joined
        }
    }

    func leaveForumCommunity(_ communityID: UUID) {
        guard let membershipIndex = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == currentProfile.id && $0.isActive
        }) else { return }
        forumMemberships[membershipIndex].status = .left
        forumMemberships[membershipIndex].notificationLevel = .off
        if let communityIndex = forumCommunities.firstIndex(where: { $0.id == communityID }) {
            forumCommunities[communityIndex].memberCount = max(0, forumCommunities[communityIndex].memberCount - 1)
        }
        persistForumSnapshot()
    }

    func setForumNotificationLevel(_ level: ForumNotificationLevel, communityID: UUID) {
        guard let index = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == currentProfile.id && $0.isActive
        }) else { return }
        forumMemberships[index].notificationLevel = level
        persistForumSnapshot()
    }

    @discardableResult
    func inviteForumMember(userID: UUID, communityID: UUID) -> Bool {
        guard canAdministerForumCommunity(communityID),
              !isForumStaff(userID),
              forumCommunities.contains(where: { $0.id == communityID && $0.archivedAt == nil }) else { return false }
        if let index = forumMemberships.firstIndex(where: { $0.communityID == communityID && $0.userID == userID }) {
            guard forumMemberships[index].status != .banned else { return false }
            forumMemberships[index].status = .invited
            forumMemberships[index].invitedBy = currentProfile.id
        } else {
            forumMemberships.append(ForumMembership(
                id: UUID(), communityID: communityID, userID: userID, role: .member,
                status: .invited, notificationLevel: .mentions, joinedAt: nil,
                mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: currentProfile.id
            ))
        }
        addForumNotification(
            userID: userID, kind: .membership, title: "Community invitation",
            message: "You were invited to join a private community.",
            communityID: communityID, postID: nil, commentID: nil
        )
        persistForumSnapshot()
        return true
    }

    func setForumMemberRole(userID: UUID, communityID: UUID, role: ForumMemberRole) {
        guard canAdministerForumCommunity(communityID),
              !isForumStaff(userID),
              role != .staff,
              let index = forumMemberships.firstIndex(where: {
                  $0.communityID == communityID && $0.userID == userID && $0.isActive
              }) else { return }
        if !isForumStaff(), role == .admin { return }
        forumMemberships[index].role = role
        persistForumSnapshot()
    }

    @discardableResult
    func createForumCommunity(_ community: ForumCommunity) -> Bool {
        guard isForumStaff(),
              !forumCommunities.contains(where: { $0.slug.caseInsensitiveCompare(community.slug) == .orderedSame }) else { return false }
        forumCommunities.append(community)
        forumMemberships.append(ForumMembership(
            id: UUID(), communityID: community.id, userID: currentProfile.id, role: .staff,
            status: .joined, notificationLevel: .all, joinedAt: .now,
            mutedUntil: nil, bannedAt: nil, restrictionReason: nil, invitedBy: nil
        ))
        persistForumSnapshot()
        return true
    }

    func updateForumCommunity(_ community: ForumCommunity) {
        guard canAdministerForumCommunity(community.id),
              let index = forumCommunities.firstIndex(where: { $0.id == community.id }) else { return }
        forumCommunities[index] = community
        persistForumSnapshot()
    }

    func setForumCommunityArchived(_ communityID: UUID, archived: Bool) {
        guard isForumStaff(), let index = forumCommunities.firstIndex(where: { $0.id == communityID }) else { return }
        forumCommunities[index].archivedAt = archived ? .now : nil
        recordForumModerationAction(
            communityID: communityID, kind: .archive, targetID: communityID,
            reason: archived ? "Community archived" : "Community restored"
        )
        persistForumSnapshot()
    }

    @discardableResult
    func createForumPost(_ post: ForumPost) -> Bool {
        let titleCount = post.title.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard (5...140).contains(titleCount), post.body.count <= 10_000 else { return false }
        if post.attachments.count > 4 { return false }
        if post.attachments.contains(where: { $0.mediaType == .video }) && post.attachments.count > 1 { return false }
        if post.kind == .poll, !(2...6).contains(post.poll?.options.count ?? 0) { return false }
        if post.kind == .link {
            guard let url = post.linkURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        }
        if let communityID = post.destination.communityID {
            guard canContributeToForumCommunity(communityID) else { return false }
        } else if let gymID = post.destination.gymID {
            guard joinedGymIDs.contains(gymID) else { return false }
        }
        forumPosts.insert(post, at: 0)
        if let communityID = post.destination.communityID,
           let index = forumCommunities.firstIndex(where: { $0.id == communityID }) {
            forumCommunities[index].postCount += 1
        }
        createForumMentionNotifications(body: "\(post.title) \(post.body)", postID: post.id, commentID: nil, communityID: post.destination.communityID)
        persistForumSnapshot()
        return true
    }

    func updateForumPost(_ post: ForumPost) {
        guard let index = forumPosts.firstIndex(where: { $0.id == post.id }),
              forumPosts[index].authorID == currentProfile.id,
              forumPosts[index].removedAt == nil else { return }
        var updated = post
        updated.editedAt = .now
        forumPosts[index] = updated
        persistForumSnapshot()
    }

    func softDeleteForumPost(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              forumPosts[index].authorID == currentProfile.id || canModerateForumPost(forumPosts[index]) else { return }
        forumPosts[index].attachments.forEach { removeForumMedia(at: $0.localURL) }
        forumPosts[index].attachments = []
        forumPosts[index].body = ""
        forumPosts[index].removedAt = .now
        forumPosts[index].removalReason = "Deleted"
        persistForumSnapshot()
    }

    func voteForumPost(_ postID: UUID, vote: CommunityVote?) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              forumPosts[index].removedAt == nil,
              canContributeToForumPost(forumPosts[index]) else { return }
        forumPosts[index].votes[currentProfile.id] = vote
        persistForumSnapshot()
    }

    func toggleForumPostSaved(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[index]) else { return }
        if !forumPosts[index].savedByUserIDs.insert(currentProfile.id).inserted {
            forumPosts[index].savedByUserIDs.remove(currentProfile.id)
        }
        persistForumSnapshot()
    }

    func toggleForumPostWatched(_ postID: UUID) {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[index]) else { return }
        if !forumPosts[index].watchedByUserIDs.insert(currentProfile.id).inserted {
            forumPosts[index].watchedByUserIDs.remove(currentProfile.id)
        }
        persistForumSnapshot()
    }

    func voteInForumPoll(postID: UUID, optionID: UUID) {
        guard let postIndex = forumPosts.firstIndex(where: { $0.id == postID }),
              canContributeToForumPost(forumPosts[postIndex]),
              var poll = forumPosts[postIndex].poll,
              !poll.isClosed,
              poll.options.contains(where: { $0.id == optionID }) else { return }
        for index in poll.options.indices {
            poll.options[index].voterIDs.remove(currentProfile.id)
            if poll.options[index].id == optionID { poll.options[index].voterIDs.insert(currentProfile.id) }
        }
        forumPosts[postIndex].poll = poll
        persistForumSnapshot()
    }

    @discardableResult
    func addForumComment(postID: UUID, parentCommentID: UUID?, body: String) -> ForumComment? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 10_000,
              let postIndex = forumPosts.firstIndex(where: { $0.id == postID }),
              !forumPosts[postIndex].isLocked,
              forumPosts[postIndex].removedAt == nil,
              canContributeToForumPost(forumPosts[postIndex]) else { return nil }

        let selectedParent = parentCommentID.flatMap { parentID in
            forumComments.first { $0.id == parentID && $0.postID == postID }
        }

        let comment = ForumComment(
            id: UUID(), postID: postID, parentCommentID: selectedParent?.id,
            authorID: currentProfile.id, authorName: currentProfile.displayName,
            body: trimmed, createdAt: .now, editedAt: nil,
            votes: [:], removedAt: nil, removalReason: nil
        )
        forumComments.append(comment)
        forumPosts[postIndex].commentCount += 1

        if let selectedParent, selectedParent.authorID != currentProfile.id {
            addForumNotification(
                userID: selectedParent.authorID, kind: .reply,
                title: "New reply", message: "\(currentProfile.displayName) replied to your comment.",
                communityID: forumPosts[postIndex].destination.communityID,
                postID: postID, commentID: comment.id
            )
        } else if forumPosts[postIndex].authorID != currentProfile.id {
            addForumNotification(
                userID: forumPosts[postIndex].authorID, kind: .reply,
                title: "New comment", message: "\(currentProfile.displayName) commented on your post.",
                communityID: forumPosts[postIndex].destination.communityID,
                postID: postID, commentID: comment.id
            )
        }
        if selectedParent == nil {
            notifyForumWatchers(for: forumPosts[postIndex], comment: comment)
        }
        createForumMentionNotifications(body: trimmed, postID: postID, commentID: comment.id, communityID: forumPosts[postIndex].destination.communityID)
        persistForumSnapshot()
        return comment
    }

    func updateForumComment(_ comment: ForumComment, body: String) {
        guard let index = forumComments.firstIndex(where: { $0.id == comment.id }),
              forumComments[index].authorID == currentProfile.id,
              forumComments[index].removedAt == nil else { return }
        forumComments[index].body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        forumComments[index].editedAt = .now
        persistForumSnapshot()
    }

    func softDeleteForumComment(_ commentID: UUID) {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              forumComments[index].authorID == currentProfile.id || canModerateForumComment(forumComments[index]) else { return }
        forumComments[index].body = ""
        forumComments[index].removedAt = .now
        forumComments[index].removalReason = "Deleted"
        persistForumSnapshot()
    }

    func voteForumComment(_ commentID: UUID, vote: CommunityVote?) {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              forumComments[index].removedAt == nil,
              let post = forumPosts.first(where: { $0.id == forumComments[index].postID }),
              canContributeToForumPost(post) else { return }
        forumComments[index].votes[currentProfile.id] = vote
        persistForumSnapshot()
    }

    @discardableResult
    func reportForumContent(
        targetType: ForumReportTargetType,
        targetID: UUID,
        communityID: UUID?,
        reason: CommunityReportReason,
        note: String
    ) -> Bool {
        let duplicate = forumReports.contains {
            $0.targetType == targetType && $0.targetID == targetID &&
            $0.reporterID == currentProfile.id && $0.status == .open
        }
        guard !duplicate else { return false }
        forumReports.insert(ForumReport(
            id: UUID(), communityID: communityID, targetType: targetType, targetID: targetID,
            reporterID: currentProfile.id, reason: reason, note: note,
            status: .open, createdAt: .now, resolvedAt: nil, resolvedBy: nil
        ), at: 0)
        persistForumSnapshot()
        return true
    }

    func resolveForumJoinRequest(_ requestID: UUID, approved: Bool) {
        guard let requestIndex = forumJoinRequests.firstIndex(where: { $0.id == requestID }),
              canAdministerForumCommunity(forumJoinRequests[requestIndex].communityID) else { return }
        let request = forumJoinRequests[requestIndex]
        forumJoinRequests[requestIndex].status = approved ? "Approved" : "Declined"
        forumJoinRequests[requestIndex].resolvedAt = .now
        forumJoinRequests[requestIndex].resolvedBy = currentProfile.id
        if let membershipIndex = forumMemberships.firstIndex(where: {
            $0.communityID == request.communityID && $0.userID == request.userID
        }) {
            forumMemberships[membershipIndex].status = approved ? .joined : .declined
            forumMemberships[membershipIndex].joinedAt = approved ? .now : nil
        }
        if approved, let communityIndex = forumCommunities.firstIndex(where: { $0.id == request.communityID }) {
            forumCommunities[communityIndex].memberCount += 1
        }
        addForumNotification(
            userID: request.userID, kind: .membership,
            title: approved ? "Membership approved" : "Membership declined",
            message: approved ? "You can now participate in the community." : "Your membership request was declined.",
            communityID: request.communityID, postID: nil, commentID: nil
        )
        recordForumModerationAction(
            communityID: request.communityID, kind: approved ? .approve : .decline,
            targetID: request.userID, reason: approved ? "Membership approved" : "Membership declined"
        )
        persistForumSnapshot()
    }

    func resolveForumReport(_ reportID: UUID, dismiss: Bool) {
        guard let index = forumReports.firstIndex(where: { $0.id == reportID }),
              forumReports[index].communityID.map({ canModerateForumCommunity($0) }) ?? isForumStaff() else { return }
        forumReports[index].status = dismiss ? .dismissed : .resolved
        forumReports[index].resolvedAt = .now
        forumReports[index].resolvedBy = currentProfile.id
        persistForumSnapshot()
    }

    func moderateForumPost(_ postID: UUID, action: ForumModerationActionKind, reason: String = "") {
        guard let index = forumPosts.firstIndex(where: { $0.id == postID }),
              canModerateForumPost(forumPosts[index]) else { return }
        switch action {
        case .pin: forumPosts[index].isPinned = true
        case .unpin: forumPosts[index].isPinned = false
        case .lock: forumPosts[index].isLocked = true
        case .unlock: forumPosts[index].isLocked = false
        case .remove:
            forumPosts[index].removedAt = .now
            forumPosts[index].removalReason = reason.isEmpty ? "Removed by a moderator" : reason
        case .restore:
            forumPosts[index].removedAt = nil
            forumPosts[index].removalReason = nil
        case .warn:
            addForumNotification(
                userID: forumPosts[index].authorID, kind: .moderation,
                title: "Moderator warning", message: reason.isEmpty ? "A moderator reviewed your post." : reason,
                communityID: forumPosts[index].destination.communityID, postID: postID, commentID: nil
            )
        default: return
        }
        recordForumModerationAction(
            communityID: forumPosts[index].destination.communityID,
            kind: action, targetID: postID, reason: reason
        )
        persistForumSnapshot()
    }

    func moderateForumComment(_ commentID: UUID, action: ForumModerationActionKind, reason: String = "") {
        guard let index = forumComments.firstIndex(where: { $0.id == commentID }),
              canModerateForumComment(forumComments[index]),
              let post = forumPosts.first(where: { $0.id == forumComments[index].postID }) else { return }
        switch action {
        case .remove:
            forumComments[index].removedAt = .now
            forumComments[index].removalReason = reason.isEmpty ? "Removed by a moderator" : reason
        case .restore:
            forumComments[index].removedAt = nil
            forumComments[index].removalReason = nil
        case .warn:
            addForumNotification(
                userID: forumComments[index].authorID, kind: .moderation,
                title: "Moderator warning", message: reason.isEmpty ? "A moderator reviewed your comment." : reason,
                communityID: post.destination.communityID, postID: post.id, commentID: commentID
            )
        default: return
        }
        recordForumModerationAction(
            communityID: post.destination.communityID, kind: action,
            targetID: commentID, reason: reason
        )
        persistForumSnapshot()
    }

    func moderateForumMember(
        userID: UUID,
        communityID: UUID,
        action: ForumModerationActionKind,
        reason: String,
        mutedUntil: Date? = nil
    ) {
        guard let targetIndex = forumMemberships.firstIndex(where: {
            $0.communityID == communityID && $0.userID == userID
        }), canRestrictForumMembership(forumMemberships[targetIndex], communityID: communityID) else { return }
        switch action {
        case .warn:
            break
        case .mute:
            forumMemberships[targetIndex].status = .muted
            forumMemberships[targetIndex].mutedUntil = mutedUntil ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)
            forumMemberships[targetIndex].restrictionReason = reason
        case .ban:
            forumMemberships[targetIndex].status = .banned
            forumMemberships[targetIndex].bannedAt = .now
            forumMemberships[targetIndex].restrictionReason = reason
        default: return
        }
        addForumNotification(
            userID: userID, kind: .moderation, title: action.rawValue,
            message: reason.isEmpty ? "A moderator updated your community access." : reason,
            communityID: communityID, postID: nil, commentID: nil
        )
        recordForumModerationAction(communityID: communityID, kind: action, targetID: userID, reason: reason)
        persistForumSnapshot()
    }

    func markForumNotificationRead(_ notificationID: UUID) {
        guard let index = forumNotifications.firstIndex(where: { $0.id == notificationID }) else { return }
        forumNotifications[index].isRead = true
        persistForumSnapshot()
    }

    private func canContributeToForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canContributeToForumCommunity(communityID) }
        if let gymID = post.destination.gymID { return joinedGymIDs.contains(gymID) }
        return false
    }

    private func canModerateForumPost(_ post: ForumPost) -> Bool {
        if let communityID = post.destination.communityID { return canModerateForumCommunity(communityID) }
        return isForumStaff()
    }

    private func canModerateForumComment(_ comment: ForumComment) -> Bool {
        guard let post = forumPosts.first(where: { $0.id == comment.postID }) else { return false }
        return canModerateForumPost(post)
    }

    private func canRestrictForumMembership(_ target: ForumMembership, communityID: UUID) -> Bool {
        guard canModerateForumCommunity(communityID), !isForumStaff(target.userID) else { return false }
        let actorAuthority = isForumStaff() ? ForumMemberRole.staff.authority :
            (forumMembership(communityID: communityID)?.role.authority ?? -1)
        return actorAuthority > target.role.authority
    }

    private func recordForumModerationAction(
        communityID: UUID?,
        kind: ForumModerationActionKind,
        targetID: UUID,
        reason: String
    ) {
        forumModerationActions.insert(ForumModerationAction(
            id: UUID(), communityID: communityID, moderatorID: currentProfile.id,
            kind: kind, targetID: targetID, reason: reason, createdAt: .now
        ), at: 0)
    }

    private func addForumNotification(
        userID: UUID,
        kind: ForumNotificationKind,
        title: String,
        message: String,
        communityID: UUID?,
        postID: UUID?,
        commentID: UUID?
    ) {
        guard userID != currentProfile.id else { return }
        forumNotifications.insert(ForumNotification(
            id: UUID(), userID: userID, actorID: currentProfile.id, kind: kind,
            title: title, message: message, communityID: communityID,
            postID: postID, commentID: commentID, createdAt: .now, isRead: false
        ), at: 0)
    }

    private func createForumMentionNotifications(body: String, postID: UUID, commentID: UUID?, communityID: UUID?) {
        let pattern = "@([A-Za-z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        let usernames = Set(regex.matches(in: body, range: range).compactMap { result -> String? in
            guard let usernameRange = Range(result.range(at: 1), in: body) else { return nil }
            return String(body[usernameRange]).lowercased()
        })
        for profile in profiles where usernames.contains(profile.username.lowercased()) {
            addForumNotification(
                userID: profile.id, kind: .mention, title: "You were mentioned",
                message: "\(currentProfile.displayName) mentioned you in the forum.",
                communityID: communityID, postID: postID, commentID: commentID
            )
        }
    }

    private func notifyForumWatchers(for post: ForumPost, comment: ForumComment) {
        for userID in post.watchedByUserIDs where userID != currentProfile.id {
            if let communityID = post.destination.communityID,
               forumMembership(communityID: communityID, userID: userID)?.notificationLevel == .off { continue }
            addForumNotification(
                userID: userID, kind: .watchedPost, title: "Watched post updated",
                message: "\(comment.authorName) added a new comment.",
                communityID: post.destination.communityID, postID: post.id, commentID: comment.id
            )
        }
    }
}

enum CommunityModerationOperation {
    case lock
    case unlock
    case remove
    case restore
    case warn
}
