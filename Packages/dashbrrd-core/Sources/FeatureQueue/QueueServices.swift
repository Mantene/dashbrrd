import Foundation
import CoreModel

/// Merged queue across all Servarr + download-client instances, plus per-instance failures.
public struct QueueResult: Sendable {
    public var items: [QueueItem]
    public var failures: [InstanceFailure]

    public init(items: [QueueItem], failures: [InstanceFailure]) {
        self.items = items
        self.failures = failures
    }
}

/// Loads + merges the unified queue. Implemented by `AppCore.QueueAggregator`.
public protocol QueueLoading: Sendable {
    func loadQueue() async -> QueueResult
}

/// Dispatches management actions to the correct underlying download client.
/// Implemented by `AppCore.LiveQueueController`.
public protocol QueueControlling: Sendable {
    func pause(_ item: QueueItem) async throws
    func resume(_ item: QueueItem) async throws
    func remove(_ item: QueueItem, deleteData: Bool) async throws
}
