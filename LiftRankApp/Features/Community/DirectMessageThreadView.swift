import SwiftUI

struct DirectMessageThreadView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let thread: DirectMessageThread
    @State private var draftMessage = ""
    @State private var reportTarget: DirectMessage?
    @State private var deleteTarget: DirectMessage?
    @State private var showingDeleteConversation = false

    private var currentThread: DirectMessageThread {
        appState.messageThreads.first { $0.id == thread.id } ?? thread
    }

    private var participant: UserProfile? {
        appState.otherParticipant(in: currentThread)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    conversationHeader

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            let messages = appState.messages(for: currentThread)
                            if messages.isEmpty {
                                emptyConversation
                            } else {
                                ForEach(messages) { message in
                                    messageBubble(message)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)

                    composer
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $reportTarget) { message in
                ReportMessageView(message: message)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Delete this message?",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Message", role: .destructive) {
                    if let deleteTarget {
                        appState.deleteMessage(deleteTarget)
                    }
                    deleteTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                Text("This message will be permanently removed from the conversation.")
            }
            .confirmationDialog(
                "Delete this conversation?",
                isPresented: $showingDeleteConversation,
                titleVisibility: .visible
            ) {
                Button("Delete Conversation", role: .destructive) {
                    appState.deleteMessageThread(currentThread)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every message in this conversation from your inbox.")
            }
        }
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close conversation")

            if let participant {
                ProfileAvatar(profile: participant, size: 44)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(participant?.displayName ?? "Messages")
                    .font(.headline.weight(.black))
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.liftGreen)
                        .frame(width: 7, height: 7)
                    Text(participant.map { "@\($0.username)" } ?? "LiftRank member")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }

            Spacer()

            Menu {
                if let participant {
                    Button {
                        appState.selectedProfile = participant
                    } label: {
                        Label("View Profile", systemImage: "person.crop.circle")
                    }
                }
                Button(role: .destructive) {
                    showingDeleteConversation = true
                } label: {
                    Label("Delete Conversation", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Conversation options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.liftBackground.opacity(0.96))
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06))
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                Haptics.light()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(Color.liftCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.liftBlue)
            .accessibilityLabel("Message attachments")

            TextField("Write a message…", text: $draftMessage, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.liftCard)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }

            Button {
                appState.sendMessage(in: currentThread, body: draftMessage)
                draftMessage = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftBackground)
                    .frame(width: 44, height: 44)
                    .background(Color.liftBlue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
    }

    private var emptyConversation: some View {
        VStack(spacing: 14) {
            if let participant {
                ProfileAvatar(profile: participant, size: 76)
            }
            Text("Start a conversation")
                .font(.title3.weight(.black))
            Text("Send a message to \(participant?.displayName ?? "this lifter") about training, rankings, or your next gym session.")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal, 28)
    }

    private func messageBubble(_ message: DirectMessage) -> some View {
        let isCurrentUser = message.senderID == appState.currentProfile.id
        return HStack(alignment: .bottom) {
            if isCurrentUser { Spacer(minLength: 42) }

            if !isCurrentUser, let participant {
                ProfileAvatar(profile: participant, size: 28)
                    .padding(.bottom, 18)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 5) {
                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(isCurrentUser ? Color.liftBackground : Color.liftText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(isCurrentUser ? Color.liftBlue : Color.liftCardRaised)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: isCurrentUser ? 18 : 5,
                            bottomTrailingRadius: isCurrentUser ? 5 : 18,
                            topTrailingRadius: 18
                        )
                    )

                HStack(spacing: 6) {
                    Text(LiftTimeFormatter.messageTime(message.createdAt))
                    if message.isReported {
                        Label("Reported", systemImage: "flag.fill")
                    }
                    if isCurrentUser {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
            }
            .contextMenu {
                Button(role: .destructive) {
                    deleteTarget = message
                } label: {
                    Label("Delete Message", systemImage: "trash")
                }
                if !isCurrentUser {
                    Button(role: .destructive) {
                        reportTarget = message
                    } label: {
                        Label("Report Message", systemImage: "exclamationmark.bubble")
                    }
                }
            }

            if !isCurrentUser { Spacer(minLength: 42) }
        }
    }
}

struct ReportMessageView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let message: DirectMessage
    @State private var reason: MessageReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Reason") {
                        Picker("Reason", selection: $reason) {
                            ForEach(MessageReportReason.allCases) { reason in
                                Text(reason.rawValue).tag(reason)
                            }
                        }
                    }
                    Section("Message") {
                        Text(message.body)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Section("Optional note") {
                        TextField("Add context for moderators", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.reportMessage(message, reason: reason, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}
