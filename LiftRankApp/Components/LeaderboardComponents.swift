import SwiftUI

enum LeaderboardMovementPresentation: Equatable {
    case up(Int)
    case down(Int)
    case unchanged

    init(_ movement: Int) {
        if movement > 0 {
            self = .up(movement)
        } else if movement < 0 {
            self = .down(abs(movement))
        } else {
            self = .unchanged
        }
    }
}

enum LeaderboardRankPresentation {
    static func color(for rank: Int) -> Color {
        switch rank {
        case 1: return .liftGold
        case 2: return .liftSilver
        case 3: return .liftBronze
        default: return .liftMuted
        }
    }
}

enum LeaderboardAgeGroupPresentation {
    static func groups(from profiles: [UserProfile]) -> [String] {
        let legacy = Set(profiles.map(\.ageGroup)).subtracting(MockData.standardAgeGroups)
        return MockData.standardAgeGroups + legacy.sorted()
    }

    static func subtitle(for group: String) -> String? {
        MockData.legacyAgeGroups.contains(group) ? "Legacy profile range" : nil
    }
}

struct LeaderboardOption: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
}

enum LeaderboardSelector: String, Identifiable {
    case scope, exercise, repetitions, age, timeRange, verification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scope: return "Scope"
        case .exercise: return "Exercise"
        case .repetitions: return "Rep count"
        case .age: return "Age"
        case .timeRange: return "Time range"
        case .verification: return "Verification"
        }
    }
}

struct LeaderboardMetricStrip: View {
    let rank: String
    let lifters: Int
    let ranking: String

    var body: some View {
        HStack(spacing: 0) {
            metric("Your rank", rank, tint: .liftBlue)
            divider
            metric("Lifters", "\(lifters)")
            divider
            metric("Ranking", ranking)
            divider
            metric("Updates", "Live", tint: .liftGreen)
        }
        .padding(.vertical, 12)
        .liftSurface(radius: 12, raised: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rank \(rank), \(lifters) lifters, \(ranking), updates live")
    }

    private func metric(_ title: String, _ value: String, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 38)
    }
}

struct LeaderboardTabBar: View {
    @Binding var selection: RankingType
    var types: [RankingType] = RankingType.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 26) {
                ForEach(types) { type in
                    Button {
                        Haptics.light()
                        selection = type
                    } label: {
                        VStack(spacing: 9) {
                            Text(type.rawValue)
                                .font(.subheadline.weight(selection == type ? .bold : .medium))
                                .foregroundStyle(selection == type ? Color.liftText : Color.liftMuted)
                                .lineLimit(1)
                            Rectangle()
                                .fill(selection == type ? Color.liftBlue : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == type ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }
}

struct LeaderboardFilterControl: View {
    let title: String
    let value: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.liftBlue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.caption2).foregroundStyle(Color.liftMuted)
                    Text(value).font(.caption.weight(.semibold)).foregroundStyle(Color.liftText).lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .liftSurface(radius: 10, raised: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityIdentifier("leaderboard.filter.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

struct LeaderboardTableHeader: View {
    let resultCount: Int
    var valueTitle = "Total"

    var body: some View {
        HStack(spacing: 8) {
            Text("#  Lifter").frame(maxWidth: .infinity, alignment: .leading)
            Text(valueTitle).frame(width: 76, alignment: .trailing)
            Text("Move").frame(width: 48, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(Color.liftMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.liftBackground.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
        .accessibilityLabel("\(resultCount) ranked \(resultCount == 1 ? "lifter" : "lifters")")
    }
}

struct CompactLeaderboardRow: View {
    let entry: LeaderboardEntry
    var rankingType: RankingType = .absolute
    var isCurrentUser = false
    var preferredUnit: UnitSystem = .pounds
    var isExerciseLeaderboard = false
    var showsGym = false

    private var rankColor: Color {
        LeaderboardRankPresentation.color(for: entry.rank)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(entry.rank)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(rankColor)
                .frame(width: 26, alignment: .leading)
            ProfileAvatar(profile: entry.profile, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.profile.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if entry.lift.verificationStatus != .selfReported {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.liftBlue)
                    }
                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color.liftBlue)
                    }
                }
                if showsGym {
                    Text(entry.profile.hideGym ? "Gym hidden" : entry.profile.primaryGymName)
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                }
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted.opacity(0.84))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(RankingFormatting.leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: preferredUnit))
                .font(.subheadline.weight(.semibold))
                .frame(width: 76, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            movementLabel.frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
        .background(isCurrentUser ? Color.liftBlue.opacity(0.09) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.profile.displayName), at \(entry.profile.username), \(RankingFormatting.leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: preferredUnit)), \(movementAccessibility)")
        .accessibilityHint("Opens lifter profile")
    }

    private var movementLabel: some View {
        Group {
            switch LeaderboardMovementPresentation(entry.rankMovement) {
            case .up(let amount):
                Label("\(amount)", systemImage: "arrow.up").foregroundStyle(Color.liftGreen)
            case .down(let amount):
                Label("\(amount)", systemImage: "arrow.down").foregroundStyle(Color.liftRed)
            case .unchanged:
                Label("0", systemImage: "minus").foregroundStyle(Color.liftMuted)
            }
        }
        .font(.caption.weight(.bold))
        .labelStyle(.titleAndIcon)
    }

    private var movementAccessibility: String {
        switch LeaderboardMovementPresentation(entry.rankMovement) {
        case .up(let amount): return "up \(amount)"
        case .down(let amount): return "down \(amount)"
        case .unchanged: return "unchanged"
        }
    }

    private var detailText: String {
        if let breakdown = entry.powerliftingBreakdown, !isExerciseLeaderboard {
            return "@\(entry.profile.username) • S \(formatted(breakdown.squatKilograms)) • B \(formatted(breakdown.benchKilograms)) • D \(formatted(breakdown.deadliftKilograms))"
        }
        let location = ProfileDisplayFormatting.location(
            city: entry.profile.city,
            region: entry.profile.state,
            hidden: entry.profile.hideCity
        )
        return "@\(entry.profile.username) • \(entry.lift.repetitions) rep\(entry.lift.repetitions == 1 ? "" : "s") • \(formattedBodyweight) BW • \(location)"
    }

    private var formattedBodyweight: String {
        if entry.profile.hideBodyweight {
            return "Hidden"
        }
        return MeasurementFormatting.formatBodyweightOrDash(
            entry.lift.bodyweightAtLift,
            preferredUnit: preferredUnit
        )
    }

    private func formatted(_ kilograms: Double?) -> String {
        MeasurementFormatting.compactDisplayedWeightOrDash(kilograms, unit: preferredUnit)
    }
}

struct LeaderboardOptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let options: [LeaderboardOption]
    let selectedID: String
    var isSearchable = false
    var searchPrompt = "Search options"
    var emptyTitle = "No options found"
    var emptyMessage = "Try another search."
    var preferredOptionIDs: Set<String> = []
    var preferredScopeTitle: String?
    var allScopeTitle = "All"
    var emptyActionTitle: String?
    var onEmptyAction: (() -> Void)?
    var dismissOnSelection = true
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @State private var showsAllOptions = true
    @FocusState private var isSearchFocused: Bool

    private var scopedOptions: [LeaderboardOption] {
        guard !showsAllOptions, preferredScopeTitle != nil, !preferredOptionIDs.isEmpty else { return options }
        return options.filter { preferredOptionIDs.contains($0.id) }
    }

    private var visibleOptions: [LeaderboardOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchable, !query.isEmpty else { return scopedOptions }
        let tokens = normalizedSearchTokens(query)
        return scopedOptions.filter {
            let searchableText = [$0.title, $0.subtitle]
                .compactMap { $0 }
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            return tokens.allSatisfy(searchableText.contains)
        }
    }

    private func normalizedSearchTokens(_ query: String) -> [String] {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    var body: some View {
        if isSearchable {
            searchableSheetContent
        } else {
            sheetContent
        }
    }

    @ViewBuilder
    private var searchableSheetContent: some View {
        if #available(iOS 18.0, *) {
            sheetContent
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: searchPrompt
                )
                .searchFocused($isSearchFocused)
                .task {
                    await Task.yield()
                    isSearchFocused = true
                }
        } else {
            sheetContent
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: searchPrompt
                )
        }
    }

    private var sheetContent: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    if let preferredScopeTitle, !preferredOptionIDs.isEmpty {
                        VStack(spacing: 8) {
                            Picker("Search scope", selection: $showsAllOptions) {
                                Text(preferredScopeTitle).tag(false)
                                Text(allScopeTitle).tag(true)
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text(showsAllOptions ? allScopeTitle : "Gyms in \(preferredScopeTitle)")
                                Spacer()
                                Text("\(visibleOptions.count) results")
                            }
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }

                    if visibleOptions.isEmpty {
                        LiftEmptyState(
                            title: emptyTitle,
                            message: emptyMessage,
                            symbolName: "magnifyingglass",
                            actionTitle: emptyActionTitle,
                            action: onEmptyAction
                        )
                        .padding(.top, 48)
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleOptions) { option in
                                Button {
                                    onSelect(option.id)
                                    if dismissOnSelection {
                                        dismiss()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        if let symbol = option.symbol {
                                            Image(systemName: symbol)
                                                .foregroundStyle(Color.liftBlue)
                                                .frame(width: 24)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(option.title).font(.body.weight(.medium)).foregroundStyle(Color.liftText)
                                            if let subtitle = option.subtitle {
                                                Text(subtitle).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        if option.id == selectedID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.liftBlue)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 58)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("option.\(option.id)")
                                .accessibilityAddTraits(option.id == selectedID ? .isSelected : [])
                                Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 56)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
