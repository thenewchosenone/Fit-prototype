import SwiftUI
import UIKit

private enum OnboardingLocationPicker: String, Identifiable {
    case country, region, city
    var id: String { rawValue }
}

private struct OnboardingComparison: Equatable {
    let label: String
    let location: String
    let standing: String?
    let participantCount: Int
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0
    @State private var goals: Set<String> = []
    @State private var profile = MockData.emptyProfile
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    @State private var isSavingProfile = false
    @State private var saveError: String?
    @State private var bench = ""
    @State private var squat = ""
    @State private var deadlift = ""
    @State private var press = ""
    @State private var bio = ""
    @State private var yearsTraining = 0
    @State private var showingBodyweightPicker = false
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
    @State private var onboardingComparisons: [OnboardingComparison] = []
    @State private var isLoadingOnboardingComparisons = false
    @FocusState private var focusedRecord: String?
    let complete: () -> Void

    private var goalOptions: [(id: String, title: String, symbol: String, subtitle: String)] {
        let base = [
            ("get_stronger", "Get stronger", "bolt.fill", "Build measurable strength"),
            ("compete_locally", "Compete locally", "medal.fill", "Prepare for the platform"),
            ("track_personal_records", "Track personal records", "chart.line.uptrend.xyaxis", "See progress over time"),
            ("compare_weight_class", "Compare with my weight class", "person.2.fill", "Rank against similar lifters"),
            ("prepare_powerlifting", "Prepare for powerlifting", "figure.strengthtraining.traditional", "Train the competition lifts")
        ]
        return base + [("represent_gym", "Represent my gym", "building.2.fill", "Climb your local leaderboard")]
    }
    private let launchCountries = LaunchLocationCatalog.countries

    private var selectedCountry: LaunchCountry? {
        launchCountries.first { $0.code == selectedCountryCode }
    }

    private var selectedRegion: LaunchRegion? {
        selectedCountry?.regions.first { $0.name == selectedRegionName }
    }

    private var onboardingGyms: [Gym] {
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = selectedRegionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty, !region.isEmpty else { return [] }

        return appState.gyms
            .filter {
                $0.city.localizedCaseInsensitiveCompare(city) == .orderedSame &&
                $0.state.localizedCaseInsensitiveCompare(region) == .orderedSame
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func ageGroup(for birthDate: Date) -> String {
        ProfileDisplayFormatting.ageGroup(for: birthDate)
    }

    private var onboardingScoreTier: (label: String, tint: Color) {
        RankingFormatting.strengthTier(for: appState.overallScore)
    }

    private var hasCompletePowerliftingTotal: Bool {
        [bench, squat, deadlift].allSatisfy { Double($0) ?? 0 > 0 }
    }

    private var onboardingPreviewKey: String {
        guard step == 4 else { return "inactive" }
        return [selectedCity, selectedRegionName, selectedCountryCode, bench, squat, deadlift, profile.preferredUnit.rawValue].joined(separator: "|")
    }

    private var onboardingTotalKilograms: Double? {
        guard hasCompletePowerliftingTotal else { return nil }
        let values = [bench, squat, deadlift].compactMap(Double.init)
        let total = values.reduce(0, +)
        return profile.preferredUnit == .pounds
            ? RankingCalculator.poundsToKilograms(total)
            : total
    }

    var body: some View {
        AppBackground {
            Group {
                switch step {
                case 0: welcome
                case 1: goalsView
                case 2: profileView
                case 3: recordsView
                default: ratingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.snappy, value: step)
            .safeAreaInset(edge: .top, spacing: 0) {
                topBar
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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear {
            profile = appState.currentProfile
            profile.username = AppleIdentityStore.usernameSuggestion(from: appState.pendingAppleFullName) ?? ""
            profile.displayName = ""
            profile.hideExactAge = false
            profile.hideBodyweight = false
            profile.hideCity = false
            profile.hideGym = false
            profile.hideLiftVideos = false
            bio = profile.bio ?? ""
            yearsTraining = max(0, profile.yearsExperience)
            if profile.bodyweightPounds <= 0 {
                profile.bodyweightPounds = 180
            }
            if profile.heightInches < 48 || profile.heightInches > 84 {
                profile.heightInches = 70
            }
            profile.ageGroup = ageGroup(for: birthDate)
            selectedCountryCode = ""
            selectedRegionName = ""
            selectedCity = ""
            selectedCityID = nil
            cityQuery = ""
            citySuggestions = []
            profile.city = ""
            profile.state = ""
            normalizeSelectedGym()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTestingPrefilledOnboarding") {
                profile.username = "launch_lifter"
                profile.displayName = "Launch Lifter"
                profile.bodyweightPounds = 180
                profile.heightInches = 70
                profile.sexCategory = .male
                selectedCountryCode = "US"
                selectedRegionName = "Florida"
                selectedCity = "Miami"
                cityQuery = "Miami"
                profile.city = "Miami"
                profile.state = "Florida"
            }
#endif
        }
        .onChange(of: appState.gyms.map(\.id)) { _, _ in normalizeSelectedGym() }
        .sheet(isPresented: $showingPhotoManager, onDismiss: {
            profile.avatarPath = appState.currentProfile.avatarPath
        }) {
            ProfilePhotoManagerView()
                .environmentObject(appState)
        }
        .sheet(item: $locationPicker) { picker in
            locationPickerSheet(picker)
        }
        .task(id: onboardingPreviewKey) {
            await loadOnboardingComparisons()
        }
        .task {
            await appState.refreshRemoteSocialState()
        }
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                if step > 0 {
                    Button {
                        dismissKeyboard()
                        withAnimation(.snappy) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .background(Color.liftCard)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Previous step")
                } else {
                    Color.clear.frame(width: 42, height: 42)
                }

                Spacer()

                Text("STEP \(step + 1) OF 5")
                    .font(.caption.weight(.bold))
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
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("Sign out")
                    .disabled(appState.accountOperationInProgress)
                }
            }

            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.liftBlue : Color.white.opacity(0.10))
                        .frame(height: 5)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.liftBlue.opacity(0.13))
                        .frame(width: 150, height: 150)
                        .blur(radius: 3)
                    Circle()
                        .stroke(Color.liftBlue.opacity(0.30), lineWidth: 1)
                        .frame(width: 126, height: 126)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 62, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.liftText, Color.liftBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    Text("KNOW YOUR STRENGTH")
                        .font(.caption.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.liftAccentText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("Turn every lift into a ranking.")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Track your best lifts, compare with lifters like you, and see exactly what to improve next.")
                        .font(.title3)
                        .foregroundStyle(Color.liftMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    onboardingStat("bolt.fill", "Strength score")
                    onboardingStat("trophy.fill", "Real rankings")
                    onboardingStat("chart.bar.fill", "Clear progress")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 124)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func onboardingStat(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(Color.liftAccentText)
            Text(title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.liftCard.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var bodyweightField: some View {
        Button { showingBodyweightPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 22)

                Text("Bodyweight")
                    .foregroundStyle(Color.liftMuted)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(profile.bodyweightPounds > 0 ? bodyweightInputText(for: profile.bodyweightPounds, unit: profile.preferredUnit) : "—")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                }

                Text(profile.preferredUnit.shortLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.bodyweight")
        .accessibilityLabel("Bodyweight")
        .padding(15)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .sheet(isPresented: $showingBodyweightPicker) {
            NavigationStack {
                Picker("Bodyweight", selection: bodyweightPickerBinding) {
                    ForEach(bodyweightPickerRange, id: \.self) { value in
                        Text(value == 0 ? "Not set" : "\(value) \(profile.preferredUnit.shortLabel)")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .navigationTitle("Bodyweight (\(profile.preferredUnit.shortLabel))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingBodyweightPicker = false }
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }

    private var bodyweightPickerRange: ClosedRange<Int> {
        profile.preferredUnit == .pounds ? 0...500 : 0...225
    }

    private var bodyweightPickerBinding: Binding<Int> {
        Binding(
            get: {
                let value = MeasurementFormatting.convert(
                    profile.bodyweightPounds,
                    from: .pounds,
                    to: profile.preferredUnit
                )
                return min(max(Int(value.rounded()), bodyweightPickerRange.lowerBound), bodyweightPickerRange.upperBound)
            },
            set: { value in
                profile.bodyweightPounds = MeasurementFormatting.convert(
                    Double(value),
                    from: profile.preferredUnit,
                    to: .pounds
                )
            }
        )
    }

    private func bodyweightInputText(for pounds: Double, unit: UnitSystem) -> String {
        guard pounds > 0 else { return "" }
        let value = MeasurementFormatting.convert(pounds, from: .pounds, to: unit)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var heightScroller: some View {
        Button { showingHeightPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "ruler")
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 22)
                Text("Height")
                    .foregroundStyle(Color.liftMuted)
                Spacer()
                Text(formattedHeight)
                    .font(.subheadline.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(15)
        }
        .buttonStyle(.plain)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .sheet(isPresented: $showingHeightPicker) {
            NavigationStack {
                Picker("Height", selection: Binding(
                    get: { Int(profile.heightInches.rounded()) },
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
        return "\(totalInches / 12)'\(totalInches % 12)\""
    }

    private var goalsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    eyebrow: "YOUR TRAINING",
                    title: "What are you working toward?",
                    subtitle: "Choose what matters to you. This helps us decide what to build and improve."
                )

                ForEach(goalOptions, id: \.id) { option in
                    Button {
                        Haptics.light()
                        if goals.contains(option.id) {
                            goals.remove(option.id)
                        } else {
                            goals.insert(option.id)
                        }
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: option.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(goals.contains(option.id) ? Color.liftOnAccent : Color.liftAccentText)
                                .frame(width: 46, height: 46)
                                .background(goals.contains(option.id) ? Color.liftBlue : Color.liftBlue.opacity(0.12))
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

                            Image(systemName: goals.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(goals.contains(option.id) ? Color.liftAccentText : Color.liftMuted.opacity(0.55))
                        }
                        .padding(15)
                        .background(goals.contains(option.id) ? Color.liftBlue.opacity(0.10) : Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(goals.contains(option.id) ? Color.liftBlue.opacity(0.75) : Color.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 124)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var profileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenHeader(
                    eyebrow: "YOUR PROFILE",
                    title: "Build your lifter profile.",
                    subtitle: "Username, bodyweight, and location are required. Your details make rankings fair and useful."
                )

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

                profileSection("Identity") {
                    field("Username", text: $profile.username, symbol: "at", disablesSuggestions: true)
                    field("Bio (optional)", text: $bio, symbol: "text.quote")
                    labeledPicker("Birth date", symbol: "calendar") {
                        DatePicker(
                            "Birth date",
                            selection: $birthDate,
                            in: ...Calendar.current.date(byAdding: .year, value: -13, to: .now)!,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .onChange(of: birthDate) { _, newValue in
                            profile.ageGroup = ageGroup(for: newValue)
                        }
                    }
                    labeledPicker("Gender", symbol: "person.2.fill") {
                        Picker("Gender", selection: $profile.sexCategory) {
                            ForEach([SexCategory.male, .female]) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                    }
                }

                profileSection("Ranking details") {
                    bodyweightField
                    heightScroller
                    labeledPicker("Years training", symbol: "calendar.badge.clock") {
                        HStack(spacing: 0) {
                            Button {
                                dismissKeyboard()
                                yearsTraining = max(0, yearsTraining - 1)
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 38, height: 36)
                            }
                            .disabled(yearsTraining == 0)
                            .accessibilityLabel("Decrease years training")
                            .accessibilityIdentifier("onboarding.yearsTraining.decrement")

                            Divider()
                                .frame(height: 22)

                            Text("\(yearsTraining)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .frame(minWidth: 34)
                                .accessibilityIdentifier("onboarding.yearsTraining.value")

                            Divider()
                                .frame(height: 22)

                            Button {
                                dismissKeyboard()
                                yearsTraining = min(100, yearsTraining + 1)
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 38, height: 36)
                            }
                            .disabled(yearsTraining == 100)
                            .accessibilityLabel("Increase years training")
                            .accessibilityIdentifier("onboarding.yearsTraining.increment")
                        }
                        .foregroundStyle(Color.liftText)
                        .padding(.horizontal, 8)
                        .background(Color.liftCardRaised)
                        .clipShape(Capsule())
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("onboarding.yearsTraining")
                    }
                    labeledPicker("Preferred unit", symbol: "scalemass.fill") {
                        Picker("Preferred unit", selection: $profile.preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                }

                profileSection("Location") {
                    locationPickerRow("Country", value: selectedCountry?.name ?? "Select country", symbol: "globe.americas.fill", picker: .country)
                    locationPickerRow("State / province", value: selectedCountry == nil ? "Choose country first" : (selectedRegionName.isEmpty ? "Select state" : selectedRegionName), symbol: "map.fill", picker: .region, disabled: selectedCountry == nil)
                    locationPickerRow("City", value: selectedRegion == nil ? "Choose state first" : (selectedCity.isEmpty ? "Select city" : selectedCity), symbol: "mappin.and.ellipse", picker: .city, disabled: selectedRegion == nil)
                    labeledPicker("Primary gym (optional)", symbol: "building.2.fill") {
                        if selectedCity.isEmpty {
                            Text("Choose your city first")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        } else if onboardingGyms.isEmpty {
                            Text("No gyms available in \(selectedCity)")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        } else {
                            Picker("Primary gym", selection: $profile.primaryGymName) {
                                Text("Choose later").tag("")
                                ForEach(onboardingGyms) { gym in
                                    Text("\(gym.name) - \(gym.city), \(gym.state)").tag(gym.name)
                                }
                            }
                            .accessibilityIdentifier("onboarding.gym")
                            .onChange(of: profile.primaryGymName) { _, newValue in
                                if let gym = onboardingGyms.first(where: { $0.name == newValue }) {
                                    profile.primaryGymID = gym.id
                                }
                            }
                        }
                    }
                }

                privacyToggles
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 124)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func profileSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
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
        Button { locationPicker = picker } label: {
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
                    .font(.caption.weight(.bold))
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
                    TextField("Search cities in \(selectedRegionName)", text: $cityQuery)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding()
                        .onChange(of: cityQuery) { _, query in searchCities(matching: query) }
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
                        Text("Select state").tag("")
                        ForEach(selectedCountry?.regions ?? []) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.wheel)
                    .onChange(of: selectedRegionName) { _, value in
                        resetCitySelection()
                        profile.state = value
                    }
                case .city:
                    if cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || citySuggestions.isEmpty {
                        ContentUnavailableView(
                            cityQuery.count < 2 ? "Search for a city" : "No matching cities",
                            systemImage: "mappin.and.ellipse"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(citySuggestions) { suggestion in
                                    Button {
                                        selectCity(suggestion)
                                        locationPicker = nil
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(suggestion.city)
                                                    .font(.body.weight(.semibold))
                                                Text(suggestion.displayDetail)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.liftMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.liftMuted)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if suggestion.id != citySuggestions.last?.id {
                                        Divider().padding(.leading)
                                    }
                                }
                            }
                        }
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
        .presentationDetents([.height(picker == .city ? 390 : 300)])
    }

    private var citySearchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.liftAccentText)
                    .frame(width: 22)
                if selectedRegion == nil {
                    Text("City")
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    Text("Choose state first")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("City")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                        TextField("Search city", text: $cityQuery)
                            .accessibilityIdentifier("onboarding.city")
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: cityQuery) { _, query in
                                searchCities(matching: query)
                            }
                    }
                }
            }
            .padding(15)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }

            if selectedRegion != nil, !citySuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(citySuggestions) { suggestion in
                        Button {
                            selectCity(suggestion)
                            dismissKeyboard()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(suggestion.city)
                                        .font(.subheadline.weight(.semibold))
                                    Text(suggestion.displayDetail)
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer()
                                if selectedCity == suggestion.city {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.liftAccentText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)

                        if suggestion != citySuggestions.last {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(Color.liftCardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if selectedRegion != nil, cityQuery.isEmpty {
                Text("Start typing, then choose a city from \(selectedRegionName).")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.leading, 34)
            } else if isSearchingCities {
                Text("Searching cities…")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.leading, 34)
            } else if selectedRegion != nil, !cityQuery.isEmpty, selectedCity.isEmpty {
                Text("Choose one of the available cities to continue.")
                    .font(.caption)
                    .foregroundStyle(Color.liftRed)
                    .padding(.leading, 34)
            }
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
        selectedCity = suggestion.city
        selectedCityID = suggestion.canonicalID
        cityQuery = suggestion.city
        citySuggestions = []
        profile.city = suggestion.city
        profile.state = suggestion.region
        selectedRegionName = suggestion.region
        selectedCountryCode = suggestion.countryCode
        normalizeSelectedGym()
    }

    private func searchCities(matching query: String) {
        citySearchTask?.cancel()
        selectedCity = ""
        selectedCityID = nil
        profile.city = ""

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
                Label("Privacy controls", systemImage: "lock.shield.fill")
                    .font(.headline)
                    .foregroundStyle(Color.liftAccentText)
                Toggle("Hide exact age", isOn: $profile.hideExactAge)
                Toggle("Hide exact bodyweight", isOn: $profile.hideBodyweight)
                Toggle("Hide city", isOn: $profile.hideCity)
                Toggle("Hide gym", isOn: $profile.hideGym)
                Toggle("Hide lift videos", isOn: $profile.hideLiftVideos)
            }
            .tint(Color.liftAccentText)
        }
    }

    private var recordsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    eyebrow: "FIRST RANK",
                    title: "What are your best lifts?",
                    subtitle: "Enter a current one-rep max. Leave anything blank if you don’t know it yet."
                )

                recordField("Bench press", text: $bench, badge: "BP", tint: .liftAccentText)
                recordField("Back squat", text: $squat, badge: "SQ", tint: .liftPurple)
                recordField("Deadlift", text: $deadlift, badge: "DL", tint: .liftGold)
                recordField("Overhead press", text: $press, badge: "OHP", tint: .liftGreen)

                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.liftAccentText)
                    Text("These starting numbers are private until you choose to share or verify a lift.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(15)
                .background(Color.liftBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 124)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var ratingView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 9) {
                    Text("YOUR LIFT RIVALS")
                        .font(.caption.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.liftAccentText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("You’re ready to compete.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("This is your starting point. Every verified lift can move you up.")
                        .foregroundStyle(Color.liftMuted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: min(1, appState.overallScore / 100))
                            .stroke(
                                AngularGradient(
                                    colors: [Color.liftBlue, .cyan, Color.liftPurple, Color.liftBlue],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(Int(appState.overallScore))")
                                .font(.system(size: 58, weight: .black, design: .rounded))
                            Text("STRENGTH SCORE")
                                .font(.caption2.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                    .frame(width: 190, height: 190)

                    Text(onboardingScoreTier.label)
                        .font(.headline.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(onboardingScoreTier.tint)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(onboardingScoreTier.tint.opacity(0.12))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: [Color.liftCardRaised, Color.liftCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.liftBlue.opacity(0.25), lineWidth: 1)
                }

                HStack(spacing: 12) {
                    resultCard("Unranked", "Global rank", "chart.line.uptrend.xyaxis", .liftGold)
                    resultCard("Unranked", "Weight class", "person.2.fill", .liftBlue)
                }

                LiftCard {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.liftGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your next milestone")
                                .font(.headline)
                            Text("Submit more lifts to unlock your next strength milestone.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                }

                onboardingComparisonCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 124)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var onboardingComparisonCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Unverified starting comparison", systemImage: "chart.bar.xaxis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.liftAccentText)
                Text("Estimated standing from your starting lifts. These numbers do not affect official rankings until your lifts are verified.")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)

                if onboardingComparisons.isEmpty {
                    Text(hasCompletePowerliftingTotal ? "Loading local comparisons…" : "Enter bench press, back squat, and deadlift to see your estimated standing.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    ForEach(onboardingComparisons, id: \.label) { comparison in
                        HStack(spacing: 12) {
                            Image(systemName: comparison.label == "City" ? "mappin.and.ellipse" : "globe.americas.fill")
                                .foregroundStyle(Color.liftBlue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comparison.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(comparison.location)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            Spacer()
                            if comparison.standing != nil {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(comparison.standing ?? "—")
                                        .font(.headline.weight(.black))
                                    Text("of \(comparison.participantCount)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            } else if isLoadingOnboardingComparisons {
                                ProgressView()
                                    .tint(Color.liftAccentText)
                            } else {
                                Text("No data yet")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private func loadOnboardingComparisons() async {
        guard step == 4, let totalKilograms = onboardingTotalKilograms else {
            onboardingComparisons = []
            isLoadingOnboardingComparisons = false
            return
        }

        isLoadingOnboardingComparisons = true
        let cityFilters = LeaderboardFilters(
            rankingType: .total,
            city: selectedCity,
            state: selectedRegionName,
            country: selectedCountryCode
        )
        let stateFilters = LeaderboardFilters(
            rankingType: .total,
            state: selectedRegionName,
            country: selectedCountryCode
        )
        let countryFilters = LeaderboardFilters(
            rankingType: .total,
            country: selectedCountryCode
        )

        async let cityEntries = appState.onboardingLeaderboardPreview(filters: cityFilters)
        async let stateEntries = appState.onboardingLeaderboardPreview(filters: stateFilters)
        async let countryEntries = appState.onboardingLeaderboardPreview(filters: countryFilters)
        let results = await (cityEntries, stateEntries, countryEntries)

        onboardingComparisons = [
            makeOnboardingComparison(label: "City", location: selectedCity, entries: results.0, totalKilograms: totalKilograms),
            makeOnboardingComparison(label: "State", location: selectedRegionName, entries: results.1, totalKilograms: totalKilograms),
            makeOnboardingComparison(label: "Country", location: selectedCountry?.name ?? selectedCountryCode, entries: results.2, totalKilograms: totalKilograms)
        ]
        isLoadingOnboardingComparisons = false
    }

    private func makeOnboardingComparison(
        label: String,
        location: String,
        entries: [LeaderboardEntry],
        totalKilograms: Double
    ) -> OnboardingComparison {
        guard !entries.isEmpty else {
            return OnboardingComparison(label: label, location: location, standing: nil, participantCount: 0)
        }
        let position = entries.filter { $0.score > totalKilograms }.count + 1
        let standing = position > entries.count ? "#\(entries.count)+" : "#\(position)"
        return OnboardingComparison(label: label, location: location, standing: standing, participantCount: entries.count)
    }

    private func resultCard(_ value: String, _ title: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.black))
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
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
                title: step == 4 ? (isSavingProfile ? "Saving…" : "Enter Lift Rivals") : nextButtonTitle,
                symbolName: step == 4 ? "arrow.right" : "chevron.right"
            ) {
                if step == 4 {
                    dismissKeyboard()
                    saveOnboardingProfile()
                } else {
                    dismissKeyboard()
                    guard step != 2 || validateProfileDetails() else { return }
                    saveError = nil
                    withAnimation(.snappy) { step += 1 }
                }
            }
            .accessibilityIdentifier("onboarding.next")

            if step == 3 && focusedRecord == nil {
                Button("I’ll add my lifts later") {
                    dismissKeyboard()
                    withAnimation(.snappy) { step += 1 }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
                .padding(.vertical, 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.liftBackground)
    }

    private func saveOnboardingProfile() {
        guard !isSavingProfile else { return }
        guard validateProfileDetails() else { return }
        let username = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.avatarPath = appState.currentProfile.avatarPath
        profile.ageGroup = ageGroup(for: birthDate)
        profile.city = city
        profile.cityID = selectedCityID
        isSavingProfile = true
        saveError = nil
        let privacy = ProfilePrivacySettings(
            ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
            bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
            locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
            gymAudience: profile.hideGym ? .privateProfile : .publicProfile,
            showLiftVideos: !profile.hideLiftVideos
        )
        let profileDraft: (Bool) -> ProfileDraft = { completesOnboarding in
            ProfileDraft(
            username: username,
            displayName: username,
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarPath: profile.avatarPath,
            preferredUnit: profile.preferredUnit,
            birthDate: birthDate,
            sexCategory: profile.sexCategory,
            heightCentimeters: profile.heightInches * 2.54,
            bodyweightPounds: profile.bodyweightPounds,
            cityID: selectedCityID,
            city: profile.city,
            region: profile.state,
            countryCode: selectedCountryCode,
            yearsExperience: yearsTraining,
            experienceLevel: appState.earnedExperienceLevel,
            privacy: privacy,
            completesOnboarding: completesOnboarding
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
            do {
                try await appState.saveAuthenticatedProfile(profileDraft(false), allowUsernameChange: true)
                try await appState.saveTrainingGoals(Array(goals).sorted())
                if let primaryGym = appState.gyms.first(where: { $0.id == profile.primaryGymID }) {
                    try? await appState.connectOnboardingPrimaryGym(primaryGym)
                }
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
                complete()
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? "Your profile could not be saved."
                Haptics.warning()
            }
            isSavingProfile = false
        }
    }

    private func validateProfileDetails() -> Bool {
        let username = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty {
            saveError = "Choose a username to continue."
        } else if profile.bodyweightPounds <= 0 {
            saveError = "Enter your current bodyweight to continue."
        } else if profile.bodyweightPounds > 1_000 {
            saveError = "Enter a bodyweight under 1,000 lb to continue."
        } else if selectedCountryCode.isEmpty || selectedRegionName.isEmpty || city.isEmpty {
            saveError = "Choose your country, state or province, and city to continue."
        } else {
            let hasBackendCanonicalCity = selectedCityID != nil
            let hasBundledCanonicalCity = selectedRegion?.cities.contains {
                $0.caseInsensitiveCompare(city) == .orderedSame
            } == true
            if !hasBackendCanonicalCity && !hasBundledCanonicalCity {
                saveError = "Choose a city from the available \(selectedRegionName) options to continue."
            } else {
                return true
            }
        }
        Haptics.warning()
        return false
    }

    private func normalizeSelectedGym() {
        guard !profile.primaryGymName.isEmpty,
              let gym = appState.gyms.first(where: { $0.id == profile.primaryGymID }),
              onboardingGyms.contains(where: { $0.id == gym.id }) else {
            profile.primaryGymName = ""
            return
        }
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

    private var nextButtonTitle: String {
        switch step {
        case 0: return "Build My Lift Rivals"
        case 1: return "Continue"
        case 2: return "Continue"
        case 3: return "Continue"
        default: return "Continue"
        }
    }

    private func screenHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow)
                .font(.caption.weight(.black))
                .tracking(1.6)
                .foregroundStyle(Color.liftAccentText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.system(size: 32, weight: .black, design: .rounded))
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel(title)
    }

    private func recordField(_ title: String, text: Binding<String>, badge: String, tint: Color) -> some View {
        HStack(spacing: 15) {
            Text(badge)
                .font(.caption.weight(.black))
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
                TextField("—", text: text)
                    .accessibilityIdentifier("onboarding.record.\(title)")
                    .keyboardType(.decimalPad)
                    .focused($focusedRecord, equals: title)
                    .multilineTextAlignment(.trailing)
                    .font(.title2.weight(.bold))
                    .frame(width: 72)
                Text(profile.preferredUnit.shortLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
        }
        .padding(16)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(text.wrappedValue.isEmpty ? Color.white.opacity(0.06) : tint.opacity(0.65), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) one-rep max")
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
