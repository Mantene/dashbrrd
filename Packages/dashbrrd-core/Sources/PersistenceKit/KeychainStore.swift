import Foundation
import CoreModel
#if canImport(Security)
import Security
#endif

/// The *only* type that touches the Keychain. Stores one generic-password item per
/// secret, keyed `"\(instanceID).\(slot)"`, with `kSecAttrAccessibleAfterFirstUnlock`
/// so a background-refresh task can read API keys while the device is locked.
///
/// A shared access group (set via `accessGroup`) lets a future widget/extension read
/// the same secrets. Secrets NEVER go into SwiftData.
public struct KeychainStore: Sendable {
    public enum Slot: String, Sendable {
        case apiKey
        case basicAuthPassword
        case downloadClientPassword
    }

    /// `kSecAttrService` namespace for all dashbrrd items.
    public let service: String
    /// Optional shared Keychain access group (requires the matching entitlement).
    public let accessGroup: String?

    public init(service: String = "com.dashbrrd.secrets", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public enum KeychainError: Error, Sendable, Equatable {
        case unexpectedStatus(OSStatus)
        case unavailable
    }

    private func account(for instanceID: InstanceID, slot: Slot) -> String {
        "\(instanceID.rawValue.uuidString).\(slot.rawValue)"
    }

    // MARK: - CRUD

    public func set(_ value: String, for instanceID: InstanceID, slot: Slot) throws {
        #if canImport(Security)
        let account = account(for: instanceID, slot: slot)
        let data = Data(value.utf8)

        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary) // idempotent upsert

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func get(_ instanceID: InstanceID, slot: Slot) throws -> String? {
        #if canImport(Security)
        let account = account(for: instanceID, slot: slot)
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func delete(_ instanceID: InstanceID, slot: Slot) throws {
        #if canImport(Security)
        let account = account(for: instanceID, slot: slot)
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    /// Removes every secret slot for an instance (used on instance deletion).
    public func deleteAll(for instanceID: InstanceID) throws {
        for slot in [Slot.apiKey, .basicAuthPassword, .downloadClientPassword] {
            try delete(instanceID, slot: slot)
        }
    }

    #if canImport(Security)
    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    #endif
}
