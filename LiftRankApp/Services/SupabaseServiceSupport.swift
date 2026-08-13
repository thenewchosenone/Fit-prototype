import Foundation
import Supabase

enum LiftRankBackendEnvironment: String, Equatable {
    case local
    case staging
    case production
}

struct SupabaseConfiguration: Equatable {
    static let authCallbackURL = URL(string: "liftrank://auth-callback")!
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
        guard let urlText,
              let url = URL(string: urlText),
              let host = url.host,
              let scheme = url.scheme,
              let key,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let environmentName,
              let backendEnvironment = LiftRankBackendEnvironment(rawValue: environmentName.lowercased()) else {
            return nil
        }
        guard backendEnvironment == .local || !isServiceRoleKey(key) else { return nil }
        if backendEnvironment == .local {
            guard ["127.0.0.1", "localhost"].contains(host), ["http", "https"].contains(scheme) else { return nil }
        } else {
            guard scheme == "https", !["127.0.0.1", "localhost"].contains(host) else { return nil }
        }
        return SupabaseConfiguration(url: url, publicKey: key, environment: backendEnvironment)
    }

    private static func isServiceRoleKey(_ key: String) -> Bool {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let role = object["role"] as? String else { return false }
        return role == "service_role"
    }
}

enum SupabaseServiceErrorMapper {
    static func map(_ error: Error) -> LiftRankServiceError {
        let message = String(describing: error).lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") { return .invalidCredentials }
        if message.contains("jwt") || (message.contains("session") && message.contains("expired")) { return .sessionExpired }
        if message.contains("profiles_username_lower_unique") || (message.contains("username") && message.contains("duplicate")) { return .usernameUnavailable }
        if message.contains("three active gyms") { return .gymLimitReached }
        if message.contains("choose another primary gym") { return .primaryGymRequired }
        if message.contains("permission denied") || message.contains("42501") { return .permissionDenied }
        if message.contains("network") || message.contains("offline") || message.contains("timed out") { return .networkUnavailable }
        return .server("Lift Rivals couldn't complete that request. Please try again.")
    }
}
