import Foundation

enum SupabaseProfileMapper {
    private static let noGymID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static func authenticated(_ remote: AuthenticatedProfile) -> UserProfile {
        UserProfile(
            id: remote.id,
            username: remote.username,
            displayName: remote.displayName,
            ageGroup: "Hidden",
            sexCategory: remote.sexCategory ?? .open,
            heightInches: (remote.heightCentimeters ?? 0) / 2.54,
            bodyweightPounds: remote.bodyweightPounds ?? 0,
            preferredUnit: remote.preferredUnit,
            city: remote.city ?? "",
            state: remote.region ?? "",
            primaryGymID: noGymID,
            primaryGymName: "No primary gym",
            yearsExperience: remote.yearsExperience ?? 0,
            experienceLevel: remote.experienceLevel ?? .beginner,
            profileImageName: "person.crop.circle",
            avatarPath: remote.avatarPath,
            followers: 0,
            following: 0,
            hideExactAge: remote.privacy.ageBandAudience == .privateProfile,
            hideBodyweight: remote.privacy.bodyweightAudience == .privateProfile,
            hideCity: remote.privacy.locationAudience == .privateProfile,
            hideGym: true,
            hideLiftVideos: false
        )
    }

    static func leaderboard(
        card: PublicProfileCard,
        bodyweightPounds: Double,
        fallbackGymID: UUID,
        bodyweightVisible: Bool
    ) -> UserProfile {
        UserProfile(
            id: card.id,
            username: card.username,
            displayName: card.displayName,
            ageGroup: card.ageBand ?? "Hidden",
            sexCategory: card.sexCategory ?? .open,
            heightInches: 0,
            bodyweightPounds: bodyweightPounds,
            preferredUnit: .pounds,
            city: card.city ?? "",
            state: card.region ?? "",
            primaryGymID: card.primaryGymID ?? fallbackGymID,
            primaryGymName: card.primaryGymName ?? "Gym hidden",
            yearsExperience: 0,
            experienceLevel: .beginner,
            profileImageName: "person.crop.circle",
            avatarPath: card.avatarPath,
            followers: 0,
            following: 0,
            hideExactAge: card.ageBand == nil,
            hideBodyweight: !bodyweightVisible,
            hideCity: card.city == nil,
            hideGym: card.primaryGymID == nil,
            hideLiftVideos: false
        )
    }
}
