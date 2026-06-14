import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

@Suite("Release search decode & grab request shaping")
struct ReleaseTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("release search decodes protocol/size/seeders/rejections/downloadAllowed")
    func releaseSearch() async throws {
        let client = ServarrClient(
            descriptor: RadarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET release": .success(try fixture("servarr_release"))])
        )
        let releases = try await client.releaseSearch(paramName: "movieId", mediaID: 1)
        #expect(releases.count == 2)

        let usenet = try #require(releases.first { $0.guid == "release-aaa" })
        #expect(usenet.isUsenet)
        #expect(usenet.indexerID == 7)
        #expect(usenet.downloadAllowed)
        #expect(usenet.quality == "WEBDL-1080p")
        #expect(usenet.rejected == false)

        let torrent = try #require(releases.first { $0.guid == "release-bbb" })
        #expect(torrent.isUsenet == false)
        #expect(torrent.seeders == 42)
        #expect(torrent.rejected)
        #expect(torrent.rejections.first == "Not an upgrade for existing file")
        #expect(torrent.downloadAllowed == false)
    }

    @Test("grab POSTs release with {guid, indexerId} body")
    func grab() async throws {
        let mock = MockHTTPClient(routes: ["POST release": .success(Data("{}".utf8))])
        let client = ServarrClient(descriptor: SonarrDescriptor(), instanceID: InstanceID(), http: mock)

        try await client.grab(guid: "release-aaa", indexerID: 7)

        let recorded = await mock.recordedEndpoints
        let post = try #require(recorded.first { $0.method == .post && $0.path == "release" })
        let body = try #require(post.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["guid"] as? String == "release-aaa")
        #expect(object["indexerId"] as? Int == 7)
    }
}
