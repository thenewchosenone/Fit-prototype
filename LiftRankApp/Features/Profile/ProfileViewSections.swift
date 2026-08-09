import SwiftUI

extension ProfileView {
    var featureBody: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summary(profileLifts: visibleProfileLifts)
                    recentSubmissions(profileLifts: visibleProfileLifts)
                    ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser, prefilteredLifts: visibleProfileLifts)
                    athleteDetails(profileLifts: visibleProfileLifts)
                }
                .padding()
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshProfileData()
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
        .alert("Permanently delete submission?", isPresented: Binding(
            get: { submissionPendingDeletion != nil },
            set: { if !$0 { submissionPendingDeletion = nil } }
        ), presenting: submissionPendingDeletion) { lift in
            Button("Cancel", role: .cancel) {
                submissionPendingDeletion = nil
            }
            Button("Delete permanently", role: .destructive) {
                Task { await deleteSubmission(lift) }
            }
        } message: { lift in
            Text("Delete \(lift.exerciseName)? This permanently removes the submission and cannot be undone.")
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
        let error = await appState.deleteEvidenceFreeSubmission(lift)
        isDeletingSubmission = false
        if let error {
            submissionDeletionError = error
        } else {
            refreshVisibleProfileLifts()
        }
    }
}
