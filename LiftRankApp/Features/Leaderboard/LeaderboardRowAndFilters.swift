import Charts
import SwiftUI

struct LeaderboardRow: View {
    @EnvironmentObject private var appState: AppState
    let entry: LeaderboardEntry
    var rankingType: RankingType = .absolute

    private var rankColor: Color {
        LeaderboardRankPresentation.color(for: entry.rank)
    }

    private var catalogExercise: TrainingExerciseCatalogItem? {
        MockData.trainingExerciseLibrary.first {
            $0.id == entry.lift.exerciseID || $0.rankingExerciseID == entry.lift.exerciseID
        }
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
                            if entry.rankMovement > 0 {
                                Label("+\(entry.rankMovement)", systemImage: "arrow.up")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.liftGreen)
                            } else if entry.rankMovement < 0 {
                                Label("\(entry.rankMovement)", systemImage: "arrow.down")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.liftRed)
                            }
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        if let catalogExercise {
                            ExerciseCatalogIcon(exercise: catalogExercise)
                                .scaleEffect(0.38)
                                .frame(width: 22, height: 22)
                        } else {
                            ExerciseNameIcon(
                                name: entry.lift.exerciseName,
                                fallbackSymbol: "figure.strengthtraining.functional"
                            )
                            .scaleEffect(0.38)
                            .frame(width: 22, height: 22)
                        }
                        Text(entry.lift.exerciseName)
                    }
                    Label(entry.profile.hideBodyweight ? "Bodyweight hidden" : "\(MeasurementFormatting.formatBodyweightOrDash(entry.lift.bodyweightAtLift, preferredUnit: appState.currentProfile.preferredUnit)) BW", systemImage: "scalemass.fill")
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

                HStack(spacing: 8) {
                    Text(MeasurementFormatting.recordedLiftSetText(
                        weight: entry.lift.weight,
                        unit: entry.lift.unit,
                        repetitions: entry.lift.repetitions,
                        includeRepLabel: true
                    ))
                    if entry.lift.weightPerHand == true {
                        Text("per hand")
                    }
                    Text("·")
                    Text(LiftTimeFormatter.shortDateTime(entry.lift.performedAt))
                }
                .font(.caption2.weight(.medium))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var customRepText = ""
    @State private var expandedFilterGroups: Set<String> = ["Exercise and reps", "Evidence and time"]
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
        return Array(Set(profileLocations + gymLocations)).sorted()
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
                            filterGroup("Exercise and reps", symbol: "dumbbell.fill") {
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
                                            optionButton(count.map { "\($0) \($0 == 1 ? "rep" : "reps")" } ?? "All", isActive: appState.leaderboardFilters.repetitionCount == count) {
                                                appState.leaderboardFilters.repetitionCount = count
                                            }
                                        }
                                    }
                                    HStack {
                                        TextField("Exact rep count", text: $customRepText)
                                            .keyboardType(.numberPad)
                                        Button("Apply") {
                                            if let reps = Int(customRepText), reps > 0 {
                                                appState.leaderboardFilters.repetitionCount = reps
                                                customRepText = ""
                                            }
                                        }
                                        .font(LiftTypography.compactEmphasis)
                                        .foregroundStyle(Color.liftAccentText)
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
                                        optionButton(LeaderboardAgeGroupPresentation.subtitle(for: ageGroup).map { "\(ageGroup) · \($0)" } ?? ageGroup, isActive: appState.leaderboardFilters.ageGroup == ageGroup) {
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
                                optionButton("Global", isActive: appState.leaderboardFilters.gymID == nil && appState.leaderboardFilters.city == nil && appState.leaderboardFilters.state == nil && appState.leaderboardFilters.country == nil) {
                                    clearLocationFilter()
                                }
                                if !appState.currentProfile.city.isEmpty {
                                    optionButton("My city: \(shortLocation(appState.currentProfile.city, appState.currentProfile.state))", isActive: appState.leaderboardFilters.gymID == nil && appState.leaderboardFilters.city == appState.currentProfile.city && appState.leaderboardFilters.state == appState.currentProfile.state) {
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
                                optionRow("Available cities") {
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
                                .foregroundStyle(Color.liftAccentText)
                                .padding(12)
                                .background(Color.leaderboardFilterOptionFill)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(Color.liftAccentText)
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
                                                .foregroundStyle(Color.liftAccentText)
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
                                                        .foregroundStyle(Color.liftAccentText)
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
        let resultCount = resultCount
        return LiftCard(padding: 14, radius: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.liftAccentText)
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.isLeaderboardRequestPending ? "Updating results…" : appState.competitionStore.leaderboardError != nil ? "Results unavailable" : "\(resultCount) matching \(resultCount == 1 ? "lifter" : "lifters")")
                        .font(.headline)
                    Text("Results update as you change filters.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        }
        .accessibilityIdentifier("leaderboard.filters.results")
    }

    private var quickFilters: some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick filters", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                    ForEach(["city", "gym", "class"], id: \.self) { filter in
                        switch filter {
                        case "city":
                            quickFilterButton("My city", symbol: "mappin.and.ellipse") {
                                applyLocation(
                                    cityID: appState.currentProfile.cityID,
                                    city: appState.currentProfile.city,
                                    region: appState.currentProfile.state,
                                    countryCode: nil
                                )
                            }
                            .disabled(appState.currentProfile.city.isEmpty)
                        case "gym":
                            quickFilterButton("My gym", symbol: "building.2") {
                                clearLocationFilter()
                                appState.leaderboardFilters.gymID = appState.currentProfile.primaryGymID
                            }
                            .disabled(appState.currentProfile.primaryGymID == nil)
                        default:
                            quickFilterButton("My weight class", symbol: "person.crop.rectangle.stack") {
                                appState.leaderboardFilters.sexCategory = appState.currentProfile.sexCategory
                                appState.leaderboardFilters.weightClassID = bodyweightClass?.id
                            }
                            .disabled(bodyweightClass == nil)
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

    private func filterGroup<Content: View>(_ title: String, symbol: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        let filters = appState.leaderboardFilters
        let activeCount: Int = switch title {
        case "Division": [filters.sexCategory != nil, filters.ageGroup != nil, filters.experienceLevel != nil, filters.weightClassID != nil].filter { $0 }.count
        case "Location": [filters.gymID != nil, filters.city != nil || filters.state != nil || filters.country != nil].filter { $0 }.count
        case "Exercise and reps": [filters.exerciseID != nil, filters.repetitionCount != nil].filter { $0 }.count
        default: [!appState.verifiedOnly || filters.verificationLevel != nil, filters.timeRange != "All time"].filter { $0 }.count
        }
        return LiftCard(padding: 14, radius: 16) {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedFilterGroups.contains(title) },
                set: { expanded in
                    if expanded { expandedFilterGroups.insert(title) }
                    else { expandedFilterGroups.remove(title) }
                }
            )) {
                VStack(alignment: .leading, spacing: 12) { content() }.padding(.top, 10)
            } label: {
                Label(activeCount == 0 ? title : "\(title) · \(activeCount) active", systemImage: symbol)
                    .font(.headline)
                    .accessibilityIdentifier("leaderboard.filters.group.\(identifierComponent(title))")
            }
            .tint(Color.liftAccentText)
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
            if let sex = appState.leaderboardFilters.sexCategory {
                weightClassGroup(sex.rawValue, classes: WeightClassCatalog.all.filter { $0.sexCategory == sex })
            } else {
                DisclosureGroup("Men") {
                    weightClassChips(WeightClassCatalog.male)
                }
                .tint(Color.liftAccentText)
                DisclosureGroup("Women") {
                    weightClassChips(WeightClassCatalog.female)
                }
                .tint(Color.liftAccentText)
            }
        }
    }

    private func weightClassGroup(_ title: String, classes: [WeightClass]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.liftMuted)
            weightClassChips(classes)
        }
    }

    private func weightClassChips(_ classes: [WeightClass]) -> some View {
        LeaderboardChipFlowLayout(spacing: 8) {
            ForEach(classes) { weightClass in
                optionButton(RankingFormatting.weightClassDisplayName(weightClass, preferredUnit: appState.currentProfile.preferredUnit), isActive: appState.leaderboardFilters.weightClassID == weightClass.id) {
                    appState.leaderboardFilters.sexCategory = weightClass.sexCategory
                    appState.leaderboardFilters.weightClassID = weightClass.id
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
                .font(LiftTypography.compactEmphasis)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(minHeight: 44)
                .background(isActive ? Color.leaderboardFilterSelectedFill : Color.leaderboardFilterOptionFill)
                .foregroundStyle(isActive ? Color.leaderboardFilterSelectedText : Color.liftAccentText)
                .clipShape(Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("leaderboard.filters.option.\(identifierComponent(title))")
    }

    private func quickFilterButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(LiftTypography.compactEmphasis)
                .frame(maxWidth: .infinity, minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.leaderboardFilterOptionFill)
                .foregroundStyle(Color.liftAccentText)
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
                proposal: ProposedViewSize(width: min(bounds.width, subviews[index].sizeThatFits(.unspecified).width), height: nil)
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: min(width, subview.sizeThatFits(.unspecified).width), height: nil))
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
