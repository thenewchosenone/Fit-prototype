import Foundation
import Supabase

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

    func handleAuthCallback(_ url: URL) async throws -> AccountSession {
        do { return accountSession(try await client.auth.session(from: url)) }
        catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func updatePassword(_ password: String) async throws {
        do { _ = try await client.auth.update(user: UserAttributes(password: password)) }
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

#if DEBUG
    func signInDemo() async throws -> UserProfile { MockData.emptyProfile }
#endif

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
    let bodyweightPounds: Double?
    let city: String?
    let region: String?
    let countryCode: String?
    let cityID: UUID?
    let yearsExperience: Int?
    let experienceLevel: String?

    enum CodingKeys: String, CodingKey {
        case city, region
        case cityID = "city_id"
        case userID = "user_id"
        case birthDate = "birth_date"
        case sexCategory = "sex_category"
        case preferredUnit = "preferred_unit"
        case heightCM = "height_cm", bodyweightPounds = "bodyweight_lb"
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
    let showLiftVideos: Bool?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case profileAudience = "profile_audience"
        case ageBandAudience = "age_band_audience"
        case divisionAudience = "division_audience"
        case bodyweightAudience = "bodyweight_audience"
        case locationAudience = "location_audience"
        case gymAudience = "gym_audience"
        case friendListAudience = "friend_list_audience"
        case showLiftVideos = "show_lift_videos"
    }
}

struct ProfileCardDTO: Codable {
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

private struct BodyweightRecordDTO: Codable {
    let id: UUID
    let userID: UUID
    let weight: Double
    let recordedAt: Date
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id, weight, notes
        case userID = "user_id"
        case recordedAt = "recorded_at"
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

    func synchronizeBodyweightEntries(_ localEntries: [BodyweightEntry]) async throws -> [BodyweightEntry] {
        do {
            let userID = try await client.auth.session.user.id
            let localRecords = localEntries.compactMap { entry -> BodyweightRecordDTO? in
                guard let weight = entry.actual, weight > 0 else { return nil }
                return BodyweightRecordDTO(
                    id: entry.id,
                    userID: userID,
                    weight: weight,
                    recordedAt: entry.targetDate,
                    notes: entry.notes
                )
            }
            let pageSize = 500
            var records: [BodyweightRecordDTO] = []
            var offset = 0
            while true {
                let page: [BodyweightRecordDTO] = try await client.from("bodyweight_records")
                    .select()
                    .eq("user_id", value: userID)
                    .order("recorded_at", ascending: true)
                    .order("id")
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                records.append(contentsOf: page)
                guard page.count == pageSize else { break }
                offset += pageSize
            }
            let remoteByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            let pendingRecords = localRecords.filter { local in
                guard let remote = remoteByID[local.id] else { return true }
                return abs(local.weight - remote.weight) > 0.000_1 ||
                    abs(local.recordedAt.timeIntervalSince(remote.recordedAt)) > 0.001 ||
                    local.notes != remote.notes
            }
            if !pendingRecords.isEmpty {
                try await client.from("bodyweight_records")
                    .upsert(pendingRecords, onConflict: "id")
                    .execute()
            }
            var mergedByID = remoteByID
            for record in localRecords { mergedByID[record.id] = record }
            let merged = mergedByID.values.sorted {
                if $0.recordedAt == $1.recordedAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.recordedAt < $1.recordedAt
            }
            return merged.enumerated().map { index, record in
                BodyweightEntry(
                    id: record.id,
                    week: index + 1,
                    targetDate: record.recordedAt,
                    actual: record.weight,
                    notes: record.notes
                )
            }
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func saveBodyweightEntry(_ entry: BodyweightEntry) async throws {
        guard let weight = entry.actual, weight > 0 else { return }
        do {
            let record = BodyweightRecordDTO(
                id: entry.id,
                userID: try await client.auth.session.user.id,
                weight: weight,
                recordedAt: entry.targetDate,
                notes: entry.notes
            )
            try await client.from("bodyweight_records")
                .upsert(record, onConflict: "id")
                .execute()
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let existing = try await authenticatedProfile()
        let draft = ProfileDraft(
            username: profile.username, displayName: profile.displayName, bio: profile.bio ?? existing.bio,
            avatarPath: profile.avatarPath,
            preferredUnit: profile.preferredUnit, birthDate: existing.birthDate,
            sexCategory: profile.sexCategory, heightCentimeters: profile.heightInches * 2.54,
            bodyweightPounds: profile.bodyweightPounds,
            cityID: profile.cityID,
            city: profile.city, region: profile.state, countryCode: existing.countryCode ?? "US",
            yearsExperience: profile.yearsExperience, experienceLevel: profile.experienceLevel,
            privacy: ProfilePrivacySettings(
                profileAudience: existing.privacy.profileAudience,
                ageBandAudience: profile.hideExactAge ? .privateProfile : .publicProfile,
                divisionAudience: existing.privacy.divisionAudience,
                bodyweightAudience: profile.hideBodyweight ? .privateProfile : .publicProfile,
                locationAudience: profile.hideCity ? .privateProfile : .publicProfile,
                gymAudience: profile.hideGym ? .privateProfile : .publicProfile,
                friendListAudience: existing.privacy.friendListAudience,
                showLiftVideos: !profile.hideLiftVideos
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
            try await client.from("profiles")
                .update(ProfileAvatarPathUpdate(avatarPath: draft.avatarPath))
                .eq("id", value: try await client.auth.session.user.id)
                .execute()
            try await client.from("profile_private_details")
                .update(PrivateBodyweightUpdate(bodyweightPounds: draft.bodyweightPounds))
                .eq("user_id", value: try await client.auth.session.user.id)
                .execute()
            try await client.from("profile_privacy")
                .update(ProfilePrivacyDirectUpdate(
                    bodyweightAudience: draft.privacy.bodyweightAudience,
                    showLiftVideos: draft.privacy.showLiftVideos
                ))
                .eq("user_id", value: try await client.auth.session.user.id)
                .execute()
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

    func uploadProfileAvatar(avatarPath: String, fullImageURL: URL, thumbnailURL: URL) async throws -> String {
        do {
            let userPath = try await client.auth.session.user.id.uuidString.lowercased()
            let normalizedPath = "\(userPath)/avatar"
            try await client.storage.from("profile-avatars").upload(
                "\(normalizedPath)/avatar-full.jpg",
                fileURL: fullImageURL,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
            try await client.storage.from("profile-avatars").upload(
                "\(normalizedPath)/avatar-thumb.jpg",
                fileURL: thumbnailURL,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
            try await client.from("profiles")
                .update(ProfileAvatarPathUpdate(avatarPath: normalizedPath))
                .eq("id", value: try await client.auth.session.user.id)
                .execute()
            return normalizedPath
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func downloadProfileAvatar(avatarPath: String) async throws -> ProfileAvatarDownload? {
        do {
            let fullURL = try await client.storage.from("profile-avatars")
                .createSignedURL(path: "\(avatarPath)/avatar-full.jpg", expiresIn: 300)
            let thumbURL = try await client.storage.from("profile-avatars")
                .createSignedURL(path: "\(avatarPath)/avatar-thumb.jpg", expiresIn: 300)
            let (fullImageData, _) = try await URLSession.shared.data(from: fullURL)
            let thumbnailData = try? await URLSession.shared.data(from: thumbURL).0
            return ProfileAvatarDownload(fullImageData: fullImageData, thumbnailData: thumbnailData)
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }

    func removeProfileAvatar(avatarPath: String?) async throws {
        guard let avatarPath else { return }
        do {
            try await client.storage.from("profile-avatars").remove(paths: [
                "\(avatarPath)/avatar-full.jpg",
                "\(avatarPath)/avatar-thumb.jpg"
            ])
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
            bodyweightPounds: details.bodyweightPounds,
            city: details.city, region: details.region, countryCode: details.countryCode, cityID: details.cityID,
            yearsExperience: details.yearsExperience,
            experienceLevel: details.experienceLevel.flatMap { value in ExperienceLevel.allCases.first { $0.rawValue.lowercased() == value } },
            privacy: ProfilePrivacySettings(
                profileAudience: PrivacyAudience(rawValue: privacy.profileAudience) ?? .publicProfile,
                ageBandAudience: PrivacyAudience(rawValue: privacy.ageBandAudience) ?? .publicProfile,
                divisionAudience: PrivacyAudience(rawValue: privacy.divisionAudience) ?? .publicProfile,
                bodyweightAudience: PrivacyAudience(rawValue: privacy.bodyweightAudience) ?? .privateProfile,
                locationAudience: PrivacyAudience(rawValue: privacy.locationAudience) ?? .privateProfile,
                gymAudience: PrivacyAudience(rawValue: privacy.gymAudience) ?? .publicProfile,
                friendListAudience: PrivacyAudience(rawValue: privacy.friendListAudience) ?? .friends,
                showLiftVideos: privacy.showLiftVideos ?? true
            )
        )
    }

    private func userProfile(_ remote: AuthenticatedProfile) -> UserProfile {
        SupabaseProfileMapper.authenticated(remote)
    }

    private func sex(_ value: String?) -> SexCategory? {
        guard let value else { return nil }
        return SexCategory.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
    }
}

private struct PrivateBodyweightUpdate: Encodable {
    let bodyweightPounds: Double?
    enum CodingKeys: String, CodingKey { case bodyweightPounds = "bodyweight_lb" }
}

private struct ProfilePrivacyDirectUpdate: Encodable {
    let bodyweightAudience: PrivacyAudience
    let showLiftVideos: Bool
    enum CodingKeys: String, CodingKey {
        case bodyweightAudience = "bodyweight_audience"
        case showLiftVideos = "show_lift_videos"
    }
}

private struct ProfileAvatarPathUpdate: Encodable {
    let avatarPath: String?
    enum CodingKeys: String, CodingKey { case avatarPath = "avatar_path" }
}

private struct SaveProfileParameters: Encodable {
    let newDisplayName: String
    let newBio: String
    let newPreferredUnit: String
    let newBirthDate: String?
    let newSexCategory: String?
    let newHeightCM: Double?
    let newCityID: UUID?
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
        case newCityID = "new_city_id", newCity = "new_city", newRegion = "new_region", newCountryCode = "new_country_code"
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
        newCityID = draft.cityID
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
