import Foundation
import CoreModel

/// A Servarr instance that supports manual import (Sonarr/Radarr).
public struct ImportTarget: Sendable, Identifiable, Hashable {
    public var id: InstanceID
    public var name: String
    public var kind: ServiceKind
    public init(id: InstanceID, name: String, kind: ServiceKind) {
        self.id = id; self.name = name; self.kind = kind
    }
}

/// Manual-import flow. Implemented by `AppCore.LiveManualImporter`.
public protocol ManualImporting: Sendable {
    func instances() async -> [ImportTarget]
    /// Downloads currently in the instance's queue (candidates for manual import).
    func pendingDownloads(_ target: ImportTarget) async throws -> [QueueItem]
    func candidates(_ target: ImportTarget, downloadID: String) async throws -> [ManualImportCandidate]
    /// Imports the chosen candidate payloads (`mode` is "move" or "copy"). A real state change.
    func performImport(_ target: ImportTarget, payloads: [Data], mode: String) async throws
}
