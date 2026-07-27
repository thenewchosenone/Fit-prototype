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
        let entries = visibleEntries(from: leaderboardEntries)
        let currentEntry = leaderboardEntries.first { $0.profile.id == appState.currentProfile.id }

        return AppBackground {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            LeaderboardMetricStrip(
                                rank: RankingFormatting.leaderboardRankText(rank: currentEntry?.rank),
                                lifters: leaderboardEntries.count,
                                ranking: appState.leaderboardFilters.rankingType.rawValue,
                                nextUpdate: appState.nextLeaderboardUpdateDate(referenceDate: .now)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 14)

                            LeaderboardTabBar(selection: rankingTypeBinding, types: availableRankingTypes)
                            filterBar.padding(.vertical, 10)

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

                            if entries.isEmpty {
                                emptyState
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                            } else {
                                Section {
                                    VStack(spacing: 0) {
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
                                                    .overlay(Color.white.opacity(0.07))
                                                    .padding(.leading, 72)
                                            }
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
                    isSearchable: selector == .scope
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
            .onAppear {
                if appState.router.requestsLeaderboardSearch {
                    isSearchVisible = true
                    appState.router.requestsLeaderboardSearch = false
                }
            }
            .onChange(of: appState.router.requestsLeaderboardSearch) { _, requested in
                guard requested else { return }
                isSearchVisible = true
                appState.router.requestsLeaderboardSearch = false
            }
            .task(id: searchText) {
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
                guard lastRefreshedLeaderboardRequestKey != appState.leaderboardRequestKey else { return }
                lastRefreshedLeaderboardRequestKey = appState.leaderboardRequestKey
                await appState.refreshLeaderboard()
            }
    }
}
