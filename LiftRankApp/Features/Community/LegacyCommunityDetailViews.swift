import SwiftUI

struct CommunityThreadDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let thread: CommunityThread
    @State private var replyText = ""
    @State private var reportTarget: CommunityReportDraft?

    private var currentThread: CommunityThread {
        appState.currentThread(thread)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(currentThread.kind.rawValue, systemImage: currentThread.kind == .gym ? "building.2.fill" : "bubble.left.and.bubble.right.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.liftBlue)
                                    if currentThread.isLocked {
                                        Label("Locked", systemImage: "lock.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.liftGold)
                                    }
                                    Text(currentThread.title)
                                        .font(.title2.bold())
                                    if !currentThread.body.isEmpty {
                                        Text(currentThread.body)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                    HStack {
                                        Button {
                                            appState.voteThread(currentThread, vote: appState.threadVote(for: currentThread) == .up ? nil : .up)
                                        } label: {
                                            Label("Up", systemImage: appState.threadVote(for: currentThread) == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftGreen)
                                        Text("\(currentThread.voteScore)")
                                            .font(.headline.weight(.black))
                                            .foregroundStyle(currentThread.voteScore < 0 ? Color.liftRed : Color.liftGreen)
                                        Button {
                                            appState.voteThread(currentThread, vote: appState.threadVote(for: currentThread) == .down ? nil : .down)
                                        } label: {
                                            Label("Down", systemImage: appState.threadVote(for: currentThread) == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftRed)
                                        Label("\(currentThread.replyCount) comments", systemImage: "bubble.left")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }

                            SectionHeader(title: "Comments")
                            let replies = appState.replies(for: currentThread)
                            if replies.isEmpty {
                                emptyThreadCommentCard
                            } else {
                                ForEach(replies) { reply in
                                    threadReplyCard(reply)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    commentComposer
                }
            }
            .navigationTitle("Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            reportTarget = CommunityReportDraft(id: currentThread.id, type: .thread, title: currentThread.title)
                        } label: {
                            Label("Report Thread", systemImage: "flag")
                        }
                        if appState.isForumStaff {
                            Button(currentThread.isLocked ? "Unlock Thread" : "Lock Thread") {
                                appState.moderateThread(currentThread, operation: currentThread.isLocked ? .unlock : .lock)
                            }
                            if currentThread.removedAt == nil {
                                Button(role: .destructive) {
                                    appState.moderateThread(currentThread, operation: .remove, reason: "Removed from community.")
                                } label: {
                                    Label("Remove Thread", systemImage: "trash")
                                }
                            } else {
                                Button("Restore Thread") {
                                    appState.moderateThread(currentThread, operation: .restore)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportCommunityView(target: target)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
        }
    }

    private var emptyThreadCommentCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("No comments yet")
                    .font(.headline)
                Text("Start the conversation with a reply.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func threadReplyCard(_ reply: CommunityThreadReply) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(reply.authorName)
                        .font(.headline)
                    Spacer()
                    Text(LiftTimeFormatter.relativeNoSeconds(from: reply.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text(reply.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                HStack(spacing: 10) {
                    Button {
                        appState.voteReply(reply, vote: appState.replyVote(for: reply) == .up ? nil : .up)
                    } label: {
                        Image(systemName: appState.replyVote(for: reply) == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    }
                    Text("\(reply.voteScore)")
                        .font(.caption.weight(.black))
                    Button {
                        appState.voteReply(reply, vote: appState.replyVote(for: reply) == .down ? nil : .down)
                    } label: {
                        Image(systemName: appState.replyVote(for: reply) == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        reportTarget = CommunityReportDraft(id: reply.id, type: .reply, title: "Reply by \(reply.authorName)")
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .buttonStyle(.plain)
            }
        }
    }

    private var commentComposer: some View {
        HStack(spacing: 10) {
            TextField(currentThread.isLocked ? "This thread is locked" : "Add a comment", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            Button {
                appState.addReply(to: currentThread, body: replyText)
                replyText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(LiftCompactProminentButtonStyle())
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .disabled(currentThread.isLocked || currentThread.removedAt != nil || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Post comment")
        }
        .padding()
        .background(Color.liftBackground)
    }
}

struct ActivityDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let activity: ActivityItem
    @State private var commentText = ""

    private var currentActivity: ActivityItem {
        appState.currentActivity(activity)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            LiftCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        ProfileAvatar(profile: currentActivity.profile, size: 48)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(currentActivity.title)
                                                .font(.title3.bold())
                                            Text(LiftTimeFormatter.relativeNoSeconds(from: currentActivity.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                    Text(currentActivity.detail)
                                        .foregroundStyle(Color.liftMuted)
                                    HStack {
                                        Button {
                                            appState.toggleActivityLike(currentActivity)
                                        } label: {
                                            Label(currentActivity.isLiked ? "Supported" : "Support", systemImage: currentActivity.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(Color.liftBlue)
                                        Label("\(currentActivity.likeCount) likes", systemImage: "hand.thumbsup")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                        Label("\(max(currentActivity.commentCount, appState.comments(for: currentActivity).count)) comments", systemImage: "bubble.left")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }

                            SectionHeader(title: "Comments")
                            let comments = appState.comments(for: currentActivity)
                            if comments.isEmpty {
                                emptyActivityCommentCard
                            } else {
                                ForEach(comments) { comment in
                                    activityCommentCard(comment)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    activityComposer
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: activity.id) {
                await appState.refreshComments(for: activity)
            }
        }
    }

    private var emptyActivityCommentCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("No comments yet")
                    .font(.headline)
                Text("Add the first comment.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activityCommentCard(_ comment: ActivityComment) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(comment.authorName)
                        .font(.headline)
                    Spacer()
                    Text(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text(comment.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private var activityComposer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.liftField)
                .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
            Button {
                appState.addComment(to: currentActivity, body: commentText)
                commentText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(LiftCompactProminentButtonStyle())
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Post comment")
        }
        .padding()
        .background(Color.liftBackground)
    }
}

struct ReportCommunityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let target: CommunityReportDraft
    @State private var reason: CommunityReportReason = .spam
    @State private var note = ""

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Content") {
                        Text(target.title)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Section("Reason") {
                        Picker("Reason", selection: $reason) {
                            ForEach(CommunityReportReason.allCases) { reason in
                                Text(reason.rawValue).tag(reason)
                            }
                        }
                    }
                    Section("Optional note") {
                        TextField("Add context for moderators", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report \(target.type.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.reportCommunity(targetType: target.type, targetID: target.id, reason: reason, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}
