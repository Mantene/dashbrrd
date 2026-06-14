import Foundation
import CoreModel
import Networking
import ServarrKit
import FeatureSettings

/// Live `ConnectionTesting`: builds a transient client from the draft and hits the cheap
/// identity endpoint, then maps the typed `APIError` into the precise `ConnectionOutcome`
/// the add-server UI renders.
struct LiveConnectionTester: ConnectionTesting {

    func test(_ draft: ServerDraft) async -> ConnectionOutcome {
        // Phase 1 ships Sonarr; other kinds report "coming soon" rather than silently failing.
        guard draft.kind == .sonarr else {
            return .failed(message: "\(draft.kind.displayName) support is coming in a later phase.")
        }

        let profile = ConnectionProfile(
            instanceID: InstanceID(),
            scheme: draft.scheme,
            host: draft.host,
            port: draft.port,
            basePath: draft.basePath,
            trustPolicy: draft.trustPolicy,
            credentials: draft.apiKey.isEmpty ? [] : [.apiKey(draft.apiKey)]
        )
        let client = ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile)

        do {
            let status = try await client.systemStatus()
            return .success(version: status.version, appName: status.appName)
        } catch let error as APIError {
            return Self.map(error, draft: draft)
        } catch {
            return .failed(message: error.localizedDescription)
        }
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
