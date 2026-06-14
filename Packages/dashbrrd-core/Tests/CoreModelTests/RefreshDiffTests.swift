import Testing
import Foundation
@testable import CoreModel

@Suite("RefreshDiff — transitions become notifications")
struct RefreshDiffTests {

    private func queueItem(_ id: String, _ state: QueueState, name: String = "Item") -> QueueItem {
        QueueItem(id: id, instanceID: InstanceID(), serviceKind: .qbittorrent, name: name,
                  state: state, progress: 0, sizeBytes: 0, sizeLeftBytes: 0, speedBytesPerSec: 0, downloadID: id)
    }

    private func check(_ id: String, _ severity: HealthCheck.Severity) -> HealthCheck {
        HealthCheck(id: id, instanceID: InstanceID(), source: "src", severity: severity, message: "msg \(id)")
    }

    @Test("empty prior digest establishes a baseline (no notifications)")
    func queueBaseline() {
        let (notes, digest) = RefreshDiff.queue(previous: QueueDigest(), current: [queueItem("a", .downloading)])
        #expect(notes.isEmpty)
        #expect(digest.states["a"] == QueueState.downloading.rawValue)
    }

    @Test("download completing and failing each notify once")
    func queueTransitions() {
        let prev = QueueDigest(states: ["a": QueueState.downloading.rawValue, "b": QueueState.downloading.rawValue])
        let (notes, _) = RefreshDiff.queue(previous: prev, current: [
            queueItem("a", .completed, name: "Movie A"),
            queueItem("b", .error, name: "Show B"),
        ])
        #expect(notes.count == 2)
        #expect(notes.contains { $0.title == "Download complete" && $0.body == "Movie A" })
        #expect(notes.contains { $0.title == "Download failed" && $0.body == "Show B" })
    }

    @Test("no notification when state is unchanged")
    func queueNoChange() {
        let prev = QueueDigest(states: ["a": QueueState.completed.rawValue])
        let (notes, _) = RefreshDiff.queue(previous: prev, current: [queueItem("a", .completed)])
        #expect(notes.isEmpty)
    }

    @Test("a newly-degraded health check notifies; an existing one does not")
    func healthTransitions() {
        let prev = HealthDigest(severities: ["existing": HealthCheck.Severity.warning.rawValue])
        let (notes, digest) = RefreshDiff.health(previous: prev, current: [
            check("existing", .warning),   // unchanged → no note
            check("new", .error),          // newly appeared → note
        ])
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Health error")
        #expect(digest.severities["new"] == HealthCheck.Severity.error.rawValue)
    }
}
