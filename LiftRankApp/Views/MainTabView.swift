import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var router: AppRouter

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                NavigationStack { HomeView() }
                    .tag(AppTab.home)
                NavigationStack { LeaderboardsView() }
                    .tag(AppTab.leaderboards)
                TrainingTrackerView(
                    startOnProgress: appState.trainingTrackerStartOnProgress,
                    isEmbeddedInTab: true
                )
                .tag(AppTab.track)
                NavigationStack { MeHubView(router: router) }
                    .tag(AppTab.profile)
            }
            .toolbar(.hidden, for: .tabBar)
            .ignoresSafeArea(.keyboard)
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar(
                    selection: $router.selectedTab,
                    items: tabItems,
                    utilityAction: {
                        appState.showingSubmitSheet = true
                    }
                )
                .padding(.bottom, 12)
            }
        }
        .tint(Color.liftLime)
        .sheet(item: $router.sheet) { destination in
            appSheet(destination)
        }
        .fullScreenCover(item: $router.cover) { destination in
            switch destination {
            case .authentication:
                AuthenticationView().environmentObject(appState)
            }
        }
    }

    private var tabItems: [FloatingTabItem] {
        var items: [FloatingTabItem] = [
            .init(tab: .home, icon: "house.fill", title: "Home", isUtility: false),
            .init(tab: .leaderboards, icon: "trophy.fill", title: "Leaderboards", isUtility: false),
            .init(tab: .track, icon: "dumbbell.fill", title: "Track", isUtility: false),
        ]

        items.append(.init(tab: .profile, icon: "person.crop.circle.fill", title: "Me", isUtility: false))

        let middle = items.count / 2
        items.insert(.init(tab: nil, icon: "plus", title: "Quick log", isUtility: true), at: middle)
        return items
    }

    @ViewBuilder
    private func appSheet(_ destination: AppSheet) -> some View {
        switch destination {
        case .submitLift:
            SubmitLiftView().environmentObject(appState).presentationDetents([.large])
        case .leaderboardFilters:
            LeaderboardFiltersView().environmentObject(appState).presentationDetents([.medium, .large])
        case .editProfile:
            EditProfileView().environmentObject(appState).presentationDetents([.large])
        case .moderatorReview:
            ModeratorReviewView().environmentObject(appState)
        case .settings:
            SettingsView().environmentObject(appState)
        case .requestGym:
            RequestGymView().environmentObject(appState).presentationDetents([.medium])
        case .reportLift(let lift):
            ReportLiftView(lift: lift).environmentObject(appState).presentationDetents([.medium])
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

struct MeHubView: View {
    @ObservedObject var router: AppRouter

    @ViewBuilder
    var body: some View {
        if router.selectedTab == .profile {
            MeHubContentView()
        } else {
            AppBackground {
                Color.clear
            }
        }
    }
}

private struct MeHubContentView: View {
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
                                Text("\(appState.earnedExperienceLevel.rawValue) lifter")
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

                    ProfileLiftVideosSection(profile: appState.currentProfile, isCurrentUser: true)

                    CompactSectionHeader(title: "Your Lift Rivals")
                    VStack(spacing: 0) {
                        NavigationLink {
                            AwardsView()
                        } label: {
                            meRow("Rival tier & awards", "Strength milestones, records, and progress", "trophy.fill", Color.liftGold,
                                  badge: appState.strengthTierSummary.overallTier.label)
                        }
                        .accessibilityIdentifier("me.awards")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink {
                            ProfileView(profile: appState.currentProfile, isCurrentUser: true)
                        } label: {
                            meRow("Public athlete profile", "Rankings, lifts, and profile identity", "person.text.rectangle.fill", Color.liftBlue)
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
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Color.liftText)
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
    @State private var rivalTierShareImage: Image?

    var body: some View {
        let tierSummary = appState.strengthTierSummary
        let achievements = appState.achievements
        let unlockedTitles = Set(appState.achievementUnlocks.map(\.title))
        let unlockedAchievements = achievements.filter { unlockedTitles.contains($0.title) }
        let progressAchievements = achievements.filter { !unlockedTitles.contains($0.title) }
        let preferredUnit = appState.currentProfile.preferredUnit
        let bestStrengthLifts = appState.bestStrengthLifts
        let bestBench = bestStrengthLifts["bench"]
        let bestSquat = bestStrengthLifts["squat"]
        let bestDeadlift = bestStrengthLifts["deadlift"]
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LIFT RIVALS AWARDS")
                            .font(.caption.weight(.black)).tracking(1.4)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(unlockedAchievements.count)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                            Text("unlocked").font(.headline)
                        }
                        ProgressView(value: Double(unlockedAchievements.count), total: Double(max(1, achievements.count)))
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

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RIVAL TIER")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.liftGold)
                                Text(tierSummary.overallTier.label)
                                    .font(.title.weight(.black))
                            }
                            Spacer()
                            Image(systemName: "medal.fill")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.liftGold)
                        }

                        Text(tierSummary.completedRequiredLiftCount == tierSummary.requiredLiftCount
                             ? "Your tier is the highest level reached across squat, bench, and deadlift."
                             : "Log completed working sets for all three lifts to unlock your starting tier.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)

                        ForEach(tierSummary.liftProgress) { lift in
                            strengthLiftRow(lift, preferredUnit: preferredUnit)
                        }
                    }
                    .padding(18)
                    .liftSurface()

                    if let rivalTierShareImage {
                        ShareLink(
                            item: rivalTierShareImage,
                            preview: SharePreview(
                                "\(appState.currentProfile.displayName)'s Rival Tier",
                                image: rivalTierShareImage
                            )
                        ) {
                            Label("Share Rival Tier card", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    } else {
                        Button {
                            prepareRivalTierShareImage(summary: tierSummary)
                        } label: {
                            Label("Prepare Rival Tier card", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Unlocked awards (\(unlockedAchievements.count))")
                        if unlockedAchievements.isEmpty {
                            LiftEmptyState(title: "No awards yet", message: "Complete workouts and log lifts to unlock your first award.", symbolName: "sparkles")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(unlockedAchievements) { achievement in
                                    awardTile(achievement, unlocked: true)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Personal records")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            personalRecord("Bench", best: bestBench, preferredUnit: preferredUnit)
                            personalRecord("Squat", best: bestSquat, preferredUnit: preferredUnit)
                            personalRecord("Deadlift", best: bestDeadlift, preferredUnit: preferredUnit)
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
                                Text("Total").font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
                                Text(MeasurementFormatting.formatDisplayedWeight(
                                    appState.powerliftingTotal,
                                    unit: preferredUnit
                                ))
                                .font(.headline.weight(.black))
                            }
                            .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Locked awards (\(progressAchievements.count))")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(progressAchievements) { awardTile($0, unlocked: false) }
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
        .onChange(of: tierSummary) { _, _ in
            rivalTierShareImage = nil
        }
    }

    private func prepareRivalTierShareImage(summary: StrengthTierSummary) {
        let renderer = ImageRenderer(content: RivalTierShareCard(
            profile: appState.currentProfile,
            summary: summary,
            preferredUnit: appState.currentProfile.preferredUnit
        ))
        renderer.scale = 2
        rivalTierShareImage = renderer.uiImage.map(Image.init(uiImage:))
    }

    private func strengthLiftRow(_ lift: LiftTierProgress, preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(lift.exerciseName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(lift.estimatedOneRepMaxKilograms == nil ? "Not logged" : lift.currentTier.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(lift.estimatedOneRepMaxKilograms == nil ? Color.liftMuted : Color.liftGold)
            }
            ProgressView(value: lift.progressToNextTier)
                .tint(.liftGold)
            HStack {
                Text(lift.estimatedOneRepMaxKilograms.map {
                    "Est. 1RM \(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))"
                } ?? "Complete a set of 10 reps or fewer")
                Spacer()
                if let nextTier = lift.nextTier, let threshold = lift.nextThresholdMultiple {
                    Text("\(RankingCalculator.format(threshold))× BW to \(nextTier.label)")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liftMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func personalRecord(_ title: String, best: LiftSubmission?, preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "trophy.fill").foregroundStyle(Color.liftGold)
            Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(best.map {
                MeasurementFormatting.formatDisplayedWeight(
                    $0.normalizedWeightKilograms,
                    unit: preferredUnit
                )
            } ?? "—")
                .font(.headline.weight(.black))
            Text(best == nil ? "No PR yet" : "Best logged lift").font(.caption).foregroundStyle(Color.liftMuted)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardTile(_ achievement: Achievement, unlocked: Bool) -> some View {
        let display = awardDisplay(for: achievement)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(unlocked ? Color.liftGold : Color.liftMuted)
            Text(display.title).font(.subheadline.weight(.bold)).foregroundStyle(unlocked ? Color.liftText : Color.liftMuted).lineLimit(2)
            Text(unlocked ? "Unlocked" : "Keep progressing").font(.caption2.weight(.semibold)).foregroundStyle(Color.liftMuted)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardDisplay(for achievement: Achievement) -> Achievement {
        var display = achievement
        let unit = appState.currentProfile.preferredUnit
        if let liftMilestone = liftAwardMilestone(for: achievement.title) {
            let formattedWeight = formattedAwardWeight(pounds: liftMilestone.pounds, unit: unit)
            display.title = "\(formattedWeight) \(liftMilestone.exercise)"
            display.description = "\(liftMilestone.exercise) \(formattedWeight.lowercased())."
        } else if let totalPounds = totalAwardPounds(for: achievement.title) {
            let formattedTotal = formattedAwardWeight(pounds: totalPounds, unit: unit)
            display.title = "\(formattedTotal) Total"
            display.description = "Build a \(formattedTotal) bench, squat, and deadlift total."
        } else if let volumeKilograms = volumeAwardKilograms(for: achievement.title) {
            let formattedVolume = formattedAwardWeight(kilograms: volumeKilograms, unit: unit)
            display.title = "\(formattedVolume) Lifted Volume"
            display.description = "Move \(formattedVolume) of lifted working-set volume."
        }
        return display
    }

    private func formattedAwardWeight(pounds: Double, unit: UnitSystem) -> String {
        formattedAwardWeight(kilograms: RankingCalculator.poundsToKilograms(pounds), unit: unit)
    }

    private func formattedAwardWeight(kilograms: Double, unit: UnitSystem) -> String {
        MeasurementFormatting.formatDisplayedWeight(kilograms, unit: unit) { value in
            Int(value.rounded()).formatted()
        }
    }

    private func liftAwardMilestone(for title: String) -> (pounds: Double, exercise: String)? {
        for exercise in ["Bench", "Squat", "Deadlift"] where title.hasSuffix(" \(exercise)") {
            let valueText = title.replacingOccurrences(of: " \(exercise)", with: "").replacingOccurrences(of: ",", with: "")
            guard let pounds = Double(valueText) else { return nil }
            return (pounds, exercise)
        }
        return nil
    }

    private func totalAwardPounds(for title: String) -> Double? {
        guard title.hasSuffix(" lb Total") else { return nil }
        let valueText = title
            .replacingOccurrences(of: " lb Total", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(valueText)
    }

    private func volumeAwardKilograms(for title: String) -> Double? {
        let suffix = title.hasSuffix(" kg Lifted Volume")
            ? " kg Lifted Volume"
            : title.hasSuffix(" kg Volume") ? " kg Volume" : nil
        guard let suffix else { return nil }
        let valueText = title.replacingOccurrences(of: suffix, with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(valueText)
    }
}

private struct RivalTierShareCard: View {
    let profile: UserProfile
    let summary: StrengthTierSummary
    let preferredUnit: UnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIFT RIVALS")
                        .font(.system(size: 18, weight: .black))
                        .tracking(3)
                        .foregroundStyle(Color.liftGold)
                    Text(profile.displayName)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("@\(profile.username)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "medal.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color.liftGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RIVAL TIER")
                    .font(.system(size: 16, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(summary.overallTier.label)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 14) {
                ForEach(summary.liftProgress) { lift in
                    HStack(spacing: 14) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.liftGold)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lift.exerciseName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                            Text(lift.estimatedOneRepMaxKilograms.map {
                                "Est. 1RM \(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))"
                            } ?? "Not logged")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }
                        Spacer()
                        Text(lift.currentTier.label)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.liftGold)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Spacer()
            Text("TRAIN. PROVE. RISE.")
                .font(.system(size: 15, weight: .black))
                .tracking(2.5)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(42)
        .frame(width: 540, height: 675)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.09, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingReset = false
    @State private var appleNonce = ""
    @State private var confirmationEmail: String?

    private let emailConfirmationMessage = "Check your email to confirm your account, then sign in."

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 46)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Color.liftBlue)
                    Text("Lift Rivals").font(.largeTitle.bold())
                    Text("Your training can stay local. Your profile and gyms use your secured account.")
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

                        if let confirmationEmail {
                            emailConfirmationNotice(for: confirmationEmail)
                        } else if let message = appState.accountMessage {
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
                                    if appState.accountMessage == emailConfirmationMessage {
                                        confirmationEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                        password = ""
                                        mode = "Sign In"
                                    }
                                }
                            }
                        }
                        .disabled(appState.accountOperationInProgress || email.isEmpty || password.count < 10)

#if DEBUG
                        Label("Apple sign-in is enabled in the release build", systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity)
#else
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
#endif

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
                    Text("For privacy, Lift Rivals gives the same response whether or not an account exists.")
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

    private func emailConfirmationNotice(for email: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Confirmation email sent", systemImage: "envelope.badge.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftBlue)

            Text("We sent a confirmation link to")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)

            Text(email)
                .font(.subheadline.weight(.bold))
                .textSelection(.enabled)

            Text("Open the email, tap the link, then return here to sign in. Check spam if it does not arrive within a few minutes.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liftBlue.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liftBlue.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PasswordUpdateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New password", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Confirm password", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    Text("Use at least 10 characters.")
                }
                if let message = appState.accountMessage {
                    Text(message).foregroundStyle(Color.liftMuted)
                }
                Button(appState.accountOperationInProgress ? "Updating…" : "Update password") {
                    Task { await appState.updatePassword(password) }
                }
                .disabled(
                    appState.accountOperationInProgress ||
                    password.count < 10 ||
                    password != confirmation
                )
            }
            .navigationTitle("Choose New Password")
        }
        .interactiveDismissDisabled()
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
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let lift: LiftSubmission
    @State private var reason = LiftReportReason.incorrectWeight
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Picker("Reason", selection: $reason) {
                        ForEach(LiftReportReason.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.liftRed)
                    }
                    Button(isSubmitting ? "Submitting…" : "Submit Report") {
                        isSubmitting = true
                        errorMessage = nil
                        Task {
                            if await appState.competitionStore.report(lift, reason: reason, note: note) {
                                Haptics.warning()
                                dismiss()
                            } else {
                                errorMessage = "The report could not be submitted. Try again."
                                isSubmitting = false
                            }
                        }
                    }
                    .accessibilityIdentifier("report.submit")
                    .disabled(isSubmitting)
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
