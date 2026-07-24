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
    let nextUpdate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            HStack(spacing: 0) {
                metric("Your rank", rank, tint: .liftBlue)
                divider
                metric("Lifters", "\(lifters)")
                divider
                metric("Ranking", ranking)
                divider
                metric("Updates", LiftTimeFormatter.relative(nextUpdate), tint: .liftGreen)
            }
            .padding(.vertical, 12)
            .liftSurface(radius: 12, raised: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your rank \(rank), \(lifters) lifters, \(ranking), next update \(LiftTimeFormatter.relative(nextUpdate, wide: true))")
        }
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
                                .foregroundStyle(selection == type ? .white : Color.liftMuted)
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
        switch entry.rank {
        case 1: return .liftGold
        case 2: return .liftSilver
        case 3: return .liftBronze
        default: return .liftMuted
        }
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
                    Text(entry.profile.username)
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
        .accessibilityLabel("Rank \(entry.rank), \(entry.profile.username), \(RankingFormatting.leaderboardValueText(for: entry, rankingType: rankingType, preferredUnit: preferredUnit)), \(movementAccessibility)")
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
            return "S \(formatted(breakdown.squatKilograms)) • B \(formatted(breakdown.benchKilograms)) • D \(formatted(breakdown.deadliftKilograms))"
        }
        let location = ProfileDisplayFormatting.location(
            city: entry.profile.city,
            region: entry.profile.state,
            hidden: entry.profile.hideCity
        )
        return "\(entry.lift.repetitions) rep\(entry.lift.repetitions == 1 ? "" : "s") • \(formattedBodyweight) BW • \(location)"
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
    var searchPrompt = "Search gyms"
    var emptyTitle = "No options found"
    var emptyMessage = "Try another search."
    var dismissOnSelection = true
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @State private var isSearchPresented = true

    private var visibleOptions: [LeaderboardOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isSearchable, !query.isEmpty else { return options }
        return options.filter {
            $0.title.lowercased().contains(query) || ($0.subtitle?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    if visibleOptions.isEmpty {
                        LiftEmptyState(
                            title: emptyTitle,
                            message: emptyMessage,
                            symbolName: "magnifyingglass"
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
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                isPresented: Binding(
                    get: { isSearchable && isSearchPresented },
                    set: { isSearchPresented = $0 }
                ),
                prompt: searchPrompt
            )
            .onChange(of: isSearchPresented) { _, isPresented in
                if !isPresented {
                    searchText = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
