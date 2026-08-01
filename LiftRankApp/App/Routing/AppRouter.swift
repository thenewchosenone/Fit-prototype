import Combine
import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case home
    case leaderboards
    case track
    case profile
}

enum AppSheet: Identifiable, Hashable {
    case submitLift
    case leaderboardFilters
    case editProfile
    case moderatorReview
    case settings(SettingsSection?)
    case requestGym
    case reportLift(LiftSubmission)
    case profile(UserProfile)
    case gym(Gym)

    var id: String {
        switch self {
        case .submitLift: return "submit-lift"
        case .leaderboardFilters: return "leaderboard-filters"
        case .editProfile: return "edit-profile"
        case .moderatorReview: return "moderator-review"
        case .settings(let section): return "settings-\(section?.rawValue ?? "all")"
        case .requestGym: return "request-gym"
        case .reportLift(let lift): return "report-lift-\(lift.id)"
        case .profile(let profile): return "profile-\(profile.id)"
        case .gym(let gym): return "gym-\(gym.id)"
        }
    }
}

enum AppCover: String, Identifiable, Hashable {
    case authentication

    var id: String { rawValue }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var trackerSection: TrackerSection = .today
    @Published var requestsLeaderboardSearch = false
    @Published var sheet: AppSheet?
    @Published var cover: AppCover?

    func setSheet(_ destination: AppSheet, isPresented: Bool) {
        if isPresented {
            sheet = destination
        } else if sheet == destination {
            sheet = nil
        }
    }

    func setCover(_ destination: AppCover, isPresented: Bool) {
        if isPresented {
            cover = destination
        } else if cover == destination {
            cover = nil
        }
    }

    func openTracker(_ section: TrackerSection) {
        trackerSection = section
        selectedTab = .track
    }

    func openAthleteSearch() {
        requestsLeaderboardSearch = true
        selectedTab = .leaderboards
    }

}
