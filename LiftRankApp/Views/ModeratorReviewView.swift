import AVKit
import SwiftUI

struct ModeratorReviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "Plates not visible"
    @State private var note = ""

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
        appState.pendingReviewLifts
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(pending.prefix(12)) { lift in reviewCard(lift) }
                            if pending.isEmpty {
                                ContentUnavailableView("No pending lifts", systemImage: "checkmark.seal.fill", description: Text("All demo submissions have been reviewed."))
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

    private func reviewCard(_ lift: LiftSubmission) -> some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(lift.exerciseName)
                            .font(.headline)
                        Text("\(MeasurementFormatting.recordedLiftSetTextWithX(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions)) - \(MeasurementFormatting.formatWeight(lift.estimatedOneRepMax)) lb max")
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
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
