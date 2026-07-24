import Combine
import Foundation

@MainActor
final class NotificationStore: ObservableObject {
    private let repository: any NotificationRepository
    private let deviceID: String
    private let features: FeatureAvailability
    private var notificationService: (any NotificationService)?
    private var cancellable: AnyCancellable?

    init(
        repository: any NotificationRepository,
        notificationService: (any NotificationService)? = nil,
        features: FeatureAvailability = .resolved(for: nil),
        deviceID: String? = nil
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.features = features
        self.deviceID = deviceID ?? Self.persistedDeviceID()
        cancellable = repository.notificationChanges.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func updateService(_ notificationService: any NotificationService) {
        self.notificationService = notificationService
    }

    func refreshProductionData() async {
        clear()
        guard let notificationService else { return }
        replaceNotifications((try? await notificationService.notifications()) ?? [])
    }

    func registerPushToken(_ token: String, userID: UUID, environment: String) async {
        guard !token.isEmpty, let notificationService else { return }
        let registration = PushDeviceRegistration(
            id: UUID(),
            userID: userID,
            deviceID: deviceID,
            token: token,
            environment: environment,
            updatedAt: .now
        )
        try? await notificationService.registerDevice(registration)
    }

    func revokeCurrentDevice() async {
        guard let notificationService else { return }
        try? await notificationService.revokeDevice(deviceID: deviceID)
    }

    var notifications: [NotificationItem] { repository.notifications }
    var unreadCount: Int { notifications.lazy.filter { !$0.isRead }.count }

    func replaceNotifications(_ notifications: [NotificationItem]) {
        repository.notifications = notifications.filter(isEnabled)
    }

    func clear() {
        repository.notifications = []
    }

    func markRead(_ notificationID: UUID) {
        guard let index = repository.notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        repository.notifications[index].isRead = true
    }

    func markAllRead() {
        for index in repository.notifications.indices {
            repository.notifications[index].isRead = true
        }
    }

    func open(_ notification: NotificationItem, fallbackGymID: UUID) -> NotificationRoute {
        markRead(notification.id)
        let destination = notification.destination

        switch destination.kind {
        case .home:
            return .home
        case .leaderboard:
            var filters = LeaderboardFilters(exerciseID: destination.exerciseID)
            filters.rankingType = destination.rankingType ?? .absolute
            filters.gymID = destination.gymID ?? fallbackGymID
            return .leaderboard(filters)
        case .lift, .profile:
            return .profile(destination.targetID)
        case .messageThread:
            return .messageThread(destination.targetID)
        case .friendRequests:
            return .friendRequests
        case .gym:
            return .gym(destination.gymID ?? destination.targetID)
        case .workoutTracker:
            return .tracker(destination.trackerStartsOnProgress ? .progress : .today)
        case .workoutShare:
            return destination.targetID.map(NotificationRoute.workoutShare) ?? .home
        case .communityThread:
            guard let targetID = destination.targetID else { return .communityHome }
            if repository.forumPosts.contains(where: { $0.id == targetID }) {
                return .forumPost(targetID)
            }
            if repository.communityThreads.contains(where: { $0.id == targetID }) {
                return .communityThread(targetID)
            }
            return .communityHome
        case .forumCommunity:
            return destination.targetID.map(NotificationRoute.forumCommunity) ?? .communityHome
        case .forumPost:
            return destination.targetID.map(NotificationRoute.forumPost) ?? .communityHome
        }
    }

    private func isEnabled(_ notification: NotificationItem) -> Bool {
        switch notification.destination.kind {
        case .messageThread: return features.messaging
        case .communityThread, .forumCommunity, .forumPost: return features.forums
        case .gym: return features.gymFeeds
        case .workoutShare: return features.connectionActivity
        default: return true
        }
    }

    private static func persistedDeviceID() -> String {
        let key = "LiftRankPushDeviceID"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
