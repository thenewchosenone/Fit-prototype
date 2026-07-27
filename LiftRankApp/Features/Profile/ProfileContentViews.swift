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
        demoMediaID != nil || videoAssetID != nil || localVideoURL != nil || remoteVideoURL != nil
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
                    symbolName: "eye.slash"
                )
            } else if videoLifts.isEmpty {
                LiftEmptyState(
                    title: "No lift videos yet",
                    message: isCurrentUser
                        ? "Attach a video when you submit a lift and it will appear here."
                        : "This athlete has not shared a lift video.",
                    symbolName: "video.badge.plus"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(videoLifts.enumerated()), id: \.offset) { index, lift in
                        Button {
                            selectedLift = lift
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.liftBlue)
                                    .frame(width: 44, height: 44)
                                    .background(Color.liftBlue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lift.exerciseName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.primary)
                                    Text("\(MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions)) • \(LiftTimeFormatter.shortDate(lift.performedAt))")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.liftMuted)
                            }
                            .padding(13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile.liftVideo.\(lift.id.uuidString)")
                        if index < videoLifts.count - 1 {
                            Divider().overlay(Color.liftSeparator).padding(.leading, 69)
                        }
                    }
                }
                .liftSurface()
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

                        if let mediaID = lift.demoMediaID {
                            DemoMediaCard(
                                title: lift.exerciseName,
                                subtitle: MeasurementFormatting.recordedLiftSetText(weight: lift.weight, unit: lift.unit, repetitions: lift.repetitions),
                                mediaID: mediaID,
                                badge: "Lift video"
                            )
                        } else if let playbackURL {
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
                guard lift.demoMediaID == nil else { return }
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

    private var gymsForSelectedLocation: [Gym] {
        let matching = appState.gyms.filter {
            $0.city.caseInsensitiveCompare(draft.city) == .orderedSame &&
                $0.state.caseInsensitiveCompare(draft.state) == .orderedSame
        }
        return (matching.isEmpty ? appState.gyms : matching).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
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
                            value: selectedGym?.name ?? "Choose a gym",
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
                        Toggle("Hide lift videos", isOn: $draft.hideLiftVideos)
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
                    searchPrompt: selector == .location ? "Search city or state" : "Search gyms",
                    emptyTitle: selector == .location ? "No locations available" : "No gyms available",
                    emptyMessage: selector == .location
                        ? "Try a different city or state search."
                        : "Choose another location or request that this gym be added."
                ) { id in
                    select(id, for: selector)
                }
                .presentationDetents([.medium, .large])
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
                        outgoingDraft.yearsExperience = 0
                        outgoingDraft.experienceLevel = appState.earnedExperienceLevel
                        Task {
                            if await appState.saveEditedProfile(outgoingDraft, primaryGym: selectedGym, privacy: privacy) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedGym == nil || appState.accountOperationInProgress)
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
            return gymsForSelectedLocation.map {
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
                    ForEach(appState.leaderboardEntries().prefix(5)) { entry in
                        LeaderboardRow(entry: entry)
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
        }
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
