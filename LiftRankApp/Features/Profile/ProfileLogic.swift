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

    var header: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Button {
                        if isCurrentUser { showingPhotoManager = true }
                    } label: {
                        ProfileAvatar(profile: profile, size: UIScreen.main.bounds.width < 380 ? 84 : 96)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.title2.weight(.bold))
                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                }
                Label(identityLocation, systemImage: profile.hideGym && profile.hideCity ? "eye.slash" : "location")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)
                Text("\(profile.hideBodyweight ? "Weight class hidden" : weightClassName) • \(displayedExperienceLevel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                if isCurrentUser {
                    HStack(spacing: 10) {
                        Button {
                            showingPhotoManager = true
                        } label: {
                            Label("Change photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiftSecondaryButtonStyle())
                        Button {
                            appState.showingEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiftSecondaryButtonStyle())
                    }
                }
            }
        }
    }

    var athleteDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $showingAthleteDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    rankings
                    progress
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

    var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                            Text("\(Int(appState.overallScore))")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.liftBlue)
                        }
                    }
                    Divider().overlay(Color.liftSeparator)
                    HStack(spacing: 0) {
                        strengthMetric("Bench", liftValue("bench"))
                        profileDivider
                        strengthMetric("Squat", liftValue("squat"))
                        profileDivider
                        strengthMetric("Deadlift", liftValue("deadlift"))
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
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Rankings")
            LiftCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    rankingMetric("Global", "Unranked", "Complete verified lifts", .liftGold)
                    rankingMetric("City", profile.hideCity ? "Hidden" : "Unranked", profile.hideCity ? "Location hidden" : profile.city, .liftBlue)
                    rankingMetric("State", profile.hideCity ? "Hidden" : "Unranked", profile.hideCity ? "Location hidden" : profile.state, .liftBlue)
                    rankingMetric("Age group", profile.hideExactAge ? "Hidden" : "Unranked", profile.hideExactAge ? "Age hidden" : profile.ageGroup, .liftGreen)
                }
            }
        }
    }

    var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Progress")
            LiftCard {
                if chartPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No strength history yet")
                            .font(.headline.weight(.bold))
                        Text("Submit verified lifts to build this progress chart.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
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
                        metric("Best", bestSubmittedLiftText)
                        metric("Latest", latestSubmittedLiftText)
                    }
                }
            }
        }
    }

    var achievements: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(appState.achievements.prefix(12)) { achievement in
                    HStack(spacing: 9) {
                        HStack {
                            Image(systemName: achievement.symbolName)
                                .foregroundStyle(unlocked(achievement) ? Color.liftGold : Color.liftMuted)
                            Text(achievement.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(unlocked(achievement) ? Color.liftText : Color.liftMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .liftSurface(radius: 12)
                }
            }
        }
    }

    var recentSubmissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Recent submissions")
            VStack(spacing: 0) {
                ForEach(Array(profileLifts.prefix(5).enumerated()), id: \.element.id) { index, lift in
                    HStack {
                VStack(alignment: .leading) {
                    Text(lift.exerciseName)
                        .font(.headline)
                    Text(MeasurementFormatting.liftSetText(weightKilograms: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
                        .foregroundStyle(Color.liftMuted)
                }
                        Spacer()
                        VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
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

    var relativeTotalText: String {
        let total = RankingCalculator.totalForUser(profile.id, lifts: appState.lifts)
        return RankingFormatting.ratioText(
            RankingCalculator.relativeTotal(total: total, bodyweight: profile.bodyweightPounds)
        )
    }

    var profileTotalText: String {
        let totalPounds = RankingCalculator.totalForUser(profile.id, lifts: appState.lifts)
        return RankingFormatting.threeLiftTotalText(totalPounds: totalPounds, preferredUnit: profile.preferredUnit)
    }

    var displayedExperienceLevel: ExperienceLevel {
        guard isCurrentUser else { return profile.experienceLevel }
        return appState.earnedExperienceLevel
    }

    func liftValue(_ exerciseID: String) -> String {
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

    private var chartPoints: [ProfileChartPoint] {
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

    private var bestSubmittedLiftText: String {
        guard let best = profileLifts.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax }) else { return "—" }
        return MeasurementFormatting.formatDisplayedWeight(best.estimatedOneRepMax, unit: profile.preferredUnit)
    }

    private var latestSubmittedLiftText: String {
        guard let latest = profileLifts.max(by: { $0.performedAt < $1.performedAt }) else { return "—" }
        return MeasurementFormatting.formatDisplayedWeight(latest.estimatedOneRepMax, unit: profile.preferredUnit)
    }
}
