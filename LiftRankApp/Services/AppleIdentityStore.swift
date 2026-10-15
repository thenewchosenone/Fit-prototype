import AuthenticationServices
import Foundation
import Security

enum AppleIdentityStore {
    private static let service = "com.liftrank.app.apple-identity"
    private static let account = "current"

    private struct Record: Codable {
        let userIdentifier: String
        var fullName: String?
    }

    static var hasStoredCredential: Bool {
        load() != nil
    }

    static var userIdentifier: String? {
        load()?.userIdentifier
    }

    static var pendingFullName: String? {
        load()?.fullName
    }

    @discardableResult
    static func save(userIdentifier: String, fullName: String?) -> Bool {
        let existing = load()
        let record = Record(
            userIdentifier: userIdentifier,
            fullName: fullName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? existing?.fullName
        )
        guard let data = try? JSONEncoder().encode(record) else { return false }

        let query = itemQuery
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insertQuery as CFDictionary, nil) == errSecSuccess
    }

    static func clearPendingFullName() {
        guard let record = load() else { return }
        guard let data = try? JSONEncoder().encode(Record(userIdentifier: record.userIdentifier, fullName: nil)) else {
            return
        }
        _ = SecItemUpdate(
            itemQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
    }

    static func clear() {
        SecItemDelete(itemQuery as CFDictionary)
    }

    static func credentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState? {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, error in
                continuation.resume(returning: error == nil ? state : nil)
            }
        }
    }

    static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        return PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static func usernameSuggestion(from fullName: String?) -> String? {
        guard let fullName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !fullName.isEmpty else {
            return nil
        }
        let folded = fullName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        var suggestion = ""
        for scalar in folded.unicodeScalars {
            if (scalar.value >= 97 && scalar.value <= 122) || (scalar.value >= 48 && scalar.value <= 57) {
                suggestion.append(String(scalar))
            } else if !suggestion.hasSuffix("_") {
                suggestion.append("_")
            }
        }
        suggestion = suggestion.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        guard suggestion.count >= 3 else { return nil }
        return String(suggestion.prefix(24))
    }

    private static var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static var loadQuery: [String: Any] {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    private static func load() -> Record? {
        var result: CFTypeRef?
        guard SecItemCopyMatching(loadQuery as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
