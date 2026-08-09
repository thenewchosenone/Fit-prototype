import Foundation
import UIKit

@MainActor
extension AppState {
    func updateBodyweight(_ entry: BodyweightEntry) {
        Haptics.light()
        guard let actual = entry.actual, actual > 0 else { return }
        var profile = currentProfile
        profile.bodyweightPounds = actual
        guard isAuthenticated, !isDemoMode else {
            trainingProgressStore.updateBodyweight(entry)
            profileStore.saveProfile(profile)
            repository.persistWorkoutSnapshot()
            return
        }
        let userID = profile.id
        Task {
            do {
                guard accountSession?.userID == userID,
                      repository.currentProfile.id == userID else { return }
                try await profileStore.saveBodyweightEntry(entry)
                guard accountSession?.userID == userID,
                      repository.currentProfile.id == userID else { return }
                trainingProgressStore.updateBodyweight(entry)
                profileStore.saveProfile(profile)
                repository.persistWorkoutSnapshot()
            } catch {
                guard accountSession?.userID == userID else { return }
                accountMessage = userMessage(error)
            }
        }
    }

    func saveProfilePhoto(_ image: UIImage) {
        do {
            profilePhotoMutation += 1
            let mutation = profilePhotoMutation
            var profile = currentProfile
            let userID = profile.id
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
                    guard repository.currentProfile.id == userID,
                          mutation == profilePhotoMutation else { return }
                    let uploadedAvatarPath = try await profileStore.uploadProfileAvatar(
                        avatarPath: avatarPath,
                        fullImageURL: fileURLs.fullImageURL,
                        thumbnailURL: fileURLs.thumbnailURL
                    )
                    guard repository.currentProfile.id == userID,
                          mutation == profilePhotoMutation else { return }
                    if uploadedAvatarPath != avatarPath {
                        let fullImageData = try Data(contentsOf: fileURLs.fullImageURL)
                        let thumbnailData = try Data(contentsOf: fileURLs.thumbnailURL)
                        try profilePhotoStore.cache(
                            fullImageData: fullImageData,
                            thumbnailData: thumbnailData,
                            avatarPath: uploadedAvatarPath
                        )
                    }
                    guard repository.currentProfile.id == userID,
                          mutation == profilePhotoMutation else { return }
                    profile.avatarPath = uploadedAvatarPath
                    _ = try await profileStore.updateProfile(profile)
                    profilePhotoStore.markUploadComplete(avatarPath: avatarPath)
                    profilePhotoStore.markUploadComplete(avatarPath: uploadedAvatarPath)
                    if uploadedAvatarPath != avatarPath {
                        profilePhotoStore.remove(avatarPath: avatarPath)
                    }
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
        profilePhotoMutation += 1
        let mutation = profilePhotoMutation
        let oldPath = currentProfile.avatarPath
        var profile = currentProfile
        let userID = profile.id
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
                guard repository.currentProfile.id == userID,
                      mutation == profilePhotoMutation else { return }
                try await profileStore.removeProfileAvatar(avatarPath: oldPath)
                guard repository.currentProfile.id == userID,
                      mutation == profilePhotoMutation else { return }
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
        let userID = currentProfile.id
        do {
            guard let download = try await profileStore.downloadProfileAvatar(avatarPath: avatarPath) else { return }
            guard repository.currentProfile.id == userID,
                  repository.currentProfile.avatarPath == avatarPath else { return }
            try profilePhotoStore.cache(
                fullImageData: download.fullImageData,
                thumbnailData: download.thumbnailData,
                avatarPath: avatarPath
            )
            profilePhotoStore.markUploadComplete(avatarPath: avatarPath)
            objectWillChange.send()
            repository.persistWorkoutSnapshot()
        } catch {
            accountMessage = userMessage(error)
        }
    }

    func uploadProfilePhotoIfNeeded(avatarPath: String?) async throws -> String? {
        guard !isDemoMode,
              let userID = accountSession?.userID,
              userID == currentProfile.id,
              let avatarPath else { return avatarPath }
        guard let fileURLs = profilePhotoStore.fileURLs(for: avatarPath) else { return avatarPath }
        guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
        let uploadedAvatarPath = try await profileStore.uploadProfileAvatar(
            avatarPath: avatarPath,
            fullImageURL: fileURLs.fullImageURL,
            thumbnailURL: fileURLs.thumbnailURL
        )
        guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
        if uploadedAvatarPath != avatarPath {
            let fullImageData = try Data(contentsOf: fileURLs.fullImageURL)
            let thumbnailData = try Data(contentsOf: fileURLs.thumbnailURL)
            try profilePhotoStore.cache(
                fullImageData: fullImageData,
                thumbnailData: thumbnailData,
                avatarPath: uploadedAvatarPath
            )
        }
        guard repository.currentProfile.id == userID else { throw LiftRankServiceError.sessionExpired }
        profilePhotoStore.markUploadComplete(avatarPath: avatarPath)
        profilePhotoStore.markUploadComplete(avatarPath: uploadedAvatarPath)
        if uploadedAvatarPath != avatarPath {
            profilePhotoStore.remove(avatarPath: avatarPath)
        }
        return uploadedAvatarPath
    }

}
