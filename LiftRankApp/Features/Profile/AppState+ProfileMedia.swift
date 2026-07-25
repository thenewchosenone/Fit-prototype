import Foundation
import UIKit

@MainActor
extension AppState {
    func updateBodyweight(_ entry: BodyweightEntry) {
        Haptics.light()
        trainingProgressStore.updateBodyweight(entry)
        repository.persistWorkoutSnapshot()
        guard let actual = entry.actual, actual > 0 else { return }
        var profile = currentProfile
        profile.bodyweightPounds = actual
        profileStore.saveProfile(profile)
        repository.persistWorkoutSnapshot()
        guard isAuthenticated, !isDemoMode else { return }
        Task {
            do {
                _ = try await profileStore.updateProfile(profile)
                repository.persistWorkoutSnapshot()
            } catch {
                accountMessage = userMessage(error)
            }
        }
    }

    func saveProfilePhoto(_ image: UIImage) {
        do {
            var profile = currentProfile
            let mode: AccountMode = isDemoMode ? .demo : .authenticated
            profile.avatarPath = try profilePhotoStore.save(image: image, userID: profile.id, mode: mode)
            profileStore.saveProfile(profile)
            repository.persistWorkoutSnapshot()
            guard isAuthenticated, !isDemoMode else {
                Haptics.success()
                return
            }
            guard let avatarPath = profile.avatarPath,
                  let fileURLs = profilePhotoStore.fileURLs(for: avatarPath) else {
                accountMessage = "Lift Rivals couldn't prepare that profile photo for upload."
                Haptics.warning()
                return
            }
            Task {
                do {
                    let uploadedAvatarPath = try await profileStore.uploadProfileAvatar(
                        avatarPath: avatarPath,
                        fullImageURL: fileURLs.fullImageURL,
                        thumbnailURL: fileURLs.thumbnailURL
                    )
                    if uploadedAvatarPath != avatarPath {
                        let fullImageData = try Data(contentsOf: fileURLs.fullImageURL)
                        let thumbnailData = try Data(contentsOf: fileURLs.thumbnailURL)
                        try profilePhotoStore.cache(
                            fullImageData: fullImageData,
                            thumbnailData: thumbnailData,
                            avatarPath: uploadedAvatarPath
                        )
                    }
                    profile.avatarPath = uploadedAvatarPath
                    _ = try await profileStore.updateProfile(profile)
                    repository.persistWorkoutSnapshot()
                } catch {
                    accountMessage = userMessage(error)
                }
            }
            Haptics.success()
        } catch {
            accountMessage = "Lift Rivals couldn't save that profile photo."
        }
    }

    func removeProfilePhoto() {
        let oldPath = currentProfile.avatarPath
        var profile = currentProfile
        profile.avatarPath = nil
        profileStore.saveProfile(profile)
        profilePhotoStore.remove(avatarPath: oldPath)
        repository.persistWorkoutSnapshot()
        guard isAuthenticated, !isDemoMode else {
            Haptics.warning()
            return
        }
        Task {
            do {
                try await profileStore.removeProfileAvatar(avatarPath: oldPath)
                _ = try await profileStore.updateProfile(profile)
                repository.persistWorkoutSnapshot()
            } catch {
                accountMessage = userMessage(error)
            }
        }
        Haptics.warning()
    }

    func cacheAuthenticatedProfilePhotoIfNeeded() async {
        guard isAuthenticated, !isDemoMode,
              let avatarPath = currentProfile.avatarPath,
              profilePhotoStore.thumbnail(for: avatarPath) == nil else { return }
        do {
            guard let download = try await profileStore.downloadProfileAvatar(avatarPath: avatarPath) else { return }
            try profilePhotoStore.cache(
                fullImageData: download.fullImageData,
                thumbnailData: download.thumbnailData,
                avatarPath: avatarPath
            )
            repository.persistWorkoutSnapshot()
        } catch {
            accountMessage = userMessage(error)
        }
    }

    func uploadProfilePhotoIfNeeded(avatarPath: String?) async throws -> String? {
        guard isAuthenticated, !isDemoMode, let avatarPath else { return avatarPath }
        guard let fileURLs = profilePhotoStore.fileURLs(for: avatarPath) else { return avatarPath }
        let uploadedAvatarPath = try await profileStore.uploadProfileAvatar(
            avatarPath: avatarPath,
            fullImageURL: fileURLs.fullImageURL,
            thumbnailURL: fileURLs.thumbnailURL
        )
        if uploadedAvatarPath != avatarPath {
            let fullImageData = try Data(contentsOf: fileURLs.fullImageURL)
            let thumbnailData = try Data(contentsOf: fileURLs.thumbnailURL)
            try profilePhotoStore.cache(
                fullImageData: fullImageData,
                thumbnailData: thumbnailData,
                avatarPath: uploadedAvatarPath
            )
        }
        return uploadedAvatarPath
    }

}
