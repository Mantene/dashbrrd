import Testing
import Foundation
import CoreModel
import Networking
import ServarrKit

/// Opt-in live integration across the Servarr family. Each kind is gated on its own env vars
/// and skips silently when absent, so no secrets or LAN assumptions are ever committed. This
/// drives the REAL stack (HTTPClient → URLBuilder → APIKeyInterceptor → ServarrRegistry).
///
///   SONARR_URL=… SONARR_API_KEY=… \
///   RADARR_URL=… RADARR_API_KEY=… \
///   PROWLARR_URL=… PROWLARR_API_KEY=… swift test --filter Live
@Suite("Servarr live integration (opt-in)")
struct ServarrLiveIntegrationTests {

    private static func profile(for kind: ServiceKind) -> ConnectionProfile? {
        let prefix: String
        switch kind {
        case .sonarr: prefix = "SONARR"
        case .radarr: prefix = "RADARR"
        case .prowlarr: prefix = "PROWLARR"
        default: return nil
        }
        let env = ProcessInfo.processInfo.environment
        guard let urlString = env["\(prefix)_URL"], let url = URL(string: urlString), let host = url.host,
              let key = env["\(prefix)_API_KEY"], !key.isEmpty else { return nil }
        return ConnectionProfile(
            instanceID: InstanceID(),
            scheme: url.scheme ?? "http",
            host: host,
            port: url.port,
            basePath: nil,
            trustPolicy: .system,
            credentials: [.apiKey(key)]
        )
    }

    @Test("live system/status identifies the app", arguments: [ServiceKind.sonarr, .radarr, .prowlarr])
    func liveStatus(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return } // skipped without env
        let status = try await ServarrRegistry.systemStatus(kind: kind, profile: profile)
        #expect(status.appName.localizedCaseInsensitiveContains(kind.displayName))
        #expect(!status.version.isEmpty)
    }

    @Test("live health returns well-formed checks", arguments: [ServiceKind.sonarr, .radarr, .prowlarr])
    func liveHealth(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return }
        let checks = try await ServarrRegistry.health(kind: kind, profile: profile)
        #expect(checks.allSatisfy { !$0.source.isEmpty })
    }

    @Test("live calendar decodes through the real stack", arguments: [ServiceKind.sonarr, .radarr])
    func liveCalendar(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return }
        let now = Date()
        let range = DateInterval(start: now, end: now.addingTimeInterval(90 * 24 * 3600))
        let entries = try await ServarrRegistry.calendar(kind: kind, profile: profile, range: range)
        for entry in entries {
            #expect(entry.serviceKind == kind)
            #expect(!entry.title.isEmpty)
        }
    }

    @Test("live library decodes through the real stack", arguments: [ServiceKind.sonarr, .radarr])
    func liveLibrary(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return }
        let items = try await ServarrRegistry.library(kind: kind, profile: profile)
        for item in items {
            #expect(item.serviceKind == kind)
            #expect(!item.title.isEmpty)
        }
    }

    @Test("live Servarr queue decodes through the real stack", arguments: [ServiceKind.sonarr, .radarr])
    func liveQueue(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return }
        let items = try await ServarrRegistry.queue(kind: kind, profile: profile)
        for item in items {
            #expect(item.serviceKind == kind)
            #expect(item.progress >= 0 && item.progress <= 1)
        }
    }

    @Test("live history decodes a page through the real stack", arguments: [ServiceKind.sonarr, .radarr])
    func liveHistory(kind: ServiceKind) async throws {
        guard let profile = Self.profile(for: kind) else { return }
        let page = try await ServarrRegistry.history(kind: kind, profile: profile, request: PagedRequest(page: 1, pageSize: 10))
        #expect(page.pageSize == 10)
        for record in page.records {
            #expect(record.serviceKind == kind)
            #expect(!record.title.isEmpty)
        }
    }
}
