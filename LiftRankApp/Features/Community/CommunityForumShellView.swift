import SwiftUI

struct CommunityForumShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                header
                tabs
                Group {
                    switch appState.selectedCommunitySegment {
                    case "Explore": ForumExploreView()
                    case "Inbox": ForumInboxView()
                    default: ForumHomeView()
                    }
                }
                .environmentObject(appState)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ForumRoute.self) { route in
                switch route {
                case .community(let id): ForumCommunityDetailView(communityID: id)
                case .post(let id): ForumPostDetailView(postID: id)
                case .gym(let id):
                    if let gym = appState.gyms.first(where: { $0.id == id }) { GymDetailView(gym: gym) }
                    else { ContentUnavailableView("Gym unavailable", systemImage: "building.2") }
                case .gyms: ForumGymDirectoryView()
                case .saved: ForumCollectionView(mode: .saved)
                case .watched: ForumCollectionView(mode: .watched)
                case .moderation: ForumModerationCenterView()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Community")
                    .font(.title2.weight(.black))
                Text("Strength forums")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            Spacer()
            if appState.isForumStaff {
                Button { appState.communityPath.append(.moderation) } label: {
                    Image(systemName: "shield.lefthalf.filled")
                        .frame(width: 44, height: 44)
                        .background(Color.liftCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Forum moderation")
            }
            Button { appState.beginForumComposer() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Create a forum post")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(["Home", "Explore", "Inbox"], id: \.self) { tab in
                Button {
                    appState.selectedCommunitySegment = tab
                    Haptics.light()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Text(tab)
                                .font(.subheadline.weight(appState.selectedCommunitySegment == tab ? .bold : .medium))
                            if tab == "Inbox", appState.unreadForumNotificationCount + appState.incomingFriendRequests.count > 0 {
                                Text("\(appState.unreadForumNotificationCount + appState.incomingFriendRequests.count)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.liftRed)
                                    .clipShape(Capsule())
                            }
                        }
                        Rectangle()
                            .fill(appState.selectedCommunitySegment == tab ? Color.liftBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(appState.selectedCommunitySegment == tab ? .white : Color.liftMuted)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.liftSeparator).frame(height: 1) }
    }
}
