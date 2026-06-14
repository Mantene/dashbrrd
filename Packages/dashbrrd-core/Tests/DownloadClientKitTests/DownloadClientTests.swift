import Testing
import Foundation
import CoreModel
import Networking
@testable import DownloadClientKit

@Suite("Download client decoding & mapping")
struct DownloadClientTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("SABnzbd queue → QueueItems: progress, byte sizes, eta, category, state")
    func sabQueue() throws {
        let dto = try JSONDecoder().decode(SABQueueResponseDTO.self, from: fixture("sab_queue"))
        let id = InstanceID()
        let items = SABnzbdMapper.items(from: dto, instanceID: id)
        #expect(items.count == 2)

        let a = items[0]
        #expect(a.serviceKind == .sabnzbd)
        #expect(a.name == "Example.Show.S01E01")
        #expect(a.state == .downloading)
        #expect(abs(a.progress - 0.5) < 0.001)
        #expect(a.sizeBytes == 1_000_000_000)
        #expect(a.sizeLeftBytes == 500_000_000)
        #expect(a.etaSeconds == 600)        // 0:10:00
        #expect(a.category == "tv")
        #expect(a.downloadID == "SABnzbd_nzo_aaa")

        let b = items[1]
        #expect(b.state == .paused)
        #expect(b.category == nil)          // empty string → nil
        #expect(b.etaSeconds == nil)        // 0:00:00 → nil
    }

    @Test("qBittorrent torrents → QueueItems via the real client + mock transport")
    func qbitQueue() async throws {
        let client = QBittorrentClient(
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET torrents/info": .success(try fixture("qbit_torrents"))])
        )
        let items = try await client.queue()
        #expect(items.count == 2)

        let a = items[0]
        #expect(a.serviceKind == .qbittorrent)
        #expect(a.state == .downloading)
        #expect(abs(a.progress - 0.42) < 0.001)
        #expect(a.speedBytesPerSec == 1_500_000)
        #expect(a.etaSeconds == 900)
        #expect(a.category == "tv")
        #expect(a.downloadID == "abc123")

        let b = items[1]
        #expect(b.state == .completed)      // stalledUP → seeding → completed
        #expect(b.etaSeconds == nil)        // 8640000 sentinel → nil
        #expect(b.category == nil)
    }

    @Test("qBittorrent version reads the plain-text endpoint")
    func qbitVersion() async throws {
        let client = QBittorrentClient(
            instanceID: InstanceID(),
            http: MockHTTPClient(routes: ["GET app/version": .success(Data("v5.1.4".utf8))])
        )
        let version = try await client.version()
        #expect(version == "v5.1.4")
    }
}
