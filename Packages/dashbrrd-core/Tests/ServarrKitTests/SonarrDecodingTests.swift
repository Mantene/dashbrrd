import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// Decoding + mapping guards against real Sonarr 4.0.x schema (fixtures captured from a live
/// server, then sanitized). If Sonarr changes a field we read, these break — exactly the
/// schema-drift alarm we want.
@Suite("Sonarr decoding & mapping")
struct SonarrDecodingTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func client(routes: [String: MockHTTPClient.Response]) -> ServarrClient<SonarrDescriptor> {
        ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: routes)
        )
    }

    @Test("system/status decodes and maps to SystemStatus")
    func systemStatus() async throws {
        let client = client(routes: ["GET system/status": .success(try fixture("sonarr_system_status"))])
        let status = try await client.systemStatus()
        #expect(status.version == "4.0.17.2952")
        #expect(status.appName == "Sonarr")
    }

    @Test("health decodes all severities and preserves wiki URLs")
    func health() async throws {
        let client = client(routes: ["GET health": .success(try fixture("sonarr_health"))])
        let checks = try await client.health()
        #expect(checks.count == 4)

        let severities = checks.map(\.severity)
        #expect(severities.contains(.warning))
        #expect(severities.contains(.error))
        #expect(severities.contains(.notice))
        #expect(severities.contains(.ok))

        let warning = try #require(checks.first { $0.severity == .warning })
        #expect(warning.wikiURL != nil)

        let notice = try #require(checks.first { $0.severity == .notice })
        #expect(notice.wikiURL == nil) // null in JSON
    }

    @Test("calendar maps episodes, drops air-date-less entries, and sorts chronologically")
    func calendar() async throws {
        let client = client(routes: ["GET calendar": .success(try fixture("sonarr_calendar"))])
        let range = DateInterval(start: .distantPast, end: .distantFuture)
        let entries = try await client.calendar(range)

        // 3 fixture items, but item 103 has a null airDateUtc → dropped.
        #expect(entries.count == 2)

        let first = entries[0]
        #expect(first.title == "Example Series One")        // series title, not episode title
        #expect(first.subtitle == "S04E06 · Example Episode A")
        #expect(first.serviceKind == .sonarr)
        #expect(first.hasFile == false)

        // Sorted by airDate ascending.
        #expect(entries[0].airDate < entries[1].airDate)
        #expect(entries[1].title == "Example Series Two")
        #expect(entries[1].hasFile == true)
    }
}
