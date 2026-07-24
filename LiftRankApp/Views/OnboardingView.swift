import SwiftUI
import UIKit
import MapKit

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0
    @State private var goals: Set<String> = ["Get stronger", "Compare with my weight class"]
    @State private var profile = MockData.emptyProfile
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    @State private var isSavingProfile = false
    @State private var saveError: String?
    @State private var bench = ""
    @State private var squat = ""
    @State private var deadlift = ""
    @State private var press = ""
    @State private var showingPhotoManager = false
    @State private var selectedCountryCode = ""
    @State private var selectedRegionName = ""
    @State private var selectedCity = ""
    @State private var cityQuery = ""
    @StateObject private var citySearch = CitySearchController()
    let complete: () -> Void

    private let ageGroups = MockData.standardAgeGroups
    private let goalOptions = [
        ("Get stronger", "bolt.fill", "Build measurable strength"),
        ("Compete locally", "medal.fill", "Prepare for the platform"),
        ("Track personal records", "chart.line.uptrend.xyaxis", "See progress over time"),
        ("Compare with my weight class", "person.2.fill", "Rank against similar lifters"),
        ("Represent my gym", "building.2.fill", "Climb your local leaderboard"),
        ("Prepare for powerlifting", "figure.strengthtraining.traditional", "Train the competition lifts")
    ]
    private let launchCountries = LaunchLocationCatalog.countries

    private var selectedCountry: LaunchCountry? {
        launchCountries.first { $0.code == selectedCountryCode }
    }

    private var selectedRegion: LaunchRegion? {
        selectedCountry?.regions.first { $0.name == selectedRegionName }
    }

    private var onboardingScoreTier: (label: String, tint: Color) {
        switch appState.overallScore {
        case 80...:
            return ("ELITE", .liftGold)
        case 60..<80:
            return ("ADVANCED", .liftGreen)
        case 35..<60:
            return ("INTERMEDIATE", .liftBlue)
        case 15..<35:
            return ("NOVICE", .liftPurple)
        default:
            return ("BEGINNER", .liftMuted)
        }
    }

    var body: some View {
        AppBackground {
            TabView(selection: $step) {
                welcome.tag(0)
                goalsView.tag(1)
                profileView.tag(2)
                recordsView.tag(3)
                ratingView.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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
        .onAppear {
            profile = appState.currentProfile
            profile.username = ""
            profile.displayName = ""
            selectedCountryCode = ""
            selectedRegionName = ""
            selectedCity = ""
            cityQuery = ""
            profile.city = ""
            profile.state = ""
            normalizeSelectedGym()
        }
        .onChange(of: appState.gyms.map(\.id)) { _, _ in normalizeSelectedGym() }
        .sheet(isPresented: $showingPhotoManager, onDismiss: {
            profile.avatarPath = appState.currentProfile.avatarPath
        }) {
            ProfilePhotoManagerView()
                .environmentObject(appState)
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

                Spacer()

                if appState.isDemoMode {
                    Button("Skip") { complete() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(width: 42)
                } else {
                    Color.clear.frame(width: 42)
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
                                colors: [.white, Color.liftBlue],
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
                        .foregroundStyle(Color.liftBlue)
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
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func onboardingStat(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(Color.liftBlue)
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

    private var heightSlider: some View {
        sliderField(
            title: "Height",
            value: formattedHeight,
            symbol: "ruler",
            rangeLabel: "4'0\" – 7'0\""
        ) {
            Slider(value: $profile.heightInches, in: 48...84, step: 1)
        }
    }

    private var formattedHeight: String {
        let totalInches = Int(profile.heightInches.rounded())
        return "\(totalInches / 12)'\(totalInches % 12)\""
    }

    private var trainingExperienceSlider: some View {
        sliderField(
            title: "Training experience",
            value: "\(profile.yearsExperience) \(profile.yearsExperience == 1 ? "year" : "years")",
            symbol: "calendar.badge.clock",
            rangeLabel: "New – 30 years"
        ) {
            Slider(
                value: Binding(
                    get: { Double(profile.yearsExperience) },
                    set: { profile.yearsExperience = Int($0.rounded()) }
                ),
                in: 0...30,
                step: 1
            )
        }
    }

    private func sliderField<Content: View>(
        title: String,
        value: String,
        symbol: String,
        rangeLabel: String,
        @ViewBuilder slider: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(Color.liftMuted)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.bold))
            }
            slider()
                .tint(Color.liftBlue)
            Text(rangeLabel)
                .font(.caption2)
                .foregroundStyle(Color.liftMuted)
        }
        .padding(15)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var goalsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader(
                    eyebrow: "YOUR TRAINING",
                    title: "What are you working toward?",
                    subtitle: "Choose as many as you want. We’ll shape your LiftRank experience around them."
                )

                ForEach(goalOptions, id: \.0) { goal, symbol, subtitle in
                    Button {
                        Haptics.light()
                        if goals.contains(goal) {
                            goals.remove(goal)
                        } else {
                            goals.insert(goal)
                        }
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(goals.contains(goal) ? Color.liftBackground : Color.liftBlue)
                                .frame(width: 46, height: 46)
                                .background(goals.contains(goal) ? Color.liftBlue : Color.liftBlue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal)
                                    .font(.headline)
                                    .foregroundStyle(Color.liftText)
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }

                            Spacer()

                            Image(systemName: goals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(goals.contains(goal) ? Color.liftBlue : Color.liftMuted.opacity(0.55))
                        }
                        .padding(15)
                        .background(goals.contains(goal) ? Color.liftBlue.opacity(0.10) : Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(goals.contains(goal) ? Color.liftBlue.opacity(0.75) : Color.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var profileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenHeader(
                    eyebrow: "YOUR PROFILE",
                    title: "Build your lifter profile.",
                    subtitle: "Your bodyweight and category make rankings fair and useful."
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
                                    .foregroundStyle(Color.liftBackground)
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
                    field("Username", text: $profile.username, symbol: "at")
                    labeledPicker("Birth date", symbol: "calendar") {
                        DatePicker(
                            "Birth date",
                            selection: $birthDate,
                            in: ...Calendar.current.date(byAdding: .year, value: -13, to: .now)!,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                    labeledPicker("Sex category", symbol: "person.2.fill") {
                        Picker("Sex category", selection: $profile.sexCategory) {
                            ForEach([SexCategory.male, .female]) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                    }
                }

                profileSection("Ranking details") {
                    NumericInputField(title: "Bodyweight", value: $profile.bodyweightPounds, unit: "lb", presentation: .inset)
                    heightSlider
                    trainingExperienceSlider
                    labeledPicker("Preferred unit", symbol: "scalemass.fill") {
                        Picker("Preferred unit", selection: $profile.preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                }

                profileSection("Location") {
                    labeledPicker("Country", symbol: "globe.americas.fill") {
                        Picker("Country", selection: $selectedCountryCode) {
                            Text("Select country").tag("")
                            ForEach(launchCountries) { country in
                                Text(country.name).tag(country.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 190, alignment: .trailing)
                        .onChange(of: selectedCountryCode) { _, _ in
                            selectedRegionName = ""
                            selectedCity = ""
                            cityQuery = ""
                            citySearch.reset()
                            profile.state = ""
                            profile.city = ""
                        }
                    }

                    labeledPicker("State / province", symbol: "map.fill") {
                        Picker("State or province", selection: $selectedRegionName) {
                            Text(selectedCountry == nil ? "Choose country first" : "Select state").tag("")
                            ForEach(selectedCountry?.regions ?? []) { region in
                                Text(region.name).tag(region.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 190, alignment: .trailing)
                        .disabled(selectedCountry == nil)
                        .onChange(of: selectedRegionName) { _, newValue in
                            selectedCity = ""
                            cityQuery = ""
                            citySearch.reset()
                            profile.state = newValue
                            profile.city = ""
                        }
                    }

                    citySearchField
                    if !appState.gyms.isEmpty {
                        labeledPicker("Primary gym (optional)", symbol: "building.2.fill") {
                            Picker("Primary gym", selection: $profile.primaryGymName) {
                                Text("Choose later").tag("")
                                ForEach(appState.gyms) { gym in
                                    Text("\(gym.name) - \(gym.city), \(gym.state)").tag(gym.name)
                                }
                            }
                            .onChange(of: profile.primaryGymName) { _, newValue in
                                if let gym = appState.gyms.first(where: { $0.name == newValue }) {
                                    profile.primaryGymID = gym.id
                                    selectedCity = gym.city
                                    cityQuery = gym.city
                                    profile.city = gym.city
                                    profile.state = gym.state
                                }
                            }
                        }
                    }
                }

                privacyToggles
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
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

    private var citySearchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 22)
                if selectedRegion == nil {
                    Text("City")
                        .foregroundStyle(Color.liftMuted)
                    Spacer()
                    Text("Choose state first")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)
                } else {
                    TextField("Search city", text: $cityQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: cityQuery) { _, query in
                            guard let selectedCountry, let selectedRegion else { return }
                            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                            selectedCity = trimmedQuery
                            profile.city = trimmedQuery
                            citySearch.search(
                                query: query,
                                region: selectedRegion.name,
                                country: selectedCountry.name
                            )
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

            if selectedRegion != nil, !citySearch.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(citySearch.results) { suggestion in
                        Button {
                            selectedCity = suggestion.city
                            cityQuery = suggestion.city
                            profile.city = suggestion.city
                            dismissKeyboard()
                            citySearch.reset()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.city)
                                    .font(.subheadline.weight(.semibold))
                                Text(suggestion.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != citySearch.results.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(Color.liftCardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if selectedRegion != nil, cityQuery.isEmpty {
                Text("Search for any city in \(selectedRegionName).")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .padding(.leading, 34)
            }
        }
    }

    private var privacyToggles: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Privacy controls", systemImage: "lock.shield.fill")
                    .font(.headline)
                    .foregroundStyle(Color.liftBlue)
                Toggle("Hide exact age", isOn: $profile.hideExactAge)
                Toggle("Hide exact bodyweight", isOn: $profile.hideBodyweight)
                Toggle("Hide city", isOn: $profile.hideCity)
                Toggle("Hide gym", isOn: $profile.hideGym)
                Toggle("Hide lift videos", isOn: $profile.hideLiftVideos)
            }
            .tint(Color.liftBlue)
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

                recordField("Bench press", text: $bench, symbol: "figure.strengthtraining.traditional", tint: .liftBlue)
                recordField("Back squat", text: $squat, symbol: "figure.strengthtraining.functional", tint: .liftPurple)
                recordField("Deadlift", text: $deadlift, symbol: "dumbbell.fill", tint: .liftGold)
                recordField("Overhead press", text: $press, symbol: "arrow.up.circle.fill", tint: .liftGreen)

                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.liftBlue)
                    Text("These starting numbers are private until you choose to share or verify a lift.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                .padding(15)
                .background(Color.liftBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var ratingView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 9) {
                    Text("YOUR LIFTRANK")
                        .font(.caption.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.liftBlue)
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
                    resultCard("Top 12%", "Weight class", "person.2.fill", .liftBlue)
                }

                LiftCard {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.liftGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your next milestone")
                                .font(.headline)
                            Text("Add 25 lb to your bench to reach the next tier.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
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
                title: step == 4 ? (isSavingProfile ? "Saving…" : "Enter LiftRank") : nextButtonTitle,
                symbolName: step == 4 ? "arrow.right" : "chevron.right"
            ) {
                if step == 4 {
                    dismissKeyboard()
                    saveOnboardingProfile()
                } else {
                    dismissKeyboard()
                    withAnimation(.snappy) { step += 1 }
                }
            }

            if step == 3 {
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
        let username = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            saveError = "Choose a username to continue."
            Haptics.warning()
            return
        }
        guard !selectedCountryCode.isEmpty,
              !selectedRegionName.isEmpty,
              !city.isEmpty else {
            saveError = "Choose your country, state or province, and city to continue."
            Haptics.warning()
            return
        }
        profile.city = city
        isSavingProfile = true
        saveError = nil
        let privacy = ProfilePrivacySettings(
            ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
            bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
            locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
            gymAudience: profile.hideGym ? .privateProfile : .publicProfile
        )
        let draft = ProfileDraft(
            username: username,
            displayName: username,
            bio: "",
            preferredUnit: profile.preferredUnit,
            birthDate: birthDate,
            sexCategory: profile.sexCategory,
            heightCentimeters: profile.heightInches * 2.54,
            bodyweightPounds: profile.bodyweightPounds,
            city: profile.city,
            region: profile.state,
            countryCode: selectedCountryCode,
            yearsExperience: profile.yearsExperience,
            experienceLevel: profile.experienceLevel,
            privacy: privacy,
            completesOnboarding: true
        )
        Task {
            do {
                try await appState.saveAuthenticatedProfile(draft)
                if let primaryGym = appState.gyms.first(where: { $0.id == profile.primaryGymID }) {
                    try await appState.connectOnboardingPrimaryGym(primaryGym)
                }
                Haptics.success()
                complete()
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? "Your profile could not be saved."
                Haptics.warning()
            }
            isSavingProfile = false
        }
    }

    private func normalizeSelectedGym() {
        guard !profile.primaryGymName.isEmpty,
              !appState.gyms.contains(where: { $0.id == profile.primaryGymID }) else { return }
        profile.primaryGymName = ""
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var nextButtonTitle: String {
        switch step {
        case 0: return "Build My LiftRank"
        case 1: return "Continue"
        case 2: return "Save Profile"
        case 3: return "Calculate My Rank"
        default: return "Continue"
        }
    }

    private func screenHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow)
                .font(.caption.weight(.black))
                .tracking(1.6)
                .foregroundStyle(Color.liftBlue)
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

    private func field(_ title: String, text: Binding<String>, symbol: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.liftBlue)
                .frame(width: 22)
            TextField(title, text: text)
                .keyboardType(keyboard)
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

    private func recordField(_ title: String, text: Binding<String>, symbol: String, tint: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: symbol)
                .font(.title2)
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
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title2.weight(.bold))
                    .frame(width: 72)
                Text("lb")
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
                .foregroundStyle(Color.liftBlue)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(Color.liftMuted)
            Spacer()
            content()
                .labelsHidden()
                .tint(.white)
        }
        .padding(15)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
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
            LaunchRegion(name: "Florida", cities: ["Miami", "Orlando", "Tampa", "Jacksonville"]),
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
}

private final class CitySearchController: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [CitySearchSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var expectedRegion = ""
    private var expectedCountry = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String, region: String, country: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        expectedRegion = region
        expectedCountry = country
        guard trimmedQuery.count >= 2 else {
            results = []
            return
        }
        completer.queryFragment = "\(trimmedQuery), \(region), \(country)"
    }

    func reset() {
        results = []
        expectedRegion = ""
        expectedCountry = ""
        completer.queryFragment = ""
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.compactMap { result -> CitySearchSuggestion? in
            let detail = result.subtitle
            guard detail.localizedCaseInsensitiveContains(self.expectedRegion),
                  detail.localizedCaseInsensitiveContains(self.expectedCountry) else { return nil }
            return CitySearchSuggestion(city: result.title, detail: detail)
        }
        DispatchQueue.main.async { [weak self] in
            self?.results = Array(Dictionary(grouping: suggestions, by: \.id).compactMap { $0.value.first }.prefix(8))
        }
    }
}

private struct CitySearchSuggestion: Identifiable {
    let city: String
    let detail: String

    var id: String { "\(city)|\(detail)" }
}
