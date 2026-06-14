import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

@Suite("Manual import: candidate decode & command shaping")
struct ManualImportTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("candidates decode: detected target, quality, rejections, importable flag")
    func candidates() async throws {
        let client = ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET manualimport": .success(try fixture("sonarr_manualimport"))])
        )
        let candidates = try await client.manualImportCandidates(downloadID: "ABC123")
        #expect(candidates.count == 2)

        let good = try #require(candidates.first { $0.importable })
        #expect(good.title == "Example Show · S04E06")
        #expect(good.qualityName == "WEBDL-1080p")
        #expect(good.rejections.isEmpty)

        let bad = try #require(candidates.first { !$0.importable })
        #expect(bad.rejections == ["Unable to parse file"])
    }

    @Test("manualImport POSTs a ManualImport command with seriesId/episodeIds and mode")
    func importCommand() async throws {
        let client = ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET manualimport": .success(try fixture("sonarr_manualimport"))])
        )
        let candidates = try await client.manualImportCandidates(downloadID: "ABC123")
        let importable = try #require(candidates.first { $0.importable })

        let mock = MockHTTPClient(routes: ["POST command": .success(Data("{}".utf8))])
        let poster = ServarrClient(descriptor: SonarrDescriptor(), instanceID: InstanceID(), http: mock)
        try await poster.manualImport(payloads: [importable.rawPayload], importMode: "move")

        let recorded = await mock.recordedEndpoints
        let post = try #require(recorded.first { $0.method == .post && $0.path == "command" })
        let body = try #require(post.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["name"] as? String == "ManualImport")
        #expect(object["importMode"] as? String == "move")
        let files = try #require(object["files"] as? [[String: Any]])
        #expect(files.count == 1)
        #expect(files[0]["seriesId"] as? Int == 295)
        #expect(files[0]["episodeIds"] as? [Int] == [9001])
        #expect(files[0]["path"] as? String == "/downloads/Example.Show.S04E06/Example.Show.S04E06.mkv")
        #expect(files[0]["quality"] != nil)
    }
}
