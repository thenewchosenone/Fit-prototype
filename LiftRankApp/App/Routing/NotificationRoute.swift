import Foundation

enum TrackerSection: String, CaseIterable, Hashable {
    case today = "Today"
    case plans = "Plans"
    case library = "Library"
    case progress = "Progress"
}

enum NotificationRoute: Hashable {
    case home
    case leaderboard(LeaderboardFilters)
    case profile(UUID?)
    case gym(UUID?)
    case tracker(TrackerSection)
}
