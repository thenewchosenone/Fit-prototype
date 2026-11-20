import SwiftUI

extension HomeView {
    @ViewBuilder
    var workoutStatus: some View {
        if let active = appState.activeWorkout {
            let workoutIcon = Image(systemName: active.pausedAt == nil ? "dumbbell.fill" : "pause.fill")
                .font(LiftTypography.sectionTitle)
                .foregroundStyle(Color.liftGold)
                .frame(width: 48, height: 48)
                .background(Color.liftGold.opacity(0.14))
                .clipShape(Circle())
            let workoutDetails = VStack(alignment: .leading, spacing: 4) {
                Text("WORKOUT IN PROGRESS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.liftGold)
                Text(active.name)
                    .font(LiftTypography.cardTitle)
                    .foregroundStyle(Color.liftText)
                Text(active.pausedAt == nil ? "Continue logging your sets" : "Paused — ready when you are")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            let resumeAction = HStack(spacing: 8) {
                Text("Resume")
                    .font(LiftTypography.rowEmphasis)
                    .foregroundStyle(Color.liftGold)
                Image(systemName: "arrow.right")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftGold)
            }
            Button {
                appState.router.cover = .activeWorkout
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                workoutIcon
                                workoutDetails
                            }
                            resumeAction
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        HStack(spacing: 14) {
                            workoutIcon
                            workoutDetails
                            Spacer(minLength: 8)
                            resumeAction
                        }
                    }
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
                    ("Workout history may be out of date", "Refresh to update your Home stats.", "clock.arrow.circlepath", .orange)
                case .needsAttention:
                    ("Workout sync needs attention", appState.workoutSyncStore.unreadableRemoteWorkoutCount > 0
                     ? "\(appState.workoutSyncStore.unreadableRemoteWorkoutCount) saved workout\(appState.workoutSyncStore.unreadableRemoteWorkoutCount == 1 ? "" : "s") could not load. Retry sync."
                     : "Your workout is saved on this device. Try again when you’re online.", "exclamationmark.triangle.fill", .orange)
                case .synced:
                    ("", "", "", .clear)
                }
                let canRetry = state == .local || state == .stale || state == .needsAttention
                let syncContent = HStack(spacing: 10) {
                    Image(systemName: copy.2)
                        .foregroundStyle(copy.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.0)
                            .font(LiftTypography.rowEmphasis)
                        Text(copy.1)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer(minLength: 4)
                    if canRetry {
                        Text(state == .needsAttention ? "Retry sync" : "Sync now")
                            .font(LiftTypography.compactEmphasis)
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
        let recoveringMuscles = Array(
            appState.recoverySummaries()
                .filter { $0.hoursSinceTraining < 48 }
                .prefix(2)
        )
        let thisWeekVolume = appState.homeWeeklySummary().volume
        let priorWeekVolumes = (1...4).compactMap { offset -> Double? in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: .now) else { return nil }
            return appState.homeWeeklySummary(referenceDate: date).volume
        }
        let baselineVolume = priorWeekVolumes.isEmpty ? 0 : priorWeekVolumes.reduce(0, +) / Double(priorWeekVolumes.count)
        let unusualVolume = appState.trainingProgressStore.hasFourFullWeeksOfHistory()
            && baselineVolume > 0 && thisWeekVolume >= baselineVolume * 1.5
        let signalCount = (stalledLifts.isEmpty ? 0 : 1)
            + (recoveringMuscles.isEmpty ? 0 : 1)
            + (unusualVolume ? 1 : 0)
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
                            Text(signalCount == 1 ? "Training alert" : "Training alerts")
                                .font(LiftTypography.rowEmphasis)
                            Text("\(signalCount)")
                                .font(LiftTypography.compactEmphasis)
                                .foregroundStyle(Color.liftAccentText)
                        }
                        if !stalledLifts.isEmpty {
                            Text("Possible plateau")
                                .font(LiftTypography.compactEmphasis)
                            Text("\(stalledLiftNames)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if !recoveringMuscles.isEmpty {
                            Text("Recently trained muscles")
                                .font(LiftTypography.compactEmphasis)
                            Text("\(recoveringMuscles.map { $0.muscle.displayName }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        if unusualVolume {
                            Text("Unusual volume")
                                .font(LiftTypography.compactEmphasis)
                            Text("Volume is \(Int(((thisWeekVolume - baselineVolume) / baselineVolume * 100).rounded()))% above your prior four-week average")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(2)
                        }
                        Text("Open Progress")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(LiftTypography.compactEmphasis)
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
        HStack(spacing: 8) {
            headerIdentity
            Spacer(minLength: 0)
            headerActions
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    var headerIdentity: some View {
        return HStack(spacing: 8) {
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
                Text(greeting)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(appState.currentProfile.displayName)
                    .font(.title3.weight(.semibold))
                    .tracking(-0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    var headerActions: some View {
        let streak = appState.workoutStreak()
        return HStack(spacing: 4) {
            if !isFirstWorkout {
                Button {
                    Haptics.light()
                    showingStreak = true
                } label: {
                    statusPill(symbol: "flame.fill", value: "\(streak) wk", tint: .orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(streak) week streak details")
                .accessibilityShowsLargeContentViewer {
                    Label("\(streak) week streak", systemImage: "flame.fill")
                }
            }

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
                .font(LiftTypography.rowEmphasis)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 8)
        .frame(minWidth: 44, minHeight: 44)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.liftCard)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.liftSeparator, lineWidth: 1)
        }
        .accessibilityLabel("\(value) streak")
    }

    var trainingOverviewCard: some View {
        let today = scheduledWorkoutToday
        let missed = today == nil ? appState.missedScheduledWorkout() : nil
        let todayComplete = today != nil && todayScheduledSessionCompleted
        let programComplete = selectedProgramIsCompleteForHome
        let active = appState.activeWorkout != nil

        return Button {
            if todayComplete || programComplete {
                openWeeklyProgress()
            } else if let scheduled = appState.scheduledWorkout(), appState.activeWorkout == nil {
                if appState.startWorkout(scheduled.session) {
                    appState.router.cover = .activeWorkout
                }
            } else {
                appState.requestedTrackerSegment = "Today"
                appState.trainingTrackerStartOnProgress = false
                appState.selectedTab = 2
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Color.liftAccentText)
                    Spacer()
                }

                Text(homeTrainingTitle(today: today, missed: missed, todayComplete: todayComplete, programComplete: programComplete))
                    .font(LiftTypography.rowEmphasis)
                    .foregroundStyle(Color.liftText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)

                Text(homeTrainingSubtitle(today: today, missed: missed, todayComplete: todayComplete, programComplete: programComplete))
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                if !todayComplete, !programComplete, let scheduled = appState.scheduledWorkout() {
                    let prescriptions = appState.prescriptions(for: scheduled.session)
                    Text("\(prescriptions.count) exercises · \(prescriptions.reduce(0) { $0 + $1.sets }) sets")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 2)

                Label(todayComplete || programComplete
                      ? "View Progress"
                      : active
                        ? "Resume workout"
                        : missed == nil
                          ? (appState.selectedPlanIsFlexible ? "Choose workout" : (today == nil ? "Start a workout" : "Start workout"))
                          : "Log missed workout",
                      systemImage: todayComplete || programComplete
                        ? "chart.bar.fill"
                        : active
                          ? "play.fill"
                          : missed == nil
                            ? (today == nil ? "plus" : "arrow.right")
                            : "arrow.uturn.backward.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftOnAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.liftBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        if appState.selectedPlanIsFlexible { return "Choose today’s workout" }
        return todayWorkoutTitle
    }

    private func homeTrainingSubtitle(
        today: WorkoutDaySummary?,
        missed: (week: WorkoutWeek, session: WorkoutSession, date: Date)?,
        todayComplete: Bool,
        programComplete: Bool
    ) -> String {
        if programComplete { return "Ready for your next program." }
        if todayComplete { return "Today's session is saved." }
        if let missed { return missedWorkoutSubtitle(missed) }
        if appState.activeWorkout != nil { return "Workout in progress • Continue logging your sets." }
        if appState.selectedPlanIsFlexible { return "Train any day, in any order. Pick the workout that fits how you feel." }
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
        scheduledWorkoutToday?.workout ?? "No workout planned"
    }

    func todayWorkoutSubtitle(_ workout: WorkoutDaySummary?) -> String {
        guard workout != nil else { return "No workout scheduled today" }
        let week = appState.currentSelectedProgramWeek?.weekNumber
            ?? appState.selectedPlanWeeks.first?.weekNumber
        let weekLabel = week.map { "Week \($0)" } ?? ""
        return [appState.selectedWorkoutPlan?.name ?? "Workout plan", weekLabel]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
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
        let awards = appState.achievements
        let unlockedTitles = Set(appState.achievementUnlocks.map(\.title))
        let earnedCount = awards.filter { unlockedTitles.contains($0.title) }.count
        let isLoading = appState.isLoadingInitialTrainingData && earnedCount == 0
        let needsSync = earnedCount == 0 && appState.workoutSyncStore.historySyncState == .needsAttention
        return Button {
            showingAwards = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color.liftGold)
                Text("Awards")
                    .font(LiftTypography.rowEmphasis)
                Spacer()
                if isLoading {
                    ProgressView().accessibilityIdentifier("home.awards.loading")
                } else {
                    Text(needsSync ? "Unavailable" : "\(earnedCount) earned")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .homePanelStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLoading ? "Open awards, loading" : needsSync ? "Open awards, sync unavailable" : "Open awards, \(earnedCount) earned")
    }

    var highlights: some View {
        Button {
            selectedBodyweightEntry = BodyweightEntry.draftForToday(
                entries: appState.bodyweightEntries,
                currentBodyweightPounds: appState.currentProfile.bodyweightPounds
            )
        } label: {
            Label("Log bodyweight", systemImage: "scalemass.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.liftAccentText)
        .accessibilityIdentifier("home.quickAction.bodyweight")
    }


    @ViewBuilder
    var lastWorkout: some View {
        if let workout = appState.completedWorkouts.max(by: { $0.completedAt < $1.completedAt }) {
            let completedExerciseIDs = Set(workout.completedWorkingSets.map(\.prescriptionID))
            let trainedExercises = workout.exercises
                .filter { completedExerciseIDs.contains($0.id) }
            let volume = workout.totalVolume(in: workout.unit, catalog: appState.trainingExerciseLibrary)
            NavigationLink {
                CompletedWorkoutDetailView(workout: workout, isPresentedModally: false)
                    .environmentObject(appState)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("LAST WORKOUT", systemImage: "checkmark.circle.fill")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                        Spacer(minLength: 8)
                        Text(workout.completedAt, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Image(systemName: "chevron.right")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Text(workout.name.range(of: #"^Workout \d+$"#, options: .regularExpression) != nil
                         ? appState.workoutSessions.first { $0.id == workout.sourceSessionID }?.name ?? workout.name
                         : workout.name)
                        .font(LiftTypography.sectionTitle)
                        .foregroundStyle(Color.liftText)
                    if workout.name.range(of: #"^Workout \d+$"#, options: .regularExpression) != nil {
                        Text(trainedExercises.prefix(2).map(\.exerciseName).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Text("\(MeasurementFormatting.shortDurationText(workout.duration)) · \(workout.completedWorkingSets.count) sets · \(trainedExercises.count) exercises")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                    if volume > 0 {
                        Label("\(MeasurementFormatting.displayRecordedVolume(volume, recordedUnit: workout.unit, preferredUnit: appState.currentProfile.preferredUnit).formatted(.number.precision(.fractionLength(0)))) \(appState.currentProfile.preferredUnit.shortLabel) total volume", systemImage: "scalemass")
                            .font(LiftTypography.rowEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homePanelStyle()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.lastWorkout")
        }
    }

    var recentPRs: some View {
        let recentLifts = Array(appState.currentUserLifts.sorted {
            if $0.performedAt != $1.performedAt { return $0.performedAt > $1.performedAt }
            return $0.createdAt > $1.createdAt
        }.prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Recent lifts", actionTitle: "Submit lift") {
                appState.showingSubmitSheet = true
            }

            Text("Your latest submitted lifts. Open one for details.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)

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
                                    .font(LiftTypography.rowEmphasis)
                                    .foregroundStyle(Color.liftText)
                                Text("Submit a lift to start tracking personal records.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.right")
                                .font(LiftTypography.compactEmphasis)
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
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: index == 0 ? "trophy.fill" : liftSymbol(for: lift.exerciseName))
                                    .font(LiftTypography.sectionTitle)
                                    .foregroundStyle(Color.liftGold)
                                .frame(width: 42, height: 42)
                                .background(Color.liftGold.opacity(0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    if index == 0 {
                                        Text("LATEST SUBMISSION")
                                            .font(.caption2.weight(.medium))
                                            .tracking(0.8)
                                            .foregroundStyle(Color.liftGold)
                                    }
                                    Text(lift.exerciseName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.liftText)
                                    Text(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
                                        .font(.headline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(Color.liftAccentText)
                                    if lift.visibility == .privateLift {
                                        Label("Private PR", systemImage: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus, compact: true)
                                        .padding(.top, 3)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(LiftTypography.compactEmphasis)
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

    var closestRivals: some View {
        let rivals = appState.suggestedTrainingRivals
        return VStack(alignment: .leading, spacing: 12) {
            dashboardSectionHeader("Closest Rivals", actionTitle: "Explore") {
                appState.selectedTab = 1
            }
            Text("Find your next training benchmark.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
            if rivals.isEmpty {
                Text("Explore rankings to discover lifters. Public lifts help us find closer matches.")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homePanelStyle()
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(rivals, id: \.profile.id) { rival in
                            NavigationLink {
                                ProfileView(profile: rival.profile, surface: .public, showsDismissButton: false)
                            } label: {
                                VStack(spacing: 10) {
                                    ProfileAvatar(profile: rival.profile, size: 64)
                                    Text(rival.profile.displayName)
                                        .font(LiftTypography.rowEmphasis)
                                        .foregroundStyle(Color.liftText)
                                        .lineLimit(2)
                                    Text(rival.reason)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("View profile")
                                        .font(LiftTypography.compactEmphasis)
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(minHeight: 44)
                                }
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .frame(width: dynamicTypeSize.isAccessibilitySize ? 260 : 180)
                                .homePanelStyle()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .accessibilityIdentifier("home.closestRivals")
            }
        }
    }

    func liftHasVideo(_ lift: LiftSubmission) -> Bool {
        lift.videoAssetID != nil || lift.localVideoURL != nil || lift.remoteVideoURL != nil
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

}

struct WeeklyTrainingActivityCard: View {
    let summary: HomeWeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ForEach(summary.points) { point in
                    VStack(spacing: 5) {
                        Text(point.date, format: .dateTime.weekday(.narrow))
                            .font(.caption)
                        Image(systemName: point.count > 0 ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(point.count > 0 ? Color.liftAccentText : Color.liftMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(point.date.formatted(date: .complete, time: .omitted)): \(point.count) workouts")
                }
            }
            Text("\(summary.completedWorkoutCount) workouts · \(summary.completedSetCount) working sets this week")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
    }
}

extension HomeView {
    @ViewBuilder
    var featureBody: some View {
        if isActiveTab {
            homeContent
        } else {
            AppBackground {
                Color.clear
            }
        }
    }

    private var isFirstWorkout: Bool {
        appState.completedWorkouts.isEmpty && appState.currentUserLifts.isEmpty
            && appState.selectedWorkoutPlan == nil && appState.activeWorkout == nil
    }

    private var homeContent: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    workoutStatus
                    if isFirstWorkout {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Start your first workout")
                                    .font(LiftTypography.sectionTitle)
                                Text("Choose a plan for guided sessions, or build a workout as you go.")
                                    .foregroundStyle(Color.liftMuted)
                                PrimaryButton(title: "Choose a plan", symbolName: "list.bullet.clipboard") {
                                    appState.requestedTrackerSegment = "Plans"
                                    appState.trainingTrackerStartOnProgress = false
                                    appState.selectedTab = 2
                                }
                                Button("Build a workout") {
                                    appState.requestedTrackerSegment = "Today"
                                    appState.trainingTrackerStartOnProgress = false
                                    appState.selectedTab = 2
                                }
                                .foregroundStyle(Color.liftAccentText)
                                .frame(minHeight: 44)
                            }
                        }
                    } else {
                        if appState.activeWorkout == nil { trainingOverviewCard }
                        VStack(alignment: .leading, spacing: 12) {
                            dashboardSectionHeader("This week", actionTitle: "View progress") { openWeeklyProgress() }
                            WeeklyTrainingActivityCard(summary: appState.homeWeeklySummary())
                        }
                        lastWorkout
                    }
                    if !isFirstWorkout {
                        trainingAlerts
                        recentPRs
                        strengthOverviewCard
                    }
                    workoutSyncStatus
                    highlights
                    closestRivals
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
            StreakDetailView(
                streakWeeks: appState.workoutStreak(),
                summary: appState.homeWeeklySummary()
            )
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedBodyweightEntry) { entry in
            BodyweightEntryEditor(entry: entry) { updatedEntry in
                appState.updateBodyweight(updatedEntry)
            } onDelete: { entry in
                appState.deleteBodyweight(entry)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingAwards) {
            NavigationStack {
                AwardsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close", systemImage: "xmark") { showingAwards = false }.labelStyle(.iconOnly)
                        }
                    }
            }
                .environmentObject(appState)
        }
    }
}
