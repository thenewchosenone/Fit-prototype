import SwiftUI

enum ProfileSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case prVideos = "PR videos"
    case training = "Training"
    case history = "History"
    case submissions = "Submissions"

    var id: String {
        switch self {
        case .overview: return "overview"
        case .prVideos: return "prVideos"
        case .training: return "training"
        case .history: return "history"
        case .submissions: return "submissions"
        }
    }
}

private struct ProfileSectionNavigation: View {
    @Binding var selection: ProfileSection
    let onSelect: (ProfileSection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileSection.allCases, id: \.id) { section in
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
                    header
                    ProfileSectionNavigation(selection: $selectedProfileSection) { section in
                        withAnimation(.easeInOut) { proxy.scrollTo(section.id, anchor: .top) }
                    }
                    .padding(.vertical, 2)
                    Group {
                        summary(profileLifts: visibleProfileLifts)
                            .id(ProfileSection.overview.id)
                        ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser, prefilteredLifts: visibleProfileLifts)
                            .id(ProfileSection.prVideos.id)
                        athleteDetails(profileLifts: visibleProfileLifts)
                            .id(ProfileSection.training.id)
                        trainingHistory
                            .id(ProfileSection.history.id)
                        recentSubmissions(profileLifts: visibleProfileLifts)
                            .id(ProfileSection.submissions.id)
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshProfileData()
            }
            }
            .sheet(isPresented: $showingPhotoManager) {
                ProfilePhotoManagerView()
                    .environmentObject(appState)
            }
            .navigationTitle(isCurrentUser ? "Profile" : profile.username)
            .toolbar {
                if isCurrentUser {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            appState.showingSubmitSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("Submit a lift")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            appState.showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.circle.fill")
                        }
                        .accessibilityLabel("Open settings")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Report athlete", role: .destructive) {
                                appState.selectedReportProfile = profile
                            }
                            .accessibilityIdentifier("profile.reportAthlete")
                            Button(appState.isBlocked(profile.id) ? "Unblock athlete" : "Block athlete", role: appState.isBlocked(profile.id) ? nil : .destructive) {
                                appState.setBlocked(profile.id, blocked: !appState.isBlocked(profile.id))
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
            await refreshProfileData()
        }
        .onChange(of: appState.repository.liftsRevision) { _, _ in
            refreshVisibleProfileLifts()
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
    }

    private func refreshProfileData() async {
        if isCurrentUser {
            async let lifts: Void = appState.refreshProductionLifts()
            async let ranking: Void = appState.refreshCurrentUserTotalRanking()
            _ = await (lifts, ranking)
        }
        refreshVisibleProfileLifts()
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
            refreshVisibleProfileLifts()
        }
    }
}
