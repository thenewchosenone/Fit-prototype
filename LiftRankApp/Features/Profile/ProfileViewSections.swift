import SwiftUI

extension ProfileView {
    var featureBody: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summary(presentation: liftPresentation)
                    recentSubmissions(profileLifts: liftPresentation.lifts)
                    ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser, prefilteredLifts: liftPresentation.lifts)
                    athleteDetails(presentation: liftPresentation)
                }
                .padding()
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshProfileData(force: true)
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
            await refreshProfileData(force: false)
        }
        .onChange(of: appState.repository.liftsRevision) { _, _ in
            Task { await refreshVisibleProfileLifts() }
        }
    }

    private func refreshProfileData(force: Bool) async {
        if isCurrentUser {
            await appState.refreshProductionLifts(force: force)
        }
        await refreshVisibleProfileLifts()
    }
}
