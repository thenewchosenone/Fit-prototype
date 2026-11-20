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

    var title: String {
        switch self {
        case .legal: "About & support"
        case .developer: "Demo"
        default: rawValue.capitalized
        }
    }
}

struct SettingsView: View {
    private enum AppearanceDestination: Hashable {
        case theme, accent
    }

    @State private var activeSection: SettingsSection?
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var preferredUnit = UnitSystem.pounds
    @State private var trainingFocus: TrainingFocus?
    @State private var privacy = ProfilePrivacySettings()
    @State private var settingsBaseline: ProfileSettingsSnapshot?
    @State private var sharingAnalytics = false
    @State private var isEnablingNotifications = false
    @State private var isRetryingPRUploads = false
    @AppStorage("liftrank.appearance") private var appearance = LiftAppearance.system.rawValue
    @AppStorage("liftrank.workoutReminder.hour") private var workoutReminderHour = 9
    @AppStorage("liftrank.workoutReminder.minute") private var workoutReminderMinute = 0
    @AppStorage("liftrank.rescheduleSuggestions.enabled") private var rescheduleSuggestionsEnabled = true
    @State private var settingsInfo: SettingsInfoPage?
    @State private var showingPublicPreview = false
    @State private var confirmingDiscard = false
    private var savedTrainingFocus: TrainingFocus? {
        if appState.isAuthenticated && !appState.isDemoMode { return appState.currentProfile.trainingFocus }
        return appState.currentProfile.trainingFocus
            ?? UserDefaults.standard.string(forKey: "liftrank.progressFocus.\(appState.currentProfile.id.uuidString)").flatMap(TrainingFocus.init(rawValue:))
    }
    private var hasDraftChanges: Bool {
        guard hasLoadedDraft, let settingsBaseline else { return false }
        return ProfileSettingsSnapshot(preferredUnit: preferredUnit, trainingFocus: trainingFocus, privacy: privacy) != settingsBaseline
    }
    @State private var confirmingSignOut = false
    @State private var confirmingDeletion = false
    @State private var confirmingDemoReset = false
    @State private var isSavingSettings = false
    @State private var hasLoadedDraft = false
    @State private var settingsSaveError: String?
    @State private var showingSettingsSaveError = false
    @State private var guestEmail = ""
    @State private var guestPassword = ""
    @Environment(\.openURL) private var openURL

    init(initialSection: SettingsSection? = nil) {
        _activeSection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    if activeSection == nil {
                        Section {
                            ForEach([SettingsSection.privacy, .training, .notifications, .units, .appearance, .legal] + (appState.isDemoMode ? [] : [.account]), id: \.self) { section in
                                Button { activeSection = section } label: {
                                    HStack {
                                        Text(section.title).foregroundStyle(Color.liftText)
                                        if section == .units { Text(preferredUnit.shortLabel).foregroundStyle(Color.liftMuted) }
                                        if section == .appearance { Text(appearance).foregroundStyle(Color.liftMuted) }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.liftMuted)
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                            if appState.isDemoMode {
                                Button { activeSection = .developer } label: { settingsDestinationLabel("Demo") }
                            }
                        }
                        .listRowBackground(Color.liftCard)

                    }
                    if activeSection == .units {
                    Section("Units") {
                        Picker("Pounds or kilograms", selection: $preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("settings.preferredUnit")
                        .accessibilityValue(preferredUnit.rawValue.capitalized)
                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.units)
                    }
                    if activeSection == .account {
                    Section("Account") {

                        LabeledContent("Account", value: appState.isGuestMode ? "Guest" : "Signed in")
                        if let email = appState.accountSession?.email, !email.isEmpty {
                            LabeledContent("Email", value: email)
                        }
                        if appState.isGuestMode {
                            Text("Add an email and password to sign in on another device. Your profile and progress stay with this account.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            TextField("Email", text: $guestEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            SecureField("Password (10+ characters)", text: $guestPassword)
                                .textContentType(.newPassword)
                            Button(appState.accountOperationInProgress ? "Adding email…" : "Add email") {
                                Task {
                                    await appState.addEmailToGuestAccount(
                                        email: guestEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                                        password: guestPassword
                                    )
                                    if appState.accountMessage?.hasPrefix("Check your email") == true {
                                        guestPassword = ""
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appState.accountOperationInProgress || !guestEmail.contains("@") || guestPassword.count < 10)
                        }
                        Button("Sign Out", role: .destructive) { confirmingSignOut = true }
                            .disabled(appState.accountOperationInProgress)
                        if appState.isAuthenticated && !appState.isDemoMode {
                            Button("Delete Account", role: .destructive) {
                                appState.accountMessage = nil
                                confirmingDeletion = true
                            }
                            .disabled(appState.accountOperationInProgress)
                        }
                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.account)
                    }
                    if activeSection == .privacy {
                    Section("Privacy") {
                        audiencePicker("Profile visibility", selection: $privacy.profileAudience)
                        audiencePicker("Bodyweight", selection: $privacy.bodyweightAudience)
                        audiencePicker("Age group", selection: $privacy.ageBandAudience)
                        audiencePicker("Location", selection: $privacy.locationAudience)
                        audiencePicker("Gym", selection: $privacy.gymAudience)
                        audiencePicker("Gender category", selection: $privacy.divisionAudience)
                        audiencePicker("Friend list", selection: $privacy.friendListAudience)
                        audiencePicker("Workout stats", selection: Binding(
                            get: { privacy.workoutStatsAudience ?? .privateProfile },
                            set: { privacy.workoutStatsAudience = $0 }
                        ))
                        Text("Workout stats share only workout counts and the latest workout date. Your full workout history and sets stay private.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Toggle("Share workout starts with friends", isOn: Binding(
                            get: { privacy.shareWorkoutStartsWithFriends ?? false },
                            set: { privacy.shareWorkoutStartsWithFriends = $0 }
                        ))
                        Toggle("Share new top lifts with friends", isOn: Binding(
                            get: { privacy.sharePRsWithFriends ?? false },
                            set: { privacy.sharePRsWithFriends = $0 }
                        ))
                        Text("Activity is off by default and visible only to accepted friends. Shared top lifts must also be visible to friends and clear of moderation restrictions.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        Toggle("Show lift videos", isOn: $privacy.showLiftVideos)
                        DisclosureGroup("How visibility works") {
                            Text("Profile visibility limits who can open your profile. Field settings apply within that audience. Achievements and unlocked badges stay private. Relative-strength values may indirectly reveal bodyweight.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Button {
                            showingPublicPreview = true
                        } label: {
                            settingsDestinationLabel("Preview public profile")
                        }
                        .disabled(isSavingSettings || hasDraftChanges)
                        Text("Audience: public visitor")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.privacy)
                    Section("App analytics") {
                        Toggle("Share usage analytics", isOn: $sharingAnalytics)
                            .accessibilityIdentifier("settings.shareAnalytics")
                        Text("Includes your account ID and training activity to help improve Lift Rivals. Off by default on each device.")
                            .font(.caption).foregroundStyle(Color.liftMuted)
                        Button { settingsInfo = .privacy } label: { settingsDestinationLabel("Privacy policy") }
                    }
                    .listRowBackground(Color.liftCard)
                    }
                    if activeSection == .notifications { notificationsSettings }
                    if activeSection == .training { trainingSettings }
                    if activeSection == .legal {
                    Section("Legal and Safety") {
                        Button { settingsInfo = .about } label: { settingsDestinationLabel("About Lift Rivals") }
                        Button { settingsInfo = .privacy } label: { settingsDestinationLabel("Privacy notice") }
                        Button { settingsInfo = .terms } label: { settingsDestinationLabel("Terms of use") }
                        Button { settingsInfo = .fitnessDisclaimer } label: { settingsDestinationLabel("Fitness disclaimer") }
                        Link(destination: URL(string: "https://liftrivals.com/support/")!) {
                            Label("Support", systemImage: "arrow.up.right.square")
                                .frame(minHeight: LiftDesign.minimumTouchTarget)
                        }
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Local")
                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.legal)
                    }
                    if activeSection == .appearance { appearanceSettings }
                    if appState.isDemoMode && activeSection == .developer {
                        Section("Demo") {
                            Button("Leave demo") { dismiss(); Task { await appState.signOutAccount() } }
                            Button("Reset Demo Data", role: .destructive) {
                                confirmingDemoReset = true
                            }
                        }
                        .listRowBackground(Color.liftCard)
                        .id(SettingsSection.developer)
                    }
                    if let error = appState.repository.workoutSaveError {
                        Section("Device storage") {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Color.liftRed)
                            Button("Retry saving on this device") { appState.persistLocalWorkoutSnapshot() }
                                .buttonStyle(.bordered)
                        }
                    }
                    if isSavingSettings || settingsSaveError != nil || appState.accountOperationInProgress || appState.accountMessage != nil {
                        Section {
                            if isSavingSettings || appState.accountOperationInProgress {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(isSavingSettings ? "Saving settings…" : "Updating account…")
                                        .foregroundStyle(Color.liftMuted)
                                }
                            } else if let settingsSaveError {
                                Label("Save not confirmed", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(Color.liftRed)
                                    .accessibilityIdentifier("settings.saveError")
                                Text(settingsSaveError)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                Button("Retry") { saveSettingsAutomatically() }
                                    .accessibilityIdentifier("settings.retrySave")
                                if appState.isAuthenticated && !appState.isDemoMode {
                                    Button("Reload saved settings") { reloadSavedSettings() }
                                }
                            } else if let message = appState.accountMessage {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(message.hasPrefix("Check your email") ? Color.liftText : Color.liftRed)
                            }
                        }
                    }
                    }
                    .disabled(isSavingSettings || appState.accountOperationInProgress)
                    .alert("Couldn’t save settings", isPresented: $showingSettingsSaveError) {
                        Button("Retry") { saveSettingsAutomatically() }
                        if appState.isAuthenticated && !appState.isDemoMode {
                            Button("Reload saved settings") { reloadSavedSettings() }
                        }
                        Button("Keep editing", role: .cancel) {}
                    } message: {
                        Text(settingsSaveError ?? "Try again.")
                    }
                .scrollContentBackground(.hidden)
                .tint(Color.liftControlTint)
            }
            .navigationTitle(activeSection?.title ?? "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !hasLoadedDraft else { return }
                hasLoadedDraft = true
                let profile = appState.currentProfile
                privacy = appState.authenticatedPrivacy
                preferredUnit = profile.preferredUnit
                trainingFocus = savedTrainingFocus
                settingsBaseline = ProfileSettingsSnapshot(preferredUnit: preferredUnit, trainingFocus: trainingFocus, privacy: privacy)
                sharingAnalytics = AnalyticsStore.isSharingEnabled(for: profile.id)
            }
            .toolbar {
                if activeSection != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Settings", systemImage: "chevron.left") { activeSection = nil }
                            .labelStyle(.titleAndIcon)
                            .disabled(isSavingSettings || appState.accountOperationInProgress)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hasDraftChanges { confirmingDiscard = true } else { dismiss() }
                    } label: {
                        if isSavingSettings {
                            ProgressView().accessibilityLabel("Saving settings")
                        } else {
                            Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
                        }
                    }
                    .disabled(isSavingSettings || appState.accountOperationInProgress)
                }
            }
            .navigationDestination(for: AppearanceDestination.self) { destination in
                switch destination {
                case .theme: themePicker
                case .accent: accentPicker
                }
            }
            .navigationDestination(item: $settingsInfo) { page in
                SettingsInfoView(page: page)
            }
            .navigationDestination(isPresented: $showingPublicPreview) {
                ProfileView(profile: profileSettingsUpdate().profile, surface: .public, viewerID: UUID(), showsDismissButton: false) {
                    showingPublicPreview = false
                    activeSection = .privacy
                }
                .environmentObject(appState)
            }
            .alert("Sign out?", isPresented: $confirmingSignOut) {
                if appState.isGuestMode {
                    Button("Add email first") { activeSection = .account }
                }
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.signOutAccount()
                        if !appState.isAuthenticated { dismiss() }
                    }
                }
            } message: {
                Text(appState.isGuestMode
                    ? "Add an email before signing out to keep access to your guest account. Signing out removes local workouts and any changes that haven’t synced."
                    : "Signing out removes this device’s local data, including any workouts, plan changes, or videos that haven’t uploaded. Synced data stays in your account.")
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
                    ? "For security, you may need to sign in again before deleting your account. Your account data, workout backup, and local training data will be removed. After deletion, also remove Lift Rivals from Settings > your name > Sign in with Apple to revoke Apple authorization. This cannot be undone."
                    : "For security, you may need to sign in again before deleting your account. Your account data, workout backup, and local training data will be removed. This cannot be undone.")
            }
            .confirmationDialog("Reset demo data?", isPresented: $confirmingDemoReset, titleVisibility: .visible) {
                Button("Reset Demo Data", role: .destructive) { appState.resetDemoData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears the demo profile, workouts, bodyweight history, plans, awards, and other local demo progress. It does not affect production accounts.")
            }
        }
        .interactiveDismissDisabled(isSavingSettings || hasDraftChanges || appState.accountOperationInProgress)
        .alert("Leave without confirming changes?", isPresented: $confirmingDiscard) {
            Button("Close without retrying", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Some changes may already have reached your account. Retry to confirm your saved settings.")
        }
        .preferredColorScheme(LiftAppearance(rawValue: appearance)?.colorScheme)
        .onChange(of: preferredUnit) { saveSettingsAutomatically() }
        .onChange(of: trainingFocus) { saveSettingsAutomatically() }
        .onChange(of: privacy) { saveSettingsAutomatically() }
        .onChange(of: sharingAnalytics) {
            UserDefaults.standard.set(sharingAnalytics, forKey: AnalyticsStore.consentKey(for: appState.currentProfile.id))
        }
        .task { await appState.refreshNotificationAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await appState.refreshNotificationAuthorization() }
        }
        .onChange(of: workoutReminderHour) { scheduleWorkoutDayReminder() }
        .onChange(of: workoutReminderMinute) { scheduleWorkoutDayReminder() }
    }

    @ViewBuilder
    private var notificationsSettings: some View {
                    Section("Delivery") {
                        if appState.isDemoMode {
                            Text("Account alerts are unavailable in demo mode.")
                                .foregroundStyle(Color.liftMuted)
                        } else if appState.isGuestMode && appState.notificationAuthorizationStatus == .notDetermined {
                            Text("Account notifications require an email account.")
                                .font(.subheadline).foregroundStyle(Color.liftMuted)
                            Button { activeSection = .account } label: {
                                settingsDestinationLabel("Add an email")
                            }
                        } else if appState.notificationAuthorizationStatus == .notDetermined {
                            Button(isEnablingNotifications ? "Enabling…" : "Enable notifications") {
                                isEnablingNotifications = true
                                Task {
                                    await appState.requestPushRegistrationIfNeeded(requestPermission: true)
                                    isEnablingNotifications = false
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isEnablingNotifications)
                        } else {
                            LabeledContent("iOS permission", value: appState.notificationAuthorizationStatus == .denied ? "Off" : appState.notificationAuthorizationStatus == .provisional ? "Quiet delivery" : "On")
                            Button("Notification settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                            }
                        }
                        if let error = appState.pushRegistrationError {
                            Text(error).font(.caption).foregroundStyle(Color.liftRed)
                            Button("Retry connection") {
                                Task { await appState.requestPushRegistrationIfNeeded(requestPermission: true) }
                            }
                        }
                    }
                    .listRowBackground(Color.liftCard)
                    Section("Notifications") {
                        if privacy.gymOvertakeAlerts != nil {
                            Toggle("Someone passes me at my gym", isOn: Binding(
                                get: { privacy.gymOvertakeAlerts == true },
                                set: { privacy.gymOvertakeAlerts = $0 }
                            ))
                            Text("Video-backed single-lift rankings in your primary gym, age group, and division. Requires public profile, age group, and division. At most one alert per lift each day.")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }
                        Toggle("Workout day reminders", isOn: Binding(
                            get: { appState.workoutPreferences.workoutDayRemindersEnabled == true },
                            set: { appState.setWorkoutDayRemindersEnabled($0) }
                        ))
                        Toggle("Missed workout reminders", isOn: Binding(
                            get: { appState.workoutPreferences.missedWorkoutRemindersEnabled == true },
                            set: { appState.setMissedWorkoutRemindersEnabled($0) }
                        ))
                        if appState.workoutPreferences.workoutDayRemindersEnabled == true || appState.workoutPreferences.missedWorkoutRemindersEnabled == true {
                            DatePicker("Reminder time", selection: workoutReminderTimeBinding, displayedComponents: .hourAndMinute)
                            Text("Missed alerts arrive the following day for unfinished workouts.")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                            if appState.selectedPlanQueueEnabled {
                                Text("No reminder scheduled: this plan uses a training queue instead of dated workout days.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            } else if appState.selectedWorkoutPlan?.isActive != true {
                                Text("No reminder scheduled: choose an active dated plan first.")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            } else {
                                if appState.workoutPreferences.workoutDayRemindersEnabled == true {
                                    if let next = appState.nextWorkoutDayReminder(minutesAfterMidnight: workoutReminderHour * 60 + workoutReminderMinute) {
                                        Text("Next eligible workout: \(next.name) · \(next.date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    } else {
                                        Text("No upcoming workout-day alert for unfinished sessions with exercises.")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                                if appState.workoutPreferences.missedWorkoutRemindersEnabled == true {
                                    if let next = appState.nextMissedWorkoutReminder(minutesAfterMidnight: workoutReminderHour * 60 + workoutReminderMinute) {
                                        Text("Next eligible missed workout: \(next.name) · \(next.date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    } else {
                                        Text("No upcoming missed-workout alert for unfinished sessions with exercises.")
                                            .font(.caption)
                                            .foregroundStyle(Color.liftMuted)
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.liftCard)
                    Section("Reminder status") {
                        if let error = appState.workoutReminderError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.liftRed)
                            Button("Retry reminders") { scheduleWorkoutDayReminder() }
                                .buttonStyle(.bordered)
                        } else {
                            Text("Delivery depends on notification permissions and your active workout schedule.")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }
                    }
                    .listRowBackground(Color.liftCard)
                    Section("Rescheduling") {
                        Toggle("Suggest days for missed workouts", isOn: $rescheduleSuggestionsEnabled)
                        Text("You choose each move to a free day in the same week.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.notifications)
    }

    @ViewBuilder
    private var trainingSettings: some View {
                    Section("Progress") {
                        Picker("Default Progress view", selection: $trainingFocus) {
                            if trainingFocus == nil {
                                Text("Choose a focus").tag(nil as TrainingFocus?)
                            }
                            ForEach(TrainingFocus.allCases) { focus in
                                Text(focus.title).tag(Optional(focus))
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("settings.trainingFocus")
                        .accessibilityValue(trainingFocus?.title ?? "Choose a focus")
                    }
                    .listRowBackground(Color.liftCard)
                    Section("Sharing") {
                        Toggle("Auto-share eligible PRs publicly", isOn: Binding(
                            get: { appState.workoutPreferences.automaticallySubmitVideoBackedPRs },
                            set: { appState.setAutomaticVideoPRSubmission($0) }
                        ))
                        Text("Eligible PRs only. An attached video does not mean verified.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        if appState.pendingWorkoutPRSubmissions.contains(where: { $0.state == .failed }) {
                            let failedUploads = appState.pendingWorkoutPRSubmissions.filter { $0.state == .failed }
                            Label("\(failedUploads.count) uploads need attention", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.liftRed)
                            if let error = failedUploads.first?.lastError {
                                Text(error).font(.caption).foregroundStyle(Color.liftMuted)
                            }
                            Button(isRetryingPRUploads ? "Retrying uploads…" : "Retry failed PR uploads") {
                                isRetryingPRUploads = true
                                Task {
                                    await appState.retryFailedWorkoutPRSubmissions()
                                    isRetryingPRUploads = false
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRetryingPRUploads)
                        }
                    }
                    .listRowBackground(Color.liftCard)
                    Section("Rest timer") {
                        Toggle("Auto-start rest in new workouts", isOn: Binding(
                            get: { appState.workoutPreferences.defaultRestTimerEnabled },
                            set: { appState.setDefaultRestTimerEnabled($0) }
                        ))
                        Toggle("Adjust rest to logged effort", isOn: Binding(
                            get: { appState.workoutPreferences.adaptiveRestTimerEnabled == true },
                            set: { appState.setAdaptiveRestTimerEnabled($0) }
                        ))
                        DisclosureGroup("How rest timing works") {
                            Text("Change an active workout’s timer in that workout. Effort adjustments apply when its timer is enabled. RPE 9–10: +30s. RPE 1–6: up to −15s, minimum 30s unless prescribed rest is shorter. No effort logged: prescribed rest.")
                                .font(.caption).foregroundStyle(Color.liftMuted)
                        }

                    }
                    .listRowBackground(Color.liftCard)
                    .id(SettingsSection.training)
    }

    private var appearanceSettings: some View {
        Section {
            Picker("Appearance", selection: $appearance) {
                ForEach(LiftAppearance.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("settings.appearance")
            .accessibilityValue(appearance)
            NavigationLink(value: AppearanceDestination.theme) {
                HStack {
                    Text("Color theme")
                    Spacer()
                    Text(LiftThemeSelection.shared.value.rawValue).foregroundStyle(Color.liftMuted)
                }
            }
            .accessibilityIdentifier("settings.colorTheme")
            .accessibilityValue(LiftThemeSelection.shared.value.rawValue)
            NavigationLink(value: AppearanceDestination.accent) {
                HStack {
                    Text("Accent color")
                    Spacer()
                    Text(LiftAccentSelection.shared.value.rawValue).foregroundStyle(Color.liftMuted)
                }
            }
            .accessibilityIdentifier("settings.accentColor")
            .accessibilityValue(LiftAccentSelection.shared.value.rawValue)
        }
        .listRowBackground(Color.liftCard)
        .id(SettingsSection.appearance)
    }

    private var themePicker: some View {
        Form {
            ForEach(LiftTheme.allCases) { theme in
                Button {
                    guard LiftThemeSelection.shared.value != theme else { return }
                    LiftThemeSelection.shared.value = theme
                    LiftAccentSelection.shared.value = theme.defaultAccent
                } label: {
                    HStack(spacing: 12) {
                        HStack(spacing: -5) {
                            ForEach(theme.swatches.indices, id: \.self) { index in
                                Circle()
                                    .fill(theme.swatches[index])
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.liftSurfaceBorder, lineWidth: 1))
                            }
                        }
                        Text(theme.rawValue).foregroundStyle(Color.liftText)
                        Spacer()
                        Image(systemName: LiftThemeSelection.shared.value == theme ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                }
                .listRowBackground(Color.liftCard)
                .accessibilityIdentifier("settings.theme.\(theme.id)")
                .accessibilityAddTraits(LiftThemeSelection.shared.value == theme ? .isSelected : [])
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.liftBackground)
        .navigationTitle("Color theme")
    }

    private var accentPicker: some View {
        Form {
            ForEach(LiftAccent.allCases) { option in
                Button {
                    LiftAccentSelection.shared.value = option
                } label: {
                    HStack {
                        Circle().fill(option.fill).frame(width: 20, height: 20)
                        Text(option.rawValue).foregroundStyle(Color.liftText)
                        Spacer()
                        Image(systemName: LiftAccentSelection.shared.value == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.liftAccentText)
                    }
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .listRowBackground(Color.liftCard)
                .accessibilityAddTraits(LiftAccentSelection.shared.value == option ? .isSelected : [])
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.liftBackground)
        .navigationTitle("Accent color")
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

    private func reloadSavedSettings() {
        guard !isSavingSettings else { return }
        isSavingSettings = true
        Task { @MainActor in
            let loaded = await appState.reloadAccountSettings()
            if loaded {
                preferredUnit = appState.currentProfile.preferredUnit
                trainingFocus = savedTrainingFocus
                privacy = appState.authenticatedPrivacy
                settingsBaseline = ProfileSettingsSnapshot(preferredUnit: preferredUnit, trainingFocus: trainingFocus, privacy: privacy)
                settingsSaveError = nil
                showingSettingsSaveError = false
            } else {
                settingsSaveError = appState.accountMessage ?? "Your saved settings couldn’t be loaded. Try again."
            }
            isSavingSettings = false
        }
    }

    @MainActor
    private func saveSettingsAutomatically() {
        guard hasLoadedDraft, !isSavingSettings else { return }
        guard hasDraftChanges else {
            if appState.accountMessage == settingsSaveError { appState.accountMessage = nil }
            settingsSaveError = nil
            showingSettingsSaveError = false
            return
        }
        let update = profileSettingsUpdate()
        let requested = ProfileSettingsSnapshot(preferredUnit: preferredUnit, trainingFocus: trainingFocus, privacy: privacy)
        guard let baseline = settingsBaseline else { return }
        let previousFocus = savedTrainingFocus
        isSavingSettings = true
        settingsSaveError = nil
        showingSettingsSaveError = false
        Task {
            let saved: Bool
            if appState.isAuthenticated && !appState.isDemoMode {
                saved = await appState.saveAccountSettings(requested, expected: baseline)
            } else {
                saved = await appState.saveEditedProfile(update.profile, primaryGym: nil, privacy: update.privacy)
            }
            isSavingSettings = false
            if saved {
                settingsBaseline = requested
                if previousFocus != update.profile.trainingFocus,
                   let category = update.profile.trainingFocus?.startingCategory {
                    UserDefaults.standard.set(category.rawValue, forKey: "liftrank.progress.category")
                }
                // An edit already queued by a control must not be lost during a save.
                if preferredUnit != update.profile.preferredUnit || trainingFocus != update.profile.trainingFocus || privacy != update.privacy {
                    saveSettingsAutomatically()
                } else {
                    preferredUnit = appState.currentProfile.preferredUnit
                    trainingFocus = savedTrainingFocus
                    privacy = appState.authenticatedPrivacy
                    settingsBaseline = ProfileSettingsSnapshot(preferredUnit: preferredUnit, trainingFocus: trainingFocus, privacy: privacy)
                }
            } else {
                settingsSaveError = appState.accountMessage ?? "Your settings weren’t saved. Try again."
                showingSettingsSaveError = true
            }
        }
    }

    private var workoutReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: workoutReminderHour, minute: workoutReminderMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                workoutReminderHour = components.hour ?? 9
                workoutReminderMinute = components.minute ?? 0
            }
        )
    }

    private func scheduleWorkoutDayReminder() {
        appState.refreshWorkoutDayReminders()
    }

    private func settingsDestinationLabel(_ title: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.liftText)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
        }
        .frame(minHeight: LiftDesign.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    private func audiencePicker(_ title: String, selection: Binding<PrivacyAudience>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PrivacyAudience.allCases) { audience in
                Text(audience == .friends ? "Accepted friends" : audience == .privateProfile ? "Only you" : audience.label).tag(audience)
            }
        }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier(title)
    }
}

enum SettingsInfoPage: String, Identifiable, Hashable {
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
                ("Lift Rivals", "Lift Rivals is a competitive strength platform for tracking workouts, recording one-rep personal records, and comparing eligible lifts."),
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
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var onBack: (() -> Void)? = nil
    var backTitle = "Back"
    var isOnboarding = false
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
                    Text("Review policies")
                        .font(.title.weight(.semibold))
                    Text("Review and accept the current policies. You can open each document below before accepting.")
                        .foregroundStyle(Color.liftMuted)

                    ForEach(documents) { document in
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    withAnimation(reduceMotion ? nil : .snappy) { expanded = expanded == document.kind ? nil : document.kind }
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
                                            Text(section.title).font(LiftTypography.rowEmphasis)
                                            Text(section.body).font(.subheadline).foregroundStyle(Color.liftMuted)
                                        }
                                    }
                                }

                                Button {
                                    if acknowledged.contains(document.kind) { acknowledged.remove(document.kind) }
                                    else { acknowledged.insert(document.kind) }
                                } label: {
                                    Label(acceptanceLabel(for: document), systemImage: acknowledged.contains(document.kind) ? "checkmark.square.fill" : "square")
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.liftAccentText)
                                .accessibilityValue(acknowledged.contains(document.kind) ? "Checked" : "Unchecked")
                                .accessibilityAddTraits(acknowledged.contains(document.kind) ? .isSelected : [])
                                .disabled(appState.accountOperationInProgress)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(LiftTypography.cardTitle)
                            .foregroundStyle(Color.liftText)
                            .frame(width: 44, height: 44)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(backTitle == "Back" ? "Previous step" : backTitle)
                    .accessibilityIdentifier("legal.back")
                    Spacer()
                    if isOnboarding {
                        Text("STEP 4 OF 4")
                            .font(LiftTypography.compactEmphasis)
                            .foregroundStyle(Color.liftMuted)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(Color.liftBackground)
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
    let page: SettingsInfoPage

    var body: some View {
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
    }
}
