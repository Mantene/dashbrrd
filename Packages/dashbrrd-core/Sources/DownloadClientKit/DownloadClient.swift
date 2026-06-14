import Foundation
import CoreModel
import Networking

/// The shared surface every download client (SABnzbd, qBittorrent) presents to the app, so
/// the unified Queue can read and dispatch actions polymorphically regardless of usenet vs torrent.
public protocol DownloadClient: Sendable {
    var instanceID: InstanceID { get }
    var kind: ServiceKind { get }

    /// Cheap identity probe for Test Connection (SAB `?mode=version`, qBit `app/version`).
    func version() async throws -> String

    /// Current queue, normalized.
    func queue() async throws -> [QueueItem]

    /// Management actions (optimistic in the UI; these are the authoritative calls).
    func pause(_ downloadID: String) async throws
    func resume(_ downloadID: String) async throws
    func remove(_ downloadID: String, deleteData: Bool) async throws
}
