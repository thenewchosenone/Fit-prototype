import SwiftUI

enum LeaderboardMovementPresentation: Equatable {
    case up(Int)
    case down(Int)
    case unavailable

    init(_ movement: Int) {
        if movement > 0 {
            self = .up(movement)
        } else if movement < 0 {
            self = .down(abs(movement))
        } else {
            self = .unavailable
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

enum CanonicalRankingPresentation {
    static func text(rank: Int?) -> String {
        rank.map { "#\($0)" } ?? "—"
    }
}

enum LeaderboardIdentityPresentation {
    static func isCurrentUser(entryProfileID: UUID, activeProfileID: UUID) -> Bool {
        entryProfileID == activeProfileID
    }
}

enum LeaderboardAgeGroupPresentation {
    static func groups(from profiles: [UserProfile]) -> [String] {
        let legacy = Set(profiles.map(\.ageGroup))
            .subtracting(MockData.standardAgeGroups)
            .filter { group in
                let value = group.trimmingCharacters(in: .whitespacesAndNewlines)
                return !value.isEmpty && value.caseInsensitiveCompare("Hidden") != .orderedSame
            }
        return MockData.standardAgeGroups + legacy.sorted()
    }

    static func subtitle(for group: String) -> String? {
        MockData.legacyAgeGroups.contains(group) ? "Legacy profile range" : nil
    }
}

struct LeaderboardOption: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
    var symbol: String?
    var exerciseCatalogID: String?
    var sectionTitle: String?
    fileprivate let searchableText: String

    init(id: String, title: String, subtitle: String? = nil, symbol: String? = nil, exerciseCatalogID: String? = nil, sectionTitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.exerciseCatalogID = exerciseCatalogID
        self.sectionTitle = sectionTitle
        self.searchableText = LeaderboardOptionSearch.normalizedText(
            [title, subtitle].compactMap { $0 }.joined(separator: " ")
        )
    }
}

enum LeaderboardOptionSearch {
    static func filter(_ options: [LeaderboardOption], query: String) -> [LeaderboardOption] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return options }
        let tokens = normalizedTokens(cleanQuery)
        return options.filter { option in
            tokens.allSatisfy(option.searchableText.contains)
        }
    }

    private static func normalizedTokens(_ query: String) -> [String] {
        normalizedText(query)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func normalizedText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rank: String
    let lifters: Int
    let ranking: String
    var rankTitle = "Your rank"

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(rankTitle, rank, tint: .liftBlue)
                    metricRow("Lifters", "\(lifters)")
                    metricRow("Ranking", ranking)
                }
                .padding(.horizontal, 14)
            } else {
                HStack(spacing: 0) {
                    metric(rankTitle, rank, tint: .liftBlue)
                    divider
                    metric("Lifters", "\(lifters)")
                    divider
                    metric("Ranking", ranking)
                }
            }
        }
        .padding(.vertical, 12)
        .liftSurface(radius: 12, raised: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rankTitle) \(rank), \(lifters) lifters, ranking by \(ranking)")
    }

    private func metricRow(_ title: String, _ value: String, tint: Color = .white) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Spacer(minLength: 8)
            Text(value)
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
    }

    private func metric(_ title: String, _ value: String, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            Text(value)
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.liftOverlay)
            .frame(width: 1, height: 38)
    }
}

struct LeaderboardTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: RankingType
    var types: [RankingType] = RankingType.allCases

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(types) { type in
                        tabButton(type)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 26) {
                        ForEach(types) { type in
                            tabButton(type)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.liftOverlay).frame(height: 1)
        }
    }

    private func tabButton(_ type: RankingType) -> some View {
        Button {
            Haptics.light()
            selection = type
        } label: {
            VStack(spacing: 9) {
                Text(type.rawValue)
                    .font(.subheadline.weight(selection == type ? .bold : .medium))
                    .foregroundStyle(selection == type ? Color.liftText : Color.liftMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(selection == type ? Color.liftBlue : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("leaderboard.ranking.\(type.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityAddTraits(selection == type ? .isSelected : [])
    }
}

struct LeaderboardFilterControl: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    .foregroundStyle(Color.liftAccentText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.caption2).foregroundStyle(Color.liftMuted)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.liftText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let resultCount: Int
    var valueTitle = "Total"
    var showsMovement = true

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text("\(resultCount) ranked \(resultCount == 1 ? "lifter" : "lifters")")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Text("#  Lifter").frame(maxWidth: .infinity, alignment: .leading)
                    Text(valueTitle).frame(width: 76, alignment: .trailing)
                    if showsMovement {
                        Text("Move").frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(Color.liftMuted)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.liftBackground.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.liftOverlay).frame(height: 1)
        }
        .accessibilityLabel("\(resultCount) ranked \(resultCount == 1 ? "lifter" : "lifters")")
    }
}

struct CompactLeaderboardRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: LeaderboardEntry
    var rankingType: RankingType = .absolute
    var isCurrentUser = false
    var preferredUnit: UnitSystem = .pounds
    var isExerciseLeaderboard = false
    var showsGym = false
    var showsMovement = true

    private var rankColor: Color {
        LeaderboardRankPresentation.color(for: entry.rank)
    }

    var body: some View {
        let valueText = RankingFormatting.leaderboardValueText(
            for: entry,
            rankingType: rankingType,
            preferredUnit: preferredUnit
        )
        let movement = LeaderboardMovementPresentation(entry.rankMovement)
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleRow(valueText: valueText, movement: movement)
            } else {
                compactRow(valueText: valueText, movement: movement)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 14 : 10)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 120 : 68)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrentUser ? Color.liftBlue.opacity(0.09) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.profile.displayName), at \(entry.profile.username), \(isCurrentUser ? "you, " : "")\(entry.lift.resolvedEvidenceStatus.displayName), \(valueText), \(detailText), \(movementAccessibility(movement))")
        .accessibilityHint("Opens lifter profile")
    }

    private func compactRow(valueText: String, movement: LeaderboardMovementPresentation) -> some View {
        HStack(spacing: 8) {
            Text("\(entry.rank)")
                .font(LiftTypography.rowEmphasis)
                .foregroundStyle(rankColor)
                .frame(width: 26, alignment: .leading)
            ProfileAvatar(profile: entry.profile, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.profile.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if entry.lift.resolvedEvidenceStatus == .videoBacked {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.liftAccentText)
                    }
                    if isCurrentUser {
                        Text("YOU")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                }
                if showsGym {
                    Text(entry.profile.hideGym ? "@\(entry.profile.username)" : entry.profile.primaryGymName)
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                } else {
                    Text("@\(entry.profile.username)")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                }
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(valueText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if showsMovement {
                movementLabel(movement)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func accessibleRow(valueText: String, movement: LeaderboardMovementPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(entry.rank)")
                    .font(LiftTypography.cardTitle)
                    .foregroundStyle(rankColor)
                    .frame(minWidth: 36, minHeight: 44, alignment: .leading)
                ProfileAvatar(profile: entry.profile, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.profile.displayName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(isCurrentUser ? "@\(entry.profile.username) · You" : "@\(entry.profile.username)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(valueText)
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if showsMovement, movement != .unavailable {
                    movementLabel(movement)
                }
            }
            Text(detailText)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
            if showsGym, !entry.profile.hideGym, !entry.profile.primaryGymName.isEmpty {
                Text(entry.profile.primaryGymName)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func movementLabel(_ movement: LeaderboardMovementPresentation) -> some View {
        Group {
            switch movement {
            case .up(let amount):
                Label("\(amount)", systemImage: "arrow.up").foregroundStyle(Color.liftGreen)
            case .down(let amount):
                Label("\(amount)", systemImage: "arrow.down").foregroundStyle(Color.liftRed)
            case .unavailable:
                Text("—").foregroundStyle(Color.liftMuted)
            }
        }
        .font(LiftTypography.compactEmphasis)
        .labelStyle(.titleAndIcon)
    }

    private func movementAccessibility(_ movement: LeaderboardMovementPresentation) -> String {
        switch movement {
        case .up(let amount): return "up \(amount)"
        case .down(let amount): return "down \(amount)"
        case .unavailable: return "rank movement unavailable"
        }
    }

    private var detailText: String {
        if let breakdown = entry.powerliftingBreakdown, !isExerciseLeaderboard {
            return "S \(formatted(breakdown.squatKilograms)) · B \(formatted(breakdown.benchKilograms)) · D \(formatted(breakdown.deadliftKilograms))"
        }
        if rankingType == .total || rankingType == .relativeTotal {
            return "@\(entry.profile.username) · \(formattedBodyweight) BW"
        }
        let context = isExerciseLeaderboard ? "\(entry.lift.repetitions) rep\(entry.lift.repetitions == 1 ? "" : "s")" : entry.lift.exerciseName
        return "\(context) · \(formattedBodyweight) BW"
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    private var scopedOptions: [LeaderboardOption] {
        guard !showsAllOptions, preferredScopeTitle != nil, !preferredOptionIDs.isEmpty else { return options }
        return options.filter { preferredOptionIDs.contains($0.id) }
    }

    private var visibleOptions: [LeaderboardOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchable, !query.isEmpty else { return scopedOptions }
        return LeaderboardOptionSearch.filter(scopedOptions, query: query)
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
        let visibleOptions = visibleOptions
        return NavigationStack {
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
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(visibleOptions.enumerated()), id: \.element.id) { index, option in
                                if let sectionTitle = option.sectionTitle,
                                   index == 0 || visibleOptions[index - 1].sectionTitle != sectionTitle {
                                    Text(sectionTitle)
                                        .font(LiftTypography.compactEmphasis)
                                        .foregroundStyle(Color.liftMuted)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 14)
                                        .padding(.bottom, 6)
                                }
                                Button {
                                    onSelect(option.id)
                                    if dismissOnSelection {
                                        dismiss()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        if let exerciseCatalogID = option.exerciseCatalogID,
                                           let exercise = MockData.trainingExerciseLibrary.first(where: { $0.id == exerciseCatalogID }) {
                                            ExerciseCatalogIcon(exercise: exercise)
                                                .scaleEffect(0.72)
                                                .frame(width: 40, height: 40)
                                        } else if let symbol = option.symbol {
                                            Image(systemName: symbol)
                                                .foregroundStyle(Color.liftAccentText)
                                                .frame(width: 24)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(option.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(Color.liftText)
                                                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                                            if let subtitle = option.subtitle {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                                            }
                                        }
                                        Spacer()
                                        if option.id == selectedID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.liftAccentText)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 58)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("option.\(option.id)")
                                .accessibilityAddTraits(option.id == selectedID ? .isSelected : [])
                                Divider().overlay(Color.liftOverlay).padding(.leading, 56)
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
