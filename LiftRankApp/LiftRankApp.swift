import SwiftData
import SwiftUI

@main
struct LiftRankApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
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
