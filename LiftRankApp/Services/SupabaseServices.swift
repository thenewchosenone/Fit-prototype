import Foundation
import Supabase

struct SupabaseConfiguration: Equatable {
    let url: URL
    let publicKey: String

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> SupabaseConfiguration? {
        let urlText = environment["LIFTRANK_SUPABASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "LIFTRANK_SUPABASE_URL") as? String
        let key = environment["LIFTRANK_SUPABASE_ANON_KEY"]
            ?? bundle.object(forInfoDictionaryKey: "LIFTRANK_SUPABASE_ANON_KEY") as? String
        guard let urlText, let url = URL(string: urlText), url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost",
              let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return SupabaseConfiguration(url: url, publicKey: key)
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
            let mapped = SupabaseServiceErrorMapper.map(error)
            if mapped == .sessionExpired || String(describing: error).lowercased().contains("missing session") { return nil }
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
