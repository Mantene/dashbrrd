import Testing
import Foundation
import CoreModel
import Networking
import DownloadClientKit

/// Opt-in live integration for download clients. Skips unless env vars are set; drives the real
/// stack (HTTPClient → URLBuilder → DownloadClientFactory). qBit needs no key on a LAN-bypassed
/// setup; SAB carries its key as a `?apikey=` query param.
///
///   SABNZBD_URL=http://host:8282 SABNZBD_API_KEY=… \
///   QBIT_URL=http://host:8080 swift test --filter DownloadClientLive
@Suite("Download client live integration (opt-in)")
struct DownloadClientLiveIntegrationTests {

    private static func client(for kind: ServiceKind) -> (any DownloadClient)? {
        let env = ProcessInfo.processInfo.environment
        let prefix = kind == .sabnzbd ? "SABNZBD" : "QBIT"
        guard let urlString = env["\(prefix)_URL"], let url = URL(string: urlString), let host = url.host else { return nil }

        var credentials: [ConnectionProfile.Credential] = []
        if kind == .sabnzbd, let key = env["SABNZBD_API_KEY"], !key.isEmpty {
            credentials.append(.queryParam(name: "apikey", value: key))
        }
        let profile = ConnectionProfile(
            instanceID: InstanceID(),
            scheme: url.scheme ?? "http",
            host: host,
            port: url.port,
            credentials: credentials
        )
        return DownloadClientFactory.make(kind: kind, instanceID: profile.instanceID, profile: profile)
    }

    @Test("live version", arguments: [ServiceKind.sabnzbd, .qbittorrent])
    func liveVersion(kind: ServiceKind) async throws {
        guard let client = Self.client(for: kind) else { return }
        let version = try await client.version()
        #expect(!version.isEmpty)
    }

    @Test("live queue decodes through the real stack", arguments: [ServiceKind.sabnzbd, .qbittorrent])
    func liveQueue(kind: ServiceKind) async throws {
        guard let client = Self.client(for: kind) else { return }
        let items = try await client.queue()
        for item in items {
            #expect(item.serviceKind == kind)
            #expect(!item.downloadID.isEmpty)
            #expect(item.progress >= 0 && item.progress <= 1)
        }
    }
}
