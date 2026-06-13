import Foundation

/// A stable, type-safe identifier for a single configured server instance.
///
/// Wrapping `UUID` in a dedicated type prevents mixing instance IDs with the many
/// other `Int`/`UUID` identifiers in the domain (remote record IDs, download IDs)
/// and makes Keychain keys (`"\(instanceID.rawValue).apiKey"`) unambiguous.
public struct InstanceID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    /// Mints a fresh identifier for a newly added instance.
    public init() {
        self.rawValue = UUID()
    }

    public var description: String { rawValue.uuidString }
}
