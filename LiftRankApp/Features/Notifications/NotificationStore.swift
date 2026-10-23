import Combine
import Foundation

@MainActor
final class NotificationStore: ObservableObject {
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var refreshError: String?
    private let repository: any NotificationRepository
    private let deviceID: String
    private var notificationService: (any NotificationService)?
    private var cancellable: AnyCancellable?
    private var cachedUserID: UUID
    private var cachedUnreadCountRevision: Int?
    private var cachedUnreadCount: Int?
    private var cachedSortedNotificationsRevision: Int?
    private var cachedSortedNotifications: [NotificationItem]?

    init(
        repository: any NotificationRepository,
        notificationService: (any NotificationService)? = nil,
        deviceID: String? = nil
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.deviceID = deviceID ?? Self.persistedDeviceID()
        self.cachedUserID = repository.currentProfile.id
        cancellable = repository.notificationChanges.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func updateService(_ notificationService: any NotificationService) {
        self.notificationService = notificationService
    }

    func refreshProductionData() async {
        let userID = repository.currentProfile.id
        resetAccountScopedCacheIfNeeded()
        let notificationsRevision = repository.notificationsRevision
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        guard let notificationService else {
            hasLoaded = true
            refreshError = "Notification service is unavailable."
            return
        }
        do {
            let notifications = try await notificationService.notifications()
            guard repository.currentProfile.id == userID else {
                resetAccountScopedCacheAfterStaleRefresh(startingAt: notificationsRevision)
                return
            }
            replaceNotifications(notifications)
            hasLoaded = true
            refreshError = nil
        } catch {
            guard repository.currentProfile.id == userID else {
                resetAccountScopedCacheAfterStaleRefresh(startingAt: notificationsRevision)
                return
            }
            hasLoaded = true
            refreshError = error.localizedDescription
        }
    }

    func registerPushToken(_ token: String, userID: UUID, environment: String) async {
        guard !token.isEmpty, repository.currentProfile.id == userID, let notificationService else { return }
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
    var sortedNotifications: [NotificationItem] {
        let revision = repository.notificationsRevision
        if let cachedSortedNotifications, cachedSortedNotificationsRevision == revision {
            return cachedSortedNotifications
        }
        let sorted = repository.notifications.sorted { $0.createdAt > $1.createdAt }
        cachedSortedNotifications = sorted
        cachedSortedNotificationsRevision = revision
        return sorted
    }
    var unreadCount: Int {
        let revision = repository.notificationsRevision
        if let cachedUnreadCount, cachedUnreadCountRevision == revision {
            return cachedUnreadCount
        }
        let count = repository.notifications.lazy.filter { !$0.isRead }.count
        cachedUnreadCount = count
        cachedUnreadCountRevision = revision
        return count
    }

    func replaceNotifications(_ notifications: [NotificationItem]) {
        repository.notifications = notifications.filter(isEnabled)
    }

    func clear() {
        repository.notifications = []
        cachedUserID = repository.currentProfile.id
        clearNotificationCaches()
        hasLoaded = false
        refreshError = nil
    }

    func markRead(_ notificationID: UUID) {
        resetAccountScopedCacheIfNeeded()
        guard let index = repository.notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        repository.notifications[index].isRead = true
        guard let notificationService else { return }
        let userID = repository.currentProfile.id
        Task {
            guard repository.currentProfile.id == userID else { return }
            try? await notificationService.markRead(notificationID: notificationID)
        }
    }

    func markAllRead() {
        resetAccountScopedCacheIfNeeded()
        let unreadNotifications = repository.notifications.filter { !$0.isRead }
        guard !unreadNotifications.isEmpty else { return }
        repository.notifications = repository.notifications.map { notification in
            var notification = notification
            notification.isRead = true
            return notification
        }
        guard let notificationService else { return }
        let notificationIDs = unreadNotifications.map(\.id)
        let userID = repository.currentProfile.id
        Task {
            for notificationID in notificationIDs {
                guard repository.currentProfile.id == userID else { return }
                try? await notificationService.markRead(notificationID: notificationID)
            }
        }
    }

    func open(_ notification: NotificationItem) -> NotificationRoute {
        markRead(notification.id)
        let destination = notification.destination

        switch destination.kind {
        case .home:
            return .home
        case .leaderboard:
            var filters = LeaderboardFilters(exerciseID: destination.exerciseID)
            filters.rankingType = destination.rankingType ?? .absolute
            return .leaderboard(filters)
        case .lift:
            return .profile(repository.currentProfile.id)
        case .profile:
            return .profile(destination.targetID)
        case .gym:
            return .gym(destination.gymID ?? destination.targetID)
        case .workoutTracker:
            return .tracker(destination.trackerStartsOnProgress ? .progress : .today)
        case .forumPost:
            guard let targetID = destination.targetID else { return .home }
            return .forumPost(targetID, commentID: destination.commentID)
        }
    }

    private func isEnabled(_ notification: NotificationItem) -> Bool {
        switch notification.destination.kind {
        case .gym:
            return true
        default: return true
        }
    }

    private func resetAccountScopedCacheIfNeeded() {
        guard cachedUserID != repository.currentProfile.id else { return }
        cachedUserID = repository.currentProfile.id
        clearNotificationCaches()
        repository.notifications = []
        hasLoaded = false
        refreshError = nil
    }

    private func resetAccountScopedCacheAfterStaleRefresh(startingAt revision: Int) {
        if repository.notificationsRevision == revision {
            repository.notifications = []
        }
        cachedUserID = repository.currentProfile.id
        clearNotificationCaches()
        hasLoaded = false
        refreshError = nil
    }

    private func clearNotificationCaches() {
        cachedUnreadCount = nil
        cachedUnreadCountRevision = nil
        cachedSortedNotifications = nil
        cachedSortedNotificationsRevision = nil
    }

    private static func persistedDeviceID() -> String {
        let key = "LiftRankPushDeviceID"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
