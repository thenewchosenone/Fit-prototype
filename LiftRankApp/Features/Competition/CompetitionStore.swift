import Combine
import Foundation


@MainActor
final class CompetitionStore: ObservableObject {
    @Published var filters = LeaderboardFilters(exerciseID: nil)
    @Published var verifiedOnly = true
    @Published var focusRequestID: UUID?
    @Published var uploadProgress = 0.0
    @Published var lastSubmissionResult: LiftSubmission?
    @Published private(set) var remoteLeaderboardEntries: [LeaderboardEntry]?
    @Published private(set) var leaderboardError: String?

    private let repository: any CompetitionRepository
    private var liftService: (any LiftService)?
    private var leaderboardService: (any LeaderboardService)?
    private var verificationService: (any VerificationService)?
    private var mediaUploadService: (any MediaUploadService)?
    private var analyticsService: (any AnalyticsService)?
    private let weightClasses: [WeightClass]
    private let calendar: Calendar
    private let now: () -> Date
    private let makeID: () -> UUID
    private var hasLoadedProductionData = false
    private var productionUserID: UUID?
    private var leaderboardRequestID: UUID?
    private var activeUploadID: UUID?

    init(
        repository: any CompetitionRepository,
        liftService: (any LiftService)? = nil,
        leaderboardService: (any LeaderboardService)? = nil,
        verificationService: (any VerificationService)? = nil,
        mediaUploadService: (any MediaUploadService)? = nil,
        analyticsService: (any AnalyticsService)? = nil,
        weightClasses: [WeightClass] = WeightClassCatalog.all,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.liftService = liftService
        self.leaderboardService = leaderboardService
        self.verificationService = verificationService
        self.mediaUploadService = mediaUploadService
        self.analyticsService = analyticsService
        self.weightClasses = weightClasses
        self.calendar = calendar
        self.now = now
        self.makeID = makeID
    }

    func updateServices(
        liftService: any LiftService,
        leaderboardService: any LeaderboardService,
        verificationService: any VerificationService,
        mediaUploadService: any MediaUploadService,
        analyticsService: any AnalyticsService
    ) {
        self.liftService = liftService
        self.leaderboardService = leaderboardService
        self.verificationService = verificationService
        self.mediaUploadService = mediaUploadService
        self.analyticsService = analyticsService
    }

    func refreshProductionData() async {
        guard let liftService else { return }
        resetProductionDataIfNeeded()
        let userID = repository.currentProfile.id
        // Production must never retain seeded/demo rankings when loading fails.
        if !hasLoadedProductionData {
            repository.lifts = []
            remoteLeaderboardEntries = nil
        }
        guard let submissions = try? await liftService.submissions() else {
            if repository.currentProfile.id != userID {
                resetProductionDataIfNeeded()
            }
            return
        }
        guard repository.currentProfile.id == userID else {
            resetProductionDataIfNeeded()
            return
        }
        repository.lifts = submissions
        hasLoadedProductionData = true
        await refreshLeaderboard()
    }

    func refreshLeaderboard() async {
        guard let leaderboardService else { return }
        let userID = repository.currentProfile.id
        let requestID = makeID()
        leaderboardRequestID = requestID
        let requestFilters = filters
        let requestVerifiedOnly = verifiedOnly
        do {
            let entries = try await leaderboardService.entries(
                filters: requestFilters,
                verifiedOnly: requestVerifiedOnly
            )
            guard repository.currentProfile.id == userID else {
                resetProductionDataIfNeeded()
                return
            }
            guard leaderboardRequestID == requestID else { return }
            remoteLeaderboardEntries = entries
            leaderboardError = nil
        } catch {
            guard repository.currentProfile.id == userID else {
                resetProductionDataIfNeeded()
                return
            }
            guard leaderboardRequestID == requestID else { return }
            if remoteLeaderboardEntries == nil {
                remoteLeaderboardEntries = []
            }
            leaderboardError = error.localizedDescription
        }
    }

    var lifts: [LiftSubmission] { repository.lifts }

    var currentUserLifts: [LiftSubmission] {
        repository.lifts.filter { $0.userID == repository.currentProfile.id }
    }

    var pendingReviewLifts: [LiftSubmission] {
        repository.lifts.filter {
            $0.verificationStatus == .videoSubmitted || $0.verificationStatus == .selfReported
        }
    }

    var powerliftingTotal: Double {
        RankingCalculator.totalForUser(repository.currentProfile.id, lifts: repository.lifts)
    }

    var relativeTotal: Double {
        RankingCalculator.relativeTotal(
            total: powerliftingTotal,
            bodyweight: repository.currentProfile.bodyweightPounds
        )
    }

    var overallScore: Double {
        let best = currentUserLifts.map(\.estimatedOneRepMax).max() ?? 0
        let recentProgress = currentUserLifts.isEmpty ? 0.0 : 74.0
        return RankingCalculator.overallScore(
            relativeStrength: min(100, relativeTotal * 22),
            absoluteStrength: min(100, best / 6),
            recentProgress: recentProgress
        )
    }

    func leaderboardSnapshotDate(referenceDate: Date) -> Date {
        calendar.startOfDay(for: referenceDate)
    }

    func nextLeaderboardUpdateDate(referenceDate: Date) -> Date {
        let snapshotDate = leaderboardSnapshotDate(referenceDate: referenceDate)
        return calendar.date(byAdding: .day, value: 1, to: snapshotDate) ?? snapshotDate
    }

    func leaderboardEntries(referenceDate: Date) -> [LeaderboardEntry] {
        if let remoteLeaderboardEntries {
            let filtered = remoteLeaderboardEntries.filter { entry in
                if let repetitionCount = filters.repetitionCount,
                   entry.lift.repetitions != repetitionCount {
                    return false
                }
                if let experienceLevel = filters.experienceLevel,
                   entry.profile.experienceLevel != experienceLevel {
                    return false
                }
                if let verificationLevel = filters.verificationLevel {
                    let evidenceStatus: LiftEvidenceStatus = verificationLevel == .selfReported ? .selfReported : .videoBacked
                    if entry.lift.resolvedEvidenceStatus != evidenceStatus { return false }
                }
                return true
            }
            var previousScore: Double?
            var currentRank = 0
            return filtered.enumerated().map { index, entry in
                if previousScore == nil || entry.score != previousScore {
                    currentRank = index + 1
                }
                previousScore = entry.score
                return LeaderboardEntry(
                    rank: currentRank,
                    profile: entry.profile,
                    lift: entry.lift,
                    rankMovement: entry.rankMovement,
                    score: entry.score,
                    powerliftingBreakdown: entry.powerliftingBreakdown
                )
            }
        }
        let snapshotDate = leaderboardSnapshotDate(referenceDate: referenceDate)
        var filtered = repository.lifts.filter { $0.leaderboardEligibleAt <= snapshotDate }
        let profileByID = Dictionary(uniqueKeysWithValues: repository.profiles.map { ($0.id, $0) })

        if let exerciseID = filters.exerciseID {
            filtered = filtered.filter { $0.exerciseID == exerciseID }
        }
        if let repetitionCount = filters.repetitionCount {
            filtered = filtered.filter { $0.repetitions == repetitionCount }
        }
        if let status = filters.verificationLevel {
            let evidenceStatus: LiftEvidenceStatus = status == .selfReported ? .selfReported : .videoBacked
            filtered = filtered.filter { $0.resolvedEvidenceStatus == evidenceStatus }
        }
        if let gymID = filters.gymID {
            filtered = filtered.filter { $0.gymID == gymID }
        }
        if let city = filters.city, !city.isEmpty {
            filtered = filtered.filter {
                profileByID[$0.userID]?.city.caseInsensitiveCompare(city) == .orderedSame
            }
        }
        if let state = filters.state, !state.isEmpty {
            filtered = filtered.filter {
                profileByID[$0.userID]?.state.caseInsensitiveCompare(state) == .orderedSame
            }
        }
        if let sexCategory = filters.sexCategory {
            filtered = filtered.filter { profileByID[$0.userID]?.sexCategory == sexCategory }
        }
        if let ageGroup = filters.ageGroup, !ageGroup.isEmpty {
            filtered = filtered.filter { profileByID[$0.userID]?.ageGroup == ageGroup }
        }
        if let experienceLevel = filters.experienceLevel {
            filtered = filtered.filter { profileByID[$0.userID]?.experienceLevel == experienceLevel }
        }
        if let weightClassID = filters.weightClassID {
            filtered = filtered.filter { lift in
                guard let profile = profileByID[lift.userID] else { return false }
                return RankingCalculator.weightClass(
                    for: lift.bodyweightAtLift,
                    sexCategory: profile.sexCategory,
                    classes: weightClasses
                )?.id == weightClassID
            }
        }
        filtered = filtered.filter { isLift($0, inTimeRange: filters.timeRange) }

        return RankingCalculator.leaderboardEntries(
            profiles: repository.profiles,
            lifts: filtered,
            rankingType: filters.rankingType,
            verifiedOnly: verifiedOnly,
            currentUserID: repository.currentProfile.id,
            exerciseID: filters.exerciseID
        )
    }

    func selectLeaderboardExercise(_ exerciseID: String?) {
        filters.exerciseID = exerciseID
        filters.repetitionCount = nil
        if exerciseID == nil {
            filters.rankingType = .total
        } else if filters.rankingType == .total || filters.rankingType == .relativeTotal {
            filters.rankingType = .absolute
        }
    }

    func normalizeFilters() {
        filters.gymID = nil
        if let weightClassID = filters.weightClassID,
           !weightClasses.contains(where: { $0.id == weightClassID }) {
            filters.weightClassID = nil
        }
        if filters.exerciseID == nil {
            filters.repetitionCount = nil
        } else if filters.rankingType == .total || filters.rankingType == .relativeTotal {
            filters.rankingType = .absolute
        }
    }

    func requestFocus(filters: LeaderboardFilters, verifiedOnly: Bool = true) {
        self.filters = filters
        self.verifiedOnly = verifiedOnly
        focusRequestID = makeID()
    }

    func makeSubmission(
        exercise: Exercise,
        weight: Double,
        unit: UnitSystem,
        reps: Int,
        isActual: Bool,
        bodyweight: Double,
        date: Date,
        gymID: UUID,
        equipment: EquipmentType,
        visibility: LiftVisibility,
        videoURL: URL?,
        caption: String,
        requestVerification: Bool
    ) -> LiftSubmission? {
        guard repository.joinedGymIDs.contains(gymID) else { return nil }

        let oneRep = isActual
            ? weight
            : RankingCalculator.epleyOneRepMax(weight: weight, repetitions: reps)
        let oneRepPounds = unit == .pounds ? oneRep : RankingCalculator.kilogramsToPounds(oneRep)
        let movement = CompetitiveMovement.resolve(exerciseID: exercise.id)
        let timestamp = now()
        return LiftSubmission(
            id: makeID(),
            userID: repository.currentProfile.id,
            exerciseID: movement?.canonicalExerciseID ?? exercise.id,
            exerciseName: exercise.name,
            weight: weight,
            unit: unit,
            normalizedWeightKilograms: unit == .pounds
                ? RankingCalculator.poundsToKilograms(weight)
                : weight,
            repetitions: reps,
            isActualOneRepMax: isActual,
            estimatedOneRepMax: unit == .pounds
                ? oneRep
                : RankingCalculator.kilogramsToPounds(oneRep),
            bodyweightAtLift: bodyweight,
            bodyweightMultiple: RankingCalculator.bodyweightMultiple(
                oneRepMax: oneRepPounds,
                bodyweight: bodyweight
            ),
            equipmentType: equipment,
            variation: exercise.name,
            gymID: gymID,
            performedAt: date,
            localVideoURL: videoURL,
            remoteVideoURL: nil,
            caption: caption,
            verificationStatus: requestVerification && videoURL != nil ? .videoSubmitted : .selfReported,
            visibility: visibility,
            leaderboardEligibleAt: nextLeaderboardUpdateDate(referenceDate: timestamp),
            createdAt: timestamp,
            updatedAt: timestamp,
            competitiveMovement: movement,
            evidenceStatus: .selfReported,
            moderationStatus: .clear,
            weightPerHand: movement?.recordsWeightPerHand ?? false
        )
    }

    func submitLift(
        exercise: Exercise,
        weight: Double,
        unit: UnitSystem,
        reps: Int,
        isActual: Bool,
        bodyweight: Double,
        date: Date,
        gymID: UUID,
        equipment: EquipmentType,
        visibility: LiftVisibility,
        videoURL: URL?,
        caption: String,
        requestVerification: Bool
    ) async -> LiftSubmission? {
        let userID = repository.currentProfile.id
        guard let liftService,
              var submission = makeSubmission(
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
              ) else {
            lastSubmissionResult = nil
            return nil
        }

        uploadProgress = 0
        do {
            submission = try await liftService.submit(submission)
        } catch {
            lastSubmissionResult = nil
            return nil
        }
        guard repository.currentProfile.id == userID else {
            resetProductionDataIfNeeded()
            return nil
        }

        let movementName = submission.competitiveMovement?.rawValue ?? "noncanonical"
        await track(.prSubmitted, userID: userID, properties: ["movement": movementName])
        guard repository.currentProfile.id == userID else {
            resetProductionDataIfNeeded()
            return nil
        }
        submission.localVideoURL = videoURL

        if let videoURL, let mediaUploadService {
            let uploadID = UUID()
            activeUploadID = uploadID
            do {
                let asset = try await mediaUploadService.uploadLiftVideo(
                    localURL: videoURL,
                    liftID: submission.id,
                    progress: { [weak self] value in
                        Task { @MainActor in
                            guard self?.activeUploadID == uploadID else { return }
                            self?.uploadProgress = value
                        }
                    }
                )
                submission.videoAssetID = asset.id
                submission.evidenceStatus = .videoBacked
                submission.verificationStatus = .videoVerified
                submission.remoteVideoURL = try? await mediaUploadService.signedPlaybackURL(assetID: asset.id)
                guard repository.currentProfile.id == userID else {
                    activeUploadID = nil
                    resetProductionDataIfNeeded()
                    return nil
                }
                activeUploadID = nil
                uploadProgress = 1
                await track(.videoBackedPRSubmitted, userID: userID, properties: ["movement": movementName])
            } catch {
                // The lift remains submitted as self-reported when evidence upload fails.
                activeUploadID = nil
                submission.evidenceStatus = .selfReported
                submission.verificationStatus = .selfReported
                submission.videoAssetID = nil
                submission.localVideoURL = nil
                submission.remoteVideoURL = nil
                uploadProgress = 0
            }
        }

        guard repository.currentProfile.id == userID else {
            resetProductionDataIfNeeded()
            return nil
        }
        upsert(submission)
        lastSubmissionResult = submission
        return submission
    }

    func playbackURL(for lift: LiftSubmission) async -> URL? {
        let userID = repository.currentProfile.id
        if let localURL = lift.localVideoURL {
            if !localURL.isFileURL || FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
        }

        if let assetID = lift.videoAssetID, let mediaUploadService {
            if let signedURL = try? await mediaUploadService.signedPlaybackURL(assetID: assetID) {
                guard repository.currentProfile.id == userID else {
                    resetProductionDataIfNeeded()
                    return lift.remoteVideoURL
                }
                var updated = lift
                updated.remoteVideoURL = signedURL
                upsert(updated)
                return signedURL
            }
        }
        return lift.remoteVideoURL
    }

    func updateVerification(
        for lift: LiftSubmission,
        status: VerificationStatus,
        note: String?
    ) async -> LiftSubmission? {
        let userID = repository.currentProfile.id
        guard let verificationService,
              let updated = try? await verificationService.updateVerification(
                for: lift,
                status: status,
                note: note
              ) else { return nil }
        guard repository.currentProfile.id == userID else {
            resetProductionDataIfNeeded()
            return nil
        }
        upsert(updated)
        return updated
    }

    private func upsert(_ submission: LiftSubmission) {
        if let index = repository.lifts.firstIndex(where: { $0.id == submission.id }) {
            repository.lifts[index] = submission
        } else {
            repository.lifts.insert(submission, at: 0)
        }
        repository.refreshAchievementUnlocks(now: now())
    }

    private func track(_ name: AnalyticsEventName, userID: UUID, properties: [String: String]) async {
        guard let analyticsService else { return }
        await analyticsService.track(AnalyticsEventRecord(
            id: makeID(),
            userID: userID,
            name: name,
            occurredAt: now(),
            properties: properties
        ))
    }

    private func resetProductionDataIfNeeded() {
        guard productionUserID != repository.currentProfile.id else { return }
        productionUserID = repository.currentProfile.id
        hasLoadedProductionData = false
        repository.lifts = []
        repository.achievementUnlocks = []
        repository.rankingHistory = []
        remoteLeaderboardEntries = nil
        leaderboardRequestID = nil
        lastSubmissionResult = nil
        leaderboardError = nil
        uploadProgress = 0
    }

    private func isLift(_ lift: LiftSubmission, inTimeRange range: String) -> Bool {
        let referenceDate = now()
        switch range {
        case "This year":
            return calendar.component(.year, from: lift.performedAt) == calendar.component(.year, from: referenceDate)
        case "Last 90 days":
            guard let cutoff = calendar.date(byAdding: .day, value: -90, to: referenceDate) else { return true }
            return lift.performedAt >= cutoff
        case "This month":
            return calendar.component(.year, from: lift.performedAt) == calendar.component(.year, from: referenceDate) &&
                calendar.component(.month, from: lift.performedAt) == calendar.component(.month, from: referenceDate)
        case "This week":
            return calendar.isDate(lift.performedAt, equalTo: referenceDate, toGranularity: .weekOfYear)
        default:
            return true
        }
    }
}

extension CompetitionStore: WorkoutPRLiftSubmitting {
    func submitWorkoutPR(
        candidate: WorkoutPRCandidate,
        exercise: Exercise,
        workout: CompletedWorkout,
        profile: UserProfile,
        videoURL: URL
    ) async -> LiftSubmission? {
        let bodyweight = workout.bodyweight ?? profile.bodyweightPounds
        let bodyweightPounds = workout.unit == .kilograms
            ? RankingCalculator.kilogramsToPounds(bodyweight)
            : bodyweight
        return await submitLift(
            exercise: exercise,
            weight: candidate.weight,
            unit: candidate.unit,
            reps: candidate.repetitions,
            isActual: candidate.repetitions == 1,
            bodyweight: bodyweightPounds,
            date: workout.completedAt,
            gymID: workout.gymID ?? profile.primaryGymID,
            equipment: .raw,
            visibility: .publicLift,
            videoURL: videoURL,
            caption: "PR from \(workout.name): \(candidate.exerciseName) \(MeasurementFormatting.recordedLiftSetText(weight: candidate.weight, unit: candidate.unit, repetitions: candidate.repetitions))",
            requestVerification: true
        )
    }
}
