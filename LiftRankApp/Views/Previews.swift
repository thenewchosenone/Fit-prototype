import SwiftUI

#Preview("Home") {
    NavigationStack {
        HomeView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Leaderboards") {
    NavigationStack {
        LeaderboardsView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Submit Lift") {
    SubmitLiftView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Community") {
    NavigationStack {
        CommunityView()
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Profile") {
    NavigationStack {
        ProfileView(profile: MockData.demoProfile, isCurrentUser: true)
    }
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Training Tracker") {
    TrainingTrackerView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
