import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

@Suite("Add media: lookup decode & add request shaping")
struct AddMediaTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("lookup maps candidates, flags already-in-library, keeps raw payload")
    func lookup() async throws {
        let client = ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET series/lookup": .success(try fixture("sonarr_lookup"))])
        )
        let items = try await client.lookup(resource: "series", term: "bad")
        #expect(items.count == 2)

        let new = try #require(items.first { $0.title == "Breaking Bad" })
        #expect(new.alreadyInLibrary == false)       // no id in lookup
        #expect(new.year == 2008)
        #expect(new.posterURL?.absoluteString == "https://example.test/bb.jpg")
        #expect(!new.rawPayload.isEmpty)

        let existing = try #require(items.first { $0.title == "Better Call Saul" })
        #expect(existing.alreadyInLibrary)           // id: 5 present
    }

    @Test("addMedia merges chosen fields into the lookup payload and POSTs it")
    func addMedia() async throws {
        let payload = Data(#"{"title":"Breaking Bad","tvdbId":81189}"#.utf8)
        let mock = MockHTTPClient(routes: ["POST series": .success(Data("{}".utf8))])
        let client = ServarrClient(descriptor: SonarrDescriptor(), instanceID: InstanceID(), http: mock)

        try await client.addMedia(
            resource: "series", payload: payload, qualityProfileID: 7,
            rootFolderPath: "/data/media/tv", monitored: true, searchOnAdd: false,
            searchOptionKey: "searchForMissingEpisodes"
        )

        let recorded = await mock.recordedEndpoints
        let post = try #require(recorded.first { $0.method == .post && $0.path == "series" })
        let body = try #require(post.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["title"] as? String == "Breaking Bad")        // original preserved
        #expect(object["tvdbId"] as? Int == 81189)
        #expect(object["qualityProfileId"] as? Int == 7)             // injected
        #expect(object["rootFolderPath"] as? String == "/data/media/tv")
        #expect(object["monitored"] as? Bool == true)
        let addOptions = try #require(object["addOptions"] as? [String: Any])
        #expect(addOptions["searchForMissingEpisodes"] as? Bool == false)
    }
}
