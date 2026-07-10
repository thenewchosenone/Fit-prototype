import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = true
    @State private var preferredUnit = UnitSystem.pounds
    @State private var privateProfile = false
    @State private var hideBodyweight = false
    @State private var hideExactAge = false
    @State private var hideLocation = false
    @State private var allowComments = true
    @State private var notificationPreferences = true
    @State private var appearance = "Dark"

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
                    Section("Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            Text("Dark").tag("Dark")
                            Text("System").tag("System")
                        }
                    }
                    Section("Developer") {
                        Button("Reset Demo Data", role: .destructive) {
                            Haptics.warning()
                            appState.repository.reset()
                        }
                        Button("Replay Onboarding") {
                            didCompleteOnboarding = false
                            dismiss()
                        }
                    }
                    Section {
                        Button("Sign Out", role: .destructive) {
                            dismiss()
                            appState.showingAuthentication = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
