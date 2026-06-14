import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

/// Verifies request *shaping* for the destructive/edit endpoints without touching a real
/// server: setMonitored must GET the full object then PUT it back with the flag flipped;
/// delete must issue DELETE with the deleteFiles query.
@Suite("Media edit/delete request shaping")
struct MediaControlTests {

    @Test("setMonitored GETs the record then PUTs it back with monitored flipped")
    func setMonitored() async throws {
        let original = #"{"id":5,"title":"Example","monitored":true,"qualityProfileId":1}"#
        let mock = MockHTTPClient(routes: [
            "GET series/5": .success(Data(original.utf8)),
            "PUT series/5": .success(Data("{}".utf8)),
        ])
        let client = ServarrClient(descriptor: SonarrDescriptor(), instanceID: InstanceID(), http: mock)

        try await client.setMonitored(resource: "series", id: 5, monitored: false)

        let recorded = await mock.recordedEndpoints
        #expect(recorded.contains { $0.method == .get && $0.path == "series/5" })

        let put = try #require(recorded.first { $0.method == .put && $0.path == "series/5" })
        let body = try #require(put.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["monitored"] as? Bool == false)
        #expect(object["title"] as? String == "Example")   // full object preserved
        #expect(object["qualityProfileId"] as? Int == 1)
    }

    @Test("deleteMedia issues DELETE with the deleteFiles query")
    func deleteMedia() async throws {
        let mock = MockHTTPClient(routes: ["DELETE movie/7": .success(Data("{}".utf8))])
        let client = ServarrClient(descriptor: RadarrDescriptor(), instanceID: InstanceID(), http: mock)

        try await client.deleteMedia(resource: "movie", id: 7, deleteFiles: true)

        let recorded = await mock.recordedEndpoints
        let del = try #require(recorded.first { $0.method == .delete && $0.path == "movie/7" })
        #expect(del.query.contains { $0.name == "deleteFiles" && $0.value == "true" })
    }
}
