import SwiftUI

struct GymDetailView: View {
    @EnvironmentObject private var appState: AppState
    let gym: Gym
    @State private var showingMembershipLimit = false

    private var joined: Bool {
        appState.isGymJoined(gym)
    }

    private var isPrimaryGym: Bool {
        appState.isPrimaryGym(gym)
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(gym.name)
                        .font(.largeTitle.bold())
                    Text("\(gym.city), \(gym.state)")
                        .foregroundStyle(Color.liftMuted)
                    PrimaryButton(
                        title: isPrimaryGym ? "Primary Gym" : (joined ? "Leave Gym" : "Join Gym"),
                        symbolName: isPrimaryGym ? "star.fill" : (joined ? "minus.circle" : "plus.circle")
                    ) {
                        if isPrimaryGym {
                            Haptics.light()
                        } else if joined {
                            appState.leaveGym(gym)
                        } else if !appState.joinGym(gym) {
                            showingMembershipLimit = true
                        }
                    }
                    .disabled(isPrimaryGym)
                    if joined && !isPrimaryGym {
                        Button {
                            appState.setPrimaryGym(gym)
                        } label: {
                            Label("Make Primary Gym", systemImage: "star")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.liftBlue)
                    }
                    Text("You can belong to up to \(AppState.maximumJoinedGyms) gyms. Your primary gym counts toward this limit.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Members", value: "\(gym.memberCount)", subtitle: "Local lifters")
                        MetricCard(title: "Verified lifts", value: "\(gym.verifiedLiftCount)", subtitle: "Approved submissions", tint: .liftGreen)
                        MetricCard(title: "Bench record", value: "365 lb", subtitle: "Andre 4", tint: .liftGold)
                        MetricCard(title: "Squat record", value: "505 lb", subtitle: "Maya 8", tint: .liftGold)
                        MetricCard(title: "Deadlift record", value: "565 lb", subtitle: "Lifter 4", tint: .liftGold)
                        MetricCard(title: "Pound-for-pound", value: "3.1x", subtitle: "Sofia 12", tint: .liftBlue)
                    }
                    SectionHeader(title: "Top lifters")
                    ForEach(appState.leaderboardEntries().prefix(5)) { entry in
                        LeaderboardRow(entry: entry)
                    }
                    SectionHeader(
                        title: "Gym discussion",
                        actionTitle: joined ? "New post" : nil,
                        action: joined ? { appState.beginForumComposer(gymID: gym.id) } : nil
                    )
                    let gymPosts = appState.forumPosts
                        .filter { $0.destination.gymID == gym.id }
                        .sorted { $0.isPinned != $1.isPinned ? $0.isPinned : $0.createdAt > $1.createdAt }
                    if gymPosts.isEmpty {
                        LiftEmptyState(
                            title: "No gym discussions yet",
                            message: joined ? "Start the first local discussion." : "Join this gym to start a discussion.",
                            symbolName: "bubble.left.and.bubble.right"
                        )
                    } else {
                        ForEach(gymPosts) { ForumPostCard(postID: $0.id) }
                    }
                }
                .padding()
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Gym limit reached", isPresented: $showingMembershipLimit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Leave one of your secondary gyms before joining another. Members can belong to a maximum of \(AppState.maximumJoinedGyms) gyms.")
            }
        }
    }
}

struct CreateThreadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Thread") {
                        TextField("Title", text: $title)
                        TextField("What do you want to discuss?", text: $bodyText, axis: .vertical)
                            .lineLimit(4...8)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Thread")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        appState.createThread(title: title, body: bodyText)
                        dismiss()
                    }
                    .disabled(!canPost)
                }
            }
        }
    }
}

struct RequestGymView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var note = ""
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Gym") {
                        TextField("Gym name", text: $name)
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("Why should this gym be added?", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Request Gym")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.requestGym(name: name, city: city, state: state, note: note)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}
