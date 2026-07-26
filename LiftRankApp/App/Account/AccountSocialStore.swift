import Combine
import Foundation

@MainActor
final class AccountSocialStore: ObservableObject {
    @Published private(set) var gymMemberships: [GymMembershipRecord] = []
    @Published private(set) var blocks: [UserBlockRecord] = []

    private let repository: any AccountSocialRepository
    private let profileStore: ProfileStore
    private var gymService: any GymService
    private var gymMembershipService: any GymMembershipService
    private var profileService: any ProfileService
    private var socialService: any SocialService
    private var cachedUserID: UUID

    init(
        repository: any AccountSocialRepository,
        profileStore: ProfileStore,
        gymService: any GymService,
        gymMembershipService: any GymMembershipService,
        profileService: any ProfileService,
        socialService: any SocialService
    ) {
        self.repository = repository
        self.profileStore = profileStore
        self.gymService = gymService
        self.gymMembershipService = gymMembershipService
        self.profileService = profileService
        self.socialService = socialService
        self.cachedUserID = repository.currentProfile.id
    }

    func updateServices(
        gymService: any GymService,
        gymMembershipService: any GymMembershipService,
        profileService: any ProfileService,
        socialService: any SocialService
    ) {
        self.gymService = gymService
        self.gymMembershipService = gymMembershipService
        self.profileService = profileService
        self.socialService = socialService
    }

    func refreshDirectoryAndRelationships() async throws {
        let userID = repository.currentProfile.id
        resetAccountScopedCacheIfNeeded()
        async let gyms = gymService.gyms()
        async let memberships = gymService.memberships()
        let (directory, joined) = try await (gyms, memberships)

        guard repository.currentProfile.id == userID else {
            resetAccountScopedCacheIfNeeded()
            return
        }
        profileStore.replaceGymDirectory(directory, memberships: joined)
        gymMemberships = joined
    }

    func refreshBlocks() async {
        let userID = repository.currentProfile.id
        resetAccountScopedCacheIfNeeded()
        guard let refreshed = try? await socialService.blocks() else {
            if repository.currentProfile.id != userID {
                resetAccountScopedCacheIfNeeded()
            }
            return
        }
        guard repository.currentProfile.id == userID else {
            resetAccountScopedCacheIfNeeded()
            return
        }
        blocks = refreshed
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
        let ownerID = repository.currentProfile.id
        resetAccountScopedCacheIfNeeded()
        guard userID != ownerID else { return }
        if blocked {
            try await socialService.block(userID: userID)
        } else {
            try await socialService.unblock(userID: userID)
        }
        guard repository.currentProfile.id == ownerID else {
            resetAccountScopedCacheIfNeeded()
            return
        }
        if let refreshed = try? await socialService.blocks() {
            guard repository.currentProfile.id == ownerID else {
                resetAccountScopedCacheIfNeeded()
                return
            }
            blocks = refreshed
        }
    }

    func clear() {
        gymMemberships = []
        blocks = []
        repository.gymRequests = []
        cachedUserID = repository.currentProfile.id
        profileStore.clearGymDirectory()
    }

    private func resetAccountScopedCacheIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        gymMemberships = []
        blocks = []
        repository.gymRequests = []
        profileStore.clearGymDirectory()
    }
}
