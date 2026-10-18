import SwiftUI

extension LeaderboardsView {
    @ViewBuilder
    var featureBody: some View {
        if appState.router.selectedTab == .leaderboards {
            leaderboardContent
        } else {
            AppBackground {
                Color.clear
            }
        }
    }

    private var leaderboardContent: some View {
        let leaderboardEntries = allEntries
        let matchingEntries = visibleEntries(from: leaderboardEntries)
        let entries = Array(matchingEntries.prefix(leaderboardPage * 100))
        let currentEntry = leaderboardEntries.first { $0.profile.id == appState.currentProfile.id }
        let showsMovement = matchingEntries.contains { $0.rankMovement != 0 }

        return AppBackground {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            LeaderboardTabBar(selection: rankingTypeBinding, types: availableRankingTypes)
                            filterBar.padding(.top, 8).padding(.bottom, 10)
                            activeFilterChips.padding(.bottom, 8)

                            (dynamicTypeSize.isAccessibilitySize
                             ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                             : AnyLayout(HStackLayout(spacing: 8))) {
                                Text(appState.isLeaderboardRequestPending
                                     ? "Updating results…"
                                     : appState.competitionStore.leaderboardError != nil
                                        ? "Results unavailable"
                                        : "\(matchingEntries.count) \(matchingEntries.count == 1 ? "lifter" : "lifters")\(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " found") · \(appState.leaderboardFilters.timeRange)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    showsRankingExplanation.toggle()
                                } label: {
                                    Label("How ranks work", systemImage: "info.circle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(showsRankingExplanation ? "Expanded" : "Collapsed")
                            }
                            .padding(.horizontal, 16)

                            Group {
                                if showsRankingExplanation {
                                    let explanation = switch appState.leaderboardFilters.rankingType {
                                    case .relativeTotal: "Relative total divides each lifter’s best bench press, squat, and deadlift total by their bodyweight."
                                    case .total: "Total adds each lifter’s best eligible bench press, squat, and deadlift. You can rank with one or two of these lifts; missing lifts add nothing to your total. S, B, and D show squat, bench, and deadlift when a breakdown is available."
                                    case .absolute: "Absolute ranks lifters by the heaviest eligible lift. Choose an exercise to compare the same movement."
                                    case .poundForPound: "Pound-for-pound divides the lifted weight by bodyweight. A higher multiple ranks higher."
                                    case .mostImproved: "Most improved ranks percentage gains over each lifter’s earlier best for the same exercise. It compares eligible lifts within the selected time range: \(appState.leaderboardFilters.timeRange.lowercased()). At least two results are needed for a comparison."
                                    }
                                    Text(explanation)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                }
                            }
                            if showsRankingExplanation, let evidenceMessage = leaderboardEvidenceMessage {
                                Text(evidenceMessage).font(.caption).foregroundStyle(Color.liftMuted)
                                    .padding(.horizontal, 16).padding(.bottom, 8)
                            }

                            if let currentEntry, !appState.isLeaderboardRequestPending, appState.competitionStore.leaderboardError == nil {
                                Button {
                                    searchText = ""
                                    appState.leaderboardFocusRequestID = UUID()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Your rank")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.liftMuted)
                                            Text("#\(currentEntry.rank)")
                                                .font(LiftTypography.sectionTitle)
                                                .foregroundStyle(Color.liftText)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(RankingFormatting.leaderboardValueText(for: currentEntry, rankingType: appState.leaderboardFilters.rankingType, preferredUnit: appState.currentProfile.preferredUnit))
                                                .font(LiftTypography.cardTitle)
                                                .foregroundStyle(Color.liftText)
                                            Text("View your result")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.liftAccentText)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(LiftTypography.compactEmphasis)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    .padding(14)
                                    .liftSurface(radius: 16)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .accessibilityLabel("Your rank number \(currentEntry.rank). View your result")
                                .accessibilityIdentifier("leaderboard.jumpToMyRank")
                            }

                            if isSearchVisible || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                searchField
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               !athleteSearchResults.isEmpty {
                                athleteSearchSection
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                            }

                            if appState.isLeaderboardRequestPending {
                                leaderboardLoadingState
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else if let leaderboardError = appState.competitionStore.leaderboardError {
                                leaderboardErrorState(leaderboardError)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else if entries.isEmpty {
                                emptyState
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else {
                                Section {
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                            Button {
                                                appState.selectedProfile = entry.profile
                                            } label: {
                                                CompactLeaderboardRow(
                                                    entry: entry,
                                                    rankingType: appState.leaderboardFilters.rankingType,
                                                    isCurrentUser: entry.profile.id == appState.currentProfile.id,
                                                    preferredUnit: appState.currentProfile.preferredUnit,
                                                    isExerciseLeaderboard: appState.leaderboardFilters.exerciseID != nil,
                                                    showsGym: appState.leaderboardFilters.gymID == nil,
                                                    showsMovement: showsMovement
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityIdentifier("leaderboard.athlete.\(entry.profile.id.uuidString)")
                                            .accessibilityValue(entry.profile.id == appState.currentProfile.id ? "Current user" : "Other athlete")
                                            .id(entry.profile.id)

                                            if index < entries.count - 1 {
                                                Divider()
                                                    .overlay(Color.liftOverlay)
                                                    .padding(.leading, 72)
                                            }
                                        }

                                        if entries.count < matchingEntries.count {
                                            Button {
                                                leaderboardPage += 1
                                            } label: {
                                                Text("Load more lifters")
                                                    .font(LiftTypography.rowEmphasis)
                                                    .frame(maxWidth: .infinity, minHeight: 48)
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(Color.liftAccentText)
                                            .accessibilityLabel("Load next 100 leaderboard entries")
                                        }
                                    }
                                    .background(Color.liftCard.opacity(0.44))
                                } header: {
                                    LeaderboardTableHeader(resultCount: matchingEntries.count, valueTitle: valueColumnTitle, showsMovement: showsMovement)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await appState.refreshLeaderboard(force: true) }
                    .onAppear {
                        appState.normalizeLeaderboardFilters()
                        focusCurrentUserIfNeeded(using: proxy)
                    }
                    .onChange(of: appState.leaderboardFocusRequestID) { _, _ in
                        focusCurrentUserIfNeeded(using: proxy)
                    }
                }
            }
        }
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.showingSubmitSheet = true
                    } label: {
                        Label("Submit lift", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Submit a lift")
                    .accessibilityIdentifier("leaderboard.submitLift")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    moreFiltersControl
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
                    isSearchable: selector == .exercise || selector == .scope,
                    searchPrompt: selector == .exercise ? "Search exercises" : "Search locations or gyms"
                ) { optionID in
                    apply(optionID, for: selector)
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
            .task(id: searchText) {
                leaderboardPage = 1
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard query.count >= 2 else {
                    athleteSearchResults = []
                    return
                }
                athleteSearchResults = []
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                let results = await appState.searchAthletes(query)
                guard !Task.isCancelled else { return }
                athleteSearchResults = results
            }
            .task(id: appState.leaderboardRequestKey) {
                leaderboardPage = 1
                guard lastRefreshedLeaderboardRequestKey != appState.leaderboardRequestKey else { return }
                lastRefreshedLeaderboardRequestKey = appState.leaderboardRequestKey
                guard appState.isLeaderboardRequestPending else { return }
                await appState.refreshLeaderboard()
            }
    }

    private var leaderboardLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.liftAccentText)
            Text("Updating leaderboard")
                .font(.headline)
            Text("Loading the selected ranking.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Updating leaderboard")
    }

    private func leaderboardErrorState(_ message: String) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Leaderboard unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(LiftTypography.cardTitle)
                    .foregroundStyle(Color.liftGold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                Button {
                    Task { await appState.refreshLeaderboard(force: true) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiftCompactProminentButtonStyle())
                .accessibilityIdentifier("leaderboard.retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leaderboard.error")
    }
}
