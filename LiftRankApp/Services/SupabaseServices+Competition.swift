import Foundation
import Supabase

// MARK: - Lift submissions and lift moderation actions

private struct LiftVoteParameters: Encodable {
    let liftID: UUID
    let voteValue: Int?
    enum CodingKeys: String, CodingKey {
        case liftID = "lift_id"
        case voteValue = "vote_value"
    }
}

private struct LiftReportParameters: Encodable {
    let liftID: UUID
    let reportReason: String
    let reportNote: String
    enum CodingKeys: String, CodingKey {
        case liftID = "lift_id"
        case reportReason = "report_reason"
        case reportNote = "report_note"
    }
}

@MainActor
final class SupabaseLiftService: LiftService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func submissions() async throws -> [LiftSubmission] {
        do {
            let pageSize = 500
            let recentRows: [CompetitiveLiftDTO] = try await client
                .from("lift_submissions")
                .select()
                .order("performed_at", ascending: false)
                .order("id")
                .limit(pageSize)
                .execute()
                .value
            let userID = try await client.auth.session.user.id
            var ownRows: [CompetitiveLiftDTO] = []
            var offset = 0
            while true {
                let page: [CompetitiveLiftDTO] = try await client
                    .from("lift_submissions")
                    .select()
                    .eq("user_id", value: userID)
                    .order("performed_at", ascending: false)
                    .order("id")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                ownRows.append(contentsOf: page)
                guard page.count == pageSize else { break }
                offset += pageSize
            }
            var seenIDs = Set<UUID>()
            return (recentRows + ownRows).compactMap { row in
                guard seenIDs.insert(row.id).inserted else { return nil }
                return row.submission
            }
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func submissions(ids: [UUID]) async throws -> [LiftSubmission] {
        guard !ids.isEmpty else { return [] }
        do {
            let rows: [CompetitiveLiftDTO] = try await client
                .from("lift_submissions")
                .select()
                .in("id", values: ids.map(\.uuidString))
                .execute()
                .value
            return rows.compactMap(\.submission)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        do {
            let row: CompetitiveLiftDTO = try await client
                .from("lift_submissions")
                .insert(CompetitiveLiftInsertDTO(submission: submission))
                .select()
                .single()
                .execute()
                .value
            guard let saved = row.submission else {
                throw LiftRankServiceError.server("The lift could not be read after submission.")
            }
            return saved
        }
        catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func removeSubmission(id: UUID) async throws {
        do {
            try await client.functions.invoke(
                "remove-lift-submission",
                options: FunctionInvokeOptions(body: ["submission_id": id.uuidString])
            )
        } catch let error as LiftRankServiceError {
            throw error
        } catch {
            throw SupabaseServiceErrorMapper.map(error)
        }
    }

    func vote(liftID: UUID, vote: LiftVoteValue?) async throws {
        do {
            try await client.rpc("vote_on_lift", params: LiftVoteParameters(liftID: liftID, voteValue: vote?.rawValue)).execute()
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {
        do {
            try await client.rpc(
                "report_lift",
                params: LiftReportParameters(liftID: liftID, reportReason: reason.rawValue, reportNote: note)
            ).execute()
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct CompetitiveLiftInsertDTO: Encodable {
    let id: UUID
    let userID: UUID
    let exerciseID: String
    let gymID: String?
    let weight: Double
    let unit: String
    let reps: Int
    let bodyweight: Double
    let visibility: String
    let verification: String
    let caption: String
    let performedAt: Date
    let repetitions: Int
    let isActualOneRepMax: Bool
    let leaderboardEligibleAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, weight, unit, reps, bodyweight, visibility, verification, caption, repetitions
        case userID = "user_id"
        case exerciseID = "exercise_id"
        case gymID = "gym_id"
        case performedAt = "performed_at"
        case isActualOneRepMax = "is_actual_one_rep_max"
        case leaderboardEligibleAt = "leaderboard_eligible_at"
    }

    init(submission: LiftSubmission) {
        id = submission.id
        userID = submission.userID
        exerciseID = submission.competitiveMovement?.canonicalExerciseID ?? submission.exerciseID
        gymID = submission.gymID?.uuidString
        weight = submission.weight
        unit = submission.unit.shortLabel
        reps = submission.repetitions
        bodyweight = submission.bodyweightAtLift
        visibility = submission.visibility.rawValue
        verification = "Self Reported"
        caption = submission.caption
        performedAt = submission.performedAt
        repetitions = submission.repetitions
        isActualOneRepMax = submission.isActualOneRepMax
        leaderboardEligibleAt = submission.leaderboardEligibleAt == .distantPast ? nil : submission.leaderboardEligibleAt
    }
}

struct CompetitiveLiftDTO: Decodable {
    let id: UUID
    let userID: UUID
    let exerciseID: String
    let gymID: String?
    let weight: Double
    let unit: String
    let reps: Int
    let bodyweight: Double?
    let visibility: String
    let verification: String
    let caption: String
    let performedAt: Date
    let createdAt: Date
    let repetitions: Int
    let isActualOneRepMax: Bool
    let competitiveMovement: String?
    let evidenceStatus: String
    let moderationStatus: String
    let weightPerHand: Bool
    let leaderboardEligibleAt: Date?
    let updatedAt: Date
    let videoAssetID: UUID?
    var approvedEvidenceStoragePath: String? = nil
    var pendingEvidenceStoragePath: String? = nil
    var evidenceStoragePath: String? = nil
    var reviewStatus: String? = nil
    var evidencePublic: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case id, weight, unit, reps, bodyweight, visibility, verification, caption, repetitions
        case userID = "user_id"
        case exerciseID = "exercise_id"
        case gymID = "gym_id"
        case performedAt = "performed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActualOneRepMax = "is_actual_one_rep_max"
        case competitiveMovement = "competitive_movement"
        case evidenceStatus = "evidence_status"
        case moderationStatus = "moderation_status"
        case weightPerHand = "weight_per_hand"
        case leaderboardEligibleAt = "leaderboard_eligible_at"
        case videoAssetID = "video_asset_id"
        case approvedEvidenceStoragePath = "approved_evidence_storage_path"
        case pendingEvidenceStoragePath = "pending_evidence_storage_path"
        case evidenceStoragePath = "evidence_storage_path"
        case reviewStatus = "review_status"
        case evidencePublic = "evidence_public"
    }

    var submission: LiftSubmission? {
        let gymID = gymID.flatMap(UUID.init(uuidString:))
        let movement = competitiveMovement.flatMap(CompetitiveMovement.init(rawValue:))
        let liftUnit: UnitSystem = unit == "kg" ? .kilograms : .pounds
        let bodyweight = bodyweight ?? 0
        let weightPounds = liftUnit == .pounds ? weight : RankingCalculator.kilogramsToPounds(weight)
        let estimatedOneRepMax = isActualOneRepMax
            ? weightPounds
            : RankingCalculator.epleyOneRepMax(weight: weightPounds, repetitions: repetitions)

        return LiftSubmission(
            id: id,
            userID: userID,
            exerciseID: exerciseID,
            exerciseName: movement?.title ?? exerciseID,
            weight: weight,
            unit: liftUnit,
            normalizedWeightKilograms: liftUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight),
            repetitions: repetitions,
            isActualOneRepMax: isActualOneRepMax,
            estimatedOneRepMax: estimatedOneRepMax,
            bodyweightAtLift: bodyweight,
            bodyweightMultiple: bodyweight > 0 ? weightPounds / bodyweight : 0,
            equipmentType: .raw,
            variation: movement?.title ?? exerciseID,
            gymID: gymID,
            performedAt: performedAt,
            localVideoURL: nil,
            remoteVideoURL: nil,
            caption: caption,
            verificationStatus: VerificationStatus(rawValue: verification) ?? (evidenceStatus == "video_backed" ? .videoVerified : .selfReported),
            visibility: LiftVisibility(rawValue: visibility) ?? .privateLift,
            leaderboardEligibleAt: leaderboardEligibleAt ?? .distantFuture,
            createdAt: createdAt,
            updatedAt: updatedAt,
            competitiveMovement: movement,
            evidenceStatus: LiftEvidenceStatus(rawValue: evidenceStatus),
            moderationStatus: LiftModerationStatus(rawValue: moderationStatus),
            videoAssetID: videoAssetID,
            weightPerHand: weightPerHand,
            hasProtectedEvidence: evidenceStatus != LiftEvidenceStatus.selfReported.rawValue ||
                videoAssetID != nil ||
                !(approvedEvidenceStoragePath ?? "").isEmpty ||
                !(pendingEvidenceStoragePath ?? "").isEmpty ||
                !(evidenceStoragePath ?? "").isEmpty ||
                reviewStatus?.lowercased() == "approved" ||
                evidencePublic == true
        )
    }
}
