import Charts
import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    let profile: UserProfile
    let isCurrentUser: Bool
    @State private var showingPhotoManager = false
    @State private var showingAthleteDetails = false
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
                    recentSubmissions
                    athleteDetails
                }
                .padding()
                .padding(.bottom, isCurrentUser ? 96 : 24)
            }
            .sheet(isPresented: $showingPhotoManager) {
                ProfilePhotoManagerView()
                    .environmentObject(appState)
            }
            .navigationTitle(isCurrentUser ? "Profile" : profile.username)
            .toolbar {
                if isCurrentUser {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            appState.showingSubmitSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("Submit a lift")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Profile") { appState.showingEditProfile = true }
                            if appState.isForumStaff {
                                Button("Moderator Review") { appState.showingModeratorReview = true }
                            }
                            Button("Settings") { appState.showingSettings = true }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                        }
                        .accessibilityLabel("Profile options")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(appState.isBlocked(profile.id) ? "Unblock athlete" : "Block athlete", role: appState.isBlocked(profile.id) ? nil : .destructive) {
                                appState.setBlocked(profile.id, blocked: !appState.isBlocked(profile.id))
                            }
                        } label: { Image(systemName: "ellipsis.circle.fill") }
                        .accessibilityLabel("Athlete options")
                    }
                }
            }
        }
    }

    private var header: some View {
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
                    metric("Followers", "\(profile.followers)")
                    metric("Following", "\(profile.following)")
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

    private var athleteDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $showingAthleteDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    rankings
                    progress
                    videos
                    achievements
                }
                .padding(.top, 18)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("More athlete details")
                        .font(.headline)
                        .foregroundStyle(.white)
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

    private var identityLocation: String {
        let gym = profile.hideGym ? nil : profile.primaryGymName
        let location = profile.hideCity ? nil : "\(profile.city), \(profile.state)"
        let value = [gym, location].compactMap { $0 }.joined(separator: " • ")
        return value.isEmpty ? "Gym and location hidden" : value
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

    private var rankings: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Rankings")
            LiftCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    rankingMetric("Gym", "#4", profile.hideGym ? "Hidden" : profile.primaryGymName, .liftGold)
                    rankingMetric("City", profile.hideCity ? "Hidden" : "#18", profile.hideCity ? "Location hidden" : profile.city, .liftBlue)
                    rankingMetric("State", profile.hideCity ? "Hidden" : "#72", profile.hideCity ? "Location hidden" : profile.state, .liftBlue)
                    rankingMetric("Age group", profile.hideExactAge ? "Hidden" : "Top 9%", profile.hideExactAge ? "Age hidden" : profile.ageGroup, .liftGreen)
                }
            }
        }
    }

    private var progress: some View {
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

    private var videos: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Lift videos")
            if profile.hideLiftVideos && !isCurrentUser {
                LiftEmptyState(title: "Lift videos hidden", message: "This lifter keeps submitted videos private.", symbolName: "eye.slash")
            } else {
                VStack(spacing: 12) {
                    ForEach(profileLifts.prefix(3)) { lift in
                        if let mediaID = lift.demoMediaID {
                            DemoMediaCard(
                                title: lift.exerciseName,
                                subtitle: "\(lift.verificationStatus.rawValue) • Demo media",
                                mediaID: mediaID,
                                badge: "Demo Media"
                            )
                        } else {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.liftBlue)
                                    Text(lift.exerciseName)
                                        .font(.headline)
                                    VerificationBadge(status: lift.verificationStatus)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var achievements: some View {
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
                                .foregroundStyle(unlocked(achievement) ? .white : Color.liftMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .liftSurface(radius: 12)
                }
            }
        }
    }

    private var recentSubmissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Recent submissions")
            VStack(spacing: 0) {
                ForEach(Array(profileLifts.prefix(5).enumerated()), id: \.element.id) { index, lift in
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

    private var profileDivider: some View {
        Rectangle().fill(Color.liftSeparator).frame(width: 1, height: 34)
    }

    private func strengthMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func rankingMetric(_ title: String, _ value: String, _ subtitle: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Color.liftMuted)
            Text(value).font(.headline.weight(.bold)).foregroundStyle(tint)
            Text(subtitle).font(.caption2).foregroundStyle(Color.liftMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        appState.achievementUnlocks.contains { $0.title == achievement.title }
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

private enum EditProfileSelector: String, Identifiable {
    case location
    case gym

    var id: String { rawValue }
    var title: String { self == .location ? "Choose Location" : "Choose Primary Gym" }
}

private struct EditProfileLocation: Identifiable, Hashable {
    let city: String
    let state: String
    var id: String { "\(state.lowercased())|\(city.lowercased())" }
}

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MockData.demoProfile
    @State private var showingPhotoManager = false
    @State private var activeSelector: EditProfileSelector?
    @State private var selectedGymID: UUID?
    @State private var privacy = ProfilePrivacySettings()
    private var ageGroups: [String] {
        MockData.standardAgeGroups.contains(draft.ageGroup)
            ? MockData.standardAgeGroups
            : [draft.ageGroup] + MockData.standardAgeGroups
    }

    private var selectedGym: Gym? {
        appState.gyms.first { $0.id == selectedGymID }
    }

    private var locations: [EditProfileLocation] {
        var unique: [String: EditProfileLocation] = [:]
        for gym in appState.gyms where !gym.city.isEmpty && !gym.state.isEmpty {
            let location = EditProfileLocation(city: gym.city, state: gym.state)
            unique[location.id] = location
        }
        if !draft.city.isEmpty && !draft.state.isEmpty {
            let current = EditProfileLocation(city: draft.city, state: draft.state)
            unique[current.id] = current
        }
        return unique.values.sorted {
            $0.state == $1.state ? $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending :
                $0.state.localizedCaseInsensitiveCompare($1.state) == .orderedAscending
        }
    }

    private var gymsForSelectedLocation: [Gym] {
        let matching = appState.gyms.filter {
            $0.city.caseInsensitiveCompare(draft.city) == .orderedSame &&
                $0.state.caseInsensitiveCompare(draft.state) == .orderedSame
        }
        return (matching.isEmpty ? appState.gyms : matching).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Identity") {
                        Button {
                            showingPhotoManager = true
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: draft, size: 76)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Profile photo")
                                        .font(.headline)
                                    Text(draft.avatarPath == nil ? "Add or change your photo" : "Replace or remove your photo")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                        }
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
                        profileSelectionRow(
                            title: "City and state",
                            value: draft.city.isEmpty ? "Choose a location" : "\(draft.city), \(draft.state)",
                            symbol: "mappin.and.ellipse"
                        ) { activeSelector = .location }
                        profileSelectionRow(
                            title: "Primary gym",
                            value: selectedGym?.name ?? "Choose a gym",
                            symbol: "building.2.fill"
                        ) { activeSelector = .gym }
                    }
                    Section("Privacy") {
                        audiencePicker("Profile", selection: $privacy.profileAudience)
                        audiencePicker("Age band", selection: $privacy.ageBandAudience)
                        audiencePicker("Division", selection: $privacy.divisionAudience)
                        audiencePicker("Bodyweight", selection: $privacy.bodyweightAudience)
                        audiencePicker("Location", selection: $privacy.locationAudience)
                        audiencePicker("Gym", selection: $privacy.gymAudience)
                        audiencePicker("Friend list", selection: $privacy.friendListAudience)
                        Toggle("Hide lift videos", isOn: $draft.hideLiftVideos)
                        Text("Ratio and weight-class rankings may indirectly reveal bodyweight even when the bodyweight field is private.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .onAppear {
                draft = appState.currentProfile
                privacy = appState.authenticatedPrivacy
                selectedGymID = appState.gyms.first(where: {
                    $0.id == draft.primaryGymID || $0.name == draft.primaryGymName
                })?.id
            }
            .sheet(item: $activeSelector) { selector in
                LeaderboardOptionSheet(
                    title: selector.title,
                    options: options(for: selector),
                    selectedID: selectedID(for: selector),
                    isSearchable: true,
                    searchPrompt: selector == .location ? "Search city or state" : "Search gyms",
                    emptyTitle: selector == .location ? "No locations available" : "No gyms available",
                    emptyMessage: selector == .location
                        ? "Locations appear when gyms are added to the directory."
                        : "Choose another location or request that this gym be added."
                ) { id in
                    select(id, for: selector)
                    activeSelector = nil
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPhotoManager, onDismiss: {
                draft = appState.currentProfile
            }) {
                ProfilePhotoManagerView()
                    .environmentObject(appState)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedGym else { return }
                        Task {
                            if await appState.saveEditedProfile(draft, primaryGym: selectedGym, privacy: privacy) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedGym == nil || appState.accountOperationInProgress)
                }
            }
        }
    }

    private func audiencePicker(_ title: String, selection: Binding<PrivacyAudience>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PrivacyAudience.allCases) { audience in
                Text(audience.label).tag(audience)
            }
        }
    }

    private func profileSelectionRow(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text(value)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
    }

    private func options(for selector: EditProfileSelector) -> [LeaderboardOption] {
        switch selector {
        case .location:
            return locations.map {
                LeaderboardOption(id: $0.id, title: $0.city, subtitle: $0.state, symbol: "mappin.and.ellipse")
            }
        case .gym:
            return gymsForSelectedLocation.map {
                LeaderboardOption(id: $0.id.uuidString, title: $0.name, subtitle: "\($0.city), \($0.state)", symbol: "building.2.fill")
            }
        }
    }

    private func selectedID(for selector: EditProfileSelector) -> String {
        switch selector {
        case .location:
            return EditProfileLocation(city: draft.city, state: draft.state).id
        case .gym:
            return selectedGymID?.uuidString ?? ""
        }
    }

    private func select(_ id: String, for selector: EditProfileSelector) {
        switch selector {
        case .location:
            guard let location = locations.first(where: { $0.id == id }) else { return }
            draft.city = location.city
            draft.state = location.state
            if let gym = selectedGym,
               gym.city.caseInsensitiveCompare(location.city) != .orderedSame ||
                gym.state.caseInsensitiveCompare(location.state) != .orderedSame {
                selectedGymID = nil
            }
        case .gym:
            guard let gymID = UUID(uuidString: id), let gym = appState.gyms.first(where: { $0.id == gymID }) else { return }
            selectedGymID = gym.id
            draft.primaryGymID = gym.id
            draft.primaryGymName = gym.name
            draft.city = gym.city
            draft.state = gym.state
        }
    }

}

struct ProfilePhotoManagerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var loading = false
    @State private var selectedSourceImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var showingCropEditor = false
    @State private var showingRemoveConfirmation = false

    private var displayedImage: UIImage? {
        previewImage ??
        LocalProfilePhotoStore.shared.image(for: appState.currentProfile.avatarPath) ??
        LocalProfilePhotoStore.shared.thumbnail(for: appState.currentProfile.avatarPath)
    }

    private var hasExistingOrPendingPhoto: Bool {
        appState.currentProfile.avatarPath != nil || previewImage != nil
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.liftCardRaised)
                            .frame(width: 164, height: 164)

                        if let displayedImage {
                            Image(uiImage: displayedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 144, height: 144)
                                .clipShape(Circle())
                        } else {
                            ProfileAvatar(profile: appState.currentProfile, size: 144)
                        }
                    }
                        .padding(.top, 24)

                    PhotosPicker(selection: $item, matching: .images) {
                        Label(hasExistingOrPendingPhoto ? "Replace Photo" : "Choose Photo", systemImage: "photo")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)

                    if previewImage != nil {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Preview")
                                    .font(.headline.weight(.bold))
                                Text("Keep the new photo, adjust it again, or discard it before saving.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                HStack(spacing: 10) {
                                    Button("Adjust") {
                                        showingCropEditor = true
                                    }
                                    .buttonStyle(LiftSecondaryButtonStyle())

                                    Button("Cancel") {
                                        previewImage = nil
                                        selectedSourceImage = nil
                                    }
                                    .buttonStyle(LiftSecondaryButtonStyle())

                                    Button("Use Photo") {
                                        guard let previewImage else { return }
                                        appState.saveProfilePhoto(previewImage)
                                        self.previewImage = nil
                                        selectedSourceImage = nil
                                    }
                                    .buttonStyle(LiftPrimaryButtonStyle())
                                }
                            }
                        }
                    } else if appState.currentProfile.avatarPath != nil {
                        Button("Remove Photo", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if loading {
                        ProgressView()
                            .tint(Color.liftBlue)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove profile photo?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove Photo", role: .destructive) {
                    appState.removeProfilePhoto()
                }
            } message: {
                Text("The current photo will be removed after confirmation.")
            }
            .fullScreenCover(isPresented: $showingCropEditor) {
                if let selectedSourceImage {
                    ProfilePhotoCropEditorView(
                        sourceImage: selectedSourceImage,
                        onCancel: {
                            showingCropEditor = false
                        },
                        onCrop: { croppedImage in
                            previewImage = croppedImage
                            showingCropEditor = false
                        }
                    )
                }
            }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                loading = true
                Task {
                    defer { loading = false }
                    guard let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)?.preparedForProfileEditing() else { return }
                    await MainActor.run {
                        selectedSourceImage = image
                        showingCropEditor = true
                        item = nil
                    }
                }
            }
        }
    }
}

private struct ProfilePhotoCropEditorView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    @State private var zoomScale: CGFloat = 1
    @State private var baseZoomScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let cropSide = min(proxy.size.width - 32, proxy.size.height * 0.55)
            let apertureSide = cropSide - 20
            let viewport = CGSize(width: apertureSide, height: apertureSide)

            AppBackground {
                VStack(spacing: 20) {
                    Text("Adjust Photo")
                        .font(.title2.weight(.bold))
                        .padding(.top, 10)

                    Text("Position and scale your photo inside the circle.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)

                    Spacer(minLength: 0)

                    ZStack {
                        Color.liftCard
                            .frame(width: cropSide, height: cropSide)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        Image(uiImage: sourceImage)
                            .resizable()
                            .frame(
                                width: sourceImage.size.width * imageScale(in: viewport),
                                height: sourceImage.size.height * imageScale(in: viewport)
                            )
                            .offset(clampedOffset(in: viewport))
                            .gesture(dragGesture(in: viewport).simultaneously(with: magnificationGesture(in: viewport)))
                            .frame(width: cropSide, height: cropSide)
                            .clipped()

                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                            .frame(width: apertureSide, height: apertureSide)

                        Color.black.opacity(0.42)
                            .mask {
                                Rectangle()
                                    .overlay {
                                        Circle()
                                            .frame(width: apertureSide, height: apertureSide)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                            }
                            .allowsHitTesting(false)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Button("Cancel") { onCancel() }
                            .buttonStyle(LiftSecondaryButtonStyle())

                        Button("Reset") {
                            zoomScale = 1
                            baseZoomScale = 1
                            offset = .zero
                            baseOffset = .zero
                        }
                        .buttonStyle(LiftSecondaryButtonStyle())

                        Button("Crop") {
                            if let cropped = croppedImage(in: viewport) {
                                onCrop(cropped)
                            } else {
                                onCancel()
                            }
                        }
                        .buttonStyle(LiftPrimaryButtonStyle())
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func imageScale(in viewport: CGSize) -> CGFloat {
        let base = max(viewport.width / sourceImage.size.width, viewport.height / sourceImage.size.height)
        return base * zoomScale
    }

    private func clampedOffset(in viewport: CGSize) -> CGSize {
        let currentScale = imageScale(in: viewport)
        let renderedWidth = sourceImage.size.width * currentScale
        let renderedHeight = sourceImage.size.height * currentScale
        let maxX = max(0, (renderedWidth - viewport.width) / 2)
        let maxY = max(0, (renderedHeight - viewport.height) / 2)

        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func dragGesture(in viewport: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                let final = clampedOffset(in: viewport)
                offset = final
                baseOffset = final
            }
    }

    private func magnificationGesture(in viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(baseZoomScale * value, 1), 4)
            }
            .onEnded { _ in
                zoomScale = min(max(zoomScale, 1), 4)
                baseZoomScale = zoomScale
                let final = clampedOffset(in: viewport)
                offset = final
                baseOffset = final
            }
    }

    private func croppedImage(in viewport: CGSize) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }

        let currentScale = imageScale(in: viewport)
        let visibleWidth = viewport.width / currentScale
        let visibleHeight = viewport.height / currentScale
        let clamped = clampedOffset(in: viewport)

        let originX = ((sourceImage.size.width - visibleWidth) / 2) - (clamped.width / currentScale)
        let originY = ((sourceImage.size.height - visibleHeight) / 2) - (clamped.height / currentScale)

        let rect = CGRect(
            x: max(0, min(originX, sourceImage.size.width - visibleWidth)),
            y: max(0, min(originY, sourceImage.size.height - visibleHeight)),
            width: min(visibleWidth, sourceImage.size.width),
            height: min(visibleHeight, sourceImage.size.height)
        ).integral

        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}

private extension UIImage {
    /// Produces an upright, one-point-per-pixel editing image so SwiftUI preview
    /// geometry and Core Graphics crop coordinates describe the same pixels.
    func preparedForProfileEditing(maxDimension: CGFloat = 4_096) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let longestSide = max(size.width, size.height)
        let downsampleScale = min(1, maxDimension / longestSide)
        let outputSize = CGSize(
            width: max(1, (size.width * downsampleScale).rounded()),
            height: max(1, (size.height * downsampleScale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}
