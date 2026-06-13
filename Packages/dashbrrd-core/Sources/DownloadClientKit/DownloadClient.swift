import Foundation
import CoreModel
import Networking

/// The shared surface every download client (SABnzbd, qBittorrent) presents to the app.
///
/// Phase 0 defines the seam so the unified Queue can dispatch actions polymorphically;
/// concrete clients (`SABnzbdClient`, `QBittorrentClient`) arrive in Phase 3.
public protocol DownloadClient: Sendable {
    var instanceID: InstanceID { get }
    var kind: ServiceKind { get }

    /// Cheap identity probe for Test Connection (SAB `?mode=version`, qBit `app/version`).
    func version() async throws -> String
}
