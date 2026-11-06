import AuthenticationServices
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct LiftRankApp: App {
    @UIApplicationDelegateAdaptor(LiftRankApplicationDelegate.self) private var applicationDelegate
    private let modelContainer: ModelContainer?
    private let localDataError: String?
    @State private var onboardingInProgress = false
    @StateObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("liftrank.appearance") private var appearanceValue = LiftAppearance.system.rawValue

    init() {
        do {
            let container = try ModelContainer(
                for: PersistentLiftRecord.self,
                PersistentSettings.self,
                PersistentWorkoutRecord.self,
                PersistentWorkoutState.self
            )
            modelContainer = container
            let workoutStore = SwiftDataWorkoutPersistenceStore(context: ModelContext(container))
            let repository = DemoRepository(workoutPersistenceStore: workoutStore)
            localDataError = workoutStore.loadError
            _appState = StateObject(wrappedValue: AppState(repository: repository))
        } catch {
            modelContainer = nil
            localDataError = error.localizedDescription
            _appState = StateObject(wrappedValue: AppState(repository: DemoRepository()))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let localDataError {
                LocalDataRecoveryView(details: localDataError)
                    .preferredColorScheme(LiftAppearance(rawValue: appearanceValue)?.colorScheme)
            } else if let modelContainer {
                accountRoot
                    .modelContainer(modelContainer)
                    .preferredColorScheme(LiftAppearance(rawValue: appearanceValue)?.colorScheme)
            } else {
                LocalDataRecoveryView(details: nil)
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
            case .needsOnboarding, .needsLegalAcceptance:
                if onboardingInProgress || appState.accountStatus == .needsOnboarding {
                    OnboardingView {}
                        .onAppear { onboardingInProgress = true }
                } else {
                    LegalAcceptanceView(onBack: {
                        Task { await appState.signOutAccount() }
                    }, backTitle: "Back to sign in")
                }
            case .authenticated, .demo, .guest:
                MainTabView(router: appState.router)
            }
        }
        .environmentObject(appState)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if appState.notificationDestinationLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Opening notification…")
                            .font(.caption)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color.liftCard)
                    .accessibilityIdentifier("notification.destination.loading")
                }
                if let saveError = appState.repository.workoutSaveError,
                   appState.workoutCompletionError == nil {
                    HStack(spacing: 12) {
                        Text(saveError)
                            .font(.caption)
                        Spacer(minLength: 0)
                        Button("Retry") { appState.persistLocalWorkoutSnapshot() }
                            .font(.caption.weight(.bold))
                    }
                    .padding(12)
                    .background(Color.liftCard)
                    .accessibilityIdentifier("workout.save.error")
                }
                if let friendActivityShareError = appState.friendActivityShareError {
                    HStack(spacing: 12) {
                        Text(friendActivityShareError)
                            .font(.caption)
                        Spacer(minLength: 0)
                        Button("Retry") { Task { await appState.retryFriendActivityShares() } }
                            .font(.caption.weight(.bold))
                    }
                    .padding(12)
                    .background(Color.liftCard)
                    .accessibilityIdentifier("friend.activity.share.error")
                }
            }
        }
        .onAppear { openPendingNotificationDestination() }
        .onChange(of: appState.accountStatus) { _, status in
            appState.refreshWorkoutDayReminders()
            if status != .needsOnboarding && status != .needsLegalAcceptance {
                onboardingInProgress = false
            }
            openPendingNotificationDestination()
        }
        .task { await appState.restoreAccount() }
        .onOpenURL { url in Task { await appState.handleAuthCallback(url) } }
        .sheet(isPresented: $appState.showingPasswordUpdate) {
            PasswordUpdateView().environmentObject(appState)
        }
        .alert("Notification unavailable", isPresented: Binding(
            get: { appState.notificationNavigationMessage != nil },
            set: { if !$0 { appState.notificationNavigationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.notificationNavigationMessage = nil }
        } message: {
            Text(appState.notificationNavigationMessage ?? "This destination is no longer available.")
        }
        .onChange(of: appState.repository.programDataRevision) { appState.refreshWorkoutDayReminders() }
        .onChange(of: appState.completedWorkoutsRevision) { appState.refreshWorkoutDayReminders() }
        .onChange(of: appState.selectedWorkoutPlanID) { appState.refreshWorkoutDayReminders() }
        .onReceive(NotificationCenter.default.publisher(for: .liftRankOpenNotificationDestination)) { _ in
            openPendingNotificationDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: .liftRankDidReceivePushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await appState.registerPushToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .liftRankNotificationReceived)) { _ in
            guard appState.isAuthenticated, !appState.isDemoMode else { return }
            Task { await appState.notificationStore.refreshProductionData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .liftRankPushRegistrationFailed)) { _ in
            appState.pushRegistrationError = "Couldn’t connect notifications. Try again in Settings."
        }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
            Task { await appState.handleAppleCredentialRevoked() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    async let historyRefresh: Void = appState.synchronizeCompletedWorkoutHistory(force: false)
                    async let planRefresh: Void = appState.synchronizeWorkoutPlans(force: false)
                    _ = await (historyRefresh, planRefresh)
                    appState.refreshWorkoutDayReminders()
                    await appState.requestPushRegistrationIfNeeded()
                    await appState.retryFriendActivityShares()
                }
            } else {
                appState.persistLocalWorkoutSnapshotIfChanged()
            }
        }
    }

    private func openPendingNotificationDestination() {
        switch appState.accountStatus {
        case .authenticated, .demo, .guest: break
        default: return
        }
        guard let pending = LiftRankApplicationDelegate.pendingDestination else { return }
        if let recipientID = pending.recipientID,
           recipientID != appState.currentProfile.id {
            LiftRankApplicationDelegate.pendingDestination = nil
            return
        }
        LiftRankApplicationDelegate.pendingDestination = nil
        appState.openNotificationDestination(pending.destination)
    }
}

final class LiftRankApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static var pendingDestination: (destination: NotificationDestination, recipientID: UUID?)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .liftRankDidReceivePushToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
#if !DEBUG && !targetEnvironment(simulator)
        NotificationCenter.default.post(name: .liftRankPushRegistrationFailed, object: nil)
#endif
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let isWorkoutToday = userInfo["local_destination"] as? String == "workout_today"
        let isActiveWorkout = userInfo["local_destination"] as? String == "active_workout"
        let recipientID = (userInfo["recipient_id"] as? String).flatMap(UUID.init(uuidString:))
        let destinationData = userInfo["destination"].flatMap { payload in
            JSONSerialization.isValidJSONObject(payload) ? try? JSONSerialization.data(withJSONObject: payload) : nil
        }
        await MainActor.run {
            if isWorkoutToday {
                Self.pendingDestination = (NotificationDestination(kind: .workoutTracker), nil)
            } else if isActiveWorkout {
                Self.pendingDestination = (NotificationDestination(kind: .activeWorkout), nil)
            } else if let destinationData,
                      let destination = try? JSONDecoder().decode(NotificationDestination.self, from: destinationData) {
                Self.pendingDestination = (destination, recipientID)
            } else {
                return
            }
            NotificationCenter.default.post(name: .liftRankOpenNotificationDestination, object: nil)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == "liftrank-active-rest-timer" {
            if await center.notificationSettings().soundSetting == .enabled {
                await MainActor.run { WorkoutRestTimerAlertSound.shared.play() }
            }
            return [.banner]
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .liftRankNotificationReceived, object: nil)
        }
        return []
    }
}

extension Notification.Name {
    static let liftRankOpenNotificationDestination = Notification.Name("LiftRankOpenNotificationDestination")
    static let liftRankDidReceivePushToken = Notification.Name("LiftRankDidReceivePushToken")
    static let liftRankNotificationReceived = Notification.Name("LiftRankNotificationReceived")
    static let liftRankPushRegistrationFailed = Notification.Name("LiftRankPushRegistrationFailed")
}

private struct LocalDataRecoveryView: View {
    let details: String?

    var body: some View {
        AppBackground {
            ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.liftGold)
                Text("Local data is unavailable")
                    .font(.title2.bold())
                Text("Lift Rivals could not safely open its on-device database. Close and reopen the app. If the problem continues, contact support before reinstalling so your local training history is not erased.")
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)
                Link("Contact support", destination: URL(string: "https://liftrivals.com/support/")!)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                if let details {
                    DisclosureGroup("Technical details") {
                        Text(details).font(.caption).foregroundStyle(Color.liftMuted).textSelection(.enabled)
                    }
                }
            }
            .padding(28)
            }
        }
    }
}

private struct AccountLoadingView: View {
    var body: some View {
        AppBackground {
            VStack(spacing: 16) {
                ProgressView().tint(Color.liftAccentText)
                Text("Restoring your Lift Rivals account…").foregroundStyle(Color.liftMuted)
            }
        }
    }
}
