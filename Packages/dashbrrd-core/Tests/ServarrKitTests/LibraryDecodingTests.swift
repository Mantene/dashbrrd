import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// Library decode/map for Sonarr series and Radarr movies → the shared `MediaItem`.
@Suite("Library decoding & mapping")
struct LibraryDecodingTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("Sonarr series → MediaItems: title-sorted, status + episode-count subtitle")
    func sonarrSeries() async throws {
        let client = ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET series": .success(try fixture("sonarr_series"))])
        )
        let items = try await client.library()
        #expect(items.count == 2)
        // Sorted by title: "Another Show" before "Example Series One".
        #expect(items[0].title == "Another Show")
        #expect(items[0].subtitle == "Ended · 10/10")
        #expect(items[0].monitored == false)
        #expect(items[1].title == "Example Series One")
        #expect(items[1].subtitle == "Continuing · 24/30")
        #expect(items[1].serviceKind == .sonarr)
        #expect(items[1].posterURL?.absoluteString == "https://example.test/p5.jpg")
    }

    @Test("Radarr movies → MediaItems: downloaded/missing subtitle")
    func radarrMovies() async throws {
        let client = ServarrClient(
            descriptor: RadarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET movie": .success(try fixture("radarr_movies"))])
        )
        let items = try await client.library()
        #expect(items.count == 2)
        let one = try #require(items.first { $0.title == "Example Movie One" })
        #expect(one.subtitle == "Missing")
        #expect(one.serviceKind == .radarr)
        let two = try #require(items.first { $0.title == "Example Movie Two" })
        #expect(two.subtitle == "Downloaded")
    }

    @Test("registry library is gated: empty for non-library kinds")
    func libraryGating() async throws {
        #expect(ServarrRegistry.capabilities(for: .sonarr).contains(.library))
        #expect(ServarrRegistry.capabilities(for: .radarr).contains(.library))
        #expect(!ServarrRegistry.capabilities(for: .prowlarr).contains(.library))

        let profile = ConnectionProfile(instanceID: InstanceID(), scheme: "http", host: "h", credentials: [])
        let items = try await ServarrRegistry.library(kind: .prowlarr, profile: profile)
        #expect(items.isEmpty)
    }
}
