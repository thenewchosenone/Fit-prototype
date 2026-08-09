import AVFoundation
import Charts
import PhotosUI
import SwiftUI
import UIKit

enum ProfileLiftVideoLibrary {
    static func visibleLifts(
        for profileID: UUID,
        viewerID: UUID,
        allLifts: [LiftSubmission],
        includeLiftsWithoutVideo: Bool = false
    ) -> [LiftSubmission] {
        allLifts
            .filter { lift in
                guard lift.userID == profileID else { return false }
                guard viewerID == profileID || lift.visibility == .publicLift else { return false }
                return includeLiftsWithoutVideo || lift.hasVideoReference
            }
            .sorted { $0.performedAt > $1.performedAt }
    }
}

private extension LiftSubmission {
    var hasVideoReference: Bool {
        videoAssetID != nil || localVideoURL != nil || remoteVideoURL != nil
    }
}

struct ProfileLiftVideosSection: View {
    @EnvironmentObject private var appState: AppState
    let profile: UserProfile
    let isCurrentUser: Bool
    let prefilteredLifts: [LiftSubmission]?
    @State private var selectedLift: LiftSubmission?

    init(profile: UserProfile, isCurrentUser: Bool, prefilteredLifts: [LiftSubmission]? = nil) {
        self.profile = profile
        self.isCurrentUser = isCurrentUser
        self.prefilteredLifts = prefilteredLifts
    }

    private var videoLifts: [LiftSubmission] {
        if let prefilteredLifts {
            return prefilteredLifts.filter(\.hasVideoReference)
        }
        return ProfileLiftVideoLibrary.visibleLifts(
            for: profile.id,
            viewerID: appState.currentProfile.id,
            allLifts: appState.lifts
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactSectionHeader(title: "Lift videos")
            if profile.hideLiftVideos && !isCurrentUser {
                LiftEmptyState(
                    title: "Lift videos hidden",
                    message: "This lifter keeps submitted videos private.",
                    symbolName: "eye.slash",
                    compact: true
                )
            } else if videoLifts.isEmpty {
                LiftEmptyState(
                    title: "No lift videos yet",
                    message: isCurrentUser
                        ? "Attach a video when you submit a lift and it will appear here."
                        : "This athlete has not shared a lift video.",
                    symbolName: "video.badge.plus",
                    compact: true
                )
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(videoLifts) { lift in
                        Button {
                            selectedLift = lift
                        } label: {
                            ProfileVideoThumbnail(lift: lift)
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play \(lift.exerciseName) lift video")
                        .accessibilityIdentifier("profile.liftVideo.\(lift.id.uuidString)")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("profile.liftVideos")
            }
        }
        .sheet(item: $selectedLift) { lift in
            ProfileLiftVideoDetailView(lift: lift)
                .environmentObject(appState)
                .presentationDetents([.large])
        }
    }
}

private struct ProfileVideoThumbnail: View {
    @EnvironmentObject private var appState: AppState
    let lift: LiftSubmission
    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        ZStack {
            Color.liftSurfaceElevated
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "video.fill")
                    .font(.title2)
                    .foregroundStyle(Color.liftMuted)
            }
            Color.black.opacity(0.18)
            Image(systemName: "play.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .shadow(radius: 3)
        }
        .clipped()
        .task(id: lift.id) {
            if let cached = Self.cache.object(forKey: lift.id.uuidString as NSString) {
                image = cached
                return
            }
            guard let url = await appState.competitionStore.playbackURL(for: lift) else { return }
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 360, height: 360)
            let time = CMTime(seconds: 0, preferredTimescale: 600)
            let thumbnail = await withCheckedContinuation { continuation in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
                    continuation.resume(returning: image)
                }
            }
            guard let thumbnail else { return }
            let image = UIImage(cgImage: thumbnail)
            Self.cache.setObject(image, forKey: lift.id.uuidString as NSString)
            self.image = image
        }
    }
}

private struct ProfileLiftVideoDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let lift: LiftSubmission
    @State private var playbackURL: URL?
    @State private var isResolvingPlayback = false

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(lift.exerciseName)
                                .font(.title2.weight(.black))
                            Text("\(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions)) • \(LiftTimeFormatter.shortDateTime(lift.performedAt))")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                            VerificationBadge(evidenceStatus: lift.resolvedEvidenceStatus)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liftSurface()

                        if let playbackURL {
                            ManagedVideoPlayer(url: playbackURL)
                                .frame(height: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityIdentifier("profile.liftVideoPlayer")
                        } else if isResolvingPlayback {
                            LiftCard {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Preparing lift video…")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        } else {
                            LiftEmptyState(
                                title: "Video unavailable",
                                message: "This upload has a lift record, but its video file could not be opened.",
                                symbolName: "video.slash"
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Lift video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: lift.id) {
                isResolvingPlayback = true
                playbackURL = await appState.competitionStore.playbackURL(for: lift)
                isResolvingPlayback = false
            }
        }
    }
}

private enum EditProfileSelector: String, Identifiable {
    case location
    case gym

    var id: String { rawValue }
    var title: String { self == .location ? "Choose Location" : "Choose Primary Gym" }
}

private struct EditProfileLocation: Identifiable, Hashable {
    let city: String
    let state: String
    var id: String { "\(state.lowercased())|\(city.lowercased())" }
}

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MockData.emptyProfile
    @State private var showingPhotoManager = false
    @State private var activeSelector: EditProfileSelector?
    @State private var selectedGymID: UUID?
    @State private var privacy = ProfilePrivacySettings()
    private var ageGroups: [String] {
        MockData.standardAgeGroups.contains(draft.ageGroup)
            ? MockData.standardAgeGroups
            : [draft.ageGroup] + MockData.standardAgeGroups
    }

    private var selectedGym: Gym? {
        appState.gyms.first { $0.id == selectedGymID }
    }

    private var locations: [EditProfileLocation] {
        var unique: [String: EditProfileLocation] = [:]
        for country in LaunchLocationCatalog.countries {
            for region in country.regions {
                for city in region.cities {
                    let location = EditProfileLocation(city: city, state: region.name)
                    unique[location.id] = location
                }
            }
        }
        for gym in appState.gyms where !gym.city.isEmpty && !gym.state.isEmpty {
            let location = EditProfileLocation(city: gym.city, state: gym.state)
            unique[location.id] = location
        }
        if !draft.city.isEmpty && !draft.state.isEmpty {
            let current = EditProfileLocation(city: draft.city, state: draft.state)
            unique[current.id] = current
        }
        return unique.values.sorted {
            $0.state == $1.state ? $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending :
                $0.state.localizedCaseInsensitiveCompare($1.state) == .orderedAscending
        }
    }

    private var orderedGyms: [Gym] {
        func locationPriority(for gym: Gym) -> Int {
            if gym.city.caseInsensitiveCompare(draft.city) == .orderedSame,
               gym.state.caseInsensitiveCompare(draft.state) == .orderedSame {
                return 0
            }
            if gym.state.caseInsensitiveCompare(draft.state) == .orderedSame {
                return 1
            }
            return 2
        }

        return appState.gyms.sorted {
            let leftPriority = locationPriority(for: $0)
            let rightPriority = locationPriority(for: $1)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            if $0.state.caseInsensitiveCompare($1.state) != .orderedSame {
                return $0.state.localizedCaseInsensitiveCompare($1.state) == .orderedAscending
            }
            if $0.city.caseInsensitiveCompare($1.city) != .orderedSame {
                return $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var selectedLocationGymOptionIDs: Set<String> {
        Set(appState.gyms.compactMap {
            guard $0.city.caseInsensitiveCompare(draft.city) == .orderedSame,
                  $0.state.caseInsensitiveCompare(draft.state) == .orderedSame else { return nil }
            return $0.id.uuidString
        })
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Identity") {
                        Button {
                            showingPhotoManager = true
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: draft, size: 76)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Profile photo")
                                        .font(.headline)
                                    Text(draft.avatarPath == nil ? "Add or change your photo" : "Replace or remove your photo")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                        }
                        LabeledContent("Username") {
                            TextField("Username", text: $draft.username)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Display name") {
                            TextField("Display name", text: $draft.displayName)
                                .multilineTextAlignment(.trailing)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                            TextField("Tell athletes about your training", text: bioBinding, axis: .vertical)
                                .lineLimit(2...4)
                        }
                        Picker("Age group", selection: $draft.ageGroup) {
                            ForEach(ageGroups, id: \.self) { ageGroup in
                                Text(ageGroup).tag(ageGroup)
                            }
                        }
                        Picker("Division", selection: $draft.sexCategory) {
                            ForEach(SexCategory.allCases.filter { $0 != .open }) { Text($0.rawValue).tag($0) }
                        }
                        LabeledContent("Experience") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(appState.earnedExperienceLevel.rawValue)
                                    .foregroundStyle(Color.liftBlue)
                                Text(appState.earnedExperienceDescription)
                                    .font(.caption2)
                                    .foregroundStyle(Color.liftMuted)
                            }
                        }
                        Stepper("Years training: \(draft.yearsExperience)", value: $draft.yearsExperience, in: 0...100)
                    }
                    Section("Body") {
                        NumericInputField(title: "Height", value: $draft.heightInches, unit: "in", presentation: .formRow)
                        NumericInputField(
                            title: "Bodyweight",
                            value: bodyweightDisplayValue,
                            unit: draft.preferredUnit.shortLabel,
                            presentation: .formRow
                        )
                    }
                    Section("Location") {
                        profileSelectionRow(
                            title: "Location",
                            value: draft.city.isEmpty ? "Choose a location" : "\(draft.city), \(draft.state)",
                            symbol: "mappin.and.ellipse"
                        ) { activeSelector = .location }
                        profileSelectionRow(
                            title: "Primary gym",
                            value: selectedGym?.name ?? "No primary gym",
                            symbol: "building.2.fill"
                        ) { activeSelector = .gym }
                    }
                    Section("Privacy") {
                        audiencePicker("Profile", selection: $privacy.profileAudience)
                        audiencePicker("Age band", selection: $privacy.ageBandAudience)
                        audiencePicker("Division", selection: $privacy.divisionAudience)
                        audiencePicker("Bodyweight", selection: $privacy.bodyweightAudience)
                        audiencePicker("Location", selection: $privacy.locationAudience)
                        audiencePicker("Gym", selection: $privacy.gymAudience)
                        audiencePicker("Friend list", selection: $privacy.friendListAudience)
                        Toggle("Show approved lift videos publicly", isOn: $privacy.showLiftVideos)
                        Text("Ratio and weight-class rankings may indirectly reveal bodyweight even when the bodyweight field is private.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .onAppear {
                draft = appState.currentProfile
                privacy = appState.authenticatedPrivacy
                selectedGymID = appState.gyms.first(where: {
                    $0.id == draft.primaryGymID || $0.name == draft.primaryGymName
                })?.id
            }
            .sheet(item: $activeSelector) { selector in
                LeaderboardOptionSheet(
                    title: selector.title,
                    options: options(for: selector),
                    selectedID: selectedID(for: selector),
                    isSearchable: true,
                    searchPrompt: selector == .location ? "Search city or state" : "Search name, city, or state",
                    emptyTitle: selector == .location ? "No locations available" : "No gyms available",
                    emptyMessage: selector == .location
                        ? "Try a different city or state search."
                        : "Try another search, switch to All gyms, or request that this gym be added.",
                    preferredOptionIDs: selector == .gym ? selectedLocationGymOptionIDs : [],
                    preferredScopeTitle: selector == .gym && !draft.city.isEmpty ? draft.city : nil,
                    allScopeTitle: "All gyms"
                ) { id in
                    select(id, for: selector)
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingPhotoManager, onDismiss: {
                draft = appState.currentProfile
            }) {
                ProfilePhotoManagerView()
                    .environmentObject(appState)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var outgoingDraft = draft
                        outgoingDraft.experienceLevel = appState.earnedExperienceLevel
                        outgoingDraft.hideLiftVideos = !privacy.showLiftVideos
                        Task {
                            if await appState.saveEditedProfile(outgoingDraft, primaryGym: selectedGym, privacy: privacy) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(appState.accountOperationInProgress)
                }
            }
        }
    }

    private func audiencePicker(_ title: String, selection: Binding<PrivacyAudience>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PrivacyAudience.allCases) { audience in
                Text(audience.label).tag(audience)
            }
        }
    }

    private var bodyweightDisplayValue: Binding<Double> {
        Binding(
            get: {
                MeasurementFormatting.convert(draft.bodyweightPounds, from: .pounds, to: draft.preferredUnit)
            },
            set: { newValue in
                draft.bodyweightPounds = MeasurementFormatting.convert(newValue, from: draft.preferredUnit, to: .pounds)
            }
        )
    }

    private var bioBinding: Binding<String> {
        Binding(
            get: { draft.bio ?? "" },
            set: { draft.bio = $0 }
        )
    }

    private func profileSelectionRow(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.liftBlue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    Text(value)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
    }

    private func options(for selector: EditProfileSelector) -> [LeaderboardOption] {
        switch selector {
        case .location:
            return locations.map {
                LeaderboardOption(id: $0.id, title: $0.city, subtitle: $0.state, symbol: "mappin.and.ellipse")
            }
        case .gym:
            return orderedGyms.map {
                LeaderboardOption(id: $0.id.uuidString, title: $0.name, subtitle: "\($0.city), \($0.state)", symbol: "building.2.fill")
            }
        }
    }

    private func selectedID(for selector: EditProfileSelector) -> String {
        switch selector {
        case .location:
            return EditProfileLocation(city: draft.city, state: draft.state).id
        case .gym:
            return selectedGymID?.uuidString ?? ""
        }
    }

    private func select(_ id: String, for selector: EditProfileSelector) {
        switch selector {
        case .location:
            guard let location = locations.first(where: { $0.id == id }) else { return }
            draft.city = location.city
            draft.state = location.state
            if let gym = selectedGym,
               gym.city.caseInsensitiveCompare(location.city) != .orderedSame ||
                gym.state.caseInsensitiveCompare(location.state) != .orderedSame {
                selectedGymID = nil
            }
        case .gym:
            guard let gymID = UUID(uuidString: id), let gym = appState.gyms.first(where: { $0.id == gymID }) else { return }
            selectedGymID = gym.id
            draft.primaryGymID = gym.id
            draft.primaryGymName = gym.name
        }
    }

}

struct ProfilePhotoManagerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var loading = false
    @State private var selectedSourceImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var showingCropEditor = false
    @State private var showingRemoveConfirmation = false

    private var displayedImage: UIImage? {
        previewImage ??
        LocalProfilePhotoStore.shared.image(for: appState.currentProfile.avatarPath) ??
        LocalProfilePhotoStore.shared.thumbnail(for: appState.currentProfile.avatarPath)
    }

    private var hasExistingOrPendingPhoto: Bool {
        appState.currentProfile.avatarPath != nil || previewImage != nil
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.liftCardRaised)
                            .frame(width: 164, height: 164)

                        if let displayedImage {
                            Image(uiImage: displayedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 144, height: 144)
                                .clipShape(Circle())
                        } else {
                            ProfileAvatar(profile: appState.currentProfile, size: 144)
                        }
                    }
                        .padding(.top, 24)

                    PhotosPicker(selection: $item, matching: .images) {
                        Label(hasExistingOrPendingPhoto ? "Replace Photo" : "Choose Photo", systemImage: "photo")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.liftBackground)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(LiftCompactProminentButtonStyle())

                    if previewImage != nil {
                        LiftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Preview")
                                    .font(.headline.weight(.bold))
                                Text("Keep the new photo, adjust it again, or discard it before saving.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.liftMuted)
                                HStack(spacing: 10) {
                                    Button("Adjust") {
                                        showingCropEditor = true
                                    }
                                    .buttonStyle(LiftSecondaryButtonStyle())

                                    Button("Cancel") {
                                        previewImage = nil
                                        selectedSourceImage = nil
                                    }
                                    .buttonStyle(LiftSecondaryButtonStyle())

                                    Button("Use Photo") {
                                        guard let previewImage else { return }
                                        appState.saveProfilePhoto(previewImage)
                                        self.previewImage = nil
                                        selectedSourceImage = nil
                                    }
                                    .buttonStyle(LiftPrimaryButtonStyle())
                                }
                            }
                        }
                    } else if appState.currentProfile.avatarPath != nil {
                        Button("Remove Photo", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if loading {
                        ProgressView()
                            .tint(Color.liftBlue)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove profile photo?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove Photo", role: .destructive) {
                    appState.removeProfilePhoto()
                }
            } message: {
                Text("The current photo will be removed after confirmation.")
            }
            .fullScreenCover(isPresented: $showingCropEditor) {
                if let selectedSourceImage {
                    ProfilePhotoCropEditorView(
                        sourceImage: selectedSourceImage,
                        onCancel: {
                            showingCropEditor = false
                        },
                        onCrop: { croppedImage in
                            previewImage = croppedImage
                            showingCropEditor = false
                        }
                    )
                }
            }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                loading = true
                Task {
                    defer { loading = false }
                    guard let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)?.preparedForProfileEditing() else { return }
                    await MainActor.run {
                        selectedSourceImage = image
                        showingCropEditor = true
                        item = nil
                    }
                }
            }
        }
    }
}

private struct ProfilePhotoCropEditorView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    @State private var zoomScale: CGFloat = 1
    @State private var baseZoomScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let cropSide = min(proxy.size.width - 32, proxy.size.height * 0.55)
            let apertureSide = cropSide - 20
            let viewport = CGSize(width: apertureSide, height: apertureSide)

            AppBackground {
                VStack(spacing: 20) {
                    Text("Adjust Photo")
                        .font(.title2.weight(.bold))
                        .padding(.top, 10)

                    Text("Position and scale your photo inside the circle.")
                        .font(.subheadline)
                        .foregroundStyle(Color.liftMuted)

                    Spacer(minLength: 0)

                    ZStack {
                        Color.liftCard
                            .frame(width: cropSide, height: cropSide)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        Image(uiImage: sourceImage)
                            .resizable()
                            .frame(
                                width: sourceImage.size.width * imageScale(in: viewport),
                                height: sourceImage.size.height * imageScale(in: viewport)
                            )
                            .offset(clampedOffset(in: viewport))
                            .gesture(dragGesture(in: viewport).simultaneously(with: magnificationGesture(in: viewport)))
                            .frame(width: cropSide, height: cropSide)
                            .clipped()

                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                            .frame(width: apertureSide, height: apertureSide)

                        Color.black.opacity(0.42)
                            .mask {
                                Rectangle()
                                    .overlay {
                                        Circle()
                                            .frame(width: apertureSide, height: apertureSide)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                            }
                            .allowsHitTesting(false)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Button("Cancel") { onCancel() }
                            .buttonStyle(LiftSecondaryButtonStyle())

                        Button("Reset") {
                            zoomScale = 1
                            baseZoomScale = 1
                            offset = .zero
                            baseOffset = .zero
                        }
                        .buttonStyle(LiftSecondaryButtonStyle())

                        Button("Crop") {
                            if let cropped = croppedImage(in: viewport) {
                                onCrop(cropped)
                            } else {
                                onCancel()
                            }
                        }
                        .buttonStyle(LiftPrimaryButtonStyle())
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func imageScale(in viewport: CGSize) -> CGFloat {
        let base = max(viewport.width / sourceImage.size.width, viewport.height / sourceImage.size.height)
        return base * zoomScale
    }

    private func clampedOffset(in viewport: CGSize) -> CGSize {
        let currentScale = imageScale(in: viewport)
        let renderedWidth = sourceImage.size.width * currentScale
        let renderedHeight = sourceImage.size.height * currentScale
        let maxX = max(0, (renderedWidth - viewport.width) / 2)
        let maxY = max(0, (renderedHeight - viewport.height) / 2)

        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func dragGesture(in viewport: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                let final = clampedOffset(in: viewport)
                offset = final
                baseOffset = final
            }
    }

    private func magnificationGesture(in viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(baseZoomScale * value, 1), 4)
            }
            .onEnded { _ in
                zoomScale = min(max(zoomScale, 1), 4)
                baseZoomScale = zoomScale
                let final = clampedOffset(in: viewport)
                offset = final
                baseOffset = final
            }
    }

    private func croppedImage(in viewport: CGSize) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }

        let currentScale = imageScale(in: viewport)
        let visibleWidth = viewport.width / currentScale
        let visibleHeight = viewport.height / currentScale
        let clamped = clampedOffset(in: viewport)

        let originX = ((sourceImage.size.width - visibleWidth) / 2) - (clamped.width / currentScale)
        let originY = ((sourceImage.size.height - visibleHeight) / 2) - (clamped.height / currentScale)

        let rect = CGRect(
            x: max(0, min(originX, sourceImage.size.width - visibleWidth)),
            y: max(0, min(originY, sourceImage.size.height - visibleHeight)),
            width: min(visibleWidth, sourceImage.size.width),
            height: min(visibleHeight, sourceImage.size.height)
        ).integral

        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}

private extension UIImage {
    /// Produces an upright, one-point-per-pixel editing image so SwiftUI preview
    /// geometry and Core Graphics crop coordinates describe the same pixels.
    func preparedForProfileEditing(maxDimension: CGFloat = 4_096) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let longestSide = max(size.width, size.height)
        let downsampleScale = min(1, maxDimension / longestSide)
        let outputSize = CGSize(
            width: max(1, (size.width * downsampleScale).rounded()),
            height: max(1, (size.height * downsampleScale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}

struct GymDirectoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var isRefreshing = false

    private var matchingGyms: [Gym] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = cleanQuery.isEmpty ? appState.gyms : appState.gyms.filter {
            $0.name.localizedCaseInsensitiveContains(cleanQuery) ||
                $0.city.localizedCaseInsensitiveContains(cleanQuery) ||
                $0.state.localizedCaseInsensitiveContains(cleanQuery)
        }
        return filtered.sorted {
            let leftJoined = appState.isGymJoined($0)
            let rightJoined = appState.isGymJoined($1)
            if leftJoined != rightJoined { return leftJoined }
            if $0.state.caseInsensitiveCompare($1.state) != .orderedSame {
                return $0.state.localizedCaseInsensitiveCompare($1.state) == .orderedAscending
            }
            if $0.city.caseInsensitiveCompare($1.city) != .orderedSame {
                return $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var joinedMatches: [Gym] { matchingGyms.filter(appState.isGymJoined) }
    private var otherMatches: [Gym] { matchingGyms.filter { !appState.isGymJoined($0) } }

    var body: some View {
        AppBackground {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find your gym")
                            .font(.largeTitle.bold())
                        Text("Join up to \(AppState.maximumJoinedGyms) gyms and choose one as your primary location.")
                            .foregroundStyle(Color.liftMuted)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.liftMuted)
                        TextField("Search gyms, cities, or states", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("gyms.search")
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .liftSurface(radius: 12)

                    if isRefreshing && appState.gyms.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading gyms…")
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    } else if matchingGyms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "building.2.crop.circle")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(Color.liftBlue)
                            Text(query.isEmpty ? "No gyms available yet" : "No matching gyms")
                                .font(.headline)
                            Text(query.isEmpty
                                 ? "Refresh the directory or request a gym to be added."
                                 : "Try a gym name, city, or state.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .multilineTextAlignment(.center)
                            if query.isEmpty {
                                Button("Refresh gyms") { Task { await refreshGyms() } }
                                    .buttonStyle(.bordered)
                                    .tint(Color.liftBlue)
                            }
                            Button("Request a gym") { appState.showingRequestGym = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.liftLime)
                                .foregroundStyle(Color.liftBackground)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .liftSurface(radius: 14)
                    } else {
                        if !joinedMatches.isEmpty {
                            gymSection("My gyms", gyms: joinedMatches)
                        }
                        if !otherMatches.isEmpty {
                            gymSection(joinedMatches.isEmpty ? "All gyms" : "More gyms", gyms: otherMatches)
                        }
                    }
                }
                .padding()
            }
            .refreshable { await refreshGyms() }
        }
        .navigationTitle("Gyms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { appState.showingRequestGym = true } label: {
                    Label("Request gym", systemImage: "plus")
                }
            }
        }
        .task {
            if appState.isAuthenticated {
                await refreshGyms()
            }
        }
    }

    @ViewBuilder
    private func gymSection(_ title: String, gyms: [Gym]) -> some View {
        CompactSectionHeader(title: title)
        VStack(spacing: 0) {
            ForEach(Array(gyms.enumerated()), id: \.element.id) { index, gym in
                NavigationLink {
                    GymDetailView(gym: gym)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: appState.isPrimaryGym(gym) ? "star.fill" : "building.2.fill")
                            .frame(width: 34, height: 34)
                            .foregroundStyle(appState.isPrimaryGym(gym) ? Color.liftGold : Color.liftBlue)
                            .background(Color.liftSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(gym.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.liftText)
                            Text([gym.city, gym.state].filter { !$0.isEmpty }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                        }
                        Spacer()
                        if appState.isPrimaryGym(gym) {
                            Text("Primary")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.liftGold)
                        } else if appState.isGymJoined(gym) {
                            Text("Joined")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.liftGreen)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.liftMuted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gyms.row.\(gym.id.uuidString)")
                if index < gyms.count - 1 {
                    Divider().overlay(Color.liftSeparator).padding(.leading, 58)
                }
            }
        }
        .liftSurface(radius: 12)
    }

    private func refreshGyms() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await appState.refreshRemoteSocialState()
        isRefreshing = false
    }
}

struct GymDetailView: View {
    @EnvironmentObject private var appState: AppState
    let gym: Gym
    @State private var showingMembershipLimit = false

    private var joined: Bool {
        appState.isGymJoined(gym)
    }

    private var isPrimaryGym: Bool {
        appState.isPrimaryGym(gym)
    }

    private var gymLeaderboardEntries: [LeaderboardEntry] {
        guard appState.leaderboardFilters.gymID == gym.id else { return [] }
        return Array(appState.leaderboardEntries().prefix(5))
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(gym.name)
                        .font(.largeTitle.bold())
                    Text("\(gym.city), \(gym.state)")
                        .foregroundStyle(Color.liftMuted)
                    PrimaryButton(
                        title: isPrimaryGym ? "Primary Gym" : (joined ? "Leave Gym" : "Join Gym"),
                        symbolName: isPrimaryGym ? "star.fill" : (joined ? "minus.circle" : "plus.circle")
                    ) {
                        if isPrimaryGym {
                            Haptics.light()
                        } else if joined {
                            appState.leaveGym(gym)
                        } else if !appState.joinGym(gym) {
                            showingMembershipLimit = true
                        }
                    }
                    .disabled(isPrimaryGym)
                    if joined && !isPrimaryGym {
                        Button {
                            appState.setPrimaryGym(gym)
                        } label: {
                            Label("Make Primary Gym", systemImage: "star")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.liftBlue)
                    }
                    Text("You can belong to up to \(AppState.maximumJoinedGyms) gyms. Your primary gym counts toward this limit.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(["members", "verified"], id: \.self) { metric in
                            if metric == "members" {
                                MetricCard(title: "Members", value: "\(gym.memberCount)", subtitle: "Local lifters")
                            } else {
                                MetricCard(title: "Verified lifts", value: "\(gym.verifiedLiftCount)", subtitle: "Approved submissions", tint: .liftGreen)
                            }
                        }
                    }
                    SectionHeader(title: "Top lifters")
                    if appState.leaderboardFilters.gymID != gym.id || appState.isLeaderboardRequestPending {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading gym rankings…")
                                .foregroundStyle(Color.liftMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70)
                    } else if gymLeaderboardEntries.isEmpty {
                        Text("No qualifying verified lifts at this gym yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(gymLeaderboardEntries) { entry in
                            LeaderboardRow(entry: entry)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Gym limit reached", isPresented: $showingMembershipLimit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Leave one of your secondary gyms before joining another. Members can belong to a maximum of \(AppState.maximumJoinedGyms) gyms.")
            }
            .task { await loadGymLeaderboard() }
        }
    }

    private func loadGymLeaderboard() async {
        appState.leaderboardFilters.gymID = gym.id
        appState.leaderboardFilters.cityID = nil
        appState.leaderboardFilters.city = nil
        appState.leaderboardFilters.state = nil
        appState.leaderboardFilters.country = nil
        await appState.refreshLeaderboard()
    }
}

struct RequestGymView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var note = ""

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                Form {
                    Section("Gym") {
                        TextField("Gym name", text: $name)
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("Why should this gym be added?", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Request Gym")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.requestGym(name: name, city: city, state: state, note: note)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}
