import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct LiftRankApp: App {
    @UIApplicationDelegateAdaptor(LiftRankApplicationDelegate.self) private var applicationDelegate
    private let modelContainer: ModelContainer?
    private let localDataError: String?
    @StateObject private var appState: AppState
    @AppStorage("liftrank.appearance") private var appearanceValue = LiftAppearance.system.rawValue

    init() {
        do {
            let container = try ModelContainer(
                for: PersistentLiftRecord.self,
                PersistentSettings.self,
                PersistentWorkoutRecord.self,
                PersistentWorkoutState.self,
                PersistentForumState.self
            )
            modelContainer = container
            localDataError = nil
            let workoutStore = SwiftDataWorkoutPersistenceStore(context: container.mainContext)
            let forumStore = SwiftDataForumPersistenceStore(context: container.mainContext)
            _appState = StateObject(wrappedValue: AppState(repository: DemoRepository(
                workoutPersistenceStore: workoutStore,
                forumPersistenceStore: forumStore
            )))
        } catch {
            modelContainer = nil
            localDataError = error.localizedDescription
            _appState = StateObject(wrappedValue: AppState(repository: DemoRepository()))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                accountRoot
                    .modelContainer(modelContainer)
                    .preferredColorScheme(LiftAppearance(rawValue: appearanceValue)?.colorScheme)
            } else {
                LocalDataRecoveryView(details: localDataError)
                    .preferredColorScheme(LiftAppearance(rawValue: appearanceValue)?.colorScheme)
            }
        }
    }

    private var accountRoot: some View {
        Group {
            switch appState.accountStatus {
            case .restoring:
                AccountLoadingView()
            case .signedOut, .configurationRequired, .failure:
                AuthenticationView()
            case .needsOnboarding:
                OnboardingView {}
            case .needsLegalAcceptance:
                LegalAcceptanceView()
            case .authenticated, .demo:
                MainTabView(router: appState.router)
            }
        }
        .environmentObject(appState)
        .task { await appState.restoreAccount() }
        .onOpenURL { url in Task { await appState.handleAuthCallback(url) } }
        .sheet(isPresented: $appState.showingPasswordUpdate) {
            PasswordUpdateView().environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .liftRankDidReceivePushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await appState.registerPushToken(token) }
        }
    }
}

final class LiftRankApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .liftRankDidReceivePushToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulator and unsigned builds have no APNs entitlement. In-app
        // notifications continue to work without presenting a false error.
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

extension Notification.Name {
    static let liftRankDidReceivePushToken = Notification.Name("LiftRankDidReceivePushToken")
}

private struct LocalDataRecoveryView: View {
    let details: String?

    var body: some View {
        AppBackground {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.liftGold)
                Text("Local data is unavailable")
                    .font(.title2.bold())
                Text("LiftRank could not safely open its on-device database. Close and reopen the app. If the problem continues, contact support before reinstalling so your local training history is not erased.")
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)
                if let details {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Technical details: \(details)")
                }
            }
            .padding(28)
        }
    }
}

private struct AccountLoadingView: View {
    var body: some View {
        AppBackground {
            VStack(spacing: 16) {
                ProgressView().tint(Color.liftBlue)
                Text("Restoring your LiftRank account…").foregroundStyle(Color.liftMuted)
            }
        }
    }
}
