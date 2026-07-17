import AVKit
import SwiftUI

struct ModeratorReviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "Plates not visible"
    @State private var note = ""
    @State private var queue = "Lifts"

    private let reasons = [
        "Plates not visible",
        "Incomplete range of motion",
        "Spotter assistance",
        "Edited or unclear video",
        "Incorrect exercise",
        "Incorrect weight",
        "Duplicate submission"
    ]

    private var pending: [LiftSubmission] {
        appState.lifts.filter { $0.verificationStatus == .videoSubmitted || $0.verificationStatus == .selfReported }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    Picker("Review queue", selection: $queue) {
                        Text("Lifts").tag("Lifts")
                        Text("Forum").tag("Forum")
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    ScrollView {
                        VStack(spacing: 14) {
                            if queue == "Lifts" {
                                ForEach(pending.prefix(12)) { lift in reviewCard(lift) }
                                if pending.isEmpty {
                                    ContentUnavailableView("No pending lifts", systemImage: "checkmark.seal.fill", description: Text("All demo submissions have been reviewed."))
                                }
                            } else {
                                forumQueue
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Moderator Review")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var forumQueue: some View {
        let reports = appState.forumReports.filter { $0.status == .open }
        if reports.isEmpty {
            ContentUnavailableView("No forum reports", systemImage: "checkmark.shield.fill", description: Text("The forum moderation queue is clear."))
        }
        ForEach(reports) { report in
            LiftCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(report.targetType.rawValue, systemImage: "flag.fill").foregroundStyle(Color.liftRed)
                        Spacer()
                        Text(report.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    Text(report.reason.rawValue).font(.headline)
                    if !report.note.isEmpty { Text(report.note).font(.subheadline).foregroundStyle(Color.liftMuted) }
                    HStack {
                        Button("Dismiss") { appState.resolveForumReport(report.id, dismiss: true) }.buttonStyle(.bordered)
                        Button("Resolve") { appState.resolveForumReport(report.id, dismiss: false) }.buttonStyle(.borderedProminent)
                        if report.targetType == .post {
                            Button("Remove", role: .destructive) {
                                appState.moderateForumPost(report.targetID, action: .remove, reason: "Removed after moderator review")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.caption.weight(.bold))
                }
            }
        }
        if !appState.forumModerationActions.isEmpty {
            CompactSectionHeader(title: "Recent audit history")
            ForEach(appState.forumModerationActions.prefix(8)) { action in
                HStack {
                    Image(systemName: "shield.fill").foregroundStyle(Color.liftBlue)
                    VStack(alignment: .leading) {
                        Text(action.kind.rawValue).font(.subheadline.weight(.bold))
                        Text(action.reason.isEmpty ? "No reason supplied" : action.reason).font(.caption).foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                }
                .padding(12).liftSurface(radius: 12)
            }
        }
    }

    private func reviewCard(_ lift: LiftSubmission) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(lift.exerciseName)
                            .font(.headline)
                        Text("\(RankingCalculator.format(lift.weight)) \(lift.unit.shortLabel) x \(lift.repetitions) - \(RankingCalculator.format(lift.estimatedOneRepMax)) lb max")
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    VerificationBadge(status: lift.verificationStatus)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.35))
                        .frame(height: 170)
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.liftBlue)
                        Text("Video playback preview")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                Picker("Rejection reason", selection: $selectedReason) {
                    ForEach(reasons, id: \.self) { Text($0).tag($0) }
                }
                TextField("Moderator note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("Approve") {
                        appState.updateVerification(lift, status: .videoVerified, note: note.isEmpty ? "Video evidence approved." : note)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftGreen)
                    Button("Reject") {
                        Haptics.warning()
                        appState.updateVerification(lift, status: .rejected, note: selectedReason)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftRed)
                    Button("More evidence") {
                        appState.updateVerification(lift, status: .videoSubmitted, note: "More evidence requested: \(selectedReason)")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)
                }
            }
        }
    }
}
