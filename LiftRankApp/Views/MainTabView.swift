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

            TrainingTrackerView(
                startOnProgress: appState.trainingTrackerStartOnProgress,
                isEmbeddedInTab: true
            )
            .tabItem { Label("Track", systemImage: "dumbbell.fill") }
            .tag(2)

            NavigationStack(path: $appState.communityPath) {
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
        .toolbarBackground(Color.liftCard, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
        .fullScreenCover(isPresented: $appState.showingForumComposer, onDismiss: {
            appState.clearForumComposerPreset()
        }) {
            ForumRichComposerView()
                .environmentObject(appState)
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingReset = false

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 46)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Color.liftBlue)
                    Text("LiftRank").font(.largeTitle.bold())
                    Text("Your training can stay local. Your profile, gyms, and friendships use your secured account.")
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)

                    if appState.accountStatus == .configurationRequired {
                        Label("Account services are not configured in this development build.", systemImage: "wrench.and.screwdriver.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftGold)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Picker("Account action", selection: $mode) {
                            Text("Sign In").tag("Sign In")
                            Text("Create Account").tag("Create Account")
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(Color.liftCardRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            SecureField("Password", text: $password)
                                .textContentType(mode == "Sign In" ? .password : .newPassword)
                                .padding(14)
                                .background(Color.liftCardRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let message = appState.accountMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Please wait…" : mode,
                            symbolName: mode == "Sign In" ? "arrow.right.circle.fill" : "person.badge.plus"
                        ) {
                            Task {
                                if mode == "Sign In" {
                                    await appState.signIn(email: email, password: password)
                                } else {
                                    await appState.signUp(email: email, password: password)
                                }
                            }
                        }
                        .disabled(appState.accountOperationInProgress || email.isEmpty || password.count < 10)

                        Button("Forgot password?") { showingReset = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                    }

                    Divider().overlay(Color.white.opacity(0.08))
                    Button {
                        Task { await appState.enterDemoMode() }
                    } label: {
                        Label("Enter Explicit Demo Mode", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)
                    Text("Demo mode uses seeded local identities and never writes to your Supabase account.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                Form {
                    TextField("Account email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Text("For privacy, LiftRank gives the same response whether or not an account exists.")
                        .font(.caption)
                    Button("Send reset instructions") {
                        Task {
                            await appState.requestPasswordReset(email: email)
                            showingReset = false
                        }
                    }
                    .disabled(email.isEmpty || appState.accountOperationInProgress)
                }
                .navigationTitle("Reset Password")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingReset = false } }
                }
            }
            .presentationDetents([.medium])
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
