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

    private let loader: any LibraryLoading

    public init(loader: any LibraryLoading) {
        self.loader = loader
    }

    public func load() async {
        if state.value == nil { state = .loading }
        let result = await loader.loadLibrary()
        failures = result.failures
        state = .loaded(result.items)
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
