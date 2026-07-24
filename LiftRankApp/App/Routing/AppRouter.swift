import Combine
import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case home
    case leaderboards
    case track
    case community
    case profile
}

enum CommunitySection: String, CaseIterable, Hashable {
    case home = "Home"
    case explore = "Explore"
    case inbox = "Inbox"

    // Kept while the legacy community screen remains available.
    case feed = "Feed"
    case messages = "Messages"
    case gyms = "Gyms"
}

struct ForumComposerRoute: Hashable {
    var communityID: UUID?
    var gymID: UUID?
    var liftID: UUID?
    var workoutID: UUID?
}

enum AppSheet: Identifiable, Hashable {
    case submitLift
    case leaderboardFilters
    case editProfile
    case moderatorReview
    case settings
    case createThread
    case requestGym
    case reportLift
    case profile(UserProfile)
    case gym(Gym)
    case messageThread(DirectMessageThread)
    case communityThread(CommunityThread)
    case activity(ActivityItem)

    var id: String {
        switch self {
        case .submitLift: return "submit-lift"
        case .leaderboardFilters: return "leaderboard-filters"
        case .editProfile: return "edit-profile"
        case .moderatorReview: return "moderator-review"
        case .settings: return "settings"
        case .createThread: return "create-thread"
        case .requestGym: return "request-gym"
        case .reportLift: return "report-lift"
        case .profile(let profile): return "profile-\(profile.id)"
        case .gym(let gym): return "gym-\(gym.id)"
        case .messageThread(let thread): return "message-\(thread.id)"
        case .communityThread(let thread): return "community-thread-\(thread.id)"
        case .activity(let activity): return "activity-\(activity.id)"
        }
    }
}

enum AppCover: String, Identifiable, Hashable {
    case authentication
    case forumComposer

    var id: String { rawValue }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var trackerSection: TrackerSection = .today
    @Published var communitySection: CommunitySection = .home
    @Published var communityPath: [ForumRoute] = []
    @Published var requestsLeaderboardSearch = false
    @Published var sheet: AppSheet?
    @Published var cover: AppCover?
    @Published var forumComposer = ForumComposerRoute()

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

    func clearForumComposer() {
        forumComposer = ForumComposerRoute()
    }
}
