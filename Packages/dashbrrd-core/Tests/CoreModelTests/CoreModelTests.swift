import Testing
import Foundation
@testable import CoreModel

@Suite("CoreModel value semantics")
struct CoreModelTests {

    @Test("LoadState exposes the loaded value and nothing else")
    func loadStateAccessors() {
        let loaded = LoadState<Int>.loaded(42)
        #expect(loaded.value == 42)
        #expect(loaded.isLoading == false)
        #expect(loaded.errorMessage == nil)

        let failed = LoadState<Int>.failed(message: "boom")
        #expect(failed.value == nil)
        #expect(failed.errorMessage == "boom")

        #expect(LoadState<Int>.loading.isLoading)
    }

    @Test("LoadState.map preserves surrounding state")
    func loadStateMap() {
        #expect(LoadState<Int>.loaded(2).map { $0 * 3 }.value == 6)
        #expect(LoadState<Int>.idle.map { $0 * 3 }.value == nil)
    }

    @Test("ServerConfig flags plaintext only for http")
    func plaintextDetection() {
        let http = ServerConfig(kind: .sonarr, displayName: "S", scheme: "http", host: "h")
        let https = ServerConfig(kind: .sonarr, displayName: "S", scheme: "https", host: "h")
        #expect(http.isPlaintext)
        #expect(https.isPlaintext == false)
    }

    @Test("ServiceKind partitions Servarr vs download clients")
    func serviceKindPartition() {
        #expect(ServiceKind.sonarr.isServarr)
        #expect(ServiceKind.prowlarr.isServarr)
        #expect(ServiceKind.qbittorrent.isDownloadClient)
        #expect(ServiceKind.sabnzbd.isServarr == false)
    }

    @Test("ServerConfig round-trips through Codable")
    func serverConfigCodable() throws {
        let original = ServerConfig(
            kind: .radarr,
            displayName: "Movies",
            scheme: "https",
            host: "media.lan",
            port: 7878,
            basePath: "/radarr",
            trustPolicy: .pinnedSelfSigned(sha256: "abcd")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)
        #expect(decoded == original)
    }
}
