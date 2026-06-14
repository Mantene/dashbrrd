import Foundation
import CoreModel

/// One page of merged history across instances, with a "more available" flag + failures.
public struct HistoryResult: Sendable {
    public var records: [HistoryRecord]
    public var hasMore: Bool
    public var failures: [InstanceFailure]

    public init(records: [HistoryRecord], hasMore: Bool, failures: [InstanceFailure]) {
        self.records = records
        self.hasMore = hasMore
        self.failures = failures
    }
}

/// Loads a page of merged history across history-capable instances. `page` is 1-based.
/// Implemented by `AppCore.HistoryAggregator`.
public protocol HistoryLoading: Sendable {
    func loadHistory(page: Int) async -> HistoryResult
}
