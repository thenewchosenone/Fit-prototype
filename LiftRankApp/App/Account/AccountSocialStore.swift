import Combine
import Foundation

@MainActor
final class AccountSocialStore: ObservableObject {
    @Published private(set) var gymMemberships: [GymMembershipRecord] = []
    @Published private(set) var friendRelationships: [FriendRelationshipRecord] = []
    @Published private(set) var blocks: [UserBlockRecord] = []

    private let repository: any AccountSocialRepository
    private let profileStore: ProfileStore
    private var gymService: any GymService
    private var gymMembershipService: any GymMembershipService
    private var friendRelationshipService: any FriendRelationshipService
    private var profileService: any ProfileService
    private var socialService: any SocialService

    init(
        repository: any AccountSocialRepository,
        profileStore: ProfileStore,
        gymService: any GymService,
        gymMembershipService: any GymMembershipService,
        friendRelationshipService: any FriendRelationshipService,
        profileService: any ProfileService,
        socialService: any SocialService
    ) {
        self.repository = repository
        self.profileStore = profileStore
        self.gymService = gymService
        self.gymMembershipService = gymMembershipService
        self.friendRelationshipService = friendRelationshipService
        self.profileService = profileService
        self.socialService = socialService
    }

    func updateServices(
        gymService: any GymService,
        gymMembershipService: any GymMembershipService,
        friendRelationshipService: any FriendRelationshipService,
        profileService: any ProfileService,
        socialService: any SocialService
    ) {
        self.gymService = gymService
        self.gymMembershipService = gymMembershipService
        self.friendRelationshipService = friendRelationshipService
        self.profileService = profileService
        self.socialService = socialService
    }

    func refreshDirectoryAndRelationships() async throws {
        async let gyms = gymService.gyms()
        async let memberships = gymService.memberships()
        async let relationships = friendRelationshipService.relationships()
        let (directory, joined, friends) = try await (gyms, memberships, relationships)

        profileStore.replaceGymDirectory(directory, memberships: joined)
        gymMemberships = joined
        friendRelationships = friends
        repository.friendRequests = friends.compactMap(Self.friendRequest)

        let relatedUserIDs = Set(friends.flatMap { [$0.userLowID, $0.userHighID] })
            .subtracting([repository.currentProfile.id])
        for userID in relatedUserIDs {
            guard let card = try? await profileService.profileCard(userID: userID) else { continue }
            profileStore.mergePublicProfileCard(card)
        }
    }

    func refreshBlocks() async {
        blocks = (try? await socialService.blocks()) ?? []
    }

    func requestFriend(userID: UUID) async throws {
        try await friendRelationshipService.request(userID: userID)
        try await refreshDirectoryAndRelationships()
    }

    func cancelFriendRequest(relationshipID: UUID) async throws {
        try await friendRelationshipService.cancel(relationshipID: relationshipID)
        try await refreshDirectoryAndRelationships()
    }

    func respondToFriendRequest(relationshipID: UUID, accept: Bool) async throws {
        try await friendRelationshipService.respond(relationshipID: relationshipID, accept: accept)
        try await refreshDirectoryAndRelationships()
    }

    func ensureGymJoined(
        _ gym: Gym,
        maximumMemberships: Int,
        authenticated: Bool
    ) async throws -> Bool {
        if profileStore.isGymJoined(gym.id) { return true }
        if authenticated {
            guard try await gymMembershipService.join(
                gym,
                maximumMemberships: maximumMemberships
            ) else { return false }
            try await refreshDirectoryAndRelationships()
            return profileStore.isGymJoined(gym.id)
        }
        return profileStore.joinGym(gym, maximumMemberships: maximumMemberships)
    }

    func leaveGym(_ gym: Gym, authenticated: Bool) async throws {
        if authenticated {
            try await gymMembershipService.leave(gym)
            try await refreshDirectoryAndRelationships()
        } else {
            profileStore.leaveGym(gym)
        }
    }

    func setPrimaryGym(_ gym: Gym, authenticated: Bool) async throws {
        if authenticated {
            try await gymMembershipService.setPrimary(gym)
            try await refreshDirectoryAndRelationships()
        } else {
            profileStore.setPrimaryGym(gym)
        }
    }

    func isBlocked(_ userID: UUID) -> Bool {
        blocks.contains { $0.blockedID == userID }
    }

    func setBlocked(_ userID: UUID, blocked: Bool) async throws {
        guard userID != repository.currentProfile.id else { return }
        if blocked {
            try await socialService.block(userID: userID)
        } else {
            try await socialService.unblock(userID: userID)
        }
        blocks = (try? await socialService.blocks()) ?? []
        guard blocked else { return }

        repository.activities.removeAll { $0.profile.id == userID }
        repository.forumPosts.removeAll { $0.authorID == userID }
        repository.forumComments.removeAll { $0.authorID == userID }
        repository.messageThreads.removeAll { $0.participantIDs.contains(userID) }
    }

    func clear() {
        gymMemberships = []
        friendRelationships = []
        blocks = []
    }

    private static func friendRequest(_ relationship: FriendRelationshipRecord) -> FriendRequest? {
        guard relationship.status != .cancelled else { return nil }
        return FriendRequest(
            id: relationship.id,
            fromUserID: relationship.requestedBy,
            toUserID: relationship.requestedBy == relationship.userLowID
                ? relationship.userHighID
                : relationship.userLowID,
            status: relationship.status == .accepted
                ? .accepted
                : relationship.status == .declined ? .declined : .pending,
            createdAt: relationship.createdAt,
            respondedAt: relationship.respondedAt
        )
    }
}
