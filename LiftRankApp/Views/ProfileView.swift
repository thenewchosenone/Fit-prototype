import SwiftUI

enum ProfileSurface {
    case personal
    case `public`
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    let profile: UserProfile
    let surface: ProfileSurface
    var isCurrentUser: Bool { surface == .personal }
    /// Public-profile routes pass a non-owner identity so visibility filtering
    /// is evaluated exactly as it would be for another athlete.
    let viewerID: UUID?
    @State var showingPhotoManager = false
    @State var showingAthleteDetails = false
    @State var selectedProfileSection: ProfileSection = .overview
    @State var liftPresentation = ProfileLiftPresentation.empty
    @State var submissionPendingDeletion: LiftSubmission?
    @State var submissionDeletionError: String?
    @State var isDeletingSubmission = false
    @State var showingPublicPreview = false
    @State var confirmingProfileBlock = false
    @State var profileHistoryDateRange: ProfileHistoryDateRange = .allTime
    @State var profileHistoryType: ProfileHistoryType = .all
    @State var profileHistoryExercise = ""
    @State var selectedTimelineWorkout: CompletedWorkout?

    init(profile: UserProfile, surface: ProfileSurface, viewerID: UUID? = nil) {
        self.profile = profile
        self.surface = surface
        self.viewerID = viewerID
    }

    init(profile: UserProfile, isCurrentUser: Bool, viewerID: UUID? = nil) {
        self.init(profile: profile, surface: isCurrentUser ? .personal : .public, viewerID: viewerID)
    }

    var body: some View { featureBody }
}
