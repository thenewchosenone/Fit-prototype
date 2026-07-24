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
    case messageThread(UUID?)
    case friendRequests
    case gym(UUID?)
    case tracker(TrackerSection)
    case workoutShare(UUID)
    case communityThread(UUID)
    case communityHome
    case forumCommunity(UUID)
    case forumPost(UUID)
}
