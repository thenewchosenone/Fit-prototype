import Combine
import Foundation

@MainActor
final class NotificationStore: ObservableObject {
    private let repository: any NotificationRepository
    private let deviceID: String
    private var notificationService: (any NotificationService)?
    private var cancellable: AnyCancellable?
    private var cachedUserID: UUID

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
        guard let notifications = try? await notificationService.notifications() else {
            if repository.currentProfile.id != userID {
                resetAccountScopedCacheIfNeeded()
            }
            return
        }
        guard repository.currentProfile.id == userID else {
            resetAccountScopedCacheIfNeeded()
            return
        }
        replaceNotifications(notifications)
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
    var unreadCount: Int { notifications.lazy.filter { !$0.isRead }.count }

    func replaceNotifications(_ notifications: [NotificationItem]) {
        repository.notifications = notifications.filter(isEnabled)
    }

    func clear() {
        repository.notifications = []
        cachedUserID = repository.currentProfile.id
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
        for index in repository.notifications.indices {
            repository.notifications[index].isRead = true
        }
        guard let notificationService else { return }
        let notificationIDs = repository.notifications.map(\.id)
        let userID = repository.currentProfile.id
        Task {
            for notificationID in notificationIDs {
                guard repository.currentProfile.id == userID else { return }
                try? await notificationService.markRead(notificationID: notificationID)
            }
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
        case .lift:
            return .profile(repository.currentProfile.id)
        case .profile:
            return .profile(destination.targetID)
        case .gym:
            return .gym(destination.gymID ?? destination.targetID)
        case .workoutTracker:
            return .tracker(destination.trackerStartsOnProgress ? .progress : .today)
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
        repository.notifications = []
    }

    private static func persistedDeviceID() -> String {
        let key = "LiftRankPushDeviceID"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
