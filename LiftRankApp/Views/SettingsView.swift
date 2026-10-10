import SwiftUI
import UIKit

enum SettingsSection: String, Hashable {
    case units
    case account
    case privacy
    case notifications
    case training
    case legal
    case appearance
    case developer
}

struct SettingsView: View {
    let initialSection: SettingsSection?
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var preferredUnit = UnitSystem.pounds
    @State private var trainingFocus: TrainingFocus?
    @State private var privacy = ProfilePrivacySettings()
    @AppStorage("liftrank.appearance") private var appearance = LiftAppearance.system.rawValue
    @State private var settingsInfo: SettingsInfoPage?
    @State private var showingPublicPreview = false
    @State private var confirmingDeletion = false
    @State private var confirmingDemoReset = false
    @State private var isSavingSettings = false
    @State private var hasLoadedDraft = false
    @State private var settingsSaveError: String?
    @State private var failedSettingsUpdate: (profile: UserProfile, privacy: ProfilePrivacySettings)?
    @Environment(\.openURL) private var openURL

    init(initialSection: SettingsSection? = nil) {
        self.initialSection = initialSection
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollViewReader { proxy in
                    Form {
                    Section("Units") {
                        Picker("Pounds or kilograms", selection: $preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                    .id(SettingsSection.units)
                    Section("Account") {
                        Button("Sign Out", role: .destructive) {
                            dismiss()
                            Task { await appState.signOutAccount() }
                        }
                        .disabled(appState.accountOperationInProgress)
                        if appState.isAuthenticated && !appState.isDemoMode {
                            Button("Delete Account", role: .destructive) {
                                appState.accountMessage = nil
                                confirmingDeletion = true
                            }
                            .disabled(appState.accountOperationInProgress)
                        }
                    }
                    .id(SettingsSection.account)
                    Section("Privacy") {
                        audiencePicker("Profile visibility", selection: $privacy.profileAudience)
                        audiencePicker("Bodyweight", selection: $privacy.bodyweightAudience)
                        audiencePicker("Age band", selection: $privacy.ageBandAudience)
                        audiencePicker("Location", selection: $privacy.locationAudience)
                        audiencePicker("Gym", selection: $privacy.gymAudience)
                        audiencePicker("Division", selection: $privacy.divisionAudience)
                        audiencePicker("Friend list", selection: $privacy.friendListAudience)
                        Toggle("Show lift videos", isOn: $privacy.showLiftVideos)
                        DisclosureGroup("How visibility works") {
                            Text("Profile visibility limits who can open your profile. Field settings apply within that audience. Achievements and unlocked badges stay private. Ratio and weight-class rankings may indirectly reveal bodyweight.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Button {
                            showingPublicPreview = true
                        } label: {
                            Label("Preview public profile", systemImage: "person.text.rectangle")
                        }
                        Text("Preview uses your saved settings.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .id(SettingsSection.privacy)
                    Section("Notifications") {
                        Button("Manage notification permissions") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settingsURL)
                            }
                        }
                        Text("Choose whether Lift Rivals can send notifications in iOS Settings.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .id(SettingsSection.notifications)
                    Section("Training") {
                        Picker("Training focus", selection: $trainingFocus) {
                            if trainingFocus == nil {
                                Text("Choose a focus").tag(nil as TrainingFocus?)
                            }
                            ForEach(TrainingFocus.allCases) { focus in
                                Text(focus.title).tag(Optional(focus))
                            }
                        }
                        .accessibilityIdentifier("settings.trainingFocus")
                        Text("Sets the first Progress view. All views and your workout history remain available.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Toggle("Automatically share workout PRs", isOn: Binding(
                            get: { appState.workoutPreferences.automaticallySubmitVideoBackedPRs },
                            set: { appState.setAutomaticVideoPRSubmission($0) }
                        ))
                        Text("With automatic sharing enabled, eligible PRs can appear publicly as self-reported without video or as video-backed when you attach one. Ordinary workout logs and private PRs stay private.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Toggle("Start rest timer after completed sets", isOn: Binding(
                            get: { appState.workoutPreferences.defaultRestTimerEnabled },
                            set: { appState.setDefaultRestTimerEnabled($0) }
                        ))
                        if appState.pendingWorkoutPRSubmissions.contains(where: { $0.state == .failed }) {
                            Button("Retry failed PR uploads") {
                                Task { await appState.retryFailedWorkoutPRSubmissions() }
                            }
                        }
                    }
                    .id(SettingsSection.training)
                    Section("Legal and Safety") {
                        Button("About Lift Rivals") { settingsInfo = .about }
                        Button("Privacy notice") { settingsInfo = .privacy }
                        Button("Terms of use") { settingsInfo = .terms }
                        Button("Fitness disclaimer") { settingsInfo = .fitnessDisclaimer }
                        Link("Support", destination: URL(string: "https://liftrivals.com/support/")!)
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Local")
                    }
                    .id(SettingsSection.legal)
                    Section("Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(LiftAppearance.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                    }
                    .id(SettingsSection.appearance)
                    if appState.isDemoMode {
                        Section("Demo") {
                            Button("Reset Demo Data", role: .destructive) {
                                confirmingDemoReset = true
                            }
                        }
                        .id(SettingsSection.developer)
                    }
                    if appState.accountOperationInProgress || appState.accountMessage != nil {
                        Section {
                            if appState.accountOperationInProgress {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(isSavingSettings ? "Saving settings…" : "Updating account…")
                                        .foregroundStyle(Color.liftMuted)
                                }
                            } else if let message = appState.accountMessage {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftRed)
                            }
                        }
                    }
                    }
                    .alert("Couldn’t save settings", isPresented: Binding(
                        get: { settingsSaveError != nil },
                        set: { if !$0 { settingsSaveError = nil } }
                    )) {
                        Button("Retry") { retrySettingsSave() }
                        Button("Cancel", role: .cancel) { failedSettingsUpdate = nil }
                    } message: {
                        Text(settingsSaveError ?? "Try again.")
                    }
                    .onAppear {
                        guard let initialSection else { return }
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo(initialSection, anchor: .top)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .onAppear {
                guard !hasLoadedDraft else { return }
                hasLoadedDraft = true
                let profile = appState.currentProfile
                privacy = appState.authenticatedPrivacy
                preferredUnit = profile.preferredUnit
                trainingFocus = profile.trainingFocus
                    ?? UserDefaults.standard.string(forKey: "liftrank.progressFocus.\(profile.id.uuidString)").flatMap(TrainingFocus.init(rawValue:))
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveSettingsAndClose()
                    } label: {
                        if isSavingSettings {
                            ProgressView().accessibilityLabel("Saving settings")
                        } else {
                            Text("Done")
                        }
                    }
                    .disabled(isSavingSettings)
                }
            }
            .sheet(item: $settingsInfo) { page in
                SettingsInfoView(page: page)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPublicPreview) {
                NavigationStack {
                    ProfileView(profile: profileSettingsUpdate().profile, surface: .public, viewerID: UUID())
                }
                .environmentObject(appState)
            }
            .alert("Permanently delete your Lift Rivals account?", isPresented: $confirmingDeletion) {
                Button(appState.accountOperationInProgress ? "Deleting..." : "Delete Account and Local Data", role: .destructive) {
                    Task {
                        await appState.deleteAuthenticatedAccount()
                        if !appState.isAuthenticated { dismiss() }
                    }
                }
                .disabled(appState.accountOperationInProgress)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(appState.hasAppleAuthorization
                    ? "For security, the server requires a recently authenticated session. Your account data, workout backup, and local training data will be removed. After deletion, also remove Lift Rivals from Settings > your name > Sign in with Apple to revoke Apple authorization. This cannot be undone."
                    : "For security, the server requires a recently authenticated session. Your account data, workout backup, and local training data will be removed. This cannot be undone.")
            }
            .confirmationDialog("Reset demo data?", isPresented: $confirmingDemoReset, titleVisibility: .visible) {
                Button("Reset Demo Data", role: .destructive) { appState.resetDemoData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears the demo profile, workouts, bodyweight history, plans, awards, and other local demo progress. It does not affect production accounts.")
            }
        }
        .interactiveDismissDisabled(isSavingSettings)
        .preferredColorScheme(LiftAppearance(rawValue: appearance)?.colorScheme)
    }

    private func profileSettingsUpdate() -> (profile: UserProfile, privacy: ProfilePrivacySettings) {
        var profile = appState.currentProfile
        profile.preferredUnit = preferredUnit
        profile.trainingFocus = trainingFocus
        profile.hideBodyweight = privacy.bodyweightAudience == .privateProfile
        profile.hideExactAge = privacy.ageBandAudience == .privateProfile
        profile.hideCity = privacy.locationAudience == .privateProfile
        profile.hideGym = privacy.gymAudience == .privateProfile
        profile.hideLiftVideos = !privacy.showLiftVideos
        profile.profileAudience = privacy.profileAudience
        return (profile, privacy)
    }

    private func saveSettingsAndClose() {
        let update = profileSettingsUpdate()
        let hasChanges = update.profile != appState.currentProfile
            || update.privacy != appState.authenticatedPrivacy
        guard hasChanges else {
            appState.showingSettings = false
            return
        }
        failedSettingsUpdate = update
        Task { await persistProfileSettings(profile: update.profile, privacy: update.privacy) }
    }

    private func retrySettingsSave() {
        guard let update = failedSettingsUpdate else { return }
        Task { await persistProfileSettings(profile: update.profile, privacy: update.privacy) }
    }

    @MainActor
    private func persistProfileSettings(profile: UserProfile, privacy: ProfilePrivacySettings) async {
        guard !isSavingSettings else { return }
        isSavingSettings = true
        defer { isSavingSettings = false }
        let saved: Bool
        saved = await appState.saveEditedProfile(profile, primaryGym: nil, privacy: privacy)
        if saved {
            failedSettingsUpdate = nil
            settingsSaveError = nil
            appState.showingSettings = false
        } else {
            settingsSaveError = appState.accountMessage ?? "Your settings weren’t saved. Try again."
        }
    }

    private func audiencePicker(_ title: String, selection: Binding<PrivacyAudience>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PrivacyAudience.allCases) { audience in
                Text(audience.label).tag(audience)
            }
        }
        .accessibilityIdentifier(title)
        .accessibilityValue(selection.wrappedValue.label)
    }
}

enum SettingsInfoPage: String, Identifiable {
    case about
    case privacy
    case terms
    case fitnessDisclaimer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about: return "About Lift Rivals"
        case .privacy: return "Privacy notice"
        case .terms: return "Terms of use"
        case .fitnessDisclaimer: return "Fitness disclaimer"
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .about:
            return [
                ("Lift Rivals", "Lift Rivals is a competitive strength platform for tracking workouts, recording true one-rep PRs, and comparing eligible lifts."),
                ("Evidence labels", "Video-backed means a lift has attached video evidence. It does not mean Lift Rivals approved the athlete’s technique."),
                ("Support", "For help, bugs, or missing gym and exercise data, open Support in Settings or email support@liftrivals.com. Never send your password, verification code, or payment information.")
            ]
        case .privacy: return documentSections(.privacy)
        case .terms: return documentSections(.terms)
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

                                Toggle(acceptanceLabel(for: document), isOn: Binding(
                                    get: { acknowledged.contains(document.kind) },
                                    set: { accepted in
                                        if accepted { acknowledged.insert(document.kind) }
                                        else { acknowledged.remove(document.kind) }
                                    }
                                ))
                                .tint(Color.liftAccentText)
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

    private func acceptanceLabel(for document: LegalDocument) -> String {
        document.kind == .privacy
            ? "I have read and acknowledge \(document.title)"
            : "I have read and accept \(document.title)"
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
