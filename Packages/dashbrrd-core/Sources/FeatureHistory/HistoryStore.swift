import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for Activity/History. Accumulates pages merged across
/// instances (newest first), with load-more paging.
@MainActor
@Observable
public final class HistoryStore {
    public private(set) var state: LoadState<[HistoryRecord]> = .idle
    public private(set) var failures: [InstanceFailure] = []
    public private(set) var hasMore = false
    public private(set) var isLoadingMore = false

    private var page = 1
    private let loader: any HistoryLoading

    public init(loader: any HistoryLoading) {
        self.loader = loader
    }

    public func load() async {
        page = 1
        if state.value == nil { state = .loading }
        let result = await loader.loadHistory(page: page)
        failures = result.failures
        hasMore = result.hasMore
        state = .loaded(result.records.sorted { $0.date > $1.date })
    }

    public func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        page += 1
        let result = await loader.loadHistory(page: page)
        hasMore = result.hasMore
        var combined = state.value ?? []
        let existingIDs = Set(combined.map(\.id))
        combined.append(contentsOf: result.records.filter { !existingIDs.contains($0.id) })
        state = .loaded(combined.sorted { $0.date > $1.date })
        isLoadingMore = false
    }
}
