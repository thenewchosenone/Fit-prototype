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
    let bestSubmittedOneRepMaxByExerciseID: [String: Double]
    let chartLifts: [LiftSubmission]
    let bestSubmittedLift: LiftSubmission?
    let latestSubmittedLift: LiftSubmission?

    static let empty = ProfileLiftPresentation(profileID: UUID(), lifts: [])

    init(profileID: UUID, lifts: [LiftSubmission]) {
        self.lifts = lifts
        let submittedTotal = RankingCalculator.powerliftingBreakdown(for: profileID, lifts: lifts)
        threeLiftTotalPounds = RankingCalculator.kilogramsToPounds(submittedTotal.totalKilograms)
        bestSubmittedOneRepMaxByExerciseID = [
            "bench": submittedTotal.benchKilograms,
            "squat": submittedTotal.squatKilograms,
            "deadlift": submittedTotal.deadliftKilograms
        ].compactMapValues { $0.map(RankingCalculator.kilogramsToPounds) }
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
        let profileID = profile.id
        let presentation = await Task.detached(priority: .userInitiated) {
            ProfileLiftPresentation(profileID: profileID, lifts: lifts)
        }.value
        guard !Task.isCancelled else { return }
        liftPresentation = presentation
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                (dynamicTypeSize.isAccessibilitySize
                 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                 : AnyLayout(HStackLayout(spacing: 12))) {
                    Button {
                        if isCurrentUser { showingPhotoManager = true }
                    } label: {
                        ProfileAvatar(profile: profile, size: 60, accent: .liftAccentText)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName.isEmpty
                             ? (isCurrentUser ? "Your profile" : "Athlete profile")
                             : profile.displayName)
                            .font(.title2.weight(.bold))
                        if !profile.username.isEmpty || isCurrentUser {
                            Text(profile.username.isEmpty
                                 ? "Add a username"
                                 : "@\(profile.username)")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                if let bio = profile.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(showsProfileDetails ? nil : 2)
                }
                DisclosureGroup(isExpanded: $showsProfileDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        if isCurrentUser || hasVisiblePublicLocation {
                            Label(identityLocation, systemImage: profile.hideGym && profile.hideCity ? "eye.slash" : "location")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }
                        if isCurrentUser || profile.yearsExperience > 0 {
                            let trainingDetails = displayedExperienceLevel.rawValue
                            if !trainingDetails.isEmpty {
                                Text("Verified experience · \(trainingDetails)")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Text("\(profile.yearsExperience) \(profile.yearsExperience == 1 ? "year" : "years") training")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        if (isCurrentUser || !profile.hideBodyweight), let loggedWeight = displayedLoggedBodyweight {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Logged weight · \(MeasurementFormatting.formatBodyweight(loggedWeight.pounds, preferredUnit: profile.preferredUnit))")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Text("Last updated \(loggedWeight.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Profile details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                .tint(Color.liftAccentText)
                if isCurrentUser && (profile.displayName.isEmpty || profile.username.isEmpty) {
                    Button("Complete profile") {
                        appState.showingEditProfile = true
                    }
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftAccentText)
                    .frame(minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
                }
            }
        }
    }

    func athleteDetails(presentation: ProfileLiftPresentation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCurrentUser {
                achievements
                Button("Open detailed strength progress in Track") {
                    appState.router.progressCategory = .strength
                    appState.trainingTrackerStartOnProgress = true
                    appState.requestedTrackerSegment = "Progress"
                    appState.selectedTab = 2
                }
                .frame(minHeight: LiftDesign.minimumTouchTarget)
            } else {
                progress(presentation: presentation)
            }
            rankings
        }
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
            CompactSectionHeader(title: "Strength record")
            Text("\(presentation.lifts.count) \(isCurrentUser ? "submissions" : "shared submissions") across \(Set(presentation.lifts.map(\.exerciseID)).count) exercises")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            if totalPounds <= 0 {
                LiftEmptyState(
                    title: "No submitted lifts yet",
                    message: isCurrentUser
                        ? "Submit a bench press, squat, or deadlift to build your strength history."
                        : "This athlete has no submitted three-lift total yet.",
                    symbolName: "dumbbell.fill",
                    actionTitle: isCurrentUser ? "Submit lift" : nil,
                    action: isCurrentUser ? { appState.showingSubmitSheet = true } : nil,
                    compact: true
                )
            } else {
                LiftCard(padding: 20, radius: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SUBMITTED THREE-LIFT TOTAL")
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(Color.liftAccentText)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(RankingCalculator.format(MeasurementFormatting.convert(totalPounds, from: .pounds, to: profile.preferredUnit)))
                                    .font(.largeTitle.weight(.bold))
                                    .monospacedDigit()
                                Text(profile.preferredUnit.shortLabel)
                                    .font(.headline)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Submitted three-lift total, \(profileTotalText)")
                        }
                        Divider().overlay(Color.liftSeparator)
                        Text("Best submitted 1RM")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        let benchmarks = [
                            ("Bench", liftValue("bench", presentation: presentation)),
                            ("Squat", liftValue("squat", presentation: presentation)),
                            ("Deadlift", liftValue("deadlift", presentation: presentation))
                        ].filter { $0.1 != "—" }
                        (dynamicTypeSize.isAccessibilitySize
                         ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                         : AnyLayout(HStackLayout(spacing: 0))) {
                            ForEach(Array(benchmarks.enumerated()), id: \.offset) { index, benchmark in
                                strengthMetric(benchmark.0, benchmark.1)
                                if index < benchmarks.count - 1 && !dynamicTypeSize.isAccessibilitySize { profileDivider }
                            }
                        }
                        if !profile.hideBodyweight || isCurrentUser {
                            Divider().overlay(Color.liftSeparator)
                            HStack {
                                Text("Relative total")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                Spacer()
                                Text(relativeTotalText)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text("Three-lift total ÷ profile bodyweight (\(MeasurementFormatting.formatBodyweight(displayedBodyweightPounds, preferredUnit: profile.preferredUnit))). Reference measurement date is unavailable.")
                                .font(.caption2).foregroundStyle(Color.liftMuted)

                        }
                    }
                }
            }
        }
    }

    var rankings: some View {
        Button {
            appState.selectedTab = 1
            if !isCurrentUser { dismiss() }
        } label: {
            HStack {
                Label("View Leaderboards", systemImage: "list.number")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: LiftDesign.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.liftAccentText)
    }

    func progress(presentation: ProfileLiftPresentation) -> some View {
        let exercises = Dictionary(grouping: presentation.lifts, by: \.exerciseID).values
            .compactMap { $0.first }.sorted { $0.exerciseName < $1.exerciseName }
        let selectedID = exercises.contains(where: { $0.exerciseID == profileProgressExerciseID })
            ? profileProgressExerciseID : presentation.chartLifts.last?.exerciseID ?? ""
        let chartLifts = Array(presentation.lifts.filter { $0.exerciseID == selectedID }
            .sorted { $0.performedAt < $1.performedAt }.suffix(6))
        let chartPoints = chartPoints(lifts: chartLifts)
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Lift submission progress")
            if !exercises.isEmpty {
                Picker("Submitted exercise", selection: Binding(get: { selectedID }, set: { profileProgressExerciseID = $0 })) {
                    ForEach(exercises, id: \.exerciseID) { Text($0.exerciseName).tag($0.exerciseID) }
                }
                .tint(Color.liftAccentText)
            }
            LiftCard {
                VStack(alignment: .leading, spacing: 12) {
                if chartPoints.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                            .frame(width: 38, height: 38)
                            .background(Color.liftAccentText.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No lift submission history yet")
                                .font(LiftTypography.rowEmphasis)
                            Text(isCurrentUser
                                 ? "Workout history is available below. Submit lifts to build this chart."
                                 : "No submitted lifts are available to show.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer(minLength: 4)
                        if isCurrentUser {
                            Button("Submit lift") {
                                appState.showingSubmitSheet = true
                            }
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftAccentText)
                            .frame(minHeight: LiftDesign.minimumTouchTarget)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if chartPoints.count == 1, let point = chartPoints.first {
                    Text(chartLifts.last?.exerciseName ?? "Submitted lift")
                        .font(LiftTypography.cardTitle)
                    Text(MeasurementFormatting.formatRecordedWeight(point.value, unit: profile.preferredUnit))
                        .font(.title2.weight(.semibold))
                    Text("\(chartLifts.first?.isActualOneRepMax == true ? "Actual 1RM" : "Estimated 1RM") · \(point.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text("One submitted lift. A trend appears after another submission.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    let values = chartPoints.map(\.value)
                    let minimum = values.min() ?? 0
                    let maximum = values.max() ?? minimum
                    let minimumPadding = MeasurementFormatting.convert(5, from: .pounds, to: profile.preferredUnit)
                    let padding = max(minimumPadding, (maximum - minimum) * 0.15)
                    Text(chartLifts.last?.exerciseName ?? "Submitted lift")
                        .font(.subheadline.weight(.semibold))
                    Text("1RM · \(profile.preferredUnit.shortLabel) · Actual or estimated as recorded in submission details")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value("1RM", point.value))
                            .foregroundStyle(Color.liftAccentText)
                        PointMark(x: .value("Date", point.date), y: .value("1RM", point.value))
                            .foregroundStyle(Color.liftGreen)
                    }
                    .frame(height: 190)
                    .chartYScale(domain: max(0, minimum - padding)...(maximum + padding))
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    HStack {
                        let best = chartLifts.max { $0.estimatedOneRepMax < $1.estimatedOneRepMax }
                        let latest = chartLifts.last
                        metric("Lifts shown", "\(chartLifts.count)")
                        metric(best.map { "Best · \($0.performedAt.formatted(.dateTime.month(.abbreviated).day()))" } ?? "Best shown", bestSubmittedLiftText(best))
                        metric(latest.map { "Latest · \($0.performedAt.formatted(.dateTime.month(.abbreviated).day()))" } ?? "Latest", latestSubmittedLiftText(latest))
                    }
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
                    let isUnlocked = unlocked(achievement)
                    HStack(spacing: 9) {
                        Image(systemName: achievement.symbolName)
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(isUnlocked ? Color.liftGold : Color.liftMuted)
                            .frame(width: 28, height: 28)
                            .background(Color.liftGold.opacity(isUnlocked ? 0.14 : 0))
                            .clipShape(Circle())
                        Text(profileAchievementTitle(achievement.title))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isUnlocked ? Color.liftText : Color.liftMuted)
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

    private func profileAchievementTitle(_ title: String) -> String {
        if title == "1 Training Hours" { return "1 Training Hour" }
        for exercise in ["Bench", "Squat", "Deadlift"] where title.hasSuffix(" \(exercise)") {
            let valueText = title.replacingOccurrences(of: " \(exercise)", with: "").replacingOccurrences(of: ",", with: "")
            if let pounds = Double(valueText) {
                let weight = MeasurementFormatting.formatDisplayedWeight(
                    RankingCalculator.poundsToKilograms(pounds),
                    unit: profile.preferredUnit
                ) { Int($0.rounded()).formatted() }
                return "\(weight) \(exercise)"
            }
        }
        if title.hasSuffix(" lb Total"),
           let pounds = Double(title.replacingOccurrences(of: " lb Total", with: "").replacingOccurrences(of: ",", with: "")) {
            let total = MeasurementFormatting.formatDisplayedWeight(
                RankingCalculator.poundsToKilograms(pounds),
                unit: profile.preferredUnit
            ) { Int($0.rounded()).formatted() }
            return "\(total) Total"
        }
        let suffix = " kg Lifted Volume"
        guard title.hasSuffix(suffix),
              let kilograms = Double(title.dropLast(suffix.count).replacingOccurrences(of: ",", with: "")) else {
            return title
        }
        let formatted = MeasurementFormatting.formatDisplayedWeight(
            kilograms,
            unit: profile.preferredUnit
        ) { Int($0.rounded()).formatted() }
        return "\(formatted) Lifted Volume"
    }

    func recentSubmissions(profileLifts: [LiftSubmission]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let cutoff = profileSubmissionDateRange.startDate()
            let query = profileSubmissionExercise.trimmingCharacters(in: .whitespacesAndNewlines)
            let submissions = profileLifts.filter { lift in
                (cutoff == nil || lift.performedAt >= cutoff!) &&
                    (query.isEmpty || lift.exerciseName.localizedCaseInsensitiveContains(query))
            }.sorted { $0.performedAt > $1.performedAt }
            CompactSectionHeader(title: "Lift submissions")
            Text("Dated lift attempts with verification status. Only shared lift submissions appear publicly; workout histories remain private.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 8) {
                Menu {
                    ForEach(ProfileHistoryDateRange.allCases) { range in
                        Button(range.rawValue) { profileSubmissionDateRange = range }
                    }
                } label: {
                    Label(profileSubmissionDateRange.rawValue, systemImage: "calendar")
                }
                TextField("Filter by exercise", text: $profileSubmissionExercise)
                    .textFieldStyle(.plain)
                    .padding(12).background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Filter lift submissions by exercise")
                Text("\(submissions.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.liftAccentText)
            if submissions.isEmpty {
                LiftEmptyState(
                    title: profileLifts.isEmpty ? "No submissions yet" : "No submissions match",
                    message: isCurrentUser
                        ? "Submit a lift to start your lift activity."
                        : profileLifts.isEmpty ? "This athlete has not shared a lift." : "Try another date range or exercise.",
                    symbolName: "dumbbell.fill",
                    actionTitle: isCurrentUser && profileLifts.isEmpty ? "Submit lift" : (submissions.isEmpty && !profileLifts.isEmpty ? "Clear filters" : nil),
                    action: {
                        if isCurrentUser && profileLifts.isEmpty {
                            appState.showingSubmitSheet = true
                        } else {
                            profileSubmissionDateRange = .allTime
                            profileSubmissionExercise = ""
                        }
                    },
                    compact: true
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array((showsAllProfileSubmissions ? submissions : Array(submissions.prefix(5))).enumerated()), id: \.offset) { index, lift in
                        HStack {
                            Button {
                                selectedProfileLiftHistory = .submitted(lift)
                            } label: {
                                HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lift.exerciseName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
                                        .foregroundStyle(Color.liftMuted)
                                    Text(lift.performedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
                                    if lift.visibility == .privateLift {
                                        Text("Private submission")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View \(lift.exerciseName) submission, \(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true)), \(LiftTimeFormatter.shortDateTime(lift.performedAt))")
                            .accessibilityHint("Shows lift details and verification status")
                            if isCurrentUser {
                                Menu {
                                    if lift.requiresCoordinatedRemoval {
                                        Button("Remove submission and video", role: .destructive) {
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
                        if index < min((showsAllProfileSubmissions ? submissions.count : 5) - 1, submissions.count - 1) {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 14)
                        }
                    }
                }
                .liftSurface()
                if submissions.count > 5 {
                    Button(showsAllProfileSubmissions ? "Show fewer" : "Show all \(submissions.count) submissions") {
                        showsAllProfileSubmissions.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftAccentText)
                }
            }
        }
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
        let workoutDatesWithMultipleSessions = Set(Dictionary(grouping: workouts) {
            Calendar.current.startOfDay(for: $0.completedAt)
        }.filter { $0.value.count > 1 }.keys)
        return VStack(alignment: .leading, spacing: 10) {
            if selectedProfileSection != .history {
                CompactSectionHeader(title: "Workout history")
            }
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
                    Text("\(workouts.count) workouts")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftAccentText)
                TextField("Filter by exercise", text: $profileHistoryExercise)
                    .textFieldStyle(.plain)
                    .padding(12).background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        Button {
                            selectedTimelineWorkout = workout
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .foregroundStyle(Color.liftAccentText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(workout.name.isEmpty ? workout.dayLabel : workout.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(workoutDatesWithMultipleSessions.contains(Calendar.current.startOfDay(for: workout.completedAt))
                                         ? workout.completedAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
                                         : workout.completedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                    if workout.sourcePlanID != nil {
                                        Text("Program")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.liftAccentText)
                                    }
                                }
                                Spacer()
                                Text("\(workout.completedWorkingSets.count) sets")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View \(workout.name.isEmpty ? workout.dayLabel : workout.name), \(workout.completedWorkingSets.count) sets, \(workout.completedAt.formatted(date: .abbreviated, time: .omitted))")
                        if index < workouts.count - 1 {
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
        let recentEvents = Array(events.reversed())
        let eventGroups = Dictionary(grouping: recentEvents) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Training milestones")
            if events.isEmpty {
                LiftEmptyState(
                    title: "No milestones yet",
                    message: "Complete a workout to start your personal training timeline.",
                    symbolName: "flag"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(eventGroups.enumerated()), id: \.offset) { groupIndex, group in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.key.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.liftMuted)
                                .padding(.horizontal, 14)
                                .padding(.top, groupIndex == 0 ? 12 : 8)
                                .padding(.bottom, 4)
                            ForEach(Array(group.value.enumerated()), id: \.element.id) { eventIndex, event in
                                let row = HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: event.workout == nil ? "flag.fill" : "dumbbell.fill")
                                            .foregroundStyle(Color.liftGold)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.liftText)
                                            if !event.detail.isEmpty && event.detail != "Training milestone" {
                                                Text(event.detail)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                            }
                                        }
                                        Spacer()
                                        if event.workout != nil {
                                            Image(systemName: "chevron.right")
                                                .font(LiftTypography.compactEmphasis)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let workout = event.workout {
                                    Button { selectedTimelineWorkout = workout } label: { row }.buttonStyle(.plain)
                                } else { row }
                                if eventIndex < group.value.count - 1 {
                                    Divider().overlay(Color.liftSeparator).padding(.leading, 48)
                                }
                            }
                        }
                        if groupIndex < eventGroups.count - 1 {
                            Divider().overlay(Color.liftSeparator)
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
                detail: "",
                workout: nil
            )
        })
        guard !workouts.isEmpty else { return events.sorted { $0.date < $1.date } }
        let milestones = [1, 5, 10, 25, 50, 100, 200]
        for milestone in milestones where workouts.count >= milestone {
            let workout = workouts[milestone - 1]
            let title = milestone == 1 ? "First workout" : "\(milestone.formatted()) workouts"
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
        Group {
            if isCurrentUser, let exerciseID = RankingCalculator.strengthTierExerciseIDs.first(where: { $0 == title.lowercased() }) {
                Button {
                    selectedProfileLiftHistory = .exerciseHistory(id: exerciseID, name: title)
                } label: {
                    strengthMetricLabel(title, value)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.strength.\(exerciseID)")
                .accessibilityHint("Opens workout history and lift submission options")
            } else {
                strengthMetricLabel(title, value)
            }
        }
        .frame(maxWidth: .infinity, minHeight: LiftDesign.minimumTouchTarget, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func strengthMetricLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var displayedLoggedBodyweight: (pounds: Double, date: Date)? {
        if profile.id == appState.currentProfile.id {
            guard let entry = appState.bodyweightEntries
                .filter({ ($0.actual ?? 0) > 0 })
                .max(by: { $0.targetDate < $1.targetDate }),
                  let pounds = entry.actual else { return nil }
            return (pounds, entry.targetDate)
        }
        guard profile.bodyweightPounds > 0,
              let date = profile.bodyweightLastUpdatedAt else { return nil }
        return (profile.bodyweightPounds, date)
    }

    private var displayedBodyweightPounds: Double {
        guard profile.id == appState.currentProfile.id else { return profile.bodyweightPounds }
        return ProfileDataAuthority.latestLoggedBodyweight(
            profilePounds: profile.bodyweightPounds,
            entries: appState.bodyweightEntries
        )
    }

    var displayedExperienceLevel: ExperienceLevel {
        guard profile.id == appState.currentProfile.id else { return profile.experienceLevel }
        return appState.earnedExperienceLevel
    }

    func liftValue(_ exerciseID: String, presentation: ProfileLiftPresentation) -> String {
        let best = presentation.bestSubmittedOneRepMaxByExerciseID[exerciseID] ?? 0
        guard best > 0 else { return "—" }
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
