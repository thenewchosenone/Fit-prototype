import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

private enum MeRoute: Hashable {
    case publicProfile
    case awards
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var router: AppRouter
    @State private var mePath: [MeRoute] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .ignoresSafeArea(.keyboard)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsFloatingTabBar {
                        FloatingTabBar(
                            selection: $router.selectedTab,
                            items: tabItems,
                            utilityAction: {
                                appState.showingSubmitSheet = true
                            }
                        )
                        .padding(.bottom, 18)
                        .background(Color.liftBackground.ignoresSafeArea(edges: .bottom))
                    }
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
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

    @ViewBuilder
    private var selectedTabContent: some View {
        switch router.selectedTab {
        case .home:
            NavigationStack { HomeView() }
        case .leaderboards:
            NavigationStack { LeaderboardsView() }
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
        MeHubContentView()
        .navigationDestination(for: MeRoute.self) { route in
            switch route {
            case .publicProfile:
                ProfileView(profile: appState.currentProfile, isCurrentUser: true)
            case .awards:
                AwardsView()
            }
        }
    }

    private var showsFloatingTabBar: Bool {
        router.selectedTab != .profile || mePath.isEmpty
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
        case .settings(let section):
            SettingsView(initialSection: section).environmentObject(appState)
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

private enum MeRecentVolumeSelection: String, CaseIterable {
    case thisWeek = "This week"
    case lastWeek = "Last week"

    var referenceDate: Date {
        switch self {
        case .thisWeek:
            Date()
        case .lastWeek:
            Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        }
    }
}

private struct MeHubContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var weeklyVolumeSelection: MeRecentVolumeSelection = .thisWeek

    var body: some View {
        AppBackground {
            ScrollView {
                let profile = appState.currentProfile
                let preferredUnit = profile.preferredUnit
                let bestStrengthLifts = appState.bestStrengthLifts
                let tierSummary = appState.strengthTierSummary
                let hasLoggedTopLifts = bestStrengthLifts["bench"] != nil || bestStrengthLifts["squat"] != nil || bestStrengthLifts["deadlift"] != nil

                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            ProfileAvatar(profile: profile, size: 66)
                                .accessibilityIdentifier("me.profileHeader")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.title3.weight(.black))
                                Text("@\(profile.username)")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Text("Tier \(tierSummary.overallTier.label)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftGold)
                            }

                            Spacer()

                            VStack(spacing: 8) {
                                compactHeaderIconButton("gearshape.fill", "Open settings", accessibilityIdentifier: "me.header.settings") {
                                    appState.showingSettings = true
                                }

                                compactHeaderIconButton("pencil", "Edit athlete profile", accessibilityIdentifier: "me.header.editProfile") {
                                    appState.showingEditProfile = true
                                }
                            }
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
                        .foregroundStyle(Color.liftBlue)
                        .accessibilityIdentifier("me.publicProfile")
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liftSurface(radius: 12)

                    CompactSectionHeader(title: "Strength progress")
                        .accessibilityIdentifier("me.section.strengthProgress")
                    VStack(alignment: .leading, spacing: 12) {
                        strengthTierHeader(tierSummary)

                        Divider().overlay(Color.liftSeparator)

                        ForEach(Array(tierSummary.liftProgress.enumerated()), id: \.element.id) { index, lift in
                            strengthProgressRow(lift: lift, preferredUnit: preferredUnit)
                            if index < tierSummary.liftProgress.count - 1 {
                                Divider().overlay(Color.liftSeparator)
                            }
                        }

                        Divider().overlay(Color.liftSeparator)

                        NavigationLink(value: MeRoute.awards) {
                            HStack(spacing: 10) {
                                Image(systemName: "trophy.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftGold)
                                Text("Tier details and awards")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(minHeight: 36)
                        }
                        .accessibilityIdentifier("me.awards.strength")
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liftSurface(radius: 12)

                    CompactSectionHeader(title: "Top lifts")
                        .accessibilityIdentifier("me.section.topLifts")
                    if hasLoggedTopLifts {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            topLiftCard("Bench", lift: bestStrengthLifts["bench"], preferredUnit: preferredUnit, suffix: "", compact: true)
                            topLiftCard("Squat", lift: bestStrengthLifts["squat"], preferredUnit: preferredUnit, suffix: "", compact: true)
                            topLiftCard("Deadlift", lift: bestStrengthLifts["deadlift"], preferredUnit: preferredUnit, suffix: "", compact: true)
                            topLiftCard("Total strength", value: appState.powerliftingTotal, preferredUnit: preferredUnit, suffix: "total", compact: true)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                appState.showingSubmitSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Log your first lift")
                                        .font(.subheadline.weight(.bold))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.bold))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.liftBlue.opacity(0.15))
                                .foregroundStyle(Color.liftBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                topLiftCard("Bench", lift: nil, preferredUnit: preferredUnit, suffix: "", showHelp: true, compact: true)
                                topLiftCard("Squat", lift: nil, preferredUnit: preferredUnit, suffix: "", showHelp: true, compact: true)
                                topLiftCard("Deadlift", lift: nil, preferredUnit: preferredUnit, suffix: "", showHelp: true, compact: true)
                            }
                        }
                    }

                    MeTrainingInsightsView(
                        selection: $weeklyVolumeSelection,
                        preferredUnit: preferredUnit
                    )

                    CompactSectionHeader(title: "Awards and history")
                        .accessibilityIdentifier("me.section.awardsHistory")
                    VStack(spacing: 0) {
                        NavigationLink(value: MeRoute.awards) {
                            meRow("Rival tier & awards", "Strength milestones, records, and progress", "trophy.fill", Color.liftGold, badge: tierSummary.overallTier.label)
                        }
                        .accessibilityIdentifier("me.awards")
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

                    CompactSectionHeader(title: "Account settings")
                        .accessibilityIdentifier("me.section.accountSettings")
                    Button { appState.showingSettings = true } label: {
                        meRow("Settings", "Account preferences, privacy, and legal controls", "gearshape.fill", Color.liftBlue)
                    }
                    .buttonStyle(.plain)
                    .liftSurface(radius: 12)

                    CompactSectionHeader(title: "Account actions")
                        .accessibilityIdentifier("me.section.accountActions")
                    VStack(spacing: 0) {
                        Button(role: .destructive) {
                            Task { await appState.signOutAccount() }
                        } label: {
                            meRow(
                                "Sign out",
                                "Open settings to delete, or sign out now",
                                "rectangle.portrait.and.arrow.right",
                                Color.liftRed,
                                isDestructive: true
                            )
                        }
                        .accessibilityIdentifier("me.accountActions.signOut")
                    }
                    .buttonStyle(.plain)
                    .liftSurface(radius: 12)
                }
                .padding(14)
                .padding(.bottom, LiftDesign.floatingTabBarContentClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Me")
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
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
            Text(showHelp ? "Log lifts to establish your best" : "Best logged lift")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .liftSurface(radius: 12)
    }

    private func strengthTierHeader(_ summary: StrengthTierSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "medal.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(Color.liftGold)
                .frame(width: 44, height: 44)
                .background(Color.liftGold.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("RIVAL TIER")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.liftMuted)
                Text(summary.overallTier.label)
                    .font(.title3.weight(.black))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.completedRequiredLiftCount) of \(summary.requiredLiftCount)")
                    .font(.subheadline.weight(.black))
                Text(summary.completedRequiredLiftCount == summary.requiredLiftCount ? "lifts ranked" : "lifts logged")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("me.strength.tier")
    }

    private func strengthProgressRow(lift: LiftTierProgress, preferredUnit: UnitSystem) -> some View {
        let hasEstimate = lift.estimatedOneRepMaxKilograms != nil
        let progressPercent = Int((lift.progressToNextTier * 100).rounded())
        let estimatedMaxText = lift.estimatedOneRepMaxKilograms.map { kilograms in
            let estimate = "Est. 1RM \(MeasurementFormatting.formatDisplayedWeight(kilograms, unit: preferredUnit))"
            guard lift.bodyweightMultiple > 0 else { return estimate }
            return "\(estimate) · \(RankingCalculator.format(lift.bodyweightMultiple))× bodyweight"
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: liftSymbol(for: lift.exerciseName))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(hasEstimate ? Color.liftGold : Color.liftMuted)
                    .frame(width: 34, height: 34)
                    .background((hasEstimate ? Color.liftGold : Color.liftMuted).opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(lift.exerciseName)
                        .font(.subheadline.weight(.bold))
                    Text(estimatedMaxText ?? "Log a working set of 10 reps or fewer")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(hasEstimate ? lift.currentTier.label : "Not logged")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hasEstimate ? Color.liftText : Color.liftMuted)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(hasEstimate ? Color.liftGold.opacity(0.14) : Color.liftSurfaceSecondary)
                    .clipShape(Capsule())
            }

            if hasEstimate {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.liftSurfaceSecondary)
                        Capsule()
                            .fill(Color.liftGold)
                            .frame(width: proxy.size.width * lift.progressToNextTier)
                    }
                }
                .frame(height: 6)

                HStack {
                    if let nextTier = lift.nextTier, let threshold = lift.nextThresholdMultiple {
                        Text("\(progressPercent)% to \(nextTier.label)")
                        Spacer()
                        Text("Target \(RankingCalculator.format(threshold))× BW")
                    } else {
                        Text("Highest tier reached")
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("me.strength.lift.\(lift.exerciseID)")
    }

    private func liftSymbol(for exerciseName: String) -> String {
        let normalized = exerciseName.lowercased()
        if normalized.contains("squat") { return "figure.strengthtraining.functional" }
        if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
        if normalized.contains("deadlift") { return "figure.strengthtraining.functional" }
        if normalized.contains("press") { return "dumbbell.fill" }
        return "chart.line.uptrend.xyaxis"
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
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(textColor)
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
                .foregroundStyle(chevronColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct MeTrainingInsightsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: MeRecentVolumeSelection
    let preferredUnit: UnitSystem

    var body: some View {
        let stats = appState.competitiveStatistics
        let recentLifts = Array(appState.currentUserLifts.prefix(5))
        let weeklyVolume = appState.weeklyVolumeByBodyPart(referenceDate: selection.referenceDate)
        let totalWeeklyVolume = weeklyVolume.values.reduce(0, +)
        let topBodyPart = weeklyVolume.max { $0.value < $1.value }?.key ?? "—"
        let topBodyPartPercent = topBodyPart == "—"
            ? 0
            : Int((weeklyVolume[topBodyPart, default: 0] / max(totalWeeklyVolume, 1)) * 100)

        Group {
            CompactSectionHeader(title: "Training stats")
                .accessibilityIdentifier("me.section.trainingStats")
            HStack(spacing: 10) {
                compactStat(title: "Workouts", value: stats.totalWorkouts.formatted(), unit: "all", symbol: "flame.fill", tint: .liftBlue)
                compactStatDivider()
                compactStat(title: "PRs", value: stats.prCount.formatted(), unit: "earned", symbol: "trophy.fill", tint: .liftGold)
                compactStatDivider()
                compactStat(
                    title: "Week volume",
                    value: Int(totalWeeklyVolume).formatted(),
                    unit: preferredUnit.shortLabel,
                    symbol: "chart.xyaxis.line",
                    tint: .liftGreen
                )
                compactStatDivider()
                compactStat(title: "Streak", value: stats.currentStreak.formatted(), unit: "days", symbol: "flame", tint: .liftOrange)
            }
            .padding(11)
            .liftSurface(radius: 12)

            CompactSectionHeader(title: "Recent performance")
                .accessibilityIdentifier("me.section.recentPerformance")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.rawValue)
                            .font(.subheadline.weight(.black))
                        Text("Weekly volume: \(Int(totalWeeklyVolume).formatted()) \(preferredUnit.shortLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Text("Top focus: \(topBodyPart) (\(topBodyPartPercent)% of this week)")
                            .font(.caption2)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Button {
                        selection = selection == .thisWeek ? .lastWeek : .thisWeek
                    } label: {
                        Text(selection.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.liftBlue)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(Color.liftBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selection.rawValue)
                }

                if recentLifts.isEmpty {
                    Text("No recent lifts yet. Log lifts to build your performance feed.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(recentLifts.enumerated()), id: \.element.id) { index, lift in
                            HStack(spacing: 13) {
                                Image(systemName: liftSymbol(for: lift.exerciseName))
                                    .font(.headline)
                                    .foregroundStyle(Color.liftGold)
                                    .frame(width: 42, height: 42)
                                    .background(Color.liftGold.opacity(0.11))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lift.exerciseName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                    Text(MeasurementFormatting.recordedLiftSetText(
                                        weight: lift.weight,
                                        unit: lift.unit,
                                        repetitions: lift.repetitions,
                                        includeRepLabel: true
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus, compact: true)
                                        .padding(.top, 3)
                                }

                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(11)
                            .contentShape(Rectangle())

                            if index < recentLifts.count - 1 {
                                Divider().overlay(Color.liftSeparator)
                            }
                        }
                    }
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }

                Button {
                    appState.trainingTrackerStartOnProgress = true
                    appState.requestedTrackerSegment = "Progress"
                    appState.selectedTab = 2
                } label: {
                    HStack {
                        Label("Training history", systemImage: "chart.xyaxis.line")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(13)
                    .foregroundStyle(Color.liftText)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func compactStatDivider() -> some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 40)
    }

    private func compactStat(
        title: String,
        value: String,
        unit: String,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.black))
                    .minimumScaleFactor(0.65)
                Text(unit)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func liftSymbol(for exerciseName: String) -> String {
        let normalized = exerciseName.lowercased()
        if normalized.contains("squat") { return "figure.strengthtraining.functional" }
        if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
        if normalized.contains("deadlift") { return "figure.strengthtraining.functional" }
        if normalized.contains("press") { return "dumbbell.fill" }
        return "chart.line.uptrend.xyaxis"
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
        let totalPowerlifting = appState.powerliftingTotal
        let bodyweightKilograms = RankingCalculator.poundsToKilograms(appState.currentProfile.bodyweightPounds)
        let bodyweightLogCount = appState.bodyweightEntries.reduce(0) { count, entry in
            count + (entry.actual == nil ? 0 : 1)
        }
        let liftCount = appState.currentUserLifts.count
        let closestAwardProgress = progressAwardItems(
            for: progressAchievements,
            stats: appState.competitiveStatistics,
            tierSummary: tierSummary,
            bestBench: bestBench?.normalizedWeightKilograms ?? 0,
            bestSquat: bestSquat?.normalizedWeightKilograms ?? 0,
            bestDeadlift: bestDeadlift?.normalizedWeightKilograms ?? 0,
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
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LIFT RIVALS AWARDS")
                            .font(.caption.weight(.black)).tracking(1.4)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(unlockedCount)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                            Text("unlocked").font(.headline)
                        }
                        Text("Progress summary: \(unlockedCount) earned · \(lockedCount) locked")
                            .font(.subheadline)
                        ProgressView(value: Double(unlockedCount), total: Double(max(1, achievements.count)))
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
                        CompactSectionHeader(title: "Unlocked awards (\(unlockedCount))")
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
                        CompactSectionHeader(title: "Next 3 closest awards")
                        if closestAwardProgress.isEmpty {
                            LiftEmptyState(title: "No progress data yet", message: "Keep training to reveal your closest next rewards.", symbolName: "bolt.fill")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Array(closestAwardProgress.prefix(3)), id: \.achievement.id) { item in
                                    awardTile(item.achievement, unlocked: false, status: item.status)
                                }
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
                             ? "Your tier is the highest level reached across squat, bench, and deadlift."
                             : "Log completed working sets for all three lifts to unlock your starting tier.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)

                        ForEach(tierSummary.liftProgress) { lift in
                            strengthLiftRow(lift, preferredUnit: preferredUnit)
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
                                    personalRecord("Bench", best: bestBench, preferredUnit: preferredUnit)
                                case "squat":
                                    personalRecord("Squat", best: bestSquat, preferredUnit: preferredUnit)
                                case "deadlift":
                                    personalRecord("Deadlift", best: bestDeadlift, preferredUnit: preferredUnit)
                                default:
                                    totalRecord(preferredUnit: preferredUnit)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Locked awards (\(lockedCount))")
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
        .onAppear {
            appState.refreshAchievementUnlocks()
        }
        .onChange(of: appState.completedWorkoutsRevision) {
            appState.refreshAchievementUnlocks()
        }
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

    private func totalRecord(preferredUnit: UnitSystem) -> some View {
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

    private func awardTile(_ achievement: Achievement, unlocked: Bool, status: String? = nil) -> some View {
        let display = awardDisplay(for: achievement)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(.title3.weight(.bold))
                .foregroundStyle(unlocked ? Color.liftGold : Color.liftMuted)
            Text(display.title).font(.subheadline.weight(.bold)).foregroundStyle(unlocked ? Color.liftText : Color.liftMuted).lineLimit(2)
            Text(status ?? (unlocked ? "Unlocked" : "Keep progressing"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
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
        } else if let liftMilestone = liftAwardMilestone(for: title) {
            let current = liftMilestone.exercise == "Bench" ? bestBench : (liftMilestone.exercise == "Squat" ? bestSquat : bestDeadlift)
            let target = RankingCalculator.poundsToKilograms(liftMilestone.pounds)
            metric = metricProgress(
                current: current,
                target: target,
                status: "\(formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let totalPounds = totalAwardPounds(for: title) {
            let target = RankingCalculator.poundsToKilograms(totalPounds)
            metric = metricProgress(
                current: totalPowerlifting,
                target: target,
                status: "\(formattedAwardWeight(kilograms: min(totalPowerlifting, target), unit: preferredUnit)) / \(formattedAwardWeight(kilograms: target, unit: preferredUnit))"
            )
        } else if let volumeKilograms = volumeAwardKilograms(for: title) {
            metric = metricProgress(
                current: stats.lifetimeWorkingSetVolume,
                target: volumeKilograms,
                status: "\(formattedAwardWeight(kilograms: min(stats.lifetimeWorkingSetVolume, volumeKilograms), unit: preferredUnit)) / \(formattedAwardWeight(kilograms: volumeKilograms, unit: preferredUnit))"
            )
        } else if let streakTarget = parseLeadingValue(from: title), title.contains("Workout Streak") {
            metric = metricProgress(current: Double(stats.currentStreak), target: streakTarget, status: "\(stats.currentStreak) / \(Int(streakTarget)) days")
        } else if title == "Profile Complete" {
            let profile = appState.currentProfile
            let isComplete = !profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !profile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            metric = metricProgress(current: isComplete ? 1 : 0, target: 1, status: isComplete ? "Profile complete" : "Profile not complete")
        } else if title == "1.5x Bodyweight Bench" || title == "1.5x Bodyweight Squat" || title == "2x Bodyweight Squat" ||
                    title == "2x Bodyweight Deadlift" || title == "2.5x Bodyweight Deadlift" || title == "Bodyweight Bench" {
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
                status: "\(formattedAwardWeight(kilograms: min(current, target), unit: preferredUnit)) / \(formattedAwardWeight(kilograms: target, unit: preferredUnit))"
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
                        Text("Demo mode stays local and never writes to your Supabase account.")
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
