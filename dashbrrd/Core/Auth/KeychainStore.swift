import Foundation
import Security

/// Stores per-instance secrets in the iOS Keychain as a JSON-encoded `AuthCredential`,
/// keyed by the instance UUID. Service-scoped so it never collides with other apps.
struct KeychainStore: Sendable {
    private let service = "com.mantene.dashbrrd.credentials"

    func save(_ credential: AuthCredential, for instanceID: UUID) throws {
        let data = try JSONEncoder().encode(credential)
        let account = instanceID.uuidString

        // Delete any existing item first, then add fresh.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func load(for instanceID: UUID) -> AuthCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthCredential.self, from: data)
    }

    func delete(for instanceID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: instanceID.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case unhandled(OSStatus)
        var errorDescription: String? {
            switch self {
            case let .unhandled(status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
                return "Keychain error: \(message) (\(status))"
            }
        }
    }
}
