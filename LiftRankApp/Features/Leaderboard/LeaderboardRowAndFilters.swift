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
                            Text(entry.profile.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            if LeaderboardIdentityPresentation.isCurrentUser(
                                entryProfileID: entry.profile.id,
                                activeProfileID: appState.currentProfile.id
                            ) {
                                Text("You")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.liftBlue.opacity(0.22))
                                    .clipShape(Capsule())
                                Text("\(appState.strengthTierSummary.overallTier.label) tier")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.liftGold)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.liftGold.opacity(0.12))
                                    .clipShape(Capsule())
                                    .accessibilityIdentifier("leaderboard.currentUserRivalTier")
                            }
                        }
                        Text("@\(entry.profile.username) • \(entry.profile.hideGym ? "Gym hidden" : entry.profile.primaryGymName)")
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
    @State private var customRepText = ""
    @State private var locationOptions: [String] = []
    @State private var locationQuery = ""
    @State private var locationSuggestions: [LocationCitySuggestion] = []
    @State private var isSearchingLocations = false
    @State private var locationSearchTask: Task<Void, Never>?
    @FocusState private var locationSearchFocused: Bool

    private var isLocationSearchActive: Bool {
        locationSearchFocused || !locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ageGroups: [String] {
        LeaderboardAgeGroupPresentation.groups(from: appState.profiles)
    }

    private var bodyweightClass: WeightClass? {
        RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: WeightClassCatalog.all
        )
    }

    private func makeLocationOptions() -> [String] {
        let profileLocations = appState.profiles.compactMap { profile -> String? in
            guard !profile.hideCity else { return nil }
            let location = ProfileDisplayFormatting.location(city: profile.city, region: profile.state)
            return location == "Location missing" ? nil : location
        }
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

                        if !isLocationSearchActive {
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
                                        appState.leaderboardFilters.weightClassID = nil
                                    }
                                    ForEach([SexCategory.male, .female]) { sex in
                                        optionButton(sex.rawValue, isActive: appState.leaderboardFilters.sexCategory == sex) {
                                            if let weightClassID = appState.leaderboardFilters.weightClassID,
                                               !WeightClassCatalog.all.contains(where: { $0.id == weightClassID && $0.sexCategory == sex }) {
                                                appState.leaderboardFilters.weightClassID = nil
                                            }
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
                                weightClassOptions
                            }
                        }

                        filterGroup("Location", symbol: "mappin.and.ellipse") {
                            optionRow("Quick location") {
                                optionButton("Global", isActive: appState.leaderboardFilters.gymID == nil && appState.leaderboardFilters.city == nil && appState.leaderboardFilters.state == nil) {
                                    clearLocationFilter()
                                }
                                if !appState.currentProfile.city.isEmpty {
                                    optionButton("My city: \(shortLocation(appState.currentProfile.city, appState.currentProfile.state))", isActive: appState.leaderboardFilters.cityID == appState.currentProfile.cityID && appState.leaderboardFilters.city == appState.currentProfile.city) {
                                        applyLocation(
                                            cityID: appState.currentProfile.cityID,
                                            city: appState.currentProfile.city,
                                            region: appState.currentProfile.state,
                                            countryCode: nil
                                        )
                                    }
                                }
                                if !appState.currentProfile.primaryGymName.isEmpty {
                                    optionButton("My gym", isActive: appState.leaderboardFilters.gymID == appState.currentProfile.primaryGymID) {
                                        clearLocationFilter()
                                        appState.leaderboardFilters.gymID = appState.currentProfile.primaryGymID
                                    }
                                }
                            }

                            if locationQuery.isEmpty, !locationOptions.isEmpty {
                                optionRow("Popular cities") {
                                    ForEach(locationOptions.prefix(5), id: \.self) { location in
                                        let parts = location.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        let city = parts.first ?? location
                                        let state = parts.count > 1 ? parts[1] : ""
                                        optionButton(shortLocation(city, state), isActive: appState.leaderboardFilters.city == city && appState.leaderboardFilters.state == state) {
                                            applyLocation(cityID: nil, city: city, region: state, countryCode: nil)
                                        }
                                    }
                                }
                            }

                            if let selectedLocationLabel {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                    Text(selectedLocationLabel)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        clearLocationFilter()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Clear selected location")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.liftBlue)
                                .padding(12)
                                .background(Color.liftBlue.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(Color.liftMuted)
                                    TextField("Search city or state", text: $locationQuery)
                                        .focused($locationSearchFocused)
                                        .submitLabel(.done)
                                        .onSubmit { locationSearchFocused = false }
                                        .onChange(of: locationQuery) { _, query in
                                            searchLocations(matching: query)
                                        }
                                    .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                    if isSearchingLocations {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if !locationQuery.isEmpty {
                                        Button {
                                            cancelLocationSearch()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Clear location search")
                                    }
                                }
                                .padding(12)

                                if !locationSuggestions.isEmpty {
                                    Divider().overlay(Color.liftSeparator)
                                    ForEach(locationSuggestions) { suggestion in
                                        Button {
                                            applyLocation(suggestion)
                                        } label: {
                                            HStack(spacing: 10) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(shortLocation(suggestion.city, suggestion.region))
                                                        .font(.subheadline.weight(.semibold))
                                                    Text(suggestion.countryName)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.liftMuted)
                                                }
                                                Spacer()
                                                if appState.leaderboardFilters.cityID == suggestion.canonicalID,
                                                   appState.leaderboardFilters.city == suggestion.city {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(Color.liftBlue)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)
                                        if suggestion.id != locationSuggestions.last?.id {
                                            Divider().overlay(Color.liftSeparator).padding(.leading, 12)
                                        }
                                    }
                                } else if !isSearchingLocations,
                                          locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                                    Divider().overlay(Color.liftSeparator)
                                    Text("No matching cities")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                }
                            }
                            .background(Color.liftBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        if !isLocationSearchActive {
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
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationOptions = makeLocationOptions()
            }
            .onDisappear {
                locationSearchTask?.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        appState.leaderboardFilters = LeaderboardFilters(exerciseID: nil)
                        appState.verifiedOnly = true
                        Haptics.light()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if locationSearchFocused {
                        Button("Cancel") { cancelLocationSearch() }
                        Spacer()
                        Button("Done") { locationSearchFocused = false }
                    }
                }
            }
        }
    }

    private var resultsPreview: some View {
        LiftCard(padding: 14, radius: 16) {
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
                    Haptics.light()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.liftBlue)
            }
        }
        .accessibilityIdentifier("leaderboard.filters.results")
    }

    private var quickFilters: some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick filters", systemImage: "bolt.fill")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(["all", "city", "class"], id: \.self) { filter in
                        switch filter {
                        case "all":
                            quickFilterButton("All lifters", symbol: "globe") {
                                appState.leaderboardFilters = LeaderboardFilters(exerciseID: appState.leaderboardFilters.exerciseID)
                            }
                        case "city":
                            quickFilterButton("My city", symbol: "mappin.and.ellipse") {
                                applyLocation(
                                    cityID: appState.currentProfile.cityID,
                                    city: appState.currentProfile.city,
                                    region: appState.currentProfile.state,
                                    countryCode: nil
                                )
                            }
                        default:
                            quickFilterButton("My class", symbol: "person.crop.rectangle.stack") {
                                appState.leaderboardFilters.sexCategory = appState.currentProfile.sexCategory
                                appState.leaderboardFilters.weightClassID = bodyweightClass?.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedLocationLabel: String? {
        guard let city = appState.leaderboardFilters.city, !city.isEmpty else { return nil }
        return shortLocation(city, appState.leaderboardFilters.state ?? "")
    }

    private func shortLocation(_ city: String, _ region: String) -> String {
        region.isEmpty ? city : "\(city), \(region)"
    }

    private func applyLocation(_ suggestion: LocationCitySuggestion) {
        applyLocation(
            cityID: suggestion.canonicalID,
            city: suggestion.city,
            region: suggestion.region,
            countryCode: suggestion.countryCode
        )
        cancelLocationSearch()
        locationSearchFocused = false
    }

    private func applyLocation(cityID: UUID?, city: String, region: String, countryCode: String?) {
        appState.leaderboardFilters.gymID = nil
        appState.leaderboardFilters.cityID = cityID
        appState.leaderboardFilters.city = city
        appState.leaderboardFilters.state = region.isEmpty ? nil : region
        appState.leaderboardFilters.country = countryCode
    }

    private func clearLocationFilter() {
        appState.leaderboardFilters.gymID = nil
        appState.leaderboardFilters.cityID = nil
        appState.leaderboardFilters.city = nil
        appState.leaderboardFilters.state = nil
        appState.leaderboardFilters.country = nil
        cancelLocationSearch()
    }

    private func cancelLocationSearch() {
        locationSearchTask?.cancel()
        locationSearchTask = nil
        locationQuery = ""
        locationSuggestions = []
        isSearchingLocations = false
    }

    private func searchLocations(matching query: String) {
        locationSearchTask?.cancel()
        locationSuggestions = []

        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanQuery.count >= 2 else {
            isSearchingLocations = false
            return
        }

        isSearchingLocations = true
        let countryCode = appState.leaderboardFilters.country
            ?? Locale.current.region?.identifier
            ?? "US"
        locationSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let results = await appState.searchCities(
                countryCode: countryCode,
                region: "",
                query: cleanQuery,
                limit: 8
            )
            guard !Task.isCancelled else { return }
            locationSuggestions = results
            isSearchingLocations = false
            locationSearchTask = nil
        }
    }

    private func filterGroup<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .accessibilityIdentifier("leaderboard.filters.group.\(identifierComponent(title))")
                content()
            }
        }
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            LeaderboardChipFlowLayout(spacing: 8) {
                content()
            }
        }
    }

    private var weightClassOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weight class")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            LeaderboardChipFlowLayout(spacing: 8) {
                optionButton("All", isActive: appState.leaderboardFilters.weightClassID == nil) {
                    appState.leaderboardFilters.weightClassID = nil
                }
            }
            if let sex = appState.leaderboardFilters.sexCategory,
               sex != .open {
                weightClassGroup(sex.rawValue, classes: WeightClassCatalog.all.filter { $0.sexCategory == sex })
            } else {
                weightClassGroup("Men", classes: WeightClassCatalog.male)
                weightClassGroup("Women", classes: WeightClassCatalog.female)
            }
        }
    }

    private func weightClassGroup(_ title: String, classes: [WeightClass]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            LeaderboardChipFlowLayout(spacing: 8) {
                ForEach(classes) { weightClass in
                    optionButton(weightClass.name, isActive: appState.leaderboardFilters.weightClassID == weightClass.id) {
                        appState.leaderboardFilters.sexCategory = weightClass.sexCategory
                        appState.leaderboardFilters.weightClassID = weightClass.id
                    }
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
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("leaderboard.filters.option.\(identifierComponent(title))")
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

    private func identifierComponent(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

private struct LeaderboardChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(in: proposal.width ?? .greatestFiniteMagnitude, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
