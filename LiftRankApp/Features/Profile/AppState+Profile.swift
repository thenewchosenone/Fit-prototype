import Foundation

struct OnboardingStartingLift: Equatable {
    let exerciseID: String
    let weight: Double

    init?(exerciseID: String, weight: Double?) {
        guard let weight, weight > 0 else { return nil }
        self.exerciseID = exerciseID
        self.weight = weight
    }
}

@MainActor
extension AppState {
    func saveOnboardingStartingLifts(
        _ startingLifts: [OnboardingStartingLift],
        unit: UnitSystem,
        bodyweightPounds: Double,
        gymID: UUID?
    ) async throws {
        guard isAuthenticated, !isDemoMode else { return }
        guard bodyweightPounds > 0 else {
            throw LiftRankServiceError.invalidInput("Enter your current bodyweight before saving starting lifts.")
        }

        await refreshProductionLifts()
        for startingLift in startingLifts {
            guard let exercise = MockData.exercises.first(where: { $0.id == startingLift.exerciseID }) else {
                throw LiftRankServiceError.invalidInput("One of the starting lifts is not supported.")
            }
            let marker = "Starting lift from onboarding: \(startingLift.exerciseID)"
            if currentUserLifts.contains(where: { $0.caption == marker }) {
                continue
            }
            let saved = await competitionStore.submitLift(
                exercise: exercise,
                weight: startingLift.weight,
                unit: unit,
                reps: 1,
                isActual: true,
                bodyweight: bodyweightPounds,
                date: .now,
                gymID: joinedGyms.contains(where: { $0.id == gymID }) ? gymID : nil,
                equipment: .raw,
                visibility: .privateLift,
                videoURL: nil,
                caption: marker,
                requestVerification: false
            )
            guard saved != nil else {
                throw LiftRankServiceError.server("Your profile was saved, but one of your starting lifts was not. Try again to finish setup.")
            }
        }
    }

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
        guard CommunityContentPolicy.allows(profile.username, profile.displayName) else {
            accountMessage = CommunityContentPolicy.rejectionMessage
            Haptics.warning()
            return false
        }
        guard beginAccountMutation() else { return false }
        defer { endAccountMutation() }

        let editingUserID = currentProfile.id
        var updatedProfile = profile
        if let primaryGym {
            updatedProfile.primaryGymID = primaryGym.id
            updatedProfile.primaryGymName = primaryGym.name
        }
        updatedProfile.experienceLevel = earnedExperienceLevel

        do {
            guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
            if let primaryGym, isAuthenticated && !isDemoMode {
                guard try await accountSocialStore.ensureGymJoined(
                    primaryGym,
                    maximumMemberships: Self.maximumJoinedGyms,
                    authenticated: true
                ) else { throw LiftRankServiceError.gymLimitReached }
                guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
                try await accountSocialStore.setPrimaryGym(primaryGym, authenticated: true)
                guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
            } else if let primaryGym,
                        !profileStore.isGymJoined(primaryGym.id) &&
                        !profileStore.joinGym(primaryGym, maximumMemberships: Self.maximumJoinedGyms) {
                throw LiftRankServiceError.gymLimitReached
            }

            if isAuthenticated && !isDemoMode {
                updatedProfile.avatarPath = try await uploadProfilePhotoIfNeeded(
                    avatarPath: updatedProfile.avatarPath
                )
            }

            guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
            _ = try await profileStore.saveEditedProfile(
                updatedProfile,
                primaryGym: primaryGym,
                privacy: privacy,
                authenticated: isAuthenticated && !isDemoMode
            )
            guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
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
