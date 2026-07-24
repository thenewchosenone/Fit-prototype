import SwiftUI

struct WeeklyPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let day: String
    let count: Int
}

extension HomeView {
    @ViewBuilder
    var workoutStatus: some View {
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

    var header: some View {
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

    var headerIdentity: some View {
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

    var headerActions: some View {
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

    func statusPill(symbol: String, value: String, tint: Color) -> some View {
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

    var balancedOverview: some View {
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

    var usesStackedOverview: Bool {
        dynamicTypeSize.isAccessibilitySize || (homeContentWidth > 0 && homeContentWidth < 340)
    }

    var trainingOverviewCard: some View {
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

    var todayWorkoutTitle: String {
        scheduledWorkoutToday?.workout ?? "Rest Day"
    }

    func todayWorkoutSubtitle(_ workout: WorkoutDaySummary?) -> String {
        guard let workout else { return "No workout scheduled today" }
        return "\(appState.selectedWorkoutPlan?.name ?? "Workout plan") • \(workout.exercises) exercises"
    }

    var scheduledWorkoutToday: WorkoutDaySummary? {
        let todayName = Calendar.current.weekdayName(for: .now)
        return appState.workoutDays(for: 1).first { $0.day.caseInsensitiveCompare(todayName) == .orderedSame }
    }

    var strengthOverviewCard: some View {
        let strengthTier = RankingFormatting.strengthTier(for: appState.overallScore)
        return Button {
            appState.selectedTab = 1
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STRENGTH")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftBlue)
                    Spacer()
                    Image(systemName: "video.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftGreen)
                        .accessibilityLabel("Video-backed strength records")
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(appState.overallScore))")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liftText)
                    Text("score")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }

                Text(strengthTier.label)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Color.liftText)

                Spacer(minLength: 2)

                HStack {
                    Label("Global rank", systemImage: "chart.line.uptrend.xyaxis")
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
        .accessibilityLabel("Open leaderboards, strength score \(Int(appState.overallScore)), \(strengthTier.label), global rank")
    }

    var quickStats: some View {
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
                value: bodyweightStat.value,
                unit: bodyweightStat.unit,
                symbol: "scalemass.fill",
                tint: .liftBlue
            )
            statDivider
            compactStat(
                title: "Relative",
                value: RankingFormatting.ratioText(appState.relativeTotal),
                unit: "x",
                symbol: "bolt.fill",
                tint: .liftBlue
            )
        }
        .padding(14)
        .liftSurface()
    }

    var bodyweightStat: (value: String, unit: String) {
        let text = MeasurementFormatting.formatBodyweightOrDash(
            appState.currentProfile.bodyweightPounds,
            preferredUnit: appState.currentProfile.preferredUnit
        )
        guard text != "—" else { return ("—", "") }
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? text, parts.dropFirst().first ?? "")
    }

    var highlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Quick actions")
            HStack(spacing: 12) {
                highlightButton("Log workout", "dumbbell.fill", Color.liftBlue) {
                    appState.requestedTrackerSegment = "Today"
                    appState.trainingTrackerStartOnProgress = false
                    appState.selectedTab = 2
                }
                highlightButton("Bodyweight", "scalemass.fill", Color.liftGold) {
                    selectedBodyweightEntry = BodyweightEntry.draftForCurrentWeek(
                        entries: appState.bodyweightEntries,
                        currentBodyweightPounds: appState.currentProfile.bodyweightPounds
                    )
                }
                highlightButton("Awards", "trophy.fill", Color.liftGreen) {
                    showingAwards = true
                }
            }
        }
    }

    func highlightButton(_ title: String, _ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
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

    var statDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 48)
    }

    func compactStat(
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

    var recentPRs: some View {
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
                                Text(MeasurementFormatting.liftSetText(weightKilograms: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
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
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(lift.exerciseName) PR, \(MeasurementFormatting.formatRecordedWeight(lift.weight, unit: lift.unit)), \(lift.resolvedEvidenceStatus.displayName)")
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

    func liftHasVideo(_ lift: LiftSubmission) -> Bool {
        lift.demoMediaID != nil || lift.videoAssetID != nil ||
            lift.localVideoURL != nil || lift.remoteVideoURL != nil
    }

    var connectionActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Connection activity", actionTitle: appState.activities.isEmpty ? nil : "See All") {
                showingAllConnectionActivity = true
            }

            if appState.activities.isEmpty {
                LiftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your connection feed is ready", systemImage: "person.2.fill")
                            .font(.headline)
                            .foregroundStyle(Color.liftText)
                        Text("Connect with athletes to see the complete workouts they intentionally share.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        Button("Find athletes") {
                            appState.router.openAthleteSearch()
                        }
                        .buttonStyle(LiftCompactProminentButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.activities.prefix(3).enumerated()), id: \.element.id) { index, activity in
                        connectionActivityRow(activity)
                        if index < min(2, appState.activities.count - 1) {
                            Divider().overlay(Color.liftSeparator)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .homePanelStyle()
            }
        }
        .accessibilityIdentifier("home.connectionActivity")
    }

    @ViewBuilder
    var connectionRequests: some View {
        if !appState.incomingFriendRequests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                dashboardSectionHeader("Connection requests", actionTitle: nil) {}
                VStack(spacing: 0) {
                    ForEach(Array(appState.incomingFriendRequests.prefix(3).enumerated()), id: \.element.id) { index, request in
                        if let profile = appState.profile(id: request.fromUserID) {
                            HStack(spacing: 12) {
                                ProfileAvatar(profile: profile, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.displayName)
                                        .font(.subheadline.weight(.bold))
                                    Text("@\(profile.username) wants to connect")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer(minLength: 6)
                                Button("Decline") { appState.declineFriendRequest(request) }
                                    .font(.caption.weight(.bold))
                                    .buttonStyle(.bordered)
                                Button("Accept") { appState.acceptFriendRequest(request) }
                                    .font(.caption.weight(.bold))
                                    .buttonStyle(LiftCompactProminentButtonStyle())
                            }
                            .padding(.vertical, 11)
                            if index < min(2, appState.incomingFriendRequests.count - 1) {
                                Divider().overlay(Color.liftSeparator)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .homePanelStyle()
            }
            .accessibilityIdentifier("home.connectionRequests")
        }
    }

    func connectionActivityRow(_ activity: ActivityItem) -> some View {
        Button {
            appState.selectedActivity = activity
        } label: {
            HStack(spacing: 12) {
                ProfileAvatar(profile: activity.profile, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.profile.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftText)
                    Text(activity.title)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftText)
                        .lineLimit(1)
                    Text(LiftTimeFormatter.relativeNoSeconds(from: activity.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
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
        .accessibilityIdentifier("home.connectionActivity.\(activity.id.uuidString)")
    }

    func liftSymbol(for exerciseName: String) -> String {
        let normalized = exerciseName.lowercased()
        if normalized.contains("squat") { return "figure.strengthtraining.functional" }
        if normalized.contains("bench") { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
    }

    var weeklyActivity: some View {
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

    func weeklyMetric(value: String, label: String) -> some View {
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

    var weeklyDivider: some View {
        Rectangle()
            .fill(Color.liftSeparator)
            .frame(width: 1, height: 36)
            .padding(.horizontal, 9)
    }

    func openWeeklyProgress() {
        appState.trainingTrackerStartOnProgress = true
        appState.requestedTrackerSegment = "Progress"
        appState.selectedTab = 2
    }

    func dashboardSectionHeader(
        _ title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        CompactSectionHeader(title: title, actionTitle: actionTitle, action: action)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    var weeklyPoints: [WeeklyPoint] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let symbols = WorkoutHistoryCalendarData.weekdaySymbols(calendar: calendar)
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: interval.start) ?? interval.start
            let symbol = symbols.indices.contains(offset) ? symbols[offset] : ""
            let count = thisWeekCompletedWorkouts
                .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
                .count
            return WeeklyPoint(date: date, day: symbol, count: count)
        }
    }

    var thisWeekCompletedWorkouts: [CompletedWorkout] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return appState.completedWorkouts.filter {
            interval.contains($0.completedAt) &&
                !$0.completedWorkingSets.isEmpty
        }
    }

    var plannedWorkoutCount: Int {
        guard let week = appState.currentSelectedProgramWeek else { return 0 }
        return appState.sessions(for: week).count
    }

    var thisWeekWorkoutCount: Int {
        thisWeekCompletedWorkouts.count
    }

    var thisWeekCompletedSetCount: Int {
        thisWeekCompletedWorkouts.flatMap(\.completedWorkingSets).count
    }

    var thisWeekVolume: Double {
        thisWeekCompletedWorkouts.flatMap(\.completedWorkingSets).reduce(0) { total, set in
            guard let weight = set.weight, let reps = set.reps else { return total }
            let displayedWeight = MeasurementFormatting.convert(weight, from: set.recordedUnit, to: appState.currentProfile.preferredUnit)
            return total + displayedWeight * Double(reps)
        }
    }

    var formattedWeeklyDuration: String {
        MeasurementFormatting.shortDurationText(thisWeekCompletedWorkouts.reduce(0) { $0 + $1.duration })
    }

    var weeklyStatusText: String {
        guard plannedWorkoutCount > 0 else { return "No plan" }
        if thisWeekWorkoutCount >= plannedWorkoutCount { return "Complete" }
        if thisWeekWorkoutCount > 0 { return "In progress" }
        return "Not started"
    }

    var weeklyStatusColor: Color {
        guard plannedWorkoutCount > 0 else { return .liftMuted }
        if thisWeekWorkoutCount >= plannedWorkoutCount { return .liftGreen }
        return thisWeekWorkoutCount > 0 ? .liftBlue : .liftMuted
    }
}

extension HomeView {
    var featureBody: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    workoutStatus
                    balancedOverview
                    quickStats
                    highlights
                    recentPRs
                    if appState.features.connectionActivity {
                        connectionRequests
                        connectionActivity
                    }
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
        .sheet(isPresented: $showingAllConnectionActivity) {
            ConnectionActivityListView()
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }
}
