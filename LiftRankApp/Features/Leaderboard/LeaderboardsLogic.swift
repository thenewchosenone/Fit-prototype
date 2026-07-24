import SwiftUI

extension LeaderboardsView {
    var allEntries: [LeaderboardEntry] {
        appState.leaderboardEntries()
    }

    var visibleEntries: [LeaderboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { entry in
            entry.profile.username.lowercased().contains(query) ||
            entry.profile.displayName.lowercased().contains(query) ||
            (appState.features.gymFeeds && entry.profile.primaryGymName.lowercased().contains(query)) ||
            entry.profile.city.lowercased().contains(query) ||
            entry.lift.exerciseName.lowercased().contains(query)
        }
    }

    var currentUserEntry: LeaderboardEntry? {
        allEntries.first { $0.profile.id == appState.currentProfile.id }
    }

    var bodyweightClass: WeightClass? {
        RankingCalculator.weightClass(
            for: appState.currentProfile.bodyweightPounds,
            sexCategory: appState.currentProfile.sexCategory,
            classes: WeightClassCatalog.all
        )
    }

    var activeFilterCount: Int {
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

    var athleteSearchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ATHLETES")
                .font(.caption2.weight(.black))
                .tracking(1)
                .foregroundStyle(Color.liftMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            ForEach(Array(athleteSearchResults.enumerated()), id: \.element.id) { index, profile in
                Button {
                    appState.selectedProfile = profile
                } label: {
                    HStack(spacing: 12) {
                        ProfileAvatar(profile: profile, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.liftText)
                            Text("@\(profile.username)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("leaderboard.searchAthlete.\(profile.id.uuidString)")
                if index < athleteSearchResults.count - 1 {
                    Divider().overlay(Color.liftSeparator).padding(.leading, 68)
                }
            }
        }
        .liftSurface()
    }

    var rankingTypeBinding: Binding<RankingType> {
        Binding(
            get: { appState.leaderboardFilters.rankingType },
            set: { appState.leaderboardFilters.rankingType = $0 }
        )
    }

    var availableRankingTypes: [RankingType] {
        appState.leaderboardFilters.exerciseID == nil
            ? RankingType.allCases
            : [.absolute, .poundForPound, .mostImproved]
    }

    var valueColumnTitle: String {
        switch appState.leaderboardFilters.rankingType {
        case .absolute: return appState.leaderboardFilters.exerciseID == nil ? "PR" : "PR"
        case .poundForPound: return "P4P"
        case .total: return "Total"
        case .relativeTotal: return "Relative"
        case .mostImproved: return "Improvement"
        }
    }

    var isGlobalScope: Bool {
        appState.leaderboardFilters.gymID == nil &&
        appState.leaderboardFilters.city == nil &&
        appState.leaderboardFilters.state == nil &&
        appState.leaderboardFilters.weightClassID == nil
    }

    var filterBar: some View {
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
                Button {
                    Haptics.light()
                    appState.showingLeaderboardFilters = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Filters")
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

    var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField(appState.features.gymFeeds ? "Search lifters, gyms, exercises" : "Search lifters or exercises", text: $searchText)
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

    var emptyState: some View {
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
                    .buttonStyle(LiftCompactProminentButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func resetFilters() {
        appState.leaderboardFilters = LeaderboardFilters(exerciseID: nil)
        appState.verifiedOnly = true
        searchText = ""
        Haptics.light()
    }

    var scopeLabel: String {
        if let gymID = appState.leaderboardFilters.gymID {
            guard appState.features.gymFeeds else { return "Global" }
            if gymID == appState.currentProfile.primaryGymID { return "My gym" }
            return appState.gyms.first(where: { $0.id == gymID })?.name ?? "Gym"
        }
        if appState.leaderboardFilters.city == appState.currentProfile.city { return "My city" }
        if appState.leaderboardFilters.weightClassID == bodyweightClass?.id { return "My class" }
        return isGlobalScope ? "Global" : "Custom"
    }

    var exerciseLabel: String {
        guard let id = appState.leaderboardFilters.exerciseID else { return "All" }
        return MockData.exercises.first(where: { $0.id == id })?.name ?? "Selected"
    }

    var repetitionLabel: String {
        appState.leaderboardFilters.repetitionCount.map { "\($0)" } ?? "All"
    }

    func options(for selector: LeaderboardSelector) -> [LeaderboardOption] {
        switch selector {
        case .scope:
            let broadScopes: [LeaderboardOption] = [
                .init(id: "global", title: "Global", subtitle: "All ranked lifters", symbol: "globe"),
                .init(id: "city", title: "My city", subtitle: "\(appState.currentProfile.city), \(appState.currentProfile.state)", symbol: "mappin.and.ellipse"),
                .init(id: "class", title: "My weight class", subtitle: bodyweightClass.map { RankingFormatting.weightClassDisplayName($0, preferredUnit: appState.currentProfile.preferredUnit) }, symbol: "person.crop.rectangle.stack")
            ]
            guard appState.features.gymFeeds else { return broadScopes }
            return broadScopes + [
                .init(id: "gym", title: "My gym", subtitle: appState.currentProfile.primaryGymName, symbol: "building.2.fill")
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
                .init(id: "video", title: "Video-backed", subtitle: "Only lifts with attached video evidence", symbol: "video.fill"),
                .init(id: "all", title: "All lifts", subtitle: "Video-backed and self-reported", symbol: "tray.full.fill"),
                .init(id: "self", title: "Self-reported", subtitle: "Only lifts without video evidence", symbol: "person.fill")
            ]
        }
    }

    func selectedOptionID(for selector: LeaderboardSelector) -> String {
        switch selector {
        case .scope:
            if appState.leaderboardFilters.gymID == appState.currentProfile.primaryGymID { return "gym" }
            if appState.leaderboardFilters.city == appState.currentProfile.city { return "city" }
            if appState.leaderboardFilters.weightClassID == bodyweightClass?.id { return "class" }
            if appState.features.gymFeeds, let gymID = appState.leaderboardFilters.gymID { return "gym:\(gymID.uuidString)" }
            return "global"
        case .exercise: return appState.leaderboardFilters.exerciseID ?? "all"
        case .repetitions: return appState.leaderboardFilters.repetitionCount.map(String.init) ?? "all"
        case .age: return appState.leaderboardFilters.ageGroup ?? "all"
        case .timeRange: return appState.leaderboardFilters.timeRange
        case .verification:
            if let level = appState.leaderboardFilters.verificationLevel {
                return level == .selfReported ? "self" : "video"
            }
            return appState.verifiedOnly ? "video" : "all"
        }
    }

    func apply(_ optionID: String, for selector: LeaderboardSelector) {
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
            if optionID == "video" {
                appState.verifiedOnly = true
            } else if optionID == "all" {
                appState.verifiedOnly = false
            } else if optionID == "self" {
                appState.verifiedOnly = false
                appState.leaderboardFilters.verificationLevel = .selfReported
            }
        }
    }

    func focusCurrentUserIfNeeded(using proxy: ScrollViewProxy) {
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
