import Foundation
import SwiftData
import CoreModel

/// SwiftData persistence of a server instance's **non-secret** configuration.
///
/// Mirrors `CoreModel.ServerConfig`. Secrets are deliberately absent — they live only in
/// `KeychainStore`. The `id` is the stable `InstanceID` UUID and the Keychain key root.
@Model
public final class ServerConfigModel {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var displayName: String
    public var scheme: String
    public var host: String
    public var port: Int?
    public var basePath: String?
    public var useBasicAuth: Bool
    /// `TrustPolicy` encoded as JSON (SwiftData stores Codable via transformable-free encoding here).
    public var trustPolicyData: Data
    public var isEnabled: Bool
    public var sortIndex: Int

    public init(
        id: UUID,
        kindRaw: String,
        displayName: String,
        scheme: String,
        host: String,
        port: Int?,
        basePath: String?,
        useBasicAuth: Bool,
        trustPolicyData: Data,
        isEnabled: Bool,
        sortIndex: Int
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.displayName = displayName
        self.scheme = scheme
        self.host = host
        self.port = port
        self.basePath = basePath
        self.useBasicAuth = useBasicAuth
        self.trustPolicyData = trustPolicyData
        self.isEnabled = isEnabled
        self.sortIndex = sortIndex
    }
}

extension ServerConfigModel {
    /// Hydrates a `CoreModel.ServerConfig` value from the persisted row.
    public func toServerConfig() -> ServerConfig? {
        guard let kind = ServiceKind(rawValue: kindRaw),
              let trustPolicy = try? JSONDecoder().decode(TrustPolicy.self, from: trustPolicyData) else {
            return nil
        }
        return ServerConfig(
            id: InstanceID(rawValue: id),
            kind: kind,
            displayName: displayName,
            scheme: scheme,
            host: host,
            port: port,
            basePath: basePath,
            useBasicAuth: useBasicAuth,
            trustPolicy: trustPolicy,
            isEnabled: isEnabled,
            sortIndex: sortIndex
        )
    }

    /// Builds a persistable row from a `CoreModel.ServerConfig` value.
    public static func make(from config: ServerConfig) throws -> ServerConfigModel {
        let trustData = try JSONEncoder().encode(config.trustPolicy)
        return ServerConfigModel(
            id: config.id.rawValue,
            kindRaw: config.kind.rawValue,
            displayName: config.displayName,
            scheme: config.scheme,
            host: config.host,
            port: config.port,
            basePath: config.basePath,
            useBasicAuth: config.useBasicAuth,
            trustPolicyData: trustData,
            isEnabled: config.isEnabled,
            sortIndex: config.sortIndex
        )
    }
}
