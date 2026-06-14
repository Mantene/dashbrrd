import Foundation
import CoreModel

/// Aggregated library items across every library-capable instance, plus per-instance failures.
public struct LibraryResult: Sendable {
    public var items: [MediaItem]
    public var failures: [InstanceFailure]

    public init(items: [MediaItem], failures: [InstanceFailure]) {
        self.items = items
        self.failures = failures
    }
}

/// Loads + merges library contents across instances. Implemented by `AppCore.LibraryAggregator`.
public protocol LibraryLoading: Sendable {
    func loadLibrary() async -> LibraryResult
}
