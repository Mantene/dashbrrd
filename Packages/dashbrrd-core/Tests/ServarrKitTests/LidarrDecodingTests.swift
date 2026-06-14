import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// The extensibility proof: Lidarr (music, API v1) maps albums→calendar and artists→library
/// through the same engine, factory, and registry as Sonarr/Radarr — only one folder of code.
@Suite("Lidarr decoding, mapping & registry wiring")
struct LidarrDecodingTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func client(_ routes: [String: MockHTTPClient.Response]) -> ServarrClient<LidarrDescriptor> {
        ServarrClient(descriptor: LidarrDescriptor(), instanceID: InstanceID(), http: MockHTTPClient(routes: routes))
    }

    @Test("calendar maps albums (artist as title, album as subtitle), drops date-less")
    func calendar() async throws {
        let entries = try await client(["GET calendar": .success(try fixture("lidarr_calendar"))])
            .calendar(DateInterval(start: .distantPast, end: .distantFuture))
        #expect(entries.count == 1)            // the null-releaseDate album is dropped
        #expect(entries[0].serviceKind == .lidarr)
        #expect(entries[0].title == "Example Artist")
        #expect(entries[0].subtitle == "Example Album")
    }

    @Test("library maps artists with album/track counts, title-sorted")
    func library() async throws {
        let items = try await client(["GET artist": .success(try fixture("lidarr_artists"))]).library()
        #expect(items.count == 2)
        #expect(items[0].title == "Aaa Band")          // sorted ascending
        #expect(items[0].subtitle == "3 albums · 30/30 tracks")
        #expect(items[1].title == "Zztop Example")
        #expect(items[1].subtitle == "12 albums · 130/140 tracks")
        #expect(items[1].serviceKind == .lidarr)
        #expect(items[1].remoteID == 5)
    }

    @Test("registry wires Lidarr: supported, v1, calendar+library capable")
    func registryWiring() {
        #expect(ServarrRegistry.isSupported(.lidarr))
        #expect(LidarrDescriptor().apiVersion == .v1)
        let caps = ServarrRegistry.capabilities(for: .lidarr)
        #expect(caps.contains(.calendar))
        #expect(caps.contains(.library))
        #expect(caps.contains(.queue))
        #expect(ServarrRegistry.mediaResource(for: .lidarr) == "artist")
    }
}
