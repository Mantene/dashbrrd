import Foundation
import CoreModel
import Networking
import ServarrKit
import DownloadClientKit
import FeatureSettings

/// Live `ConnectionTesting`: builds a transient client from the draft and hits the cheap
/// identity endpoint (Servarr `system/status`, SAB `?mode=version`, qBit `app/version`), then
/// maps the typed `APIError` into the precise `ConnectionOutcome` the add-server UI renders.
struct LiveConnectionTester: ConnectionTesting {

    func test(_ draft: ServerDraft) async -> ConnectionOutcome {
        let profile = Self.makeProfile(draft)
        do {
            if ServarrRegistry.isSupported(draft.kind) {
                let status = try await ServarrRegistry.systemStatus(kind: draft.kind, profile: profile)
                return .success(version: status.version, appName: status.appName)
            } else if let client = DownloadClientFactory.make(kind: draft.kind, instanceID: profile.instanceID, profile: profile) {
                let version = try await client.version()
                return .success(version: version, appName: draft.kind.displayName)
            } else {
                return .failed(message: "\(draft.kind.displayName) support is coming in a later phase.")
            }
        } catch let error as APIError {
            return Self.map(error, draft: draft)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    /// Builds a transient profile, choosing the auth carrier appropriate to the kind.
    private static func makeProfile(_ draft: ServerDraft) -> ConnectionProfile {
        var credentials: [ConnectionProfile.Credential] = []
        if !draft.apiKey.isEmpty {
            switch draft.kind {
            case .sabnzbd: credentials.append(.queryParam(name: "apikey", value: draft.apiKey))
            case .qbittorrent: break // LAN bypass; cookie login is a follow-up
            default: credentials.append(.apiKey(draft.apiKey))
            }
        }
        return ConnectionProfile(
            instanceID: InstanceID(),
            scheme: draft.scheme,
            host: draft.host,
            port: draft.port,
            basePath: draft.basePath,
            trustPolicy: draft.trustPolicy,
            credentials: credentials
        )
    }

    private static func map(_ error: APIError, draft: ServerDraft) -> ConnectionOutcome {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .reachableButNoAPI
        case let .untrustedCertificate(fingerprint):
            return .untrustedCertificate(host: draft.host, fingerprint: fingerprint)
        case let .transport(message):
            return .unreachable(message: message)
        case .forbidden:
            return .failed(message: "Access forbidden (403). Check API key permissions.")
        case let .server(status, _):
            return .failed(message: "Server returned status \(status).")
        case .decoding:
            return .reachableButNoAPI
        case .clientCancelled:
            return .failed(message: "Connection test was cancelled.")
        case .invalidURL:
            return .failed(message: "The URL is invalid — check host, port, and base path.")
        }
    }
}
