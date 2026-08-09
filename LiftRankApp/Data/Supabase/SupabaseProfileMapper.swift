import Foundation

enum SupabaseProfileMapper {
    private static let noGymID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static func authenticated(_ remote: AuthenticatedProfile) -> UserProfile {
        UserProfile(
            id: remote.id,
            username: remote.username,
            displayName: remote.displayName,
            bio: remote.bio,
            ageGroup: ProfileDisplayFormatting.ageGroup(for: remote.birthDate),
            sexCategory: remote.sexCategory ?? .open,
            heightInches: (remote.heightCentimeters ?? 0) / 2.54,
            bodyweightPounds: remote.bodyweightPounds ?? 0,
            preferredUnit: remote.preferredUnit,
            city: remote.city ?? "",
            state: remote.region ?? "",
            cityID: remote.cityID,
            primaryGymID: noGymID,
            primaryGymName: "No primary gym",
            yearsExperience: remote.yearsExperience ?? 0,
            experienceLevel: remote.experienceLevel ?? .beginner,
            profileImageName: "person.crop.circle",
            avatarPath: remote.avatarPath,
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
        fallbackGymID: UUID?,
        bodyweightVisible: Bool
    ) -> UserProfile {
        UserProfile(
            id: card.id,
            username: card.username,
            displayName: card.displayName,
            bio: card.bio,
            ageGroup: card.ageBand ?? "Hidden",
            sexCategory: card.sexCategory ?? .open,
            heightInches: 0,
            bodyweightPounds: bodyweightPounds,
            preferredUnit: .pounds,
            city: card.city ?? "",
            state: card.region ?? "",
            cityID: nil,
            primaryGymID: card.primaryGymID ?? fallbackGymID ?? noGymID,
            primaryGymName: card.primaryGymName ?? "Gym hidden",
            yearsExperience: 0,
            experienceLevel: .beginner,
            profileImageName: "person.crop.circle",
            avatarPath: card.avatarPath,
            hideExactAge: card.ageBand == nil,
            hideBodyweight: !bodyweightVisible,
            hideCity: card.city == nil,
            hideGym: card.primaryGymID == nil,
            hideLiftVideos: false
        )
    }
}

enum ProfileDataAuthority {
    static func currentBodyweight(profilePounds: Double, historyFallbackPounds: Double?) -> Double {
        guard profilePounds <= 0,
              let historyFallbackPounds,
              historyFallbackPounds > 0 else { return profilePounds }
        return historyFallbackPounds
    }
}

enum ProfileDisplayFormatting {
    static func location(city: String?, region: String?, hidden: Bool = false) -> String {
        guard !hidden else { return "Location hidden" }
        let parts = [city, region]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Location missing" : parts.joined(separator: ", ")
    }

    static func ageGroup(for birthDate: Date?, calendar: Calendar = .current, now: Date = .now) -> String {
        guard let birthDate else { return "Hidden" }
        let age = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        switch age {
        case ..<18:
            return "Under 18"
        case 18...24:
            return "18-24"
        case 25...29:
            return "25-29"
        case 30...34:
            return "30-34"
        case 35...39:
            return "35-39"
        case 40...44:
            return "40-44"
        case 45...49:
            return "45-49"
        case 50...54:
            return "50-54"
        case 55...59:
            return "55-59"
        case 60...64:
            return "60-64"
        case 65...69:
            return "65-69"
        default:
            return "70+"
        }
    }

    static func representativeBirthDate(for ageGroup: String, calendar: Calendar = .current, now: Date = .now, fallback: Date = .now) -> Date {
        let representativeAge: Int
        switch ageGroup {
        case "Under 18":
            representativeAge = 16
        case "18-24":
            representativeAge = 21
        case "25-29":
            representativeAge = 27
        case "30-34":
            representativeAge = 32
        case "35-39":
            representativeAge = 37
        case "40-44":
            representativeAge = 42
        case "45-49":
            representativeAge = 47
        case "50-54":
            representativeAge = 52
        case "55-59":
            representativeAge = 57
        case "60-64":
            representativeAge = 62
        case "65-69":
            representativeAge = 67
        default:
            representativeAge = 72
        }
        return calendar.date(byAdding: .year, value: -representativeAge, to: now) ?? fallback
    }
}
