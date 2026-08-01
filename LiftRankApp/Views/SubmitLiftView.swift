import PhotosUI
import SwiftData
import SwiftUI

private enum SubmitLiftSelector: String, Identifiable {
    case exercise, gym, equipment, visibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exercise: return "Choose Exercise"
        case .gym: return "Choose Gym"
        case .equipment: return "Choose Equipment"
        case .visibility: return "Choose Visibility"
        }
    }
}

struct SubmitLiftView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var exercise = MockData.exercises[2]
    @State private var weight = 315.0
    @State private var unit: UnitSystem = .pounds
    @State private var repetitions = 1
    @State private var isActualOneRepMax = true
    @State private var bodyweight = 0.0
    @State private var performedAt = Date()
    @State private var gymID = UUID()
    @State private var equipment = EquipmentType.raw
    @State private var caption = ""
    @State private var visibility = LiftVisibility.publicLift
    @State private var requestVerification = true
    @State private var confirmsMatchedDumbbells = true
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var isPreparingVideo = false
    @State private var videoError: String?
    @State private var submissionError: String?
    @State private var gymSelectionError: String?
    @State private var showingVideoReview = false
    @State private var isVideoPickerReady = false
    @State private var showingResult = false
    @State private var submittedLift: LiftSubmission?
    @State private var isSubmitting = false
    @State private var plateLoads: [EditablePlateLoad] = []
    @State private var barbellWeight = 45.0
    @State private var plateLoadingWasEdited = false
    @State private var isSyncingPlateLoading = false
    @State private var isPlateLoadingExpanded = false
    @State private var activeSelector: SubmitLiftSelector?

    private var estimate: Double {
        isActualOneRepMax ? weight : RankingCalculator.epleyOneRepMax(weight: weight, repetitions: repetitions)
    }

    private var bodyweightDisplayValue: Binding<Double> {
        Binding(
            get: {
                MeasurementFormatting.convert(bodyweight, from: .pounds, to: appState.currentProfile.preferredUnit)
            },
            set: { newValue in
                bodyweight = MeasurementFormatting.convert(newValue, from: appState.currentProfile.preferredUnit, to: .pounds)
            }
        )
    }

    private var selectedGym: Gym? {
        appState.gyms.first { $0.id == gymID }
    }

    private var selectedMovement: CompetitiveMovement? { CompetitiveMovement.resolve(exerciseID: exercise.id) }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        liftDetailsCard
                        estimateCard
                        trainingContextCard
                        videoCard
                        plateCard
                    }
                    .padding(.horizontal, LiftDesign.screenHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitFooter
            }
            .navigationTitle("Submit Lift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingResult) {
                if let result = submittedLift {
                    LiftSubmissionResultView(lift: result) {
                        showingResult = false
                        submittedLift = nil
                        dismiss()
                    }
                    .environmentObject(appState)
                }
            }
            .sheet(item: $activeSelector) { selector in
                LeaderboardOptionSheet(
                    title: selector.title,
                    options: options(for: selector),
                    selectedID: selectedID(for: selector),
                    isSearchable: selector == .exercise || selector == .gym,
                    searchPrompt: selector == .exercise ? "Search exercises" : "Search gyms",
                    dismissOnSelection: selector != .gym
                ) { id in
                    if selector == .gym {
                        Task { await selectGym(id) }
                    } else {
                        select(id, for: selector)
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showingVideoReview) {
                VideoReviewView(videoURL: selectedVideoURL) {
                    showingVideoReview = false
                }
            }
            .onChange(of: pickerItem) { _, _ in
                prepareSelectedVideo()
            }
            .alert("Gym unavailable", isPresented: Binding(
                get: { gymSelectionError != nil },
                set: { if !$0 { gymSelectionError = nil } }
            )) {
                Button("OK", role: .cancel) { gymSelectionError = nil }
            } message: {
                Text(gymSelectionError ?? "Choose another gym.")
            }
            .onAppear {
                bodyweight = appState.currentProfile.bodyweightPounds
                unit = appState.currentProfile.preferredUnit
                gymID = appState.gyms.first(where: {
                    $0.id == appState.currentProfile.primaryGymID && appState.isGymJoined($0)
                })?.id ?? appState.gyms.first(where: { appState.isGymJoined($0) })?.id ?? UUID()
                resetPlateLoadingFromWeight()
                prepareVideoPickerAfterPresentation()
            }
            .alert("Lift not submitted", isPresented: Binding(
                get: { submissionError != nil },
                set: { if !$0 { submissionError = nil } }
            )) {
                Button("OK", role: .cancel) { submissionError = nil }
            } message: {
                Text(submissionError ?? "Try again.")
            }
            .onChange(of: unit) { oldUnit, newUnit in
                weight = MeasurementFormatting.convert(weight, from: oldUnit, to: newUnit)
                resetPlateLoadingFromWeight()
            }
            .onChange(of: weight) { _, _ in
                if !plateLoadingWasEdited {
                    resetPlateLoadingFromWeight()
                }
            }
        }
    }

    private var liftDetailsCard: some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                CompactSectionHeader(title: "Lift details", eyebrow: "Performance")
                LiftActionRow(
                    title: "Exercise",
                    subtitle: exercise.name,
                    symbolName: exerciseSymbol
                ) {
                    activeSelector = .exercise
                }
                Divider().overlay(Color.liftSeparator)
                Picker("Weight unit", selection: $unit) {
                    ForEach(UnitSystem.allCases) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Weight unit")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        NumericInputField(title: selectedMovement == .dumbbellBenchPress ? "Weight per hand" : "Weight", value: $weight, unit: unit.shortLabel, precision: 0...2, presentation: .inset)
                        IntegerInputField(title: "Reps", value: $repetitions, presentation: .inset)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        NumericInputField(title: selectedMovement == .dumbbellBenchPress ? "Weight per hand" : "Weight", value: $weight, unit: unit.shortLabel, precision: 0...2, presentation: .inset)
                        IntegerInputField(title: "Reps", value: $repetitions, presentation: .inset)
                    }
                }
                Picker("Maximum type", selection: $isActualOneRepMax) {
                    Text("Actual 1RM").tag(true)
                    Text("Estimated").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Maximum type")
                if selectedMovement == .dumbbellBenchPress {
                    Toggle("Matched dumbbell pair", isOn: $confirmsMatchedDumbbells)
                        .tint(Color.liftBlue)
                    Text("Enter the weight of one dumbbell. Both dumbbells must match for ranking eligibility.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                if isActualOneRepMax && repetitions != 1 {
                    Label("An actual 1RM must be exactly one repetition. This set will stay in history but will not rank.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.liftGold)
                }
            }
        }
    }

    private var trainingContextCard: some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                CompactSectionHeader(title: "Training context")
                NumericInputField(
                    title: "Bodyweight",
                    value: bodyweightDisplayValue,
                    unit: appState.currentProfile.preferredUnit.shortLabel,
                    precision: 0...2,
                    presentation: .inset
                )
                DatePicker("Date performed", selection: $performedAt, displayedComponents: .date)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)
                Divider().overlay(Color.liftSeparator)
                LiftActionRow(title: "Gym", subtitle: selectedGym?.name ?? "Choose a joined gym", symbolName: "building.2") {
                    activeSelector = .gym
                }
                .accessibilityIdentifier("lift.gym")
                Divider().overlay(Color.liftSeparator)
                LiftActionRow(title: "Equipment", subtitle: equipment.rawValue, symbolName: "dumbbell") {
                    activeSelector = .equipment
                }
            }
        }
    }

    private var estimateCard: some View {
        MetricCard(
            title: "Estimated max",
            value: "\(RankingCalculator.format(estimate)) \(unit.shortLabel)",
            subtitle: "\(MeasurementFormatting.recordedLiftSetTextWithX(weight: weight, unit: unit, repetitions: repetitions)) estimates a \(RankingCalculator.format(estimate)) \(unit.shortLabel) one-rep max.",
            symbolName: "function",
            tint: .liftGreen
        )
    }

    private var plateCard: some View {
        LiftCard(padding: 14, radius: 16) {
            DisclosureGroup(isExpanded: $isPlateLoadingExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Each side")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                        Spacer()
                        Button("Recalculate") {
                            plateLoadingWasEdited = false
                            resetPlateLoadingFromWeight()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftBlue)
                    }

                    NumericInputField(title: "Barbell", value: $barbellWeight, unit: unit.shortLabel, precision: 0...2, presentation: .inset)
                        .onChange(of: barbellWeight) { _, _ in
                            guard !isSyncingPlateLoading else { return }
                            plateLoadingWasEdited = true
                            updateWeightFromPlateLoading()
                        }

                    ForEach($plateLoads) { $plate in
                        HStack(spacing: 12) {
                            Text(plate.label)
                                .font(.subheadline.weight(.semibold))
                            Text("per side")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                            Spacer()
                            TextField("0", value: $plate.count, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 58)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.liftField)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .onChange(of: plate.count) { _, newValue in
                                    guard !isSyncingPlateLoading else { return }
                                    if newValue < 0 { plate.count = 0 }
                                    plateLoadingWasEdited = true
                                    updateWeightFromPlateLoading()
                                }
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plate loading")
                        .font(.headline)
                    Text("Loaded total: \(RankingCalculator.format(weight)) \(unit.shortLabel)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .tint(Color.liftBlue)
        }
    }

    private var exerciseSymbol: String {
        switch exercise.id {
        case "bench": return "figure.strengthtraining.traditional"
        case "squat": return "figure.strengthtraining.functional"
        case "deadlift": return "dumbbell.fill"
        default: return "figure.strengthtraining.traditional"
        }
    }

    private var visibilitySymbol: String {
        switch visibility {
        case .publicLift: return "globe"
        case .privateLift: return "lock"
        }
    }

    private var submissionConsequence: String {
        switch visibility {
        case .publicLift:
            return "Public lifts appear on your profile. Eligible verified results enter the next daily leaderboard update."
        case .privateLift:
            return "Private lifts stay on your profile and are excluded from public leaderboards."
        }
    }

    private func options(for selector: SubmitLiftSelector) -> [LeaderboardOption] {
        switch selector {
        case .exercise:
            return MockData.exercises.map { LeaderboardOption(id: $0.id, title: $0.name, subtitle: $0.isPowerlift ? "Powerlift" : "Exercise", symbol: $0.symbolName) }
        case .gym:
            return appState.gyms.map { gym in
                let location = [gym.city, gym.state].filter { !$0.isEmpty }.joined(separator: ", ")
                let membership = appState.isGymJoined(gym) ? "Joined" : "Tap to join"
                return LeaderboardOption(
                    id: gym.id.uuidString,
                    title: gym.name,
                    subtitle: location.isEmpty ? membership : "\(location) • \(membership)",
                    symbol: "building.2"
                )
            }
        case .equipment:
            return EquipmentType.allCases.map { LeaderboardOption(id: $0.rawValue, title: $0.rawValue, symbol: "dumbbell") }
        case .visibility:
            return LiftVisibility.allCases.map { option in
                LeaderboardOption(
                    id: option.rawValue,
                    title: option.rawValue,
                    subtitle: option == .publicLift ? "Eligible daily rankings" : "Visible only to you",
                    symbol: option == .publicLift ? "globe" : "lock"
                )
            }
        }
    }

    private func selectedID(for selector: SubmitLiftSelector) -> String {
        switch selector {
        case .exercise: return exercise.id
        case .gym: return gymID.uuidString
        case .equipment: return equipment.rawValue
        case .visibility: return visibility.rawValue
        }
    }

    private func select(_ id: String, for selector: SubmitLiftSelector) {
        switch selector {
        case .exercise:
            if let option = MockData.exercises.first(where: { $0.id == id }) { exercise = option }
        case .gym:
            break
        case .equipment:
            if let option = EquipmentType.allCases.first(where: { $0.rawValue == id }) { equipment = option }
        case .visibility:
            if let option = LiftVisibility.allCases.first(where: { $0.rawValue == id }) { visibility = option }
        }
    }

    @MainActor
    private func selectGym(_ id: String) async {
        guard let gym = appState.gyms.first(where: { $0.id.uuidString == id }) else { return }
        guard await appState.joinGymForLift(gym) else {
            gymSelectionError = appState.accountMessage ?? "This gym could not be joined. You can join up to three gyms."
            return
        }
        gymID = gym.id
        activeSelector = nil
    }

    private func prepareVideoPickerAfterPresentation() {
        guard !isVideoPickerReady else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isVideoPickerReady = true
        }
    }

    private func prepareSelectedVideo() {
        guard let pickerItem else { return }
        isPreparingVideo = true
        videoError = nil
        Task {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                let fileExtension = pickerItem.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
                let url = try await MainActor.run {
                    try appState.persistWorkoutVideo(data, fileExtension: fileExtension)
                }
                await MainActor.run {
                    selectedVideoURL = url
                    appState.uploadProgress = 0
                    isPreparingVideo = false
                    self.pickerItem = nil
                }
            } catch {
                await MainActor.run {
                    selectedVideoURL = nil
                    isPreparingVideo = false
                    videoError = "That video could not be prepared. Choose it again."
                    self.pickerItem = nil
                }
            }
        }
    }

    private func resetPlateLoadingFromWeight() {
        isSyncingPlateLoading = true
        defer { isSyncingPlateLoading = false }
        barbellWeight = unit == .pounds ? 45 : 20
        var sideWeight = max(0, (weight - barbellWeight) / 2)
        plateLoads = plateOptions.map { plateWeight in
            let count = Int(sideWeight / plateWeight)
            sideWeight -= Double(count) * plateWeight
            return EditablePlateLoad(plateWeight: plateWeight, label: "\(RankingCalculator.format(plateWeight)) \(unit.shortLabel)", count: count)
        }
    }

    private func updateWeightFromPlateLoading() {
        let sideWeight = plateLoads.reduce(0) { total, plate in
            total + (plate.plateWeight * Double(max(0, plate.count)))
        }
        weight = barbellWeight + (sideWeight * 2)
    }

    private var plateOptions: [Double] {
        unit == .pounds ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    private var videoCard: some View {
        LiftCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Video & verification")
                        .font(.headline)
                    Spacer()
                    if selectedVideoURL != nil {
                        VerificationBadge(evidenceStatus: .videoBacked)
                    }
                }
                if selectedVideoURL != nil {
                    Button {
                        showingVideoReview = true
                    } label: {
                        Label("Review selected video", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())
                    UploadProgressView()
                    Button(role: .destructive) {
                        Haptics.warning()
                        selectedVideoURL = nil
                    } label: {
                        Label("Remove video", systemImage: "trash")
                    }
                } else {
                    if isVideoPickerReady {
                        PhotosPicker(selection: $pickerItem, matching: .videos) {
                            if isPreparingVideo {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Select lift video", systemImage: "video.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(LiftCompactProminentButtonStyle())
                        .disabled(isPreparingVideo)
                    } else {
                        Label("Video optional", systemImage: "video")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.liftField)
                        .clipShape(RoundedRectangle(cornerRadius: LiftDesign.controlRadius, style: .continuous))
                    }
                }

                Toggle("Request verification", isOn: $requestVerification)
                    .tint(Color.liftBlue)
                    .frame(minHeight: LiftDesign.minimumTouchTarget)

                if requestVerification {
                    DisclosureGroup("Recording guidance") {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(["Keep the lifter and plates visible", "Show the complete repetition", "Avoid edited videos", "Show the full range of motion"], id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.liftBlue)
                }

                Divider().overlay(Color.liftSeparator)

                LiftActionRow(title: "Visibility", subtitle: visibility.rawValue, symbolName: visibilitySymbol) {
                    activeSelector = .visibility
                }
                TextField("Add a caption (optional)", text: $caption, axis: .vertical)
                    .lineLimit(2...3)
                    .padding(12)
                    .background(Color.liftField)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Label(submissionConsequence, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let videoError {
                    Text(videoError)
                        .font(.caption)
                        .foregroundStyle(Color.liftRed)
                }
            }
        }
    }

    private var submitFooter: some View {
        VStack(spacing: 7) {
            if let submissionBlockReason {
                Text(submissionBlockReason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("lift.submitReason")
            }

            PrimaryButton(
                title: isSubmitting ? "Submitting..." : "Submit lift",
                symbolName: isSubmitting ? "hourglass" : "paperplane.fill"
            ) {
                submitLift()
            }
            .accessibilityIdentifier("lift.submit")
            .disabled(submitDisabled)
        }
        .padding(.horizontal, LiftDesign.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.liftBackground.opacity(0.98))
        .overlay(alignment: .top) {
            Divider().overlay(Color.liftSeparator)
        }
    }

    private var submitDisabled: Bool {
        submissionBlockReason != nil
    }

    private var submissionBlockReason: String? {
        if isSubmitting { return "Submitting your lift..." }
        if isPreparingVideo { return "Preparing the selected video..." }
        if selectedGym == nil || !appState.isGymJoined(gymID) { return "Choose a joined gym to continue." }
        if requestVerification && selectedVideoURL == nil { return "Add a lift video or turn off verification." }
        if selectedMovement == .dumbbellBenchPress && !confirmsMatchedDumbbells { return "Confirm that both dumbbells match." }
        return nil
    }

    private func submitLift() {
        guard !submitDisabled else { return }
        isSubmitting = true
        Task {
            submittedLift = await appState.submitLift(
                exercise: exercise,
                weight: weight,
                unit: unit,
                reps: repetitions,
                isActual: isActualOneRepMax,
                bodyweight: bodyweight,
                date: performedAt,
                gymID: gymID,
                equipment: equipment,
                visibility: visibility,
                videoURL: selectedVideoURL,
                caption: caption,
                requestVerification: requestVerification
            )
            isSubmitting = false
            if submittedLift != nil {
                showingResult = true
            } else {
                submissionError = appState.accountMessage ?? "The lift could not be submitted."
            }
        }
    }
}

private struct EditablePlateLoad: Identifiable, Hashable {
    let id = UUID()
    var plateWeight: Double
    var label: String
    var count: Int
}

private struct UploadProgressView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.uploadProgress > 0 {
            ProgressView(value: appState.uploadProgress)
                .tint(Color.liftGreen)
        }
    }
}

struct VideoReviewView: View {
    let videoURL: URL?
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let videoURL {
                ManagedVideoPlayer(url: videoURL)
                    .ignoresSafeArea()
            } else {
                Text("No video selected")
            }
            Button {
                close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("Close video review")
        }
    }
}

struct LiftSubmissionResultView: View {
    @EnvironmentObject private var appState: AppState
    let lift: LiftSubmission
    let done: () -> Void

    var body: some View {
        AppBackground {
            VStack(alignment: .leading, spacing: 18) {
                Text("Lift submitted")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("lift.submissionResult")
                MetricCard(title: "New max", value: "\(RankingCalculator.format(lift.estimatedOneRepMax)) lb", subtitle: lift.isActualOneRepMax ? "Actual one-rep max" : "Estimated one-rep max", symbolName: "bolt.fill", tint: .liftGreen)
                MetricCard(
                    title: "Evidence",
                    value: lift.resolvedEvidenceStatus.evidenceMetricValue,
                    subtitle: lift.resolvedEvidenceStatus.evidenceMetricSubtitle,
                    symbolName: lift.resolvedEvidenceStatus.evidenceMetricSymbol,
                    tint: lift.resolvedEvidenceStatus.evidenceMetricTint
                )
                MetricCard(title: "Ranking update", value: "Tomorrow", subtitle: "Leaderboards refresh once daily at midnight.", symbolName: "clock.arrow.circlepath", tint: .liftBlue)
                Button("Done", action: done)
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("lift.submissionDone")
                Spacer()
            }
            .padding()
        }
    }
}
