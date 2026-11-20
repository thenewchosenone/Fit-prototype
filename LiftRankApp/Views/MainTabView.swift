import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var router: AppRouter
    @State private var mePath: [MeRoute] = []

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack { HomeView(isActiveTab: router.selectedTab == .home) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { LeaderboardsView(isActiveTab: router.selectedTab == .leaderboards) }
                .tabItem { Label("Rankings", systemImage: "trophy.fill") }
                .tag(AppTab.leaderboards)
            TrainingTrackerView(
                startOnProgress: appState.trainingTrackerStartOnProgress,
                isEmbeddedInTab: true,
                isActiveTab: router.selectedTab == .track
            )
                .tabItem { Label("Track", systemImage: "dumbbell.fill") }
                .tag(AppTab.track)
            if appState.features.forum {
                NavigationStack { ForumView().environmentObject(appState) }
                    .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(AppTab.forum)
            }
            NavigationStack(path: $mePath) { meTabContent }
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(Color.liftAccentText)
        .sheet(item: $router.sheet) { destination in
            appSheet(destination)
        }
        .fullScreenCover(item: $router.cover) { destination in
            switch destination {
            case .authentication:
                AuthenticationView().environmentObject(appState)
            case .activeWorkout:
                WorkoutSessionRunView().environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private var meTabContent: some View {
        MeHubContentView()
        .navigationDestination(for: MeRoute.self) { route in
            switch route {
            case .publicProfile:
                ProfileView(profile: appState.currentProfile, surface: .public, viewerID: UUID(), showsDismissButton: false)
            case .personalProfile(let section):
                ProfileView(profile: appState.currentProfile, surface: .personal, initialSection: section)
            case .awards:
                AwardsView()
            case .gyms:
                GymDirectoryView()
            }
        }
    }

    @ViewBuilder
    private func appSheet(_ destination: AppSheet) -> some View {
        switch destination {
        case .friendRequests:
            NavigationStack { FriendRequestsView().environmentObject(appState) }
        case .submitLift:
            SubmitLiftView().environmentObject(appState).presentationDetents([.large])
        case .leaderboardFilters:
            LeaderboardFiltersView().environmentObject(appState).presentationDetents([.large])
        case .editProfile:
            EditProfileView().environmentObject(appState).presentationDetents([.large])
        case .moderatorReview:
            ModeratorReviewView().environmentObject(appState)
        case .settings(let section):
            SettingsView(initialSection: section).environmentObject(appState)
        case .requestGym:
            RequestGymView().environmentObject(appState).presentationDetents([.medium])
        case .recentPR(let lift):
            RecentPRDetailView(lift: lift)
                .environmentObject(appState)
                .presentationDetents([.large])
        case .reportLift(let lift):
            ReportLiftView(lift: lift).environmentObject(appState).presentationDetents([.medium])
        case .reportProfile(let profile):
            ReportProfileView(profile: profile).environmentObject(appState).presentationDetents([.medium])
        case .profile(let profile):
            NavigationStack {
                ProfileView(profile: profile, isCurrentUser: profile.id == appState.currentProfile.id)
            }
            .environmentObject(appState)
        case .gym(let gym):
            NavigationStack { GymDetailView(gym: gym) }.environmentObject(appState)
        }
    }
}
