import Foundation
import Supabase

enum LiftRankBackendEnvironment: String, Equatable {
    case local
    case staging
    case production
}

struct SupabaseConfiguration: Equatable {
    let url: URL
    let publicKey: String
    let environment: LiftRankBackendEnvironment

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> SupabaseConfiguration? {
        let urlText = environment["LIFTRANK_SUPABASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "LIFTRANK_SUPABASE_URL") as? String
        let key = environment["LIFTRANK_SUPABASE_ANON_KEY"]
            ?? bundle.object(forInfoDictionaryKey: "LIFTRANK_SUPABASE_ANON_KEY") as? String
        let environmentName = environment["LIFTRANK_BACKEND_ENVIRONMENT"]
            ?? bundle.object(forInfoDictionaryKey: "LIFTRANK_BACKEND_ENVIRONMENT") as? String
        guard let urlText, let url = URL(string: urlText), let host = url.host, let scheme = url.scheme,
              let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let environmentName,
              let backendEnvironment = LiftRankBackendEnvironment(rawValue: environmentName.lowercased()) else {
            return nil
        }
        if backendEnvironment == .local {
            guard ["127.0.0.1", "localhost"].contains(host), ["http", "https"].contains(scheme) else { return nil }
        } else {
            guard scheme == "https", !["127.0.0.1", "localhost"].contains(host) else { return nil }
        }
        return SupabaseConfiguration(url: url, publicKey: key, environment: backendEnvironment)
    }
}

enum SupabaseServiceErrorMapper {
    static func map(_ error: Error) -> LiftRankServiceError {
        let message = String(describing: error).lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") { return .invalidCredentials }
        if message.contains("jwt") || message.contains("session") && message.contains("expired") { return .sessionExpired }
        if message.contains("profiles_username_lower_unique") || message.contains("username") && message.contains("duplicate") { return .usernameUnavailable }
        if message.contains("three active gyms") { return .gymLimitReached }
        if message.contains("choose another primary gym") { return .primaryGymRequired }
        if message.contains("friendship or pending request") || message.contains("duplicate") { return .duplicateRelationship }
        if message.contains("permission denied") || message.contains("42501") { return .permissionDenied }
        if message.contains("network") || message.contains("offline") || message.contains("timed out") { return .networkUnavailable }
        return .server("LiftRank couldn't complete that request. Please try again.")
    }
}

@MainActor
final class SupabaseAuthenticationService: AuthenticationService {
    let client: SupabaseClient
    var isConfigured: Bool { true }
    var isDemoMode: Bool { false }

    init(client: SupabaseClient) { self.client = client }

    func restoreSession() async throws -> AccountSession? {
        do { return accountSession(try await client.auth.session) }
        catch {
            if let authError = error as? AuthError, authError == .sessionMissing { return nil }
            let mapped = SupabaseServiceErrorMapper.map(error)
            let message = String(describing: error).lowercased()
            if mapped == .sessionExpired || message.contains("missing session") || message.contains("session missing") { return nil }
            throw mapped
        }
    }

    func signUp(email: String, password: String) async throws -> AccountSession {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let session = response.session { return accountSession(session) }
            return AccountSession(userID: response.user.id, email: response.user.email, expiresAt: nil)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func signIn(email: String, password: String) async throws -> AccountSession {
        do { return accountSession(try await client.auth.signIn(email: email, password: password)) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func requestPasswordReset(email: String) async throws {
        do { try await client.auth.resetPasswordForEmail(email) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func signInWithApple(identityToken: String, nonce: String) async throws -> AccountSession {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: nonce)
            )
            return accountSession(session)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func signInDemo() async throws -> UserProfile { MockData.demoProfile }

    func signOut() async throws {
        do { try await client.auth.signOut() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    private func accountSession(_ session: Session) -> AccountSession {
        AccountSession(
            userID: session.user.id,
            email: session.user.email,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt))
        )
    }
}

private struct ProfileDTO: Codable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let avatarPath: String?
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case onboardingCompleted = "onboarding_completed"
    }
}

private struct PrivateDetailsDTO: Codable {
    let userID: UUID
    let birthDate: String?
    let sexCategory: String?
    let preferredUnit: String
    let heightCM: Double?
    let city: String?
    let region: String?
    let countryCode: String?
    let yearsExperience: Int?
    let experienceLevel: String?

    enum CodingKeys: String, CodingKey {
        case city, region
        case userID = "user_id"
        case birthDate = "birth_date"
        case sexCategory = "sex_category"
        case preferredUnit = "preferred_unit"
        case heightCM = "height_cm"
        case countryCode = "country_code"
        case yearsExperience = "years_experience"
        case experienceLevel = "experience_level"
    }
}

private struct PrivacyDTO: Codable {
    let userID: UUID
    let profileAudience: String
    let ageBandAudience: String
    let divisionAudience: String
    let bodyweightAudience: String
    let locationAudience: String
    let gymAudience: String
    let friendListAudience: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case profileAudience = "profile_audience"
        case ageBandAudience = "age_band_audience"
        case divisionAudience = "division_audience"
        case bodyweightAudience = "bodyweight_audience"
        case locationAudience = "location_audience"
        case gymAudience = "gym_audience"
        case friendListAudience = "friend_list_audience"
    }
}

private struct ProfileCardDTO: Codable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let avatarPath: String?
    let ageBand: String?
    let sexCategory: String?
    let city: String?
    let region: String?
    let countryCode: String?
    let primaryGymID: UUID?
    let primaryGymName: String?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, city, region
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case ageBand = "age_band"
        case sexCategory = "sex_category"
        case countryCode = "country_code"
        case primaryGymID = "primary_gym_id"
        case primaryGymName = "primary_gym_name"
    }
}

@MainActor
final class SupabaseProfileService: ProfileService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func authenticatedProfile() async throws -> AuthenticatedProfile {
        do {
            let userID = try await client.auth.session.user.id
            let profile: ProfileDTO = try await client.from("profiles").select("id,username,display_name,bio,avatar_path,onboarding_completed").eq("id", value: userID).single().execute().value
            let details: PrivateDetailsDTO = try await client.from("profile_private_details").select().eq("user_id", value: userID).single().execute().value
            let privacy: PrivacyDTO = try await client.from("profile_privacy").select().eq("user_id", value: userID).single().execute().value
            return map(profile: profile, details: details, privacy: privacy)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func currentProfile() async throws -> UserProfile {
        let remote = try await authenticatedProfile()
        return userProfile(remote)
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let existing = try await authenticatedProfile()
        let draft = ProfileDraft(
            username: profile.username, displayName: profile.displayName, bio: existing.bio,
            preferredUnit: profile.preferredUnit, birthDate: existing.birthDate,
            sexCategory: profile.sexCategory, heightCentimeters: profile.heightInches * 2.54,
            city: profile.city, region: profile.state, countryCode: existing.countryCode ?? "US",
            yearsExperience: profile.yearsExperience, experienceLevel: profile.experienceLevel,
            privacy: ProfilePrivacySettings(
                profileAudience: existing.privacy.profileAudience,
                ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
                divisionAudience: existing.privacy.divisionAudience,
                bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
                locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
                gymAudience: profile.hideGym ? .privateProfile : .publicProfile,
                friendListAudience: existing.privacy.friendListAudience
            ),
            completesOnboarding: existing.onboardingCompleted
        )
        return userProfile(try await saveProfile(draft))
    }

    func saveProfile(_ draft: ProfileDraft) async throws -> AuthenticatedProfile {
        do {
            _ = try await claimUsername(draft.username)
            let params = SaveProfileParameters(draft: draft)
            try await client.rpc("save_own_profile", params: params).execute()
            return try await authenticatedProfile()
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func claimUsername(_ username: String) async throws -> String {
        let normalized = username.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            throw LiftRankServiceError.invalidInput("Use 3–24 lowercase letters, numbers, or underscores.")
        }
        do {
            let value: String = try await client.rpc("claim_username", params: ["desired_username": normalized]).execute().value
            return value
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func profileCard(userID: UUID) async throws -> PublicProfileCard {
        do {
            let dto: ProfileCardDTO = try await client.rpc("get_profile_card", params: ["target_user_id": userID]).single().execute().value
            return PublicProfileCard(
                id: dto.id, username: dto.username, displayName: dto.displayName, bio: dto.bio,
                avatarPath: dto.avatarPath, ageBand: dto.ageBand,
                sexCategory: sex(dto.sexCategory), city: dto.city, region: dto.region,
                countryCode: dto.countryCode, primaryGymID: dto.primaryGymID,
                primaryGymName: dto.primaryGymName
            )
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    private func map(profile: ProfileDTO, details: PrivateDetailsDTO, privacy: PrivacyDTO) -> AuthenticatedProfile {
        AuthenticatedProfile(
            id: profile.id, username: profile.username, displayName: profile.displayName,
            bio: profile.bio, avatarPath: profile.avatarPath,
            onboardingCompleted: profile.onboardingCompleted,
            preferredUnit: details.preferredUnit == "kg" ? .kilograms : .pounds,
            birthDate: details.birthDate.flatMap { ISO8601DateFormatter.liftRankDate.date(from: $0) },
            sexCategory: sex(details.sexCategory), heightCentimeters: details.heightCM,
            city: details.city, region: details.region, countryCode: details.countryCode,
            yearsExperience: details.yearsExperience,
            experienceLevel: details.experienceLevel.flatMap { value in ExperienceLevel.allCases.first { $0.rawValue.lowercased() == value } },
            privacy: ProfilePrivacySettings(
                profileAudience: PrivacyAudience(rawValue: privacy.profileAudience) ?? .publicProfile,
                ageBandAudience: PrivacyAudience(rawValue: privacy.ageBandAudience) ?? .publicProfile,
                divisionAudience: PrivacyAudience(rawValue: privacy.divisionAudience) ?? .publicProfile,
                bodyweightAudience: PrivacyAudience(rawValue: privacy.bodyweightAudience) ?? .privateProfile,
                locationAudience: PrivacyAudience(rawValue: privacy.locationAudience) ?? .friends,
                gymAudience: PrivacyAudience(rawValue: privacy.gymAudience) ?? .publicProfile,
                friendListAudience: PrivacyAudience(rawValue: privacy.friendListAudience) ?? .friends
            )
        )
    }

    private func userProfile(_ remote: AuthenticatedProfile) -> UserProfile {
        var profile = MockData.demoProfile
        profile.id = remote.id
        profile.username = remote.username
        profile.displayName = remote.displayName
        profile.preferredUnit = remote.preferredUnit
        profile.sexCategory = remote.sexCategory ?? .open
        profile.heightInches = (remote.heightCentimeters ?? 0) / 2.54
        profile.city = remote.city ?? ""
        profile.state = remote.region ?? ""
        profile.yearsExperience = remote.yearsExperience ?? 0
        profile.experienceLevel = remote.experienceLevel ?? .beginner
        profile.hideExactAge = remote.privacy.ageBandAudience == .privateProfile
        profile.hideCity = remote.privacy.locationAudience == .privateProfile
        profile.hideGym = remote.privacy.gymAudience == .privateProfile
        profile.followers = 0
        profile.following = 0
        return profile
    }

    private func sex(_ value: String?) -> SexCategory? {
        guard let value else { return nil }
        return SexCategory.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
    }
}

private struct SaveProfileParameters: Encodable {
    let newDisplayName: String
    let newBio: String
    let newPreferredUnit: String
    let newBirthDate: String?
    let newSexCategory: String?
    let newHeightCM: Double?
    let newCity: String
    let newRegion: String
    let newCountryCode: String
    let newYearsExperience: Int?
    let newExperienceLevel: String?
    let newProfileAudience: String
    let newAgeBandAudience: String
    let newDivisionAudience: String
    let newLocationAudience: String
    let newGymAudience: String
    let newFriendListAudience: String
    let completeOnboarding: Bool

    enum CodingKeys: String, CodingKey {
        case newDisplayName = "new_display_name", newBio = "new_bio"
        case newPreferredUnit = "new_preferred_unit", newBirthDate = "new_birth_date"
        case newSexCategory = "new_sex_category", newHeightCM = "new_height_cm"
        case newCity = "new_city", newRegion = "new_region", newCountryCode = "new_country_code"
        case newYearsExperience = "new_years_experience", newExperienceLevel = "new_experience_level"
        case newProfileAudience = "new_profile_audience", newAgeBandAudience = "new_age_band_audience"
        case newDivisionAudience = "new_division_audience", newLocationAudience = "new_location_audience"
        case newGymAudience = "new_gym_audience", newFriendListAudience = "new_friend_list_audience"
        case completeOnboarding = "complete_onboarding"
    }

    init(draft: ProfileDraft) {
        newDisplayName = draft.displayName
        newBio = draft.bio
        newPreferredUnit = draft.preferredUnit.shortLabel
        newBirthDate = draft.birthDate.map { ISO8601DateFormatter.liftRankDate.string(from: $0) }
        newSexCategory = draft.sexCategory?.rawValue.lowercased()
        newHeightCM = draft.heightCentimeters
        newCity = draft.city
        newRegion = draft.region
        newCountryCode = draft.countryCode
        newYearsExperience = draft.yearsExperience
        newExperienceLevel = draft.experienceLevel?.rawValue.lowercased()
        newProfileAudience = draft.privacy.profileAudience.rawValue
        newAgeBandAudience = draft.privacy.ageBandAudience.rawValue
        newDivisionAudience = draft.privacy.divisionAudience.rawValue
        newLocationAudience = draft.privacy.locationAudience.rawValue
        newGymAudience = draft.privacy.gymAudience.rawValue
        newFriendListAudience = draft.privacy.friendListAudience.rawValue
        completeOnboarding = draft.completesOnboarding
    }
}

private extension ISO8601DateFormatter {
    static let liftRankDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}

private struct GymDTO: Codable {
    let id: UUID
    let name: String
    let city: String?
    let region: String?
    enum CodingKeys: String, CodingKey { case id, name, city, region }
}

private struct MembershipDTO: Codable {
    let userID: UUID
    let gymID: UUID
    let isPrimary: Bool
    let joinedAt: Date
    let leftAt: Date?
    enum CodingKeys: String, CodingKey {
        case userID = "user_id", gymID = "gym_id", isPrimary = "is_primary"
        case joinedAt = "joined_at", leftAt = "left_at"
    }
}

@MainActor
final class SupabaseGymService: GymService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func gyms() async throws -> [Gym] {
        do {
            let rows: [GymDTO] = try await client.from("gyms").select("id,name,city,region").eq("status", value: "active").order("name").execute().value
            return rows.map { Gym(id: $0.id, name: $0.name, city: $0.city ?? "", state: $0.region ?? "", memberCount: 0, verifiedLiftCount: 0) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func memberships() async throws -> [GymMembershipRecord] {
        do {
            let rows: [MembershipDTO] = try await client.from("gym_memberships").select().is("left_at", value: nil).execute().value
            return rows.map { GymMembershipRecord(userID: $0.userID, gymID: $0.gymID, isPrimary: $0.isPrimary, joinedAt: $0.joinedAt, leftAt: $0.leftAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

@MainActor
final class SupabaseGymMembershipService: GymMembershipService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func join(_ gym: Gym, maximumMemberships: Int) async throws -> Bool {
        do { try await client.rpc("join_gym", params: JoinGymParameters(targetGymID: gym.id, makePrimary: false)).execute(); return true }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func leave(_ gym: Gym) async throws {
        do { try await client.rpc("leave_gym", params: ["target_gym_id": gym.id]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func setPrimary(_ gym: Gym) async throws {
        do { try await client.rpc("set_primary_gym", params: ["target_gym_id": gym.id]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct JoinGymParameters: Encodable {
    let targetGymID: UUID
    let makePrimary: Bool
    enum CodingKeys: String, CodingKey { case targetGymID = "target_gym_id", makePrimary = "make_primary" }
}

private struct RelationshipDTO: Codable {
    let id: UUID
    let userLowID: UUID
    let userHighID: UUID
    let requestedBy: UUID
    let status: FriendRelationshipState
    let createdAt: Date
    let respondedAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, status
        case userLowID = "user_low_id", userHighID = "user_high_id"
        case requestedBy = "requested_by", createdAt = "created_at", respondedAt = "responded_at"
    }
}

@MainActor
final class SupabaseFriendRelationshipService: FriendRelationshipService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func relationships() async throws -> [FriendRelationshipRecord] {
        do {
            let rows: [RelationshipDTO] = try await client.from("friend_relationships").select().order("created_at", ascending: false).execute().value
            return rows.map { FriendRelationshipRecord(id: $0.id, userLowID: $0.userLowID, userHighID: $0.userHighID, requestedBy: $0.requestedBy, status: $0.status, createdAt: $0.createdAt, respondedAt: $0.respondedAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func request(userID: UUID) async throws { try await rpc("request_friendship", RelationshipTargetParameters(targetUserID: userID)) }
    func respond(relationshipID: UUID, accept: Bool) async throws { try await rpc("respond_to_friendship", RelationshipResponseParameters(relationshipID: relationshipID, acceptRequest: accept)) }
    func cancel(relationshipID: UUID) async throws { try await rpc("cancel_friendship", RelationshipIDParameters(relationshipID: relationshipID)) }
    func remove(relationshipID: UUID) async throws { try await rpc("remove_friendship", RelationshipIDParameters(relationshipID: relationshipID)) }
    private func rpc<Parameters: Encodable>(_ name: String, _ params: Parameters) async throws {
        do { try await client.rpc(name, params: params).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct RelationshipTargetParameters: Encodable {
    let targetUserID: UUID
    enum CodingKeys: String, CodingKey { case targetUserID = "target_user_id" }
}

private struct RelationshipIDParameters: Encodable {
    let relationshipID: UUID
    enum CodingKeys: String, CodingKey { case relationshipID = "relationship_id" }
}

private struct RelationshipResponseParameters: Encodable {
    let relationshipID: UUID
    let acceptRequest: Bool
    enum CodingKeys: String, CodingKey { case relationshipID = "relationship_id", acceptRequest = "accept_request" }
}

private struct ExerciseDTO: Codable {
    let id: String
    let displayName: String
    let status: String
    let rankingMovement: String?
    enum CodingKeys: String, CodingKey {
        case id, status
        case displayName = "display_name", rankingMovement = "ranking_movement"
    }
}

@MainActor
final class SupabaseExerciseCatalogService: ExerciseCatalogService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func activeExercises() async throws -> [CatalogExercise] {
        do {
            let rows: [ExerciseDTO] = try await client.from("exercises").select("id,display_name,status,ranking_movement").eq("status", value: "active").order("display_name").execute().value
            return rows.map { CatalogExercise(id: $0.id, displayName: $0.displayName, status: $0.status, rankingMovement: $0.rankingMovement, metadata: [:]) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func resolve(identifier: String) async throws -> CatalogExercise? {
        do {
            let row: ExerciseDTO = try await client.rpc("resolve_exercise_identifier", params: ["identifier": identifier]).single().execute().value
            return CatalogExercise(id: row.id, displayName: row.displayName, status: row.status, rankingMovement: row.rankingMovement, metadata: [:])
        } catch {
            if String(describing: error).lowercased().contains("0 rows") { return nil }
            throw SupabaseServiceErrorMapper.map(error)
        }
    }
}

// MARK: - Public launch services

private struct LiftIDParameters: Encodable {
    let liftID: UUID
    enum CodingKeys: String, CodingKey { case liftID = "lift_id" }
}

private struct LiftVoteParameters: Encodable {
    let liftID: UUID
    let voteValue: Int?
    enum CodingKeys: String, CodingKey { case liftID = "lift_id", voteValue = "vote_value" }
}

private struct LiftReportParameters: Encodable {
    let liftID: UUID
    let reportReason: String
    let reportNote: String
    enum CodingKeys: String, CodingKey { case liftID = "lift_id", reportReason = "report_reason", reportNote = "report_note" }
}

@MainActor
final class SupabaseLiftService: LiftService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func submissions() async throws -> [LiftSubmission] {
        do {
            let rows: [CompetitiveLiftDTO] = try await client.from("lift_submissions").select().order("performed_at", ascending: false).execute().value
            return rows.compactMap(\.submission)
        }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func submit(_ submission: LiftSubmission) async throws -> LiftSubmission {
        do {
            let row: CompetitiveLiftDTO = try await client.from("lift_submissions")
                .insert(CompetitiveLiftInsertDTO(submission: submission))
                .select().single().execute().value
            guard let saved = row.submission else { throw LiftRankServiceError.server("The lift could not be read after submission.") }
            return saved
        }
        catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func vote(liftID: UUID, vote: CommunityVote?) async throws {
        do { try await client.rpc("vote_on_lift", params: LiftVoteParameters(liftID: liftID, voteValue: vote?.rawValue)).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func report(liftID: UUID, reason: LiftReportReason, note: String) async throws {
        do { try await client.rpc("report_lift", params: LiftReportParameters(liftID: liftID, reportReason: reason.rawValue, reportNote: note)).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct CompetitiveLiftInsertDTO: Encodable {
    let id: UUID; let userID: UUID; let exerciseID: String; let gymID: String
    let weight: Double; let unit: String; let reps: Int; let bodyweight: Double
    let visibility: String; let verification: String; let caption: String; let performedAt: Date
    let repetitions: Int; let isActualOneRepMax: Bool; let leaderboardEligibleAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, weight, unit, reps, bodyweight, visibility, verification, caption, repetitions
        case userID = "user_id", exerciseID = "exercise_id", gymID = "gym_id"
        case performedAt = "performed_at", isActualOneRepMax = "is_actual_one_rep_max"
        case leaderboardEligibleAt = "leaderboard_eligible_at"
    }
    init(submission: LiftSubmission) {
        id = submission.id; userID = submission.userID; exerciseID = submission.competitiveMovement?.canonicalExerciseID ?? submission.exerciseID
        gymID = submission.gymID.uuidString; weight = submission.weight; unit = submission.unit.shortLabel
        reps = submission.repetitions; bodyweight = submission.bodyweightAtLift
        visibility = submission.visibility == .followers ? "Friends" : submission.visibility.rawValue
        verification = "Self Reported"; caption = submission.caption; performedAt = submission.performedAt
        repetitions = submission.repetitions; isActualOneRepMax = submission.isActualOneRepMax
        leaderboardEligibleAt = submission.leaderboardEligibleAt == .distantPast ? nil : submission.leaderboardEligibleAt
    }
}

private struct CompetitiveLiftDTO: Decodable {
    let id: UUID; let userID: UUID; let exerciseID: String; let gymID: String
    let weight: Double; let unit: String; let reps: Int; let bodyweight: Double?
    let visibility: String; let verification: String; let caption: String; let performedAt: Date; let createdAt: Date
    let repetitions: Int; let isActualOneRepMax: Bool; let competitiveMovement: String?
    let evidenceStatus: String; let moderationStatus: String; let weightPerHand: Bool
    let leaderboardEligibleAt: Date?; let updatedAt: Date; let videoAssetID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, weight, unit, reps, bodyweight, visibility, verification, caption, repetitions
        case userID = "user_id", exerciseID = "exercise_id", gymID = "gym_id"
        case performedAt = "performed_at", createdAt = "created_at", updatedAt = "updated_at"
        case isActualOneRepMax = "is_actual_one_rep_max", competitiveMovement = "competitive_movement"
        case evidenceStatus = "evidence_status", moderationStatus = "moderation_status"
        case weightPerHand = "weight_per_hand", leaderboardEligibleAt = "leaderboard_eligible_at", videoAssetID = "video_asset_id"
    }

    var submission: LiftSubmission? {
        guard let gymID = UUID(uuidString: gymID) else { return nil }
        let movement = competitiveMovement.flatMap(CompetitiveMovement.init(rawValue:))
        let liftUnit: UnitSystem = unit == "kg" ? .kilograms : .pounds
        let bodyweight = bodyweight ?? 0
        let weightPounds = liftUnit == .pounds ? weight : RankingCalculator.kilogramsToPounds(weight)
        return LiftSubmission(
            id: id, userID: userID, exerciseID: exerciseID, exerciseName: movement?.title ?? exerciseID,
            weight: weight, unit: liftUnit,
            normalizedWeightKilograms: liftUnit == .kilograms ? weight : RankingCalculator.poundsToKilograms(weight),
            repetitions: repetitions, isActualOneRepMax: isActualOneRepMax, estimatedOneRepMax: weightPounds,
            bodyweightAtLift: bodyweight, bodyweightMultiple: bodyweight > 0 ? weightPounds / bodyweight : 0,
            equipmentType: .raw, variation: movement?.title ?? exerciseID, gymID: gymID, performedAt: performedAt,
            localVideoURL: nil, remoteVideoURL: nil, caption: caption,
            verificationStatus: VerificationStatus(rawValue: verification) ?? (evidenceStatus == "video_backed" ? .videoVerified : .selfReported),
            visibility: visibility == "Public" ? .publicLift : visibility == "Private" ? .privateLift : .followers,
            leaderboardEligibleAt: leaderboardEligibleAt ?? .distantFuture, createdAt: createdAt, updatedAt: updatedAt,
            competitiveMovement: movement, evidenceStatus: LiftEvidenceStatus(rawValue: evidenceStatus),
            moderationStatus: LiftModerationStatus(rawValue: moderationStatus), videoAssetID: videoAssetID, weightPerHand: weightPerHand
        )
    }
}

private struct LeaderboardParameters: Encodable {
    let exerciseID: String?
    let rankingType: String
    let gymID: UUID?
    let city: String?
    let region: String?
    let country: String?
    let ageBand: String?
    let sexCategory: String?
    let weightMinKG: Double?
    let weightMaxKG: Double?
    let verifiedOnly: Bool
    let timeRange: String
    enum CodingKeys: String, CodingKey {
        case exerciseID = "exercise_id", rankingType = "ranking_type", gymID = "gym_id", city, region, country
        case ageBand = "age_band", sexCategory = "sex_category", weightMinKG = "weight_min_kg", weightMaxKG = "weight_max_kg"
        case verifiedOnly = "verified_only", timeRange = "time_range"
    }
}

private struct RankedLiftIDDTO: Codable {
    let rank: Int
    let liftID: UUID
    let userID: UUID
    let rankMovement: Int
    let score: Double
    let bodyweightVisible: Bool
    enum CodingKeys: String, CodingKey {
        case rank, score
        case liftID = "lift_id", userID = "user_id", rankMovement = "rank_movement", bodyweightVisible = "bodyweight_visible"
    }
}

@MainActor
final class SupabaseLeaderboardService: LeaderboardService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func entries(filters: LeaderboardFilters, verifiedOnly: Bool) async throws -> [LeaderboardEntry] {
        do {
            let weightClass = filters.weightClassID.flatMap { id in MockData.weightClasses.first { $0.id == id } }
            let params = LeaderboardParameters(
                exerciseID: filters.exerciseID, rankingType: filters.rankingType.rawValue,
                gymID: filters.gymID, city: filters.city, region: filters.state, country: filters.country,
                ageBand: filters.ageGroup, sexCategory: filters.sexCategory?.rawValue,
                weightMinKG: weightClass?.minKilograms, weightMaxKG: weightClass?.maxKilograms,
                verifiedOnly: verifiedOnly, timeRange: filters.timeRange
            )
            let rows: [RankedLiftIDDTO] = try await client.rpc("get_ranked_lift_ids", params: params).execute().value
            let submissions = try await SupabaseLiftService(client: client).submissions()
            let lifts = Dictionary(uniqueKeysWithValues: submissions.map { ($0.id, $0) })
            var entries: [LeaderboardEntry] = []
            for row in rows {
                guard let lift = lifts[row.liftID] else { continue }
                let card = try await SupabaseProfileService(client: client).profileCard(userID: row.userID)
                var profile = MockData.demoProfile
                profile.id = card.id; profile.username = card.username; profile.displayName = card.displayName
                profile.ageGroup = card.ageBand ?? "Hidden"; profile.sexCategory = card.sexCategory ?? .open
                profile.bodyweightPounds = lift.bodyweightAtLift; profile.heightInches = 0
                profile.city = card.city ?? ""; profile.state = card.region ?? ""
                profile.primaryGymID = card.primaryGymID ?? lift.gymID; profile.primaryGymName = card.primaryGymName ?? "Gym hidden"
                profile.followers = 0; profile.following = 0; profile.hideExactAge = card.ageBand == nil
                profile.hideBodyweight = !row.bodyweightVisible; profile.hideCity = card.city == nil; profile.hideGym = card.primaryGymID == nil
                entries.append(LeaderboardEntry(rank: row.rank, profile: profile, lift: lift, rankMovement: row.rankMovement, score: row.score, powerliftingBreakdown: nil))
            }
            return entries
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct BlockDTO: Codable {
    let blockerID: UUID
    let blockedID: UUID
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case blockerID = "blocker_id", blockedID = "blocked_id", createdAt = "created_at" }
}
private struct ActivityDTO: Codable {
    let id: UUID
    let userID: UUID
    let username: String
    let displayName: String
    let title: String
    let detail: String
    let liftID: UUID?
    let createdAt: Date
    let isLiked: Bool
    let isSaved: Bool
    enum CodingKeys: String, CodingKey {
        case id, username, title, detail
        case userID = "user_id", displayName = "display_name", liftID = "lift_id"
        case createdAt = "created_at", isLiked = "is_liked", isSaved = "is_saved"
    }
}

@MainActor
final class SupabaseSocialService: SocialService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func feed() async throws -> [ActivityItem] {
        do {
            let rows: [ActivityDTO] = try await client.rpc("get_followed_activity").execute().value
            return rows.map { row in
                let profile = UserProfile(
                    id: row.userID, username: row.username, displayName: row.displayName,
                    ageGroup: "Hidden", sexCategory: .open, heightInches: 0, bodyweightPounds: 0,
                    preferredUnit: .pounds, city: "", state: "", primaryGymID: UUID(), primaryGymName: "Hidden",
                    yearsExperience: 0, experienceLevel: .beginner, profileImageName: "person.crop.circle", followers: 0, following: 0,
                    hideExactAge: true, hideBodyweight: true, hideCity: true, hideGym: true, hideLiftVideos: false
                )
                return ActivityItem(id: row.id, profile: profile, title: row.title, detail: row.detail, liftID: row.liftID, createdAt: row.createdAt, isLiked: row.isLiked, isSaved: row.isSaved)
            }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func block(userID: UUID) async throws { try await rpc("block_user", userID) }
    func unblock(userID: UUID) async throws { try await rpc("unblock_user", userID) }
    func blocks() async throws -> [UserBlockRecord] {
        do {
            let rows: [BlockDTO] = try await client.from("user_blocks").select().order("created_at", ascending: false).execute().value
            return rows.map { .init(blockerID: $0.blockerID, blockedID: $0.blockedID, createdAt: $0.createdAt) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    private func rpc(_ name: String, _ userID: UUID) async throws {
        do { try await client.rpc(name, params: ["target_user_id": userID]).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

@MainActor
final class SupabaseCommunityService: CommunityService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func communities() async throws -> [ForumCommunity] { do { let rows: [ForumCommunityDTO] = try await client.from("forum_communities").select().order("name").execute().value; return rows.map(\.community) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func posts(in destination: ForumDestination?) async throws -> [ForumPost] {
        do {
            var query = client.from("forum_posts").select()
            if let id = destination?.communityID { query = query.eq("community_id", value: id) }
            if let id = destination?.gymID { query = query.eq("gym_id", value: id) }
            let rows: [ForumPostDTO] = try await query.order("created_at", ascending: false).execute().value
            let votes: [ForumPostVoteDTO] = try await client.from("forum_post_votes").select().execute().value
            let saves: [ForumPostUserDTO] = try await client.from("forum_post_saves").select("post_id,user_id").execute().value
            let watches: [ForumPostUserDTO] = try await client.from("forum_post_watches").select("post_id,user_id").execute().value
            let comments: [ForumCommentDTO] = try await client.from("forum_comments").select().execute().value
            var result: [ForumPost] = []
            for row in rows {
                let card = try? await SupabaseProfileService(client: client).profileCard(userID: row.authorID)
                result.append(row.post(
                    authorName: card?.displayName ?? card?.username ?? "Member",
                    commentCount: comments.filter { $0.postID == row.id && $0.removedAt == nil }.count,
                    votes: Dictionary(uniqueKeysWithValues: votes.filter { $0.postID == row.id }.map { ($0.userID, $0.vote) }),
                    saves: Set(saves.filter { $0.postID == row.id }.map(\.userID)),
                    watches: Set(watches.filter { $0.postID == row.id }.map(\.userID))
                ))
            }
            return result
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func comments(for post: ForumPost) async throws -> [ForumComment] { do { let rows: [ForumCommentDTO] = try await client.from("forum_comments").select().eq("post_id", value: post.id).order("created_at").execute().value; let votes: [ForumCommentVoteDTO] = try await client.from("forum_comment_votes").select().execute().value; var result:[ForumComment]=[]; for row in rows { let card = try? await SupabaseProfileService(client: client).profileCard(userID: row.authorID); result.append(row.comment(authorName: card?.displayName ?? "Member", votes: Dictionary(uniqueKeysWithValues: votes.filter{$0.commentID==row.id}.map{($0.userID,$0.vote)}))) }; return result } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func join(community: ForumCommunity, note: String) async throws -> ForumMembershipStatus? { do { let value:String = try await client.rpc("join_forum_community", params:["target_community_id":community.id.uuidString,"request_note":note]).execute().value; return ForumMembershipStatus(rawValue:value) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func leave(community: ForumCommunity) async throws { do { try await client.rpc("leave_forum_community", params:["target_community_id":community.id]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func createPost(_ post: ForumPost) async throws -> Bool { do { let userID=try await client.auth.session.user.id; try await client.from("forum_posts").insert(ForumPostInsertDTO(post:post,userID:userID)).execute(); return true } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func addComment(to post: ForumPost, parentCommentID: UUID?, body: String) async throws -> ForumComment? { do { let userID=try await client.auth.session.user.id; let row:ForumCommentDTO=try await client.from("forum_comments").insert(ForumCommentInsertDTO(id:UUID(),postID:post.id,parentCommentID:parentCommentID,authorID:userID,body:body)).select().single().execute().value; return row.comment(authorName:"You",votes:[:]) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func vote(post: ForumPost, vote: CommunityVote?) async throws { try await setVote(table:"forum_post_votes",targetColumn:"post_id",targetID:post.id,vote:vote) }
    func vote(comment: ForumComment, vote: CommunityVote?) async throws { try await setVote(table:"forum_comment_votes",targetColumn:"comment_id",targetID:comment.id,vote:vote) }
    func toggleSaved(post: ForumPost) async throws { try await togglePostUser(table:"forum_post_saves",post:post,currentlySet:post.savedByUserIDs) }
    func toggleWatched(post: ForumPost) async throws { try await togglePostUser(table:"forum_post_watches",post:post,currentlySet:post.watchedByUserIDs) }
    func vote(pollPost: ForumPost, optionID: UUID) async throws { do { let userID=try await client.auth.session.user.id;try await client.from("forum_poll_votes").upsert(ForumPollVoteDTO(postID:pollPost.id,optionID:optionID,userID:userID),onConflict:"post_id,user_id").execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func report(targetType: ForumReportTargetType, targetID: UUID, communityID: UUID?, reason: CommunityReportReason, note: String) async throws -> Bool { do { let userID=try await client.auth.session.user.id;try await client.from("forum_reports").upsert(ForumReportInsertDTO(communityID:communityID,targetType:targetType.rawValue,targetID:targetID,reporterID:userID,reason:reason.rawValue,note:note),onConflict:"target_type,target_id,reporter_id",ignoreDuplicates:true).execute();return true } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func moderate(post: ForumPost, action: ForumModerationActionKind, reason: String) async throws { do { try await client.rpc("moderate_forum_post",params:["target_post_id":post.id.uuidString,"action":action.rawValue,"reason":reason]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func threads() async throws -> [CommunityThread] { try await posts(in:nil).map { CommunityThread(id:$0.id,title:$0.title,body:$0.body,authorID:$0.authorID,authorName:$0.authorName,kind:.general,challengeID:$0.challengeID,gymID:$0.destination.gymID,replyCount:$0.commentCount,likeCount:max(0,$0.voteScore),createdAt:$0.createdAt,votes:$0.votes,isLocked:$0.isLocked,removedAt:$0.removedAt,removalReason:$0.removalReason,warning:nil) } }
    func replies(for thread: CommunityThread) async throws -> [CommunityThreadReply] { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id}) else{return []};return try await comments(for:post).map{CommunityThreadReply(id:$0.id,threadID:$0.postID,authorID:$0.authorID,authorName:$0.authorName,body:$0.body,createdAt:$0.createdAt,votes:$0.votes,removedAt:$0.removedAt)} }
    func createThread(_ thread: CommunityThread) async throws -> CommunityThread { guard let community=try await communities().first else{throw LiftRankServiceError.server("No community is available.")};let post=ForumPost(id:thread.id,destination:thread.gymID.map(ForumDestination.gym) ?? .community(community.id),authorID:thread.authorID,authorName:thread.authorName,kind:.discussion,title:thread.title,body:thread.body,tag:nil,attachments:[],poll:nil,liftID:nil,workoutID:nil,linkURL:nil,challengeID:thread.challengeID,createdAt:thread.createdAt,editedAt:nil,commentCount:0,votes:[:],savedByUserIDs:[],watchedByUserIDs:[],isPinned:false,isLocked:false,removedAt:nil,removalReason:nil);_ = try await createPost(post);return thread }
    func addReply(to thread: CommunityThread, body: String) async throws -> CommunityThreadReply? { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id}),let value=try await addComment(to:post,parentCommentID:nil,body:body)else{return nil};return CommunityThreadReply(id:value.id,threadID:thread.id,authorID:value.authorID,authorName:value.authorName,body:value.body,createdAt:value.createdAt,votes:value.votes,removedAt:value.removedAt) }
    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) async throws { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id})else{return};try await self.vote(post:post,vote:vote) }
    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) async throws { let placeholder=ForumComment(id:reply.id,postID:reply.threadID,parentCommentID:nil,authorID:reply.authorID,authorName:reply.authorName,body:reply.body,createdAt:reply.createdAt,editedAt:nil,votes:reply.votes,removedAt:reply.removedAt,removalReason:nil);try await self.vote(comment:placeholder,vote:vote) }
    func report(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) async throws { _ = try await report(targetType:targetType == .thread ? .post:.comment,targetID:targetID,communityID:nil,reason:reason,note:note) }
    func moderate(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String?) async throws { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id})else{return};let action:ForumModerationActionKind = operation == .lock ? .lock : operation == .unlock ? .unlock : operation == .remove ? .remove : .restore;try await moderate(post:post,action:action,reason:reason ?? "") }

    private func setVote(table:String,targetColumn:String,targetID:UUID,vote:CommunityVote?) async throws { do { let userID=try await client.auth.session.user.id;if let vote{try await client.from(table).upsert(ForumVoteInsertDTO(targetColumn:targetColumn,targetID:targetID,userID:userID,value:vote.rawValue),onConflict:"\(targetColumn),user_id").execute()}else{try await client.from(table).delete().eq(targetColumn,value:targetID).eq("user_id",value:userID).execute()} } catch { throw SupabaseServiceErrorMapper.map(error) } }
    private func togglePostUser(table:String,post:ForumPost,currentlySet:Set<UUID>) async throws { do { let userID=try await client.auth.session.user.id;if currentlySet.contains(userID){try await client.from(table).delete().eq("post_id",value:post.id).eq("user_id",value:userID).execute()}else{try await client.from(table).insert(ForumPostUserDTO(postID:post.id,userID:userID)).execute()} } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct ForumCommunityDTO: Decodable {
    let id:UUID;let slug:String;let name:String;let summary:String;let details:String;let category:String;let symbolName:String;let accentHex:String;let visibility:String;let rules:[String];let availableTags:[String];let staffOwnerID:UUID?;let createdAt:Date;let archivedAt:Date?
    enum CodingKeys:String,CodingKey{case id,slug,name,summary,details,category,visibility,rules;case symbolName="symbol_name",accentHex="accent_hex",availableTags="available_tags",staffOwnerID="staff_owner_id",createdAt="created_at",archivedAt="archived_at"}
    var community:ForumCommunity{.init(id:id,slug:slug,name:name,summary:summary,details:details,category:category,symbolName:symbolName,accentHex:accentHex,visibility:ForumCommunityVisibility(rawValue:visibility) ?? .publicOpen,rules:rules,availableTags:availableTags,staffOwnerID:staffOwnerID ?? UUID(uuidString:"00000000-0000-0000-0000-000000000000")!,memberCount:0,postCount:0,createdAt:createdAt,archivedAt:archivedAt)}
}
private struct ForumPostDTO:Decodable{
    let id:UUID;let communityID:UUID?;let gymID:UUID?;let authorID:UUID;let kind:String;let title:String;let body:String;let tag:String?;let attachments:[ForumAttachment];let poll:ForumPoll?;let liftID:UUID?;let workoutID:UUID?;let linkURL:String?;let challengeID:UUID?;let isPinned:Bool;let isLocked:Bool;let removedAt:Date?;let removalReason:String?;let createdAt:Date;let editedAt:Date?
    enum CodingKeys:String,CodingKey{case id,kind,title,body,tag,attachments,poll;case communityID="community_id",gymID="gym_id",authorID="author_id",liftID="lift_id",workoutID="workout_id",linkURL="link_url",challengeID="challenge_id",isPinned="is_pinned",isLocked="is_locked",removedAt="removed_at",removalReason="removal_reason",createdAt="created_at",editedAt="edited_at"}
    func post(authorName:String,commentCount:Int,votes:[UUID:CommunityVote],saves:Set<UUID>,watches:Set<UUID>)->ForumPost{.init(id:id,destination:communityID.map(ForumDestination.community) ?? .gym(gymID!),authorID:authorID,authorName:authorName,kind:ForumPostKind(rawValue:kind) ?? .discussion,title:title,body:body,tag:tag,attachments:attachments,poll:poll,liftID:liftID,workoutID:workoutID,linkURL:linkURL.flatMap(URL.init(string:)),challengeID:challengeID,createdAt:createdAt,editedAt:editedAt,commentCount:commentCount,votes:votes,savedByUserIDs:saves,watchedByUserIDs:watches,isPinned:isPinned,isLocked:isLocked,removedAt:removedAt,removalReason:removalReason)}
}
private struct ForumPostInsertDTO:Encodable{
    let id:UUID;let communityID:UUID?;let gymID:UUID?;let authorID:UUID;let kind:String;let title:String;let body:String;let tag:String?;let attachments:[ForumAttachment];let poll:ForumPoll?;let liftID:UUID?;let workoutID:UUID?;let linkURL:String?;let challengeID:UUID?;let createdAt:Date
    enum CodingKeys:String,CodingKey{case id,kind,title,body,tag,attachments,poll;case communityID="community_id",gymID="gym_id",authorID="author_id",liftID="lift_id",workoutID="workout_id",linkURL="link_url",challengeID="challenge_id",createdAt="created_at"}
    init(post:ForumPost,userID:UUID){id=post.id;communityID=post.destination.communityID;gymID=post.destination.gymID;authorID=userID;kind=post.kind.rawValue;title=post.title;body=post.body;tag=post.tag;attachments=post.attachments;poll=post.poll;liftID=post.liftID;workoutID=post.workoutID;linkURL=post.linkURL?.absoluteString;challengeID=post.challengeID;createdAt=post.createdAt}
}
private struct ForumCommentDTO:Decodable{let id:UUID;let postID:UUID;let parentCommentID:UUID?;let authorID:UUID;let body:String;let createdAt:Date;let editedAt:Date?;let removedAt:Date?;let removalReason:String?;enum CodingKeys:String,CodingKey{case id,body;case postID="post_id",parentCommentID="parent_comment_id",authorID="author_id",createdAt="created_at",editedAt="edited_at",removedAt="removed_at",removalReason="removal_reason"};func comment(authorName:String,votes:[UUID:CommunityVote])->ForumComment{.init(id:id,postID:postID,parentCommentID:parentCommentID,authorID:authorID,authorName:authorName,body:body,createdAt:createdAt,editedAt:editedAt,votes:votes,removedAt:removedAt,removalReason:removalReason)}}
private struct ForumCommentInsertDTO:Encodable{let id:UUID;let postID:UUID;let parentCommentID:UUID?;let authorID:UUID;let body:String;enum CodingKeys:String,CodingKey{case id,body;case postID="post_id",parentCommentID="parent_comment_id",authorID="author_id"}}
private struct ForumPostVoteDTO:Decodable{let postID:UUID;let userID:UUID;let value:Int;enum CodingKeys:String,CodingKey{case value;case postID="post_id",userID="user_id"};var vote:CommunityVote{CommunityVote(rawValue:value) ?? .up}}
private struct ForumCommentVoteDTO:Decodable{let commentID:UUID;let userID:UUID;let value:Int;enum CodingKeys:String,CodingKey{case value;case commentID="comment_id",userID="user_id"};var vote:CommunityVote{CommunityVote(rawValue:value) ?? .up}}
private struct ForumPostUserDTO:Codable{let postID:UUID;let userID:UUID;enum CodingKeys:String,CodingKey{case postID="post_id",userID="user_id"}}
private struct ForumPollVoteDTO:Encodable{let postID:UUID;let optionID:UUID;let userID:UUID;enum CodingKeys:String,CodingKey{case postID="post_id",optionID="option_id",userID="user_id"}}
private struct ForumReportInsertDTO:Encodable{let communityID:UUID?;let targetType:String;let targetID:UUID;let reporterID:UUID;let reason:String;let note:String;enum CodingKeys:String,CodingKey{case reason,note;case communityID="community_id",targetType="target_type",targetID="target_id",reporterID="reporter_id"}}
private struct ForumVoteInsertDTO:Encodable{
    let targetColumn:String;let targetID:UUID;let userID:UUID;let value:Int
    struct DynamicKey:CodingKey{var stringValue:String;init?(stringValue:String){self.stringValue=stringValue};var intValue:Int?{nil};init?(intValue:Int){nil}}
    func encode(to encoder:Encoder)throws{var c=encoder.container(keyedBy:DynamicKey.self);try c.encode(targetID,forKey:DynamicKey(stringValue:targetColumn)!);try c.encode(userID,forKey:DynamicKey(stringValue:"user_id")!);try c.encode(value,forKey:DynamicKey(stringValue:"value")!)}
}

@MainActor
final class SupabaseMessagingService: MessagingService {
    private struct SendParameters: Encodable {
        let targetThreadID: UUID
        let messageBody: String
        enum CodingKeys: String, CodingKey { case targetThreadID = "target_thread_id", messageBody = "message_body" }
    }
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func createOrGetThread(with userID: UUID) async throws -> DirectMessageThread { do { let row:MessageThreadDTO=try await client.rpc("create_or_get_message_thread",params:["target_user_id":userID]).single().execute().value;return row.thread } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func threads() async throws -> [DirectMessageThread] { do { let rows: [MessageThreadDTO] = try await client.rpc("get_message_threads").execute().value; return rows.map(\.thread) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func messages(for thread: DirectMessageThread) async throws -> [DirectMessage] { do { let rows: [MessageDTO] = try await client.rpc("get_thread_messages", params: ["target_thread_id": thread.id]).execute().value; return rows.map(\.message) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func sendMessage(in thread: DirectMessageThread, body: String) async throws -> DirectMessage? { do { let row: MessageDTO = try await client.rpc("send_message", params: SendParameters(targetThreadID: thread.id, messageBody: body)).single().execute().value; return row.message } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func deleteMessage(_ message: DirectMessage) async throws { try await rpc("delete_message", id: message.id) }
    func deleteThread(_ thread: DirectMessageThread) async throws { try await rpc("hide_message_thread", id: thread.id) }
    func reportMessage(_ message: DirectMessage, reason: MessageReportReason, note: String) async throws { do { try await client.rpc("report_message", params: ["target_message_id": message.id.uuidString, "report_reason": reason.rawValue, "report_note": note]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    private func rpc(_ name: String, id: UUID) async throws { do { try await client.rpc(name, params: ["target_id": id]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct MessageThreadDTO: Decodable {
    let id: UUID; let participantIDs: [UUID]; let createdAt: Date; let updatedAt: Date
    enum CodingKeys: String, CodingKey { case id; case participantIDs = "participant_ids", createdAt = "created_at", updatedAt = "updated_at" }
    var thread: DirectMessageThread { .init(id: id, participantIDs: participantIDs, createdAt: createdAt, updatedAt: updatedAt) }
}
private struct MessageDTO: Decodable {
    let id: UUID; let threadID: UUID; let senderID: UUID; let body: String; let createdAt: Date; let isRead: Bool; let isReported: Bool
    enum CodingKeys: String, CodingKey { case id, body; case threadID = "thread_id", senderID = "sender_id", createdAt = "created_at", isRead = "is_read", isReported = "is_reported" }
    var message: DirectMessage { .init(id: id, threadID: threadID, senderID: senderID, body: body, createdAt: createdAt, isRead: isRead, isReported: isReported) }
}

private struct ModerateLiftParameters: Encodable {
    let liftID: UUID; let decision: String; let note: String
    enum CodingKeys: String, CodingKey { case liftID = "lift_id", decision, note }
}
@MainActor
final class SupabaseVerificationService: VerificationService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func pendingSubmissions() async throws -> [LiftSubmission] {
        do {
            let ids: [ModerationQueueIDDTO] = try await client.rpc("get_moderation_queue_ids").execute().value
            let all = try await SupabaseLiftService(client: client).submissions()
            let pending = Set(ids.map(\.liftID))
            return all.filter { pending.contains($0.id) }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func updateVerification(for lift: LiftSubmission, status: VerificationStatus, note: String?) async throws -> LiftSubmission {
        let decision: LiftModeratorDecision = status == .rejected ? .reject : .uphold
        return try await moderate(liftID: lift.id, decision: decision, note: note ?? "")
    }
    func moderate(liftID: UUID, decision: LiftModeratorDecision, note: String) async throws -> LiftSubmission {
        do {
            try await client.rpc("moderate_lift", params: ModerateLiftParameters(liftID: liftID, decision: decision.rawValue, note: note)).execute()
            guard let lift = try await SupabaseLiftService(client: client).submissions().first(where: { $0.id == liftID }) else {
                throw LiftRankServiceError.server("The moderated lift could not be refreshed.")
            }
            return lift
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct ModerationQueueIDDTO: Decodable {
    let liftID: UUID
    enum CodingKeys: String, CodingKey { case liftID = "lift_id" }
}

private struct MediaDTO: Codable {
    let id: UUID; let ownerID: UUID; let storagePath: String; let contentType: String; let byteCount: Int; let createdAt: Date
    enum CodingKeys: String, CodingKey { case id; case ownerID = "owner_id", storagePath = "storage_path", contentType = "content_type", byteCount = "byte_count", createdAt = "created_at" }
}
@MainActor
final class SupabaseMediaUploadService: MediaUploadService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func upload(localURL: URL?) async throws -> URL? { guard let localURL else { return nil }; let asset = try await uploadLiftVideo(localURL: localURL, liftID: UUID(), progress: { _ in }); return try await signedPlaybackURL(assetID: asset.id) }
    func uploadLiftVideo(localURL: URL, liftID: UUID, progress: @escaping @Sendable (Double) -> Void) async throws -> LiftMediaAsset {
        do {
            let userID = try await client.auth.session.user.id
            let assetID = UUID(); let path = "\(userID.uuidString)/\(liftID.uuidString)/\(assetID.uuidString).mov"
            _ = try await client.storage.from("lift-videos").upload(path, fileURL: localURL, options: FileOptions(cacheControl: "3600", contentType: "video/quicktime", upsert: false))
            progress(0.9)
            let size = (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let dto: MediaDTO = try await client.rpc("complete_lift_media_upload", params: CompleteMediaParameters(assetID: assetID, liftID: liftID, storagePath: path, contentType: "video/quicktime", byteCount: size)).single().execute().value
            progress(1)
            return .init(id: dto.id, ownerID: dto.ownerID, storagePath: dto.storagePath, contentType: dto.contentType, byteCount: dto.byteCount, createdAt: dto.createdAt)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func signedPlaybackURL(assetID: UUID) async throws -> URL {
        do { let dto: MediaDTO = try await client.rpc("get_lift_media_for_playback", params: ["asset_id": assetID]).single().execute().value; return try await client.storage.from("lift-videos").createSignedURL(path: dto.storagePath, expiresIn: 300) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

private struct CompleteMediaParameters: Encodable {
    let assetID: UUID; let liftID: UUID; let storagePath: String; let contentType: String; let byteCount: Int
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id", liftID = "lift_id", storagePath = "storage_path", contentType = "content_type", byteCount = "byte_count"
    }
}

@MainActor
final class SupabaseNotificationService: NotificationService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func notifications() async throws -> [NotificationItem] { do { let rows:[NotificationDTO]=try await client.from("notifications").select().order("created_at",ascending:false).execute().value;return rows.map(\.notification) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func markRead(notificationID: UUID) async throws { do { try await client.from("notifications").update(["read_at": Date().ISO8601Format()]).eq("id", value: notificationID).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func registerDevice(_ registration: PushDeviceRegistration) async throws { do { try await client.rpc("register_device_token", params: DeviceTokenParameters(registration:registration)).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func revokeDevice(deviceID: String) async throws { do { try await client.rpc("revoke_device_token", params: ["target_device_id": deviceID]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct NotificationDTO:Decodable{let id:UUID;let title:String;let body:String;let kind:String;let destination:NotificationDestination;let readAt:Date?;let createdAt:Date;enum CodingKeys:String,CodingKey{case id,title,body,kind,destination;case readAt="read_at",createdAt="created_at"};var notification:NotificationItem{.init(id:id,title:title,message:body,kind:kind,createdAt:createdAt,isRead:readAt != nil,destination:destination)}}
private struct DeviceTokenParameters:Encodable{let id:UUID;let deviceID:String;let token:String;let environment:String;enum CodingKeys:String,CodingKey{case id,token,environment;case deviceID="target_device_id"};init(registration:PushDeviceRegistration){id=registration.id;deviceID=registration.deviceID;token=registration.token;environment=registration.environment}}

@MainActor
final class SupabaseWorkoutSyncService: WorkoutSyncService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func plans() async throws -> [WorkoutPlanDocument] {
        do {
            let rows: [WorkoutPlanDocumentDTO] = try await client.from("workout_plan_documents").select().execute().value
            return rows.compactMap(\.document)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func savePlan(_ document: WorkoutPlanDocument, expectedRevision: Int) async throws -> WorkoutSyncResult {
        guard !document.isSeededDemoData else { throw LiftRankServiceError.invalidInput("Demo data cannot be synced.") }
        do {
            let userID = try await client.auth.session.user.id
            let next = WorkoutPlanDocumentDTO(document: document, ownerID: userID, revision: max(1, expectedRevision + 1))
            if expectedRevision == 0 {
                do {
                    let saved: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents").insert(next).select().single().execute().value
                    guard let value = saved.document else { throw LiftRankServiceError.server("The saved plan could not be read.") }
                    return .saved(value)
                } catch {
                    return try await preserveConflict(document, expectedRevision: expectedRevision, ownerID: userID)
                }
            }

            let updated: [WorkoutPlanDocumentDTO] = try await client
                .from("workout_plan_documents")
                .update(next)
                .eq("owner_id", value: userID)
                .eq("id", value: document.id)
                .eq("revision", value: expectedRevision)
                .select()
                .execute()
                .value
            guard let saved = updated.first?.document else {
                return try await preserveConflict(document, expectedRevision: expectedRevision, ownerID: userID)
            }
            return .saved(saved)
        } catch let error as LiftRankServiceError { throw error }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func deletePlan(id: UUID) async throws {
        do { try await client.from("workout_plan_documents").delete().eq("id", value: id).execute() }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func completedWorkouts(since: Date?) async throws -> [CompletedWorkoutSnapshot] {
        do {
            var query = client.from("completed_workout_snapshots").select()
            if let since { query = query.gt("completed_at", value: since) }
            let rows: [CompletedWorkoutSnapshotDTO] = try await query.execute().value
            return rows.compactMap(\.snapshot)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func uploadCompletedWorkout(_ snapshot: CompletedWorkoutSnapshot) async throws {
        guard !snapshot.isSeededDemoData else { return }
        do {
            let userID = try await client.auth.session.user.id
            let row = CompletedWorkoutSnapshotDTO(snapshot: snapshot, ownerID: userID)
            try await client.from("completed_workout_snapshots").upsert(row, onConflict: "owner_id,id", ignoreDuplicates: true).execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    private func preserveConflict(_ document: WorkoutPlanDocument, expectedRevision: Int, ownerID: UUID) async throws -> WorkoutSyncResult {
        let serverRow: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents")
            .select().eq("owner_id", value: ownerID).eq("id", value: document.id).single().execute().value
        guard let server = serverRow.document else { throw LiftRankServiceError.server("The server plan could not be read.") }
        var localCopy = document
        localCopy.id = UUID()
        localCopy.name = "\(document.name) (Conflict copy)"
        localCopy.revision = 1
        localCopy.conflictOfRevision = expectedRevision
        localCopy.isConflictCopy = true
        localCopy.updatedAt = .now
        let copyRow = WorkoutPlanDocumentDTO(document: localCopy, ownerID: ownerID, revision: 1)
        let inserted: WorkoutPlanDocumentDTO = try await client.from("workout_plan_documents").insert(copyRow).select().single().execute().value
        guard let savedCopy = inserted.document else { throw LiftRankServiceError.server("The conflict copy could not be read.") }
        return .conflict(server: server, localCopy: savedCopy)
    }
}

private struct WorkoutPlanDocumentDTO: Codable {
    let id: UUID
    let ownerID: UUID
    let revision: Int
    let name: String
    let payload: String
    let conflictOfRevision: Int?
    let isConflictCopy: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, revision, name, payload
        case ownerID = "owner_id"
        case conflictOfRevision = "conflict_of_revision"
        case isConflictCopy = "is_conflict_copy"
        case updatedAt = "updated_at"
    }

    init(document: WorkoutPlanDocument, ownerID: UUID, revision: Int) {
        id = document.id; self.ownerID = ownerID; self.revision = revision; name = document.name
        payload = document.payload.base64EncodedString(); conflictOfRevision = document.conflictOfRevision
        isConflictCopy = document.isConflictCopy; updatedAt = document.updatedAt
    }

    var document: WorkoutPlanDocument? {
        guard let data = Data(base64Encoded: payload) else { return nil }
        return WorkoutPlanDocument(id: id, ownerID: ownerID, revision: revision, name: name, payload: data, updatedAt: updatedAt, conflictOfRevision: conflictOfRevision, isConflictCopy: isConflictCopy)
    }
}

private struct CompletedWorkoutSnapshotDTO: Codable {
    let id: UUID
    let ownerID: UUID
    let payload: String
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, payload
        case ownerID = "owner_id"
        case completedAt = "completed_at"
    }

    init(snapshot: CompletedWorkoutSnapshot, ownerID: UUID) {
        id = snapshot.id; self.ownerID = ownerID; payload = snapshot.payload.base64EncodedString(); completedAt = snapshot.completedAt
    }

    var snapshot: CompletedWorkoutSnapshot? {
        guard let data = Data(base64Encoded: payload) else { return nil }
        return CompletedWorkoutSnapshot(id: id, ownerID: ownerID, payload: data, completedAt: completedAt)
    }
}

private struct AnalyticsEventInsertDTO: Encodable {
    let id: UUID
    let userID: UUID
    let name: String
    let properties: [String: String]
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case properties
        case occurredAt = "occurred_at"
    }
}

struct SupabaseAnalyticsService: AnalyticsService {
    let client: SupabaseClient
    func track(_ event: AnalyticsEventRecord) async {
        let row = AnalyticsEventInsertDTO(
            id: event.id,
            userID: event.userID,
            name: event.name.rawValue,
            properties: event.properties,
            occurredAt: event.occurredAt
        )
        _ = try? await client.from("analytics_events").insert(row).execute()
    }
}

private struct LegalAcceptanceDTO: Codable {
    let id: UUID
    let userID: UUID
    let documentKind: String
    let documentVersion: String
    let acceptedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case documentKind = "document_kind"
        case documentVersion = "document_version"
        case acceptedAt = "accepted_at"
    }
}

private struct LegalAcceptanceInsertDTO: Encodable {
    let userID: UUID
    let documentKind: String
    let documentVersion: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case documentKind = "document_kind"
        case documentVersion = "document_version"
    }
}

@MainActor
final class SupabaseLegalAcceptanceService: LegalAcceptanceService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func acceptances() async throws -> [LegalAcceptanceRecord] {
        do {
            let rows: [LegalAcceptanceDTO] = try await client
                .from("legal_acceptances")
                .select()
                .execute()
                .value
            return rows.map {
                LegalAcceptanceRecord(
                    id: $0.id,
                    userID: $0.userID,
                    documentKind: $0.documentKind,
                    documentVersion: $0.documentVersion,
                    acceptedAt: $0.acceptedAt
                )
            }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func accept(documents: [LegalDocument]) async throws {
        guard !documents.isEmpty else { return }
        do {
            let userID = try await client.auth.session.user.id
            let rows = documents.map {
                LegalAcceptanceInsertDTO(userID: userID, documentKind: $0.kind.rawValue, documentVersion: $0.version)
            }
            try await client
                .from("legal_acceptances")
                .upsert(rows, onConflict: "user_id,document_kind,document_version")
                .execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
}

struct SupabaseAccountDeletionService: AccountDeletionService {
    let client: SupabaseClient
    func deleteAccount() async throws { do { try await client.functions.invoke("delete-account") } catch { throw SupabaseServiceErrorMapper.map(error) } }
}
