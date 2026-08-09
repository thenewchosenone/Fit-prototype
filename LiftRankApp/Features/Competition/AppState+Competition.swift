import Foundation

@MainActor
extension AppState {
    var powerliftingTotal: Double {
        competitionStore.powerliftingTotal
    }

    var relativeTotal: Double {
        competitionStore.relativeTotal
    }

    var overallScore: Double {
        competitionStore.overallScore
    }

    var currentUserTotalRankingEntry: LeaderboardEntry? {
        competitionStore.currentUserTotalEntry
    }

    var earnedExperienceLevel: ExperienceLevel {
        RankingFormatting.earnedExperienceLevel(
            relativeTotal: relativeTotal,
            verifiedLiftCount: competitiveStatistics.verifiedLiftCount
        )
    }

    var earnedExperienceDescription: String {
        RankingFormatting.earnedExperienceDescription(
            relativeTotal: relativeTotal,
            verifiedLiftCount: competitiveStatistics.verifiedLiftCount
        )
    }

    func leaderboardSnapshotDate(referenceDate: Date = .now) -> Date {
        competitionStore.leaderboardSnapshotDate(referenceDate: referenceDate)
    }

    func nextLeaderboardUpdateDate(referenceDate: Date = .now) -> Date {
        competitionStore.nextLeaderboardUpdateDate(referenceDate: referenceDate)
    }

    func leaderboardEntries(referenceDate: Date = .now) -> [LeaderboardEntry] {
        competitionStore.leaderboardEntries(referenceDate: referenceDate)
    }

    var isLeaderboardRequestPending: Bool {
        competitionStore.isLeaderboardRequestPending
    }

    var leaderboardRequestKey: String {
        let filters = leaderboardFilters
        return [
            filters.exerciseID ?? "all",
            filters.rankingType.rawValue,
            filters.gymID?.uuidString ?? "",
            filters.city ?? "",
            filters.state ?? "",
            filters.country ?? "",
            filters.ageGroup ?? "",
            filters.sexCategory?.rawValue ?? "",
            filters.weightClassID ?? "",
            filters.repetitionCount.map(String.init) ?? "",
            filters.experienceLevel?.rawValue ?? "",
            filters.verificationLevel?.rawValue ?? "",
            filters.timeRange,
            verifiedOnly ? "verified" : "all"
        ].joined(separator: "|")
    }

    func refreshLeaderboard() async {
        guard isAuthenticated, !isDemoMode else { return }
        await competitionStore.refreshLeaderboard()
    }

    func refreshCurrentUserTotalRanking() async {
        guard isAuthenticated, !isDemoMode else { return }
        await competitionStore.refreshCurrentUserTotalEntry()
    }

    func refreshProductionLifts() async {
        guard isAuthenticated, !isDemoMode else { return }
        await competitionStore.refreshProductionData()
    }

    func selectLeaderboardExercise(_ exerciseID: String?) {
        competitionStore.selectLeaderboardExercise(exerciseID)
    }

    func normalizeLeaderboardFilters() {
        competitionStore.normalizeFilters()
    }

    func submitLift(exercise: Exercise, weight: Double, unit: UnitSystem, reps: Int, isActual: Bool, bodyweight: Double, date: Date, gymID: UUID?, equipment: EquipmentType, visibility: LiftVisibility, videoURL: URL?, caption: String, requestVerification: Bool) async -> LiftSubmission? {
        guard CommunityContentPolicy.allows(caption) else {
            accountMessage = CommunityContentPolicy.rejectionMessage
            Haptics.warning()
            return nil
        }
        let submission = await competitionStore.submitLift(
            exercise: exercise,
            weight: weight,
            unit: unit,
            reps: reps,
            isActual: isActual,
            bodyweight: bodyweight,
            date: date,
            gymID: gymID,
            equipment: equipment,
            visibility: visibility,
            videoURL: videoURL,
            caption: caption,
            requestVerification: requestVerification
        )
        if submission == nil {
            accountMessage = "The lift could not be submitted. Check your connection, then try again."
            Haptics.warning()
        } else {
            if videoURL != nil, submission?.evidenceStatus != .videoBacked {
                accountMessage = "The lift was saved as self-reported, but the video upload did not finish."
            }
            Haptics.success()
        }
        return submission
    }

}
