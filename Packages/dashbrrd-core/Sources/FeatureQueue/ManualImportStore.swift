import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for manual import: pick an instance, pick a download, choose
/// files, import.
@MainActor
@Observable
public final class ManualImportStore {
    public private(set) var targets: [ImportTarget] = []
    public var selectedTarget: ImportTarget? {
        didSet { if oldValue != selectedTarget { Task { await loadDownloads() } } }
    }
    public private(set) var downloads: LoadState<[QueueItem]> = .idle

    private let importer: any ManualImporting

    public init(importer: any ManualImporting) {
        self.importer = importer
    }

    public func loadTargets() async {
        targets = await importer.instances()
        if selectedTarget == nil { selectedTarget = targets.first }
        else { await loadDownloads() }
    }

    public func loadDownloads() async {
        guard let target = selectedTarget else { downloads = .loaded([]); return }
        downloads = .loading
        do {
            downloads = .loaded(try await importer.pendingDownloads(target))
        } catch {
            downloads = .failed(message: error.localizedDescription)
        }
    }

    public func candidates(for download: QueueItem) async -> LoadState<[ManualImportCandidate]> {
        guard let target = selectedTarget else { return .loaded([]) }
        do {
            return .loaded(try await importer.candidates(target, downloadID: download.downloadID))
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    public func performImport(_ candidates: [ManualImportCandidate], mode: String) async throws {
        guard let target = selectedTarget else { return }
        try await importer.performImport(target, payloads: candidates.map(\.rawPayload), mode: mode)
    }
}
