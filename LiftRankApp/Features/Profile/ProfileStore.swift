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

    func fetchAuthenticatedProfile() async throws -> AuthenticatedProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        return try await profileService.authenticatedProfile()
    }

    func saveAuthenticatedProfile(
        _ draft: ProfileDraft,
        retainingDemoProfiles: Bool
    ) async throws -> AuthenticatedProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        let expectedUserID = repository.currentProfile.id
        let remote = try await profileService.saveProfile(draft)
        guard repository.currentProfile.id == expectedUserID,
              remote.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
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
        if repository.currentProfile != profile {
            repository.currentProfile = profile
        }
        if let index = repository.profiles.firstIndex(where: { $0.id == profile.id }) {
            if repository.profiles[index] != profile {
                repository.profiles[index] = profile
            }
        } else if insertIfMissing {
            repository.profiles.insert(profile, at: 0)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        let expectedUserID = repository.currentProfile.id
        guard profile.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
        var saved = try await profileService.updateProfile(profile)
        guard repository.currentProfile.id == expectedUserID,
              saved.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
        saved.avatarPath = profile.avatarPath
        saveProfile(saved)
        return saved
    }

    func saveEditedProfile(
        _ profile: UserProfile,
        primaryGym: Gym?,
        privacy: ProfilePrivacySettings,
        authenticated: Bool
    ) async throws -> UserProfile {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        let expectedUserID = repository.currentProfile.id
        guard profile.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
        var saved: UserProfile
        if authenticated {
            let existing = try await profileService.authenticatedProfile()
            guard repository.currentProfile.id == expectedUserID,
                  existing.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
            let remote = try await profileService.saveProfile(ProfileDraft(
                username: profile.username,
                displayName: profile.displayName,
                bio: profile.bio ?? existing.bio,
                avatarPath: profile.avatarPath,
                preferredUnit: profile.preferredUnit,
                birthDate: ProfileDisplayFormatting.representativeBirthDate(
                    for: profile.ageGroup,
                    fallback: existing.birthDate ?? Date()
                ),
                sexCategory: profile.sexCategory,
                heightCentimeters: profile.heightInches * 2.54,
                bodyweightPounds: profile.bodyweightPounds,
                cityID: profile.cityID,
                city: profile.city,
                region: profile.state,
                countryCode: existing.countryCode ?? "US",
                yearsExperience: profile.yearsExperience,
                experienceLevel: profile.experienceLevel,
                privacy: privacy,
                completesOnboarding: existing.onboardingCompleted
            ))
            guard repository.currentProfile.id == expectedUserID,
                  remote.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
            applyAuthenticatedProfile(remote, retainingDemoProfiles: false)
            saved = currentProfile
        } else {
            saved = try await profileService.updateProfile(profile)
            guard repository.currentProfile.id == expectedUserID,
                  saved.id == expectedUserID else { throw LiftRankServiceError.sessionExpired }
        }

        if let primaryGym {
            saved.primaryGymID = primaryGym.id
            saved.primaryGymName = primaryGym.name
        }
        saveProfile(saved)
        return saved
    }

    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        return try await profileService.uploadProfileAvatar(
            avatarPath: avatarPath,
            fullImageURL: fullImageURL,
            thumbnailURL: thumbnailURL
        )
    }

    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        return try await profileService.downloadProfileAvatar(avatarPath: avatarPath)
    }

    func removeProfileAvatar(avatarPath: String?) async throws {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        try await profileService.removeProfileAvatar(avatarPath: avatarPath)
    }

    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry] {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        return try await profileService.synchronizeBodyweightEntries(localEntries)
    }

    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws {
        guard let profileService else { throw LiftRankServiceError.configurationMissing }
        try await profileService.saveBodyweightEntry(entry)
    }

    func applyAuthenticatedProfile(_ remote: AuthenticatedProfile, retainingDemoProfiles: Bool) {
        let isSameAccount = repository.currentProfile.id == remote.id
        var local = repository.currentProfile
        local.id = remote.id
        local.username = remote.username
        local.displayName = remote.displayName
        local.bio = remote.bio
        local.preferredUnit = remote.preferredUnit
        local.sexCategory = remote.sexCategory ?? .open
        local.heightInches = (remote.heightCentimeters ?? 0) / 2.54
        local.bodyweightPounds = remote.bodyweightPounds ?? 0
        local.city = remote.city ?? ""
        local.state = remote.region ?? ""
        local.cityID = remote.cityID
        local.yearsExperience = remote.yearsExperience ?? 0
        local.experienceLevel = remote.experienceLevel ?? .beginner
        local.hideExactAge = remote.privacy.ageBandAudience == .privateProfile
        local.hideBodyweight = remote.privacy.bodyweightAudience == .privateProfile
        local.hideCity = remote.privacy.locationAudience == .privateProfile
        local.hideGym = remote.privacy.gymAudience == .privateProfile
        local.hideLiftVideos = !remote.privacy.showLiftVideos
        local.avatarPath = remote.avatarPath

        if repository.currentProfile != local {
            repository.currentProfile = local
        }
        if !retainingDemoProfiles && !isSameAccount {
            if repository.profiles != [local] {
                repository.profiles = [local]
            }
        } else if let index = repository.profiles.firstIndex(where: { $0.id == local.id }) {
            if repository.profiles[index] != local {
                repository.profiles[index] = local
            }
        } else {
            repository.profiles.insert(local, at: 0)
        }
    }

    func replaceGymDirectory(_ gyms: [Gym], memberships: [GymMembershipRecord]) {
        if repository.gyms != gyms {
            repository.gyms = gyms
        }
        let joinedGymIDs = Set(memberships.filter { $0.leftAt == nil }.map(\.gymID))
        if repository.joinedGymIDs != joinedGymIDs {
            repository.joinedGymIDs = joinedGymIDs
        }
        guard let primaryMembership = memberships.first(where: { $0.isPrimary && $0.leftAt == nil }),
              let primaryGym = gyms.first(where: { $0.id == primaryMembership.gymID }) else {
            clearPrimaryGym()
            return
        }
        setPrimaryGym(primaryGym)
    }

    func clearGymDirectory() {
        repository.gyms = []
        repository.joinedGymIDs = []
        clearPrimaryGym()
    }

    private func clearPrimaryGym() {
        var profile = repository.currentProfile
        profile.primaryGymID = UUID()
        profile.primaryGymName = ""
        saveProfile(profile, insertIfMissing: false)
    }

    func mergePublicProfileCard(_ card: PublicProfileCard) {
        var profile = MockData.emptyProfile
        profile.id = card.id
        profile.username = card.username
        profile.displayName = card.displayName
        profile.bio = card.bio
        profile.ageGroup = card.ageBand ?? "Hidden"
        profile.sexCategory = card.sexCategory ?? .open
        profile.city = card.city ?? ""
        profile.state = card.region ?? ""
        profile.primaryGymID = card.primaryGymID ?? UUID()
        profile.primaryGymName = card.primaryGymName ?? "Hidden"
        profile.bodyweightPounds = 0
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
