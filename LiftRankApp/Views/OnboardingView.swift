import PhotosUI
import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0
    @State private var goals: Set<String> = ["Get stronger", "Compare with my weight class"]
    @State private var profile = MockData.demoProfile
    @State private var bench = ""
    @State private var squat = ""
    @State private var deadlift = ""
    @State private var press = ""
    @State private var photoItem: PhotosPickerItem?
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

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                topBar

                TabView(selection: $step) {
                    welcome.tag(0)
                    goalsView.tag(1)
                    profileView.tag(2)
                    recordsView.tag(3)
                    ratingView.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: step)

                controls
            }
        }
        .interactiveDismissDisabled()
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                if step > 0 {
                    Button {
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

                Button("Skip") { complete() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 42)
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
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()

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

            Spacer()
        }
        .padding(.horizontal, 20)
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
                                    .foregroundStyle(.white)
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }

                            Spacer()

                            Image(systemName: goals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(goals.contains(goal) ? Color.liftBlue : Color.white.opacity(0.18))
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

                PhotosPicker(selection: $photoItem, matching: .images) {
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
                    field("Display name", text: $profile.displayName, symbol: "person.fill")
                    labeledPicker("Age group", symbol: "calendar") {
                        Picker("Age group", selection: $profile.ageGroup) {
                            ForEach(ageGroups, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    labeledPicker("Sex category", symbol: "person.2.fill") {
                        Picker("Sex category", selection: $profile.sexCategory) {
                            ForEach(SexCategory.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }

                profileSection("Ranking details") {
                    NumericInputField(title: "Bodyweight", value: $profile.bodyweightPounds, unit: "lb", presentation: .inset)
                    NumericInputField(title: "Height", value: $profile.heightInches, unit: "in", presentation: .inset)
                    IntegerInputField(title: "Training experience", value: $profile.yearsExperience, unit: "years", presentation: .inset)
                    labeledPicker("Preferred unit", symbol: "scalemass.fill") {
                        Picker("Preferred unit", selection: $profile.preferredUnit) {
                            ForEach(UnitSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                }

                profileSection("Home gym") {
                    field("City", text: $profile.city, symbol: "mappin")
                    field("State", text: $profile.state, symbol: "map")
                    labeledPicker("Primary gym", symbol: "building.2.fill") {
                        Picker("Primary gym", selection: $profile.primaryGymName) {
                            ForEach(MockData.crunchGyms) { gym in
                                Text("\(gym.name) - \(gym.city), \(gym.state)").tag(gym.name)
                            }
                        }
                        .onChange(of: profile.primaryGymName) { _, newValue in
                            if let gym = MockData.gyms.first(where: { $0.name == newValue }) {
                                profile.primaryGymID = gym.id
                                profile.city = gym.city
                                profile.state = gym.state
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

                    Text("ADVANCED")
                        .font(.headline.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(Color.liftGreen)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.liftGreen.opacity(0.12))
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
                    resultCard("#4", "Gym rank", "building.2.fill", .liftGold)
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
            PrimaryButton(
                title: step == 4 ? "Enter LiftRank" : nextButtonTitle,
                symbolName: step == 4 ? "arrow.right" : "chevron.right"
            ) {
                if step == 4 {
                    appState.updateProfile(profile)
                    Haptics.success()
                    complete()
                } else {
                    withAnimation(.snappy) { step += 1 }
                }
            }

            if step == 3 {
                Button("I’ll add my lifts later") {
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
        .background(.ultraThinMaterial)
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
