import Foundation
import UIKit

@MainActor
extension AppState {
    func updateBodyweight(_ entry: BodyweightEntry) {
        Haptics.light()
        trainingProgressStore.updateBodyweight(entry)
        guard let actual = entry.actual, actual > 0 else { return }
        var profile = currentProfile
        profile.bodyweightPounds = actual
        profileStore.saveProfile(profile)
        guard isAuthenticated, !isDemoMode else { return }
        Task {
            do {
                _ = try await profileStore.updateProfile(profile)
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
            Haptics.success()
        } catch {
            accountMessage = "LiftRank couldn't save that profile photo."
        }
    }

    func removeProfilePhoto() {
        let oldPath = currentProfile.avatarPath
        var profile = currentProfile
        profile.avatarPath = nil
        profileStore.saveProfile(profile)
        profilePhotoStore.remove(avatarPath: oldPath)
        repository.persistWorkoutSnapshot()
        Haptics.warning()
    }

}
