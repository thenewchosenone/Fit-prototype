import Charts
import SwiftUI

private struct ProfileChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

extension ProfileView {
    var profileLifts: [LiftSubmission] {
        ProfileLiftVideoLibrary.visibleLifts(
            for: profile.id,
            viewerID: appState.currentProfile.id,
            allLifts: appState.lifts,
            includeLiftsWithoutVideo: true
        )
    }

    func refreshVisibleProfileLifts() {
        visibleProfileLifts = profileLifts
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
                        Text(profile.displayName)
                            .font(.title3.weight(.bold))
                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
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
                Label(identityLocation, systemImage: profile.hideGym && profile.hideCity ? "eye.slash" : "location")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)
                if let bio = profile.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(Color.liftText)
                }
                Text("\(profile.hideBodyweight ? "Weight class hidden" : weightClassName) • \(displayedExperienceLevel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Text("\(profile.yearsExperience) \(profile.yearsExperience == 1 ? "year" : "years") training")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    func athleteDetails(profileLifts: [LiftSubmission]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $showingAthleteDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    rankings
                    progress(profileLifts: profileLifts)
                    achievements
                }
                .padding(.top, 18)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("More athlete details")
                        .font(.headline)
                        .foregroundStyle(Color.liftText)
                    Text("Rankings, progress, videos, and achievements")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftBlue)
        }
        .padding(16)
        .liftSurface()
    }

    var identityLocation: String {
        let gym = profile.hideGym ? nil : profile.primaryGymName
        let location = profile.hideCity ? nil : "\(profile.city), \(profile.state)"
        let value = [gym, location].compactMap { $0 }.joined(separator: " • ")
        return value.isEmpty ? "Gym and location hidden" : value
    }

    func summary(profileLifts: [LiftSubmission]) -> some View {
        let totalPounds = RankingCalculator.totalForUser(profile.id, lifts: profileLifts)
        let profileTotalText = RankingFormatting.threeLiftTotalText(totalPounds: totalPounds, preferredUnit: profile.preferredUnit)
        let relativeTotalText = RankingFormatting.ratioText(
            RankingCalculator.relativeTotal(total: totalPounds, bodyweight: profile.bodyweightPounds)
        )
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Strength")
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
                                .foregroundStyle(Color.liftBlue)
                        }
                    }
                    Divider().overlay(Color.liftSeparator)
                    HStack(spacing: 0) {
                        strengthMetric("Bench", liftValue("bench", profileLifts: profileLifts))
                        profileDivider
                        strengthMetric("Squat", liftValue("squat", profileLifts: profileLifts))
                        profileDivider
                        strengthMetric("Deadlift", liftValue("deadlift", profileLifts: profileLifts))
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
                            rankingMetric("City", profile.hideCity ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideCity ? "Location hidden" : "Open city leaderboard", .liftBlue)
                        case "state":
                            rankingMetric("State", profile.hideCity ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideCity ? "Location hidden" : "Open state leaderboard", .liftBlue)
                        default:
                            rankingMetric("Age group", profile.hideExactAge ? "Hidden" : CanonicalRankingPresentation.text(rank: nil), profile.hideExactAge ? "Age hidden" : "Open age leaderboard", .liftGreen)
                        }
                    }
                }
            }
        }
    }

    func progress(profileLifts: [LiftSubmission]) -> some View {
        let chartPoints = chartPoints(profileLifts: profileLifts)
        return VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Progress")
            LiftCard {
                if chartPoints.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                            .frame(width: 38, height: 38)
                            .background(Color.liftBlue.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No strength history yet")
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
                            .foregroundStyle(Color.liftBlue)
                            .frame(minHeight: LiftDesign.minimumTouchTarget)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Month", point.label), y: .value("Max", point.value))
                            .foregroundStyle(Color.liftBlue)
                        PointMark(x: .value("Month", point.label), y: .value("Max", point.value))
                            .foregroundStyle(Color.liftGreen)
                    }
                    .frame(height: 190)
                    HStack {
                        metric("Lifts", "\(profileLifts.count)")
                        metric("Best", bestSubmittedLiftText(profileLifts: profileLifts))
                        metric("Latest", latestSubmittedLiftText(profileLifts: profileLifts))
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
            for: profile.bodyweightPounds,
            sexCategory: profile.sexCategory,
            classes: WeightClassCatalog.all
        ) else { return "Bodyweight needed" }
        return RankingFormatting.weightClassDisplayName(weightClass, preferredUnit: profile.preferredUnit)
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
        appState.currentUserTotalRankingEntry == nil ? "No canonical total rank" : "Verified total leaderboard"
    }

    private var canonicalScoreText: String {
        guard isCurrentUser, let entry = appState.currentUserTotalRankingEntry else { return "—" }
        return entry.score.formatted(.number.precision(.fractionLength(0...2)))
    }

    func liftValue(_ exerciseID: String, profileLifts: [LiftSubmission]) -> String {
        let best = RankingCalculator.bestLift(exerciseID: exerciseID, submissions: profileLifts)?.estimatedOneRepMax ?? 0
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

    private func chartPoints(profileLifts: [LiftSubmission]) -> [ProfileChartPoint] {
        profileLifts
            .sorted { $0.performedAt < $1.performedAt }
            .suffix(6)
            .map {
                ProfileChartPoint(
                    label: $0.performedAt.formatted(.dateTime.month(.abbreviated)),
                    value: MeasurementFormatting.convert($0.estimatedOneRepMax, from: .kilograms, to: profile.preferredUnit)
                )
            }
    }

    private func bestSubmittedLiftText(profileLifts: [LiftSubmission]) -> String {
        guard let best = profileLifts.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax }) else { return "—" }
        return MeasurementFormatting.formatDisplayedWeight(best.estimatedOneRepMax, unit: profile.preferredUnit)
    }

    private func latestSubmittedLiftText(profileLifts: [LiftSubmission]) -> String {
        guard let latest = profileLifts.max(by: { $0.performedAt < $1.performedAt }) else { return "—" }
        return MeasurementFormatting.formatDisplayedWeight(latest.estimatedOneRepMax, unit: profile.preferredUnit)
    }
}
