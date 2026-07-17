import SwiftUI

struct LeaderboardsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var activeSelector: LeaderboardSelector?
    @State private var showingCustomRepInput = false
    @State private var customRepText = ""
    @State private var handledFocusRequestID: UUID?

    private var allEntries: [LeaderboardEntry] {
        appState.leaderboardEntries()
    }

    private var visibleEntries: [LeaderboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { entry in
            entry.profile.username.lowercased().contains(query) ||
            entry.profile.displayName.lowercased().contains(query) ||
            entry.profile.primaryGymName.lowercased().contains(query) ||
            entry.profile.city.lowercased().contains(query) ||
            entry.lift.exerciseName.lowercased().contains(query)
        }
    }

    private var currentUserEntry: LeaderboardEntry? {
        allEntries.first { $0.profile.id == appState.currentProfile.id }
    }

    private var bodyweightClass: WeightClass? {
        RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: MockData.weightClasses
        )
    }

    private var activeFilterCount: Int {
        var count = 0
        if appState.leaderboardFilters.exerciseID != nil { count += 1 }
        if appState.leaderboardFilters.gymID != nil { count += 1 }
        if appState.leaderboardFilters.city != nil || appState.leaderboardFilters.state != nil { count += 1 }
        if appState.leaderboardFilters.sexCategory != nil { count += 1 }
        if appState.leaderboardFilters.ageGroup != nil { count += 1 }
        if appState.leaderboardFilters.weightClassID != nil { count += 1 }
        if appState.leaderboardFilters.experienceLevel != nil { count += 1 }
        if appState.leaderboardFilters.verificationLevel != nil { count += 1 }
        if appState.leaderboardFilters.repetitionCount != nil { count += 1 }
        if appState.leaderboardFilters.timeRange != "All time" { count += 1 }
        return count
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            LeaderboardMetricStrip(
                                rank: currentUserEntry.map { "#\($0.rank)" } ?? "Unranked",
                                lifters: allEntries.count,
                                ranking: appState.leaderboardFilters.rankingType.rawValue,
                                nextUpdate: appState.nextLeaderboardUpdateDate(referenceDate: .now)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 14)

                            LeaderboardTabBar(selection: rankingTypeBinding, types: availableRankingTypes)
                            filterBar.padding(.vertical, 10)

                            if isSearchVisible || !searchText.isEmpty {
                                searchField
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if visibleEntries.isEmpty {
                                emptyState
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else {
                                Section {
                                    VStack(spacing: 0) {
                                        ForEach(visibleEntries) { entry in
                                            Button {
                                                appState.selectedProfile = entry.profile
                                            } label: {
                                                CompactLeaderboardRow(
                                                    entry: entry,
                                                    rankingType: appState.leaderboardFilters.rankingType,
                                                    isCurrentUser: entry.profile.id == appState.currentProfile.id,
                                                    preferredUnit: appState.currentProfile.preferredUnit,
                                                    isExerciseLeaderboard: appState.leaderboardFilters.exerciseID != nil
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .id(entry.profile.id)

                                            if entry.id != visibleEntries.last?.id {
                                                Divider()
                                                    .overlay(Color.white.opacity(0.07))
                                                    .padding(.leading, 72)
                                            }
                                        }
                                    }
                                    .background(Color.liftCard.opacity(0.44))
                                } header: {
                                    LeaderboardTableHeader(resultCount: visibleEntries.count, valueTitle: valueColumnTitle)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .onAppear {
                        appState.normalizeLeaderboardFilters()
                        focusCurrentUserIfNeeded(using: proxy)
                    }
                    .onChange(of: appState.leaderboardFocusRequestID) { _, _ in
                        focusCurrentUserIfNeeded(using: proxy)
                    }
                }
            }
            .navigationTitle("Leaderboards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.showingSubmitSheet = true
                    } label: {
                        Label("Submit lift", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Submit a lift")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchVisible.toggle()
                            if !isSearchVisible { searchText = "" }
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(isSearchVisible ? "Hide leaderboard search" : "Search leaderboard")
                }
            }
            .sheet(item: $activeSelector) { selector in
                LeaderboardOptionSheet(
                    title: selector.title,
                    options: options(for: selector),
                    selectedID: selectedOptionID(for: selector),
                    isSearchable: selector == .scope
                ) { optionID in
                    apply(optionID, for: selector)
                    activeSelector = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Custom rep count", isPresented: $showingCustomRepInput) {
                TextField("Reps", text: $customRepText)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) { customRepText = "" }
                Button("Apply") {
                    if let reps = Int(customRepText), reps > 0 {
                        appState.leaderboardFilters.repetitionCount = reps
                    }
                    customRepText = ""
                }
            } message: {
                Text("Enter the exact number of repetitions to include.")
            }
        }
    }

    private var rankingTypeBinding: Binding<RankingType> {
        Binding(
            get: { appState.leaderboardFilters.rankingType },
            set: { appState.leaderboardFilters.rankingType = $0 }
        )
    }

    private var availableRankingTypes: [RankingType] {
        appState.leaderboardFilters.exerciseID == nil
            ? RankingType.allCases
            : [.absolute, .poundForPound, .mostImproved]
    }

    private var valueColumnTitle: String {
        switch appState.leaderboardFilters.rankingType {
        case .absolute: return appState.leaderboardFilters.exerciseID == nil ? "PR" : "PR"
        case .poundForPound: return "P4P"
        case .total: return "Total"
        case .relativeTotal: return "Relative"
        case .mostImproved: return "Improvement"
        }
    }

    private var isGlobalScope: Bool {
        appState.leaderboardFilters.gymID == nil &&
        appState.leaderboardFilters.city == nil &&
        appState.leaderboardFilters.state == nil &&
        appState.leaderboardFilters.weightClassID == nil
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                LeaderboardFilterControl(title: "Scope", value: scopeLabel, symbol: "globe") {
                    activeSelector = .scope
                }
                LeaderboardFilterControl(title: "Exercise", value: exerciseLabel, symbol: "dumbbell.fill") {
                    activeSelector = .exercise
                }
                if appState.leaderboardFilters.exerciseID != nil {
                    LeaderboardFilterControl(title: "Reps", value: repetitionLabel, symbol: "number") {
                        activeSelector = .repetitions
                    }
                }
                LeaderboardFilterControl(title: "Age", value: appState.leaderboardFilters.ageGroup ?? "All", symbol: "person.text.rectangle") {
                    activeSelector = .age
                }
                LeaderboardFilterControl(title: "Time", value: appState.leaderboardFilters.timeRange, symbol: "calendar") {
                    activeSelector = .timeRange
                }
                LeaderboardFilterControl(title: "Status", value: verificationLabel, symbol: "checkmark.seal.fill") {
                    activeSelector = .verification
                }
                Button {
                    Haptics.light()
                    appState.showingLeaderboardFilters = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        if activeFilterCount > 0 { Text("\(activeFilterCount)") }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, 4)
                    .liftSurface(radius: 10, raised: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More filters, \(activeFilterCount) active")
            }
            .padding(.horizontal, 16)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField("Search lifters, gyms, exercises", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Haptics.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.liftMuted)
                }
                .accessibilityLabel("Clear leaderboard search")
            }
        }
        .padding(12)
        .liftSurface(radius: LiftDesign.controlRadius)
    }

    private var emptyState: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "list.number")
                    .font(.largeTitle)
                    .foregroundStyle(Color.liftBlue)
                Text("No ranked lifters")
                    .font(.headline)
                Text("Adjust filters or clear search to broaden this leaderboard.")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    Button("Clear Search") {
                        searchText = ""
                        Haptics.light()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)

                    Button("Reset Filters") {
                        resetFilters()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func resetFilters() {
        appState.leaderboardFilters = LeaderboardFilters(exerciseID: nil)
        appState.verifiedOnly = true
        searchText = ""
        Haptics.light()
    }

    private var scopeLabel: String {
        if let gymID = appState.leaderboardFilters.gymID {
            if gymID == appState.currentProfile.primaryGymID { return "My gym" }
            return appState.gyms.first(where: { $0.id == gymID })?.name ?? "Gym"
        }
        if appState.leaderboardFilters.city == appState.currentProfile.city { return "My city" }
        if appState.leaderboardFilters.weightClassID == bodyweightClass?.id { return "My class" }
        return isGlobalScope ? "Global" : "Custom"
    }

    private var exerciseLabel: String {
        guard let id = appState.leaderboardFilters.exerciseID else { return "All" }
        return MockData.exercises.first(where: { $0.id == id })?.name ?? "Selected"
    }

    private var verificationLabel: String {
        if let level = appState.leaderboardFilters.verificationLevel { return level.rawValue }
        return appState.verifiedOnly ? "Verified" : "All lifts"
    }

    private var repetitionLabel: String {
        appState.leaderboardFilters.repetitionCount.map { "\($0)" } ?? "All"
    }

    private func options(for selector: LeaderboardSelector) -> [LeaderboardOption] {
        switch selector {
        case .scope:
            return [
                .init(id: "global", title: "Global", subtitle: "All ranked lifters", symbol: "globe"),
                .init(id: "gym", title: "My gym", subtitle: appState.currentProfile.primaryGymName, symbol: "building.2.fill"),
                .init(id: "city", title: "My city", subtitle: "\(appState.currentProfile.city), \(appState.currentProfile.state)", symbol: "mappin.and.ellipse"),
                .init(id: "class", title: "My weight class", subtitle: bodyweightClass.map { weightClassDisplayName($0) }, symbol: "person.crop.rectangle.stack")
            ] + appState.gyms.sorted(by: { $0.name < $1.name }).map {
                .init(id: "gym:\($0.id.uuidString)", title: $0.name, subtitle: "\($0.city), \($0.state)", symbol: "building.2")
            }
        case .exercise:
            return [.init(id: "all", title: "All exercises", symbol: "dumbbell.fill")] + MockData.exercises.map {
                .init(id: $0.id, title: $0.name, symbol: $0.symbolName)
            }
        case .repetitions:
            return [
                .init(id: "all", title: "All rep counts", symbol: "number"),
                .init(id: "1", title: "1 rep", symbol: "1.circle"),
                .init(id: "3", title: "3 reps", symbol: "3.circle"),
                .init(id: "5", title: "5 reps", symbol: "5.circle"),
                .init(id: "8", title: "8 reps", symbol: "8.circle"),
                .init(id: "10", title: "10 reps", symbol: "10.circle"),
                .init(id: "custom", title: "Custom rep count", symbol: "number.square")
            ]
        case .age:
            let legacy = Set(appState.profiles.map(\.ageGroup)).subtracting(MockData.standardAgeGroups)
            return [.init(id: "all", title: "All ages", symbol: "person.2")] +
                (MockData.standardAgeGroups + legacy.sorted()).map {
                    .init(id: $0, title: $0, subtitle: MockData.legacyAgeGroups.contains($0) ? "Legacy profile range" : nil, symbol: "person")
                }
        case .timeRange:
            return ["All time", "This year", "Last 90 days", "This month", "This week"].map {
                .init(id: $0, title: $0, symbol: "calendar")
            }
        case .verification:
            return [
                .init(id: "verified", title: "Verified only", subtitle: "Include accepted verified lifts", symbol: "checkmark.seal.fill"),
                .init(id: "all", title: "All submissions", subtitle: "Include self-reported lifts", symbol: "tray.full.fill")
            ] + VerificationStatus.allCases.map {
                .init(id: "level:\($0.rawValue)", title: $0.rawValue, symbol: "checkmark.seal")
            }
        }
    }

    private func selectedOptionID(for selector: LeaderboardSelector) -> String {
        switch selector {
        case .scope:
            if appState.leaderboardFilters.gymID == appState.currentProfile.primaryGymID { return "gym" }
            if appState.leaderboardFilters.city == appState.currentProfile.city { return "city" }
            if appState.leaderboardFilters.weightClassID == bodyweightClass?.id { return "class" }
            if let gymID = appState.leaderboardFilters.gymID { return "gym:\(gymID.uuidString)" }
            return "global"
        case .exercise: return appState.leaderboardFilters.exerciseID ?? "all"
        case .repetitions: return appState.leaderboardFilters.repetitionCount.map(String.init) ?? "all"
        case .age: return appState.leaderboardFilters.ageGroup ?? "all"
        case .timeRange: return appState.leaderboardFilters.timeRange
        case .verification:
            if let level = appState.leaderboardFilters.verificationLevel { return "level:\(level.rawValue)" }
            return appState.verifiedOnly ? "verified" : "all"
        }
    }

    private func apply(_ optionID: String, for selector: LeaderboardSelector) {
        Haptics.light()
        switch selector {
        case .scope:
            appState.leaderboardFilters.gymID = nil
            appState.leaderboardFilters.city = nil
            appState.leaderboardFilters.state = nil
            appState.leaderboardFilters.weightClassID = nil
            if optionID == "gym" {
                appState.leaderboardFilters.gymID = appState.currentProfile.primaryGymID
            } else if optionID == "city" {
                appState.leaderboardFilters.city = appState.currentProfile.city
                appState.leaderboardFilters.state = appState.currentProfile.state
            } else if optionID == "class" {
                appState.leaderboardFilters.sexCategory = appState.currentProfile.sexCategory
                appState.leaderboardFilters.weightClassID = bodyweightClass?.id
            } else if optionID.hasPrefix("gym:"),
                      let gymID = UUID(uuidString: String(optionID.dropFirst(4))) {
                appState.leaderboardFilters.gymID = gymID
            }
        case .exercise:
            appState.selectLeaderboardExercise(optionID == "all" ? nil : optionID)
        case .repetitions:
            if optionID == "custom" {
                showingCustomRepInput = true
            } else {
                appState.leaderboardFilters.repetitionCount = optionID == "all" ? nil : Int(optionID)
            }
        case .age:
            appState.leaderboardFilters.ageGroup = optionID == "all" ? nil : optionID
        case .timeRange:
            appState.leaderboardFilters.timeRange = optionID
        case .verification:
            appState.leaderboardFilters.verificationLevel = nil
            if optionID == "verified" {
                appState.verifiedOnly = true
            } else if optionID == "all" {
                appState.verifiedOnly = false
            } else if optionID.hasPrefix("level:"),
                      let status = VerificationStatus(rawValue: String(optionID.dropFirst(6))) {
                appState.verifiedOnly = false
                appState.leaderboardFilters.verificationLevel = status
            }
        }
    }

    private func weightClassDisplayName(_ weightClass: WeightClass) -> String {
        guard appState.currentProfile.preferredUnit == .pounds else { return weightClass.name }
        if let maximum = weightClass.maxKilograms {
            return "\(RankingCalculator.format(RankingCalculator.usaplPoundEquivalent(maximum))) lb (\(weightClass.name))"
        }
        let lower = RankingCalculator.usaplPoundEquivalent(weightClass.minKilograms ?? 0)
        return "\(RankingCalculator.format(lower))+ lb (\(weightClass.name))"
    }

    private func focusCurrentUserIfNeeded(using proxy: ScrollViewProxy) {
        guard let requestID = appState.leaderboardFocusRequestID,
              requestID != handledFocusRequestID,
              visibleEntries.contains(where: { $0.profile.id == appState.currentProfile.id }) else {
            return
        }

        handledFocusRequestID = requestID
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(appState.currentProfile.id, anchor: .center)
            }
        }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    var rankingType: RankingType = .absolute

    private var rankColor: Color {
        switch entry.rank {
        case 1: return .liftGold
        case 2: return .liftSilver
        case 3: return .liftBronze
        default: return .liftMuted
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
                            Text(entry.profile.username)
                                .font(.headline)
                                .lineLimit(1)
                            if entry.profile.id == MockData.demoUserID {
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
                        Text(scoreText(for: entry, rankingType: rankingType))
                            .font(.headline)
                        Label(entry.rankMovement >= 0 ? "+\(entry.rankMovement)" : "\(entry.rankMovement)", systemImage: entry.rankMovement >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption.bold())
                            .foregroundStyle(entry.rankMovement >= 0 ? Color.liftGreen : Color.liftRed)
                    }
                }

                HStack(spacing: 8) {
                    Label(entry.lift.exerciseName, systemImage: "dumbbell.fill")
                    Label(entry.profile.hideBodyweight ? "Hidden BW" : "\(Int(entry.lift.bodyweightAtLift)) lb BW", systemImage: "scalemass.fill")
                    Label(entry.profile.hideCity ? "Location hidden" : "\(entry.profile.city), \(entry.profile.state)", systemImage: "mappin.and.ellipse")
                }
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .lineLimit(1)

                VerificationBadge(status: entry.lift.verificationStatus)
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
        let legacy = Set(appState.profiles.map(\.ageGroup)).subtracting(MockData.standardAgeGroups)
        return MockData.standardAgeGroups + legacy.sorted()
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
            classes: MockData.weightClasses
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
                                ForEach(MockData.weightClasses.filter { appState.leaderboardFilters.sexCategory == nil || $0.sexCategory == appState.leaderboardFilters.sexCategory }) { weightClass in
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

                        filterGroup("Verification and time", symbol: "checkmark.seal.fill") {
                            optionRow("Submission status") {
                                optionButton(appState.verifiedOnly ? "Verified only" : "All submissions", isActive: true) {
                                    appState.verifiedOnly.toggle()
                                }
                            }
                            optionRow("Verification level") {
                                optionButton("Any", isActive: appState.leaderboardFilters.verificationLevel == nil) {
                                    appState.leaderboardFilters.verificationLevel = nil
                                }
                                ForEach(VerificationStatus.allCases) { status in
                                    optionButton(status.rawValue, isActive: appState.leaderboardFilters.verificationLevel == status) {
                                        appState.leaderboardFilters.verificationLevel = status
                                    }
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

func scoreText(for entry: LeaderboardEntry, rankingType: RankingType) -> String {
    leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: .pounds)
}

func leaderboardValueText(for entry: LeaderboardEntry, rankingType: RankingType, preferredUnit: UnitSystem) -> String {
    switch rankingType {
    case .absolute:
        let value = preferredUnit == .kilograms ? entry.score : RankingCalculator.kilogramsToPounds(entry.score)
        return "\(RankingCalculator.format(value)) \(preferredUnit.shortLabel)"
    case .poundForPound:
        return "\(String(format: "%.2f", entry.score))x"
    case .total:
        let value = preferredUnit == .kilograms ? entry.score : RankingCalculator.kilogramsToPounds(entry.score)
        return "\(RankingCalculator.format(value)) \(preferredUnit.shortLabel)"
    case .relativeTotal:
        return "\(String(format: "%.2f", entry.score))x"
    case .mostImproved:
        return "\(entry.score >= 0 ? "+" : "")\(RankingCalculator.format(entry.score))%"
    }
}
