import Charts
import SwiftUI

struct LeaderboardRow: View {
    @EnvironmentObject private var appState: AppState
    let entry: LeaderboardEntry
    var rankingType: RankingType = .absolute

    private var rankColor: Color {
        LeaderboardRankPresentation.color(for: entry.rank)
    }

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("#\(entry.rank)")
                        .font(.headline.bold())
                        .foregroundStyle(rankColor)
                        .frame(width: 54, height: 42)
                        .background(rankColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    ProfileAvatar(profile: entry.profile, size: 44)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(entry.profile.username)
                                .font(.headline)
                                .lineLimit(1)
                            if entry.profile.id == appState.currentProfile.id {
                                Text("You")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.liftBlue.opacity(0.22))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(entry.profile.hideGym ? "Gym hidden" : entry.profile.primaryGymName)
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(RankingFormatting.leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: appState.currentProfile.preferredUnit))
                            .font(.headline)
                        Label(entry.rankMovement >= 0 ? "+\(entry.rankMovement)" : "\(entry.rankMovement)", systemImage: entry.rankMovement >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption.bold())
                            .foregroundStyle(entry.rankMovement >= 0 ? Color.liftGreen : Color.liftRed)
                    }
                }

                HStack(spacing: 8) {
                    Label(entry.lift.exerciseName, systemImage: "dumbbell.fill")
                    Label(entry.profile.hideBodyweight ? "Hidden BW" : "\(MeasurementFormatting.formatBodyweightOrDash(entry.lift.bodyweightAtLift, preferredUnit: appState.currentProfile.preferredUnit)) BW", systemImage: "scalemass.fill")
                    Label(
                        ProfileDisplayFormatting.location(
                            city: entry.profile.city,
                            region: entry.profile.state,
                            hidden: entry.profile.hideCity
                        ),
                        systemImage: "mappin.and.ellipse"
                    )
                }
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)

                VerificationBadge(evidenceStatus: entry.lift.resolvedEvidenceStatus)
            }
        }
    }
}

struct LeaderboardFiltersView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var gymSearch = ""
    @State private var customRepText = ""

    private var ageGroups: [String] {
        LeaderboardAgeGroupPresentation.groups(from: appState.profiles)
    }

    private var filteredGyms: [Gym] {
        let query = gymSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.gyms.sorted { $0.name < $1.name } }
        return appState.gyms
            .filter { gym in
                gym.name.lowercased().contains(query) ||
                gym.city.lowercased().contains(query) ||
                gym.state.lowercased().contains(query)
            }
            .sorted { $0.name < $1.name }
    }

    private var bodyweightClass: WeightClass? {
        RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: WeightClassCatalog.all
        )
    }

    private var locationOptions: [String] {
        let profileLocations = appState.profiles.map { "\($0.city), \($0.state)" }
        let gymLocations = appState.gyms.map { "\($0.city), \($0.state)" }
        return Array(Set(profileLocations + gymLocations)).sorted().prefix(14).map { $0 }
    }

    private var resultCount: Int {
        appState.leaderboardEntries().count
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        resultsPreview
                        quickFilters

                        filterGroup("Ranking", symbol: "list.number") {
                            optionRow("Ranking type") {
                                ForEach(appState.leaderboardFilters.exerciseID == nil ? RankingType.allCases : [.absolute, .poundForPound, .mostImproved]) { type in
                                    optionButton(type.rawValue, isActive: appState.leaderboardFilters.rankingType == type) {
                                        appState.leaderboardFilters.rankingType = type
                                    }
                                }
                            }
                            optionRow("Exercise") {
                                optionButton("All", isActive: appState.leaderboardFilters.exerciseID == nil) {
                                    appState.selectLeaderboardExercise(nil)
                                }
                                ForEach(MockData.exercises) { exercise in
                                    optionButton(exercise.name, isActive: appState.leaderboardFilters.exerciseID == exercise.id) {
                                        appState.selectLeaderboardExercise(exercise.id)
                                    }
                                }
                            }
                            if appState.leaderboardFilters.exerciseID != nil {
                                optionRow("Rep count") {
                                    ForEach([nil, 1, 3, 5, 8, 10], id: \.self) { count in
                                        optionButton(count.map { "\($0) reps" } ?? "All", isActive: appState.leaderboardFilters.repetitionCount == count) {
                                            appState.leaderboardFilters.repetitionCount = count
                                        }
                                    }
                                }
                                HStack {
                                    TextField("Custom exact reps", text: $customRepText)
                                        .keyboardType(.numberPad)
                                    Button("Apply") {
                                        if let reps = Int(customRepText), reps > 0 {
                                            appState.leaderboardFilters.repetitionCount = reps
                                            customRepText = ""
                                        }
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftBlue)
                                }
                                .padding(12)
                                .background(Color.liftBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }

                        filterGroup("Division", symbol: "person.2.fill") {
                            optionRow("Sex") {
                                optionButton("All", isActive: appState.leaderboardFilters.sexCategory == nil) {
                                    appState.leaderboardFilters.sexCategory = nil
                                }
                                ForEach(SexCategory.allCases) { sex in
                                    optionButton(sex.rawValue, isActive: appState.leaderboardFilters.sexCategory == sex) {
                                        appState.leaderboardFilters.sexCategory = sex
                                    }
                                }
                            }
                            optionRow("Age") {
                                optionButton("All", isActive: appState.leaderboardFilters.ageGroup == nil) {
                                    appState.leaderboardFilters.ageGroup = nil
                                }
                                ForEach(ageGroups, id: \.self) { ageGroup in
                                    optionButton(ageGroup, isActive: appState.leaderboardFilters.ageGroup == ageGroup) {
                                        appState.leaderboardFilters.ageGroup = ageGroup
                                    }
                                }
                            }
                            optionRow("Experience") {
                                optionButton("All", isActive: appState.leaderboardFilters.experienceLevel == nil) {
                                    appState.leaderboardFilters.experienceLevel = nil
                                }
                                ForEach(ExperienceLevel.allCases) { level in
                                    optionButton(level.rawValue, isActive: appState.leaderboardFilters.experienceLevel == level) {
                                        appState.leaderboardFilters.experienceLevel = level
                                    }
                                }
                            }
                            optionRow("Weight class") {
                                optionButton("All", isActive: appState.leaderboardFilters.weightClassID == nil) {
                                    appState.leaderboardFilters.weightClassID = nil
                                }
                                ForEach(WeightClassCatalog.all.filter { appState.leaderboardFilters.sexCategory == nil || $0.sexCategory == appState.leaderboardFilters.sexCategory }) { weightClass in
                                    optionButton(weightClass.name, isActive: appState.leaderboardFilters.weightClassID == weightClass.id) {
                                        appState.leaderboardFilters.sexCategory = weightClass.sexCategory
                                        appState.leaderboardFilters.weightClassID = weightClass.id
                                    }
                                }
                            }
                        }

                        filterGroup("Location", symbol: "mappin.and.ellipse") {
                            optionRow("Quick location") {
                                optionButton("Global", isActive: appState.leaderboardFilters.gymID == nil && appState.leaderboardFilters.city == nil && appState.leaderboardFilters.state == nil) {
                                    appState.leaderboardFilters.gymID = nil
                                    appState.leaderboardFilters.city = nil
                                    appState.leaderboardFilters.state = nil
                                }
                                optionButton("My gym", isActive: appState.leaderboardFilters.gymID == appState.currentProfile.primaryGymID) {
                                    appState.leaderboardFilters.gymID = appState.currentProfile.primaryGymID
                                    appState.leaderboardFilters.city = nil
                                    appState.leaderboardFilters.state = nil
                                }
                                optionButton("My city", isActive: appState.leaderboardFilters.city == appState.currentProfile.city && appState.leaderboardFilters.state == appState.currentProfile.state) {
                                    appState.leaderboardFilters.city = appState.currentProfile.city
                                    appState.leaderboardFilters.state = appState.currentProfile.state
                                    appState.leaderboardFilters.gymID = nil
                                }
                            }

                            optionRow("Popular cities") {
                                ForEach(locationOptions, id: \.self) { location in
                                    let parts = location.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    let city = parts.first ?? location
                                    let state = parts.count > 1 ? parts[1] : ""
                                    optionButton(location, isActive: appState.leaderboardFilters.city == city && appState.leaderboardFilters.state == state) {
                                        appState.leaderboardFilters.city = city
                                        appState.leaderboardFilters.state = state.isEmpty ? nil : state
                                        appState.leaderboardFilters.gymID = nil
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                TextField("City", text: optionalStringBinding(\.city))
                                    .textInputAutocapitalization(.words)
                                TextField("State", text: optionalStringBinding(\.state))
                                    .textInputAutocapitalization(.characters)
                                    .frame(width: 80)
                            }
                            .padding(12)
                            .background(Color.liftBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.liftMuted)
                                TextField("Search gyms", text: $gymSearch)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                if !gymSearch.isEmpty {
                                    Button {
                                        gymSearch = ""
                                        Haptics.light()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .foregroundStyle(Color.liftMuted)
                                    .accessibilityLabel("Clear gym search")
                                }
                            }
                            .padding(12)
                            .background(Color.liftBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(spacing: 8) {
                                gymButton(nil)
                                ForEach(filteredGyms.prefix(10)) { gym in
                                    gymButton(gym)
                                }
                            }
                        }

                        filterGroup("Evidence and time", symbol: "video.fill") {
                            optionRow("Evidence") {
                                optionButton("All lifts", isActive: !appState.verifiedOnly && appState.leaderboardFilters.verificationLevel == nil) {
                                    appState.verifiedOnly = false
                                    appState.leaderboardFilters.verificationLevel = nil
                                }
                                optionButton("Video-backed", isActive: appState.verifiedOnly) {
                                    appState.verifiedOnly = true
                                    appState.leaderboardFilters.verificationLevel = nil
                                }
                                optionButton("Self-reported", isActive: appState.leaderboardFilters.verificationLevel == .selfReported) {
                                    appState.verifiedOnly = false
                                    appState.leaderboardFilters.verificationLevel = .selfReported
                                }
                            }
                            optionRow("Time range") {
                                ForEach(["All time", "This year", "Last 90 days", "This month", "This week"], id: \.self) { range in
                                    optionButton(range, isActive: appState.leaderboardFilters.timeRange == range) {
                                        appState.leaderboardFilters.timeRange = range
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        appState.leaderboardFilters = LeaderboardFilters(exerciseID: nil)
                        appState.verifiedOnly = true
                        gymSearch = ""
                        Haptics.light()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var resultsPreview: some View {
        LiftCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.liftBlue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(resultCount) matching \(resultCount == 1 ? "lifter" : "lifters")")
                        .font(.headline)
                    Text("Filters apply immediately to the current daily snapshot.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button("Reset") {
                    appState.leaderboardFilters = LeaderboardFilters(exerciseID: nil)
                    appState.verifiedOnly = true
                    gymSearch = ""
                    Haptics.light()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
            }
        }
    }

    private var quickFilters: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick filters", systemImage: "bolt.fill")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    quickFilterButton("All lifters", symbol: "globe") {
                        appState.leaderboardFilters = LeaderboardFilters(exerciseID: appState.leaderboardFilters.exerciseID)
                    }
                    quickFilterButton("My gym", symbol: "building.2.fill") {
                        appState.leaderboardFilters.gymID = appState.currentProfile.primaryGymID
                        appState.leaderboardFilters.city = nil
                        appState.leaderboardFilters.state = nil
                    }
                    quickFilterButton("My city", symbol: "mappin.and.ellipse") {
                        appState.leaderboardFilters.city = appState.currentProfile.city
                        appState.leaderboardFilters.state = appState.currentProfile.state
                        appState.leaderboardFilters.gymID = nil
                    }
                    quickFilterButton("My class", symbol: "person.crop.rectangle.stack") {
                        appState.leaderboardFilters.sexCategory = appState.currentProfile.sexCategory
                        appState.leaderboardFilters.weightClassID = bodyweightClass?.id
                    }
                }
            }
        }
    }

    private func filterGroup<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                content()
            }
        }
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
            }
        }
    }

    private func optionButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isActive ? Color.liftBlue : Color.liftBlue.opacity(0.10))
                .foregroundStyle(isActive ? Color.white : Color.liftBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func gymButton(_ gym: Gym?) -> some View {
        let isActive = appState.leaderboardFilters.gymID == gym?.id
        return Button {
            Haptics.light()
            appState.leaderboardFilters.gymID = gym?.id
            if gym != nil {
                appState.leaderboardFilters.city = nil
                appState.leaderboardFilters.state = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(gym?.name ?? "All gyms")
                        .font(.subheadline.weight(.semibold))
                    if let gym {
                        Text("\(gym.city), \(gym.state)")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Spacer()
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Color.liftBlue : Color.liftMuted)
            }
            .padding(12)
            .background(isActive ? Color.liftBlue.opacity(0.14) : Color.liftBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func quickFilterButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color.liftBlue.opacity(0.14))
                .foregroundStyle(Color.liftBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<LeaderboardFilters, String?>) -> Binding<String> {
        Binding(
            get: { appState.leaderboardFilters[keyPath: keyPath] ?? "" },
            set: { newValue in
                let cleanValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.leaderboardFilters[keyPath: keyPath] = cleanValue.isEmpty ? nil : cleanValue
            }
        )
    }
}
