import SwiftUI

struct ForumPostDetailView: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    @State private var sort: ForumCommentSort = .best
    @State private var draft = ""
    @State private var replyingTo: ForumComment?
    @State private var collapsedCommentIDs: Set<UUID> = []

    private var post: ForumPost? { appState.forumPost(postID) }
    private var commentItems: [ForumCommentThreadItem] {
        ForumCommentThreadBuilder.flattened(
            comments: appState.forumComments(for: postID, sort: sort),
            collapsedCommentIDs: collapsedCommentIDs
        )
    }

    var body: some View {
        AppBackground {
            if let post {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForumPostCard(postID: post.id, opensDetail: false)
#if DEBUG
                        if appState.isDemoMode {
                            ForumPromotedContentPreview()
                        }
#endif
                        HStack {
                            Text("Comments").font(.headline.weight(.bold))
                            Text("\(post.commentCount)").font(.caption.weight(.black)).foregroundStyle(Color.liftBlue)
                            Spacer()
                            Menu(sort.rawValue) {
                                ForEach(ForumCommentSort.allCases) { option in Button(option.rawValue) { sort = option } }
                            }
                            .font(.caption.weight(.bold))
                        }
                        if commentItems.isEmpty {
                            LiftEmptyState(title: "Start the discussion", message: "Be the first member to comment.", symbolName: "bubble.left")
                        } else {
                            ForEach(commentItems) { item in
                                ThreadedForumCommentRow(
                                    item: item,
                                    onCollapse: {
                                        if !collapsedCommentIDs.insert(item.id).inserted { collapsedCommentIDs.remove(item.id) }
                                    },
                                    onReply: { replyingTo = $0 }
                                )
                            }
                        }
                        Color.clear.frame(height: 86)
                    }
                    .padding(16)
                }
                .safeAreaInset(edge: .bottom) { composer(post) }
                .navigationTitle(post.destination.communityID.flatMap { appState.forumCommunity($0)?.name } ?? "Discussion")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Post unavailable", systemImage: "text.bubble")
            }
        }
    }

    private func composer(_ post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let replyingTo {
                HStack {
                    Text("Replying to \(replyingTo.authorName)").font(.caption).foregroundStyle(Color.liftBlue)
                    Spacer(); Button { self.replyingTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField(post.isLocked ? "Comments are locked" : "Add a comment", text: $draft, axis: .vertical)
                    .lineLimit(1...5).padding(.horizontal, 12).frame(minHeight: 44).background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(post.isLocked || !canComment(post))
                Button {
                    if appState.addForumComment(postID: post.id, parentCommentID: replyingTo?.id, body: draft) != nil {
                        draft = ""; replyingTo = nil
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Color.liftBlue).frame(width: 44, height: 44)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || post.isLocked || !canComment(post))
            }
            if !canComment(post), let communityID = post.destination.communityID {
                Button("Join this community to comment") { _ = appState.joinForumCommunity(communityID) }
                    .font(.caption.weight(.bold)).foregroundStyle(Color.liftBlue)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9).background(.ultraThinMaterial)
    }

    private func canComment(_ post: ForumPost) -> Bool {
        appState.canContributeToForumPost(post)
    }
}

private struct ForumPromotedContentPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 36, height: 36)
                    .background(Color.liftBlue.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Advertiser")
                        .font(.caption.weight(.bold))
                    Text("Promoted")
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Text("Ad")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.liftMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay {
                        Capsule().stroke(Color.liftSeparator, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Sponsored content placement")
                    .font(.headline.weight(.bold))
                Text("Reserved for a clearly labeled image, video, or native campaign relevant to strength athletes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        LinearGradient(
                            colors: [Color.liftBlue.opacity(0.2), Color.liftCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: index == 1 ? "play.rectangle.fill" : "photo.fill")
                            .font(.title3)
                            .foregroundStyle(Color.liftBlue.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            HStack {
                Text("sponsor.example")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                Spacer()
                Text("Learn more")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.liftField)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.liftCard.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.liftSeparator, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Advertisement preview. Sponsored content placement.")
        .accessibilityIdentifier("forum.ad.postDetail")
    }
}

private struct ThreadedForumCommentRow: View {
    let item: ForumCommentThreadItem
    let onCollapse: () -> Void
    let onReply: (ForumComment) -> Void

    private var visualDepth: Int { min(item.depth, 4) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if visualDepth > 0 {
                HStack(spacing: 0) {
                    ForEach(0..<visualDepth, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.liftSeparator.opacity(0.9))
                            .frame(width: 1)
                            .frame(width: 18)
                    }
                }
                .accessibilityHidden(true)
            }
            ForumCommentRow(
                comment: item.comment,
                onReply: onReply,
                onCollapse: item.descendantCount > 0 ? onCollapse : nil,
                replyCount: item.descendantCount
            )
        }
        .padding(.top, item.depth == 0 ? 6 : 0)
        .accessibilityIdentifier("forum.comment.depth.\(item.depth)")
    }
}

private struct ForumCommentRow: View {
    @EnvironmentObject private var appState: AppState
    let comment: ForumComment
    let onReply: (ForumComment) -> Void
    var onCollapse: (() -> Void)?
    var replyCount = 0
    @State private var reportTarget: ForumReportDraft?
    @State private var confirmDelete = false

    private var post: ForumPost? { appState.forumPost(comment.postID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(comment.authorName).font(.caption.weight(.bold))
                Text("• \(LiftTimeFormatter.relativeNoSeconds(from: comment.createdAt))").font(.caption2).foregroundStyle(Color.liftMuted)
                if comment.editedAt != nil { Text("edited").font(.caption2).foregroundStyle(Color.liftMuted) }
                Spacer()
                Menu {
                    Button("Report Comment", role: .destructive) {
                        reportTarget = ForumReportDraft(id: comment.id, type: .comment, title: "Comment by \(comment.authorName)")
                    }
                    if comment.authorID == appState.currentProfile.id {
                        Button("Delete Comment", role: .destructive) { confirmDelete = true }
                    }
                    if let communityID = post?.destination.communityID,
                       appState.canModerateForumCommunity(communityID) {
                        Divider()
                        Button(comment.removedAt == nil ? "Remove Comment" : "Restore Comment", role: comment.removedAt == nil ? .destructive : nil) {
                            appState.moderateForumComment(comment.id, action: comment.removedAt == nil ? .remove : .restore)
                        }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 32, height: 32) }
            }
            Text(comment.removedAt == nil ? comment.body : "[comment removed]")
                .font(.subheadline).foregroundStyle(comment.removedAt == nil ? Color.liftText : Color.liftMuted)
            HStack(spacing: 15) {
                ForumVoteControl(
                    score: comment.voteScore,
                    selection: comment.votes[appState.currentProfile.id],
                    enabled: post.map(appState.canContributeToForumPost) ?? false,
                    onVote: { appState.voteForumComment(comment.id, vote: $0) }
                )
                if comment.removedAt == nil {
                    Button("Reply") { onReply(comment) }
                }
                if let onCollapse, replyCount > 0 {
                    Button("\(replyCount) replies") { onCollapse() }
                }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
        }
        .padding(12).background(Color.liftCard.opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $reportTarget) { target in
            ForumReportSheet(target: target, communityID: post?.destination.communityID)
                .environmentObject(appState).presentationDetents([.medium])
        }
        .confirmationDialog("Delete this comment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Comment", role: .destructive) { appState.deleteForumComment(comment.id) }
            Button("Cancel", role: .cancel) {}
        }
    }
}
