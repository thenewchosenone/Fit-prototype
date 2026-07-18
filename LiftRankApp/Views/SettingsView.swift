import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var preferredUnit = UnitSystem.pounds
    @State private var privateProfile = false
    @State private var hideBodyweight = false
    @State private var hideExactAge = false
    @State private var hideLocation = false
    @State private var allowComments = true
    @State private var notificationPreferences = true
    @AppStorage("liftrank.appearance") private var appearance = LiftAppearance.system.rawValue
    @State private var settingsInfo: SettingsInfoPage?
    @State private var confirmingDeletion = false

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Units") {
                        Picker("Pounds or kilograms", selection: $preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                    Section("Privacy") {
                        Toggle("Private profile", isOn: $privateProfile)
                        Toggle("Hide bodyweight", isOn: $hideBodyweight)
                        Toggle("Hide exact age", isOn: $hideExactAge)
                        Toggle("Hide location", isOn: $hideLocation)
                        Toggle("Allow comments", isOn: $allowComments)
                    }
                    Section("Notifications") {
                        Toggle("Notification preferences", isOn: $notificationPreferences)
                    }
                    Section("Workout Tracking") {
                        Toggle("Automatically submit video-backed PRs", isOn: Binding(
                            get: { appState.workoutPreferences.automaticallySubmitVideoBackedPRs },
                            set: { appState.setAutomaticVideoPRSubmission($0) }
                        ))
                        Toggle("Start rest timer after completed sets", isOn: Binding(
                            get: { appState.workoutPreferences.defaultRestTimerEnabled },
                            set: {
                                appState.repository.workoutPreferences.defaultRestTimerEnabled = $0
                                appState.repository.persistWorkoutSnapshot()
                            }
                        ))
                        if appState.pendingWorkoutPRSubmissions.contains(where: { $0.state == .failed }) {
                            Button("Retry failed PR uploads") {
                                Task { await appState.retryFailedWorkoutPRSubmissions() }
                            }
                        }
                        Text("Only eligible canonical lift PRs with an attached video can be posted. The setting is off by default; all other workout records stay private.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Section("Legal and Safety") {
                        Button("About LiftRank") { settingsInfo = .about }
                        Button("Privacy notice") { settingsInfo = .privacy }
                        Button("Terms of use") { settingsInfo = .terms }
                        Button("Community rules") { settingsInfo = .communityRules }
                        Button("Fitness disclaimer") { settingsInfo = .fitnessDisclaimer }
                        Link("Send feedback", destination: URL(string: "https://github.com/thenewchosenone/Fit-prototype/issues/new")!)
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Local")
                    }
                    Section("Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(LiftAppearance.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                    }
                    Section("Developer") {
                        if appState.isDemoMode {
                            Button("Reset Demo Data", role: .destructive) {
                                Haptics.warning()
                                appState.profilePhotoStore.removeNamespace(.demo)
                                appState.repository.reset()
                            }
                        } else {
                            Text("Authenticated profile and social data are stored by Supabase. Workout data remains local in this beta.")
                                .font(.caption)
                        }
                    }
                    Section {
                        Button("Sign Out", role: .destructive) {
                            dismiss()
                            Task { await appState.signOutAccount() }
                        }
                        if appState.isAuthenticated && !appState.isDemoMode {
                            Button("Delete Account", role: .destructive) { confirmingDeletion = true }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .onAppear {
                let profile = appState.currentProfile
                preferredUnit = profile.preferredUnit
                privateProfile = false
                hideBodyweight = profile.hideBodyweight
                hideExactAge = profile.hideExactAge
                hideLocation = profile.hideCity
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        persistProfileSettings()
                        dismiss()
                    }
                }
            }
            .sheet(item: $settingsInfo) { page in
                SettingsInfoView(page: page)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Permanently delete your LiftRank account?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button("Delete Account and Local Data", role: .destructive) {
                    Task {
                        await appState.deleteAuthenticatedAccount()
                        if !appState.isAuthenticated { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("For security, the server requires a recently authenticated session. Your account data, workout backup, and local training data will be removed. This cannot be undone.")
            }
        }
    }

    private func persistProfileSettings() {
        var profile = appState.currentProfile
        profile.preferredUnit = preferredUnit
        profile.hideBodyweight = hideBodyweight
        profile.hideExactAge = hideExactAge
        profile.hideCity = hideLocation
        if privateProfile {
            profile.hideExactAge = true
            profile.hideBodyweight = true
            profile.hideCity = true
            profile.hideGym = true
        }
        appState.updateProfile(profile)
    }
}

enum SettingsInfoPage: String, Identifiable {
    case about
    case privacy
    case terms
    case communityRules
    case fitnessDisclaimer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about: return "About LiftRank"
        case .privacy: return "Privacy notice"
        case .terms: return "Terms of use"
        case .communityRules: return "Community rules"
        case .fitnessDisclaimer: return "Fitness disclaimer"
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .about:
            return [
                ("LiftRank", "LiftRank is a competitive strength platform for tracking workouts, recording true one-rep PRs, and comparing eligible lifts."),
                ("Evidence labels", "Video-backed means a lift has attached video evidence. It does not mean LiftRank approved the athlete’s technique."),
                ("Feedback", "Report bugs, confusing flows, and missing gym or exercise data through the feedback link in Settings.")
            ]
        case .privacy: return documentSections(.privacy)
        case .terms: return documentSections(.terms)
        case .communityRules: return documentSections(.communityRules)
        case .fitnessDisclaimer: return documentSections(.fitnessDisclaimer)
        }
    }

    private func documentSections(_ kind: LegalDocumentKind) -> [(String, String)] {
        LegalDocument.current.first(where: { $0.kind == kind })?.sections.map { ($0.title, $0.body) } ?? []
    }
}

struct LegalAcceptanceView: View {
    @EnvironmentObject private var appState: AppState
    @State private var acknowledged: Set<LegalDocumentKind> = []
    @State private var expanded: LegalDocumentKind?

    private var documents: [LegalDocument] {
        appState.outstandingLegalDocuments.isEmpty ? LegalDocument.current : appState.outstandingLegalDocuments
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Before you compete")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text("Review and accept the current policies. We record each document version so future changes can be shown clearly.")
                        .foregroundStyle(Color.liftMuted)

                    ForEach(documents) { document in
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    withAnimation(.snappy) { expanded = expanded == document.kind ? nil : document.kind }
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(document.title).font(.headline)
                                            Text(document.summary).font(.subheadline).foregroundStyle(Color.liftMuted)
                                            Text("Version \(document.version)").font(.caption2).foregroundStyle(Color.liftMuted)
                                        }
                                        Spacer()
                                        Image(systemName: expanded == document.kind ? "chevron.up" : "chevron.down")
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Shows the full document")

                                if expanded == document.kind {
                                    ForEach(document.sections, id: \.title) { section in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(section.title).font(.subheadline.weight(.bold))
                                            Text(section.body).font(.subheadline).foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                }

                                Toggle("I have read and accept \(document.title)", isOn: Binding(
                                    get: { acknowledged.contains(document.kind) },
                                    set: { accepted in
                                        if accepted { acknowledged.insert(document.kind) }
                                        else { acknowledged.remove(document.kind) }
                                    }
                                ))
                                .tint(Color.liftBlue)
                            }
                        }
                    }

                    if let message = appState.accountMessage {
                        Text(message).font(.caption).foregroundStyle(Color.liftRed)
                    }

                    PrimaryButton(title: appState.accountOperationInProgress ? "Saving…" : "Accept and Continue", symbolName: "checkmark.shield.fill") {
                        Task { await appState.acceptCurrentLegalDocuments() }
                    }
                    .disabled(appState.accountOperationInProgress || documents.contains { !acknowledged.contains($0.kind) })

                    Button("Sign out") { Task { await appState.signOutAccount() } }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(20)
            }
        }
    }
}

struct SettingsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let page: SettingsInfoPage

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(page.sections, id: \.0) { title, body in
                            LiftCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(title)
                                        .font(.headline)
                                    Text(body)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.liftMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
