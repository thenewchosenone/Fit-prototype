import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var appState: AppState
    @State var conversationDeleteTarget: DirectMessageThread?
    @State var selectedTopic: CommunityTopic = .all
    @State var gymSearch = ""
    @State var communityReportTarget: CommunityReportDraft?

    var body: some View { featureBody }
}
