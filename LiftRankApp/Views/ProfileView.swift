import SwiftUI

enum ProfileSurface {
    case personal
    case `public`
}

struct ProfileView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dismiss) var dismiss
    private let initialProfile: UserProfile
    var profile: UserProfile {
        guard initialProfile.id == appState.currentProfile.id else { return initialProfile }
        var current = appState.currentProfile
        if surface == .public {
            let privacy = appState.authenticatedPrivacy
            current.hideBodyweight = privacy.bodyweightAudience != .publicProfile
            current.hideExactAge = privacy.ageBandAudience != .publicProfile
            current.hideCity = privacy.locationAudience != .publicProfile
            current.hideGym = privacy.gymAudience != .publicProfile
            current.hideLiftVideos = !privacy.showLiftVideos
        }
        return current
    }
    let surface: ProfileSurface
    var isCurrentUser: Bool { surface == .personal }
    var isOwnerPublicPreview: Bool { surface == .public && initialProfile.id == appState.currentProfile.id }
    /// Public-profile routes pass a non-owner identity so visibility filtering
    /// is evaluated exactly as it would be for another athlete.
    let viewerID: UUID?
    let showsDismissButton: Bool
    var onOpenPrivacy: (() -> Void)?
    @State var showingPhotoManager = false
    @State var selectedProfileSection: ProfileSection
    @State var showsProfileDetails = false
    @State var profileProgressExerciseID = ""
    @State var liftPresentation = ProfileLiftPresentation.empty
    @State var profileLoadError: String?
    @State var sharedWorkoutStats: SharedWorkoutStats?
    @State var submissionPendingDeletion: LiftSubmission?
    @State var submissionDeletionError: String?
    @State var isDeletingSubmission = false
    @State var showingPublicPreview = false
    @State var confirmingProfileBlock = false
    @State var profileHistoryDateRange: ProfileHistoryDateRange = .allTime
    @State var profileHistoryType: ProfileHistoryType = .all
    @State var profileHistoryExercise = ""
    @State var profileSubmissionDateRange: ProfileHistoryDateRange = .allTime
    @State var profileSubmissionExercise = ""
    @State var showsAllProfileSubmissions = false
    @State var selectedTimelineWorkout: CompletedWorkout?
    @State var selectedProfileLiftHistory: TopLiftCardDestination?

    init(profile: UserProfile, surface: ProfileSurface, viewerID: UUID? = nil, initialSection: ProfileSection = .overview, showsDismissButton: Bool = true, onOpenPrivacy: (() -> Void)? = nil) {
        self.initialProfile = profile
        self.surface = surface
        self.viewerID = viewerID
        self.showsDismissButton = showsDismissButton
        self.onOpenPrivacy = onOpenPrivacy
        _selectedProfileSection = State(initialValue: initialSection)
    }

    init(profile: UserProfile, isCurrentUser: Bool, viewerID: UUID? = nil, initialSection: ProfileSection = .overview) {
        self.init(profile: profile, surface: isCurrentUser ? .personal : .public, viewerID: viewerID, initialSection: initialSection)
    }

    var body: some View { featureBody }
}
