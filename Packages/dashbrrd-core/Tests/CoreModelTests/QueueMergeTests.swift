import Testing
import Foundation
@testable import CoreModel

@Suite("QueueItem.merged — dedup Servarr vs download client")
struct QueueMergeTests {

    private func item(_ name: String, kind: ServiceKind, downloadID: String, state: QueueState = .downloading) -> QueueItem {
        QueueItem(
            id: "\(kind.rawValue):\(name)",
            instanceID: InstanceID(),
            serviceKind: kind,
            name: name,
            state: state,
            progress: 0.5,
            sizeBytes: 100,
            sizeLeftBytes: 50,
            speedBytesPerSec: 10,
            downloadID: downloadID
        )
    }

    @Test("a download present in both Servarr and the client keeps the client copy")
    func dedupPrefersClient() {
        let merged = QueueItem.merged([
            item("Show", kind: .sonarr, downloadID: "h1"),
            item("Show", kind: .qbittorrent, downloadID: "h1"),
        ])
        #expect(merged.count == 1)
        #expect(merged[0].serviceKind == .qbittorrent)
    }

    @Test("items without a downloadID are never deduped away")
    func keepsUncorrelated() {
        let merged = QueueItem.merged([
            item("A", kind: .sonarr, downloadID: ""),
            item("B", kind: .sonarr, downloadID: ""),
        ])
        #expect(merged.count == 2)
    }

    @Test("sorted active-first then by name")
    func sorting() {
        let merged = QueueItem.merged([
            item("Zeta", kind: .qbittorrent, downloadID: "z", state: .downloading),
            item("Alpha", kind: .qbittorrent, downloadID: "a", state: .paused),
            item("Beta", kind: .qbittorrent, downloadID: "b", state: .downloading),
        ])
        // downloading (Beta, Zeta) before paused (Alpha); within state, alphabetical.
        #expect(merged.map(\.name) == ["Beta", "Zeta", "Alpha"])
    }
}
