import SwiftUI

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
                        .foregroundStyle(Color.liftOnAccent)
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

    @ViewBuilder
    var workoutSyncStatus: some View {
        if appState.isAuthenticated && !appState.isDemoMode {
            let state = appState.workoutSyncStore.historySyncState
            if state != .synced {
                let pendingCount = appState.workoutSyncStore.pendingCompletedWorkoutUploads.count
                let copy: (String, String, String, Color) = switch state {
                case .local:
                    ("Workout saved on this device", "\(pendingCount) workout\(pendingCount == 1 ? "" : "s") waiting to sync when the connection is available.", "arrow.triangle.2.circlepath", .orange)
                case .syncing:
                    ("Syncing workout history", "Keeping this workout available across your devices.", "arrow.triangle.2.circlepath", .liftAccentText)
                case .stale:
                    ("Workout history may be stale", "Refresh to make Home metrics current.", "clock.arrow.circlepath", .orange)
                case .needsAttention:
                    ("Workout sync needs attention", "Your workout is safe locally. Try again when you’re online.", "exclamationmark.triangle.fill", .orange)
                case .synced:
                    ("", "", "", .clear)
                }
                let canRetry = state == .local || state == .stale || state == .needsAttention
                let syncContent = HStack(spacing: 10) {
                    Image(systemName: copy.2)
                        .foregroundStyle(copy.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.0)
                            .font(.subheadline.weight(.bold))
                        Text(copy.1)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer(minLength: 4)
                    if canRetry {
                        Text(state == .needsAttention ? "Retry sync" : "Sync now")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                }
                if canRetry {
                    Button {
                        Task { await appState.synchronizeCompletedWorkoutHistory(force: true) }
                    } label: {
                        syncContent
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .homePanelStyle()
                    .accessibilityLabel(state == .needsAttention ? "Retry workout sync" : "Sync workout now")
                    .accessibilityValue(copy.1)
                } else {
                    syncContent
                        .padding(12)
                        .homePanelStyle()
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(copy.0)
                        .accessibilityValue(copy.1)
                }
            }
        }
    }

    @ViewBuilder
    var trainingAlerts: some View {
        let stalledLifts = Array(appState.plateauInsights.prefix(2))
        let stalledLiftNames = stalledLifts.map { $0.exerciseName }.joined(separator: ", ")
        let missedWorkout = appState.missedScheduledWorkout()
        let recoveringMuscles = Array(
            appState.recoverySummaries()
                .filter { $0.hoursSinceTraining < 48 }
                .prefix(2)
        )
        let thisWeekVolume = appState.weeklyVolumeByBodyPart().values.reduce(0, +)
        let priorWeekVolumes = (1...4).compactMap { offset -> Double? in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: .now) else { return nil }
            return appState.weeklyVolumeByBodyPart(referenceDate: date).values.reduce(0, +)
        }
        let baselineVolume = priorWeekVolumes.isEmpty ? 0 : priorWeekVolumes.reduce(0, +) / Double(priorWeekVolumes.count)
        let unusualVolume = baselineVolume > 0 && thisWeekVolume >= baselineVolume * 1.5
        let programComplete = selectedProgramIsCompleteForHome
        let signalCount = (missedWorkout == nil ? 0 : 1)
            + (stalledLifts.isEmpty ? 0 : 1)
            + (recoveringMuscles.isEmpty ? 0 : 1)
            + (unusualVolume ? 1 : 0)
            + (programComplete ? 1 : 0)
        if signalCount > 0 {
            Button {
                appState.trainingTrackerStartOnProgress = true
                appState.requestedTrackerSegment = "Progress"
                appState.selectedTab = 2
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "equal.circle.fill")
                                .foregroundStyle(Color.liftGold)
                            Text(signalCount == 1 ? "Training signal" : "Training signals")
                                .font(.subheadline.weight(.bold))
                            Text("\(signalCount)")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.liftAccentText)
                        }
                        if let missedWorkout {
                            Text("Missed session")
                                .font(.caption.weight(.bold))
                            Text("\(missedWorkout.session.name) · scheduled \(LiftTimeFormatter.shortDateNoTime(missedWorkout.date)) · Log missed workout")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if !stalledLifts.isEmpty {
                            Text("Possible plateau")
                                .font(.caption.weight(.bold))
                            Text("\(stalledLiftNames) · Open plateau details")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if !recoveringMuscles.isEmpty {
                            Text("Recovery context")
                                .font(.caption.weight(.bold))
                            Text("\(recoveringMuscles.map { $0.muscle.displayName }.joined(separator: ", ")) · Review recovery")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if unusualVolume {
                            Text("Unusual volume")
                                .font(.caption.weight(.bold))
                            Text("\(Int((thisWeekVolume / baselineVolume) * 100))% of your prior four-week average · Review volume")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if programComplete {
                            Text("Program milestone")
                                .font(.caption.weight(.bold))
                            Text("Program complete · Review program progress")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        Text("Open Progress")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .homePanelStyle()
            .accessibilityLabel("Training alerts")
            .accessibilityValue("\(signalCount) signal\(signalCount == 1 ? "" : "s")")
            .accessibilityHint("Opens Progress for details and next actions")
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
        return HStack(spacing: 12) {
            Button {
                appState.selectedTab = 3
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
                    .foregroundStyle(Color.liftAccentText)
                    .lineLimit(2)
                Text(appState.currentProfile.displayName)
                    .font(.title3.weight(.black))
                    .lineLimit(2)
            }
        }
    }

    var headerActions: some View {
        let streak = appState.workoutStreak()
        return HStack(spacing: 8) {
            Button {
                Haptics.light()
                showingStreak = true
            } label: {
                statusPill(symbol: "flame.fill", value: "\(streak)", tint: .orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(streak) day streak details")

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
        let currentWeekNumber = appState.currentSelectedProgramWeek?.weekNumber
            ?? appState.selectedPlanWeeks.first?.weekNumber
            ?? 1
        let balance = appState.strengthBalance(for: currentWeekNumber)
        let today = scheduledWorkoutToday
        let missed = today == nil ? appState.missedScheduledWorkout() : nil
        let todayComplete = today != nil && todayScheduledSessionCompleted
        let programComplete = selectedProgramIsCompleteForHome
        let active = appState.activeWorkout != nil

        return Button {
            if todayComplete || programComplete {
                openWeeklyProgress()
            } else {
                appState.requestedTrackerSegment = active ? "Today" : (today == nil && missed == nil ? "Plans" : "Today")
                appState.trainingTrackerStartOnProgress = false
                appState.selectedTab = 2
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftAccentText)
                    Spacer()
                    Image(systemName: todayComplete || programComplete ? "checkmark.circle.fill" : active ? "play.fill" : today == nil ? (missed == nil ? "bed.double.fill" : "exclamationmark.circle.fill") : "play.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.liftOnAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.liftBlue)
                        .clipShape(Circle())
                }

                Text(homeTrainingTitle(today: today, missed: missed, todayComplete: todayComplete, programComplete: programComplete))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Color.liftText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(homeTrainingSubtitle(today: today, missed: missed, todayComplete: todayComplete, programComplete: programComplete))
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)

                Spacer(minLength: 2)

                Label(todayComplete || programComplete
                      ? "View Progress"
                      : active
                        ? "Resume workout"
                        : missed == nil
                          ? (today == nil ? "Open Programs" : "Focus: \(balance.weakest)")
                          : "Log missed workout",
                      systemImage: todayComplete || programComplete
                        ? "chart.bar.fill"
                        : active
                          ? "play.fill"
                          : missed == nil
                            ? (today == nil ? "list.bullet.rectangle" : "scope")
                            : "arrow.uturn.backward.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(homeTrainingTitle(today: today, missed: missed, todayComplete: todayComplete, programComplete: programComplete))
    }

    private func homeTrainingTitle(
        today: WorkoutDaySummary?,
        missed: (week: WorkoutWeek, session: WorkoutSession, date: Date)?,
        todayComplete: Bool,
        programComplete: Bool
    ) -> String {
        if programComplete { return "Program complete" }
        if todayComplete { return "Completed: \(today?.workout ?? "Today's workout")" }
        if let missed { return "Missed: \(missed.session.name)" }
        if appState.activeWorkout != nil { return "Resume: \(today?.workout ?? "Active workout")" }
        return todayWorkoutTitle
    }

    private func homeTrainingSubtitle(
        today: WorkoutDaySummary?,
        missed: (week: WorkoutWeek, session: WorkoutSession, date: Date)?,
        todayComplete: Bool,
        programComplete: Bool
    ) -> String {
        if programComplete { return "Review your progress and choose what to train next." }
        if todayComplete { return "Today's session is saved. Review your training progress." }
        if let missed { return missedWorkoutSubtitle(missed) }
        if appState.activeWorkout != nil { return "Workout in progress • Continue logging your sets." }
        return todayWorkoutSubtitle(today)
    }

    private var todayScheduledSessionCompleted: Bool {
        guard let scheduled = appState.scheduledWorkout() else { return false }
        let planned = appState.prescriptions(for: scheduled.session)
        guard !planned.isEmpty else { return false }
        return appState.completedPrescriptionCount(for: scheduled.session) >= planned.count
    }

    private var selectedProgramIsCompleteForHome: Bool {
        let sessions = appState.selectedPlanWeeks.flatMap { appState.sessions(for: $0) }
        guard !sessions.isEmpty else { return false }
        return sessions.allSatisfy { session in
            let planned = appState.prescriptions(for: session)
            return !planned.isEmpty && appState.completedPrescriptionCount(for: session) >= planned.count
        }
    }

    var todayWorkoutTitle: String {
        scheduledWorkoutToday?.workout ?? "Rest Day"
    }

    func todayWorkoutSubtitle(_ workout: WorkoutDaySummary?) -> String {
        guard let workout else { return "No workout scheduled today" }
        let week = appState.currentSelectedProgramWeek?.weekNumber
            ?? appState.selectedPlanWeeks.first?.weekNumber
        let weekLabel = week.map { "Week \($0)" } ?? ""
        let progression = appState.workoutPlanProgressionSettings
            .first { $0.planID == appState.selectedWorkoutPlanID }?.method.rawValue
        let plannedSets = plannedSetCount(for: workout)
        let detail = [
            weekLabel,
            progression ?? "",
            "\(workout.exercises) exercises",
            plannedSets.map { "\($0) planned sets" } ?? ""
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        return "\(appState.selectedWorkoutPlan?.name ?? "Workout plan") • \(detail)"
    }

    func missedWorkoutSubtitle(_ missed: (week: WorkoutWeek, session: WorkoutSession, date: Date)) -> String {
        let planName = appState.selectedWorkoutPlan?.name ?? "Workout plan"
        let progression = appState.workoutPlanProgressionSettings
            .first { $0.planID == appState.selectedWorkoutPlanID }?.method.rawValue
        let plannedSets = appState.prescriptions(for: missed.session).reduce(0) { $0 + $1.sets }
        let details = [
            "Scheduled \(LiftTimeFormatter.shortDateNoTime(missed.date))",
            "Week \(missed.week.weekNumber)",
            progression,
            "\(plannedSets) planned sets"
        ].compactMap { $0 }.joined(separator: " • ")
        return "\(planName) • \(details)"
    }


    private func plannedSetCount(for workout: WorkoutDaySummary) -> Int? {
        guard let week = appState.currentSelectedProgramWeek ?? appState.selectedPlanWeeks.first,
              let session = appState.sessions(for: week).first(where: {
                  $0.day.caseInsensitiveCompare(workout.day) == .orderedSame &&
                  $0.name.caseInsensitiveCompare(workout.workout) == .orderedSame
              }) else { return nil }
        return appState.prescriptions(for: session).reduce(0) { $0 + $1.sets }
    }

    var scheduledWorkoutToday: WorkoutDaySummary? {
        guard let scheduled = appState.scheduledWorkout() else { return nil }
        let prescriptions = appState.prescriptions(for: scheduled.session)
        return WorkoutDaySummary(
            day: scheduled.session.day,
            workout: scheduled.session.name,
            exercises: prescriptions.count,
            completed: appState.completedPrescriptionCount(for: scheduled.session)
        )
    }

    var strengthOverviewCard: some View {
        let summary = appState.strengthTierSummary
        return Button {
            showingAwards = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STRENGTH")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(Color.liftAccentText)
                    Spacer()
                    Image(systemName: "medal.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.liftGold)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(summary.overallTier.label)
                        .font(.title2.weight(.black))
                        .foregroundStyle(Color.liftText)
                }

                Text("\(summary.completedRequiredLiftCount) of \(summary.requiredLiftCount) lifts logged")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)

                Spacer(minLength: 2)

                HStack {
                    Label(summary.nextTier.map { "Next: \($0.label)" } ?? "Top tier reached", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftAccentText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .liftSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open strength milestones, \(summary.overallTier.label), \(summary.completedRequiredLiftCount) of \(summary.requiredLiftCount) lifts logged")
    }

    var quickStats: some View {
        let preferredUnit = appState.currentProfile.preferredUnit
        let totalPounds = appState.powerliftingTotal
        let topTrackedOneRepMaxPounds = appState.progressExerciseOptions()
            .compactMap { option -> Double? in
                guard let kilograms = appState.exerciseRecords(for: option.id).bestEstimatedOneRepMaxKilograms else { return nil }
                return RankingCalculator.kilogramsToPounds(kilograms)
            }
            .max() ?? 0
        let primaryStrengthPounds = totalPounds > 0 ? totalPounds : topTrackedOneRepMaxPounds
        let relativeTotal = RankingCalculator.relativeTotal(
            total: totalPounds,
            bodyweight: appState.currentProfile.bodyweightPounds
        )
        return HStack(spacing: 12) {
            CompactMetric(
                title: totalPounds > 0 ? "Total" : "Top 1RM",
                value: primaryStrengthPounds > 0
                    ? "\(Int(MeasurementFormatting.convert(primaryStrengthPounds, from: .pounds, to: preferredUnit)))"
                    : "—",
                unit: preferredUnit.shortLabel,
                symbolName: "dumbbell.fill",
                tint: .liftAccentText
            )
            statDivider
            CompactMetric(
                title: "Bodyweight",
                value: bodyweightStat.value,
                unit: bodyweightStat.unit,
                symbolName: "scalemass.fill",
                tint: .liftAccentText
            )
            statDivider
            CompactMetric(
                title: "Relative",
                value: totalPounds > 0 ? RankingFormatting.ratioText(relativeTotal) : "—",
                unit: "x",
                symbolName: "bolt.fill",
                tint: .liftAccentText
            )
        }
        .padding(14)
        .liftSurface()
    }

    var bodyweightStat: (value: String, unit: String) {
        let latestLoggedBodyweight = ProfileDataAuthority.latestLoggedBodyweight(
            profilePounds: appState.currentProfile.bodyweightPounds,
            entries: appState.bodyweightEntries
        )
        let text = MeasurementFormatting.formatBodyweightOrDash(
            latestLoggedBodyweight,
            preferredUnit: appState.currentProfile.preferredUnit
        )
        guard text != "—" else { return ("—", "") }
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? text, parts.dropFirst().first ?? "")
    }

    var highlights: some View {
        let missedWorkout = appState.missedScheduledWorkout()
        return VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Quick actions")
            HStack(spacing: 12) {
                highlightButton(
                    missedWorkout == nil ? "Log workout" : "Log missed workout",
                    missedWorkout == nil ? "dumbbell.fill" : "arrow.uturn.backward.circle",
                    Color.liftAccentText
                ) {
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
                highlightButton("Progress", "chart.bar.fill", Color.liftGreen) {
                    openWeeklyProgress()
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

    var recentPRs: some View {
        let recentLifts = Array(appState.currentUserLifts.prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Recent submitted PRs", actionTitle: "Submit lift") {
                appState.showingSubmitSheet = true
            }

            VStack(spacing: 0) {
                if recentLifts.isEmpty {
                    Button {
                        appState.showingSubmitSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(Color.liftGold)
                                .frame(width: 38, height: 38)
                                .background(Color.liftGold.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Log your first PR")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.liftText)
                                Text("Submit a lift to start tracking personal records.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftAccentText)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.recentPRs.emptyAction")
                } else {
                    ForEach(Array(recentLifts.enumerated()), id: \.element.id) { index, lift in
                        let prAccessibilityLabel = "Open \(lift.exerciseName) PR, \(MeasurementFormatting.formatRecordedWeight(lift.weight, unit: lift.unit)), \(lift.resolvedEvidenceStatus.displayName)"
                        Button {
                            appState.router.sheet = .recentPR(lift)
                        } label: {
                            HStack(spacing: 13) {
                                Group {
                                    if let catalogExercise = MockData.trainingExerciseLibrary.first(where: {
                                        $0.id == lift.exerciseID || $0.rankingExerciseID == lift.exerciseID
                                    }) {
                                        ExerciseCatalogIcon(exercise: catalogExercise)
                                            .scaleEffect(0.72)
                                    } else {
                                        ExerciseNameIcon(name: lift.exerciseName, fallbackSymbol: liftSymbol(for: lift.exerciseName))
                                            .font(.headline)
                                            .foregroundStyle(Color.liftGold)
                                    }
                                }
                                .frame(width: 42, height: 42)
                                .background(Color.liftGold.opacity(0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lift.exerciseName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.liftText)
                                Text("\(prSourceLabel(for: lift)) · " + MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
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
                        .accessibilityLabel(prAccessibilityLabel)
                        .accessibilityHint(liftHasVideo(lift) ? "Shows PR video and attempt details" : "Shows the workout set and attempt details")

                        if index < recentLifts.count - 1 {
                            Divider()
                                .overlay(Color.liftSeparator)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homePanelStyle()
        }
    }

    func liftHasVideo(_ lift: LiftSubmission) -> Bool {
        lift.videoAssetID != nil || lift.localVideoURL != nil || lift.remoteVideoURL != nil
    }

    func prSourceLabel(for lift: LiftSubmission) -> String {
        if lift.visibility == .privateLift { return "Private PR" }
        return lift.resolvedEvidenceStatus == .videoBacked
            ? "Video-backed submission"
            : "Self-reported submission"
    }

    func liftSymbol(for exerciseName: String) -> String {
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
        return "figure.strengthtraining.functional"
    }

    var weeklyActivity: some View {
        WeeklyTrainingDayGoalCard(summary: homeWeeklySummary)
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

    var homeWeeklySummary: HomeWeeklySummary {
        appState.homeWeeklySummary()
    }
}

struct WeeklyTrainingDayGoalCard: View {
    @EnvironmentObject private var appState: AppState
    let summary: HomeWeeklySummary

    private var goal: Int? { appState.workoutPreferences.weeklyTrainingDayGoal }

    var body: some View {
        Group {
            if let goal {
                let completedDays = summary.completedTrainingDayCount
                HStack(spacing: 12) {
                    ZStack {
                        ProgressView(value: Double(min(completedDays, goal)), total: Double(goal))
                            .progressViewStyle(.circular)
                            .tint(Color.liftGreen)
                            .scaleEffect(1.35)
                        Text("\(min(completedDays, goal))")
                            .font(.caption.weight(.black).monospacedDigit())
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Label("Training-day goal", systemImage: "target")
                            .font(.subheadline.weight(.bold))
                        Text(completedDays >= goal ? "Goal reached" : "\(goal - completedDays) to go")
                            .font(.caption)
                            .foregroundStyle(completedDays >= goal ? Color.liftGreen : Color.liftMuted)
                    }
                    Spacer(minLength: 4)
                    goalMenu
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homePanelStyle()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Weekly training-day goal")
                .accessibilityValue("\(min(completedDays, goal)) of \(goal) days")
            } else {
                Button {
                    appState.setWeeklyTrainingDayGoal(3)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "target")
                            .foregroundStyle(Color.liftAccentText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a weekly training goal")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.liftText)
                            Text("Counts distinct training days")
                                .font(.caption2)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .homePanelStyle()
                .accessibilityIdentifier("weeklyTrainingGoal.set")
                .accessibilityHint("Sets a three-day weekly training goal; use the goal menu to change it.")
            }
        }
    }

    private var goalMenu: some View {
        Menu {
            ForEach(1...7, id: \.self) { days in
                Button("\(days) day\(days == 1 ? "" : "s") per week") {
                    appState.setWeeklyTrainingDayGoal(days)
                }
            }
            Button("Turn off goal", role: .destructive) {
                appState.setWeeklyTrainingDayGoal(nil)
            }
        } label: {
            Label("\(goal ?? 0) days", systemImage: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
        }
        .accessibilityIdentifier("weeklyTrainingGoal.menu")
    }
}

extension HomeView {
    @ViewBuilder
    var featureBody: some View {
        if appState.router.selectedTab == .home {
            homeContent
        } else {
            AppBackground {
                Color.clear
            }
        }
    }

    private var homeContent: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    workoutStatus
                    workoutSyncStatus
                    trainingAlerts
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
        .onAppear {
            appState.recordLaunchReadyIfNeeded()
        }
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
    }
}
