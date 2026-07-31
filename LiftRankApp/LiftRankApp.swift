import Combine
import SwiftData
import SwiftUI

@main
struct LiftRankApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var account = SupabaseMobileSync.shared
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .task {
                    await account.restore(into: appState.repository)
                }
                .onReceive(
                    appState.repository.objectWillChange
                        .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
                ) { _ in
                    guard account.isAuthenticated else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        await account.pushCurrentState(from: appState.repository)
                    }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !didCompleteOnboarding },
                    set: { isPresented in
                        if !isPresented { didCompleteOnboarding = true }
                    }
                )) {
                    OnboardingView {
                        didCompleteOnboarding = true
                    }
                    .environmentObject(appState)
                }
        }
        .modelContainer(for: [PersistentLiftRecord.self, PersistentSettings.self, PersistentWorkoutRecord.self])
    }
}
