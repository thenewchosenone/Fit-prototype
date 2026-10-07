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
        let currentEntry = matchingEntries.first { $0.profile.id == appState.currentProfile.id }

        return AppBackground {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            LeaderboardMetricStrip(
                                rank: RankingFormatting.leaderboardRankText(rank: currentEntry?.rank),
                                lifters: matchingEntries.count,
                                ranking: appState.leaderboardFilters.rankingType.rawValue
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 14)

                            LeaderboardTabBar(selection: rankingTypeBinding, types: availableRankingTypes)
                            filterBar.padding(.vertical, 10)

                            if appState.leaderboardFilters.exerciseID == nil,
                               [.total, .relativeTotal].contains(appState.leaderboardFilters.rankingType) {
                                Label(
                                    appState.leaderboardFilters.rankingType == .relativeTotal
                                        ? "Relative total compares best bench, squat, and deadlift to bodyweight."
                                        : "Total combines each lifter’s best bench, squat, and deadlift.",
                                    systemImage: "info.circle"
                                )
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            if appState.leaderboardFilters.exerciseID == nil,
                               appState.leaderboardFilters.rankingType == .absolute {
                                Label(
                                    "All exercises ranks each athlete by their best eligible single lift. Choose an exercise for an exercise-specific ranking.",
                                    systemImage: "info.circle"
                                )
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            if let evidenceMessage = leaderboardEvidenceMessage {
                                Label(evidenceMessage, systemImage: appState.verifiedOnly ? "video.fill" : "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }

                            if currentUserEntry != nil {
                                Button {
                                    appState.leaderboardFocusRequestID = UUID()
                                } label: {
                                    Label("Jump to my rank", systemImage: "location.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftAccentText)
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(Color.liftBlue.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
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
                                                    showsGym: true
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
                                                Text("Load next 100")
                                                    .font(.subheadline.weight(.bold))
                                                    .frame(maxWidth: .infinity, minHeight: 48)
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(Color.liftAccentText)
                                            .accessibilityLabel("Load next 100 leaderboard entries")
                                        }
                                    }
                                    .background(Color.liftCard.opacity(0.44))
                                } header: {
                                    LeaderboardTableHeader(resultCount: entries.count, valueTitle: valueColumnTitle)
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
                    .accessibilityIdentifier("leaderboard.submitLift")
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
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                athleteSearchResults = await appState.searchAthletes(query)
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
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftGold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                Button {
                    Task { await appState.refreshLeaderboard() }
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
