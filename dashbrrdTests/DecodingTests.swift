import XCTest
@testable import dashbrrd

final class DecodingTests: XCTestCase {
    func testQueuePageDecoding() throws {
        let json = """
        {"page":1,"pageSize":10,"totalRecords":1,"records":[
          {"id":5,"title":"Some.Show.S01E01","status":"downloading","size":100,"sizeleft":40,
           "trackedDownloadState":"downloading","indexer":"NZBgeek"}
        ]}
        """
        let page = try JSONDecoder.serviceDefault.decode(
            ServarrPage<QueueRecord>.self, from: Data(json.utf8)
        )
        let record = try XCTUnwrap(page.records.first)
        XCTAssertEqual(record.id, 5)
        XCTAssertEqual(record.progressFraction, 0.6, accuracy: 0.001)
    }

    func testSystemStatusDecoding() throws {
        let json = #"{"version":"4.0.1.123","appName":"Sonarr","instanceName":"Sonarr"}"#
        let status = try JSONDecoder.serviceDefault.decode(SystemStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status.version, "4.0.1.123")
        XCTAssertEqual(status.appName, "Sonarr")
    }

    func testMediaSummaryParsing() {
        let json = """
        [{"id":1,"title":"Breaking Bad","year":2008,"monitored":true,"tvdbId":81189,
          "status":"ended","overview":"A chemistry teacher...",
          "images":[{"coverType":"poster","remoteUrl":"http://img/p.jpg"}],
          "statistics":{"sizeOnDisk":1024}}]
        """
        let items = MediaSummary.parseList(
            Data(json.utf8), entity: .forType(.sonarr), isLibrary: true
        )
        let item = items.first
        XCTAssertEqual(item?.title, "Breaking Bad")
        XCTAssertEqual(item?.year, 2008)
        XCTAssertEqual(item?.monitored, true)
        XCTAssertEqual(item?.posterURL?.absoluteString, "http://img/p.jpg")
        XCTAssertEqual(item?.sizeOnDisk, 1024)
        XCTAssertEqual(item?.externalKey, "81189")
        XCTAssertNotNil(item?.rawAddPayload)
    }

    func testLidarrUsesArtistNameKey() {
        let json = #"[{"id":3,"artistName":"Radiohead","foreignArtistId":"abc","monitored":false}]"#
        let items = MediaSummary.parseList(
            Data(json.utf8), entity: .forType(.lidarr), isLibrary: true
        )
        XCTAssertEqual(items.first?.title, "Radiohead")
        XCTAssertEqual(items.first?.externalKey, "abc")
    }
}
