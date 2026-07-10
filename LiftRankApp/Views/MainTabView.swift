import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                LeaderboardsView()
            }
            .tabItem { Label("Leaderboards", systemImage: "list.number") }
            .tag(1)

            NavigationStack {
                SubmitLiftLauncherView()
            }
            .tabItem { Label("Submit", systemImage: "plus.circle.fill") }
            .tag(2)

            NavigationStack {
                CommunityView()
            }
            .tabItem { Label("Community", systemImage: "person.3.fill") }
            .tag(3)

            NavigationStack {
                ProfileView(profile: appState.currentProfile, isCurrentUser: true)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
            .tag(4)
        }
        .tint(Color.liftBlue)
        .sheet(isPresented: $appState.showingSubmitSheet) {
            SubmitLiftView()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $appState.showingLeaderboardFilters) {
            LeaderboardFiltersView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $appState.showingEditProfile) {
            EditProfileView()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $appState.showingModeratorReview) {
            ModeratorReviewView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showingTrainingTracker, onDismiss: {
            appState.trainingTrackerStartOnProgress = false
        }) {
            TrainingTrackerView(startOnProgress: appState.trainingTrackerStartOnProgress)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showingCreateThread) {
            CreateThreadView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $appState.showingRequestGym) {
            RequestGymView()
                .environmentObject(appState)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $appState.showingReportLift) {
            ReportLiftView()
                .presentationDetents([.medium])
        }
        .sheet(item: $appState.selectedProfile) { profile in
            NavigationStack {
                ProfileView(profile: profile, isCurrentUser: profile.id == appState.currentProfile.id)
            }
            .environmentObject(appState)
        }
        .sheet(item: $appState.selectedGym) { gym in
            NavigationStack {
                GymDetailView(gym: gym)
            }
            .environmentObject(appState)
        }
        .sheet(item: $appState.selectedMessageThread) { thread in
            DirectMessageThreadView(thread: thread)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .sheet(item: $appState.selectedCommunityThread) { thread in
            CommunityThreadDetailView(thread: thread)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .sheet(item: $appState.selectedActivity) { activity in
            ActivityDetailView(activity: activity)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $appState.showingAuthentication) {
            AuthenticationView()
                .environmentObject(appState)
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBackground {
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.liftBlue)
                Text("LiftRank")
                    .font(.largeTitle.bold())
                Text("Demo mode runs locally without Supabase credentials.")
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Continue in Demo Mode", symbolName: "person.crop.circle.badge.checkmark") {
                    appState.showingAuthentication = false
                    Haptics.success()
                }
                Spacer()
            }
            .padding()
        }
    }
}

struct ReportLiftView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Incorrect weight"
    @State private var note = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Picker("Reason", selection: $reason) {
                        ForEach(["Incorrect weight", "Duplicate submission", "Edited or unclear video", "Incorrect exercise"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                    Button("Submit Report") {
                        Haptics.warning()
                        dismiss()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report Lift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SubmitLiftLauncherView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBackground {
            VStack(spacing: 20) {
                Spacer()
                Button {
                    Haptics.light()
                    appState.showingSubmitSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 92, weight: .semibold))
                        .foregroundStyle(Color.liftBlue)
                        .accessibilityLabel("Submit a lift")
                }
                Text("Submit a Lift")
                    .font(.largeTitle.bold())
                Text("Log a major lift, estimate your max, and see where it lands.")
                    .font(.body)
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .navigationTitle("Submit")
        }
    }
}
