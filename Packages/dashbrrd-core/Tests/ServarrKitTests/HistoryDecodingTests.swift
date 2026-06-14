import Testing
import Foundation
import CoreModel
import Networking
@testable import ServarrKit

@Suite("History decoding & mapping")
struct HistoryDecodingTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("history decodes a page, maps event types, parses plain + fractional dates, reads quality")
    func history() async throws {
        let client = ServarrClient(
            descriptor: SonarrDescriptor(),
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET history": .success(try fixture("sonarr_history"))])
        )
        let page = try await client.history(PagedRequest(page: 1, pageSize: 2))

        #expect(page.totalRecords == 3311)
        #expect(page.hasMore) // 1*2 < 3311
        #expect(page.records.count == 2)

        let imported = page.records[0]
        #expect(imported.eventType == .imported)         // downloadFolderImported
        #expect(imported.quality == "WEBDL-1080p")
        #expect(imported.serviceKind == .sonarr)

        let grabbed = page.records[1]
        #expect(grabbed.eventType == .grabbed)
        #expect(grabbed.quality == "HDTV-720p")
        // Fractional-second timestamp parsed and is older than the plain-second one.
        #expect(grabbed.date < imported.date)
    }
}
