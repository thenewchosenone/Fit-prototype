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
    @ObservedObject private var account = SupabaseMobileSync.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !account.isBusy
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 72)

                    ZStack {
                        Circle()
                            .fill(Color.liftBlue.opacity(0.14))
                            .frame(width: 104, height: 104)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(Color.liftBlue)
                    }

                    VStack(spacing: 8) {
                        Text("Lift Rivals")
                            .font(.largeTitle.bold())
                        Text(isCreatingAccount ? "Create your shared app and website account." : "Use the same account on mobile and the web.")
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        TextField("Email address", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
                            .padding(16)
                            .background(Color.liftCard, in: RoundedRectangle(cornerRadius: 16))

                        SecureField("Password", text: $password)
                            .textContentType(isCreatingAccount ? .newPassword : .password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit { authenticate() }
                            .padding(16)
                            .background(Color.liftCard, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if let error = account.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Authentication error: (error)")
                    } else if let status = account.statusMessage {
                        Label(status, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftGreen)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: authenticate) {
                        HStack {
                            if account.isBusy {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(account.isBusy ? "Connecting..." : (isCreatingAccount ? "Create account" : "Sign in"))
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                    .foregroundStyle(.black)
                    .disabled(!canSubmit)

                    Button(isCreatingAccount ? "Already have an account? Sign in" : "New to Lift Rivals? Create an account") {
                        isCreatingAccount.toggle()
                        focusedField = .email
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.liftBlue)
                    .frame(minHeight: 44)

                    Button("Continue offline") {
                        appState.showingAuthentication = false
                    }
                    .foregroundStyle(Color.liftMuted)
                    .frame(minHeight: 44)

                    Text("Profile and completed workout data sync only after successful Supabase authentication. Offline activity remains on this device.")
                        .font(.footnote)
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { focusedField = .email }
    }

    private func authenticate() {
        guard canSubmit else { return }
        Task {
            let succeeded: Bool
            if isCreatingAccount {
                succeeded = await account.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    repository: appState.repository
                )
            } else {
                succeeded = await account.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    repository: appState.repository
                )
            }
            if succeeded {
                appState.showingAuthentication = false
                Haptics.success()
            }
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
                        ForEach(["Incorrect weight", "Duplicate submission", "Edited or unclear video", "Incorrect exercise"], id: .self) {
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
