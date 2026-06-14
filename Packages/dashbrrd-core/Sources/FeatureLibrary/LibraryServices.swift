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

/// Edit/delete actions on a media record. Implemented by `AppCore.LiveMediaController`.
public protocol MediaControlling: Sendable {
    func setMonitored(_ item: MediaItem, monitored: Bool) async throws
    func delete(_ item: MediaItem, deleteFiles: Bool) async throws
}

/// Interactive release search for a media item (read-only). `AppCore.LiveReleaseController`.
public protocol ReleaseSearching: Sendable {
    func search(_ item: MediaItem) async throws -> [Release]
}

/// Grabs a release → sends it to the download client (a real state change).
public protocol ReleaseGrabbing: Sendable {
    func grab(_ release: Release) async throws
}
