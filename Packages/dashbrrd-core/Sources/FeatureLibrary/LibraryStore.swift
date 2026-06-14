import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for the Library. Holds merged items + per-instance failures
/// and groups items by service for the sectioned poster grid.
@MainActor
@Observable
public final class LibraryStore {
    public private(set) var state: LoadState<[MediaItem]> = .idle
    public private(set) var failures: [InstanceFailure] = []
    public var actionError: String?

    private let loader: any LibraryLoading
    private let controller: any MediaControlling
    private let releaseSearcher: any ReleaseSearching
    private let releaseGrabber: any ReleaseGrabbing

    public init(
        loader: any LibraryLoading,
        controller: any MediaControlling,
        releaseSearcher: any ReleaseSearching,
        releaseGrabber: any ReleaseGrabbing
    ) {
        self.loader = loader
        self.controller = controller
        self.releaseSearcher = releaseSearcher
        self.releaseGrabber = releaseGrabber
    }

    /// Builds a release-search store for a media item (used by the detail view).
    public func makeReleaseStore(for item: MediaItem) -> ReleaseStore {
        ReleaseStore(item: item, searcher: releaseSearcher, grabber: releaseGrabber)
    }

    public func load() async {
        if state.value == nil { state = .loading }
        let result = await loader.loadLibrary()
        failures = result.failures
        state = .loaded(result.items)
    }

    /// Optimistically flips `monitored`; rolls back on failure.
    public func setMonitored(_ item: MediaItem, monitored: Bool) async {
        let previous = state.value ?? []
        var updated = previous
        if let index = updated.firstIndex(where: { $0.id == item.id }) {
            updated[index].monitored = monitored
            state = .loaded(updated)
        }
        do {
            try await controller.setMonitored(item, monitored: monitored)
        } catch {
            state = .loaded(previous)
            actionError = "Couldn't update \(item.title): \(error.localizedDescription)"
        }
    }

    /// Optimistically removes the item; rolls back (reloads) on failure.
    public func delete(_ item: MediaItem, deleteFiles: Bool) async {
        let previous = state.value ?? []
        state = .loaded(previous.filter { $0.id != item.id })
        do {
            try await controller.delete(item, deleteFiles: deleteFiles)
        } catch {
            state = .loaded(previous)
            actionError = "Couldn't delete \(item.title): \(error.localizedDescription)"
        }
    }

    public func currentItem(_ id: String) -> MediaItem? {
        (state.value ?? []).first { $0.id == id }
    }

    /// Items grouped by service kind (TV vs Movies …), each sorted by title.
    public var groupedByService: [(kind: ServiceKind, items: [MediaItem])] {
        guard let items = state.value else { return [] }
        let groups = Dictionary(grouping: items, by: \.serviceKind)
        return groups.keys
            .sorted { $0.displayName < $1.displayName }
            .map { kind in
                (kind, groups[kind]!.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
            }
    }
}
