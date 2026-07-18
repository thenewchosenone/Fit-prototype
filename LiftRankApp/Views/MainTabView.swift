import AuthenticationServices
import CryptoKit
import Security
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
                MeHubView()
            }
            .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
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

struct MeHubView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LiftCard {
                        HStack(spacing: 16) {
                            ProfileAvatar(profile: appState.currentProfile, size: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.currentProfile.displayName)
                                    .font(.title2.weight(.black))
                                Text("@\(appState.currentProfile.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                Text("\(appState.currentProfile.experienceLevel.rawValue) lifter")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftBlue)
                            }
                            Spacer()
                            Button {
                                appState.showingEditProfile = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Edit athlete profile")
                        }
                    }

                    CompactSectionHeader(title: "Your LiftRank")
                    VStack(spacing: 0) {
                        NavigationLink {
                            AwardsView()
                        } label: {
                            meRow("Awards", "Milestones, records, and progress", "trophy.fill", Color.liftGold,
                                  badge: "\(appState.achievementUnlocks.count)")
                        }
                        .accessibilityIdentifier("me.awards")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink {
                            ProfileView(profile: appState.currentProfile, isCurrentUser: true)
                        } label: {
                            meRow("Public athlete profile", "Rankings, lifts, and community identity", "person.text.rectangle.fill", Color.liftBlue)
                        }
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        Button {
                            appState.trainingTrackerStartOnProgress = true
                            appState.requestedTrackerSegment = "Progress"
                            appState.selectedTab = 2
                        } label: {
                            meRow("Training history", "Workouts, bodyweight, and trends", "chart.xyaxis.line", Color.liftGreen)
                        }
                    }
                    .buttonStyle(.plain)
                    .liftSurface()

                    CompactSectionHeader(title: "Account")
                    VStack(spacing: 0) {
                        Button { appState.showingEditProfile = true } label: {
                            meRow("Athlete details", "Goals, identity, and privacy", "person.crop.circle.badge.checkmark", Color.liftBlue)
                        }
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        Button { appState.showingSettings = true } label: {
                            meRow("Settings", "Units, notifications, tracking, and safety", "gearshape.fill", Color.liftMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .liftSurface()
                }
                .padding(16)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Me")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { appState.showingSettings = true } label: { Image(systemName: "gearshape.fill") }
                    .accessibilityLabel("Open settings")
            }
        }
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, badge: String? = nil) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(2)
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.liftGold)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftMuted)
        }
        .padding(13)
        .contentShape(Rectangle())
    }
}

struct AwardsView: View {
    @EnvironmentObject private var appState: AppState

    private var unlockedTitles: Set<String> { Set(appState.achievementUnlocks.map(\.title)) }
    private var unlockedAchievements: [Achievement] { appState.achievements.filter { unlockedTitles.contains($0.title) } }
    private var progressAchievements: [Achievement] { appState.achievements.filter { !unlockedTitles.contains($0.title) } }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LIFTRANK AWARDS")
                            .font(.caption.weight(.black)).tracking(1.4)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(unlockedAchievements.count)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                            Text("unlocked").font(.headline)
                        }
                        ProgressView(value: Double(unlockedAchievements.count), total: Double(max(1, appState.achievements.count)))
                            .tint(.white)
                        Text("Celebrate consistent training, personal records, and ranking milestones.")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color.liftGold, Color.orange, Color.pink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Showcase")
                        if unlockedAchievements.isEmpty {
                            LiftEmptyState(title: "No awards yet", message: "Complete workouts and log lifts to unlock your first award.", symbolName: "sparkles")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(unlockedAchievements.prefix(3)) { achievement in
                                        awardTile(achievement, unlocked: true).frame(width: 168)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Personal records")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            personalRecord("Bench", exerciseID: "bench-press")
                            personalRecord("Squat", exerciseID: "back-squat")
                            personalRecord("Deadlift", exerciseID: "deadlift")
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
                                Text("Total").font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
                                Text("\(Int(appState.powerliftingTotal)) lb").font(.headline.weight(.black))
                            }
                            .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Progress awards")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(progressAchievements.prefix(12)) { awardTile($0, unlocked: false) }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Awards")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("awards.screen")
    }

    private func personalRecord(_ title: String, exerciseID: String) -> some View {
        let best = RankingCalculator.bestLift(exerciseID: exerciseID, submissions: appState.currentUserLifts)
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "trophy.fill").foregroundStyle(Color.liftGold)
            Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(best.map { "\(RankingCalculator.format($0.weight)) \($0.unit.shortLabel)" } ?? "—")
                .font(.headline.weight(.black))
            Text(best == nil ? "No PR yet" : "Best logged lift").font(.caption).foregroundStyle(Color.liftMuted)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardTile(_ achievement: Achievement, unlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(unlocked ? Color.liftGold : Color.liftMuted)
            Text(achievement.title).font(.subheadline.weight(.bold)).foregroundStyle(unlocked ? .white : Color.liftMuted).lineLimit(2)
            Text(unlocked ? "Unlocked" : "Keep progressing").font(.caption2.weight(.semibold)).foregroundStyle(Color.liftMuted)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingReset = false
    @State private var appleNonce = ""

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

                        SignInWithAppleButton(.continue) { request in
                            let nonce = AppleNonce.make()
                            appleNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = AppleNonce.sha256(nonce)
                        } onCompletion: { result in
                            guard case .success(let authorization) = result,
                                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                  let data = credential.identityToken,
                                  let token = String(data: data, encoding: .utf8),
                                  !appleNonce.isEmpty else {
                                appState.accountMessage = "Sign in with Apple could not be completed."
                                return
                            }
                            Task { await appState.signInWithApple(identityToken: token, nonce: appleNonce) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(appState.accountOperationInProgress)

                        Button("Forgot password?") { showingReset = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                    }

                    if AppState.allowsDemoMode {
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
                    }
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

private enum AppleNonce {
    static func make(length: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString }
        for byte in bytes { result.append(alphabet[Int(byte) % alphabet.count]) }
        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
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
