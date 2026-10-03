import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    let profile: UserProfile
    let isCurrentUser: Bool
    @State var showingPhotoManager = false
    @State var showingAthleteDetails = false
    @State var selectedProfileSection: ProfileSection = .overview
    @State var liftPresentation = ProfileLiftPresentation.empty
    @State var submissionPendingDeletion: LiftSubmission?
    @State var submissionDeletionError: String?
    @State var isDeletingSubmission = false

    var body: some View { featureBody }
}
