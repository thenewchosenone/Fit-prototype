import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    let profile: UserProfile
    let isCurrentUser: Bool
    @State var showingPhotoManager = false
    @State var showingAthleteDetails = false

    var body: some View { featureBody }
}
