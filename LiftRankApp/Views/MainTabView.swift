import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

private func liftSymbol(for exerciseName: String) -> String {
    let normalized = exerciseName.lowercased()
    if normalized.contains("squat") { return "figure.strengthtraining.functional" }
    if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
    if normalized.contains("deadlift") { return "figure.strengthtraining.functional" }
    if normalized.contains("row") { return "figure.rower" }
    if normalized.contains("pulldown") || normalized.contains("pull-down") || normalized.contains("pullover") { return "figure.climbing" }
    if normalized.contains("curl") { return "figure.stand" }
    if normalized.contains("fly") || normalized.contains("rear delt") { return "figure.stand" }
    if normalized.contains("lateral raise") || normalized.contains("front raise") { return "figure.stand" }
    if normalized.contains("lunge") || normalized.contains("step-up") || normalized.contains("step up") { return "figure.walk" }
    if normalized.contains("calf raise") { return normalized.contains("seated") ? "figure.seated.side" : "figure.stand" }
    if normalized.contains("leg press") { return "figure.seated.side" }
    if normalized.contains("hip thrust") || normalized.contains("glute bridge") { return "figure.strengthtraining.functional" }
    if normalized.contains("shrug") { return "figure.stand" }
    if normalized.contains("overhead press") || normalized.contains("shoulder press") || normalized.contains("push press") || normalized.contains("arnold press") || normalized.contains("military press") {
        return "figure.stand"
    }
    if normalized.contains("push-up") || normalized.contains("push up") || normalized.contains("dip") {
        return "figure.strengthtraining.functional"
    }
    if normalized.contains("press") { return "figure.strengthtraining.traditional" }
    return "chart.line.uptrend.xyaxis"
}

private enum MeRoute: Hashable {
    case publicProfile
    case personalProfile
    case awards
    case gyms
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var router: AppRouter
    @State private var mePath: [MeRoute] = []
    @State private var showsMeTabBar = true

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .ignoresSafeArea(.keyboard)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsFloatingTabBar {
                        FloatingTabBar(
                            selection: $router.selectedTab,
                            items: tabItems
                        )
                        .padding(.bottom, 18)
                        .background(
                            Color.liftBackground
                                .ignoresSafeArea(edges: .bottom)
                                .allowsHitTesting(false)
                        )
                    }
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .tint(Color.liftAccentText)
        .onChange(of: mePath) { _, path in
            if path.isEmpty {
                showsMeTabBar = true
            } else {
                showsMeTabBar = false
            }
        }
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

    @ViewBuilder
    private var selectedTabContent: some View {
        switch router.selectedTab {
        case .home:
            NavigationStack { HomeView() }
        case .track:
            TrainingTrackerView(
                startOnProgress: appState.trainingTrackerStartOnProgress,
                isEmbeddedInTab: true
            )
        case .profile:
            NavigationStack(path: $mePath) {
                meTabContent
            }
        }
    }

    @ViewBuilder
    private var meTabContent: some View {
        Group {
            if router.selectedTab == .profile {
                MeHubContentView()
            } else {
                AppBackground {
                    Color.clear
                }
            }
        }
        .navigationDestination(for: MeRoute.self) { route in
            switch route {
            case .publicProfile:
                ProfileView(profile: appState.currentProfile, surface: .public, viewerID: UUID())
            case .personalProfile:
                ProfileView(profile: appState.currentProfile, surface: .personal)
            case .awards:
                AwardsView()
            case .gyms:
                GymDirectoryView()
            }
        }
    }

    private var showsFloatingTabBar: Bool {
        router.selectedTab != .profile || showsMeTabBar
    }

    private var tabItems: [FloatingTabItem] {
        var items: [FloatingTabItem] = [
            .init(tab: .home, icon: "house.fill", title: "Home"),
            .init(tab: .track, icon: "dumbbell.fill", title: "Track"),
        ]

        items.append(.init(tab: .profile, icon: "person.crop.circle.fill", title: "Me"))

        return items
    }

    @ViewBuilder
    private func appSheet(_ destination: AppSheet) -> some View {
        switch destination {
        case .submitLift:
            SubmitLiftView().environmentObject(appState).presentationDetents([.large])
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

private struct MeHubContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsTrainingDetails = false
    @State private var selectedTopLiftCard: TopLiftCardDestination?

    var body: some View {
        AppBackground {
            ScrollView {
                let profile = appState.currentProfile
                let preferredUnit = profile.preferredUnit
                let tierSummary = appState.strengthTierSummary
                let trainingStats = appState.competitiveStatistics
                let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your profile" : profile.displayName
                let handle = profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add a username in Edit Profile" : "@\(profile.username)"

                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                         : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                            ProfileAvatar(profile: profile, size: 66)
                                .accessibilityIdentifier("me.profileHeader")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.title3.weight(.black))
                                Text(handle)
                                    .font(.caption)
                                    .foregroundStyle(profile.username.isEmpty ? Color.liftAccentText : Color.liftMuted)
                                Text("Tier \(tierSummary.overallTier.label)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGold)
                            }

                            .frame(maxWidth: .infinity, alignment: .leading)

                            (dynamicTypeSize.isAccessibilitySize
                             ? AnyLayout(HStackLayout(spacing: 8))
                             : AnyLayout(VStackLayout(spacing: 8))) {
                                compactHeaderIconButton("gearshape.fill", "Open settings", accessibilityIdentifier: "me.header.settings") {
                                    appState.showingSettings = true
                                }

                                compactHeaderIconButton("pencil", "Edit athlete profile", accessibilityIdentifier: "me.header.editProfile") {
                                    appState.showingEditProfile = true
                                }
                            }
                        }

                        if let bio = profile.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bio).font(.subheadline).lineLimit(3)
                        }

                        NavigationLink(value: MeRoute.publicProfile) {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                Text("View public profile")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftSurfaceElevated.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.liftAccentText)
                        .accessibilityIdentifier("me.publicProfile")

                        HStack(spacing: 0) {
                            meHeaderStat("Workouts", trainingStats.totalWorkouts.formatted())
                            Divider().frame(height: 28).overlay(Color.liftSeparator)
                            meHeaderStat("Workout PRs", trainingStats.prCount.formatted())
                            Divider().frame(height: 28).overlay(Color.liftSeparator)
                            meHeaderStat("Streak", "\(trainingStats.currentStreak)w")
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liftSurface(radius: 12)

                    DisclosureGroup(isExpanded: $showsTrainingDetails) {
                    if showsTrainingDetails {
                    let bestStrengthLifts = appState.bestStrengthLifts
                    let hasLoggedTopLifts = bestStrengthLifts["bench"] != nil || bestStrengthLifts["squat"] != nil || bestStrengthLifts["deadlift"] != nil
                    CompactSectionHeader(title: "Top submitted lifts")
                        .accessibilityIdentifier("me.section.topLifts")
                    if hasLoggedTopLifts {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            topLiftCardButton("Bench", exerciseID: "bench", lift: bestStrengthLifts["bench"], preferredUnit: preferredUnit)
                            topLiftCardButton("Squat", exerciseID: "squat", lift: bestStrengthLifts["squat"], preferredUnit: preferredUnit)
                            topLiftCardButton("Deadlift", exerciseID: "deadlift", lift: bestStrengthLifts["deadlift"], preferredUnit: preferredUnit)
                            let breakdown = RankingCalculator.powerliftingBreakdown(for: profile.id, lifts: appState.currentUserLifts)
                            Button {
                                selectedTopLiftCard = .totalStrength(breakdown)
                            } label: {
                                topLiftCard("Total strength", value: breakdown.totalKilograms, preferredUnit: preferredUnit, suffix: "total", compact: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View total strength breakdown")
                            .accessibilityHint("Shows the submitted one-rep-max lifts included in your total")
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                appState.showingSubmitSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Submit a new lift")
                                        .font(.subheadline.weight(.bold))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.bold))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.liftBlue.opacity(0.15))
                                .foregroundStyle(Color.liftAccentText)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                                topLiftCardButton("Bench", exerciseID: "bench", lift: nil, preferredUnit: preferredUnit)
                                topLiftCardButton("Squat", exerciseID: "squat", lift: nil, preferredUnit: preferredUnit)
                                topLiftCardButton("Deadlift", exerciseID: "deadlift", lift: nil, preferredUnit: preferredUnit)
                            }
                        }
                    }

                    }
                    }
                    label: {
                        Text("Submitted lift records")
                            .accessibilityIdentifier("me.trainingDetails")
                    }
                    .tint(Color.liftAccentText)

                    CompactSectionHeader(title: "Activity & connections")
                        .accessibilityIdentifier("me.section.awardsHistory")
                    VStack(spacing: 0) {
                        NavigationLink(value: MeRoute.awards) {
                            meRow("Rival tier & awards", "Strength milestones, records, and progress", "trophy.fill", Color.liftGold, badge: tierSummary.overallTier.label)
                        }
                        .accessibilityIdentifier("me.awards")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.personalProfile) {
                            meRow("Submitted lift activity", "Your athlete profile and shared lifts", "chart.xyaxis.line", Color.liftGreen)
                        }
                        .accessibilityIdentifier("me.personalProfile")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        Button {
                            appState.router.progressCategory = appState.currentProfile.trainingFocus?.startingCategory ?? .consistency
                            appState.trainingTrackerStartOnProgress = true
                            appState.requestedTrackerSegment = "Progress"
                            appState.selectedTab = 2
                        } label: {
                            meRow("Training progress", "Workouts, strength, and muscle workload", "chart.line.uptrend.xyaxis", Color.liftBlue)
                        }
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.gyms) {
                            meRow(
                                "Find a gym",
                                appState.gyms.isEmpty
                                    ? "Browse locations and choose your primary gym"
                                    : "Browse locations and manage your primary gym",
                                "building.2.fill",
                                Color.liftBlue,
                                badge: appState.currentProfile.primaryGymName.isEmpty
                                    ? nil
                                    : appState.currentProfile.primaryGymName
                            )
                        }
                        .accessibilityIdentifier("me.gyms")
                    }
                    .buttonStyle(.plain)
                    .liftSurface()

                }
                .padding(14)
                .padding(.bottom, LiftDesign.floatingTabBarContentClearance)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await appState.refreshProductionLifts(force: true)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appState.refreshProductionLifts()
        }
        .sheet(item: $selectedTopLiftCard) { destination in
            TopLiftCardDetailSheet(destination: destination)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    private func topLiftCardButton(
        _ title: String,
        exerciseID: String,
        lift: LiftSubmission?,
        preferredUnit: UnitSystem
    ) -> some View {
        Button {
            selectedTopLiftCard = lift.map(TopLiftCardDestination.submitted)
                ?? .exerciseHistory(id: exerciseID, name: title)
        } label: {
            topLiftCard(title, lift: lift, preferredUnit: preferredUnit, suffix: "", compact: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lift == nil ? "View past \(title.lowercased()) workout lifts" : "View submitted \(title.lowercased()) lift")
        .accessibilityHint(lift == nil ? "Shows matching workout sets and lets you submit one" : "Shows details for this submitted lift")
    }

    private func topLiftCard(
        _ title: String,
        lift: LiftSubmission?,
        preferredUnit: UnitSystem,
        suffix: String,
        showHelp: Bool = false,
        compact: Bool = false
    ) -> some View {
        topLiftCard(
            title,
            value: lift?.normalizedWeightKilograms,
            preferredUnit: preferredUnit,
            suffix: suffix,
            showHelp: showHelp || lift == nil,
            compact: compact
        )
    }

    private func compactHeaderIconButton(
        _ systemImage: String,
        _ accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.liftCard)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.liftSurfaceBorder, lineWidth: 1))
                .frame(width: LiftDesign.minimumTouchTarget, height: LiftDesign.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func meHeaderStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.black))
            Text(title)
                .font(.caption2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func topLiftCard(_ title: String, value: Double?, preferredUnit: UnitSystem, suffix: String, showHelp: Bool = false, compact: Bool = false) -> some View {
        let minHeight: CGFloat = compact ? 86 : 112
        let verticalPadding: CGFloat = compact ? 9 : 14
        let horizontalPadding: CGFloat = compact ? 10 : 14
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
            Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(
                value.map { "\(MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit))\(suffix.isEmpty ? "" : " \(suffix)")" } ?? "—"
            )
                .font(.subheadline.weight(.black))
            Text(showHelp ? "No lift submission yet" : "Best submitted lift")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .liftSurface(radius: 12)
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, badge: String? = nil) -> some View {
        meRow(title, subtitle, symbol, tint, badge: badge, isDestructive: false)
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, badge: String? = nil, isDestructive: Bool = false) -> some View {
        let iconColor = isDestructive ? Color.liftRed : tint
        let textColor = isDestructive ? Color.liftRed : Color.liftText
        let chevronColor = isDestructive ? Color.liftRed : Color.liftMuted
        return HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(textColor)
                Text(subtitle).font(.caption).foregroundStyle(Color.liftMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if dynamicTypeSize.isAccessibilitySize, let badge {
                    Text(badge).font(.caption.weight(.black)).foregroundStyle(Color.liftGold)
                }
            }
            Spacer(minLength: 8)
            if let badge, !dynamicTypeSize.isAccessibilitySize {
                Text(badge)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.liftGold)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(chevronColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

struct AwardsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rivalTierShareImage: Image?
    @State private var showsAllUnlockedAwards = false
    @State private var showsAllLockedAwards = false
    @State private var selectedLiftHistory: TopLiftCardDestination?

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
        let awardEligibleOneRepWeights = RankingCalculator.achievementEligibleOneRepWeights(
            lifts: appState.currentUserLifts,
            completedWorkouts: appState.completedWorkouts
        )
        let awardEligibleBench = awardEligibleOneRepWeights["bench"] ?? 0
        let awardEligibleSquat = awardEligibleOneRepWeights["squat"] ?? 0
        let awardEligibleDeadlift = awardEligibleOneRepWeights["deadlift"] ?? 0
        let totalPowerlifting = awardEligibleBench + awardEligibleSquat + awardEligibleDeadlift
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(appState.currentProfile.bodyweightPounds)
        let bodyweightLogCount = appState.bodyweightEntries.reduce(0) { count, entry in
            count + (entry.actual == nil ? 0 : 1)
        }
        let liftCount = appState.currentUserLifts.count
        let closestAwardProgress = progressAwardItems(
            for: progressAchievements,
            stats: appState.competitiveStatistics,
            tierSummary: tierSummary,
            bestBench: awardEligibleBench,
            bestSquat: awardEligibleSquat,
            bestDeadlift: awardEligibleDeadlift,
            totalPowerlifting: totalPowerlifting,
            liftCount: liftCount,
            bodyweightLogCount: bodyweightLogCount,
            bodyweightKilograms: bodyweightKilograms
        )
        let unlockedCount = unlockedAchievements.count
        let lockedCount = progressAchievements.count
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("\(unlockedCount) earned", systemImage: "medal.fill")
                        Spacer()
                        Text("\(lockedCount) remaining").foregroundStyle(Color.liftMuted)
                    }
                    .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Closest awards")
                        if closestAwardProgress.isEmpty {
                            LiftEmptyState(title: "No progress data yet", message: "Keep training to see your next awards.", symbolName: "chart.xyaxis.line")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Array(closestAwardProgress.prefix(3)), id: \.achievement.id) { item in
                                    awardTile(item.achievement, unlocked: false, status: item.status)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Unlocked awards (\(unlockedCount))")
                        if unlockedAchievements.isEmpty {
                            LiftEmptyState(title: "No awards yet", message: "Complete workouts and log lifts to unlock your first award.", symbolName: "medal.fill")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(showsAllUnlockedAwards ? unlockedAchievements : Array(unlockedAchievements.prefix(8))) { achievement in
                                    awardTile(achievement, unlocked: true)
                                }
                            }
                            if unlockedCount > 8 {
                                Button(showsAllUnlockedAwards ? "Show fewer" : "Show all \(unlockedCount) unlocked awards") {
                                    showsAllUnlockedAwards.toggle()
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                            }
                        }
                    }

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
                             ? "Your overall tier is the highest tier reached in all three lifts: squat, bench press, and deadlift."
                             : "Log completed working sets for all three lifts to unlock your starting tier.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)

                        ForEach(tierSummary.liftProgress) { lift in
                            Button {
                                selectedLiftHistory = .exerciseHistory(id: lift.exerciseID, name: lift.exerciseName)
                            } label: {
                                strengthLiftRow(lift, preferredUnit: preferredUnit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View \(lift.exerciseName) workout history")
                            .accessibilityHint("Review a workout set and submit it as a lift")
                        }
                    }
                    .padding(14)
                    .liftSurface(radius: 12)

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
                                .frame(maxWidth: .infinity, minHeight: 44)
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
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Personal records")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(["bench", "squat", "deadlift", "total"], id: \.self) { metric in
                                switch metric {
                                case "bench":
                                    personalRecord(
                                        "Bench",
                                        exerciseID: "bench",
                                        best: bestBench,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "bench" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                case "squat":
                                    personalRecord(
                                        "Squat",
                                        exerciseID: "squat",
                                        best: bestSquat,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "squat" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                case "deadlift":
                                    personalRecord(
                                        "Deadlift",
                                        exerciseID: "deadlift",
                                        best: bestDeadlift,
                                        workoutEstimate: tierSummary.liftProgress.first { $0.exerciseID == "deadlift" }?.estimatedOneRepMaxKilograms,
                                        preferredUnit: preferredUnit
                                    )
                                default:
                                    totalRecord(preferredUnit: preferredUnit)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Locked awards (\(lockedCount))")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(showsAllLockedAwards ? progressAchievements : Array(progressAchievements.prefix(8))) {
                                awardTile($0, unlocked: false)
                            }
                        }
                        if lockedCount > 8 {
                            Button(showsAllLockedAwards ? "Show fewer" : "Show all \(lockedCount) locked awards") {
                                showsAllLockedAwards.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
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
        .task {
            await appState.refreshProductionLifts()
        }
        .onAppear {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.competitionStore.liftsRevision) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.bodyweightEntries) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.currentProfile.bodyweightPounds) {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: tierSummary) { _, _ in
            rivalTierShareImage = nil
        }
        .sheet(item: $selectedLiftHistory) { destination in
            TopLiftCardDetailSheet(destination: destination)
                .environmentObject(appState)
                .presentationDetents([.large])
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

    private func personalRecord(
        _ title: String,
        exerciseID: String,
        best: LiftSubmission?,
        workoutEstimate: Double?,
        preferredUnit: UnitSystem
    ) -> some View {
        let valueKilograms = best?.normalizedWeightKilograms ?? workoutEstimate
        return Button {
            selectedLiftHistory = .exerciseHistory(id: exerciseID, name: title)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(Color.liftGold)
                Text(title.uppercased()).font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
                Text(valueKilograms.map {
                    MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit)
                } ?? "—")
                    .font(.headline.weight(.black))
                Text(best != nil ? "Best submitted lift" : workoutEstimate != nil ? "Estimated 1RM from workouts" : "No workout lift yet")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(title) workout history and lift details")
        .accessibilityHint("Review a workout set and submit it as a lift")
    }

    private func totalRecord(preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
            Text("Total").font(.caption.weight(.black)).foregroundStyle(Color.liftMuted)
            Text(RankingFormatting.threeLiftTotalText(
                totalPounds: appState.powerliftingTotal,
                preferredUnit: preferredUnit
            ))
            .font(.headline.weight(.black))
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardTile(_ achievement: Achievement, unlocked: Bool, status: String? = nil) -> some View {
        let display = MeasurementFormatting.awardDisplay(for: achievement, unit: appState.currentProfile.preferredUnit)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(unlocked ? Color.liftGold : Color.liftMuted)
                .accessibilityHidden(true)
            Text(display.title).font(.subheadline.weight(.bold)).foregroundStyle(unlocked ? Color.liftText : Color.liftMuted).lineLimit(2)
                .accessibilityLabel("\(display.title), \(unlocked ? "earned" : "locked")")
            if let status {
                Text(status).font(.caption2.weight(.semibold)).foregroundStyle(Color.liftMuted)
            } else if !unlocked {
                Text("Keep progressing").font(.caption2).foregroundStyle(Color.liftMuted)
            }
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func progressAwardItems(
        for achievements: [Achievement],
        stats: CompetitiveStatistics,
        tierSummary: StrengthTierSummary,
        bestBench: Double,
        bestSquat: Double,
        bestDeadlift: Double,
        totalPowerlifting: Double,
        liftCount: Int,
        bodyweightLogCount: Int,
        bodyweightKilograms: Double
    ) -> [(achievement: Achievement, progress: Double, status: String)] {
        achievements.compactMap { achievement in
            guard let item = progressAward(
                for: achievement,
                stats: stats,
                tierSummary: tierSummary,
                bestBench: bestBench,
                bestSquat: bestSquat,
                bestDeadlift: bestDeadlift,
                totalPowerlifting: totalPowerlifting,
                liftCount: liftCount,
                bodyweightLogCount: bodyweightLogCount,
                bodyweightKilograms: bodyweightKilograms
            ) else { return nil }
            return (achievement: item.0, progress: item.1, status: item.2)
        }
        .sorted {
            if $0.progress == $1.progress {
                return $0.achievement.title < $1.achievement.title
            }
            return $0.progress > $1.progress
        }
    }

    private func progressAward(
        for achievement: Achievement,
        stats: CompetitiveStatistics,
        tierSummary: StrengthTierSummary,
        bestBench: Double,
        bestSquat: Double,
        bestDeadlift: Double,
        totalPowerlifting: Double,
        liftCount: Int,
        bodyweightLogCount: Int,
        bodyweightKilograms: Double
    ) -> (Achievement, Double, String)? {
        let title = achievement.title
        let preferredUnit = appState.currentProfile.preferredUnit
        let metric: (Double, String)?

        if title == "First Workout" {
            metric = metricProgress(current: Double(stats.totalWorkouts), target: 1, status: "\(stats.totalWorkouts) / 1 workout")
        } else if title.hasSuffix(" Workouts") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.totalWorkouts), target: target, status: "\(stats.totalWorkouts) / \(Int(target)) workouts")
        } else if title == "First Lift Logged" {
            metric = metricProgress(current: Double(liftCount), target: 1, status: "\(liftCount) / 1 lift logged")
        } else if title.contains("Lifts Logged") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(liftCount), target: target, status: "\(liftCount) / \(Int(target)) lifts logged")
        } else if title == "First Verified Lift" {
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: 1, status: "\(stats.verifiedLiftCount) / 1 verified lift")
        } else if title == "Five Verified Lifts" || title == "Ten Verified Lifts" {
            let target = title == "Five Verified Lifts" ? 5.0 : 10.0
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: target, status: "\(stats.verifiedLiftCount) / \(Int(target)) verified lifts")
        } else if title.contains("Verified Lifts") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.verifiedLiftCount), target: target, status: "\(stats.verifiedLiftCount) / \(Int(target)) verified lifts")
        } else if title == "First PR" {
            metric = metricProgress(current: Double(stats.prCount), target: 1, status: "\(stats.prCount) / 1 PR")
        } else if title.contains(" PRs") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.prCount), target: target, status: "\(stats.prCount) / \(Int(target)) PRs")
        } else if title.hasSuffix(" Reps") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(stats.totalWorkingSetRepetitions), target: target, status: "\(stats.totalWorkingSetRepetitions) / \(Int(target)) reps")
        } else if title.hasSuffix(" Training Hours") {
            guard let targetHours = parseLeadingValue(from: title) else { return nil }
            let targetSeconds = targetHours * 60 * 60
            metric = metricProgress(
                current: stats.totalActiveTrainingTime,
                target: targetSeconds,
                status: "\(String(format: "%.1f", min(stats.totalActiveTrainingTime, targetSeconds) / 3600)) / \(Int(targetHours)) hrs"
            )
        } else if title == "Bodyweight Logged" {
            metric = metricProgress(current: Double(bodyweightLogCount), target: 1, status: "\(bodyweightLogCount) / 1 bodyweight log")
        } else if title.hasSuffix(" Bodyweight Logs") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            metric = metricProgress(current: Double(bodyweightLogCount), target: target, status: "\(bodyweightLogCount) / \(Int(target)) bodyweight logs")
        } else if title.hasSuffix(" Exercises Explored") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = Set(appState.completedWorkouts.flatMap { $0.exercises.map(\.exerciseID) }).count
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) exercises")
        } else if title.hasSuffix(" Gyms Joined") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = appState.joinedGymCount
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) gyms")
        } else if title.hasSuffix(" Programs Started") {
            guard let target = parseLeadingValue(from: title) else { return nil }
            let count = appState.workoutPlans.count
            metric = metricProgress(current: Double(count), target: target, status: "\(count) / \(Int(target)) programs")
        } else if let liftMilestone = MeasurementFormatting.liftAwardMilestone(for: title) {
            let current = liftMilestone.exercise == "Bench" ? bestBench : (liftMilestone.exercise == "Squat" ? bestSquat : bestDeadlift)
            let target = RankingCalculator.poundsToKilograms(liftMilestone.pounds)
            metric = metricProgress(
                current: current,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let totalPounds = MeasurementFormatting.totalAwardPounds(for: title) {
            let target = RankingCalculator.poundsToKilograms(totalPounds)
            metric = metricProgress(
                current: totalPowerlifting,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(totalPowerlifting, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let volumeKilograms = MeasurementFormatting.volumeAwardKilograms(for: title) {
            metric = metricProgress(
                current: stats.lifetimeWorkingSetVolume,
                target: volumeKilograms,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(stats.lifetimeWorkingSetVolume, volumeKilograms), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: volumeKilograms, unit: preferredUnit))"
            )
        } else if let streakTarget = parseLeadingValue(from: title), title.contains("Week Workout Streak") {
            metric = metricProgress(current: Double(stats.currentStreak), target: streakTarget, status: "\(stats.currentStreak) / \(Int(streakTarget)) weeks")
        } else if title == "Profile Complete" {
            let profile = appState.currentProfile
            let isComplete = !profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            metric = metricProgress(current: isComplete ? 1 : 0, target: 1, status: isComplete ? "Profile complete" : "Profile not complete")
        } else if title.contains("Bodyweight") {
            let multiple = parseLeadingValue(from: title) ?? 1
            let target = bodyweightKilograms * multiple
            let current: Double
            switch true {
            case title.contains("Bench"):
                current = bestBench
            case title.contains("Squat"):
                current = bestSquat
            default:
                current = bestDeadlift
            }
            metric = metricProgress(
                current: current,
                target: target,
                status: "\(MeasurementFormatting.formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(MeasurementFormatting.formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if title.hasSuffix(" Rival"), let rivalTier = rivalTier(for: title) {
            let currentTier = tierSummary.overallTier == .unranked ? 0 : tierSummary.overallTier.rawValue
            metric = metricProgress(
                current: Double(currentTier),
                target: Double(rivalTier.rawValue),
                status: "\(tierSummary.overallTier.label) / \(rivalTier.label)"
            )
        } else if title.hasPrefix("Global Top"), let target = parseLeadingValue(from: title), let rank = stats.highestGlobalTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: target)
        } else if title == "Gym Top 10", let rank = stats.highestGymTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 10)
        } else if title == "Gym Record Holder", let rank = stats.highestGymTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 1)
        } else if title == "Global Number One", let rank = stats.highestGlobalTotalRank {
            metric = metricRankProgress(currentRank: Double(rank), target: 1)
        } else {
            return nil
        }

        guard let metric else { return nil }
        return (achievement, metric.0, "\(Int(metric.0 * 100))%  •  \(metric.1)")
    }

    private func metricProgress(current: Double, target: Double, status: String) -> (Double, String)? {
        guard target > 0 else { return nil }
        let progress = min(1, max(0, current / target))
        return (progress, status)
    }

    private func metricRankProgress(currentRank: Double, target: Double) -> (Double, String)? {
        guard currentRank > 0, target > 0 else { return nil }
        let progress = min(1, target / currentRank)
        return (progress, "\(Int(currentRank)) / \(Int(target))")
    }

    private func parseLeadingValue(from title: String) -> Double? {
        let cleaned = title.replacingOccurrences(of: ",", with: "")
        var collected = ""
        var foundStart = false
        var hasDecimal = false
        for scalar in cleaned.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                foundStart = true
                collected.append(Character(scalar))
            } else if scalar == "." && foundStart {
                if hasDecimal { continue }
                hasDecimal = true
                collected.append(".")
            } else if foundStart {
                break
            }
        }
        return Double(collected)
    }

    private func rivalTier(for title: String) -> StrengthTier? {
        let base = title.replacingOccurrences(of: " Rival", with: "")
        return StrengthTier.allCases.first { $0.label == base && $0 != .unranked }
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
                    .background(Color.liftOverlay)
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingPassword = false
    @State private var showingReset = false
    @State private var resetEmail = ""
    @State private var resetError: String?
    @State private var appleNonce = ""
    @State private var confirmationEmail: String?

    private let emailConfirmationMessage = "Check your email to confirm your account, then sign in."
    private let emailResentMessage = "A new confirmation email is on the way."

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 46)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Color.liftAccentText)
                    Text("Lift Rivals").font(.largeTitle.bold())
                    Text("Sign in to save your profile, sync workouts, and connect with other lifters.")
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            TextField("", text: $email)
                                .accessibilityLabel("Email")
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(Color.liftCardRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Password").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            HStack(spacing: 10) {
                                Group {
                                    if showingPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textContentType(mode == "Sign In" ? .password : .newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    showingPassword.toggle()
                                } label: {
                                    Image(systemName: showingPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .accessibilityLabel(showingPassword ? "Hide password" : "Show password")
                            }
                            .padding(14)
                            .background(Color.liftCardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text(
                            mode == "Sign In"
                                ? "Use the email address connected to your account."
                                : "Use a valid email and a password of at least 10 characters."
                        )
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let confirmationEmail {
                            emailConfirmationNotice(for: confirmationEmail)
                        } else if let message = appState.accountMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(
                                    message == "Incorrect password. Check your password and try again."
                                        ? .red
                                        : (message.localizedCaseInsensitiveContains("connection") || message.localizedCaseInsensitiveContains("network")
                                            ? Color.liftGold
                                            : Color.liftMuted)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Please wait…" : mode,
                            symbolName: mode == "Sign In" ? "arrow.right.circle.fill" : "person.badge.plus"
                        ) {
                            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !normalizedEmail.isEmpty else {
                                appState.accountMessage = "Enter your email address."
                                return
                            }
                            guard normalizedEmail.contains("@") else {
                                appState.accountMessage = "Enter a valid email address."
                                return
                            }
                            guard !password.isEmpty else {
                                appState.accountMessage = "Enter your password."
                                return
                            }
                            guard mode == "Sign In" || password.count >= 10 else {
                                appState.accountMessage = "New passwords must contain at least 10 characters."
                                return
                            }
                            Task {
                                if mode == "Sign In" {
                                    await appState.signIn(email: normalizedEmail, password: password)
                                    if appState.isAuthenticated {
                                        appState.selectedTab = 1
                                    }
                                } else {
                                    await appState.signUp(email: normalizedEmail, password: password)
                                    if appState.accountMessage == emailConfirmationMessage {
                                        confirmationEmail = normalizedEmail
                                        password = ""
                                        mode = "Sign In"
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("authentication.email.submit")
                        .disabled(appState.accountOperationInProgress)

#if DEBUG
                        Label("Apple sign-in is enabled in the release build", systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity)
#else
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = AppleNonce.make()
                            appleNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = AppleNonce.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let data = credential.identityToken,
                                      let token = String(data: data, encoding: .utf8),
                                      !appleNonce.isEmpty else {
                                    appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                                    return
                                }
                                let fullName = AppleIdentityStore.displayName(from: credential.fullName)
                                Task {
                                    await appState.signInWithApple(
                                        identityToken: token,
                                        nonce: appleNonce,
                                        appleUserIdentifier: credential.user,
                                        fullName: fullName
                                    )
                                    if appState.isAuthenticated {
                                        appState.selectedTab = 1
                                    }
                                }
                            case .failure(let error):
                                if let authorizationError = error as? ASAuthorizationError,
                                   authorizationError.code == .canceled {
                                    return
                                }
                                appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .disabled(appState.accountOperationInProgress)
#endif

                        Button("Forgot password?") { resetEmail = email; resetError = nil; showingReset = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                    }

                    Divider().overlay(Color.liftOverlay)
                    Button {
                        Task { await appState.enterGuestMode() }
                    } label: {
                        Label("Continue as Guest", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftAccentText)
                    .disabled(appState.accountOperationInProgress)
                    Text("Start your profile without an email. Add an email later in Settings to sign in on another device.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)
#if DEBUG
                    if AppState.allowsDemoMode {
                        Button("Explore demo") {
                            Task { await appState.enterDemoMode() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    }
#endif
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                Form {
                    Section {
                        Text("Enter your account email and we’ll send a secure reset link. Open it on this device to choose a new password in Lift Rivals.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        TextField("Email", text: $resetEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if let resetError {
                        Text(resetError).foregroundStyle(Color.liftRed)
                            .accessibilityIdentifier("authentication.reset.error")
                    }
                    Section {
                        Button(appState.accountOperationInProgress ? "Sending…" : "Send reset link") {
                            let normalizedEmail = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard normalizedEmail.contains("@") else {
                                resetError = "Enter a valid email address."
                                return
                            }
                            resetError = nil
                            Task {
                                await appState.requestPasswordReset(email: normalizedEmail)
                                if appState.accountMessage == "If an account can receive a reset email, instructions are on the way." {
                                    showingReset = false
                                } else {
                                    resetError = appState.accountMessage
                                }
                            }
                        }
                        .disabled(appState.accountOperationInProgress)
                    }
                }
                .navigationTitle("Reset password")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingReset = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private func emailConfirmationNotice(for email: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Confirmation email sent", systemImage: "envelope.badge.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.liftAccentText)

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

            Button {
                Task { await appState.resendConfirmationEmail(email: email) }
            } label: {
                Label(
                    appState.accountOperationInProgress ? "Sending…" : "Send again",
                    systemImage: "arrow.clockwise"
                )
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.liftAccentText)
            .disabled(appState.accountOperationInProgress)

            if appState.accountMessage == emailResentMessage {
                Text(emailResentMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftAccentText)
            }
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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case password
        case confirmation
    }

    private var hasMinimumLength: Bool { password.count >= 10 }
    private var passwordsMatch: Bool { !confirmation.isEmpty && password == confirmation }
    private var canSubmit: Bool { hasMinimumLength && passwordsMatch }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.liftLime.opacity(0.15))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(Color.liftAccentText)
                            }

                            Text("Choose a new password")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                            Text("Your recovery link is verified. Set a new password to secure your Lift Rivals account.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 13) {
                            secureInput(
                                label: "New password",
                                placeholder: "Enter a new password",
                                text: $password,
                                field: .password
                            )
                            secureInput(
                                label: "Confirm new password",
                                placeholder: "Enter it again",
                                text: $confirmation,
                                field: .confirmation
                            )
                        }

                        LiftCard(padding: 15, radius: 18) {
                            VStack(alignment: .leading, spacing: 11) {
                                Text("Password requirements")
                                    .font(.subheadline.weight(.bold))
                                requirementRow(
                                    "At least 10 characters",
                                    isSatisfied: hasMinimumLength,
                                    isError: !password.isEmpty && !hasMinimumLength
                                )
                                requirementRow(
                                    confirmation.isEmpty ? "Confirm your password" : passwordsMatch ? "Passwords match" : "Passwords do not match",
                                    isSatisfied: passwordsMatch,
                                    isError: !confirmation.isEmpty && !passwordsMatch
                                )
                            }
                        }

                        if let message = appState.accountMessage {
                            Label {
                                Text(message)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .foregroundStyle(Color.liftRed)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftRed.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Updating…" : "Update password",
                            symbolName: appState.accountOperationInProgress ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill"
                        ) {
                            Task { await appState.updatePassword(password) }
                        }
                        .disabled(appState.accountOperationInProgress || !canSubmit)
                        .accessibilityIdentifier("authentication.password.update")

                        Text("If this link expires or stops working, request a new reset email from the sign-in screen.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Account recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private func secureInput(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 20)
                SecureField(placeholder, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .password ? .next : .done)
                    .onSubmit {
                        if field == .password { focusedField = .confirmation }
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.liftField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == field ? Color.liftLime.opacity(0.75) : Color.clear, lineWidth: 1.5)
            }
        }
        .onChange(of: text.wrappedValue) { _, _ in
            if appState.accountMessage != nil { appState.accountMessage = nil }
        }
    }

    private func requirementRow(_ title: String, isSatisfied: Bool, isError: Bool) -> some View {
        Label(title, systemImage: isSatisfied ? "checkmark.circle.fill" : isError ? "xmark.circle.fill" : "circle")
            .font(.caption)
            .foregroundStyle(isSatisfied ? Color.liftAccentText : isError ? Color.liftRed : Color.liftMuted)
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
