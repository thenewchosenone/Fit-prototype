import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(.dismiss) private var dismiss
    @ObservedObject private var account = SupabaseMobileSync.shared
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = true
    @State private var preferredUnit = UnitSystem.pounds
    @AppStorage("privateProfile") private var privateProfile = false
    @State private var hideBodyweight = false
    @State private var hideExactAge = false
    @State private var hideLocation = false
    @State private var hideGym = false
    @State private var hideLiftVideos = false
    @State private var allowComments = true
    @State private var notificationPreferences = true
    @State private var appearance = "Dark"

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Lift Rivals account") {
                        LabeledContent("Status", value: account.isAuthenticated ? "Connected" : "Offline")
                        if account.isAuthenticated {
                            LabeledContent("Account", value: account.accountLabel)
                            Button("Sync profile and workouts now") {
                                Task {
                                    await account.pushCurrentState(from: appState.repository)
                                }
                            }
                            .disabled(account.isBusy)

                            Button("Sign Out", role: .destructive) {
                                Task {
                                    await account.signOut()
                                    dismiss()
                                    appState.showingAuthentication = true
                                }
                            }
                        } else {
                            Button("Sign in to sync with the website") {
                                dismiss()
                                appState.showingAuthentication = true
                            }
                        }

                        if let status = account.statusMessage {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(Color.liftGreen)
                        }
                        if let error = account.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.liftRed)
                        }
                    }

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
                        Toggle("Hide gym", isOn: $hideGym)
                        Toggle("Hide lift videos", isOn: $hideLiftVideos)
                        Toggle("Allow comments", isOn: $allowComments)
                    }
                    Section("Notifications") {
                        Toggle("Notification preferences", isOn: $notificationPreferences)
                    }
                    Section("Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            Text("Dark").tag("Dark")
                            Text("System").tag("System")
                        }
                    }
#if DEBUG
                    Section("Developer") {
                        Button("Reset local data", role: .destructive) {
                            Haptics.warning()
                            appState.repository.reset()
                        }
                        Button("Replay Onboarding") {
                            didCompleteOnboarding = false
                            dismiss()
                        }
                    }
#endif
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        persistProfilePreferences()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let profile = appState.currentProfile
            preferredUnit = profile.preferredUnit
            hideBodyweight = profile.hideBodyweight
            hideExactAge = profile.hideExactAge
            hideLocation = profile.hideCity
            hideGym = profile.hideGym
            hideLiftVideos = profile.hideLiftVideos
        }
    }

    private func persistProfilePreferences() {
        var profile = appState.currentProfile
        profile.preferredUnit = preferredUnit
        profile.hideBodyweight = hideBodyweight
        profile.hideExactAge = hideExactAge
        profile.hideCity = hideLocation
        profile.hideGym = hideGym
        profile.hideLiftVideos = hideLiftVideos
        appState.updateProfile(profile)
        Task {
            await account.pushCurrentState(from: appState.repository)
        }
    }
}
