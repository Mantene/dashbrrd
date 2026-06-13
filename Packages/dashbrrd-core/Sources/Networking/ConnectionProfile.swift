import Foundation
import CoreModel

/// The fully-resolved, in-memory coordinates + secrets needed to talk to one instance.
///
/// Assembled by `PersistenceKit.ServerConfigRepository` by joining the non-secret
/// `ServerConfig` with secrets pulled from the Keychain. This is the only type that
/// carries credentials, and it never touches disk.
public struct ConnectionProfile: Sendable {
    public var instanceID: InstanceID
    public var scheme: String
    public var host: String
    public var port: Int?
    public var basePath: String?
    public var trustPolicy: TrustPolicy
    /// Auth strategies to apply, in order, to every outgoing request.
    public var credentials: [Credential]

    public enum Credential: Sendable, Hashable {
        /// Servarr `X-Api-Key` header.
        case apiKey(String)
        /// Reverse-proxy HTTP Basic Auth.
        case basic(username: String, password: String)
        /// SABnzbd-style `?apikey=` query parameter.
        case queryParam(name: String, value: String)
    }

    public init(
        instanceID: InstanceID,
        scheme: String,
        host: String,
        port: Int? = nil,
        basePath: String? = nil,
        trustPolicy: TrustPolicy = .system,
        credentials: [Credential] = []
    ) {
        self.instanceID = instanceID
        self.scheme = scheme
        self.host = host
        self.port = port
        self.basePath = basePath
        self.trustPolicy = trustPolicy
        self.credentials = credentials
    }
}
