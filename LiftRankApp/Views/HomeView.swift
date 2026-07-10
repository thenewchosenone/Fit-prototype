import Charts
import SwiftUI

private extension View {
    func homePanelStyle() -> some View {
        background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingNotifications = false
    @State private var showingStreak = false
    @State private var homeContentWidth: CGFloat = 0

    private struct WeeklyPoint: Identifiable {
        let id = UUID()
        let day: String
        let count: Int
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    balancedOverview
                    quickStats
                    recentPRs
                    weeklyActivity
                    communityHighlights
                }
                .padding(.horizontal, 18)
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
                ProfileAvatar(profile: appState.currentProfile, size: 46)
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

            Button {
                Haptics.light()
                showingNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }

                    if appState.unreadNotificationCount > 0 {
                        Text("\(appState.unreadNotificationCount)")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(Color.liftRed)
                            .clipShape(Circle())
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications, \(appState.unreadNotificationCount) unread")

            Button {
                appState.showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftCard)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
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
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
        let weekEntries = appState.selectedPlanWorkoutEntries.filter { $0.week == 1 }

        return Button {
            appState.trainingTrackerStartOnProgress = false
            appState.showingTrainingTracker = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftBlue)
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftBackground)
                        .frame(width: 36, height: 36)
                        .background(Color.liftBlue)
                        .clipShape(Circle())
                }

                Text(appState.selectedWorkoutPlan?.name ?? "Workout plan")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(appState.workoutDays(for: 1).count) workouts • \(weekEntries.count) exercises")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)

                Spacer(minLength: 2)

                Label("Focus: \(balance.weakest)", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open today's training, \(appState.selectedWorkoutPlan?.name ?? "workout plan")")
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
                        .foregroundStyle(.white)
                    Text("score")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }

                Text("Advanced")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)

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
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
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
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
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
                appState.selectedTab = 2
            }

            VStack(spacing: 0) {
                    ForEach(Array(appState.currentUserLifts.prefix(3).enumerated()), id: \.element.id) { index, lift in
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
                                Text("\(RankingCalculator.format(lift.estimatedOneRepMax)) lb estimated max")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }

                            Spacer()

                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(VerificationBadge(status: lift.verificationStatus).color)
                                .accessibilityLabel(lift.verificationStatus.rawValue)
                        }
                        .padding(.vertical, 11)

                        if index < min(2, appState.currentUserLifts.count - 1) {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                        }
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homePanelStyle()
        }
    }

    private func liftSymbol(for exerciseName: String) -> String {
        let normalized = exerciseName.lowercased()
        if normalized.contains("squat") { return "figure.strengthtraining.functional" }
        if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("This week", actionTitle: "Open") {
                openWeeklyProgress()
            }

            Button {
                openWeeklyProgress()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("9")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                            Text("completed lifts")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Text("+18%")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Color.liftGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.liftGreen.opacity(0.11))
                            .clipShape(Capsule())
                    }

                    Chart(weeklyPoints) { point in
                        BarMark(
                            x: .value("Day", point.day),
                            y: .value("Lifts", point.count)
                        )
                        .foregroundStyle(Color.liftBlue.gradient)
                        .cornerRadius(5)
                    }
                    .frame(height: 145)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .chartYAxis(.hidden)
                    .padding(.top, 8)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homePanelStyle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open weekly training progress, 9 completed lifts, up 18 percent")
        }
    }

    private func openWeeklyProgress() {
        appState.trainingTrackerStartOnProgress = true
        appState.showingTrainingTracker = true
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
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        .frame(width: 210, height: 126, alignment: .leading)
                        .padding(16)
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        }
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
        HStack {
            Text(title)
                .font(.title3.weight(.black))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var weeklyPoints: [WeeklyPoint] {
        [
            WeeklyPoint(day: "M", count: 2),
            WeeklyPoint(day: "T", count: 1),
            WeeklyPoint(day: "W", count: 0),
            WeeklyPoint(day: "T", count: 3),
            WeeklyPoint(day: "F", count: 2),
            WeeklyPoint(day: "S", count: 1),
            WeeklyPoint(day: "S", count: 0)
        ]
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
                        .foregroundStyle(.white)
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
        .padding(15)
        .background(notification.isRead ? Color.liftCard : Color.liftBlue.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(notification.isRead ? Color.white.opacity(0.06) : Color.liftBlue.opacity(0.32), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.liftBlue)
            Text("You’re all caught up")
                .font(.title3.weight(.black))
            Text("Ranking changes, lift reviews, and achievements will appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
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
                                .fill(day <= streakDays ? Color.orange : Color.white.opacity(0.09))
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
