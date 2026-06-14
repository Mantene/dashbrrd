import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for the unified Queue. Mutations are **optimistic**: the
/// local list updates immediately, the request fires, and on failure the previous state is
/// restored and a transient error is surfaced.
@MainActor
@Observable
public final class QueueStore {
    public private(set) var state: LoadState<[QueueItem]> = .idle
    public private(set) var failures: [InstanceFailure] = []
    public var actionError: String?

    private let loader: any QueueLoading
    private let controller: any QueueControlling
    private let manualImporter: any ManualImporting

    public init(loader: any QueueLoading, controller: any QueueControlling, manualImporter: any ManualImporting) {
        self.loader = loader
        self.controller = controller
        self.manualImporter = manualImporter
    }

    /// Builds a manual-import store (used by the Queue's "Manual Import" action).
    public func makeManualImportStore() -> ManualImportStore {
        ManualImportStore(importer: manualImporter)
    }

    public func load() async {
        if state.value == nil { state = .loading }
        let result = await loader.loadQueue()
        failures = result.failures
        state = .loaded(QueueItem.merged(result.items))
    }

    private var items: [QueueItem] { state.value ?? [] }

    public func pause(_ item: QueueItem) async {
        await mutate(item, optimistic: { $0.state = .paused }) {
            try await self.controller.pause(item)
        }
    }

    public func resume(_ item: QueueItem) async {
        await mutate(item, optimistic: { $0.state = .downloading }) {
            try await self.controller.resume(item)
        }
    }

    public func remove(_ item: QueueItem, deleteData: Bool) async {
        let previous = items
        state = .loaded(items.filter { $0.id != item.id })
        do {
            try await controller.remove(item, deleteData: deleteData)
        } catch {
            state = .loaded(previous) // rollback
            actionError = "Couldn't remove \(item.name): \(error.localizedDescription)"
        }
    }

    /// Applies an optimistic edit to one item, fires the request, rolls back on failure.
    private func mutate(_ item: QueueItem, optimistic: (inout QueueItem) -> Void, perform: @escaping () async throws -> Void) async {
        let previous = items
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == item.id }) {
            optimistic(&updated[index])
            state = .loaded(updated)
        }
        do {
            try await perform()
        } catch {
            state = .loaded(previous) // rollback
            actionError = "Action failed for \(item.name): \(error.localizedDescription)"
        }
    }

    /// Only download-client items support inline actions (Servarr-side items are read-only here).
    public func canControl(_ item: QueueItem) -> Bool {
        item.serviceKind.isDownloadClient
    }
}
