import SwiftUI

extension ProfileView {
    var featureBody: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summary
                    recentSubmissions
                    ProfileLiftVideosSection(profile: profile, isCurrentUser: isCurrentUser)
                    athleteDetails
                }
                .padding()
                .padding(.bottom, isCurrentUser ? 96 : 24)
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
                        Menu {
                            Button("Edit Profile") { appState.showingEditProfile = true }
                            if appState.isForumStaff {
                                Button("Moderator Review") { appState.showingModeratorReview = true }
                            }
                            Button("Settings") { appState.showingSettings = true }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                        }
                        .accessibilityLabel("Profile options")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
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
            .confirmationDialog(
                "Cancel friend request?",
                isPresented: $showingCancelFriendRequest,
                titleVisibility: .visible
            ) {
                if let request = outgoingPendingFriendRequest {
                    Button("Cancel Request", role: .destructive) {
                        appState.cancelFriendRequest(request)
                    }
                }
                Button("Keep Request", role: .cancel) {}
            } message: {
                Text("\(profile.displayName) will no longer see your pending request. You can send another request later.")
            }
        }
    }
}
