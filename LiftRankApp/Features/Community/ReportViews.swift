import SwiftUI

struct ReportLiftView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let lift: LiftSubmission
    @State private var reason = LiftReportReason.harassment
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Picker("Reason", selection: $reason) {
                        ForEach(LiftReportReason.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.liftRed)
                    }
                    Button(isSubmitting ? "Submitting…" : "Submit Report") {
                        isSubmitting = true
                        errorMessage = nil
                        Task {
                            if await appState.competitionStore.report(lift, reason: reason, note: note) {
                                Haptics.warning()
                                dismiss()
                            } else {
                                errorMessage = "The report could not be submitted. Try again."
                                isSubmitting = false
                            }
                        }
                    }
                    .accessibilityIdentifier("report.submit")
                    .disabled(isSubmitting)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report Lift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ReportProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    @State private var reason = ProfileReportReason.harassment
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section {
                        Text("Report @\(profile.username) for content or behavior that violates the Lift Rivals community standards.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Picker("Reason", selection: $reason) {
                        ForEach(ProfileReportReason.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    TextField("Optional details", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.liftRed)
                    }
                    Button(isSubmitting ? "Submitting..." : "Submit Report") {
                        isSubmitting = true
                        errorMessage = nil
                        Task {
                            if await appState.reportProfile(profile.id, reason: reason, note: note) {
                                Haptics.warning()
                                dismiss()
                            } else {
                                errorMessage = "The report could not be submitted. Try again."
                                isSubmitting = false
                            }
                        }
                    }
                    .accessibilityIdentifier("profileReport.submit")
                    .disabled(isSubmitting)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Report Athlete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
