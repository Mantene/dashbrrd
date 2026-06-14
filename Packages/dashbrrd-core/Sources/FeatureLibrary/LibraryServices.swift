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

/// A selectable library (one Sonarr/Radarr instance).
public struct LibraryInstance: Sendable, Identifiable, Hashable {
    public var id: InstanceID
    public var name: String
    public var kind: ServiceKind
    public init(id: InstanceID, name: String, kind: ServiceKind) {
        self.id = id; self.name = name; self.kind = kind
    }
}

/// Lists library-capable instances and loads ONE at a time (large libraries make a single
/// merged page unwieldy). Implemented by `AppCore.LibraryAggregator`.
public protocol LibraryLoading: Sendable {
    func instances() async -> [LibraryInstance]
    func loadLibrary(_ instance: LibraryInstance) async -> LibraryResult
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

/// An instance new media can be added to (a Sonarr/Radarr config).
public struct AddTarget: Sendable, Identifiable, Hashable {
    public var id: InstanceID
    public var name: String
    public var kind: ServiceKind
    public init(id: InstanceID, name: String, kind: ServiceKind) {
        self.id = id; self.name = name; self.kind = kind
    }
}

/// The choices required to add media to a target (fetched per instance).
public struct AddOptions: Sendable {
    public var qualityProfiles: [QualityProfile]
    public var rootFolders: [RootFolder]
    public init(qualityProfiles: [QualityProfile], rootFolders: [RootFolder]) {
        self.qualityProfiles = qualityProfiles
        self.rootFolders = rootFolders
    }
}

/// Add-new-media flow. Implemented by `AppCore.LiveMediaAdder`.
public protocol MediaAdding: Sendable {
    func addableInstances() async -> [AddTarget]
    func lookup(_ target: AddTarget, term: String) async throws -> [MediaLookupItem]
    func options(_ target: AddTarget) async throws -> AddOptions
    func add(_ item: MediaLookupItem, to target: AddTarget, qualityProfileID: Int, rootFolderPath: String, monitored: Bool, searchOnAdd: Bool) async throws
}
