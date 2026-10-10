import Charts
import SwiftUI

private struct ProfileChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct ProfileTimelineEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String
    let workout: CompletedWorkout?
}

enum ProfileHistoryDateRange: String, CaseIterable, Identifiable {
    case allTime = "All time"
    case thirtyDays = "30 days"
    case ninetyDays = "90 days"
    case oneYear = "1 year"

    var id: String { rawValue }

    func startDate(from date: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .allTime: return nil
        case .thirtyDays: return calendar.date(byAdding: .day, value: -30, to: date)
        case .ninetyDays: return calendar.date(byAdding: .day, value: -90, to: date)
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: date)
        }
    }
}

enum ProfileHistoryType: String, CaseIterable, Identifiable {
    case all = "All workouts"
    case program = "Program"
    case freestyle = "Freestyle"

    var id: String { rawValue }
}

struct ProfileLiftPresentation {
    let lifts: [LiftSubmission]
    let threeLiftTotalPounds: Double
    let bestEstimatedOneRepMaxByExerciseID: [String: Double]
    let chartLifts: [LiftSubmission]
    let bestSubmittedLift: LiftSubmission?
    let latestSubmittedLift: LiftSubmission?

    static let empty = ProfileLiftPresentation(profileID: UUID(), lifts: [])

    init(profileID: UUID, lifts: [LiftSubmission]) {
        self.lifts = lifts
        threeLiftTotalPounds = RankingCalculator.totalForUser(profileID, lifts: lifts)
        bestEstimatedOneRepMaxByExerciseID = Dictionary(uniqueKeysWithValues: ["bench", "squat", "deadlift"].map {
            ($0, RankingCalculator.bestLift(exerciseID: $0, submissions: lifts)?.estimatedOneRepMax ?? 0)
        })
        let latestExerciseID = lifts.max { $0.performedAt < $1.performedAt }?.exerciseID
        chartLifts = Array(lifts.filter { $0.exerciseID == latestExerciseID }
            .sorted { $0.performedAt < $1.performedAt }.suffix(6))
        bestSubmittedLift = lifts.max { $0.estimatedOneRepMax < $1.estimatedOneRepMax }
        latestSubmittedLift = lifts.max { $0.performedAt < $1.performedAt }
    }
}

extension ProfileView {
    var blockedProfileState: some View {
        return LiftEmptyState(
            title: "Athlete blocked",
            message: "You won’t see this athlete’s profile, lifts, or activity while they’re blocked.",
            symbolName: "hand.raised.slash",
            actionTitle: "Unblock athlete",
            action: { appState.setBlocked(profile.id, blocked: false) }
        )
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityIdentifier("profile.blockedState")
    }

    var restrictedProfileState: some View {
        let title: String
        let message: String
        switch profile.profileAudience {
        case .privateProfile:
            title = "Private profile"
            message = "This athlete’s profile is private. Their training activity isn’t available to visitors."
        case .friends:
            title = "Friends-only profile"
            message = "This athlete shares their profile with accepted friends."
        case .gym:
            title = "Gym-only profile"
            message = "This athlete shares their profile with members of their gym."
        case .publicProfile:
            title = "Profile unavailable"
            message = "This athlete’s profile isn’t available right now."
        }
        return LiftEmptyState(
            title: title,
            message: message,
            symbolName: "lock.fill"
        )
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityIdentifier("profile.restrictedState")
    }

    func refreshVisibleProfileLifts() async {
        guard isCurrentUser || (!appState.isBlocked(profile.id) && appState.competitionStore.canViewProfile(
            profile,
            viewerID: viewerID ?? appState.currentProfile.id
        )) else {
            liftPresentation = .empty
            return
        }
        let lifts = await appState.competitionStore.visibleProfileLifts(
            for: profile.id,
            viewerID: viewerID ?? appState.currentProfile.id,
            includeLiftsWithoutVideo: true
        )
        let presentation = await Task.detached(priority: .userInitiated) {
            ProfileLiftPresentation(profileID: profile.id, lifts: lifts)
        }.value
        guard !Task.isCancelled else { return }
        liftPresentation = presentation
    }

    var header: some View {
        LiftCard(padding: 14, radius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        if isCurrentUser { showingPhotoManager = true }
                    } label: {
                        ProfileAvatar(profile: profile, size: 72)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName.isEmpty
                             ? (isCurrentUser ? "Your profile" : "Athlete profile")
                             : profile.displayName)
                            .font(.title3.weight(.bold))
                        if !profile.username.isEmpty || isCurrentUser {
                            Text(profile.username.isEmpty
                                 ? "Add a username"
                                 : "@\(profile.username)")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    Spacer()
                    if isCurrentUser {
                        HStack(spacing: 8) {
                            NativeIconButton(symbolName: "camera.fill", accessibilityLabel: "Change profile photo") {
                                showingPhotoManager = true
                            }
                            NativeIconButton(symbolName: "pencil", accessibilityLabel: "Edit Profile") {
                                appState.showingEditProfile = true
                            }
                        }
                    }
                }
                if isCurrentUser || hasVisiblePublicLocation {
                    Label(identityLocation, systemImage: profile.hideGym && profile.hideCity ? "eye.slash" : "location")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(2)
                }
                if let bio = profile.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftText)
                }
                if isCurrentUser || profile.yearsExperience > 0 {
                    let trainingDetails = [
                        isCurrentUser || profile.hideBodyweight || profile.bodyweightPounds > 0
                            ? (profile.hideBodyweight ? "Weight class hidden" : weightClassName)
                            : nil,
                        displayedExperienceLevel.rawValue
                    ].compactMap { $0 }.joined(separator: " • ")
                    if !trainingDetails.isEmpty {
                        Text(trainingDetails)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Text("\(profile.yearsExperience) \(profile.yearsExperience == 1 ? "year" : "years") training")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                if isCurrentUser && (profile.displayName.isEmpty || profile.username.isEmpty) {
                    Button("Complete profile") {
                        appState.showingEditProfile = true
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                    .frame(minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                }
            }
        }
    }

    func athleteDetails(presentation: ProfileLiftPresentation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $showingAthleteDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    rankings
                    progress(presentation: presentation)
                    if isCurrentUser {
                        achievements
                    }
                }
                .padding(.top, 18)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                        Text("Training profile")
                        .font(.headline)
                        .foregroundStyle(Color.liftText)
                        Text(isCurrentUser ? "Strength progress, rankings, and achievements" : "Strength progress and rankings")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftAccentText)
        }
        .padding(16)
        .liftSurface()
    }

    var identityLocation: String {
        let gymName = profile.primaryGymName.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = profile.state.trimmingCharacters(in: .whitespacesAndNewlines)
        let gym = profile.hideGym || gymName.isEmpty ? nil : gymName
        let location = profile.hideCity || (city.isEmpty && state.isEmpty)
            ? nil
            : [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        let value = [gym, location].compactMap { $0 }.joined(separator: " • ")
        return value.isEmpty ? "Gym and location hidden" : value
    }

    var hasVisiblePublicLocation: Bool {
        guard !isCurrentUser else { return true }
        let gymVisible = !profile.hideGym && !profile.primaryGymName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cityVisible = !profile.hideCity && (!profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !profile.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return gymVisible || cityVisible
    }

    func summary(presentation: ProfileLiftPresentation) -> some View {
        let totalPounds = presentation.threeLiftTotalPounds
        let profileTotalText = RankingFormatting.threeLiftTotalText(totalPounds: totalPounds, preferredUnit: profile.preferredUnit)
        let relativeTotalText = RankingFormatting.ratioText(
            RankingCalculator.relativeTotal(total: totalPounds, bodyweight: displayedBodyweightPounds)
        )
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Strength")
            if totalPounds <= 0 {
                LiftEmptyState(
                    title: "No ranked lifts yet",
                    message: isCurrentUser
                        ? "Submit an eligible bench press, squat, or deadlift to build your strength total."
                        : "This athlete has no eligible three-lift total yet.",
                    symbolName: "dumbbell.fill",
                    actionTitle: isCurrentUser ? "Submit lift" : nil,
                    action: isCurrentUser ? { appState.showingSubmitSheet = true } : nil,
                    compact: true
                )
            } else {
                LiftCard {
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("THREE-LIFT TOTAL")
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(Color.liftMuted)
                                Text(profileTotalText)
                                    .font(.title2.weight(.bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("SCORE")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                                Text(canonicalScoreText)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.liftAccentText)
                            }
                        }
                        Divider().overlay(Color.liftSeparator)
                        HStack(spacing: 0) {
                            strengthMetric("Bench", liftValue("bench", presentation: presentation))
                            profileDivider
                            strengthMetric("Squat", liftValue("squat", presentation: presentation))
                            profileDivider
                            strengthMetric("Deadlift", liftValue("deadlift", presentation: presentation))
                        }
                        Divider().overlay(Color.liftSeparator)
                        HStack {
                            Text("Relative total")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                            Spacer()
                            Text(profile.hideBodyweight ? "Hidden" : relativeTotalText)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    var rankings: some View {
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Rankings")
            LiftCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(["global", "city", "state", "age"], id: \.self) { metric in
                        switch metric {
                        case "global":
                            rankingMetric("Global", canonicalRankText, canonicalRankSubtitle, .liftGold)
                        case "city":
                            rankingMetric("City", profile.hideCity ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideCity ? "Location hidden" : "No city rank yet", .liftBlue)
                        case "state":
                            rankingMetric("State", profile.hideCity ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideCity ? "Location hidden" : "No state rank yet", .liftBlue)
                        default:
                            rankingMetric("Age group", profile.hideExactAge ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideExactAge ? "Age hidden" : "No age rank yet", .liftGreen)
                        }
                    }
                }
            }
        }
    }

    func progress(presentation: ProfileLiftPresentation) -> some View {
        let chartPoints = chartPoints(lifts: presentation.chartLifts)
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: isCurrentUser ? "Progress" : "Submitted-lift progress")
            LiftCard {
                if chartPoints.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                            .frame(width: 38, height: 38)
                            .background(Color.liftBlue.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isCurrentUser ? "No strength history yet" : "No submitted-lift history yet")
                                .font(.subheadline.weight(.bold))
                            Text("Submit verified lifts to build this progress chart.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer(minLength: 4)
                        if isCurrentUser {
                            Button("Submit lift") {
                                appState.showingSubmitSheet = true
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                            .frame(minHeight: LiftDesign.minimumTouchTarget)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(presentation.chartLifts.last?.exerciseName ?? "Submitted lift")
                        .font(.subheadline.weight(.semibold))
                    Text("Estimated 1RM · \(profile.preferredUnit.shortLabel)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                            .foregroundStyle(Color.liftAccentText)
                        PointMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                            .foregroundStyle(Color.liftGreen)
                    }
                    .frame(height: 190)
                    HStack {
                        metric("Lifts shown", "\(presentation.chartLifts.count)")
                        metric("Best shown", bestSubmittedLiftText(presentation.chartLifts.max { $0.estimatedOneRepMax < $1.estimatedOneRepMax }))
                        metric("Latest", latestSubmittedLiftText(presentation.chartLifts.last))
                    }
                }
            }
        }
    }

    var achievements: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(profileAchievementPreview) { achievement in
                    HStack(spacing: 9) {
                        Image(systemName: achievement.symbolName)
                            .foregroundStyle(unlocked(achievement) ? Color.liftGold : Color.liftMuted)
                        Text(achievement.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(unlocked(achievement) ? Color.liftText : Color.liftMuted)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .liftSurface(radius: 10)
                    .accessibilityIdentifier(unlocked(achievement) ? "profile.achievement.unlocked" : "profile.achievement.locked")
                }
            }
        }
    }

    var profileAchievementPreview: [Achievement] {
        let unlockedAchievements = appState.achievements.filter(unlocked)
        let lockedAchievements = appState.achievements.filter { !unlocked($0) }
        return unlockedAchievements + Array(lockedAchievements.prefix(4))
    }

    func recentSubmissions(profileLifts: [LiftSubmission]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Recent submissions")
            if profileLifts.isEmpty {
                LiftEmptyState(
                    title: "No submissions yet",
                    message: isCurrentUser ? "Submit a lift to start your public history." : "This athlete has not shared a lift.",
                    symbolName: "dumbbell.fill",
                    actionTitle: isCurrentUser ? "Submit lift" : nil,
                    action: isCurrentUser ? { appState.showingSubmitSheet = true } : nil,
                    compact: true
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(profileLifts.prefix(5).enumerated()), id: \.offset) { index, lift in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(lift.exerciseName)
                                    .font(.headline)
                                Text(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
                                    .foregroundStyle(Color.liftMuted)
                                Text(profileLiftSourceLabel(lift))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer()
                            VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
                            if isCurrentUser {
                                Menu {
                                    if lift.requiresCoordinatedRemoval {
                                        Button("Request coordinated removal", role: .destructive) {
                                            submissionPendingDeletion = lift
                                        }
                                        .disabled(isDeletingSubmission)
                                    } else {
                                        Button("Delete submission", role: .destructive) {
                                            submissionPendingDeletion = lift
                                        }
                                        .disabled(isDeletingSubmission)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .accessibilityLabel("Submission options")
                                .accessibilityIdentifier("profile.ownLiftOptions.\(lift.id.uuidString)")
                            } else {
                                Menu {
                                    Button("Report lift", role: .destructive) {
                                        appState.selectedReportLift = lift
                                    }
                                    .accessibilityIdentifier("profile.reportLift")
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(Color.liftMuted)
                                }
                                .accessibilityLabel("Lift options")
                                .accessibilityIdentifier("profile.liftOptions.\(lift.id.uuidString)")
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 66)
                        if index < min(4, profileLifts.count - 1) {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                        }
                    }
                }
                .liftSurface()
            }
        }
    }

    private func profileLiftSourceLabel(_ lift: LiftSubmission) -> String {
        if lift.visibility == .privateLift { return "Private submission" }
        return lift.resolvedEvidenceStatus == .videoBacked ? "Video-backed submission" : "Self-reported submission"
    }

    var trainingHistory: some View {
        let cutoff = profileHistoryDateRange.startDate()
        let query = profileHistoryExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        let workouts = isCurrentUser
            ? appState.completedWorkouts
                .filter { workout in
                    guard cutoff == nil || workout.completedAt >= cutoff! else { return false }
                    switch profileHistoryType {
                    case .all: break
                    case .program where workout.sourcePlanID == nil: return false
                    case .freestyle where workout.sourcePlanID != nil: return false
                    default: break
                    }
                    guard !query.isEmpty else { return true }
                    return workout.exercises.contains { $0.exerciseName.localizedCaseInsensitiveContains(query) }
                }
                .sorted { $0.completedAt > $1.completedAt }
            : []
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Training history")
            if isCurrentUser {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(ProfileHistoryDateRange.allCases) { range in
                            Button(range.rawValue) { profileHistoryDateRange = range }
                        }
                    } label: {
                        Label(profileHistoryDateRange.rawValue, systemImage: "calendar")
                    }
                    Menu {
                        ForEach(ProfileHistoryType.allCases) { type in
                            Button(type.rawValue) { profileHistoryType = type }
                        }
                    } label: {
                        Label(profileHistoryType.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                    }
                    Spacer()
                    Text("\(min(workouts.count, 20)) of \(workouts.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftAccentText)
                TextField("Filter by exercise", text: $profileHistoryExercise)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Filter workout history by exercise")
            }
            if workouts.isEmpty {
                LiftEmptyState(
                    title: isCurrentUser && !appState.completedWorkouts.isEmpty ? "No workouts match" : "No completed workouts yet",
                    message: isCurrentUser
                        ? (appState.completedWorkouts.isEmpty ? "Complete a training session to build your history." : "Try another date range, workout type, or exercise.")
                        : "Workout history is not shown on public profiles.",
                    symbolName: "calendar",
                    actionTitle: isCurrentUser && !appState.completedWorkouts.isEmpty ? "Clear filters" : nil,
                    action: {
                        profileHistoryDateRange = .allTime
                        profileHistoryType = .all
                        profileHistoryExercise = ""
                    }
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workouts.prefix(20).enumerated()), id: \.element.id) { index, workout in
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(Color.liftAccentText)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name.isEmpty ? workout.dayLabel : workout.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(workout.completedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Text(workout.sourcePlanID == nil ? "Freestyle" : "Program")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.liftAccentText)
                            }
                            Spacer()
                            Text("\(workout.completedWorkingSets.count) sets")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 58)
                        if index < min(19, workouts.count - 1) {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 48)
                        }
                    }
                }
                .liftSurface()
            }
        }
        .accessibilityIdentifier("profile.trainingHistory")
    }

    var profileTimeline: some View {
        let workouts = appState.completedWorkouts.sorted { $0.completedAt < $1.completedAt }
        let events = profileTimelineEvents(from: workouts)
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Progress timeline")
            if events.isEmpty {
                LiftEmptyState(
                    title: "No milestones yet",
                    message: "Complete a workout to start your personal training timeline.",
                    symbolName: "flag"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.reversed().prefix(12).enumerated()), id: \.offset) { index, event in
                        Button {
                            if let workout = event.workout { selectedTimelineWorkout = workout }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: event.workout == nil ? "flag.fill" : "dumbbell.fill")
                                    .foregroundStyle(Color.liftGold)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.liftText)
                                    Text(event.detail)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    Text(event.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                if event.workout != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(event.workout == nil)
                        if index < min(11, events.count - 1) {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 48)
                        }
                    }
                }
                .liftSurface()
            }
        }
        .accessibilityIdentifier("profile.progressTimeline")
    }

    private func profileTimelineEvents(from workouts: [CompletedWorkout]) -> [ProfileTimelineEvent] {
        var events: [ProfileTimelineEvent] = []
        events.append(contentsOf: appState.achievementUnlocks.map { unlock in
            ProfileTimelineEvent(
                id: "achievement-\(unlock.id)",
                date: unlock.unlockedAt,
                title: unlock.title,
                detail: "Achievement unlocked",
                workout: nil
            )
        })
        guard !workouts.isEmpty else { return events.sorted { $0.date < $1.date } }
        let milestones = [1, 5, 10, 25, 50, 100, 200]
        for milestone in milestones where workouts.count >= milestone {
            let workout = workouts[milestone - 1]
            let title = milestone == 1 ? "First workout" : "(milestone.formatted()) workouts"
            events.append(ProfileTimelineEvent(
                id: "workouts-\(milestone)",
                date: workout.completedAt,
                title: title,
                detail: "Training milestone",
                workout: workout
            ))
        }
        for pair in zip(workouts, workouts.dropFirst()) {
            let gap = pair.1.completedAt.timeIntervalSince(pair.0.completedAt)
            if gap >= 21 * 24 * 60 * 60 {
                events.append(ProfileTimelineEvent(
                    id: "comeback-\(pair.1.id.uuidString)",
                    date: pair.1.completedAt,
                    title: "Comeback workout",
                    detail: "Returned after \(Int(gap / (24 * 60 * 60))) days away",
                    workout: pair.1
                ))
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    var profileDivider: some View {
        Rectangle().fill(Color.liftSeparator).frame(width: 1, height: 34)
    }

    func strengthMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    func rankingMetric(_ title: String, _ value: String, _ subtitle: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.headline.weight(.bold)).foregroundStyle(tint)
            Text(subtitle).font(.caption2).foregroundStyle(Color.liftMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var weightClassName: String {
        guard let weightClass = RankingCalculator.weightClass(
            for: displayedBodyweightPounds,
            sexCategory: profile.sexCategory,
            classes: WeightClassCatalog.all
        ) else { return "Bodyweight needed" }
        return RankingFormatting.weightClassDisplayName(weightClass, preferredUnit: profile.preferredUnit)
    }

    private var displayedBodyweightPounds: Double {
        guard isCurrentUser else { return profile.bodyweightPounds }
        return ProfileDataAuthority.latestLoggedBodyweight(
            profilePounds: profile.bodyweightPounds,
            entries: appState.bodyweightEntries
        )
    }

    var displayedExperienceLevel: ExperienceLevel {
        guard isCurrentUser else { return profile.experienceLevel }
        return appState.earnedExperienceLevel
    }

    private var canonicalRankText: String {
        CanonicalRankingPresentation.text(
            rank: isCurrentUser ? appState.currentUserTotalRankingEntry?.rank : nil
        )
    }

    private var canonicalRankSubtitle: String {
        guard isCurrentUser else { return "Not shown on public profiles" }
        return appState.currentUserTotalRankingEntry == nil ? "No canonical total rank" : "Verified total leaderboard"
    }

    private var canonicalScoreText: String {
        guard isCurrentUser, let entry = appState.currentUserTotalRankingEntry else { return "—" }
        return entry.score.formatted(.number.precision(.fractionLength(0...2)))
    }

    func liftValue(_ exerciseID: String, presentation: ProfileLiftPresentation) -> String {
        let best = presentation.bestEstimatedOneRepMaxByExerciseID[exerciseID] ?? 0
        return RankingFormatting.threeLiftTotalText(totalPounds: best, preferredUnit: profile.preferredUnit)
    }

    func unlocked(_ achievement: Achievement) -> Bool {
        appState.achievementUnlocks.contains { $0.title == achievement.title }
    }

    func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartPoints(lifts: [LiftSubmission]) -> [ProfileChartPoint] {
        lifts.map {
            ProfileChartPoint(
                date: $0.performedAt,
                value: MeasurementFormatting.convert($0.estimatedOneRepMax, from: .pounds, to: profile.preferredUnit)
            )
        }
    }

    private func bestSubmittedLiftText(_ best: LiftSubmission?) -> String {
        guard let best else { return "—" }
        return MeasurementFormatting.formatRecordedWeight(MeasurementFormatting.convert(best.estimatedOneRepMax, from: .pounds, to: profile.preferredUnit), unit: profile.preferredUnit)
    }

    private func latestSubmittedLiftText(_ latest: LiftSubmission?) -> String {
        guard let latest else { return "—" }
        return MeasurementFormatting.formatRecordedWeight(MeasurementFormatting.convert(latest.estimatedOneRepMax, from: .pounds, to: profile.preferredUnit), unit: profile.preferredUnit)
    }
}
