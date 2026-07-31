import Combine
import Foundation
import Security

@MainActor
final class SupabaseMobileSync: ObservableObject {
    static let shared = SupabaseMobileSync()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isBusy = false
    @Published private(set) var accountLabel = "Offline"
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
        let userID: UUID
        let email: String?
    }

    private struct AuthResponse: Decodable {
        struct User: Decodable {
            let id: UUID
            let email: String?
        }

        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Double?
        let user: User?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private struct APIError: Decodable {
        let message: String?
        let errorDescription: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case message
            case errorDescription = "error_description"
            case error
        }
    }

    private enum SyncError: LocalizedError {
        case invalidConfiguration
        case invalidResponse
        case authenticationRequired
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "The Lift Rivals backend is not configured."
            case .invalidResponse:
                return "The server returned an unreadable response."
            case .authenticationRequired:
                return "Sign in to sync your Lift Rivals account."
            case .server(let message):
                return message
            }
        }
    }

    private let baseURL = URL(string: "https://ikjgbsrlriqiusuvezco.supabase.co")!
    private let publishableKey = "sb_publishable_5dg5sIRy7DCibFdf-_cKlA_WZZmp8yf"
    private let sessionKey = "com.liftrivals.supabase.session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()
    private var session: Session?

    private init() {}

    func restore(into repository: DemoRepository) async {
        guard let stored = loadSession() else {
            setSignedOutState()
            return
        }

        do {
            session = stored
            if stored.expiresAt <= Date().addingTimeInterval(60) {
                try await refreshSession()
            } else {
                setSignedInState(stored)
            }
            try await hydrateProfile(into: repository)
            try await pushCurrentState(from: repository)
        } catch {
            clearSession()
            setSignedOutState()
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func signIn(email: String, password: String, repository: DemoRepository) async -> Bool {
        await authenticate(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password],
            repository: repository,
            confirmationMessage: nil
        )
    }

    @discardableResult
    func signUp(email: String, password: String, repository: DemoRepository) async -> Bool {
        await authenticate(
            path: "auth/v1/signup",
            queryItems: [],
            body: ["email": email, "password": password],
            repository: repository,
            confirmationMessage: "Check your email to confirm your Lift Rivals account."
        )
    }

    func signOut() async {
        if let current = session {
            _ = try? await request(
                path: "auth/v1/logout",
                method: "POST",
                bearer: current.accessToken
            )
        }
        clearSession()
        setSignedOutState()
        statusMessage = "Signed out."
    }

    func pushCurrentState(from repository: DemoRepository) async {
        guard session != nil, !isBusy else { return }

        do {
            try await syncProfile(repository.currentProfile)
            let workouts = workoutPayloads(from: repository)
            if !workouts.isEmpty {
                try await syncWorkouts(workouts)
            }
            let workoutSuffix = workouts.count == 1 ? "" : "s"
            statusMessage = workouts.isEmpty
                ? "Profile synced."
                : "Profile and \(workouts.count) completed workout\(workoutSuffix) synced."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate(
        path: String,
        queryItems: [URLQueryItem],
        body: [String: Any],
        repository: DemoRepository,
        confirmationMessage: String?
    ) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            let data = try await request(path: path, method: "POST", queryItems: queryItems, body: body)
            let response = try decoder.decode(AuthResponse.self, from: data)
            guard let newSession = session(from: response) else {
                statusMessage = confirmationMessage ?? "Confirm your email, then sign in."
                return false
            }

            saveSession(newSession)
            setSignedInState(newSession)
            try await hydrateProfile(into: repository)
            try await pushCurrentState(from: repository)
            statusMessage = "Connected to your Lift Rivals account."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshSession() async throws {
        guard let current = session else { throw SyncError.authenticationRequired }
        let data = try await request(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: ["refresh_token": current.refreshToken]
        )
        let response = try decoder.decode(AuthResponse.self, from: data)
        guard let refreshed = session(from: response) else {
            throw SyncError.authenticationRequired
        }
        saveSession(refreshed)
        setSignedInState(refreshed)
    }

    private func hydrateProfile(into repository: DemoRepository) async throws {
        let current = try await validSession()
        let data = try await request(
            path: "rest/v1/profile_sync",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "payload"),
                URLQueryItem(name: "user_id", value: "eq.\(current.userID.uuidString)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            bearer: current.accessToken
        )

        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let payload = rows?.first?["payload"] as? [String: Any]
        var profile = repository.currentProfile
        let previousID = profile.id
        profile.id = current.userID

        if let payload {
            apply(payload: payload, to: &profile)
        }

        repository.currentProfile = profile
        if let index = repository.profiles.firstIndex(where: { $0.id == previousID || $0.id == current.userID }) {
            repository.profiles[index] = profile
        } else {
            repository.profiles.append(profile)
        }
    }

    private func apply(payload: [String: Any], to profile: inout UserProfile) {
        if let value = payload["username"] as? String, !value.isEmpty {
            profile.username = value.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        } else if let value = payload["handle"] as? String, !value.isEmpty {
            profile.username = value.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        }
        if let value = payload["displayName"] as? String, !value.isEmpty { profile.displayName = value }
        if let value = payload["ageGroup"] as? String, !value.isEmpty { profile.ageGroup = value }
        if let value = payload["sexCategory"] as? String, let category = SexCategory(rawValue: value) { profile.sexCategory = category }
        if let value = number(payload["heightInches"]) { profile.heightInches = value }
        if let value = number(payload["bodyweightPounds"]) { profile.bodyweightPounds = value }
        if let value = payload["preferredUnit"] as? String {
            profile.preferredUnit = value.lowercased().hasPrefix("kg") ? .kilograms : .pounds
        }
        if let value = payload["city"] as? String { profile.city = value }
        if let value = payload["state"] as? String { profile.state = value }
        if let value = payload["primaryGymID"] as? String, let id = UUID(uuidString: value) { profile.primaryGymID = id }
        if let value = payload["primaryGymName"] as? String { profile.primaryGymName = value }
        if let value = number(payload["yearsTraining"]) { profile.yearsExperience = Int(value) }
        if let value = payload["experienceLevel"] as? String, let level = ExperienceLevel(rawValue: value) {
            profile.experienceLevel = level
        }
        if let value = payload["profileImageName"] as? String { profile.profileImageName = value }
        if let value = payload["hideExactAge"] as? Bool { profile.hideExactAge = value }
        if let value = payload["hideBodyweight"] as? Bool { profile.hideBodyweight = value }
        if let value = payload["hideCity"] as? Bool { profile.hideCity = value }
        if let value = payload["hideGym"] as? Bool { profile.hideGym = value }
        if let value = payload["hideLiftVideos"] as? Bool { profile.hideLiftVideos = value }
        if let value = payload["isPublicProfile"] as? Bool {
            UserDefaults.standard.set(!value, forKey: "privateProfile")
        }
    }

    private func syncProfile(_ profile: UserProfile) async throws {
        let current = try await validSession()
        let cleanUsername = profile.username.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let payload: [String: Any] = [
            "username": cleanUsername,
            "handle": cleanUsername.isEmpty ? "" : "@\(cleanUsername)",
            "displayName": profile.displayName,
            "ageGroup": profile.ageGroup,
            "sexCategory": profile.sexCategory.rawValue,
            "heightInches": profile.heightInches,
            "bodyweightPounds": profile.bodyweightPounds,
            "preferredUnit": profile.preferredUnit.shortLabel,
            "city": profile.city,
            "state": profile.state,
            "countryCode": "US",
            "primaryGymID": profile.primaryGymID.uuidString,
            "primaryGymName": profile.primaryGymName,
            "yearsTraining": profile.yearsExperience,
            "experienceLevel": profile.experienceLevel.rawValue,
            "discipline": "General Strength",
            "profileImageName": profile.profileImageName,
            "isPublicProfile": !UserDefaults.standard.bool(forKey: "privateProfile"),
            "showLiftVideos": !profile.hideLiftVideos,
            "hideExactAge": profile.hideExactAge,
            "hideBodyweight": profile.hideBodyweight,
            "hideCity": profile.hideCity,
            "hideGym": profile.hideGym,
            "hideLiftVideos": profile.hideLiftVideos
        ]
        _ = try await request(
            path: "rest/v1/rpc/sync_mobile_profile",
            method: "POST",
            body: ["profile_payload": payload],
            bearer: current.accessToken
        )
    }

    private func syncWorkouts(_ workouts: [[String: Any]]) async throws {
        let current = try await validSession()
        _ = try await request(
            path: "rest/v1/rpc/sync_mobile_workouts",
            method: "POST",
            body: ["workout_payloads": workouts],
            bearer: current.accessToken
        )
    }

    private func workoutPayloads(from repository: DemoRepository) -> [[String: Any]] {
        let feedbackPayloads = repository.workoutFeedback.compactMap { feedback -> [String: Any]? in
            guard let session = repository.workoutSessions.first(where: { $0.id == feedback.sessionID }) else {
                return nil
            }
            let prescriptions = repository.workoutPrescriptions
                .filter { $0.sessionID == session.id }
                .sorted { $0.order < $1.order }
            let prescriptionIDs = Set(prescriptions.map(\.id))
            let logs = repository.workoutSetLogs.filter {
                prescriptionIDs.contains($0.prescriptionID) &&
                    $0.isComplete &&
                    Calendar.current.isDate($0.performedAt, inSameDayAs: feedback.completedAt)
            }
            let completedIDs = Set(logs.map(\.prescriptionID))
            let totalVolume = logs.reduce(0) { $0 + $1.volume }
            let best = logs.max { $0.volume < $1.volume }
            let firstLog = logs.map(.performedAt).min()
            let lastLog = logs.map(.performedAt).max()
            let duration = max(0, lastLog?.timeIntervalSince(firstLog ?? lastLog ?? feedback.completedAt) ?? 0)
            let day = dayKey(feedback.completedAt)

            return [
                "id": "\(session.id.uuidString)-\(day)",
                "name": session.name,
                "completedAt": isoFormatter.string(from: feedback.completedAt),
                "durationSeconds": Int(duration),
                "completedExercises": completedIDs.count,
                "totalExercises": prescriptions.count,
                "totalSets": logs.count,
                "totalVolume": totalVolume,
                "effort": feedback.effort,
                "notes": feedback.notes,
                "bestSet": best.map { setPayload($0) as Any } ?? (NSNull() as Any),
                "prescriptions": prescriptions.map(prescriptionPayload),
                "setLogs": logs.map(setPayload)
            ]
        }

        let legacyGroups = Dictionary(grouping: repository.workoutEntries.filter(\.isDone)) {
            "\($0.planID.uuidString)|\(dayKey($0.date))|\($0.workout)"
        }
        let legacyPayloads = legacyGroups.values.compactMap { entries -> [String: Any]? in
            guard let first = entries.first else { return nil }
            let allSets = entries.flatMap { entry in
                entry.sets.map { set in
                    [
                        "id": set.id.uuidString,
                        "prescriptionId": entry.id.uuidString,
                        "weight": set.weight ?? 0,
                        "reps": set.reps ?? 0,
                        "rpe": set.rpe ?? 0,
                        "isWarmup": false,
                        "isComplete": true,
                        "performedAt": isoFormatter.string(from: entry.date)
                    ] as [String: Any]
                }
            }
            let completedAt = entries.map(.date).max() ?? first.date
            let totalVolume = entries.reduce(0) { $0 + $1.volume }
            let bestSet = allSets.max {
                (number($0["weight"]) ?? 0) * (number($0["reps"]) ?? 0) <
                    (number($1["weight"]) ?? 0) * (number($1["reps"]) ?? 0)
            }
            let safeName = first.workout
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")

            return [
                "id": "legacy-\(first.planID.uuidString)-\(dayKey(completedAt))-\(safeName)",
                "name": first.workout,
                "completedAt": isoFormatter.string(from: completedAt),
                "durationSeconds": 0,
                "completedExercises": entries.count,
                "totalExercises": entries.count,
                "totalSets": allSets.count,
                "totalVolume": totalVolume,
                "bestSet": bestSet.map { $0 as Any } ?? (NSNull() as Any),
                "prescriptions": entries.enumerated().map { index, entry in
                    [
                        "id": entry.id.uuidString,
                        "exerciseName": entry.exercise,
                        "bodyPart": entry.muscleGroup,
                        "equipment": "",
                        "order": index
                    ] as [String: Any]
                },
                "setLogs": allSets
            ]
        }

        let merged = feedbackPayloads + legacyPayloads
        return Dictionary(grouping: merged, by: { $0["id"] as? String ?? UUID().uuidString })
            .compactMap { $0.value.first }
            .sorted {
                (($0["completedAt"] as? String) ?? "") > (($1["completedAt"] as? String) ?? "")
            }
    }

    private func prescriptionPayload(_ prescription: WorkoutExercisePrescription) -> [String: Any] {
        [
            "id": prescription.id.uuidString,
            "exerciseId": prescription.exerciseID,
            "exerciseName": prescription.exerciseName,
            "bodyPart": prescription.bodyPart,
            "equipment": prescription.equipment,
            "sets": prescription.sets,
            "reps": prescription.reps,
            "order": prescription.order,
            "notes": prescription.notes
        ]
    }

    private func setPayload(_ log: WorkoutSetLog) -> [String: Any] {
        [
            "id": log.id.uuidString,
            "prescriptionId": log.prescriptionID.uuidString,
            "weight": log.weight ?? 0,
            "reps": log.reps ?? 0,
            "rpe": log.rpe ?? 0,
            "isWarmup": log.isWarmup,
            "isComplete": log.isComplete,
            "performedAt": isoFormatter.string(from: log.performedAt)
        ]
    }

    private func validSession() async throws -> Session {
        guard let current = session else { throw SyncError.authenticationRequired }
        if current.expiresAt <= Date().addingTimeInterval(60) {
            try await refreshSession()
        }
        guard let refreshed = session else { throw SyncError.authenticationRequired }
        return refreshed
    }

    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        bearer: String? = nil
    ) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw SyncError.invalidConfiguration
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw SyncError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer ?? publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let apiError = try? decoder.decode(APIError.self, from: data)
            throw SyncError.server(
                apiError?.message ?? apiError?.errorDescription ?? apiError?.error ?? "The Lift Rivals server returned \(http.statusCode)."
            )
        }
        return data
    }

    private func session(from response: AuthResponse) -> Session? {
        guard
            let accessToken = response.accessToken,
            let refreshToken = response.refreshToken,
            let user = response.user
        else {
            return nil
        }
        return Session(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn ?? 3600),
            userID: user.id,
            email: user.email
        )
    }

    private func setSignedInState(_ newSession: Session) {
        session = newSession
        isAuthenticated = true
        accountLabel = newSession.email ?? "Connected account"
    }

    private func setSignedOutState() {
        session = nil
        isAuthenticated = false
        isBusy = false
        accountLabel = "Offline"
    }

    private func saveSession(_ value: Session) {
        guard let data = try? encoder.encode(value) else { return }
        var attributes = keychainQuery()
        SecItemDelete(attributes as CFDictionary)
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func loadSession() -> Session? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }
        return try? decoder.decode(Session.self, from: data)
    }

    private func clearSession() {
        SecItemDelete(keychainQuery() as CFDictionary)
    }

    private func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sessionKey,
            kSecAttrAccount as String: "current"
        ]
    }

    private func dayKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
