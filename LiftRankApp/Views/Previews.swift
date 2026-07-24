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

#Preview("Anatomy Matrix") {
    AnatomyPreviewMatrix()
        .preferredColorScheme(.dark)
}

private struct AnatomyPreviewMatrix: View {
    private let profiles: [(String, ExerciseMuscleProfile)] = [
        ("Chest", .init(primary: [.chest], secondary: [.frontDelts, .triceps], orientation: .front)),
        ("Back", .init(primary: [.lats, .upperBack], secondary: [.rearDelts, .biceps], orientation: .back)),
        ("Core", .init(primary: [.abs, .obliques], secondary: [], orientation: .front)),
        ("Glutes", .init(primary: [.glutes], secondary: [.hamstrings], orientation: .back)),
        ("Quads", .init(primary: [.quads], secondary: [.glutes, .adductors], orientation: .split)),
        ("Full body", .init(primary: [.fullBody], secondary: [], orientation: .split))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(profiles, id: \.0) { name, profile in
                    VStack(spacing: 8) {
                        ExerciseMuscleMap(profile: profile)
                            .frame(height: 190)
                        Text(name)
                            .font(.caption.weight(.bold))
                    }
                }
            }
            .padding()
        }
        .background(Color.liftBackground)
    }
}
