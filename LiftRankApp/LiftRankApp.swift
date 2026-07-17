import SwiftData
import SwiftUI

@main
struct LiftRankApp: App {
    private let modelContainer: ModelContainer
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
            let workoutStore = SwiftDataWorkoutPersistenceStore(context: container.mainContext)
            let forumStore = SwiftDataForumPersistenceStore(context: container.mainContext)
            _appState = StateObject(wrappedValue: AppState(repository: DemoRepository(
                workoutPersistenceStore: workoutStore,
                forumPersistenceStore: forumStore
            )))
        } catch {
            fatalError("Unable to create LiftRank's local data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
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
        .modelContainer(modelContainer)
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
