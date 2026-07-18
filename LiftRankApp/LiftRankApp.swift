import SwiftData
import SwiftUI

@main
struct LiftRankApp: App {
    private let modelContainer: ModelContainer?
    private let localDataError: String?
    @StateObject private var appState: AppState

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
            } else {
                LocalDataRecoveryView(details: localDataError)
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
            case .authenticated, .demo:
                MainTabView()
            }
        }
        .environmentObject(appState)
        .preferredColorScheme(.dark)
        .task { await appState.restoreAccount() }
    }
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
        .preferredColorScheme(.dark)
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
