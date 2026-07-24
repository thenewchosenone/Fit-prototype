import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    private let repository: any ProfileRepository
    private var profileService: (any ProfileService)?
    private var cancellable: AnyCancellable?

    init(
        repository: any ProfileRepository,
        profileService: (any ProfileService)? = nil
    ) {
        self.repository = repository
        self.profileService = profileService
        cancellable = repository.profileChanges.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func updateService(_ profileService: any ProfileService) {
        self.profileService = profileService
    }

    func loadAuthenticatedProfile(retainingDemoProfiles: Bool) async throws -> AuthenticatedProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        let remote = try await profileService.authenticatedProfile()
        applyAuthenticatedProfile(remote, retainingDemoProfiles: retainingDemoProfiles)
        return remote
    }

    func saveAuthenticatedProfile(
        _ draft: ProfileDraft,
        retainingDemoProfiles: Bool
    ) async throws -> AuthenticatedProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        let remote = try await profileService.saveProfile(draft)
        applyAuthenticatedProfile(remote, retainingDemoProfiles: retainingDemoProfiles)
        return remote
    }

    var currentProfile: UserProfile { repository.currentProfile }
    var profiles: [UserProfile] { repository.profiles }
    var gyms: [Gym] { repository.gyms }
    var joinedGymIDs: Set<UUID> { repository.joinedGymIDs }
    var joinedGyms: [Gym] { gyms.filter { joinedGymIDs.contains($0.id) } }
    var joinedGymCount: Int { joinedGymIDs.count }

    func canJoinAnotherGym(maximumMemberships: Int) -> Bool {
        joinedGymCount < maximumMemberships
    }

    func isGymJoined(_ gymID: UUID) -> Bool {
        joinedGymIDs.contains(gymID)
    }

    func isPrimaryGym(_ gymID: UUID) -> Bool {
        currentProfile.primaryGymID == gymID
    }

    func profile(id: UUID) -> UserProfile? {
        profiles.first { $0.id == id }
    }

    func containsGym(id: UUID) -> Bool {
        gyms.contains { $0.id == id }
    }

    func saveProfile(_ profile: UserProfile, insertIfMissing: Bool = true) {
        repository.currentProfile = profile
        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            repository.profiles[index] = profile
        } else if insertIfMissing {
            repository.profiles.insert(profile, at: 0)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        var saved = try await profileService.updateProfile(profile)
        saved.avatarPath = profile.avatarPath
        saveProfile(saved)
        return saved
    }

    func saveEditedProfile(
        _ profile: UserProfile,
        primaryGym: Gym,
        privacy: ProfilePrivacySettings,
        authenticated: Bool
    ) async throws -> UserProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        var saved: UserProfile
        if authenticated {
            let existing = try await profileService.authenticatedProfile()
            let remote = try await profileService.saveProfile(ProfileDraft(
                username: profile.username,
                displayName: profile.displayName,
                bio: existing.bio,
                preferredUnit: profile.preferredUnit,
                birthDate: existing.birthDate,
                sexCategory: profile.sexCategory,
                heightCentimeters: profile.heightInches * 2.54,
                bodyweightPounds: profile.bodyweightPounds,
                city: profile.city,
                region: profile.state,
                countryCode: existing.countryCode ?? "US",
                yearsExperience: profile.yearsExperience,
                experienceLevel: profile.experienceLevel,
                privacy: privacy,
                completesOnboarding: existing.onboardingCompleted
            ))
            applyAuthenticatedProfile(remote, retainingDemoProfiles: false)
            saved = currentProfile
        } else {
            saved = try await profileService.updateProfile(profile)
        }

        saved.avatarPath = profile.avatarPath
        saved.primaryGymID = primaryGym.id
        saved.primaryGymName = primaryGym.name
        saved.city = primaryGym.city
        saved.state = primaryGym.state
        saveProfile(saved)
        return saved
    }

    func applyAuthenticatedProfile(_ remote: AuthenticatedProfile, retainingDemoProfiles: Bool) {
        var local = repository.currentProfile
        local.id = remote.id
        local.username = remote.username
        local.displayName = remote.displayName
        local.preferredUnit = remote.preferredUnit
        local.sexCategory = remote.sexCategory ?? .open
        local.heightInches = (remote.heightCentimeters ?? 0) / 2.54
        local.bodyweightPounds = remote.bodyweightPounds ?? 0
        local.city = remote.city ?? ""
        local.state = remote.region ?? ""
        local.yearsExperience = remote.yearsExperience ?? 0
        local.experienceLevel = remote.experienceLevel ?? .beginner
        local.followers = 0
        local.following = 0
        local.hideExactAge = remote.privacy.ageBandAudience == .privateProfile
        local.hideBodyweight = remote.privacy.bodyweightAudience == .privateProfile
        local.hideCity = remote.privacy.locationAudience == .privateProfile
        local.hideGym = remote.privacy.gymAudience == .privateProfile
        if let avatarPath = remote.avatarPath {
            local.avatarPath = avatarPath
        }

        repository.currentProfile = local
        if !retainingDemoProfiles {
            repository.profiles = [local]
        } else if let index = repository.profiles.firstIndex(where: { $0.id == local.id }) {
            repository.profiles[index] = local
        } else {
            repository.profiles.insert(local, at: 0)
        }
    }

    func replaceGymDirectory(_ gyms: [Gym], memberships: [GymMembershipRecord]) {
        repository.gyms = gyms
        repository.joinedGymIDs = Set(memberships.filter { $0.leftAt == nil }.map(\.gymID))
        guard let primaryMembership = memberships.first(where: { $0.isPrimary && $0.leftAt == nil }),
              let primaryGym = gyms.first(where: { $0.id == primaryMembership.gymID }) else { return }
        setPrimaryGym(primaryGym)
    }

    func mergePublicProfileCard(_ card: PublicProfileCard) {
        var profile = MockData.emptyProfile
        profile.id = card.id
        profile.username = card.username
        profile.displayName = card.displayName
        profile.ageGroup = card.ageBand ?? "Hidden"
        profile.sexCategory = card.sexCategory ?? .open
        profile.city = card.city ?? ""
        profile.state = card.region ?? ""
        profile.primaryGymID = card.primaryGymID ?? UUID()
        profile.primaryGymName = card.primaryGymName ?? "Hidden"
        profile.bodyweightPounds = 0
        profile.followers = 0
        profile.following = 0
        profile.hideExactAge = card.ageBand == nil
        profile.hideCity = card.city == nil
        profile.hideGym = card.primaryGymID == nil

        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            repository.profiles[index] = profile
        } else {
            repository.profiles.append(profile)
        }
    }

    @discardableResult
    func joinGym(_ gym: Gym, maximumMemberships: Int) -> Bool {
        repository.joinGym(gym, maximumMemberships: maximumMemberships)
    }

    func leaveGym(_ gym: Gym) {
        repository.leaveGym(gym)
    }

    func setPrimaryGym(_ gym: Gym) {
        var profile = repository.currentProfile
        profile.primaryGymID = gym.id
        profile.primaryGymName = gym.name
        repository.currentProfile = profile
    }
}
