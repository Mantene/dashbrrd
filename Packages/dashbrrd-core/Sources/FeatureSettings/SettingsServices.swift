import Foundation
import CoreModel

/// Everything the add-server form collects, including the secret. Lives here (not in
/// `CoreModel`) because it is a UI-input concern; `AppCore` reads it to run the live test
/// and to persist (splitting secret from non-secret).
public struct ServerDraft: Sendable, Hashable {
    public var kind: ServiceKind
    public var displayName: String
    public var scheme: String
    public var host: String
    public var port: Int?
    public var basePath: String?
    public var apiKey: String
    public var trustPolicy: TrustPolicy

    public init(
        kind: ServiceKind = .sonarr,
        displayName: String = "",
        scheme: String = "https",
        host: String = "",
        port: Int? = nil,
        basePath: String? = nil,
        apiKey: String = "",
        trustPolicy: TrustPolicy = .system
    ) {
        self.kind = kind
        self.displayName = displayName
        self.scheme = scheme
        self.host = host
        self.port = port
        self.basePath = basePath
        self.apiKey = apiKey
        self.trustPolicy = trustPolicy
    }
}

/// The precise result of a connection test, mirroring `APIError` outcomes but without
/// importing `Networking` — so feature UI can render exact guidance and pivot to cert-pinning.
public enum ConnectionOutcome: Sendable, Equatable {
    case success(version: String, appName: String)
    case unauthorized
    case reachableButNoAPI            // 404 — wrong base path / not an *arr
    case unreachable(message: String)
    case untrustedCertificate(host: String, fingerprint: String)
    case failed(message: String)
}

/// Runs a live connection test against a draft (cheap identity endpoint). Implemented by
/// `AppCore.LiveConnectionTester`.
public protocol ConnectionTesting: Sendable {
    func test(_ draft: ServerDraft) async -> ConnectionOutcome
}

/// Reads/writes server instances (config to SwiftData, secrets to Keychain). Implemented by
/// `AppCore.LiveServerStore`, which wraps `PersistenceKit.ServerConfigRepository`.
@MainActor
public protocol ServerStoring: AnyObject {
    func load() throws -> [ServerConfig]
    func add(_ draft: ServerDraft) throws -> ServerConfig
    func delete(_ config: ServerConfig) throws
}
