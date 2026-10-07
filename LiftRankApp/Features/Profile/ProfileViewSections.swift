import SwiftUI

enum ProfileSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case prVideos = "PR videos"
    case training = "Training"
    case history = "Workout history"
    case timeline = "Timeline"
    case submissions = "Submissions"

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
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? Color.liftText : Color.liftMuted)
                    .padding(.horizontal, 14)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    .background(isSelected ? Color.liftLime : Color.liftSurfaceElevated)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("profile.section.\(section.id)")
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
                        header
                        if !isCurrentUser && liftPresentation.lifts.isEmpty {
                            LiftEmptyState(
                                title: "No public training data",
                                message: "This athlete hasn’t shared any qualifying lifts yet, or their submissions are private.",
                                symbolName: "eye.slash",
                                compact: true
                            )
                            .accessibilityIdentifier("profile.noPublicData")
                        }
                        Text("Jump to")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            ProfileSectionNavigation(
                                selection: $selectedProfileSection,
                            sections: isCurrentUser
                                ? ProfileSection.allCases
                                : [.overview, .prVideos, .training, .submissions]
                        ) { section in
                            if section == .training { showingAthleteDetails = true }
                            withAnimation(.easeInOut) { proxy.scrollTo(section.id, anchor: .top) }
                        }
                        .padding(.vertical, 2)
                        Group {
                            summary(presentation: liftPresentation)
                                .id(ProfileSection.overview.id)
                            ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser, prefilteredLifts: liftPresentation.lifts)
                                .id(ProfileSection.prVideos.id)
                            athleteDetails(presentation: liftPresentation)
                                .id(ProfileSection.training.id)
                            if isCurrentUser {
                                trainingHistory
                                    .id(ProfileSection.history.id)
                                profileTimeline
                                    .id(ProfileSection.timeline.id)
                            }
                            recentSubmissions(profileLifts: liftPresentation.lifts)
                                .id(ProfileSection.submissions.id)
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
            .navigationTitle(isCurrentUser ? "Personal profile" : (profile.username.isEmpty ? "Public profile" : profile.username))
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
        .alert(submissionPendingDeletion?.requiresCoordinatedRemoval == true ? "Remove protected submission?" : "Permanently delete submission?", isPresented: Binding(
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
                Text("Remove \(lift.exerciseName)? Its video, proof, moderation state, and ranking record will be cleaned together. This cannot be undone.")
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
