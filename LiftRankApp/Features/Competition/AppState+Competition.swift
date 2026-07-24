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
            filters.timeRange,
            verifiedOnly ? "verified" : "all"
        ].joined(separator: "|")
    }

    func refreshLeaderboard() async {
        guard isAuthenticated, !isDemoMode else { return }
        await competitionStore.refreshLeaderboard()
    }

    func selectLeaderboardExercise(_ exerciseID: String?) {
        competitionStore.selectLeaderboardExercise(exerciseID)
    }

    func normalizeLeaderboardFilters() {
        competitionStore.normalizeFilters()
        if !features.gymFeeds {
            competitionStore.filters.gymID = nil
        }
    }

    func submitLift(exercise: Exercise, weight: Double, unit: UnitSystem, reps: Int, isActual: Bool, bodyweight: Double, date: Date, gymID: UUID, equipment: EquipmentType, visibility: LiftVisibility, videoURL: URL?, caption: String, requestVerification: Bool) async {
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
            accountMessage = "The lift could not be submitted. Check the selected gym and your connection, then try again."
            Haptics.warning()
        } else {
            if videoURL != nil, submission?.evidenceStatus != .videoBacked {
                accountMessage = "The lift was saved as self-reported, but the video upload did not finish."
            }
            Haptics.success()
        }
    }

}
