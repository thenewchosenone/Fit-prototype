import SwiftUI
import UIKit

private enum OnboardingLocationPicker: String, Identifiable {
    case country, region, city
    var id: String { rawValue }
}

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject private var appState: AppState
    @State private var step = 1
    @State private var showingStartingLifts = false
    @State private var goals: Set<String> = []
    @State private var profile = MockData.emptyProfile
    @State private var privacy = ProfilePrivacySettings()
    @State private var loadedProfile = false
    @State private var showingLegalAcceptance = false
    @State private var isSavingProfile = false
    @State private var saveError: String?
    @State private var bench = ""
    @State private var squat = ""
    @State private var deadlift = ""
    @State private var press = ""
    @State private var bio = ""
    @State private var yearsTraining: Int?
    @State private var showingHeightPicker = false
    @State private var showingPhotoManager = false
    @State private var selectedCountryCode = ""
    @State private var selectedRegionName = ""
    @State private var selectedCity = ""
    @State private var selectedCityID: UUID?
    @State private var cityQuery = ""
    @State private var citySuggestions: [LocationCitySuggestion] = []
    @State private var citySearchTask: Task<Void, Never>?
    @State private var isSearchingCities = false
    @State private var locationPicker: OnboardingLocationPicker?
    @FocusState private var focusedRecord: String?
    let complete: () -> Void

    private let goalOptions: [(id: String, title: String, symbol: String, subtitle: String, focus: TrainingFocus?)] = [
        ("get_stronger", "Build all-around strength", "bolt.fill", "Improve strength across your exercises", nil),
        ("bodybuilding", "Build muscle", "figure.strengthtraining.traditional", "Focus on muscle growth and balance", .bodybuilding),
        ("powerlifting", "Improve my powerlifting total", "dumbbell.fill", "Focus on squat, bench, and deadlift", .powerlifting),
        ("generalFitness", "General fitness", "heart.fill", "Build a consistent training habit", .generalFitness)
    ]
    private let launchCountries = LaunchLocationCatalog.countries

    private var selectedCountry: LaunchCountry? {
        launchCountries.first { $0.code == selectedCountryCode }
    }

    private var selectedRegion: LaunchRegion? {
        selectedCountry?.regions.first { $0.name == selectedRegionName }
    }

    static func gymsMatchingLocation(_ gyms: [Gym], city: String, region: String) -> [Gym] {
        gyms
            .filter {
                $0.city.localizedCaseInsensitiveCompare(city) == .orderedSame &&
                $0.state.localizedCaseInsensitiveCompare(region) == .orderedSame
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        AppBackground {
            Group {
                switch step {
                case 1: goalsView
                case 2: profileView
                default: recordsView
                }
            }
            .disabled(isSavingProfile)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .snappy, value: step)
            .safeAreaInset(edge: .top, spacing: 0) {
                topBar
                    .disabled(isSavingProfile)
                    .background(Color.liftBackground)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controls
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(isPresented: $showingLegalAcceptance) {
            LegalAcceptanceView(onBack: { showingLegalAcceptance = false }, isOnboarding: true)
                .environmentObject(appState)
                .interactiveDismissDisabled()
        }
        .onAppear {
            guard !loadedProfile else { return }
            loadedProfile = true
            profile = appState.currentProfile
            privacy = appState.authenticatedPrivacy
            profile.username = AppleIdentityStore.usernameSuggestion(from: appState.pendingAppleFullName) ?? ""
            profile.displayName = ""
            bio = profile.bio ?? ""
            yearsTraining = profile.yearsExperience > 0 ? profile.yearsExperience : nil
            selectedCountryCode = ""
            selectedRegionName = ""
            selectedCity = ""
            selectedCityID = nil
            cityQuery = ""
            citySuggestions = []
            profile.city = ""
            profile.state = ""
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTestingPrefilledOnboarding") {
                profile.username = "launch_lifter"
                profile.displayName = "Launch Lifter"
                profile.sexCategory = .male
                selectedCountryCode = "US"
                selectedRegionName = "Florida"
                selectedCity = "Miami"
                profile.city = "Miami"
                profile.state = "Florida"
            }
#endif
        }
        .sheet(isPresented: $showingPhotoManager, onDismiss: {
            profile.avatarPath = appState.currentProfile.avatarPath
        }) {
            ProfilePhotoManagerView()
                .environmentObject(appState)
        }
        .sheet(item: $locationPicker) { picker in
            locationPickerSheet(picker)
        }
        .onChange(of: cityQuery) { _, query in searchCities(matching: query) }
        .task {
            await appState.refreshRemoteSocialState()
        }
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                if step > 1 {
                    Button {
                        dismissKeyboard()
                        withAnimation(reduceMotion ? nil : .snappy) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(LiftTypography.cardTitle)
                            .frame(width: 44, height: 44)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Previous step")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                Text("STEP \(step) OF 4")
                    .font(LiftTypography.compactEmphasis)
                    .tracking(1.2)
                    .foregroundStyle(Color.liftMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer()

                if appState.isDemoMode {
                    Button("Skip") { complete() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 42)
                } else {
                    Button {
                        Task { await appState.signOutAccount() }
                    } label: {
                        Text("Exit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Exit setup and sign out")
                    .disabled(appState.accountOperationInProgress)
                }
            }

            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < step ? Color.liftBlue : Color.liftOverlay)
                        .frame(height: 5)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bodyweightField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bodyweight", systemImage: "scalemass.fill")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Not set", value: Binding<Double?>(
                    get: {
                        profile.bodyweightPounds > 0
                            ? MeasurementFormatting.convert(profile.bodyweightPounds, from: .pounds, to: profile.preferredUnit)
                            : nil
                    },
                    set: { value in
                        profile.bodyweightPounds = value.map {
                            MeasurementFormatting.convert($0, from: profile.preferredUnit, to: .pounds)
                        } ?? 0
                    }
                ), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .accessibilityLabel("Bodyweight")
                    .accessibilityIdentifier("onboarding.bodyweight")
                Text(profile.preferredUnit.shortLabel)
                    .font(LiftTypography.rowEmphasis)
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private var heightScroller: some View {
        Button { showingHeightPicker = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("Height", systemImage: "ruler")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    Text(formattedHeight)
                        .font(LiftTypography.rowEmphasis)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(LiftTypography.compactEmphasis)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .sheet(isPresented: $showingHeightPicker) {
            NavigationStack {
                Picker("Height", selection: Binding(
                    get: {
                        (48...84).contains(Int(profile.heightInches.rounded()))
                            ? Int(profile.heightInches.rounded())
                            : 70
                    },
                    set: { profile.heightInches = Double($0) }
                )) {
                    ForEach(48...84, id: \.self) { inches in
                        Text(heightLabel(for: inches)).tag(inches)
                    }
                }
                .pickerStyle(.wheel)
                .navigationTitle("Height")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingHeightPicker = false }
                    }
                }
            }
            .presentationDetents([.height(280)])
        }
    }

    private func heightLabel(for totalInches: Int) -> String {
        "\(totalInches / 12)'\(totalInches % 12)\""
    }

    private var formattedHeight: String {
        let totalInches = Int(profile.heightInches.rounded())
        guard (48...84).contains(totalInches) else { return "Not set" }
        return "\(totalInches / 12)'\(totalInches % 12)\""
    }

    private var goalsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    eyebrow: "YOUR TRAINING",
                    title: "What are you training for?",
                    subtitle: "Choose your main goal. This saves your training preference; it does not assign a workout plan. You can change it later in Settings."
                )

                Text("Choose one")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)

                ForEach(goalOptions, id: \.id) { option in
                    let isSelected = option.focus.map { profile.trainingFocus == $0 } ?? goals.contains(option.id)
                    Button {
                        Haptics.light()
                        profile.trainingFocus = option.focus
                        goals = option.focus == nil ? [option.id] : []
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: option.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.liftOnAccent : Color.liftAccentText)
                                .frame(width: 46, height: 46)
                                .background(isSelected ? Color.liftBlue : Color.liftBlue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.liftText)
                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isSelected ? Color.liftAccentText : Color.liftMuted.opacity(0.55))
                        }
                        .padding(15)
                        .background(isSelected ? Color.liftBlue.opacity(0.10) : Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? Color.liftBlue.opacity(0.75) : Color.liftOverlay, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.goal.\(option.id)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var profileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenHeader(
                    eyebrow: "YOUR PROFILE",
                    title: "Set up your profile.",
                    subtitle: "Choose a username. The other details below are optional."
                )

                field("Username", text: $profile.username, symbol: "at", disablesSuggestions: true)
                    .onChange(of: profile.username) { _, _ in
                        saveError = nil
                    }

                Button {
                    showingPhotoManager = true
                } label: {
                    HStack(spacing: 14) {
                        ProfileAvatar(profile: profile, size: 64)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .padding(7)
                                    .background(Color.liftBlue)
                                    .foregroundStyle(Color.liftOnAccent)
                                    .clipShape(Circle())
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile photo")
                                .font(.headline)
                            Text("Choose a photo or keep the default")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(16)
                    .background(Color.liftCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.photo")

                field("Bio (optional)", text: $bio, symbol: "text.quote")

                profileSection("Training details (optional)") {
                    labeledPicker("Preferred unit", symbol: "scalemass.fill") {
                        Picker("Preferred unit", selection: $profile.preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        bodyweightField
                        heightScroller
                    }
                    labeledPicker("Years training", symbol: "calendar.badge.clock") {
                        TextField("Not set", value: $yearsTraining, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Years training")
                            .accessibilityIdentifier("onboarding.yearsTraining")
                    }
                }

                profileSection("Location (optional)") {
                    locationPickerRow("Country", value: selectedCountry?.name ?? "Not set", symbol: "globe.americas.fill", picker: .country)
                    locationPickerRow("State / province", value: selectedRegionName.isEmpty ? "Not set" : selectedRegionName, symbol: "map.fill", picker: .region, disabled: selectedCountry == nil)
                    locationPickerRow("City", value: selectedCity.isEmpty ? "Not set" : selectedCity, symbol: "mappin.and.ellipse", picker: .city, disabled: selectedRegion == nil)
                }
                privacyToggles
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func profileSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(LiftTypography.compactEmphasis)
                .tracking(1)
                .foregroundStyle(Color.liftMuted)
            content()
        }
    }

    private func locationPickerRow(
        _ title: String,
        value: String,
        symbol: String,
        picker: OnboardingLocationPicker,
        disabled: Bool = false
    ) -> some View {
        Button {
            dismissKeyboard()
            if picker == .city {
                citySearchTask?.cancel()
                cityQuery = ""
                citySuggestions = []
                isSearchingCities = false
            }
            locationPicker = picker
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 22)
                Text(title).foregroundStyle(Color.liftMuted)
                Spacer()
                Text(value)
                    .foregroundStyle(disabled ? Color.liftTextDisabled : Color.liftText)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(15)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.location.\(picker.rawValue)")
        .disabled(disabled)
    }

    @ViewBuilder
    private func locationPickerSheet(_ picker: OnboardingLocationPicker) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                if picker == .city {
                    TextField("Search other cities in \(selectedRegionName)", text: $cityQuery)
                        .accessibilityIdentifier("onboarding.city.search")
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding()
                }
                switch picker {
                case .country:
                    Picker("Country", selection: $selectedCountryCode) {
                        Text("Select country").tag("")
                        ForEach(launchCountries) { Text($0.name).tag($0.code) }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedCountryCode) { _, _ in
                        selectedRegionName = ""
                        resetCitySelection()
                        profile.state = ""
                    }
                case .region:
                    Picker("State or province", selection: $selectedRegionName) {
                        Text("Select state or province").tag("")
                        ForEach(selectedCountry?.regions ?? []) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedRegionName) { _, value in
                        resetCitySelection()
                        profile.state = value
                    }
                case .city:
                    if isSearchingCities {
                        ProgressView("Searching cities…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !cityQuery.isEmpty && cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                        ContentUnavailableView("Type at least two letters", systemImage: "magnifyingglass")
                    } else if cityPickerSuggestions.isEmpty {
                        ContentUnavailableView {
                            Label("No matching cities", systemImage: "mappin.and.ellipse")
                        } description: {
                            Text("Try another search or add your location later in Settings.")
                        } actions: {
                            Button("Search again") { searchCities(matching: cityQuery) }
                        }
                    } else {
                        List {
                            Section(cityQuery.isEmpty ? "Common cities" : "Search results") {
                                ForEach(cityPickerSuggestions) { suggestion in
                                    Button {
                                        selectCity(suggestion)
                                        locationPicker = nil
                                    } label: {
                                        HStack {
                                            Text(suggestion.city)
                                            Spacer()
                                            if selectedCity == suggestion.city {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(Color.liftAccentText)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(picker == .country ? "Country" : picker == .region ? "State / province" : "City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { locationPicker = nil }
                }
            }
        }
        .presentationDetents(picker == .city ? [.medium, .large] : [.height(300)])
    }

    private var cityPickerSuggestions: [LocationCitySuggestion] {
        guard cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return citySuggestions
        }
        return (selectedRegion?.cities ?? []).map { city in
            LocationCitySuggestion(
                canonicalID: nil,
                city: city,
                region: selectedRegionName,
                countryCode: selectedCountryCode,
                countryName: selectedCountry?.name ?? "",
                population: nil
            )
        }
    }

    private func resetCitySelection() {
        citySearchTask?.cancel()
        selectedCity = ""
        selectedCityID = nil
        cityQuery = ""
        citySuggestions = []
        isSearchingCities = false
        profile.city = ""
        normalizeSelectedGym()
    }

    private func selectCity(_ suggestion: LocationCitySuggestion) {
        citySearchTask?.cancel()
        isSearchingCities = false
        selectedCity = suggestion.city
        selectedCityID = suggestion.canonicalID
        citySuggestions = []
        profile.city = suggestion.city
        profile.state = suggestion.region
        selectedRegionName = suggestion.region
        selectedCountryCode = suggestion.countryCode
        normalizeSelectedGym()
    }

    private func normalizeSelectedGym() {
        guard !profile.primaryGymName.isEmpty,
              appState.gyms.contains(where: { $0.id == profile.primaryGymID }) else {
            profile.primaryGymName = ""
            return
        }
    }

    private func searchCities(matching query: String) {
        citySearchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedCountry, let selectedRegion, trimmedQuery.count >= 2 else {
            citySuggestions = []
            isSearchingCities = false
            return
        }

        isSearchingCities = true
        citySearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let results = await appState.searchCities(
                countryCode: selectedCountry.code,
                region: selectedRegion.name,
                query: trimmedQuery,
                limit: 20
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                citySuggestions = results
                isSearchingCities = false
            }
        }
    }

    private var privacyToggles: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Profile visibility", systemImage: "lock.shield.fill")
                    .font(.headline)
                    .foregroundStyle(Color.liftAccentText)
                ForEach([
                    (title: "Profile", field: \ProfilePrivacySettings.profileAudience),
                    (title: "Bodyweight", field: \ProfilePrivacySettings.bodyweightAudience),
                    (title: "Location", field: \ProfilePrivacySettings.locationAudience)
                ], id: \.title) { option in
                    HStack {
                        Text(option.title)
                        Spacer()
                        Picker(option.title, selection: Binding(
                            get: { privacy[keyPath: option.field] },
                            set: { privacy[keyPath: option.field] = $0 }
                        )) {
                            ForEach(PrivacyAudience.allCases) { audience in
                                Text(audience.label).tag(audience)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("onboarding.privacy.\(option.title.lowercased().replacingOccurrences(of: " ", with: "_"))")
                        .accessibilityValue(privacy[keyPath: option.field].label)
                    }
                    .frame(minHeight: 44)
                }
                Text("These settings apply to details you choose to add. You can manage age group, gym, and video visibility later in Settings.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .tint(Color.liftAccentText)
        }
    }

    private var recordsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    eyebrow: "STARTING LIFTS",
                    title: "Add starting lifts?",
                    subtitle: "This is optional. If you already know your best single-rep lifts, add them as a baseline. Otherwise, continue and log your training later."
                )

                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.liftAccentText)
                    Text("These starting lifts stay private. You can choose to share lifts later.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(15)
                .background(Color.liftBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                DisclosureGroup("Add known one-rep maxes", isExpanded: $showingStartingLifts) {
                    VStack(spacing: 12) {
                        recordField("Bench press", text: $bench, badge: "BP", tint: .liftAccentText)
                        recordField("Back squat", text: $squat, badge: "SQ", tint: .liftPurple)
                        recordField("Deadlift", text: $deadlift, badge: "DL", tint: .liftGold)
                        recordField("Overhead press", text: $press, badge: "OHP", tint: .liftGreen)

                    }
                    .padding(.top, 12)
                }
                .tint(Color.liftAccentText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var controls: some View {
        VStack(spacing: 9) {
            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(Color.liftRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PrimaryButton(
                title: isSavingProfile ? "Saving…" : (step == 3 ? "Continue to policies" : "Continue"),
                symbolName: step == 3 ? "arrow.right" : "chevron.right"
            ) {
                if step == 3 {
                    dismissKeyboard()
                    saveOnboardingProfile()
                } else if step == 2 {
                    dismissKeyboard()
                    saveOnboardingProfile(completesOnboarding: false)
                } else {
                    dismissKeyboard()
                    saveError = nil
                    withAnimation(reduceMotion ? nil : .snappy) { step += 1 }
                }
            }
            .accessibilityIdentifier("onboarding.next")
            .disabled(isSavingProfile || (step == 1 && profile.trainingFocus == nil && goals.isEmpty))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.liftBackground)
    }

    private func saveOnboardingProfile(completesOnboarding: Bool = true) {
        guard !isSavingProfile else { return }
        guard validateProfileDetails() else { return }
        let username = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedCityValue = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCompleteLocation = selectedCountry != nil && selectedRegion != nil && !selectedCityValue.isEmpty &&
            (selectedCityID != nil || selectedRegion?.cities.contains { $0.caseInsensitiveCompare(selectedCityValue) == .orderedSame } == true)
        profile.avatarPath = appState.currentProfile.avatarPath
        profile.city = hasCompleteLocation ? selectedCityValue : ""
        profile.cityID = hasCompleteLocation ? selectedCityID : nil
        isSavingProfile = true
        saveError = nil
        let privacy = self.privacy
        let profileDraft: (Bool) -> ProfileDraft = { completesOnboarding in
            ProfileDraft(
            username: username,
            displayName: username,
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarPath: profile.avatarPath,
            preferredUnit: profile.preferredUnit,
            birthDate: nil,
            sexCategory: nil,
            heightCentimeters: (48...84).contains(Int(profile.heightInches.rounded())) ? profile.heightInches * 2.54 : nil,
            bodyweightPounds: profile.bodyweightPounds > 0 ? profile.bodyweightPounds : nil,
            cityID: hasCompleteLocation ? selectedCityID : nil,
            city: profile.city,
            region: hasCompleteLocation ? (selectedRegion?.name ?? "") : "",
            countryCode: hasCompleteLocation ? selectedCountryCode : "",
            yearsExperience: yearsTraining,
            experienceLevel: appState.earnedExperienceLevel,
            privacy: privacy,
            completesOnboarding: completesOnboarding,
            trainingFocus: profile.trainingFocus
            )
        }
        let startingLifts = [
            ("bench", bench),
            ("squat", squat),
            ("deadlift", deadlift),
            ("press", press)
        ].compactMap { exerciseID, value in
            OnboardingStartingLift(exerciseID: exerciseID, weight: Double(value))
        }
        Task {
            defer { isSavingProfile = false }
            do {
                try await appState.saveAuthenticatedProfile(profileDraft(false), allowUsernameChange: true)
                profile.username = appState.currentProfile.username
                guard completesOnboarding else {
                    withAnimation(reduceMotion ? nil : .snappy) { step = 3 }
                    return
                }
                try await appState.saveTrainingGoals(Array(goals).sorted())
                try await appState.saveAuthenticatedProfile(profileDraft(true))
                // Starting lifts are optional. A failed lift submission must not block account setup.
                try? await appState.saveOnboardingStartingLifts(
                    startingLifts,
                    unit: profile.preferredUnit,
                    bodyweightPounds: profile.bodyweightPounds,
                    gymID: profile.primaryGymID
                )
                appState.consumePendingAppleFullName()
                Haptics.success()
                showingLegalAcceptance = appState.accountStatus == .needsLegalAcceptance
                complete()
            } catch {
                if let serviceError = error as? LiftRankServiceError, case .usernameUnavailable = serviceError {
                    step = 2
                }
                saveError = (error as? LocalizedError)?.errorDescription ?? "Your profile could not be saved."
                Haptics.warning()
            }
        }
    }

    private func validateProfileDetails() -> Bool {
        let username = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty {
            saveError = "Choose a username to continue."
        } else if let yearsTraining, !(0...100).contains(yearsTraining) {
            saveError = "Enter years training from 0 to 100, or leave it blank."
        } else if profile.bodyweightPounds < 0 {
            saveError = "Enter a positive bodyweight or leave it blank."
        } else if profile.bodyweightPounds > 1_000 {
            saveError = "Enter a bodyweight under 1,000 lb to continue."
        } else {
            return true
        }
        Haptics.warning()
        return false
    }

    private func dismissKeyboard() {
        focusedRecord = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func screenHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow)
                .font(LiftTypography.compactEmphasis)
                .tracking(1.6)
                .foregroundStyle(Color.liftAccentText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.title.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        symbol: String,
        keyboard: UIKeyboardType = .default,
        disablesSuggestions: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.liftAccentText)
                .frame(width: 22)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textContentType(disablesSuggestions ? .none : nil)
                .textInputAutocapitalization(disablesSuggestions ? .never : nil)
                .autocorrectionDisabled(disablesSuggestions)
                .textFieldStyle(.plain)
        }
        .padding(15)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .accessibilityLabel(title)
    }

    private func recordField(_ title: String, text: Binding<String>, badge: String, tint: Color) -> some View {
        HStack(spacing: 15) {
            Text(badge)
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text("Current one-rep max")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("Weight", text: text)
                    .accessibilityIdentifier("onboarding.record.\(title)")
                    .accessibilityLabel("\(title) one-rep max")
                    .keyboardType(.decimalPad)
                    .focused($focusedRecord, equals: title)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.semibold))
                    .frame(width: 80)
                    .padding(10)
                    .background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(profile.preferredUnit.shortLabel)
                    .fixedSize()
                    .font(LiftTypography.compactEmphasis)
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(16)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(text.wrappedValue.isEmpty ? Color.liftOverlay : tint.opacity(0.65), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func labeledPicker<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.liftAccentText)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            content()
                .labelsHidden()
                .tint(Color.liftText)
        }
        .padding(15)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
    }
}

struct LaunchCountry: Identifiable {
    let code: String
    let name: String
    let regionLabel: String
    let regions: [LaunchRegion]

    var id: String { code }
}

struct LaunchRegion: Identifiable {
    let name: String
    let cities: [String]

    var id: String { name }
}

enum LaunchLocationCatalog {
    static let countries: [LaunchCountry] = [
        LaunchCountry(code: "US", name: "United States", regionLabel: "State", regions: [
            LaunchRegion(name: "Alabama", cities: ["Birmingham", "Montgomery", "Mobile"]),
            LaunchRegion(name: "Alaska", cities: ["Anchorage", "Fairbanks", "Juneau"]),
            LaunchRegion(name: "Arizona", cities: ["Phoenix", "Tucson", "Mesa"]),
            LaunchRegion(name: "Arkansas", cities: ["Little Rock", "Fayetteville", "Fort Smith"]),
            LaunchRegion(name: "California", cities: ["Los Angeles", "San Diego", "San Francisco", "San Jose"]),
            LaunchRegion(name: "Colorado", cities: ["Denver", "Colorado Springs", "Aurora"]),
            LaunchRegion(name: "Connecticut", cities: ["Bridgeport", "New Haven", "Hartford"]),
            LaunchRegion(name: "Delaware", cities: ["Wilmington", "Dover", "Newark"]),
            LaunchRegion(name: "District of Columbia", cities: ["Washington"]),
            LaunchRegion(name: "Florida", cities: ["Miami", "Cutler Bay", "Homestead", "Orlando", "Tampa", "Jacksonville"]),
            LaunchRegion(name: "Georgia", cities: ["Atlanta", "Augusta", "Savannah"]),
            LaunchRegion(name: "Hawaii", cities: ["Honolulu", "Hilo", "Kailua"]),
            LaunchRegion(name: "Idaho", cities: ["Boise", "Meridian", "Nampa"]),
            LaunchRegion(name: "Illinois", cities: ["Chicago", "Aurora", "Naperville"]),
            LaunchRegion(name: "Indiana", cities: ["Indianapolis", "Fort Wayne", "Evansville"]),
            LaunchRegion(name: "Iowa", cities: ["Des Moines", "Cedar Rapids", "Davenport"]),
            LaunchRegion(name: "Kansas", cities: ["Wichita", "Overland Park", "Kansas City"]),
            LaunchRegion(name: "Kentucky", cities: ["Louisville", "Lexington", "Bowling Green"]),
            LaunchRegion(name: "Louisiana", cities: ["New Orleans", "Baton Rouge", "Shreveport"]),
            LaunchRegion(name: "Maine", cities: ["Portland", "Lewiston", "Bangor"]),
            LaunchRegion(name: "Maryland", cities: ["Baltimore", "Frederick", "Rockville"]),
            LaunchRegion(name: "Massachusetts", cities: ["Boston", "Worcester", "Springfield"]),
            LaunchRegion(name: "Michigan", cities: ["Detroit", "Grand Rapids", "Ann Arbor"]),
            LaunchRegion(name: "Minnesota", cities: ["Minneapolis", "Saint Paul", "Rochester"]),
            LaunchRegion(name: "Mississippi", cities: ["Jackson", "Gulfport", "Southaven"]),
            LaunchRegion(name: "Missouri", cities: ["Kansas City", "St. Louis", "Springfield"]),
            LaunchRegion(name: "Montana", cities: ["Billings", "Missoula", "Bozeman"]),
            LaunchRegion(name: "Nebraska", cities: ["Omaha", "Lincoln", "Bellevue"]),
            LaunchRegion(name: "Nevada", cities: ["Las Vegas", "Henderson", "Reno"]),
            LaunchRegion(name: "New Hampshire", cities: ["Manchester", "Nashua", "Concord"]),
            LaunchRegion(name: "New Jersey", cities: ["Newark", "Jersey City", "Paterson"]),
            LaunchRegion(name: "New York", cities: ["New York City", "Buffalo", "Rochester", "Albany"]),
            LaunchRegion(name: "North Carolina", cities: ["Charlotte", "Raleigh", "Greensboro"]),
            LaunchRegion(name: "North Dakota", cities: ["Fargo", "Bismarck", "Grand Forks"]),
            LaunchRegion(name: "Ohio", cities: ["Columbus", "Cleveland", "Cincinnati"]),
            LaunchRegion(name: "Oklahoma", cities: ["Oklahoma City", "Tulsa", "Norman"]),
            LaunchRegion(name: "Oregon", cities: ["Portland", "Eugene", "Salem"]),
            LaunchRegion(name: "Pennsylvania", cities: ["Philadelphia", "Pittsburgh", "Allentown"]),
            LaunchRegion(name: "Rhode Island", cities: ["Providence", "Warwick", "Cranston"]),
            LaunchRegion(name: "South Carolina", cities: ["Charleston", "Columbia", "Greenville"]),
            LaunchRegion(name: "South Dakota", cities: ["Sioux Falls", "Rapid City", "Aberdeen"]),
            LaunchRegion(name: "Tennessee", cities: ["Nashville", "Memphis", "Knoxville"]),
            LaunchRegion(name: "Texas", cities: ["Austin", "Dallas", "Houston", "San Antonio"]),
            LaunchRegion(name: "Utah", cities: ["Salt Lake City", "West Valley City", "Provo"]),
            LaunchRegion(name: "Vermont", cities: ["Burlington", "South Burlington", "Rutland"]),
            LaunchRegion(name: "Virginia", cities: ["Virginia Beach", "Richmond", "Norfolk"]),
            LaunchRegion(name: "Washington", cities: ["Seattle", "Spokane", "Tacoma"]),
            LaunchRegion(name: "West Virginia", cities: ["Charleston", "Huntington", "Morgantown"]),
            LaunchRegion(name: "Wisconsin", cities: ["Milwaukee", "Madison", "Green Bay"]),
            LaunchRegion(name: "Wyoming", cities: ["Cheyenne", "Casper", "Laramie"])
        ]),
        LaunchCountry(code: "CA", name: "Canada", regionLabel: "Province", regions: [
            LaunchRegion(name: "Alberta", cities: ["Calgary", "Edmonton"]),
            LaunchRegion(name: "British Columbia", cities: ["Vancouver", "Victoria", "Kelowna"]),
            LaunchRegion(name: "Ontario", cities: ["Toronto", "Ottawa", "Hamilton", "Mississauga"]),
            LaunchRegion(name: "Quebec", cities: ["Montreal", "Quebec City", "Laval"])
        ]),
        LaunchCountry(code: "GB", name: "United Kingdom", regionLabel: "Nation", regions: [
            LaunchRegion(name: "England", cities: ["London", "Manchester", "Birmingham", "Leeds"]),
            LaunchRegion(name: "Northern Ireland", cities: ["Belfast", "Derry"]),
            LaunchRegion(name: "Scotland", cities: ["Glasgow", "Edinburgh", "Aberdeen"]),
            LaunchRegion(name: "Wales", cities: ["Cardiff", "Swansea", "Newport"])
        ]),
        LaunchCountry(code: "IE", name: "Ireland", regionLabel: "Province", regions: [
            LaunchRegion(name: "Connacht", cities: ["Galway", "Sligo"]),
            LaunchRegion(name: "Leinster", cities: ["Dublin", "Kilkenny", "Wexford"]),
            LaunchRegion(name: "Munster", cities: ["Cork", "Limerick", "Waterford"]),
            LaunchRegion(name: "Ulster", cities: ["Donegal", "Cavan", "Monaghan"])
        ]),
        LaunchCountry(code: "AU", name: "Australia", regionLabel: "State or territory", regions: [
            LaunchRegion(name: "New South Wales", cities: ["Sydney", "Newcastle", "Wollongong"]),
            LaunchRegion(name: "Queensland", cities: ["Brisbane", "Gold Coast", "Cairns"]),
            LaunchRegion(name: "Victoria", cities: ["Melbourne", "Geelong"]),
            LaunchRegion(name: "Western Australia", cities: ["Perth", "Fremantle"])
        ]),
        LaunchCountry(code: "NZ", name: "New Zealand", regionLabel: "Region", regions: [
            LaunchRegion(name: "Auckland", cities: ["Auckland", "Manukau", "North Shore"]),
            LaunchRegion(name: "Canterbury", cities: ["Christchurch", "Timaru"]),
            LaunchRegion(name: "Otago", cities: ["Dunedin", "Queenstown"]),
            LaunchRegion(name: "Wellington", cities: ["Wellington", "Lower Hutt", "Porirua"])
        ]),
        LaunchCountry(code: "ZA", name: "South Africa", regionLabel: "Province", regions: [
            LaunchRegion(name: "Gauteng", cities: ["Johannesburg", "Pretoria", "Soweto"]),
            LaunchRegion(name: "KwaZulu-Natal", cities: ["Durban", "Pietermaritzburg"]),
            LaunchRegion(name: "Western Cape", cities: ["Cape Town", "Stellenbosch", "George"])
        ])
    ]

    static func citySuggestions(
        countryCode: String,
        regionName: String,
        query: String,
        limit: Int
    ) -> [LocationCitySuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty,
              let country = countries.first(where: { $0.code == countryCode }) else { return [] }

        let normalizedQuery = trimmedQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let regions = regionName.isEmpty
            ? country.regions
            : country.regions.filter { $0.name == regionName }
        return regions
            .flatMap { region in region.cities.map { (region: region, city: $0) } }
            .filter { item in
                let normalizedCity = item.city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return normalizedCity.hasPrefix(normalizedQuery) || normalizedCity.contains(normalizedQuery)
            }
            .sorted { lhs, rhs in
                let normalizedLeft = lhs.city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let normalizedRight = rhs.city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let leftStarts = normalizedLeft.hasPrefix(normalizedQuery)
                let rightStarts = normalizedRight.hasPrefix(normalizedQuery)
                if leftStarts != rightStarts { return leftStarts }
                return lhs.city < rhs.city
            }
            .prefix(limit)
            .map { item in
                LocationCitySuggestion(
                    canonicalID: nil,
                    city: item.city,
                    region: item.region.name,
                    countryCode: country.code,
                    countryName: country.name,
                    population: nil
                )
            }
    }
}
