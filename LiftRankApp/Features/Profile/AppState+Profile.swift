import Foundation

@MainActor
extension AppState {
    func connectOnboardingPrimaryGym(_ gym: Gym) async throws {
        guard isAuthenticated, !isDemoMode else { return }
        guard try await accountSocialStore.ensureGymJoined(
            gym,
            maximumMemberships: Self.maximumJoinedGyms,
            authenticated: true
        ) else { throw LiftRankServiceError.gymLimitReached }
        try await accountSocialStore.setPrimaryGym(gym, authenticated: true)
    }

    func updateProfile(_ profile: UserProfile) {
        Task {
            do {
                _ = try await profileStore.updateProfile(profile)
                repository.persistWorkoutSnapshot()
            } catch {
                accountMessage = userMessage(error)
            }
        }
    }

    func saveEditedProfile(_ profile: UserProfile, primaryGym: Gym?, privacy: ProfilePrivacySettings) async -> Bool {
        guard beginAccountMutation() else { return false }
        defer { endAccountMutation() }

        var updatedProfile = profile
        if let primaryGym {
            updatedProfile.primaryGymID = primaryGym.id
            updatedProfile.primaryGymName = primaryGym.name
        }
        updatedProfile.yearsExperience = 0
        updatedProfile.experienceLevel = earnedExperienceLevel

        do {
            if features.gymFeeds, let primaryGym, isAuthenticated && !isDemoMode {
                guard try await accountSocialStore.ensureGymJoined(
                    primaryGym,
                    maximumMemberships: Self.maximumJoinedGyms,
                    authenticated: true
                ) else { throw LiftRankServiceError.gymLimitReached }
                try await accountSocialStore.setPrimaryGym(primaryGym, authenticated: true)
            } else if features.gymFeeds,
                        let primaryGym,
                        !profileStore.isGymJoined(primaryGym.id) &&
                        !profileStore.joinGym(primaryGym, maximumMemberships: Self.maximumJoinedGyms) {
                throw LiftRankServiceError.gymLimitReached
            }

            _ = try await profileStore.saveEditedProfile(
                updatedProfile,
                primaryGym: primaryGym,
                privacy: privacy,
                authenticated: isAuthenticated && !isDemoMode
            )
            setAuthenticatedPrivacy(privacy)
            if isAuthenticated && !isDemoMode {
                await refreshRemoteSocialState()
            }
            repository.persistWorkoutSnapshot()
            Haptics.success()
            return true
        } catch {
            accountMessage = userMessage(error)
            Haptics.warning()
            return false
        }
    }

    func updateVerification(_ lift: LiftSubmission, status: VerificationStatus, note: String?) {
        Haptics.success()
        Task {
            _ = await competitionStore.updateVerification(
                for: lift,
                status: status,
                note: note
            )
        }
    }

}
