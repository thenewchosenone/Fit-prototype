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
    @State private var appearance = "Dark"
    @State private var settingsInfo: SettingsInfoPage?

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
                    Section("Prototype and Safety") {
                        Button("About this beta") { settingsInfo = .about }
                        Button("Privacy notice") { settingsInfo = .privacy }
                        Button("Terms and fitness disclaimer") { settingsInfo = .terms }
                        Link("Send feedback", destination: URL(string: "https://github.com/thenewchosenone/Fit-prototype/issues/new")!)
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Local")
                    }
                    Section("Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            Text("Dark").tag("Dark")
                            Text("System").tag("System")
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about: return "About this beta"
        case .privacy: return "Privacy notice"
        case .terms: return "Terms and disclaimer"
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .about:
            return [
                ("LiftRank beta", "This build previews ranked strength tracking, community, gyms, messages, and workout planning before the production backend is complete."),
                ("Seeded data", "Some rankings, messages, gyms, and posts use seeded demo data so the app can be tested without a live member base."),
                ("Feedback", "Report bugs, confusing flows, and missing gym or exercise data through the feedback link in Settings.")
            ]
        case .privacy:
            return [
                ("Prototype data", "Local demo changes may be reset during development. Do not enter sensitive health, financial, or private account information into prototype builds."),
                ("Public surfaces", "Public lift submissions, community posts, gym activity, and profile fields can appear across the app unless privacy controls hide them."),
                ("Messages", "Messages are part of the prototype experience and should not be treated as secure medical, legal, or private record storage.")
            ]
        case .terms:
            return [
                ("Fitness disclaimer", "LiftRank content is general information and personal experience, not medical advice, diagnosis, or individualized training instruction."),
                ("Safe use", "Do not rely on prototype rankings or exercise guidance for maximal attempts without qualified coaching and appropriate safety precautions."),
                ("Community rules", "Harassment, unsafe supplement advice, misleading lift claims, and spam may be reported and moderated.")
            ]
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
