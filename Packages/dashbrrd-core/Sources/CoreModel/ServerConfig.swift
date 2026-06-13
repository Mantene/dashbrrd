import Foundation

/// The in-memory, **non-secret** description of a configured server instance.
///
/// This mirrors what `PersistenceKit.ServerConfigModel` stores in SwiftData. API keys
/// and passwords are *never* part of this type — they live only in the Keychain and are
/// joined in at the last moment to form a `Networking.ConnectionProfile`.
public struct ServerConfig: Identifiable, Sendable, Hashable, Codable {
    public var id: InstanceID
    public var kind: ServiceKind
    public var displayName: String

    /// `"http"` or `"https"`.
    public var scheme: String
    public var host: String
    /// `nil` means the scheme default (80/443).
    public var port: Int?
    /// Reverse-proxy base path, e.g. `"/sonarr"`. `nil`/empty means mounted at root.
    public var basePath: String?

    /// Whether an HTTP Basic Auth credential (reverse proxy) is also required.
    public var useBasicAuth: Bool

    public var trustPolicy: TrustPolicy
    public var isEnabled: Bool
    /// User-defined ordering across the instance list.
    public var sortIndex: Int

    public init(
        id: InstanceID = InstanceID(),
        kind: ServiceKind,
        displayName: String,
        scheme: String = "https",
        host: String,
        port: Int? = nil,
        basePath: String? = nil,
        useBasicAuth: Bool = false,
        trustPolicy: TrustPolicy = .system,
        isEnabled: Bool = true,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.scheme = scheme
        self.host = host
        self.port = port
        self.basePath = basePath
        self.useBasicAuth = useBasicAuth
        self.trustPolicy = trustPolicy
        self.isEnabled = isEnabled
        self.sortIndex = sortIndex
    }

    /// `true` when traffic is unencrypted — drives the persistent "Not encrypted" badge.
    public var isPlaintext: Bool { scheme.lowercased() == "http" }
}
