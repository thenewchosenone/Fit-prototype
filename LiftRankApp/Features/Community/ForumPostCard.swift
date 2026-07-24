import SwiftUI

struct ForumPostCard: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    var opensDetail = true
    @State private var reportTarget: ForumReportDraft?
    @State private var editingPost: ForumPost?
    @State private var confirmDelete = false

    private var post: ForumPost? { appState.forumPost(postID) }

    var body: some View {
        if let post {
            VStack(alignment: .leading, spacing: 12) {
                postHeader(post)
                Button {
                    if opensDetail { appState.openForumPost(post.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(post.removedAt == nil ? post.title : "Post removed")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(post.removedAt == nil ? Color.liftText : Color.liftMuted)
                            .multilineTextAlignment(.leading)
                        if post.removedAt == nil {
                            if !post.body.isEmpty {
                                Text(post.body)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                    .lineLimit(opensDetail ? 4 : nil)
                                    .multilineTextAlignment(.leading)
                            }
                            postPayload(post)
                        } else {
                            Text("The author or a moderator removed this content.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                footer(post)
            }
            .padding(14)
            .liftSurface(radius: 14)
            .sheet(item: $reportTarget) { target in
                ForumReportSheet(target: target, communityID: post.destination.communityID)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .sheet(item: $editingPost) { post in
                ForumEditPostView(post: post)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Post", role: .destructive) { appState.deleteForumPost(post.id) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The discussion structure stays visible, but the text and media are removed.")
            }
        }
    }

    private func postHeader(_ post: ForumPost) -> some View {
        HStack(spacing: 9) {
            if let author = appState.profile(id: post.authorID) {
                ProfileAvatar(profile: author, size: 36)
            } else {
                Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Color.liftMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(post.authorName).font(.caption.weight(.bold))
                    Text("• \(LiftTimeFormatter.relativeNoSeconds(from: post.createdAt))")
                        .font(.caption2).foregroundStyle(Color.liftMuted)
                    if post.editedAt != nil { Text("edited").font(.caption2).foregroundStyle(Color.liftMuted) }
                }
                HStack(spacing: 5) {
                    if let communityID = post.destination.communityID, let community = appState.forumCommunity(communityID) {
                        Button(community.name) { appState.openForumCommunity(community.id) }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.liftBlue)
                    } else if let gymID = post.destination.gymID {
                        Text(appState.gyms.first(where: { $0.id == gymID })?.name ?? "Gym discussion")
                            .font(.caption2.weight(.semibold)).foregroundStyle(Color.liftBlue)
                    }
                    if let tag = post.tag {
                        Text(tag).font(.caption2.weight(.bold)).foregroundStyle(Color.liftMuted)
                    }
                }
            }
            Spacer()
            if post.isPinned { Image(systemName: "pin.fill").foregroundStyle(Color.liftGold).accessibilityLabel("Pinned") }
            Menu {
                if post.authorID == appState.currentProfile.id, post.removedAt == nil {
                    Button("Edit Post") { editingPost = post }
                    Button("Delete Post", role: .destructive) { confirmDelete = true }
                }
                Button("Report Post", role: .destructive) {
                    reportTarget = ForumReportDraft(id: post.id, type: .post, title: post.title)
                }
                if let communityID = post.destination.communityID, appState.canModerateForumCommunity(communityID) {
                    Divider()
                    Button(post.isPinned ? "Unpin" : "Pin") {
                        appState.moderateForumPost(post.id, action: post.isPinned ? .unpin : .pin)
                    }
                    Button(post.isLocked ? "Unlock" : "Lock") {
                        appState.moderateForumPost(post.id, action: post.isLocked ? .unlock : .lock)
                    }
                    Button(post.removedAt == nil ? "Remove" : "Restore", role: post.removedAt == nil ? .destructive : nil) {
                        appState.moderateForumPost(post.id, action: post.removedAt == nil ? .remove : .restore)
                    }
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 36, height: 36)
            }
            .foregroundStyle(Color.liftMuted)
        }
    }

    @ViewBuilder
    private func postPayload(_ post: ForumPost) -> some View {
        if let attachment = post.attachments.first {
            if attachment.mediaType == .image, let image = UIImage(contentsOfFile: attachment.localURL.path) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(maxWidth: .infinity, minHeight: 170, maxHeight: 260)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Label("Attached video", systemImage: "play.rectangle.fill")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.liftBlue)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.liftBackground).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        if let poll = post.poll { ForumPollView(postID: post.id, poll: poll) }
        if let liftID = post.liftID, let lift = appState.lifts.first(where: { $0.id == liftID }) {
            ForumLiftShareView(lift: lift)
        }
        if let workoutID = post.workoutID, let workout = appState.completedWorkouts.first(where: { $0.id == workoutID }) {
            ForumWorkoutShareView(workout: workout)
        }
        if let link = post.linkURL {
            Link(destination: link) {
                HStack(spacing: 10) {
                    Image(systemName: "link.circle.fill").font(.title2).foregroundStyle(Color.liftBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.host() ?? "Website").font(.subheadline.weight(.bold))
                        Text(link.absoluteString).font(.caption).foregroundStyle(Color.liftMuted).lineLimit(1)
                    }
                    Spacer(); Image(systemName: "arrow.up.right")
                }
                .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func footer(_ post: ForumPost) -> some View {
        HStack(spacing: 16) {
            ForumVoteControl(
                score: post.voteScore,
                selection: post.votes[appState.currentProfile.id],
                enabled: appState.canContributeToForumPost(post),
                onVote: { appState.voteForumPost(post.id, vote: $0) }
            )
            Button { if opensDetail { appState.openForumPost(post.id) } } label: {
                Label("\(post.commentCount)", systemImage: "bubble.left")
            }
            Button { appState.toggleForumPostSaved(post.id) } label: {
                Image(systemName: post.savedByUserIDs.contains(appState.currentProfile.id) ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(post.savedByUserIDs.contains(appState.currentProfile.id) ? Color.liftBlue : Color.liftMuted)
            }
            Button { appState.toggleForumPostWatched(post.id) } label: {
                Image(systemName: post.watchedByUserIDs.contains(appState.currentProfile.id) ? "bell.fill" : "bell")
                    .foregroundStyle(post.watchedByUserIDs.contains(appState.currentProfile.id) ? Color.liftBlue : Color.liftMuted)
            }
            Spacer()
            if post.isLocked { Label("Locked", systemImage: "lock.fill").font(.caption2.weight(.bold)) }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.liftMuted)
        .buttonStyle(.plain)
    }
}

struct ForumVoteControl: View {
    let score: Int
    let selection: CommunityVote?
    let enabled: Bool
    let onVote: (CommunityVote?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onVote(selection == .up ? nil : .up) } label: {
                Image(systemName: selection == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .foregroundStyle(selection == .up ? Color.liftGreen : Color.liftMuted)
            }
            Text("\(score)").font(.caption.weight(.black)).foregroundStyle(Color.liftText).monospacedDigit()
            Button { onVote(selection == .down ? nil : .down) } label: {
                Image(systemName: selection == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(selection == .down ? Color.liftRed : Color.liftMuted)
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vote score \(score)")
    }
}

private struct ForumPollView: View {
    @EnvironmentObject private var appState: AppState
    let postID: UUID
    let poll: ForumPoll

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(poll.options) { option in
                let isSelected = option.voterIDs.contains(appState.currentProfile.id)
                Button { appState.voteInForumPoll(postID: postID, optionID: option.id) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.liftBlue : Color.liftMuted)
                        Text(option.text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.liftText)
                        Spacer()
                        Text("\(option.voterIDs.count)").font(.caption.monospacedDigit()).foregroundStyle(Color.liftMuted)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(isSelected ? Color.liftBlue.opacity(0.14) : Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(poll.isClosed)
            }
            Text(poll.isClosed ? "Poll closed • \(poll.totalVotes) votes" : "\(poll.totalVotes) votes • You can change your vote")
                .font(.caption2).foregroundStyle(Color.liftMuted)
        }
    }
}

private struct ForumLiftShareView: View {
    let lift: LiftSubmission

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2).foregroundStyle(Color.liftGold)
                .frame(width: 46, height: 46).background(Color.liftGold.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(lift.exerciseName).font(.subheadline.weight(.bold))
                Text(MeasurementFormatting.liftSetText(weightKilograms: lift.weight, unit: lift.unit, repetitions: lift.repetitions, includeRepLabel: true))
                    .font(.headline.weight(.black))
                Text(lift.resolvedEvidenceStatus.displayName).font(.caption2).foregroundStyle(Color.liftMuted)
            }
            Spacer()
        }
        .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct ForumWorkoutShareView: View {
    let workout: CompletedWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title2).foregroundStyle(Color.liftBlue)
                .frame(width: 46, height: 46).background(Color.liftBlue.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name).font(.subheadline.weight(.bold))
                Text("\(workout.completedWorkingSets.count) working sets • \(Int(workout.duration / 60)) min")
                    .font(.caption).foregroundStyle(Color.liftMuted)
                Text("\(MeasurementFormatting.formatRecordedWeight(workout.totalVolume, unit: workout.unit)) volume")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.liftBlue)
            }
            Spacer()
        }
        .padding(12).background(Color.liftField).clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
