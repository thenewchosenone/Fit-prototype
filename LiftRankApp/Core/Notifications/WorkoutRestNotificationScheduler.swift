import Foundation
import UserNotifications

protocol WorkoutRestNotificationScheduling {
    func schedule(endsAt: Date, exerciseName: String)
    func cancel()
}

final class SystemWorkoutRestNotificationScheduler: WorkoutRestNotificationScheduling {
    static let shared = SystemWorkoutRestNotificationScheduler()

    private let identifier = "liftrank-active-rest-timer"
    private let inactivityIdentifier = "liftrank-open-workout-reminder"
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

    func scheduleInactivityReminder(at date: Date, workoutName: String) {
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Workout still open?"
            content.body = "\(workoutName) has been open for a while. Finish it or pause it when you’re done."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: self.inactivityIdentifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            )
            self.center.removePendingNotificationRequests(withIdentifiers: [self.inactivityIdentifier])
            self.center.add(request)
        }
    }

    func cancelInactivityReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [inactivityIdentifier])
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
