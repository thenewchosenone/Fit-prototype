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

        guard repository.currentProfile.id == userID else { return }
        profileStore.replaceGymDirectory(directory, memberships: joined)
        gymMemberships = joined
    }

    func refreshBlocks() async {
        let userID = repository.currentProfile.id
        resetAccountScopedCacheIfNeeded()
        guard let refreshed = try? await socialService.blocks() else { return }
        guard repository.currentProfile.id == userID else { return }
        blocks = refreshed
    }

    func ensureGymJoined(
        _ gym: Gym,
        maximumMemberships: Int,
        authenticated: Bool
    ) async throws -> Bool {
        if profileStore.isGymJoined(gym.id) { return true }
        if authenticated {
            let userID = repository.currentProfile.id
            guard try await gymMembershipService.join(
                gym,
                maximumMemberships: maximumMemberships
            ) else { return false }
            guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
            try await refreshDirectoryAndRelationships()
            guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
            return profileStore.isGymJoined(gym.id)
        }
        return profileStore.joinGym(gym, maximumMemberships: maximumMemberships)
    }

    func leaveGym(_ gym: Gym, authenticated: Bool) async throws {
        if authenticated {
            let userID = repository.currentProfile.id
            try await gymMembershipService.leave(gym)
            guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
            try await refreshDirectoryAndRelationships()
        } else {
            profileStore.leaveGym(gym)
        }
    }

    func setPrimaryGym(_ gym: Gym, authenticated: Bool) async throws {
        if authenticated {
            let userID = repository.currentProfile.id
            try await gymMembershipService.setPrimary(gym)
            guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
            try await refreshDirectoryAndRelationships()
        } else {
            profileStore.setPrimaryGym(gym)
        }
    }

    func isBlocked(_ userID: UUID) -> Bool {
        blocks.contains { $0.blockedID == userID }
    }

    func report(_ userID: UUID, reason: ProfileReportReason, note: String) async throws {
        let ownerID = repository.currentProfile.id
        guard userID != ownerID else { throw LiftRankServiceError.permissionDenied }
        try await socialService.report(userID: userID, reason: reason, note: note)
        guard repository.currentProfile.id == ownerID else { throw LiftRankServiceError.sessionExpired }
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
        guard repository.currentProfile.id == ownerID else { return }
        if let refreshed = try? await socialService.blocks() {
            guard repository.currentProfile.id == ownerID else { return }
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
