import SwiftUI

enum ProfileSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case prVideos = "PR videos"
    case training = "Training"
    case history = "Workout history"
    case timeline = "Timeline"
    case submissions = "Activity"

    var id: String {
        switch self {
        case .overview: return "overview"
        case .prVideos: return "prVideos"
        case .training: return "training"
        case .history: return "history"
        case .timeline: return "timeline"
        case .submissions: return "submissions"
        }
    }
}

private struct ProfileSectionNavigation: View {
    @Binding var selection: ProfileSection
    let sections: [ProfileSection]
    let onSelect: (ProfileSection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections, id: \.id) { section in
                    let isSelected = selection == section
                    Button(action: { select(section) }) {
                        Text(section.rawValue)
                    }
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(isSelected ? Color.liftOnAccent : Color.liftMuted)
                    .padding(.horizontal, 14)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    .background(isSelected ? Color.liftLime : Color.liftSurfaceElevated)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("profile.section.\(section.id)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.sectionNavigation")
    }

    private func select(_ section: ProfileSection) {
        selection = section
        onSelect(section)
    }
}

extension ProfileView {
    var featureBody: some View {
        AppBackground {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    if !isCurrentUser && appState.isBlocked(profile.id) {
                        blockedProfileState
                    } else if !isCurrentUser && !appState.competitionStore.canViewProfile(
                        profile,
                        viewerID: viewerID ?? appState.currentProfile.id
                    ) {
                        restrictedProfileState
                    } else {
                        header.id("profile-content-top")
                        if let profileLoadError {
                            LiftEmptyState(
                                title: "Couldn't load training data",
                                message: profileLoadError,
                                symbolName: "wifi.exclamationmark",
                                actionTitle: "Retry",
                                action: { Task { await refreshProfileData(force: true) } },
                                compact: true
                            )
                        }
                        if !isCurrentUser && liftPresentation.lifts.isEmpty && profileLoadError == nil {
                            LiftEmptyState(
                                title: "No public training data",
                                message: "Qualifying lifts are either not shared yet or not available to visitors.",
                                symbolName: "eye.slash",
                                compact: true
                            )
                            .accessibilityIdentifier("profile.noPublicData")
                        }
                        if isCurrentUser || !liftPresentation.lifts.isEmpty {
                        ProfileSectionNavigation(
                                selection: $selectedProfileSection,
                            sections: [.overview, .submissions, .prVideos, .training]
                        ) { section in
                            if section == .training { showingAthleteDetails = true }
                            withAnimation(.easeInOut) { proxy.scrollTo("profile-content-top", anchor: .top) }
                        }
                        .padding(.vertical, 2)
                        Group {
                            switch selectedProfileSection {
                            case .overview:
                                summary(presentation: liftPresentation)
                            case .prVideos:
                                ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser, prefilteredLifts: liftPresentation.lifts)
                            case .training:
                                athleteDetails(presentation: liftPresentation)
                                if isCurrentUser {
                                    Button("Open private workout history in Track") {
                                        appState.router.progressCategory = .consistency
                                        appState.trainingTrackerStartOnProgress = true
                                        appState.requestedTrackerSegment = "Progress"
                                        appState.selectedTab = 2
                                    }
                                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                                }
                            case .submissions:
                                recentSubmissions(profileLifts: liftPresentation.lifts)
                                if isCurrentUser { DisclosureGroup("Training milestones") { profileTimeline } }
                            case .history, .timeline:
                                if isCurrentUser { trainingHistory }
                            }

                        }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshProfileData(force: true)
            }
            }
            .sheet(isPresented: $showingPhotoManager) {
                ProfilePhotoManagerView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingPublicPreview) {
                NavigationStack {
                    ProfileView(profile: profile, surface: .public, viewerID: UUID())
                        .environmentObject(appState)
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedTimelineWorkout) { workout in
                CompletedWorkoutDetailView(workout: workout)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedProfileLiftHistory) { destination in
                TopLiftCardDetailSheet(destination: destination)
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .navigationTitle(isCurrentUser ? "Personal profile" : (profile.username.isEmpty ? "Public profile" : profile.username))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isCurrentUser {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            appState.showingSubmitSheet = true
                        } label: {
                            Label("Submit lift", systemImage: "plus.circle.fill")
                        }
                        .accessibilityLabel("Submit a lift")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingPublicPreview = true
                            } label: {
                                Label("View as public", systemImage: "eye")
                            }
                            Button {
                                appState.showingSettings = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Label("Profile actions", systemImage: "gearshape.circle.fill")
                        }
                        .accessibilityLabel("Profile actions")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Report athlete", role: .destructive) {
                                appState.selectedReportProfile = profile
                            }
                            .accessibilityIdentifier("profile.reportAthlete")
                            Button(appState.isBlocked(profile.id) ? "Unblock athlete" : "Block athlete", role: appState.isBlocked(profile.id) ? nil : .destructive) {
                                if appState.isBlocked(profile.id) {
                                    appState.setBlocked(profile.id, blocked: false)
                                } else {
                                    confirmingProfileBlock = true
                                }
                            }
                            .accessibilityIdentifier(appState.isBlocked(profile.id) ? "profile.unblockAthlete" : "profile.blockAthlete")
                        } label: { Image(systemName: "ellipsis.circle.fill") }
                        .accessibilityLabel("Athlete options")
                        .accessibilityIdentifier("profile.athleteOptions")
                        .accessibilityValue(appState.isBlocked(profile.id) ? "Blocked" : "Not blocked")
                    }
                }
            }
        }
        .task(id: profile.id) {
            await refreshProfileData(force: false)
        }
        .onChange(of: appState.competitionStore.liftsRevision) { _, _ in
            Task { await refreshVisibleProfileLifts() }
        }
        .onChange(of: appState.authenticatedPrivacy) { _, _ in
            Task { await refreshVisibleProfileLifts() }
        }
        .alert(submissionPendingDeletion?.requiresCoordinatedRemoval == true ? "Remove submission and video?" : "Permanently delete submission?", isPresented: Binding(
            get: { submissionPendingDeletion != nil },
            set: { if !$0 { submissionPendingDeletion = nil } }
        ), presenting: submissionPendingDeletion) { lift in
            Button("Cancel", role: .cancel) {
                submissionPendingDeletion = nil
            }
            Button(lift.requiresCoordinatedRemoval ? "Remove submission" : "Delete permanently", role: .destructive) {
                Task { await deleteSubmission(lift) }
            }
        } message: { lift in
            if lift.requiresCoordinatedRemoval {
                Text("Remove \(lift.exerciseName)? This removes the lift and its video. This cannot be undone.")
            } else {
                Text("Delete \(lift.exerciseName)? This permanently removes the submission and cannot be undone.")
            }
        }
        .alert("Submission not deleted", isPresented: Binding(
            get: { submissionDeletionError != nil },
            set: { if !$0 { submissionDeletionError = nil } }
        )) {
            Button("OK", role: .cancel) { submissionDeletionError = nil }
        } message: {
            Text(submissionDeletionError ?? "Try again.")
        }
        .confirmationDialog("Block this athlete?", isPresented: $confirmingProfileBlock, titleVisibility: .visible) {
            Button("Block athlete", role: .destructive) {
                appState.setBlocked(profile.id, blocked: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won’t see this athlete’s profile, lifts, or activity until you unblock them.")
        }
    }

    private func refreshProfileData(force: Bool) async {
        profileLoadError = nil
        if !isCurrentUser && appState.isAuthenticated && !appState.isDemoMode {
            do {
                try await appState.competitionStore.refreshProfileSubmissions(for: profile.id)
            } catch {
                profileLoadError = appState.userMessage(error)
            }
        }
        await refreshVisibleProfileLifts()
        if isCurrentUser {
            async let lifts: Void = appState.refreshProductionLifts(force: force)
            async let ranking: Void = appState.refreshCurrentUserTotalRanking(force: force)
            _ = await (lifts, ranking)
        }
    }

    @MainActor
    private func deleteSubmission(_ lift: LiftSubmission) async {
        isDeletingSubmission = true
        submissionPendingDeletion = nil
        let error = await appState.removeSubmission(lift)
        isDeletingSubmission = false
        if let error {
            submissionDeletionError = error
        } else {
            await refreshVisibleProfileLifts()
        }
    }
}
