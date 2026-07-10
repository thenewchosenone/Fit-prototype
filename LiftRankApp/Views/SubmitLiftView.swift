import AVKit
import PhotosUI
import SwiftData
import SwiftUI

struct SubmitLiftView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var exercise = MockData.exercises[2]
    @State private var weight = 315.0
    @State private var unit: UnitSystem = .pounds
    @State private var repetitions = 1
    @State private var isActualOneRepMax = true
    @State private var bodyweight = MockData.demoProfile.bodyweightPounds
    @State private var performedAt = Date()
    @State private var gymID = MockData.demoGymID
    @State private var equipment = EquipmentType.raw
    @State private var caption = ""
    @State private var visibility = LiftVisibility.publicLift
    @State private var requestVerification = true
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var showingVideoReview = false
    @State private var showingResult = false
    @State private var plateLoads: [EditablePlateLoad] = []
    @State private var barbellWeight = 45.0
    @State private var plateLoadingWasEdited = false
    @State private var isSyncingPlateLoading = false

    private var estimate: Double {
        isActualOneRepMax ? weight : RankingCalculator.epleyOneRepMax(weight: weight, repetitions: repetitions)
    }

    private var selectedGym: Gym? {
        appState.gyms.first { $0.id == gymID }
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        formSection
                        estimateCard
                        plateCard
                        videoCard
                        guidanceCard
                        PrimaryButton(title: "Submit lift", symbolName: "paperplane.fill") {
                            Task {
                                await appState.submitLift(exercise: exercise, weight: weight, unit: unit, reps: repetitions, isActual: isActualOneRepMax, bodyweight: bodyweight, date: performedAt, gymID: gymID, equipment: equipment, visibility: visibility, videoURL: selectedVideoURL, caption: caption, requestVerification: requestVerification)
                                if let lift = appState.lastSubmissionResult {
                                    modelContext.insert(PersistentLiftRecord(id: lift.id, exerciseID: lift.exerciseID, exerciseName: lift.exerciseName, weight: lift.weight, repetitions: lift.repetitions, performedAt: lift.performedAt))
                                }
                                showingResult = true
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Submit Lift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingResult) {
                if let result = appState.lastSubmissionResult {
                    LiftSubmissionResultView(lift: result) {
                        showingResult = false
                        dismiss()
                    }
                    .environmentObject(appState)
                }
            }
            .fullScreenCover(isPresented: $showingVideoReview) {
                VideoReviewView(videoURL: selectedVideoURL) {
                    showingVideoReview = false
                }
            }
            .onChange(of: pickerItem) { _, _ in
                selectedVideoURL = URL(fileURLWithPath: "/tmp/liftrank-demo-video.mov")
                appState.uploadProgress = 0
            }
            .onAppear {
                resetPlateLoadingFromWeight()
            }
            .onChange(of: unit) { _, _ in
                resetPlateLoadingFromWeight()
            }
            .onChange(of: weight) { _, _ in
                if !plateLoadingWasEdited {
                    resetPlateLoadingFromWeight()
                }
            }
        }
    }

    private var formSection: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 16) {
                bubbleSection(title: "Exercise") {
                    ForEach(MockData.exercises) { option in
                        bubbleButton(option.name, isActive: exercise == option) {
                            exercise = option
                        }
                    }
                }

                bubbleSection(title: "Weight unit") {
                    ForEach(UnitSystem.allCases) { option in
                        bubbleButton(option.rawValue.capitalized, isActive: unit == option) {
                            unit = option
                        }
                    }
                }

                NumericInputField(title: "Weight", value: $weight, unit: unit.shortLabel, precision: 0...2, presentation: .inset)
                IntegerInputField(title: "Repetitions", value: $repetitions, presentation: .inset)

                bubbleSection(title: "Max type") {
                    bubbleButton("Actual 1RM", isActive: isActualOneRepMax) {
                        isActualOneRepMax = true
                    }
                    bubbleButton("Estimated", isActive: !isActualOneRepMax) {
                        isActualOneRepMax = false
                    }
                }

                NumericInputField(title: "Bodyweight", value: $bodyweight, unit: "lb", precision: 0...2, presentation: .inset)
                DatePicker("Date performed", selection: $performedAt, displayedComponents: .date)

                bubbleSection(title: "Gym") {
                    if let selectedGym {
                        bubbleButton(selectedGym.name, isActive: true) {}
                    }
                    ForEach(appState.joinedGyms.filter { $0.id != gymID }) { gym in
                        bubbleButton(gym.name, isActive: false) {
                            gymID = gym.id
                        }
                    }
                }

                bubbleSection(title: "Equipment type") {
                    ForEach(EquipmentType.allCases) { option in
                        bubbleButton(option.rawValue, isActive: equipment == option) {
                            equipment = option
                        }
                    }
                }

                bubbleSection(title: "Visibility") {
                    ForEach(LiftVisibility.allCases) { option in
                        bubbleButton(option.rawValue, isActive: visibility == option) {
                            visibility = option
                        }
                    }
                }

                TextField("Caption", text: $caption, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Toggle("Request verification", isOn: $requestVerification)
            }
        }
    }

    private var estimateCard: some View {
        MetricCard(title: "Estimated max", value: "\(RankingCalculator.format(estimate)) \(unit.shortLabel)", subtitle: "\(RankingCalculator.format(weight)) x \(repetitions) estimates a \(RankingCalculator.format(estimate)) \(unit.shortLabel) one-rep max.", symbolName: "function", tint: .liftGreen)
    }

    private var plateCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plate loading")
                            .font(.headline)
                        Text("Each side. Editing plates updates the submitted weight.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                    Spacer()
                    Button("Calculated") {
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

                VStack(spacing: 8) {
                    ForEach($plateLoads) { $plate in
                        HStack(spacing: 12) {
                            Text(plate.label)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 72, alignment: .leading)
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
                                .background(Color.black.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: plate.count) { _, newValue in
                                    guard !isSyncingPlateLoading else { return }
                                    if newValue < 0 { plate.count = 0 }
                                    plateLoadingWasEdited = true
                                    updateWeightFromPlateLoading()
                                }
                        }
                    }
                }

                Text("Loaded total: \(RankingCalculator.format(weight)) \(unit.shortLabel)")
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
        }
    }

    private func bubbleSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                content()
            }
        }
    }

    private func bubbleButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isActive ? Color.liftBlue : Color.liftBlue.opacity(0.12))
                .foregroundStyle(isActive ? Color.white : Color.liftBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
        LiftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Video")
                        .font(.headline)
                    Spacer()
                    if selectedVideoURL != nil {
                        VerificationBadge(status: .videoSubmitted)
                    }
                }
                if selectedVideoURL != nil {
                    Button {
                        showingVideoReview = true
                    } label: {
                        Label("Review selected video", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                    if appState.uploadProgress > 0 {
                        ProgressView(value: appState.uploadProgress)
                            .tint(Color.liftGreen)
                    }
                    Button(role: .destructive) {
                        Haptics.warning()
                        selectedVideoURL = nil
                    } label: {
                        Label("Remove video", systemImage: "trash")
                    }
                } else {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label("Select lift video", systemImage: "video.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liftBlue)
                }
            }
        }
    }

    private var guidanceCard: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification guidance")
                    .font(.headline)
                ForEach(["Keep the lifter and plates visible", "Show the complete repetition", "Avoid edited videos", "Record from an angle that shows range of motion"], id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, in: proposal.width ?? .infinity)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, in: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(for subviews: Subviews, in maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemWidth = currentItems.isEmpty ? size.width : size.width + spacing
            if currentWidth + itemWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth += itemWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }
        return rows
    }

    private struct FlowItem {
        let index: Int
        let size: CGSize
    }

    private struct FlowRow {
        let items: [FlowItem]
        let width: CGFloat
        let height: CGFloat
    }
}

struct VideoReviewView: View {
    let videoURL: URL?
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
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
                MetricCard(title: "New max", value: "\(RankingCalculator.format(lift.estimatedOneRepMax)) lb", subtitle: lift.isActualOneRepMax ? "Actual one-rep max" : "Estimated one-rep max", symbolName: "bolt.fill", tint: .liftGreen)
                MetricCard(title: "Improvement", value: "+20 lb", subtitle: "Previous best: \(RankingCalculator.format(max(0, lift.estimatedOneRepMax - 20))) lb", symbolName: "arrow.up.right", tint: .liftGold)
                MetricCard(title: "Ranking update", value: "Tomorrow", subtitle: "Leaderboards refresh once daily at midnight.", symbolName: "clock.arrow.circlepath", tint: .liftBlue)
                MetricCard(title: "Achievement", value: "First Lift Logged", subtitle: "Share your result with the community.", symbolName: "medal.fill", tint: .liftGold)
                PrimaryButton(title: "Share result", symbolName: "square.and.arrow.up") {
                    Haptics.light()
                }
                Button("Done", action: done)
                    .buttonStyle(.bordered)
                    .tint(Color.liftBlue)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding()
        }
    }
}
