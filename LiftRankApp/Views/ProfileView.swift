import Charts
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    let profile: UserProfile
    let isCurrentUser: Bool
    private struct ProfileChartPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private var profileLifts: [LiftSubmission] {
        appState.lifts.filter { $0.userID == profile.id }
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summary
                    rankings
                    progress
                    videos
                    achievements
                    recentSubmissions
                }
                .padding()
            }
            .navigationTitle(isCurrentUser ? "Profile" : profile.username)
            .toolbar {
                if isCurrentUser {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Profile") { appState.showingEditProfile = true }
                            Button("Moderator Review") { appState.showingModeratorReview = true }
                            Button("Settings") { appState.showingSettings = true }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ProfileAvatar(profile: profile, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.title.bold())
                        Text("@\(profile.username)")
                            .foregroundStyle(Color.liftMuted)
                        VerificationBadge(status: .moderatorVerified)
                    }
                    Spacer()
                }
                Text("\(profile.hideGym ? "Gym hidden" : profile.primaryGymName) - \(profile.hideCity ? "Location hidden" : "\(profile.city), \(profile.state)")")
                    .foregroundStyle(Color.liftMuted)
                Text("\(profile.ageGroup) - \(weightClassName) - \(profile.experienceLevel.rawValue)")
                    .font(.subheadline)
                HStack {
                    metric("Followers", "\(profile.followers)")
                    metric("Following", "\(profile.following)")
                    if isCurrentUser {
                        Button("Edit Profile") {
                            appState.showingEditProfile = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liftBlue)
                    }
                }
                if !isCurrentUser {
                    socialActions
                }
            }
        }
    }

    private var socialActions: some View {
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

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "Overall score", value: "\(Int(appState.overallScore))", subtitle: "Prototype formula", symbolName: "bolt.fill")
            MetricCard(title: "Bench PR", value: liftValue("bench"), subtitle: "Personal record", tint: .liftGreen)
            MetricCard(title: "Squat PR", value: liftValue("squat"), subtitle: "Personal record", tint: .liftGreen)
            MetricCard(title: "Deadlift PR", value: liftValue("deadlift"), subtitle: "Personal record", tint: .liftGold)
            MetricCard(title: "Total", value: "\(Int(RankingCalculator.totalForUser(profile.id, lifts: appState.lifts))) lb", subtitle: "Bench + squat + deadlift", tint: .liftBlue)
            MetricCard(title: "Relative total", value: relativeTotalText, subtitle: "Total / bodyweight", tint: .liftBlue)
        }
    }

    private var rankings: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Rankings")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Gym", value: "#4", subtitle: "Deadlift", tint: .liftGold)
                MetricCard(title: "City", value: "#18", subtitle: "Miami", tint: .liftBlue)
                MetricCard(title: "State", value: "#72", subtitle: "Florida", tint: .liftBlue)
                MetricCard(title: "Age group", value: "Top 9%", subtitle: profile.ageGroup, tint: .liftGreen)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Progress")
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

    private var videos: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Lift videos")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(profileLifts.prefix(5)) { lift in
                        LiftCard {
                            VStack(alignment: .leading) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.liftBlue)
                                Text(lift.exerciseName)
                                    .font(.headline)
                                VerificationBadge(status: lift.verificationStatus)
                            }
                        }
                        .frame(width: 170)
                    }
                }
            }
        }
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(appState.achievements.prefix(8)) { achievement in
                    LiftCard {
                        HStack {
                            Image(systemName: achievement.symbolName)
                                .foregroundStyle(unlocked(achievement) ? Color.liftGold : Color.liftMuted)
                            Text(achievement.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(unlocked(achievement) ? .white : Color.liftMuted)
                        }
                    }
                }
            }
        }
    }

    private var recentSubmissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent submissions")
            ForEach(profileLifts.prefix(5)) { lift in
                LiftCard {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(lift.exerciseName)
                                .font(.headline)
                            Text("\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) x \(lift.repetitions)")
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        VerificationBadge(status: lift.verificationStatus)
                    }
                }
            }
        }
    }

    private var weightClassName: String {
        guard let weightClass = RankingCalculator.weightClass(
            for: profile.bodyweightPounds,
            sexCategory: profile.sexCategory,
            classes: MockData.weightClasses
        ) else { return "Open" }
        guard profile.preferredUnit == .pounds else { return weightClass.name }
        if let maximum = weightClass.maxKilograms {
            return "\(RankingCalculator.format(RankingCalculator.usaplPoundEquivalent(maximum))) lb (\(weightClass.name))"
        }
        let lower = RankingCalculator.usaplPoundEquivalent(weightClass.minKilograms ?? 0)
        return "\(RankingCalculator.format(lower))+ lb (\(weightClass.name))"
    }

    private var relativeTotalText: String {
        let total = RankingCalculator.totalForUser(profile.id, lifts: appState.lifts)
        return String(format: "%.2fx", RankingCalculator.relativeTotal(total: total, bodyweight: profile.bodyweightPounds))
    }

    private func liftValue(_ exerciseID: String) -> String {
        let best = RankingCalculator.bestLift(exerciseID: exerciseID, submissions: profileLifts)?.estimatedOneRepMax ?? 0
        return "\(Int(best)) lb"
    }

    private func unlocked(_ achievement: Achievement) -> Bool {
        ["First Lift Logged", "405 Deadlift", "2x Bodyweight Deadlift", "Top 10 at Your Gym"].contains(achievement.title)
    }

    private var friendActionSymbol: String {
        switch appState.friendRequest(with: profile)?.status {
        case .accepted:
            return "person.crop.circle.badge.checkmark"
        case .pending:
            return appState.friendRequest(with: profile)?.fromUserID == appState.currentProfile.id ? "clock.fill" : "person.crop.circle.badge.plus"
        case .declined, nil:
            return "person.badge.plus"
        }
    }

    private var friendActionTint: Color {
        guard let request = appState.friendRequest(with: profile) else { return Color.liftBlue }
        if request.status == .accepted { return Color.liftGreen }
        if request.status == .pending && request.toUserID == appState.currentProfile.id { return Color.liftBlue }
        return Color.liftMuted
    }

    private var isFriendActionDisabled: Bool {
        guard let request = appState.friendRequest(with: profile) else { return false }
        return request.status == .accepted || (request.status == .pending && request.fromUserID == appState.currentProfile.id)
    }

    private func handleFriendAction() {
        if let request = appState.friendRequest(with: profile), request.status == .pending, request.toUserID == appState.currentProfile.id {
            appState.acceptFriendRequest(request)
        } else {
            appState.sendFriendRequest(to: profile)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
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

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MockData.demoProfile
    private var ageGroups: [String] {
        MockData.standardAgeGroups.contains(draft.ageGroup)
            ? MockData.standardAgeGroups
            : [draft.ageGroup] + MockData.standardAgeGroups
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Identity") {
                        TextField("Username", text: $draft.username)
                        TextField("Display name", text: $draft.displayName)
                        Picker("Age group", selection: $draft.ageGroup) {
                            ForEach(ageGroups, id: \.self) { ageGroup in
                                Text(ageGroup).tag(ageGroup)
                            }
                        }
                        Picker("Sex category", selection: $draft.sexCategory) {
                            ForEach(SexCategory.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Experience", selection: $draft.experienceLevel) {
                            ForEach(ExperienceLevel.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                    Section("Body") {
                        NumericInputField(title: "Height", value: $draft.heightInches, unit: "in", presentation: .formRow)
                        NumericInputField(title: "Bodyweight", value: $draft.bodyweightPounds, unit: "lb", presentation: .formRow)
                    }
                    Section("Location") {
                        TextField("City", text: $draft.city)
                        TextField("State", text: $draft.state)
                        TextField("Primary gym", text: $draft.primaryGymName)
                    }
                    Section("Privacy") {
                        Toggle("Hide bodyweight", isOn: $draft.hideBodyweight)
                        Toggle("Hide exact age", isOn: $draft.hideExactAge)
                        Toggle("Hide city", isOn: $draft.hideCity)
                        Toggle("Hide gym", isOn: $draft.hideGym)
                        Toggle("Hide lift videos", isOn: $draft.hideLiftVideos)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .onAppear { draft = appState.currentProfile }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.updateProfile(draft)
                        dismiss()
                    }
                }
            }
        }
    }

}
