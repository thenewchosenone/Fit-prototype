import SwiftUI

enum MeRoute: Hashable {
    case publicProfile
    case personalProfile(ProfileSection)
    case awards
    case gyms
}

struct MeHubContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingWorkoutHistory = false
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

                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                         : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                            ProfileAvatar(profile: profile, size: 64, accent: .liftAccentText)
                                .accessibilityIdentifier("me.profileHeader")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.title2.weight(.bold))
                                Text(handle)
                                    .font(.caption)
                                    .foregroundStyle(profile.username.isEmpty ? Color.liftAccentText : Color.liftMuted)
                                Text("Rival Tier · \(tierSummary.overallTier.label)")
                                    .font(LiftTypography.compactEmphasis)
                                    .foregroundStyle(Color.liftAccentText)
                            }

                            .frame(maxWidth: .infinity, alignment: .leading)

                            compactHeaderIconButton("gearshape", "Open settings", accessibilityIdentifier: "me.header.settings") {
                                appState.showingSettings = true
                            }
                        }

                        if let bio = profile.bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bio).font(.subheadline).foregroundStyle(Color.liftMuted).lineLimit(3)
                        }

                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                         : AnyLayout(HStackLayout(spacing: 24))) {
                            profileActions
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.liftMuted)
                        .buttonStyle(.plain)

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    let bestStrengthLifts = Dictionary(uniqueKeysWithValues: ["bench", "squat", "deadlift"].compactMap { exerciseID in
                        RankingCalculator.bestSubmittedLift(exerciseID: exerciseID, repetitions: 1, submissions: appState.currentUserLifts)
                            .map { (exerciseID, $0) }
                    })
                    let hasSubmittedLifts = bestStrengthLifts["bench"] != nil || bestStrengthLifts["squat"] != nil || bestStrengthLifts["deadlift"] != nil
                    DisclosureGroup("Submitted strength records") {
                        HStack {
                            Text("STRENGTH RECORD")
                                .font(.caption.weight(.semibold))
                                .tracking(1)
                                .foregroundStyle(Color.liftAccentText)
                            Spacer()
                            Button("Submit lift") { appState.showingSubmitSheet = true }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftAccentText)
                                .frame(minHeight: LiftDesign.minimumTouchTarget)
                        }
                        .accessibilityIdentifier("me.section.topLifts")
                        if hasSubmittedLifts {
                            let breakdown = RankingCalculator.powerliftingBreakdown(for: profile.id, lifts: appState.currentUserLifts)
                            Button {
                                selectedTopLiftCard = .totalStrength(breakdown)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Submitted three-lift total")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(RankingCalculator.format(MeasurementFormatting.convert(breakdown.totalKilograms, from: .kilograms, to: preferredUnit)))
                                                .font(.largeTitle.weight(.bold))
                                                .monospacedDigit()
                                            Text(preferredUnit.shortLabel)
                                                .font(.headline)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Total submitted strength, \(MeasurementFormatting.formatDisplayedWeight(breakdown.totalKilograms, unit: preferredUnit)). View breakdown")
                            .accessibilityHint("Shows the submitted one-rep-max lifts included in your total")
                        } else {
                            Text("Your strength story starts here.")
                                .font(.title3.weight(.semibold))
                            Text("Submit a one-rep max for bench press, squat, or deadlift to start your record.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Divider().overlay(Color.liftSeparator)
                        Text("Best submitted 1RM")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), alignment: .leading, spacing: 12) {
                            topLiftCardButton("Bench", exerciseID: "bench", lift: bestStrengthLifts["bench"], preferredUnit: preferredUnit)
                            topLiftCardButton("Squat", exerciseID: "squat", lift: bestStrengthLifts["squat"], preferredUnit: preferredUnit)
                            topLiftCardButton("Deadlift", exerciseID: "deadlift", lift: bestStrengthLifts["deadlift"], preferredUnit: preferredUnit)
                        }
                    }
                    .padding(20)
                    .liftSurface(radius: 18)
                    .accessibilityIdentifier("me.trainingDetails")

                    (dynamicTypeSize.isAccessibilitySize
                     ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                     : AnyLayout(HStackLayout(spacing: 0))) {
                        meHeaderStat("Workouts", trainingStats.totalWorkouts.formatted(), detail: "all time") {
                            showingWorkoutHistory = true
                        }
                        if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 28).overlay(Color.liftSeparator) }
                        meHeaderStat("Workout PRs", trainingStats.prCount.formatted(), detail: "lifetime events") {
                            openTrainingProgress(category: .strength)
                        }
                        if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 28).overlay(Color.liftSeparator) }
                        meHeaderStat("Weekly streak", "\(appState.workoutStreak())w", detail: "current") {
                            openTrainingProgress(category: .consistency)
                        }
                    }
                    .padding(.top, 2)

                    CompactSectionHeader(title: "Your training")
                        .accessibilityIdentifier("me.section.awardsHistory")
                    VStack(spacing: 0) {
                        NavigationLink(value: MeRoute.awards) {
                            meRow("Rival tier & awards", "Strength milestones, records, and progress", "trophy.fill")
                        }
                        .accessibilityIdentifier("me.awards")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.personalProfile(.history)) {
                            meRow("Workout history", "Your private completed workouts", "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("me.workoutHistory")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.personalProfile(.submissions)) {
                            meRow("Lift submissions", "All attempts, evidence, and sharing", "chart.xyaxis.line")
                        }
                        .accessibilityIdentifier("me.personalProfile")
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        Button {
                            openTrainingProgress(category: appState.currentProfile.trainingFocus?.startingCategory ?? .consistency)
                        } label: {
                            meRow("Training progress", "Consistency, strength, muscle, and body trends", "chart.line.uptrend.xyaxis")
                        }
                        Divider().overlay(Color.liftSeparator).padding(.leading, 66)
                        NavigationLink(value: MeRoute.gyms) {
                            meRow(
                                "Gyms",
                                "Primary: \(appState.currentProfile.primaryGymName.isEmpty ? "none selected" : appState.currentProfile.primaryGymName) · \(appState.joinedGymCount) joined",
                                "building.2.fill"
                            )
                        }
                        .accessibilityIdentifier("me.gyms")
                    }
                    .buttonStyle(.plain)
                    .liftSurface(radius: 18)

                }
                .padding(.horizontal, LiftDesign.screenHorizontalPadding)
                .padding(.vertical, 20)
                .padding(.bottom, 24)
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
        .sheet(isPresented: $showingWorkoutHistory) {
            NavigationStack {
                ProfileView(profile: appState.currentProfile, surface: .personal, initialSection: .history)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close", systemImage: "xmark") { showingWorkoutHistory = false }.labelStyle(.iconOnly)
                        }
                    }
            }
        }
        .sheet(item: $selectedTopLiftCard) { destination in
            TopLiftCardDetailSheet(destination: destination)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var profileActions: some View {
        Button {
            appState.showingEditProfile = true
        } label: {
            Label("Edit profile", systemImage: "pencil")
        }
        .frame(minWidth: LiftDesign.minimumTouchTarget, minHeight: LiftDesign.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel("Edit athlete profile")
        .accessibilityIdentifier("me.header.editProfile")
        NavigationLink(value: MeRoute.publicProfile) {
            Label("Public preview", systemImage: "arrow.up.right")
        }
        .frame(minWidth: LiftDesign.minimumTouchTarget, minHeight: LiftDesign.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel("Preview public profile")
        .accessibilityIdentifier("me.publicProfile")
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
            topLiftCard(title, lift: lift, preferredUnit: preferredUnit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lift == nil ? "View past \(title.lowercased()) workout lifts" : "View submitted \(title.lowercased()) lift")
        .accessibilityValue(lift.map { "\(MeasurementFormatting.formatDisplayedWeight($0.normalizedWeightKilograms, unit: preferredUnit)), \($0.resolvedEvidenceStatus.displayName)" } ?? "No submitted one-rep max")
        .accessibilityHint(lift == nil ? "Shows matching workout sets and lets you submit one" : "Shows details for this submitted lift")
    }

    private func openTrainingProgress(category: TrackerProgressCategory) {
        appState.router.progressCategory = category
        appState.trainingTrackerStartOnProgress = true
        appState.requestedTrackerSegment = "Progress"
        appState.selectedTab = 2
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
        .frame(width: LiftDesign.minimumTouchTarget, height: LiftDesign.minimumTouchTarget)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func meHeaderStat(_ title: String, _ value: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Text(title).font(.caption)
                HStack(spacing: 3) {
                    Text(detail)
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.liftText)
        .accessibilityElement(children: .combine)
        .accessibilityHint(title == "Workouts" ? "Opens workout history" : "Opens matching training progress")
    }

    private func topLiftCard(_ title: String, lift: LiftSubmission?, preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title).font(.caption).foregroundStyle(Color.liftMuted)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
                    .accessibilityHidden(true)
            }
            Text(lift.map { MeasurementFormatting.formatDisplayedWeight($0.normalizedWeightKilograms, unit: preferredUnit) } ?? "—")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(lift?.resolvedEvidenceStatus.displayName ?? "No submitted 1RM")
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, badge: String? = nil) -> some View {
        meRow(title, subtitle, symbol, badge: badge, isDestructive: false)
    }

    private func meRow(_ title: String, _ subtitle: String, _ symbol: String, badge: String? = nil, isDestructive: Bool = false) -> some View {
        let iconColor = isDestructive ? Color.liftRed : Color.liftMuted
        let textColor = isDestructive ? Color.liftRed : Color.liftText
        let chevronColor = isDestructive ? Color.liftRed : Color.liftMuted
        return HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(LiftTypography.rowEmphasis)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(LiftTypography.rowEmphasis).foregroundStyle(textColor)
                Text(subtitle).font(.caption).foregroundStyle(Color.liftMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if dynamicTypeSize.isAccessibilitySize, let badge {
                    Text(badge).font(LiftTypography.compactEmphasis).foregroundStyle(Color.liftGold)
                }
            }
            Spacer(minLength: 8)
            if let badge, !dynamicTypeSize.isAccessibilitySize {
                Text(badge)
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftGold)
            }
            Image(systemName: "chevron.right")
                .font(LiftTypography.compactEmphasis)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedAward: Achievement?
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
        let unlockDates = appState.achievementUnlocks.reduce(into: [String: Date]()) { dates, unlock in
            dates[unlock.title] = unlock.unlockedAt
        }
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
        let featuredGoals = Array(closestAwardProgress.prefix(3))
        let featuredGoalTitles = Set(featuredGoals.map { $0.achievement.title })
        let otherProgressAchievements = progressAchievements.filter { !featuredGoalTitles.contains($0.title) }
        let unlockedCount = unlockedAchievements.count
        let lockedCount = progressAchievements.count
        let otherAwardCount = otherProgressAchievements.count
        let visibleOtherAwards = showsAllLockedAwards ? otherProgressAchievements : Array(otherProgressAchievements.prefix(8))
        let otherAwardGroups = Dictionary(grouping: visibleOtherAwards, by: awardGroup(for:))
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if appState.isLoadingInitialTrainingData && unlockedCount == 0 {
                        ProgressView("Loading awards…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("awards.loading")
                    } else if unlockedCount == 0 && appState.workoutSyncStore.historySyncState == .needsAttention {
                        LiftEmptyState(
                            title: "Awards unavailable",
                            message: "Your workout history couldn’t sync.",
                            symbolName: "wifi.exclamationmark",
                            actionTitle: "Retry",
                            action: { Task { await appState.synchronizeCompletedWorkoutHistory() } }
                        )
                    } else {
                    HStack {
                        Label("\(unlockedCount) earned", systemImage: "medal.fill")
                        Spacer()
                        Text("\(lockedCount) remaining").foregroundStyle(Color.liftMuted)
                    }
                    .font(.subheadline.weight(.semibold))

                    rivalTierCard(tierSummary, preferredUnit: preferredUnit)

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Closest awards")
                        if closestAwardProgress.isEmpty {
                            LiftEmptyState(title: "No progress data yet", message: "Keep training to see your next awards.", symbolName: "chart.xyaxis.line")
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                                ForEach(featuredGoals, id: \.achievement.id) { item in
                                    awardTile(item.achievement, unlocked: false, status: item.status)
                                }
                            }
                        }
                    }

                    DisclosureGroup("Earned awards (\(unlockedCount))") {
                        if unlockedAchievements.isEmpty {
                            LiftEmptyState(title: "No awards yet", message: "Complete workouts and log lifts to unlock your first award.", symbolName: "medal.fill")
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                                ForEach(showsAllUnlockedAwards ? unlockedAchievements : Array(unlockedAchievements.prefix(8))) { achievement in
                                    awardTile(achievement, unlocked: true, earnedAt: unlockDates[achievement.title])
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

                    NavigationLink("Milestone timeline") {
                        ProfileView(profile: appState.currentProfile, surface: .personal, initialSection: .timeline)
                    }.frame(minHeight: 44)
                    if let rivalTierShareImage {
                        ShareLink(
                            item: rivalTierShareImage,
                            preview: SharePreview(
                                "\(appState.currentProfile.displayName)'s Rival Tier",
                                image: rivalTierShareImage
                            )
                        ) {
                            Label("Share Rival Tier card", systemImage: "square.and.arrow.up")
                                .font(LiftTypography.cardTitle)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .foregroundStyle(Color.liftBackground)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    } else {
                        Button {
                            prepareRivalTierShareImage(summary: tierSummary)
                        } label: {
                            Label("Retry tier card", systemImage: "square.and.arrow.up")
                                .font(LiftTypography.cardTitle)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftGold)
                        .foregroundStyle(Color.liftBackground)
                        .accessibilityIdentifier("awards.shareRivalTier")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactSectionHeader(title: "Personal records")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
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

                    DisclosureGroup("Other awards (\(otherAwardCount))") {
                        ForEach(otherAwardGroups, id: \.key) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.key)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                                    ForEach(group.value) { achievement in
                                        awardTile(achievement, unlocked: false)
                                    }
                                }
                            }
                        }
                        if otherAwardCount > 8 {
                            Button(showsAllLockedAwards ? "Show fewer" : "Show all \(otherAwardCount) other awards") {
                                showsAllLockedAwards.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                        }
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
        .task(id: tierSummary) { prepareRivalTierShareImage(summary: tierSummary) }
        .sheet(item: $selectedAward) { achievement in
            let display = MeasurementFormatting.awardDisplay(for: achievement, unit: appState.currentProfile.preferredUnit)
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(display.title).font(.title2.bold())
                        Text(display.description)
                        if let date = appState.achievementUnlocks.first(where: { $0.title == achievement.title })?.unlockedAt {
                            Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }.padding(20)
                }
                .navigationTitle("Award details")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { selectedAward = nil }.labelStyle(.iconOnly) } }
            }.presentationDetents([.medium, .large])
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
                    .font(LiftTypography.rowEmphasis)
                Spacer()
                Text(lift.estimatedOneRepMaxKilograms == nil ? "Not logged" : lift.currentTier.label)
                    .font(LiftTypography.compactEmphasis)
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
            selectedLiftHistory = best.map { .submitted($0) } ?? .exerciseHistory(id: exerciseID, name: title)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(Color.liftGold)
                Text(title.uppercased()).font(LiftTypography.compactEmphasis).foregroundStyle(Color.liftMuted)
                Text(valueKilograms.map {
                    MeasurementFormatting.formatDisplayedWeight($0, unit: preferredUnit)
                } ?? "—")
                    .font(LiftTypography.cardTitle)
                Text(best != nil ? "Best submitted lift" : workoutEstimate != nil ? "Estimated 1RM from workouts" : "No workout lift yet")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(title) \(best != nil ? "submitted lift" : "workout history")")
        .accessibilityHint("Opens the evidence for this record")
    }

    private func totalRecord(preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Color.liftGold)
            Text("Total").font(LiftTypography.compactEmphasis).foregroundStyle(Color.liftMuted)
            Text(RankingFormatting.threeLiftTotalText(
                totalPounds: appState.powerliftingTotal,
                preferredUnit: preferredUnit
            ))
            .font(LiftTypography.cardTitle)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
    }

    private func awardTile(_ achievement: Achievement, unlocked: Bool, status: String? = nil, earnedAt: Date? = nil) -> some View {
        let display = MeasurementFormatting.awardDisplay(for: achievement, unit: appState.currentProfile.preferredUnit)
        let isGoal = status != nil
        return Button { selectedAward = achievement } label: {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: achievement.symbolName)
                .font(LiftTypography.sectionTitle)
                .foregroundStyle(unlocked || isGoal ? Color.liftGold : Color.liftMuted)
                .accessibilityHidden(true)
            Text(display.title).font(LiftTypography.rowEmphasis).foregroundStyle(unlocked || isGoal ? Color.liftText : Color.liftMuted).lineLimit(2)
                .accessibilityLabel("\(display.title), \(unlocked ? "earned" : "locked")")
            if let status {
                Text(status).font(.caption.weight(.semibold)).foregroundStyle(Color.liftAccentText)
            } else if unlocked, let earnedAt {
                Text("Earned \(earnedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
            } else if !unlocked {
                Text(display.description).font(.caption2).foregroundStyle(Color.liftMuted).lineLimit(2)
            }
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).liftSurface()
        }.buttonStyle(.plain)
    }

    private func awardGroup(for achievement: Achievement) -> String {
        let title = achievement.title
        if title.contains("Verified") { return "Verified lifts" }
        if title.contains("Workouts") || title.contains("Workout") || title.contains("Training Hours") || title.contains("Reps") {
            return "Training milestones"
        }
        if MeasurementFormatting.liftAwardMilestone(for: title) != nil ||
            MeasurementFormatting.totalAwardPounds(for: title) != nil || title.hasSuffix(" Rival") {
            return "Strength milestones"
        }
        return "Other milestones"
    }

    private func rivalTierCard(_ tierSummary: StrengthTierSummary, preferredUnit: UnitSystem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RIVAL TIER")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.liftGold)
                    Text(tierSummary.overallTier.label)
                        .font(.title.weight(.bold))
                }
                Spacer()
                Image(systemName: "medal.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.liftGold)
            }
            Text(tierSummary.completedRequiredLiftCount == tierSummary.requiredLiftCount
                 ? "Your Rival Tier is set by your lowest tier across squat, bench press, and deadlift."
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
                .accessibilityHint("Opens the evidence for this record")
            }
        }
        .padding(14)
        .liftSurface(radius: 12)
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
                        .font(.system(size: 18, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.liftGold)
                    Text(profile.displayName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text("@\(profile.username)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "medal.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.liftGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RIVAL TIER")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(summary.overallTier.label)
                    .font(.system(size: 58, weight: .bold))
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
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.liftGold)
                    }
                    .padding(16)
                    .background(Color.liftOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Spacer()
            Text("TRAIN. PROVE. RISE.")
                .font(.system(size: 15, weight: .bold))
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

struct FriendRequestsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var requests: [FriendRequest] = []
    @State private var searchText = ""
    @State private var results: [UserProfile] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        List {
            if let message {
                Section {
                    Text(message).foregroundStyle(Color.liftRed)
                    Button("Retry") { Task { await load() } }
                }
            }
            if isLoading { ProgressView() }
            if !results.isEmpty {
                Section("Find friends") {
                    ForEach(results) { profile in
                        HStack {
                            Text(profile.displayName)
                            Spacer()
                            if requests.contains(where: { $0.userID == profile.id }) {
                                Text("Connected or pending").font(.caption).foregroundStyle(Color.liftMuted)
                            } else {
                                Button("Add friend") {
                                    Task { await sendRequest(to: profile.id) }
                                }.disabled(isSaving)
                            }
                        }
                    }
                }
            }
            Section("Friends and requests") {
                if !isLoading && requests.isEmpty {
                    Text("Search a lifter’s name to send a friend request.")
                        .foregroundStyle(Color.liftMuted)
                }
                ForEach(requests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.displayName).font(.headline)
                        if request.isAccepted {
                            Text("Friends").foregroundStyle(Color.liftMuted)
                        } else if request.isIncoming {
                            HStack {
                                Button("Accept") { Task { await respond(to: request, accept: true) } }
                                Button("Decline", role: .destructive) { Task { await respond(to: request, accept: false) } }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSaving)
                        } else {
                            Text("Request sent").foregroundStyle(Color.liftMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $searchText, prompt: "Find lifters")
        .onSubmit(of: .search) {
            Task {
                let accountID = appState.currentProfile.id
                let loaded = await appState.searchAthletes(searchText)
                guard appState.currentProfile.id == accountID else { return }
                results = loaded
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
            }
        }
        .task(id: appState.currentProfile.id) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let accountID = appState.currentProfile.id
        isLoading = true
        message = nil
        requests = []
        results = []
        do {
            let loaded = try await appState.accountSocialStore.friendRequests()
            guard appState.currentProfile.id == accountID else { return }
            requests = loaded
        } catch {
            guard appState.currentProfile.id == accountID else { return }
            message = appState.userMessage(error)
        }
        isLoading = false
    }

    private func sendRequest(to userID: UUID) async {
        let accountID = appState.currentProfile.id
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.accountSocialStore.requestFriendship(userID: userID)
            guard appState.currentProfile.id == accountID else { return }
            await load()
        } catch {
            guard appState.currentProfile.id == accountID else { return }
            message = appState.userMessage(error)
        }
    }

    private func respond(to request: FriendRequest, accept: Bool) async {
        let accountID = appState.currentProfile.id
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.accountSocialStore.respondToFriendship(id: request.id, accept: accept)
            guard appState.currentProfile.id == accountID else { return }
            await load()
        } catch {
            guard appState.currentProfile.id == accountID else { return }
            message = appState.userMessage(error)
        }
    }
}
