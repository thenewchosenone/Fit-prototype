import AVKit
import SwiftUI

private extension View {
    func homePanelStyle() -> some View {
        liftSurface()
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingNotifications = false
    @State private var showingStreak = false
    @State private var showingActiveWorkout = false
    @State private var showingAwards = false
    @State private var selectedBodyweightEntry: BodyweightEntry?
    @State private var selectedRecentPR: LiftSubmission?
    @State private var homeContentWidth: CGFloat = 0

    private struct WeeklyPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let day: String
        let count: Int
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    workoutStatus
                    balancedOverview
                    quickStats
                    highlights
                    recentPRs
                    weeklyActivity
                }
                .padding(.horizontal, LiftDesign.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 116)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNotifications) {
            HomeNotificationCenterView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingStreak) {
            StreakDetailView(streakDays: appState.workoutStreak())
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedBodyweightEntry) { entry in
            BodyweightEntryEditor(entry: entry) { updatedEntry in
                appState.updateBodyweight(updatedEntry)
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            WorkoutSessionRunView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingAwards) {
            NavigationStack { AwardsView() }
                .environmentObject(appState)
        }
        .sheet(item: $selectedRecentPR) { lift in
            RecentPRDetailView(lift: lift)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var workoutStatus: some View {
        if let active = appState.activeWorkout {
            Button {
                showingActiveWorkout = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: active.pausedAt == nil ? "dumbbell.fill" : "pause.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.liftBackground)
                        .frame(width: 48, height: 48)
                        .background(Color.liftGold)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORKOUT IN PROGRESS")
                            .font(.caption2.weight(.black))
                            .tracking(1.1)
                            .foregroundStyle(Color.liftGold)
                        Text(active.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.liftText)
                        Text(active.pausedAt == nil ? "Keep your sets and timer moving" : "Paused — ready when you are")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer(minLength: 8)
                    Text("Resume")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color.liftGold)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftGold)
                }
                .padding(16)
                .contentShape(Rectangle())
                .liftSurface()
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.liftGold.opacity(0.35), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume active workout, \(active.name)")
            .accessibilityIdentifier("home.activeWorkout.resume")
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    headerIdentity
                    headerActions
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    headerIdentity
                    Spacer(minLength: 8)
                    headerActions
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var headerIdentity: some View {
        HStack(spacing: 12) {
            Button {
                appState.selectedTab = 4
            } label: {
                ProfileAvatar(profile: appState.currentProfile, size: 44)
                    .overlay {
                        Circle()
                            .stroke(Color.liftBlue.opacity(0.75), lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")

            VStack(alignment: .leading, spacing: 3) {
                Text(greeting.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(Color.liftBlue)
                    .lineLimit(2)
                Text(appState.currentProfile.displayName)
                    .font(.title3.weight(.black))
                    .lineLimit(2)
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.light()
                showingStreak = true
            } label: {
                statusPill(symbol: "flame.fill", value: "\(appState.workoutStreak())", tint: .orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(appState.workoutStreak()) day streak details")

            NativeIconButton(
                symbolName: "bell.fill",
                accessibilityLabel: "Notifications, \(appState.unreadNotificationCount) unread",
                badge: appState.unreadNotificationCount
            ) {
                showingNotifications = true
            }

            NativeIconButton(symbolName: "gearshape.fill", accessibilityLabel: "Open settings") {
                appState.showingSettings = true
            }
        }
    }

    private func statusPill(symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.black))
        }
        .padding(.horizontal, 11)
        .frame(minWidth: 44, minHeight: 44)
        .background(Color.liftCard)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.liftSeparator, lineWidth: 1)
        }
        .accessibilityLabel("\(value) day streak")
    }

    private var balancedOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Overview")

            if usesStackedOverview {
                VStack(spacing: 12) {
                    trainingOverviewCard
                    strengthOverviewCard
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    trainingOverviewCard
                    strengthOverviewCard
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            homeContentWidth = width
        }
    }

    private var usesStackedOverview: Bool {
        dynamicTypeSize.isAccessibilitySize || (homeContentWidth > 0 && homeContentWidth < 340)
    }

    private var trainingOverviewCard: some View {
        let balance = appState.strengthBalance(for: 1)
        let today = scheduledWorkoutToday

        return Button {
            appState.requestedTrackerSegment = "Today"
            appState.trainingTrackerStartOnProgress = false
            appState.selectedTab = 2
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftBlue)
                    Spacer()
                    Image(systemName: today == nil ? "bed.double.fill" : "play.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftBackground)
                        .frame(width: 36, height: 36)
                        .background(Color.liftBlue)
                        .clipShape(Circle())
                }

                Text(todayWorkoutTitle)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Color.liftText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(todayWorkoutSubtitle(today))
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)

                Spacer(minLength: 2)

                Label(today == nil ? "Open Programs" : "Focus: \(balance.weakest)", systemImage: today == nil ? "list.bullet.rectangle" : "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scheduledWorkoutToday == nil ? "Rest day, open programs" : "Open today's training, \(todayWorkoutTitle)")
    }

    private var todayWorkoutTitle: String {
        scheduledWorkoutToday?.workout ?? "Rest Day"
    }

    private func todayWorkoutSubtitle(_ workout: WorkoutDaySummary?) -> String {
        guard let workout else { return "No workout scheduled today" }
        return "\(appState.selectedWorkoutPlan?.name ?? "Workout plan") • \(workout.exercises) exercises"
    }

    private var scheduledWorkoutToday: WorkoutDaySummary? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let weekdayNames = Calendar.current.weekdaySymbols
        guard weekday > 0, weekday <= weekdayNames.count else { return nil }
        let todayName = weekdayNames[weekday - 1]
        return appState.workoutDays(for: 1).first { $0.day.caseInsensitiveCompare(todayName) == .orderedSame }
    }

    private var strengthOverviewCard: some View {
        Button {
            appState.selectedTab = 1
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STRENGTH")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftBlue)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftGold)
                        .accessibilityLabel("Competition verified")
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(appState.overallScore))")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liftText)
                    Text("score")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }

                Text("Advanced")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Color.liftText)

                Spacer(minLength: 2)

                HStack {
                    Label("Gym #4", systemImage: "building.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open leaderboards, strength score \(Int(appState.overallScore)), Advanced, gym rank 4")
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            compactStat(
                title: "Total",
                value: "\(Int(appState.powerliftingTotal))",
                unit: "lb",
                symbol: "dumbbell.fill",
                tint: .liftBlue
            )
            statDivider
            compactStat(
                title: "Bodyweight",
                value: "\(Int(appState.currentProfile.bodyweightPounds))",
                unit: "lb",
                symbol: "scalemass.fill",
                tint: .liftBlue
            )
            statDivider
            compactStat(
                title: "Relative",
                value: String(format: "%.2f", appState.relativeTotal),
                unit: "x",
                symbol: "bolt.fill",
                tint: .liftBlue
            )
        }
        .padding(14)
        .liftSurface()
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Quick actions")
            HStack(spacing: 12) {
                highlightButton("Log workout", "dumbbell.fill", Color.liftBlue) {
                    appState.requestedTrackerSegment = "Today"
                    appState.trainingTrackerStartOnProgress = false
                    appState.selectedTab = 2
                }
                highlightButton("Bodyweight", "scalemass.fill", Color.liftGold) {
                    selectedBodyweightEntry = appState.bodyweightEntries.last ?? BodyweightEntry(
                        id: UUID(), week: 1, targetDate: .now,
                        actual: appState.currentProfile.bodyweightPounds, notes: ""
                    )
                }
                highlightButton("Awards", "trophy.fill", Color.liftGreen) {
                    showingAwards = true
                }
            }
        }
    }

    private func highlightButton(_ title: String, _ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .padding(13)
            .liftSurface(radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.quickAction.\(title.replacingOccurrences(of: " ", with: "").lowercased())")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 48)
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

    private var recentPRs: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Recent PRs", actionTitle: "Submit lift") {
                appState.showingSubmitSheet = true
            }

                VStack(spacing: 0) {
                    ForEach(Array(appState.currentUserLifts.prefix(3).enumerated()), id: \.element.id) { index, lift in
                        Button {
                            selectedRecentPR = lift
                        } label: {
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
                                    Text("\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) × \(lift.repetitions) \(lift.repetitions == 1 ? "rep" : "reps")")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    compactVerificationBadge(for: lift.verificationStatus)
                                        .padding(.top, 3)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(lift.exerciseName) PR, \(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel), \(lift.verificationStatus.rawValue)")
                        .accessibilityHint(liftHasVideo(lift) ? "Shows PR video and attempt details" : "Shows the workout set and attempt details")

                        if index < min(2, appState.currentUserLifts.count - 1) {
                            Divider()
                                .overlay(Color.liftSeparator)
                        }
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homePanelStyle()
        }
    }

    private func compactVerificationBadge(for status: VerificationStatus) -> some View {
        let badge = VerificationBadge(status: status)
        let label: String
        let symbol: String
        switch status {
        case .selfReported:
            label = "Self-reported"
            symbol = "person.fill"
        case .videoSubmitted:
            label = "Video submitted"
            symbol = "video.fill"
        case .videoVerified:
            label = "Video-backed"
            symbol = "video.badge.checkmark"
        case .communityVerified:
            label = "Community verified"
            symbol = "person.3.fill"
        case .competitionVerified:
            label = "Competition verified"
            symbol = "trophy.fill"
        case .rejected:
            label = "Rejected"
            symbol = "xmark.seal.fill"
        }

        return Label(label, systemImage: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(badge.color)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(badge.color.opacity(0.13))
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Verification status: \(label)")
    }

    private func liftHasVideo(_ lift: LiftSubmission) -> Bool {
        lift.demoMediaID != nil || lift.localVideoURL != nil || lift.remoteVideoURL != nil
    }

    private func liftSymbol(for exerciseName: String) -> String {
        let normalized = exerciseName.lowercased()
        if normalized.contains("squat") { return "figure.strengthtraining.functional" }
        if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Training this week", actionTitle: "Details") {
                openWeeklyProgress()
            }

            Button {
                openWeeklyProgress()
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(thisWeekWorkoutCount)/\(plannedWorkoutCount)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Color.liftText)
                        Text("workouts")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                        Spacer(minLength: 8)
                        Text(weeklyStatusText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(weeklyStatusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(weeklyStatusColor.opacity(0.11))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 0) {
                        weeklyMetric(
                            value: Int(thisWeekVolume).formatted(),
                            label: "\(appState.currentProfile.preferredUnit.shortLabel) VOLUME"
                        )
                        weeklyDivider
                        weeklyMetric(value: formattedWeeklyDuration, label: "TRAINING TIME")
                        weeklyDivider
                        weeklyMetric(value: "\(thisWeekCompletedSetCount)", label: "WORKING SETS")
                    }

                    HStack(spacing: 0) {
                        ForEach(weeklyPoints) { point in
                            VStack(spacing: 7) {
                                Text(point.day)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Calendar.current.isDateInToday(point.date) ? Color.liftBlue : Color.liftMuted)
                                ZStack {
                                    Circle()
                                        .fill(point.count > 0 ? Color.liftBlue : Color.liftSeparator)
                                        .frame(width: 30, height: 30)
                                    if point.count > 0 {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.black))
                                            .foregroundStyle(.white)
                                    } else {
                                        Circle()
                                            .fill(Color.liftMuted.opacity(0.55))
                                            .frame(width: 4, height: 4)
                                    }
                                    if Calendar.current.isDateInToday(point.date) {
                                        Circle()
                                            .stroke(Color.liftBlue, lineWidth: 2)
                                            .frame(width: 36, height: 36)
                                    }
                                }
                                .accessibilityLabel("\(point.day), \(point.count > 0 ? "workout completed" : "no completed workout")")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homePanelStyle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open weekly training progress, \(thisWeekWorkoutCount) of \(plannedWorkoutCount) workouts, \(thisWeekCompletedSetCount) completed working sets")
        }
    }

    private func weeklyMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.black).monospacedDigit())
                .foregroundStyle(Color.liftText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.45)
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 36)
            .padding(.horizontal, 9)
    }

    private func openWeeklyProgress() {
        appState.trainingTrackerStartOnProgress = true
        appState.requestedTrackerSegment = "Progress"
        appState.selectedTab = 2
    }

    private var communityHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Community highlights", actionTitle: "Open") {
                appState.selectedTab = 3
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.activities.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ProfileAvatar(profile: item.profile, size: 40)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(Color.liftText)
                                .lineLimit(2)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        .frame(width: 210, height: 126, alignment: .leading)
                        .padding(16)
                        .liftSurface()
                    }
                }
            }
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private func dashboardSectionHeader(
        _ title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        CompactSectionHeader(title: title, actionTitle: actionTitle, action: action)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var weeklyPoints: [WeeklyPoint] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: interval.start) ?? interval.start
            let count = thisWeekPlanWorkouts
                .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
                .count
            return WeeklyPoint(date: date, day: symbols[offset], count: count)
        }
    }

    private var thisWeekPlanWorkouts: [CompletedWorkout] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return appState.completedWorkouts.filter {
            interval.contains($0.completedAt) &&
                $0.sourcePlanID == appState.selectedWorkoutPlanID &&
                !$0.completedWorkingSets.isEmpty
        }
    }

    private var plannedWorkoutCount: Int {
        guard let week = appState.currentSelectedProgramWeek else { return 0 }
        return appState.sessions(for: week).count
    }

    private var thisWeekWorkoutCount: Int {
        thisWeekPlanWorkouts.count
    }

    private var thisWeekCompletedSetCount: Int {
        thisWeekPlanWorkouts.flatMap(\.completedWorkingSets).count
    }

    private var thisWeekVolume: Double {
        thisWeekPlanWorkouts.flatMap(\.completedWorkingSets).reduce(0) { total, set in
            guard let weight = set.weight, let reps = set.reps else { return total }
            let displayedWeight: Double
            if set.recordedUnit == appState.currentProfile.preferredUnit {
                displayedWeight = weight
            } else if appState.currentProfile.preferredUnit == .kilograms {
                displayedWeight = RankingCalculator.poundsToKilograms(weight)
            } else {
                displayedWeight = RankingCalculator.kilogramsToPounds(weight)
            }
            return total + displayedWeight * Double(reps)
        }
    }

    private var formattedWeeklyDuration: String {
        let minutes = Int(thisWeekPlanWorkouts.reduce(0) { $0 + $1.duration } / 60)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    private var weeklyStatusText: String {
        guard plannedWorkoutCount > 0 else { return "No plan" }
        if thisWeekWorkoutCount >= plannedWorkoutCount { return "Complete" }
        if thisWeekWorkoutCount > 0 { return "In progress" }
        return "Not started"
    }

    private var weeklyStatusColor: Color {
        guard plannedWorkoutCount > 0 else { return .liftMuted }
        if thisWeekWorkoutCount >= plannedWorkoutCount { return .liftGreen }
        return thisWeekWorkoutCount > 0 ? .liftBlue : .liftMuted
    }
}

private struct RecentPRSetContext {
    let workout: CompletedWorkout
    let exercise: WorkoutExerciseSnapshot
    let set: WorkoutSetLog
}

private struct RecentPRDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let lift: LiftSubmission

    private var videoURL: URL? {
        lift.localVideoURL ?? lift.remoteVideoURL
    }

    private var setContext: RecentPRSetContext? {
        let linked = appState.completedWorkouts.filter { $0.linkedSubmissionIDs.contains(lift.id) }
        for workout in linked {
            if let context = matchingContext(in: workout, requiresExactMatch: false) { return context }
        }

        return appState.completedWorkouts
            .filter { abs($0.completedAt.timeIntervalSince(lift.performedAt)) <= 172_800 }
            .sorted { abs($0.completedAt.timeIntervalSince(lift.performedAt)) < abs($1.completedAt.timeIntervalSince(lift.performedAt)) }
            .compactMap { matchingContext(in: $0, requiresExactMatch: true) }
            .first
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        attemptHeader

                        if let mediaID = lift.demoMediaID {
                            DemoMediaCard(
                                title: lift.exerciseName,
                                subtitle: "\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) × \(lift.repetitions)",
                                mediaID: mediaID,
                                badge: "PR Video"
                            )
                        } else if let videoURL {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PR video")
                                    .font(.headline.weight(.bold))
                                VideoPlayer(player: AVPlayer(url: videoURL))
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .padding(14)
                            .liftSurface()
                        }

                        if let setContext {
                            workoutSetCard(setContext)
                        } else if lift.demoMediaID == nil && videoURL == nil {
                            LiftEmptyState(
                                title: "Workout set unavailable",
                                message: "This PR was not linked to a completed workout and has no video attached.",
                                symbolName: "link.badge.plus"
                            )
                        }

                        attemptDetails
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("PR details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var attemptHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Color.liftGold)
                    .frame(width: 46, height: 46)
                    .background(Color.liftGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(lift.exerciseName)
                        .font(.headline.weight(.black))
                    Text(lift.performedAt.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(RankingCalculator.format(lift.weight))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text(lift.unit.shortLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
                Text("× \(lift.repetitions) \(lift.repetitions == 1 ? "rep" : "reps")")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }

            VerificationBadge(status: lift.verificationStatus)
        }
        .padding(16)
        .liftSurface()
    }

    private func workoutSetCard(_ context: RecentPRSetContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PR workout set")
                        .font(.headline.weight(.bold))
                    Text("\(context.workout.name) · \(context.workout.completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.liftBlue)
            }

            HStack(spacing: 12) {
                Text(context.set.isWarmup ? "W" : "\(context.set.setNumber)")
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 34, height: 34)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.exercise.exerciseName)
                        .font(.subheadline.weight(.bold))
                    Text("Set \(context.set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(RankingCalculator.format(context.set.weight ?? 0)) \(context.set.recordedUnit.shortLabel) × \(context.set.reps ?? 0)")
                        .font(.subheadline.weight(.black).monospacedDigit())
                    if let rpe = context.set.rpe {
                        Text("RPE \(rpe)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftBlue)
                    }
                }
            }
            .padding(12)
            .background(Color.liftCardRaised.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            NavigationLink {
                CompletedWorkoutDetailView(workout: context.workout)
                    .environmentObject(appState)
            } label: {
                Label("View full workout", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiftSecondaryButtonStyle())
        }
        .padding(14)
        .liftSurface()
    }

    private var attemptDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attempt details")
                .font(.headline.weight(.bold))
            detailRow("Bodyweight", "\(RankingCalculator.format(lift.bodyweightAtLift)) lb")
            detailRow("Relative strength", String(format: "%.2fx", lift.bodyweightMultiple))
            detailRow("Evidence", lift.resolvedEvidenceStatus.rawValue)
            detailRow("Review status", lift.resolvedModerationStatus.rawValue)
        }
        .padding(14)
        .liftSurface()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func matchingContext(in workout: CompletedWorkout, requiresExactMatch: Bool) -> RecentPRSetContext? {
        let exercises = workout.exercises.filter(exerciseMatchesLift)
        let candidates = exercises.flatMap { exercise in
            workout.sets
                .filter { $0.prescriptionID == exercise.id && $0.isComplete && !$0.isWarmup }
                .map { RecentPRSetContext(workout: workout, exercise: exercise, set: $0) }
        }
        guard !candidates.isEmpty else { return nil }

        if let exact = candidates.first(where: { context in
            context.set.reps == lift.repetitions && abs(setWeightInPounds(context.set) - liftWeightInPounds) < 0.6
        }) {
            return exact
        }
        guard !requiresExactMatch else { return nil }
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(setWeightInPounds(lhs.set) - liftWeightInPounds) + Double(abs((lhs.set.reps ?? 0) - lift.repetitions) * 20)
            let rhsDistance = abs(setWeightInPounds(rhs.set) - liftWeightInPounds) + Double(abs((rhs.set.reps ?? 0) - lift.repetitions) * 20)
            return lhsDistance < rhsDistance
        }
    }

    private func exerciseMatchesLift(_ exercise: WorkoutExerciseSnapshot) -> Bool {
        if exercise.exerciseID == lift.exerciseID || exercise.rankingExerciseID == lift.exerciseID { return true }
        let exerciseName = exercise.exerciseName.lowercased().filter(\.isLetter)
        let liftName = lift.exerciseName.lowercased().filter(\.isLetter)
        return exerciseName == liftName
    }

    private var liftWeightInPounds: Double {
        lift.unit == .pounds ? lift.weight : RankingCalculator.kilogramsToPounds(lift.weight)
    }

    private func setWeightInPounds(_ set: WorkoutSetLog) -> Double {
        guard let weight = set.weight else { return 0 }
        return set.recordedUnit == .pounds ? weight : RankingCalculator.kilogramsToPounds(weight)
    }
}

private struct HomeNotificationCenterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if appState.notifications.isEmpty {
                            emptyState
                        } else {
                            ForEach(appState.notifications.sorted(by: { $0.createdAt > $1.createdAt })) { notification in
                                Button {
                                    appState.openNotification(notification)
                                    dismiss()
                                } label: {
                                    notificationRow(notification)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(accessibilityHint(for: notification))
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if appState.unreadNotificationCount > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Read all") {
                            appState.markAllNotificationsRead()
                        }
                    }
                }
            }
        }
    }

    private func notificationRow(_ notification: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol(for: notification.kind))
                .font(.headline.weight(.bold))
                .foregroundStyle(tint(for: notification.kind))
                .frame(width: 44, height: 44)
                .background(tint(for: notification.kind).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(Color.liftText)
                    Spacer()
                    if !notification.isRead {
                        Circle()
                            .fill(Color.liftBlue)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LiftTimeFormatter.relativeNoSeconds(from: notification.createdAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftBlue)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
                .frame(maxHeight: .infinity)
        }
        .padding(14)
        .background(notification.isRead ? Color.liftCard : Color.liftBlue.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(notification.isRead ? Color.liftSeparator : Color.liftBlue.opacity(0.32), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        LiftEmptyState(
            title: "You’re all caught up",
            message: "Ranking changes, lift reviews, and achievements will appear here.",
            symbolName: "bell.slash.fill"
        )
    }

    private func symbol(for kind: String) -> String {
        let value = kind.lowercased()
        if value.contains("approved") { return "checkmark.seal.fill" }
        if value.contains("ranking") { return "chart.line.uptrend.xyaxis" }
        if value.contains("achievement") { return "trophy.fill" }
        if value.contains("friend") { return "person.badge.plus" }
        return "bell.fill"
    }

    private func accessibilityHint(for notification: NotificationItem) -> String {
        let kind = notification.kind.lowercased()
        if kind.contains("ranking") { return "Opens your position on the leaderboard" }
        if kind.contains("friend") || kind.contains("message") { return "Opens Community messages" }
        if kind.contains("gym") { return "Opens Community gyms" }
        if kind.contains("lift") || kind.contains("approved") || kind.contains("rejected") || kind.contains("achievement") {
            return "Opens your profile"
        }
        return "Opens the related area"
    }

    private func tint(for kind: String) -> Color {
        let value = kind.lowercased()
        if value.contains("approved") { return .liftGreen }
        if value.contains("ranking") { return .liftBlue }
        if value.contains("achievement") { return .liftGold }
        return .liftPurple
    }
}

private struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let streakDays: Int

    var body: some View {
        AppBackground {
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONSISTENCY")
                            .font(.caption2.weight(.black))
                            .tracking(1.3)
                            .foregroundStyle(.orange)
                        Text("Workout streak")
                            .font(.title2.weight(.black))
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 150, height: 150)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                        )
                    Text("\(streakDays)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .offset(y: 65)
                }
                .padding(.bottom, 12)

                Text(streakDays == 1 ? "1 day streak" : "\(streakDays) day streak")
                    .font(.title.weight(.black))
                Text(streakMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 7) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 7) {
                            Circle()
                                .fill(day <= streakDays ? Color.orange : Color.liftSeparator)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: day <= streakDays ? "checkmark" : "circle")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(day <= streakDays ? Color.liftBackground : Color.liftMuted)
                                }
                            Text("\(day)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var streakMessage: String {
        if streakDays == 0 {
            return "Complete a workout today to begin a new streak."
        }
        if streakDays < 7 {
            return "Keep training consistently. Your next milestone unlocks at 7 days."
        }
        return "Your streak is active. Complete another workout by tomorrow to keep it going."
    }
}
