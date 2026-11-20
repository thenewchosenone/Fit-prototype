import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationStore: ObservableObject {
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
        guard let notificationService else { return }
        guard let notifications = try? await notificationService.notifications() else { return }
        guard repository.currentProfile.id == userID else { return }
        replaceNotifications(notifications)
    }

    static func pushEnvironment(signingEnvironment: String?) -> String? {
        switch signingEnvironment {
        case "development": "sandbox"
        case "production": "production"
        default: nil
        }
    }

    func registerPushToken(_ token: String, userID: UUID, environment: String) async throws {
        guard !token.isEmpty, repository.currentProfile.id == userID, let notificationService else { return }
        let registration = PushDeviceRegistration(
            id: UUID(),
            userID: userID,
            deviceID: deviceID,
            token: token,
            environment: environment,
            updatedAt: .now
        )
        try await notificationService.registerDevice(registration)
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
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        repository.notifications = []
        cachedUserID = repository.currentProfile.id
        clearNotificationCaches()
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
        return route(for: notification.destination)
    }

    func route(for destination: NotificationDestination) -> NotificationRoute {
        switch destination.kind {
        case .friendRequests:
            return .friendRequests
        case .home, .unsupported:
            return .home
        case .leaderboard:
            var filters = LeaderboardFilters(exerciseID: destination.exerciseID)
            filters.rankingType = destination.rankingType ?? .absolute
            filters.gymID = destination.gymID
            filters.ageGroup = destination.ageGroup
            filters.sexCategory = destination.sexCategory
            if destination.videoBackedOnly == true { filters.verificationLevel = .videoVerified }
            return .leaderboard(filters)
        case .lift:
            return .profile(repository.currentProfile.id)
        case .profile:
            return .profile(destination.targetID)
        case .gym:
            return .gym(destination.gymID ?? destination.targetID)
        case .workoutTracker:
            return .tracker(destination.trackerStartsOnProgress ? .progress : .today)
        case .activeWorkout:
            return .activeWorkout
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
