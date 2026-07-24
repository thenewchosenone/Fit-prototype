import Foundation
import UserNotifications

protocol WorkoutRestNotificationScheduling {
    func schedule(endsAt: Date, exerciseName: String)
    func cancel()
}

final class SystemWorkoutRestNotificationScheduler: WorkoutRestNotificationScheduling {
    static let shared = SystemWorkoutRestNotificationScheduler()

    private let identifier = "liftrank-active-rest-timer"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(endsAt: Date, exerciseName: String) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.addRequest(endsAt: endsAt, exerciseName: exerciseName)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    if granted {
                        self?.addRequest(endsAt: endsAt, exerciseName: exerciseName)
                    }
                }
            default:
                break
            }
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func addRequest(endsAt: Date, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Your next \(exerciseName) set is ready."
        content.sound = .default
        let interval = max(1, endsAt.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        cancel()
        center.add(request)
    }
}
