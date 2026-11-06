import SwiftUI

struct HomeView: View {
    var isActiveTab = true
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var showingNotifications = false
    @State var showingStreak = false
    @State var showingAwards = false
    @State var selectedBodyweightEntry: BodyweightEntry?

    var body: some View { featureBody }
}
