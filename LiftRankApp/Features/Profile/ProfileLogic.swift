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
                Text("\(profile.hideBodyweight ? "Weight class hidden" : weightClassName) • \(profile.experienceLevel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                HStack(spacing: 12) {
                    metric("Connections", "\(connectionCount)")
                }
                if !isCurrentUser {
                    socialActions
                } else {
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

    var socialActions: some View {
        HStack(spacing: 10) {
            Button {
                handleFriendAction()
            } label: {
                Label(appState.friendActionTitle(for: profile), systemImage: friendActionSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(friendActionTint)
            .disabled(isFriendActionDisabled)
            .accessibilityHint(outgoingPendingFriendRequest == nil ? "" : "Double tap to cancel this friend request")

            if appState.features.messaging {
                Button {
                    appState.openMessageThread(with: profile)
                } label: {
                    Label("Message", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.liftBlue)
            }
        }
    }

    var connectionCount: Int {
        if isCurrentUser {
            return appState.remoteFriendRelationships.filter { $0.status == .accepted }.count
        }
        return max(profile.followers, profile.following)
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
                            Text("\(Int(RankingCalculator.totalForUser(profile.id, lifts: appState.lifts))) lb")
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
                    rankingMetric("Age group", profile.hideExactAge ? "Hidden" : "Top 9%", profile.hideExactAge ? "Age hidden" : profile.ageGroup, .liftGreen)
                }
            }
        }
    }

    var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Progress")
            LiftCard {
                Chart(chartPoints) { point in
                    LineMark(x: .value("Month", point.label), y: .value("Max", point.value))
                        .foregroundStyle(Color.liftBlue)
                    PointMark(x: .value("Month", point.label), y: .value("Max", point.value))
                        .foregroundStyle(Color.liftGreen)
                }
                .frame(height: 190)
                HStack {
                    metric("30 days", "+5 lb")
                    metric("90 days", "+20 lb")
                    metric("1 year", "+65 lb")
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
        ) else { return "Open" }
        return RankingFormatting.weightClassDisplayName(weightClass, preferredUnit: profile.preferredUnit)
    }

    var relativeTotalText: String {
        let total = RankingCalculator.totalForUser(profile.id, lifts: appState.lifts)
        return RankingFormatting.ratioText(
            RankingCalculator.relativeTotal(total: total, bodyweight: profile.bodyweightPounds)
        )
    }

    func liftValue(_ exerciseID: String) -> String {
        let best = RankingCalculator.bestLift(exerciseID: exerciseID, submissions: profileLifts)?.estimatedOneRepMax ?? 0
        return "\(Int(best)) lb"
    }

    func unlocked(_ achievement: Achievement) -> Bool {
        appState.achievementUnlocks.contains { $0.title == achievement.title }
    }

    var friendActionSymbol: String {
        switch appState.friendRequest(with: profile)?.status {
        case .accepted:
            return "person.crop.circle.badge.checkmark"
        case .pending:
            return appState.friendRequest(with: profile)?.fromUserID == appState.currentProfile.id ? "clock.fill" : "person.crop.circle.badge.plus"
        case .declined, nil:
            return "person.badge.plus"
        }
    }

    var friendActionTint: Color {
        guard let request = appState.friendRequest(with: profile) else { return Color.liftBlue }
        if request.status == .accepted { return Color.liftGreen }
        if request.status == .pending && request.toUserID == appState.currentProfile.id { return Color.liftBlue }
        return Color.liftMuted
    }

    var isFriendActionDisabled: Bool {
        guard let request = appState.friendRequest(with: profile) else { return false }
        return request.status == .accepted
    }

    var outgoingPendingFriendRequest: FriendRequest? {
        guard let request = appState.friendRequest(with: profile),
              request.status == .pending,
              request.fromUserID == appState.currentProfile.id else { return nil }
        return request
    }

    func handleFriendAction() {
        if outgoingPendingFriendRequest != nil {
            showingCancelFriendRequest = true
        } else if let request = appState.friendRequest(with: profile), request.status == .pending, request.toUserID == appState.currentProfile.id {
            appState.acceptFriendRequest(request)
        } else {
            appState.sendFriendRequest(to: profile)
        }
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
        [
            ProfileChartPoint(label: "Jan", value: 405),
            ProfileChartPoint(label: "Feb", value: 425),
            ProfileChartPoint(label: "Mar", value: 455),
            ProfileChartPoint(label: "Apr", value: 475),
            ProfileChartPoint(label: "May", value: 485),
            ProfileChartPoint(label: "Jun", value: 495)
        ]
    }
}
