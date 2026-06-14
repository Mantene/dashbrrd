import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// Opt-in live integration test: exercises the REAL transport (HTTPClient actor → URLBuilder
/// → APIKeyInterceptor → trust eval) against an actual Sonarr server. Skips silently unless
/// `SONARR_URL` and `SONARR_API_KEY` are set, so it never commits secrets or LAN assumptions.
///
///   SONARR_URL=http://host:8989 SONARR_API_KEY=xx␣swift test --filter Live
@Suite("Sonarr live integration (opt-in)")
struct SonarrLiveIntegrationTests {

    private struct Env {
        let url: URL
        let apiKey: String
    }

    private func env() -> Env? {
        let e = ProcessInfo.processInfo.environment
        guard let urlString = e["SONARR_URL"], let url = URL(string: urlString),
              let key = e["SONARR_API_KEY"], !key.isEmpty else { return nil }
        return Env(url: url, apiKey: key)
    }

    private func makeClient(_ env: Env) -> ServarrClient<SonarrDescriptor> {
        let profile = ConnectionProfile(
            instanceID: InstanceID(),
            scheme: env.url.scheme ?? "http",
            host: env.url.host ?? "",
            port: env.url.port,
            basePath: nil,
            trustPolicy: .system,
            credentials: [.apiKey(env.apiKey)]
        )
        return ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile)
    }

    @Test("live system/status returns a Sonarr version")
    func liveStatus() async throws {
        guard let env = env() else { return } // skipped without env
        let status = try await makeClient(env).systemStatus()
        #expect(status.appName.localizedCaseInsensitiveContains("sonarr"))
        #expect(!status.version.isEmpty)
    }

    @Test("live health returns checks (possibly empty) without throwing")
    func liveHealth() async throws {
        guard let env = env() else { return }
        let checks = try await makeClient(env).health()
        #expect(checks.allSatisfy { !$0.source.isEmpty })
    }

    @Test("live calendar over the next 60 days decodes through the real stack")
    func liveCalendar() async throws {
        guard let env = env() else { return }
        let start = Date()
        let end = start.addingTimeInterval(60 * 24 * 3600)
        let entries = try await makeClient(env).calendar(DateInterval(start: start, end: end))
        // Don't assert a count (depends on the user's library); assert shape integrity.
        for entry in entries {
            #expect(entry.serviceKind == .sonarr)
            #expect(!entry.title.isEmpty)
        }
    }
}
