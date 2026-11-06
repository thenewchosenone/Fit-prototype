import Foundation

@MainActor
final class MockAuthenticationService: AuthenticationService {
    private let repository: DemoRepository
#if DEBUG
    private var didAttemptConfirmationResend = false
#endif
    var isConfigured: Bool { true }
    var isDemoMode: Bool { true }

    init(repository: DemoRepository) {
        self.repository = repository
    }

    func restoreSession() async throws -> AccountSession? {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingRestoredAuthenticatedAccount") {
            return AccountSession(
                userID: repository.currentProfile.id,
                email: "restored@example.test",
                expiresAt: .now.addingTimeInterval(3_600)
            )
        }
#endif
        return nil
    }
    func signInAnonymously() async throws -> AccountSession {
        AccountSession(userID: repository.currentProfile.id, email: nil, expiresAt: .now.addingTimeInterval(3_600), isGuest: true)
    }
    func addEmailToGuestAccount(email: String, password: String) async throws -> AccountSession {
        AccountSession(userID: repository.currentProfile.id, email: email, expiresAt: .now.addingTimeInterval(3_600))
    }
    func signUp(email: String, password: String) async throws -> AccountSession {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingEmailConfirmation") {
            return AccountSession(userID: repository.currentProfile.id, email: email, expiresAt: nil)
        }
#endif
        throw LiftRankServiceError.invalidCredentials
    }
    func resendConfirmation(email: String) async throws {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingEmailConfirmation") {
            if !didAttemptConfirmationResend {
                didAttemptConfirmationResend = true
                throw LiftRankServiceError.server("Confirmation could not be sent. Try again.")
            }
            return
        }
#endif
        throw LiftRankServiceError.configurationMissing
    }
    func signIn(email: String, password: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func requestPasswordReset(email: String) async throws {}
    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession { throw LiftRankServiceError.invalidCredentials }
    func signInDemo() async throws -> UserProfile {
        repository.currentProfile = MockData.demoProfile
        return repository.currentProfile
    }
    func signOut() async throws {}
}

@MainActor
final class MockProfileService: ProfileService {
    private let repository: DemoRepository
    private var savedPrivacy: ProfilePrivacySettings?
    private var shouldFailNextSettingsSave = ProcessInfo.processInfo.arguments.contains("-uiTestingSettingsSaveFailure")
    init(repository: DemoRepository) { self.repository = repository }
    func currentProfile() async throws -> UserProfile { repository.currentProfile }
    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry] { localEntries }
    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws {}
    func deleteBodyweightEntry(id: UUID) async throws {}
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        if shouldFailNextSettingsSave {
            shouldFailNextSettingsSave = false
            throw LiftRankServiceError.server("Simulated settings save failure.")
        }
        var saved = profile
        saved.username = repository.currentProfile.username
        repository.currentProfile = saved
        if let index = repository.profiles.firstIndex(where: { $0.id == saved.id }) {
            repository.profiles[index] = saved
        }
        return saved
    }
    func authenticatedProfile() async throws -> AuthenticatedProfile {
        let profile = repository.currentProfile
        return AuthenticatedProfile(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: profile.bio ?? "", avatarPath: profile.avatarPath, onboardingCompleted: true,
            preferredUnit: profile.preferredUnit, birthDate: nil, sexCategory: profile.sexCategory,
            heightCentimeters: profile.heightInches * 2.54,
            bodyweightPounds: profile.bodyweightPounds, city: profile.city,
            region: profile.state, countryCode: profile.countryCode, cityID: profile.cityID, yearsExperience: profile.yearsExperience,
            experienceLevel: profile.experienceLevel,
            privacy: savedPrivacy ?? ProfilePrivacySettings(
                profileAudience: profile.profileAudience,
                ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
                bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
                locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
                gymAudience: profile.hideGym ? .privateProfile : .publicProfile,
                showLiftVideos: !profile.hideLiftVideos
            ),
            trainingFocus: profile.trainingFocus
        )
    }
    func saveSettings(_ settings: ProfileSettingsSnapshot, expected: ProfileSettingsSnapshot) async throws -> AuthenticatedProfile {
        throw LiftRankServiceError.configurationMissing
    }

    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        var profile = repository.currentProfile
        profile.displayName = draft.displayName
        profile.bio = draft.bio
        profile.preferredUnit = draft.preferredUnit
        profile.trainingFocus = draft.trainingFocus ?? profile.trainingFocus
        profile.sexCategory = draft.sexCategory ?? .male
        profile.heightInches = (draft.heightCentimeters ?? profile.heightInches * 2.54) / 2.54
        profile.bodyweightPounds = draft.bodyweightPounds ?? profile.bodyweightPounds
        profile.city = draft.city
        profile.state = draft.region
        profile.cityID = draft.cityID
        profile.countryCode = draft.countryCode
        profile.yearsExperience = draft.yearsExperience ?? profile.yearsExperience
        profile.experienceLevel = draft.experienceLevel ?? profile.experienceLevel
        profile.profileAudience = draft.privacy.profileAudience
        profile.hideLiftVideos = !draft.privacy.showLiftVideos
        _ = try await updateProfile(profile)
        savedPrivacy = draft.privacy
        return try await authenticatedProfile()
    }
    func strengthGoalTargets() async throws -> [String: Double]? { nil }
    func saveStrengthGoalTargets(_ targets: [String: Double]) async throws {}
    func saveTrainingGoals(_ goalIDs: [String]) async throws {}
    func changeUsername(currentUsername: String, newUsername: String) async throws -> String {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingUsernameUnavailable") {
            throw LiftRankServiceError.usernameUnavailable
        }
#endif
        let normalized = newUsername.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            throw LiftRankServiceError.invalidInput("Use 3–24 lowercase letters, numbers, or underscores.")
        }
        guard repository.currentProfile.username.caseInsensitiveCompare(currentUsername) == .orderedSame else {
            throw LiftRankServiceError.sessionExpired
        }
        repository.currentProfile.username = normalized
        if let index = repository.profiles.firstIndex(where: { $0.id == repository.currentProfile.id }) {
            repository.profiles[index].username = normalized
        }
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
            primaryGymName: profile.hideGym ? nil : profile.primaryGymName,
            bodyweightPounds: profile.hideBodyweight ? nil : profile.bodyweightPounds,
            bodyweightLastUpdatedAt: profile.hideBodyweight ? nil : profile.bodyweightLastUpdatedAt
        )
    }
    func sharedWorkoutStats(userID: UUID) async throws -> SharedWorkoutStats? { nil }
    func recordFriendWorkoutStart(workoutID: UUID, ownerID: UUID) async throws {}
    func recordFriendTopLift(liftID: UUID) async throws {}
    func friendTrainingActivity() async throws -> [FriendTrainingActivity] {
        guard let friend = repository.profiles.first(where: { profile in
            profile.id != repository.currentProfile.id && repository.lifts.contains {
                $0.userID == profile.id && $0.visibility == .publicLift
            }
        }) else { return [] }
        var activities = [FriendTrainingActivity(
            id: friend.id, ownerID: friend.id, displayName: friend.displayName,
            kind: .workoutStarted, sourceID: friend.id, occurredAt: .now.addingTimeInterval(-3_600)
        )]
        if var lift = repository.lifts.first(where: { $0.userID == friend.id && $0.visibility == .publicLift }) {
            if lift.caption.hasPrefix("[demo:") { lift.caption = "" }
            activities.append(FriendTrainingActivity(
                id: lift.id, ownerID: friend.id, displayName: friend.displayName,
                kind: .topLift, sourceID: lift.id, occurredAt: lift.performedAt, lift: lift
            ))
        }
        return activities
    }
    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String { avatarPath }
    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? { nil }
    func removeProfileAvatar(avatarPath: String?) async throws {}
}

@MainActor
final class MockLiftService: LiftService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func submissions() async throws -> [LiftSubmission] { repository.lifts }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        repository.addLift(submission, refreshAchievements: false)
        return submission
    }
    func removeSubmission(id: UUID) async throws {
        guard let lift = repository.lifts.first(where: { $0.id == id }),
              lift.userID == repository.currentProfile.id else {
            throw LiftRankServiceError.invalidInput("Submission not found or no longer available.")
        }
        repository.lifts.removeAll { $0.id == id }
    }
    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {}
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {}
}

@MainActor
final class MockLeaderboardService: LeaderboardService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        var filtered = repository.lifts
        if let exerciseID = filters.exerciseID {
            filtered = filtered.filter { RankingCalculator.matchesExerciseID($0, exerciseID: exerciseID) }
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
final class MockSocialService: SocialService {
    private let repository: DemoRepository
    private var blockRecords: [UserBlockRecord] = []
    var shouldFailBlocksFetch = false
    init(repository: DemoRepository) { self.repository = repository }
    func friendRequests() async throws -> [FriendRequest] { [] }
    func requestFriendship(userID: UUID) async throws {
        throw LiftRankServiceError.invalidInput("Friend requests require a signed-in account.")
    }
    func respondToFriendship(id: UUID, accept: Bool) async throws {
        throw LiftRankServiceError.invalidInput("Friend requests require a signed-in account.")
    }
    func searchProfiles(query: String, limit: Int) async throws -> [PublicProfileCard] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return repository.profiles.filter {
            clean.isEmpty || $0.username.lowercased().contains(clean) || $0.displayName.lowercased().contains(clean)
        }.prefix(max(1, min(limit, 50))).map {
            PublicProfileCard(
                id: $0.id, username: $0.username, displayName: $0.displayName,
                bio: "", avatarPath: $0.avatarPath, ageBand: $0.hideExactAge ? nil : $0.ageGroup,
                sexCategory: $0.sexCategory, city: $0.hideCity ? nil : $0.city,
                region: $0.hideCity ? nil : $0.state, countryCode: nil,
                primaryGymID: $0.hideGym ? nil : $0.primaryGymID,
                primaryGymName: $0.hideGym ? nil : $0.primaryGymName,
                bodyweightPounds: $0.hideBodyweight ? nil : $0.bodyweightPounds,
                bodyweightLastUpdatedAt: $0.hideBodyweight ? nil : $0.bodyweightLastUpdatedAt
            )
        }
    }
    func report(userID: UUID, reason: ProfileReportReason, note: String) async throws {
        guard userID != repository.currentProfile.id else { throw LiftRankServiceError.permissionDenied }
    }
    func block(userID: UUID) async throws {
        guard userID != repository.currentProfile.id,
              !blockRecords.contains(where: { $0.blockedID == userID }) else { return }
        blockRecords.append(UserBlockRecord(
            blockerID: repository.currentProfile.id,
            blockedID: userID,
            createdAt: .now
        ))
    }
    func unblock(userID: UUID) async throws {
        blockRecords.removeAll { $0.blockedID == userID }
    }
    func blocks() async throws -> [UserBlockRecord] {
        if shouldFailBlocksFetch {
            throw LiftRankServiceError.server("Blocks unavailable")
        }
        return blockRecords
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
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission {
        guard let lift = repository.lifts.first(where: { $0.id == liftID }) else { throw LiftRankServiceError.invalidInput("Lift not found.") }
        let status: VerificationStatus = decision == .reject ? .rejected : .videoVerified
        var updated = try await updateVerification(for: lift, status: status, note: note)
        updated.moderationStatus = decision == .requestReplacement ? .replacementRequested : decision == .reject ? .rejected : .clear
        if let index = repository.lifts.firstIndex(where: { $0.id == liftID }) { repository.lifts[index] = updated }
        return updated
    }
}

struct MockMediaUploadService: MediaUploadService {
    func upload(localURL: URL?) async throws -> URL? {
        try await Task.sleep(for: .milliseconds(450))
        return localURL ?? URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov")
    }
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset {
        progress(1)
        return LiftMediaAsset(id: UUID(), ownerID: MockData.demoUserID, storagePath: localURL.path, contentType: "video/quicktime", byteCount: 0, createdAt: .now)
    }
    func signedPlaybackURL(assetID: UUID) async throws -> URL { URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov") }
}

@MainActor
final class MockNotificationService: NotificationService {
    private let repository: DemoRepository
    init(repository: DemoRepository) { self.repository = repository }
    func notifications() async throws -> [NotificationItem] { repository.notifications }
    func markRead(notificationID: UUID) async throws {
        if let index = repository.notifications.firstIndex(where: { $0.id == notificationID }) { repository.notifications[index].isRead = true }
    }
    func registerDevice(_ registration: PushDeviceRegistration) async throws {}
    func revokeDevice(deviceID: String) async throws {}
}

@MainActor
final class MockForumService: ForumService {
    private let repository: DemoRepository
    private let hasEditableTestFixture: Bool
    private var editedPost: ForumPost?
    private var editedComments: [ForumComment]?
    private var isTestPostDeleted = false
    private var localPosts: [ForumPost] = []
    private var localComments: [UUID: [ForumComment]] = [:]
    private var localMedia: [String: URL] = [:]
    private var joinedIDs: Set<UUID> = []
    private var postVotes: [UUID: Int] = [:]
    private var watchedPostIDs: Set<UUID> = []

    init(repository: DemoRepository) {
        self.repository = repository
        hasEditableTestFixture = ProcessInfo.processInfo.arguments.contains("-uiTestingEditableForumThread")
        let communityID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        localPosts = [
            ForumPost(id: UUID(uuidString: "00000000-0000-0000-0000-000000000271")!, communityID: communityID, gymID: nil, authorID: MockData.demoProfile.id,
                      kind: "Discussion", title: "Photo test · Lift Rivals", body: "A demo image for checking photo previews and full-screen viewing.", tag: "Test post", liftID: nil, isPinned: false, isLocked: false, createdAt: Date().addingTimeInterval(-60),
                      attachments: [ForumAttachment(kind: .photo, storagePath: "demo/forum-demo-photo.png")]),
            ForumPost(id: UUID(uuidString: "00000000-0000-0000-0000-000000000272")!, communityID: communityID, gymID: nil, authorID: MockData.demoProfile.id,
                      kind: "Discussion", title: "Video test · App recording", body: "A demo app recording for checking video playback. This is not a verified lift.", tag: "Test post", liftID: nil, isPinned: false, isLocked: false, createdAt: Date().addingTimeInterval(-120),
                      attachments: [ForumAttachment(kind: .video, storagePath: "demo/forum-demo-video.mp4")])
        ]
    }

    private var testPostID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000211")! }
    private var testCommentID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000212")! }
    private var testCommunityID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000201")! }

    private let demoCommunities = [
        ForumCommunity(id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!, slug: "strength", name: "Strength Training", summary: "Build strength together.", details: "Discuss programming, technique, and progress.", category: "Training", visibility: "public", accentHex: "8B5CF6"),
        ForumCommunity(id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!, slug: "powerlifting", name: "Powerlifting", summary: "Train the competition lifts.", details: "Share meet prep and powerlifting advice.", category: "Training", visibility: "public", accentHex: "F59E0B"),
        ForumCommunity(id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!, slug: "nutrition", name: "Nutrition", summary: "Fuel your training.", details: "Talk meals, recovery, and sustainable habits.", category: "Lifestyle", visibility: "public", accentHex: "22C55E")
    ]

    func communities() async throws -> [ForumCommunity] { demoCommunities }
    func joinedCommunityIDs() async throws -> [UUID] { Array(joinedIDs.union(hasEditableTestFixture ? [testCommunityID] : [])) }
    func communityMembershipStatuses() async throws -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: try await joinedCommunityIDs().map { ($0, "Joined") })
    }
    func posts(communityID: UUID?, limit: Int, offset: Int) async throws -> [ForumPost] {
        var posts = localPosts.map(presentedPost)
        if hasEditableTestFixture, !isTestPostDeleted { posts.insert(currentTestPost, at: 0) }
        return Array(posts.filter { communityID == nil || $0.communityID == communityID }
            .dropFirst(max(offset, 0)).prefix(max(limit, 0)))
    }
    func thread(postID: UUID) async throws -> ForumThread? {
        if let post = localPosts.first(where: { $0.id == postID }) {
            return ForumThread(post: presentedPost(post), comments: localComments[postID] ?? [], isWatching: watchedPostIDs.contains(postID))
        }
        guard hasEditableTestFixture, !isTestPostDeleted, postID == testPostID else { return nil }
        return ForumThread(post: currentTestPost, comments: currentTestComments)
    }
    func join(communityID: UUID, requestNote: String) async throws -> String {
        joinedIDs.insert(communityID)
        return "Joined"
    }
    func leave(communityID: UUID) async throws {
        joinedIDs.remove(communityID)
    }
    func createPost(_ draft: ForumPostDraft) async throws -> ForumPost {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingForumPublishFailure") {
            throw LiftRankServiceError.invalidInput("Posting is unavailable in the simulator demo.")
        }
        if let existing = localPosts.first(where: { $0.id == draft.id }) { return presentedPost(existing) }
        var attachments: [ForumAttachment] = []
        if let media = draft.media {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("forum-post-\(UUID().uuidString)")
                .appendingPathExtension(media.kind == .photo ? "jpg" : "mp4")
            try FileManager.default.copyItem(at: media.fileURL, to: url)
            localMedia[url.path] = url
            attachments = [ForumAttachment(kind: media.kind, storagePath: url.path)]
        }
        let post = ForumPost(id: draft.id, communityID: draft.communityID, gymID: nil, authorID: repository.currentProfile.id, kind: draft.kind, title: draft.title, body: draft.body, tag: draft.tag, liftID: draft.liftID, isPinned: false, isLocked: false, createdAt: .now, attachments: attachments)
        localPosts.insert(post, at: 0)
        return post
    }
    func mediaURL(for attachment: ForumAttachment) async throws -> URL {
        if let url = localMedia[attachment.storagePath] { return url }
        if attachment.storagePath == "demo/forum-demo-photo.png",
           let url = Bundle.main.url(forResource: "forum-demo-photo", withExtension: "png") { return url }
        if attachment.storagePath == "demo/forum-demo-video.mp4",
           let url = Bundle.main.url(forResource: "forum-demo-video", withExtension: "mp4") { return url }
        throw LiftRankServiceError.invalidInput("This demo attachment is unavailable.")
    }
    func createComment(postID: UUID, body: String, parentCommentID: UUID?) async throws -> ForumComment {
        if localPosts.contains(where: { $0.id == postID }) {
            let comment = ForumComment(id: UUID(), postID: postID, authorID: repository.currentProfile.id, parentCommentID: parentCommentID, body: body, createdAt: .now)
            localComments[postID, default: []].append(comment)
            return comment
        }
        throw LiftRankServiceError.invalidInput("Commenting is unavailable in the simulator demo.")
    }
    func updatePost(postID: UUID, title: String, body: String) async throws -> ForumPost {
        if let index = localPosts.firstIndex(where: { $0.id == postID && $0.authorID == repository.currentProfile.id }) {
            let post = localPosts[index]
            let updated = ForumPost(id: post.id, communityID: post.communityID, gymID: post.gymID, authorID: post.authorID, kind: post.kind, title: title, body: body, tag: post.tag, liftID: post.liftID, isPinned: post.isPinned, isLocked: post.isLocked, createdAt: post.createdAt, attachments: post.attachments)
            localPosts[index] = updated
            return presentedPost(updated)
        }
        if hasEditableTestFixture, postID == testPostID, currentTestPost.authorID == repository.currentProfile.id {
            let post = currentTestPost
            let updated = ForumPost(id: post.id, communityID: post.communityID, gymID: post.gymID, authorID: post.authorID, kind: post.kind, title: title, body: body, tag: post.tag, liftID: post.liftID, isPinned: post.isPinned, isLocked: post.isLocked, createdAt: post.createdAt, voteCount: post.voteCount, commentCount: post.commentCount, currentUserVote: post.currentUserVote)
            editedPost = updated
            return updated
        }
        throw LiftRankServiceError.invalidInput("Editing posts is unavailable in the simulator demo.")
    }
    func updateComment(commentID: UUID, body: String) async throws -> ForumComment {
        if let postID = localComments.first(where: { $0.value.contains(where: { $0.id == commentID }) })?.key,
           let index = localComments[postID]?.firstIndex(where: { $0.id == commentID && $0.authorID == repository.currentProfile.id }),
           let comment = localComments[postID]?[index] {
            let updated = ForumComment(id: comment.id, postID: postID, authorID: comment.authorID, parentCommentID: comment.parentCommentID, body: body, createdAt: comment.createdAt)
            localComments[postID]?[index] = updated
            return updated
        }
        if hasEditableTestFixture, let index = currentTestComments.firstIndex(where: { $0.id == commentID && $0.authorID == repository.currentProfile.id }) {
            let comment = currentTestComments[index]
            let updated = ForumComment(id: comment.id, postID: comment.postID, authorID: comment.authorID, parentCommentID: comment.parentCommentID, body: body, createdAt: comment.createdAt, voteCount: comment.voteCount, currentUserVote: comment.currentUserVote)
            var comments = currentTestComments
            comments[index] = updated
            editedComments = comments
            return updated
        }
        throw LiftRankServiceError.invalidInput("Editing comments is unavailable in the simulator demo.")
    }
    func deletePost(postID: UUID) async throws {
        if let post = localPosts.first(where: { $0.id == postID && $0.authorID == repository.currentProfile.id }) {
            for attachment in post.attachments {
                if let url = localMedia[attachment.storagePath] {
                    try FileManager.default.removeItem(at: url)
                    localMedia[attachment.storagePath] = nil
                }
            }
            localPosts.removeAll { $0.id == postID }
            localComments[postID] = nil
            postVotes[postID] = nil
            return
        }
        if hasEditableTestFixture, postID == testPostID, currentTestPost.authorID == repository.currentProfile.id {
            isTestPostDeleted = true
            return
        }
        throw LiftRankServiceError.invalidInput("Deleting posts is unavailable in the simulator demo.")
    }
    func deleteComment(commentID: UUID) async throws {
        if let postID = localComments.first(where: { $0.value.contains(where: { $0.id == commentID && $0.authorID == repository.currentProfile.id }) })?.key {
            localComments[postID]?.removeAll { $0.id == commentID }
            return
        }
        if hasEditableTestFixture, currentTestComments.contains(where: { $0.id == commentID && $0.authorID == repository.currentProfile.id }) {
            editedComments = currentTestComments.filter { $0.id != commentID }
            return
        }
        throw LiftRankServiceError.invalidInput("Deleting comments is unavailable in the simulator demo.")
    }
    func vote(postID: UUID, value: Int?) async throws {
        if localPosts.contains(where: { $0.id == postID }) {
            postVotes[postID] = value
            return
        }
        throw LiftRankServiceError.invalidInput("Voting is unavailable in the simulator demo.")
    }
    func vote(commentID: UUID, value: Int?) async throws {
        throw LiftRankServiceError.invalidInput("Voting is unavailable in the simulator demo.")
    }
    func watch(postID: UUID, watched: Bool) async throws {
        if localPosts.contains(where: { $0.id == postID }) {
            if watched { watchedPostIDs.insert(postID) } else { watchedPostIDs.remove(postID) }
            return
        }
        throw LiftRankServiceError.invalidInput("Watching discussions is unavailable in the simulator demo.")
    }
    func report(targetType: String, targetID: UUID, communityID: UUID?, reason: String, note: String) async throws {
        throw LiftRankServiceError.invalidInput("Reporting is unavailable in the simulator demo.")
    }
    func reports() async throws -> [ForumReport] { [] }
    func moderate(postID: UUID, action: String, reason: String) async throws {
        throw LiftRankServiceError.invalidInput("Moderation is unavailable in the simulator demo.")
    }

    private func presentedPost(_ post: ForumPost) -> ForumPost {
        ForumPost(id: post.id, communityID: post.communityID, gymID: post.gymID, authorID: post.authorID, kind: post.kind, title: post.title, body: post.body, tag: post.tag, liftID: post.liftID, isPinned: post.isPinned, isLocked: post.isLocked, createdAt: post.createdAt, voteCount: postVotes[post.id] ?? 0, commentCount: localComments[post.id]?.count ?? 0, currentUserVote: postVotes[post.id], attachments: post.attachments)
    }

    private var currentTestPost: ForumPost {
        editedPost ?? ForumPost(
            id: testPostID,
            communityID: testCommunityID,
            gymID: nil,
            authorID: repository.currentProfile.id,
            kind: "Discussion",
            title: "Editable UI test discussion",
            body: "Use this fixture to verify author edit and delete controls.",
            tag: nil,
            liftID: nil,
            isPinned: true,
            isLocked: false,
            createdAt: .now,
            voteCount: 100,
            commentCount: currentTestComments.count
        )
    }

    private var currentTestComments: [ForumComment] {
        editedComments ?? [ForumComment(
            id: testCommentID,
            postID: testPostID,
            authorID: repository.currentProfile.id,
            parentCommentID: nil,
            body: "Editable UI test comment",
            createdAt: .now
        )]
    }
}

@MainActor
final class MockWorkoutSyncService: WorkoutSyncService {
    private var planDocuments: [WorkoutPlanDocument] = []
    private var snapshots: [CompletedWorkoutSnapshot] = []
    var failNextPlanDeletion = false
    func plans() async throws -> [WorkoutPlanDocument] { planDocuments }
    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        guard !document.isSeededDemoData else { throw LiftRankServiceError.invalidInput("Demo data cannot be synced.") }
        if let current = planDocuments.first(where: { $0.id == document.id }), current.revision != expectedRevision {
            let payload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: document.payload)
            let serverPayload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: current.payload)
            if payload.canonicalized == serverPayload.canonicalized { return .saved(current) }
            let conflict = try document.conflictCopy(expectedRevision: expectedRevision)
            if let existing = planDocuments.first(where: { $0.id == conflict.id }) {
                return .conflict(server: current, localCopy: existing)
            }
            planDocuments.append(conflict)
            return .conflict(server: current, localCopy: conflict)
        }
        var saved = document; saved.revision = expectedRevision + 1
        planDocuments.removeAll { $0.id == saved.id }; planDocuments.append(saved)
        return .saved(saved)
    }
    func deletePlan(id: UUID) async throws {
        if failNextPlanDeletion {
            failNextPlanDeletion = false
            throw LiftRankServiceError.invalidInput("Simulated plan deletion failure")
        }
        planDocuments.removeAll { $0.id == id }
    }
    func deleteDuplicatePlan(_ document: WorkoutPlanDocument) async throws -> Bool {
        guard let current = planDocuments.first(where: { $0.id == document.id }),
              current.ownerID == document.ownerID, current.revision == document.revision else { return false }
        let payload = try JSONDecoder().decode(WorkoutPlanSyncPayload.self, from: current.payload)
        guard !payload.plan.isActive, payload.plan.name.hasSuffix(" (Conflict copy)") else {
            throw LiftRankServiceError.invalidInput("Only an inactive conflict copy can be cleaned up.")
        }
        try await deletePlan(id: document.id)
        return true
    }
    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] { snapshots.filter { since == nil || $0.completedAt > since! } }
    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        guard !snapshot.isSeededDemoData else { return }
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)
    }
    func deleteCompletedWorkout(id: UUID) async throws {
        snapshots.removeAll { $0.id == id }
    }
}

struct MockAnalyticsService: AnalyticsService { func track(_ event: AnalyticsEventRecord) async {} }
struct MockLegalAcceptanceService: LegalAcceptanceService {
    func acceptances() async throws -> [LegalAcceptanceRecord] {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingRestoredAuthenticatedAccount") {
            return LegalDocument.current.map {
                LegalAcceptanceRecord(
                    id: UUID(),
                    userID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                    documentKind: $0.kind.rawValue,
                    documentVersion: $0.version,
                    acceptedAt: .now
                )
            }
        }
#endif
        return []
    }
    func accept(documents: [LegalDocument]) async throws {}
}
struct MockAccountDeletionService: AccountDeletionService { func deleteAccount() async throws {} }
