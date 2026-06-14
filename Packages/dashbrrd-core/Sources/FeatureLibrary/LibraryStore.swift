import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for the Library. Shows ONE selected library at a time
/// (large libraries make an all-in-one page unwieldy) plus a title filter.
@MainActor
@Observable
public final class LibraryStore {
    public private(set) var instances: [LibraryInstance] = []
    public var selected: LibraryInstance? {
        didSet { if oldValue != selected { Task { await loadSelected() } } }
    }

    public private(set) var state: LoadState<[MediaItem]> = .idle
    public private(set) var failures: [InstanceFailure] = []
    /// Live title filter within the selected library.
    public var filterText: String = ""
    public var actionError: String?

    private let loader: any LibraryLoading
    private let controller: any MediaControlling
    private let releaseSearcher: any ReleaseSearching
    private let releaseGrabber: any ReleaseGrabbing
    private let adder: any MediaAdding

    public init(
        loader: any LibraryLoading,
        controller: any MediaControlling,
        releaseSearcher: any ReleaseSearching,
        releaseGrabber: any ReleaseGrabbing,
        adder: any MediaAdding
    ) {
        self.loader = loader
        self.controller = controller
        self.releaseSearcher = releaseSearcher
        self.releaseGrabber = releaseGrabber
        self.adder = adder
    }

    /// Loads the instance list; selects the first the first time, then loads it.
    public func loadInstances() async {
        instances = await loader.instances()
        if selected == nil || !instances.contains(where: { $0.id == selected?.id }) {
            selected = instances.first   // triggers loadSelected via didSet
        } else if state.value == nil {
            await loadSelected()
        }
    }

    public func loadSelected() async {
        guard let selected else { state = .loaded([]); return }
        state = .loading
        let result = await loader.loadLibrary(selected)
        failures = result.failures
        state = .loaded(result.items)
    }

    /// Items for the selected library, title-filtered and sorted.
    public var visibleItems: [MediaItem] {
        let items = state.value ?? []
        let query = filterText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public var totalCount: Int { (state.value ?? []).count }

    // MARK: - Edit / delete (optimistic)

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

    public func makeReleaseStore(for item: MediaItem) -> ReleaseStore {
        ReleaseStore(item: item, searcher: releaseSearcher, grabber: releaseGrabber)
    }

    public func makeAddStore() -> AddMediaStore {
        AddMediaStore(adder: adder)
    }
}
