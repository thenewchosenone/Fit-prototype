import SwiftUI

struct ForumModerationCenterView: View {
    @EnvironmentObject private var appState: AppState
    @State private var segment = "Reports"

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Picker("Moderation section", selection: $segment) {
                        Text("Reports").tag("Reports")
                        Text("Requests").tag("Requests")
                        Text("Audit").tag("Audit")
                    }
                    .pickerStyle(.segmented)

                    if segment == "Reports" {
                        reports
                    } else if segment == "Requests" {
                        requests
                    } else {
                        audit
                    }

                    Color.clear.frame(height: 60)
                }
                .padding(16)
            }
        }
        .navigationTitle("Forum Moderation")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var reports: some View {
        let openReports = appState.forumReports.filter { $0.status == .open }
        if openReports.isEmpty {
            LiftEmptyState(
                title: "Queue clear",
                message: "There are no open forum reports.",
                symbolName: "checkmark.shield.fill"
            )
        }

        ForEach(openReports) { report in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(report.targetType.rawValue, systemImage: "flag.fill")
                        .foregroundStyle(Color.liftRed)
                    Spacer()
                    Text(LiftTimeFormatter.shortDateTime(report.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Text(report.reason.rawValue).font(.headline)
                if !report.note.isEmpty {
                    Text(report.note).font(.subheadline).foregroundStyle(Color.liftMuted)
                }
                HStack {
                    Button("Dismiss") { appState.resolveForumReport(report.id, dismiss: true) }
                        .buttonStyle(.bordered)
                    Button("Resolve") { appState.resolveForumReport(report.id, dismiss: false) }
                        .buttonStyle(.borderedProminent)
                    if report.targetType == .post {
                        Button("Remove", role: .destructive) {
                            appState.moderateForumPost(report.targetID, action: .remove, reason: "Removed after report")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.caption.weight(.bold))
            }
            .padding(14)
            .liftSurface(radius: 13)
        }
    }

    @ViewBuilder
    private var requests: some View {
        let pending = appState.forumJoinRequests.filter {
            $0.status == "Pending" && appState.canModerateForumCommunity($0.communityID)
        }
        if pending.isEmpty {
            LiftEmptyState(
                title: "No membership requests",
                message: "Restricted-community requests appear here.",
                symbolName: "person.badge.checkmark"
            )
        }

        ForEach(pending) { request in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.profile(id: request.userID)?.displayName ?? "Member")
                        .font(.subheadline.weight(.bold))
                    Text(appState.forumCommunity(request.communityID)?.name ?? "Community")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button("Decline", role: .destructive) {
                    appState.resolveForumJoinRequest(request.id, approved: false)
                }
                .buttonStyle(.bordered)
                Button("Approve") { appState.resolveForumJoinRequest(request.id, approved: true) }
                    .buttonStyle(.borderedProminent)
            }
            .font(.caption.weight(.bold))
            .padding(13)
            .liftSurface(radius: 13)
        }
    }

    @ViewBuilder
    private var audit: some View {
        if appState.forumModerationActions.isEmpty {
            LiftEmptyState(
                title: "No audit history",
                message: "Moderator actions are recorded here.",
                symbolName: "list.bullet.clipboard"
            )
        }

        ForEach(appState.forumModerationActions) { action in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.fill").foregroundStyle(Color.liftBlue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.kind.rawValue).font(.subheadline.weight(.bold))
                    Text(action.reason.isEmpty ? "No reason supplied" : action.reason)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text(LiftTimeFormatter.shortDateTime(action.createdAt))
                        .font(.caption2)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
            }
            .padding(13)
            .liftSurface(radius: 13)
        }
    }
}
