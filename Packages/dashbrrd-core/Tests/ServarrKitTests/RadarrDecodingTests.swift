import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// Radarr decode/map + capability-gating. Proves "one folder per app": the same engine,
/// factory, and registry serve Radarr with movie-centric calendar semantics.
@Suite("Radarr decoding, mapping & capability gating")
struct RadarrDecodingTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func client(routes: [String: MockHTTPClient.Response]) -> ServarrClient<RadarrDescriptor> {
        ServarrClient(descriptor: RadarrDescriptor(), instanceID: InstanceID(), http: MockHTTPClient(routes: routes))
    }

    @Test("calendar maps movies, picks digital→physical→cinema date, drops date-less, sorts")
    func calendar() async throws {
        let client = client(routes: ["GET calendar": .success(try fixture("radarr_calendar"))])
        let entries = try await client.calendar(DateInterval(start: .distantPast, end: .distantFuture))

        // 3 fixture movies; #203 has no release date → dropped.
        #expect(entries.count == 2)

        // #201 digitalRelease 2026-06-15 is chosen over physical/cinema, and sorts AFTER
        // #202's inCinemas 2026-06-20? No: 06-15 < 06-20, so #201 comes first.
        #expect(entries[0].title == "Example Movie One (2026)")
        #expect(entries[0].subtitle == "Digital release")
        #expect(entries[0].serviceKind == .radarr)
        #expect(entries[1].title == "Example Movie Two (2026)")
        #expect(entries[1].subtitle == "In cinemas")
        #expect(entries[0].airDate < entries[1].airDate)
    }

    @Test("capabilities gate calendar: Sonarr/Radarr have it, Prowlarr does not")
    func capabilityGating() {
        #expect(ServarrRegistry.capabilities(for: .sonarr).contains(.calendar))
        #expect(ServarrRegistry.capabilities(for: .radarr).contains(.calendar))
        #expect(!ServarrRegistry.capabilities(for: .prowlarr).contains(.calendar))
        #expect(ServarrRegistry.capabilities(for: .prowlarr).contains(.indexers))
        #expect(ServarrRegistry.isSupported(.prowlarr))
        #expect(!ServarrRegistry.isSupported(.sabnzbd))
    }

    @Test("registry calendar returns empty for a non-calendar kind without hitting the network")
    func prowlarrCalendarEmpty() async throws {
        let profile = ConnectionProfile(instanceID: InstanceID(), scheme: "http", host: "h", credentials: [])
        let entries = try await ServarrRegistry.calendar(kind: .prowlarr, profile: profile, range: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(entries.isEmpty)
    }
}
