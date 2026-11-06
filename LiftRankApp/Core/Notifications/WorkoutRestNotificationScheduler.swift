import Foundation
import UserNotifications
import AVFoundation
import Combine

@MainActor
final class WorkoutRestTimerAlertSound: NSObject, AVAudioPlayerDelegate {
    static let shared = WorkoutRestTimerAlertSound()
    private var player: AVAudioPlayer?
    private lazy var tone = toneData()

    func play() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        guard let player = try? AVAudioPlayer(data: tone) else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            return
        }
        self.player = player
        player.delegate = self
        player.volume = 1
        player.play()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func toneData() -> Data {
        let sampleRate: UInt32 = 44_100
        let sampleCount = Int(sampleRate) * 2
        var samples = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let frequency = time.truncatingRemainder(dividingBy: 0.8) < 0.4 ? 880.0 : 1_100.0
            let edge = min(1, min(Double(index) / 441, Double(sampleCount - index) / 2_646))
            let value = Int16(sin(2 * .pi * frequency * time) * edge * 0.8 * Double(Int16.max))
            var littleEndianValue = value.littleEndian
            withUnsafeBytes(of: &littleEndianValue) { samples.append(contentsOf: $0) }
        }

        var data = Data()
        func append(_ text: String) { data.append(contentsOf: text.utf8) }
        func append16(_ value: UInt16) {
            var littleEndianValue = value.littleEndian
            withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
        }
        func append32(_ value: UInt32) {
            var littleEndianValue = value.littleEndian
            withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
        }
        append("RIFF")
        append32(UInt32(36 + samples.count))
        append("WAVEfmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(sampleRate)
        append32(sampleRate * 2)
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(samples.count))
        data.append(samples)
        return data
    }
}

protocol WorkoutRestNotificationScheduling {
    func schedule(endsAt: Date, exerciseName: String)
    func cancel()
}

enum WorkoutRestAlertStatus: Equatable {
    case inactive
    case checking
    case scheduled
    case quiet
    case blocked
    case failed
}

final class SystemWorkoutRestNotificationScheduler: WorkoutRestNotificationScheduling, ObservableObject {
    static let shared = SystemWorkoutRestNotificationScheduler()

    @Published private(set) var status: WorkoutRestAlertStatus = .inactive

    private let identifier = "liftrank-active-rest-timer"
    private let center: UNUserNotificationCenter
    private let revisionLock = NSLock()
    private var revision = 0

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(endsAt: Date, exerciseName: String) {
        let scheduledRevision = advanceRevision()
        report(.checking, revision: scheduledRevision)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.getNotificationSettings { [weak self] settings in
            guard let self, self.isCurrent(scheduledRevision) else { return }
            switch settings.authorizationStatus {
            case .authorized, .ephemeral:
                self.addRequest(endsAt: endsAt, exerciseName: exerciseName, revision: scheduledRevision, success: .scheduled)
            case .provisional:
                self.addRequest(endsAt: endsAt, exerciseName: exerciseName, revision: scheduledRevision, success: .quiet)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
                    if granted {
                        self?.addRequest(endsAt: endsAt, exerciseName: exerciseName, revision: scheduledRevision, success: .scheduled)
                    } else {
                        self?.report(error == nil ? .blocked : .failed, revision: scheduledRevision)
                    }
                }
            default:
                self.report(.blocked, revision: scheduledRevision)
            }
        }
    }

    func cancel() {
        let canceledRevision = advanceRevision()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        report(.inactive, revision: canceledRevision)
    }

    private func advanceRevision() -> Int {
        revisionLock.lock()
        defer { revisionLock.unlock() }
        revision &+= 1
        return revision
    }

    private func isCurrent(_ scheduledRevision: Int) -> Bool {
        revisionLock.lock()
        defer { revisionLock.unlock() }
        return revision == scheduledRevision
    }

    private func addRequest(endsAt: Date, exerciseName: String, revision scheduledRevision: Int, success: WorkoutRestAlertStatus) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Your rest timer has finished."
        content.sound = .default
        content.userInfo = ["local_destination": "active_workout"]
        let interval = max(1, endsAt.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        revisionLock.lock()
        defer { revisionLock.unlock() }
        guard revision == scheduledRevision else { return }
        center.add(request) { [weak self] error in
            self?.report(error == nil ? success : .failed, revision: scheduledRevision)
        }
    }

    private func report(_ status: WorkoutRestAlertStatus, revision scheduledRevision: Int) {
        guard isCurrent(scheduledRevision) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrent(scheduledRevision) else { return }
            self.status = status
        }
    }
}

@MainActor
final class WorkoutTodayReminderScheduler {
    static let shared = WorkoutTodayReminderScheduler()
    private let center = UNUserNotificationCenter.current()
    private var revision = 0
    private let identifiers = (0..<48).map { "liftrank-workout-session-\($0)" }
        + (1...7).map { "liftrank-workout-day-\($0)" }

    static func reminderDate(on day: Date, minutesAfterMidnight: Int, calendar: Calendar = .current) -> Date? {
        guard (0..<1440).contains(minutesAfterMidnight) else { return nil }
        return calendar.date(bySettingHour: minutesAfterMidnight / 60,
                             minute: minutesAfterMidnight % 60, second: 0, of: day)
    }

    static func missedReminderDate(on day: Date, minutesAfterMidnight: Int, calendar: Calendar = .current) -> Date? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return reminderDate(on: nextDay, minutesAfterMidnight: minutesAfterMidnight, calendar: calendar)
    }

    static func upcomingReminders(
        dayEnabled: Bool,
        missedEnabled: Bool,
        sessions: [(date: Date, name: String)],
        minutesAfterMidnight: Int,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [(date: Date, name: String, missed: Bool)] {
        sessions.flatMap { session -> [(date: Date, name: String, missed: Bool)] in
            var reminders: [(date: Date, name: String, missed: Bool)] = []
            if dayEnabled,
               let date = reminderDate(on: session.date, minutesAfterMidnight: minutesAfterMidnight, calendar: calendar),
               date > referenceDate {
                reminders.append((date, session.name, false))
            }
            if missedEnabled,
               let date = missedReminderDate(on: session.date, minutesAfterMidnight: minutesAfterMidnight, calendar: calendar),
               date > referenceDate {
                reminders.append((date, session.name, true))
            }
            return reminders
        }.sorted { $0.date < $1.date }.prefix(48).map { $0 }
    }

    func schedule(dayEnabled: Bool, missedEnabled: Bool, sessions: [(date: Date, name: String)], minutesAfterMidnight: Int) async throws {
        revision += 1
        let requestRevision = revision
        let pending = await center.pendingNotificationRequests()
        guard requestRevision == revision else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers + pending.filter {
            $0.identifier.hasPrefix("liftrank-workout-session-")
        }.map(\.identifier))
        guard dayEnabled || missedEnabled, !sessions.isEmpty else { return }
        let settings = await center.notificationSettings()
        guard requestRevision == revision else { return }
        let authorized: Bool
        if settings.authorizationStatus == .notDetermined {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        } else {
            authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        }
        guard requestRevision == revision else { return }
        guard authorized else {
            throw NSError(domain: "WorkoutReminders", code: 1, userInfo: [NSLocalizedDescriptionKey: "Workout reminders are blocked. Enable notifications in iOS Settings."])
        }
        let upcoming = Self.upcomingReminders(
            dayEnabled: dayEnabled,
            missedEnabled: missedEnabled,
            sessions: sessions,
            minutesAfterMidnight: minutesAfterMidnight
        )
        let batchID = UUID().uuidString
        for (index, session) in upcoming.enumerated() {
            guard requestRevision == revision else { return }
            let content = UNMutableNotificationContent()
            content.title = session.missed ? "Missed workout" : "Workout today"
            content.body = session.missed
                ? "Your schedule has an unfinished workout."
                : "A workout is on your schedule today."
            content.sound = .default
            content.userInfo = ["local_destination": "workout_today"]
            let identifier = "liftrank-workout-session-\(batchID)-\(index)"
            try await center.add(UNNotificationRequest(
                identifier: identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: session.date), repeats: false)
            ))
            if requestRevision != revision {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                return
            }
        }
    }
}
