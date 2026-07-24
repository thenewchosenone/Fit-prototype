import Foundation

struct DirectMessageThread: Identifiable, Codable, Hashable {
    let id: UUID
    var participantIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
}

struct DirectMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var threadID: UUID
    var senderID: UUID
    var body: String
    var createdAt: Date
    var isRead: Bool
    var isReported: Bool
}

enum MessageReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "Spam"
    case offensive = "Offensive"
    case harassment = "Harassment"
    case other = "Other"

    var id: String { rawValue }
}

struct MessageReport: Identifiable, Codable, Hashable {
    let id: UUID
    var messageID: UUID
    var reporterID: UUID
    var reason: MessageReportReason
    var note: String
    var createdAt: Date
}

enum CommunityThreadKind: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case challenge = "Challenge"
    case gym = "Gym"
    var id: String { rawValue }
}

enum CommunityVote: Int, Codable, CaseIterable, Identifiable {
    case down = -1
    case up = 1

    var id: Int { rawValue }
}

enum CommunityReportTargetType: String, Codable, CaseIterable, Identifiable {
    case thread = "Thread"
    case reply = "Reply"

    var id: String { rawValue }
}

enum CommunityReportReason: String, Codable, CaseIterable, Identifiable {
    case dangerousAdvice = "Dangerous advice"
    case harassment = "Harassment"
    case misinformation = "Misinformation"
    case spam = "Spam"
    case unsafeSupplements = "Unsafe supplements"
    case other = "Other"

    var id: String { rawValue }
}

struct CommunityThread: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var authorID: UUID
    var authorName: String
    var kind: CommunityThreadKind
    var challengeID: UUID?
    var gymID: UUID?
    var replyCount: Int
    var likeCount: Int
    var createdAt: Date
    var votes: [UUID: CommunityVote] = [:]
    var isLocked: Bool = false
    var removedAt: Date?
    var removalReason: String?
    var warning: String?

    var voteScore: Int {
        votes.values.reduce(0) { $0 + $1.rawValue }
    }
}

struct CommunityThreadReply: Identifiable, Codable, Hashable {
    var id: UUID
    var threadID: UUID
    var authorID: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var votes: [UUID: CommunityVote] = [:]
    var removedAt: Date?

    var voteScore: Int {
        votes.values.reduce(0) { $0 + $1.rawValue }
    }
}

struct CommunityReport: Identifiable, Codable, Hashable {
    var id: UUID
    var targetType: CommunityReportTargetType
    var targetID: UUID
    var reporterID: UUID
    var reason: CommunityReportReason
    var note: String
    var status: String
    let createdAt: Date
}

enum ForumCommunityVisibility: String, Codable, CaseIterable, Identifiable {
    case publicOpen = "Public"
    case restricted = "Restricted"
    case inviteOnly = "Invite Only"

    var id: String { rawValue }
}

enum ForumMemberRole: String, Codable, CaseIterable, Identifiable {
    case member = "Member"
    case moderator = "Moderator"
    case admin = "Admin"
    case staff = "Staff"

    var id: String { rawValue }

    var authority: Int {
        switch self {
        case .member: return 0
        case .moderator: return 1
        case .admin: return 2
        case .staff: return 3
        }
    }
}

enum ForumMembershipStatus: String, Codable, CaseIterable, Identifiable {
    case joined = "Joined"
    case pending = "Pending"
    case invited = "Invited"
    case muted = "Muted"
    case banned = "Banned"
    case declined = "Declined"
    case left = "Left"

    var id: String { rawValue }
}

enum ForumNotificationLevel: String, Codable, CaseIterable, Identifiable {
    case all = "All activity"
    case mentions = "Mentions and replies"
    case off = "Muted"

    var id: String { rawValue }
}

enum ForumPostKind: String, Codable, CaseIterable, Identifiable {
    case discussion = "Discussion"
    case media = "Media"
    case poll = "Poll"
    case liftShare = "Lift"
    case workoutShare = "Workout"
    case link = "Link"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .discussion: return "text.bubble.fill"
        case .media: return "photo.on.rectangle.angled"
        case .poll: return "chart.bar.fill"
        case .liftShare: return "trophy.fill"
        case .workoutShare: return "dumbbell.fill"
        case .link: return "link"
        }
    }
}

enum ForumMediaType: String, Codable, CaseIterable, Identifiable {
    case image
    case video
    var id: String { rawValue }
}

enum ForumDestination: Codable, Hashable {
    case community(UUID)
    case gym(UUID)

    var communityID: UUID? {
        guard case .community(let id) = self else { return nil }
        return id
    }

    var gymID: UUID? {
        guard case .gym(let id) = self else { return nil }
        return id
    }
}

struct ForumCommunity: Identifiable, Codable, Hashable {
    var id: UUID
    var slug: String
    var name: String
    var summary: String
    var details: String
    var category: String
    var symbolName: String
    var accentHex: String
    var visibility: ForumCommunityVisibility
    var rules: [String]
    var availableTags: [String]
    var staffOwnerID: UUID
    var memberCount: Int
    var postCount: Int
    var createdAt: Date
    var archivedAt: Date?
}

struct ForumMembership: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID
    var userID: UUID
    var role: ForumMemberRole
    var status: ForumMembershipStatus
    var notificationLevel: ForumNotificationLevel
    var joinedAt: Date?
    var mutedUntil: Date?
    var bannedAt: Date?
    var restrictionReason: String?
    var invitedBy: UUID?

    var isActive: Bool {
        status == .joined || status == .muted
    }

    var canContribute: Bool {
        if status == .joined { return true }
        if status == .muted, let mutedUntil { return mutedUntil <= .now }
        return false
    }
}

struct ForumAttachment: Identifiable, Codable, Hashable {
    var id: UUID
    var mediaType: ForumMediaType
    var localURL: URL
    var createdAt: Date
}

struct ForumPollOption: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var voterIDs: Set<UUID>
}

struct ForumPoll: Identifiable, Codable, Hashable {
    var id: UUID
    var options: [ForumPollOption]
    var closesAt: Date?

    var isClosed: Bool { closesAt.map { $0 <= .now } ?? false }
    var totalVotes: Int { options.reduce(0) { $0 + $1.voterIDs.count } }
}

struct ForumPost: Identifiable, Codable, Hashable {
    var id: UUID
    var destination: ForumDestination
    var authorID: UUID
    var authorName: String
    var kind: ForumPostKind
    var title: String
    var body: String
    var tag: String?
    var attachments: [ForumAttachment]
    var poll: ForumPoll?
    var liftID: UUID?
    var workoutID: UUID?
    var linkURL: URL?
    var challengeID: UUID?
    var createdAt: Date
    var editedAt: Date?
    var commentCount: Int
    var votes: [UUID: CommunityVote]
    var savedByUserIDs: Set<UUID>
    var watchedByUserIDs: Set<UUID>
    var isPinned: Bool
    var isLocked: Bool
    var removedAt: Date?
    var removalReason: String?

    var voteScore: Int { votes.values.reduce(0) { $0 + $1.rawValue } }
}

struct ForumComment: Identifiable, Codable, Hashable {
    var id: UUID
    var postID: UUID
    var parentCommentID: UUID?
    var authorID: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var editedAt: Date?
    var votes: [UUID: CommunityVote]
    var removedAt: Date?
    var removalReason: String?

    var voteScore: Int { votes.values.reduce(0) { $0 + $1.rawValue } }
}

struct ForumVoteRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var targetType: ForumReportTargetType
    var targetID: UUID
    var userID: UUID
    var vote: CommunityVote
    var updatedAt: Date
}

struct ForumJoinRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID
    var userID: UUID
    var note: String
    var status: String
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedBy: UUID?
}

enum ForumReportTargetType: String, Codable, CaseIterable, Identifiable {
    case post = "Post"
    case comment = "Comment"
    case community = "Community"
    case member = "Member"
    var id: String { rawValue }
}

enum ForumReportStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case resolved = "Resolved"
    case dismissed = "Dismissed"
    var id: String { rawValue }
}

struct ForumReport: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID?
    var targetType: ForumReportTargetType
    var targetID: UUID
    var reporterID: UUID
    var reason: CommunityReportReason
    var note: String
    var status: ForumReportStatus
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedBy: UUID?
}

enum ForumModerationActionKind: String, Codable, CaseIterable, Identifiable {
    case pin = "Pinned"
    case unpin = "Unpinned"
    case lock = "Locked"
    case unlock = "Unlocked"
    case remove = "Removed"
    case restore = "Restored"
    case warn = "Warned"
    case mute = "Muted"
    case ban = "Banned"
    case approve = "Approved"
    case decline = "Declined"
    case archive = "Archived"
    var id: String { rawValue }
}

struct ForumModerationAction: Identifiable, Codable, Hashable {
    var id: UUID
    var communityID: UUID?
    var moderatorID: UUID
    var kind: ForumModerationActionKind
    var targetID: UUID
    var reason: String
    var createdAt: Date
}

enum ForumNotificationKind: String, Codable, CaseIterable, Identifiable {
    case reply = "Reply"
    case mention = "Mention"
    case watchedPost = "Watched Post"
    case moderation = "Moderation"
    case membership = "Membership"
    var id: String { rawValue }
}

struct ForumNotification: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var actorID: UUID?
    var kind: ForumNotificationKind
    var title: String
    var message: String
    var communityID: UUID?
    var postID: UUID?
    var commentID: UUID?
    var createdAt: Date
    var isRead: Bool
}

enum ForumFeedSort: String, Codable, CaseIterable, Identifiable {
    case hot = "Hot"
    case new = "New"
    case top = "Top"
    var id: String { rawValue }
}

enum ForumTopRange: String, Codable, CaseIterable, Identifiable {
    case day = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All time"
    var id: String { rawValue }
}

enum ForumCommentSort: String, Codable, CaseIterable, Identifiable {
    case best = "Best"
    case new = "New"
    case old = "Old"
    var id: String { rawValue }
}

enum ForumRoute: Hashable {
    case community(UUID)
    case post(UUID)
    case gym(UUID)
    case gyms
    case saved
    case watched
    case moderation
}

struct ForumPersistenceSnapshot: Codable, Hashable {
    static let currentVersion = 1

    var schemaVersion: Int
    var communities: [ForumCommunity]
    var memberships: [ForumMembership]
    var posts: [ForumPost]
    var comments: [ForumComment]
    var joinRequests: [ForumJoinRequest]
    var reports: [ForumReport]
    var moderationActions: [ForumModerationAction]
    var notifications: [ForumNotification]
    var globalStaffUserIDs: Set<UUID>
}

struct Follow: Identifiable, Codable, Hashable {
    let id: UUID
    let followerID: UUID
    let followedID: UUID
}

enum FriendRequestStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"

    var id: String { rawValue }
}

struct FriendRequest: Identifiable, Codable, Hashable {
    let id: UUID
    var fromUserID: UUID
    var toUserID: UUID
    var status: FriendRequestStatus
    var createdAt: Date
    var respondedAt: Date?
}

struct Comment: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let liftID: UUID
    var text: String
    let createdAt: Date
}

struct Reaction: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let targetID: UUID
    var kind: String
}

struct Challenge: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var startDate: Date
    var endDate: Date
    var goal: String
    var eligibility: String
    var participantCount: Int
    var progress: Double
    var isJoined: Bool
}

struct ChallengeParticipant: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let challengeID: UUID
    var progress: Double
}

struct UserAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let achievementID: UUID
    var unlockedAt: Date?
}

struct Report: Identifiable, Codable, Hashable {
    let id: UUID
    let liftID: UUID
    let reason: String
    let createdAt: Date
}

struct GymRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var city: String
    var state: String
    var requestedBy: UUID
    var note: String
    var createdAt: Date
}
