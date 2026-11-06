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
    func shareWorkoutStartIfEnabled() {
        guard isAuthenticated, !isDemoMode,
              authenticatedPrivacy.shareWorkoutStartsWithFriends == true,
              let workoutID = activeWorkout?.id else { return }
        queueFriendActivity(.init(ownerID: currentProfile.id, kind: .workoutStarted, sourceID: workoutID))
    }

    func shareTopLiftIfEnabled(_ lift: LiftSubmission) {
        shareTopLiftIfEnabled(liftID: lift.id, ownerID: lift.userID)
    }

    func shareTopLiftIfEnabled(liftID: UUID, ownerID: UUID) {
        guard isAuthenticated, !isDemoMode,
              authenticatedPrivacy.sharePRsWithFriends == true,
              ownerID == currentProfile.id else { return }
        queueFriendActivity(.init(ownerID: ownerID, kind: .topLift, sourceID: liftID))
    }

    func retryFriendActivityShares() async {
        guard isAuthenticated, !isDemoMode else { return }
        let ownerID = currentProfile.id
        guard !repository.pendingFriendActivityShares.isEmpty else {
            friendActivityShareError = nil
            return
        }
        guard repository.persistWorkoutSnapshotReportingError() else {
            friendActivityShareError = "Friend activity could not be saved on this device. Retry when storage is available."
            return
        }
        for pending in repository.pendingFriendActivityShares where pending.ownerID == ownerID {
            await publishFriendActivity(pending)
        }
    }

    private func queueFriendActivity(_ pending: PendingFriendActivityShare) {
        guard currentProfile.id == pending.ownerID else { return }
        if !repository.pendingFriendActivityShares.contains(pending) {
            repository.pendingFriendActivityShares.append(pending)
        }
        guard repository.persistWorkoutSnapshotReportingError() else {
            friendActivityShareError = "Friend activity could not be saved on this device. Retry when storage is available."
            return
        }
        Task { await publishFriendActivity(pending) }
    }

    private func publishFriendActivity(_ pending: PendingFriendActivityShare) async {
        guard currentProfile.id == pending.ownerID,
              repository.pendingFriendActivityShares.contains(pending) else { return }
        do {
            switch pending.kind {
            case .workoutStarted:
                try await profileStore.recordFriendWorkoutStart(workoutID: pending.sourceID, ownerID: pending.ownerID)
            case .topLift:
                try await profileStore.recordFriendTopLift(liftID: pending.sourceID)
            }
            guard currentProfile.id == pending.ownerID,
                  repository.pendingFriendActivityShares.contains(pending) else { return }
            let previous = repository.pendingFriendActivityShares
            repository.pendingFriendActivityShares.removeAll { $0 == pending }
            if repository.persistWorkoutSnapshotReportingError() {
                if repository.pendingFriendActivityShares.isEmpty { friendActivityShareError = nil }
            } else {
                repository.pendingFriendActivityShares = previous
                friendActivityShareError = "Friend activity was shared, but its local queue could not be updated. Retry when storage is available."
            }
        } catch {
            guard currentProfile.id == pending.ownerID,
                  repository.pendingFriendActivityShares.contains(pending) else { return }
            friendActivityShareError = "Friend activity could not be shared. Check your connection, then retry."
        }
    }

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

    func visibleProfileLifts(
        for profileID: UUID,
        includeLiftsWithoutVideo: Bool = true
    ) async -> [LiftSubmission] {
        await competitionStore.visibleProfileLifts(
            for: profileID,
            viewerID: currentProfile.id,
            includeLiftsWithoutVideo: includeLiftsWithoutVideo
        )
    }

    func updateProfile(_ profile: UserProfile) {
        Task {
            do {
                _ = try await profileStore.updateProfile(profile)
                repository.scheduleWorkoutSnapshotPersistence()
            } catch {
                accountMessage = userMessage(error)
            }
        }
    }

    func reloadAccountSettings() async -> Bool {
        guard beginAccountMutation() else { return false }
        defer { endAccountMutation() }
        let userID = currentProfile.id
        do {
            let remote = try await profileStore.fetchAuthenticatedProfile()
            guard currentProfile.id == userID, remote.id == userID else {
                throw LiftRankServiceError.sessionExpired
            }
            profileStore.applyAuthenticatedProfile(remote, retainingDemoProfiles: false)
            setAuthenticatedPrivacy(remote.privacy)
            accountMessage = nil
            return true
        } catch {
            accountMessage = userMessage(error)
            return false
        }
    }

    func saveAccountSettings(_ settings: ProfileSettingsSnapshot, expected: ProfileSettingsSnapshot) async -> Bool {
        guard beginAccountMutation() else { return false }
        defer { endAccountMutation() }
        do {
            let remote = try await profileStore.saveSettings(settings, expected: expected)
            setAuthenticatedPrivacy(remote.privacy)
            repository.persistWorkoutSnapshotWithoutBlockingUI()
            await refreshRemoteSocialState()
            Haptics.success()
            return true
        } catch {
            accountMessage = userMessage(error)
            Haptics.warning()
            return false
        }
    }

    func saveEditedProfile(
        _ profile: UserProfile,
        primaryGym: Gym?,
        privacy: ProfilePrivacySettings,
        allowUsernameChange: Bool = false,
        updatePrimaryGym: Bool = false
    ) async -> Bool {
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
            if isAuthenticated && !isDemoMode,
               profile.city != currentProfile.city || profile.state != currentProfile.state || profile.countryCode != currentProfile.countryCode {
                let matches = try await serviceContainer.locations.searchCities(
                    countryCode: profile.countryCode ?? "US", region: profile.state, query: profile.city, limit: 50
                )
                guard let city = matches.first(where: {
                    $0.city.caseInsensitiveCompare(profile.city) == .orderedSame &&
                    $0.region.caseInsensitiveCompare(profile.state) == .orderedSame && $0.canonicalID != nil
                }) else {
                    throw LiftRankServiceError.invalidInput("Choose an available city before saving your location.")
                }
                updatedProfile.cityID = city.canonicalID
                updatedProfile.countryCode = city.countryCode
                updatedProfile.city = city.city
                updatedProfile.state = city.region
            }
            if let primaryGym, (!isAuthenticated || isDemoMode),
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
                authenticated: isAuthenticated && !isDemoMode,
                allowUsernameChange: allowUsernameChange,
                updatePrimaryGym: updatePrimaryGym
            )
            guard currentProfile.id == editingUserID else { throw LiftRankServiceError.sessionExpired }
            setAuthenticatedPrivacy(privacy)
            if isAuthenticated && !isDemoMode {
                await refreshRemoteSocialState()
            }
            repository.persistWorkoutSnapshotWithoutBlockingUI()
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
