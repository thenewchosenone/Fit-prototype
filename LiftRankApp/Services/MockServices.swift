import Foundation

@MainActor
final class MockAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
    var isConfigured: Bool { true }
    var isDemoMode: Bool { true }

    init(repository: DemoRepository) {
        self.repository = repository
    }

    func restoreSession() async throws -> AccountSession? { nil }
    func signUp(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func signIn(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func requestPasswordReset(email: String) async throws {}
    func signInDemo() async throws -> UserProfile { repository.currentProfile }
    func signOut() async throws {}
}

@MainActor
final class MockProfileService: ProfileService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func currentProfile() async throws -> UserProfile { repository.currentProfile }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        repository.currentProfile = profile
        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            repository.profiles[index] = profile
        }
        return profile
    }
    func authenticatedProfile() async throws -> AuthenticatedProfile {
        let profile = repository.currentProfile
        return AuthenticatedProfile(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: "", avatarPath: profile.avatarPath, onboardingCompleted: true,
            preferredUnit: profile.preferredUnit, birthDate: nil, sexCategory: profile.sexCategory,
            heightCentimeters: profile.heightInches * 2.54, city: profile.city,
            region: profile.state, countryCode: "US", yearsExperience: profile.yearsExperience,
            experienceLevel: profile.experienceLevel,
            privacy: ProfilePrivacySettings(
                ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
                bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
                locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
                gymAudience: profile.hideGym ? .privateProfile : .publicProfile
            )
        )
    }
    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        var profile = repository.currentProfile
        profile.username = draft.username
        profile.displayName = draft.displayName
        profile.preferredUnit = draft.preferredUnit
        profile.sexCategory = draft.sexCategory ?? .open
        profile.heightInches = (draft.heightCentimeters ?? profile.heightInches * 2.54) / 2.54
        profile.city = draft.city
        profile.state = draft.region
        profile.yearsExperience = draft.yearsExperience ?? profile.yearsExperience
        profile.experienceLevel = draft.experienceLevel ?? profile.experienceLevel
        _ = try await updateProfile(profile)
        return try await authenticatedProfile()
    }
    func claimUsername(_ username: String) async throws -> String {
        let normalized = username.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            throw LiftRankServiceError.invalidInput("Use 3–24 lowercase letters, numbers, or underscores.")
        }
        repository.currentProfile.username = normalized
        return normalized
    }
    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        guard let profile = repository.profiles.first(where: { $0.id == userID }) else {
            throw LiftRankServiceError.server("Profile not found.")
        }
        return PublicProfileCard(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: "", avatarPath: profile.avatarPath, ageBand: profile.hideExactAge ? nil : profile.ageGroup,
            sexCategory: profile.sexCategory, city: profile.hideCity ? nil : profile.city,
            region: profile.hideCity ? nil : profile.state, countryCode: nil,
            primaryGymID: profile.hideGym ? nil : profile.primaryGymID,
            primaryGymName: profile.hideGym ? nil : profile.primaryGymName
        )
    }
}

@MainActor
final class MockLiftService: LiftService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func submissions() async throws -> [LiftSubmission] { repository.lifts }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        repository.addLift(submission)
        return submission
    }
}

@MainActor
final class MockLeaderboardService: LeaderboardService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        var filtered = repository.lifts
        if let exerciseID = filters.exerciseID {
            filtered = filtered.filter { $0.exerciseID == exerciseID }
        }
        if let status = filters.verificationLevel {
            filtered = filtered.filter { $0.verificationStatus == status }
        }
        if let gymID = filters.gymID {
            filtered = filtered.filter { $0.gymID == gymID }
        }
        if let level = filters.experienceLevel {
            let ids = repository.profiles.filter { $0.experienceLevel == level }.map(\.id)
            filtered = filtered.filter { ids.contains($0.userID) }
        }
        return RankingCalculator.leaderboardEntries(
            profiles: repository.profiles,
            lifts: filtered,
            rankingType: filters.rankingType,
            verifiedOnly: verifiedOnly,
            currentUserID: repository.currentProfile.id
        )
    }
}

@MainActor
final class MockGymService: GymService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func gyms() async throws -> [Gym] { repository.gyms }
    func memberships() async throws -> [GymMembershipRecord] {
        repository.joinedGymIDs.map { gymID in
            GymMembershipRecord(
                userID: repository.currentProfile.id, gymID: gymID,
                isPrimary: gymID == repository.currentProfile.primaryGymID,
                joinedAt: .now, leftAt: nil
            )
        }
    }
}

@MainActor
final class MockChallengeService: ChallengeService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func challenges() async throws -> [Challenge] { repository.challenges }
    func join(_ challenge: Challenge) async throws -> Challenge {
        guard let index = repository.challenges.firstIndex(where: { $0.id == challenge.id }) else { return challenge }
        repository.challenges[index].isJoined = true
        repository.challenges[index].participantCount += 1
        return repository.challenges[index]
    }
}

@MainActor
final class MockSocialService: SocialService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func feed() async throws -> [ActivityItem] { repository.activities }
}

@MainActor
final class MockCommunityService: CommunityService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func communities() async throws -> [ForumCommunity] { repository.visibleForumCommunities() }
    func posts(in destination: ForumDestination?) async throws -> [ForumPost] {
        guard let destination else { return repository.forumPosts }
        return repository.forumPosts.filter { $0.destination == destination }
    }
    func comments(for post: ForumPost) async throws -> [ForumComment] {
        repository.forumComments.filter { $0.postID == post.id }
    }
    func join(community: ForumCommunity, note: String) async throws -> ForumMembershipStatus? {
        repository.joinForumCommunity(community.id, note: note)
    }
    func leave(community: ForumCommunity) async throws { repository.leaveForumCommunity(community.id) }
    func createPost(_ post: ForumPost) async throws -> Bool { repository.createForumPost(post) }
    func addComment(to post: ForumPost, parentCommentID: UUID?, body: String) async throws -> ForumComment? {
        repository.addForumComment(postID: post.id, parentCommentID: parentCommentID, body: body)
    }
    func vote(post: ForumPost, vote: CommunityVote?) async throws { repository.voteForumPost(post.id, vote: vote) }
    func vote(comment: ForumComment, vote: CommunityVote?) async throws { repository.voteForumComment(comment.id, vote: vote) }
    func toggleSaved(post: ForumPost) async throws { repository.toggleForumPostSaved(post.id) }
    func toggleWatched(post: ForumPost) async throws { repository.toggleForumPostWatched(post.id) }
    func vote(pollPost: ForumPost, optionID: UUID) async throws {
        repository.voteInForumPoll(postID: pollPost.id, optionID: optionID)
    }
    func report(targetType: ForumReportTargetType, targetID: UUID, communityID: UUID?, reason: CommunityReportReason, note: String) async throws -> Bool {
        repository.reportForumContent(targetType: targetType, targetID: targetID, communityID: communityID, reason: reason, note: note)
    }
    func moderate(post: ForumPost, action: ForumModerationActionKind, reason: String) async throws {
        repository.moderateForumPost(post.id, action: action, reason: reason)
    }
    func threads() async throws -> [CommunityThread] { repository.communityThreads }
    func replies(for thread: CommunityThread) async throws -> [CommunityThreadReply] {
        repository.communityThreadReplies.filter { $0.threadID == thread.id }
    }
    func createThread(_ thread: CommunityThread) async throws -> CommunityThread {
        repository.addThread(thread)
        return thread
    }
    func addReply(to thread: CommunityThread, body: String) async throws -> CommunityThreadReply? {
        let before = repository.communityThreadReplies.count
        repository.addReply(to: thread, body: body, author: repository.currentProfile)
        return repository.communityThreadReplies.count > before ? repository.communityThreadReplies.last : nil
    }
    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) async throws {
        repository.voteThread(thread, vote: vote)
    }
    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) async throws {
        repository.voteReply(reply, vote: vote)
    }
    func report(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) async throws {
        repository.reportCommunity(targetType: targetType, targetID: targetID, reason: reason, note: note)
    }
    func moderate(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String?) async throws {
        repository.moderateThread(thread, operation: operation, reason: reason)
    }
}

@MainActor
final class MockMessagingService: MessagingService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func threads() async throws -> [DirectMessageThread] { repository.messageThreads }
    func messages(for thread: DirectMessageThread) async throws -> [DirectMessage] {
        repository.directMessages.filter { $0.threadID == thread.id }
    }
    func sendMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessage? {
        let before = repository.directMessages.count
        repository.addMessage(to: thread, body: body)
        return repository.directMessages.count > before ? repository.directMessages.last : nil
    }
    func deleteMessage(_ message: DirectMessage) async throws {
        repository.deleteMessage(message)
    }
    func deleteThread(_ thread: DirectMessageThread) async throws {
        repository.deleteMessageThread(thread)
    }
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws {
        repository.reportMessage(message, reason: reason, note: note)
    }
}

@MainActor
final class MockGymMembershipService: GymMembershipService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool {
        repository.joinGym(gym, maximumMemberships: maximumMemberships)
    }
    func leave(_ gym: Gym) async throws {
        repository.leaveGym(gym)
    }
    func setPrimary(_ gym: Gym) async throws {
        guard repository.joinedGymIDs.contains(gym.id) else {
            throw LiftRankServiceError.invalidInput("Join this gym before making it primary.")
        }
        repository.currentProfile.primaryGymID = gym.id
        repository.currentProfile.primaryGymName = gym.name
    }
}

@MainActor
final class MockFriendRelationshipService: FriendRelationshipService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func relationships() async throws -> [FriendRelationshipRecord] {
        repository.friendRequests.map { request in
            let low = request.fromUserID.uuidString < request.toUserID.uuidString ? request.fromUserID : request.toUserID
            let high = low == request.fromUserID ? request.toUserID : request.fromUserID
            return FriendRelationshipRecord(
                id: request.id, userLowID: low, userHighID: high, requestedBy: request.fromUserID,
                status: request.status == .accepted ? .accepted : request.status == .declined ? .declined : .pending,
                createdAt: request.createdAt, respondedAt: request.respondedAt
            )
        }
    }
    func request(userID: UUID) async throws {
        guard let profile = repository.profiles.first(where: { $0.id == userID }) else { return }
        repository.sendFriendRequest(to: profile)
    }
    func respond(relationshipID: UUID, accept: Bool) async throws {
        guard let request = repository.friendRequests.first(where: { $0.id == relationshipID }) else { return }
        repository.respondToFriendRequest(request, status: accept ? .accepted : .declined)
    }
    func cancel(relationshipID: UUID) async throws {
        guard let request = repository.friendRequests.first(where: { $0.id == relationshipID }) else { return }
        repository.cancelFriendRequest(request)
    }
    func remove(relationshipID: UUID) async throws { try await cancel(relationshipID: relationshipID) }
}

@MainActor
final class MockExerciseCatalogService: ExerciseCatalogService {
    func activeExercises() async throws -> [CatalogExercise] {
        MockData.trainingExerciseLibrary.map {
            CatalogExercise(
                id: $0.id, displayName: $0.name, status: "active",
                rankingMovement: $0.rankingExerciseID, metadata: ["body_part": $0.bodyPart]
            )
        }
    }
    func resolve(identifier: String) async throws -> CatalogExercise? {
        try await activeExercises().first {
            $0.id == identifier || $0.displayName.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }
}

@MainActor
final class MockVerificationService: VerificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func pendingSubmissions() async throws -> [LiftSubmission] {
        repository.lifts.filter { $0.verificationStatus == .videoSubmitted || $0.verificationStatus == .selfReported }
    }
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission {
        guard let index = repository.lifts.firstIndex(where: { $0.id == lift.id }) else { return lift }
        repository.lifts[index].verificationStatus = status
        repository.lifts[index].updatedAt = .now
        repository.notifications.insert(NotificationItem(id: UUID(), title: status == .rejected ? "Lift rejected" : "Lift approved", message: note ?? "Verification updated.", kind: status.rawValue, createdAt: .now, isRead: false, destination: NotificationDestination(kind: .lift, targetID: lift.id)), at: 0)
        return repository.lifts[index]
    }
}

struct MockMediaUploadService: MediaUploadService {
    func upload(localURL: URL?) async throws -> URL? {
        try await Task.sleep(for: .milliseconds(450))
        return localURL ?? URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov")
    }
}

@MainActor
final class MockNotificationService: NotificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func notifications() async throws -> [NotificationItem] { repository.notifications }
}
