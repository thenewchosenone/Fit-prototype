import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var showingNotifications = false
    @State var showingStreak = false
    @State var showingActiveWorkout = false
    @State var showingAwards = false
    @State var showingGyms = false
    @State var selectedBodyweightEntry: BodyweightEntry?
    @State var selectedRecentPR: LiftSubmission?
    @State var homeContentWidth: CGFloat = 0

    var body: some View { featureBody }
}
