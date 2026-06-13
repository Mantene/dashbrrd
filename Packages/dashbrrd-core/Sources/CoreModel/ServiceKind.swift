import Foundation

/// The kind of self-hosted service a configured instance represents.
///
/// `ServiceKind` is the discriminator that drives capability gating, iconography,
/// and which engine (`ServarrKit` vs `DownloadClientKit`) handles an instance.
public enum ServiceKind: String, Codable, Sendable, CaseIterable, Hashable {
    // Servarr family
    case sonarr
    case radarr
    case prowlarr
    case lidarr
    case readarr

    // Download clients
    case sabnzbd
    case qbittorrent

    /// Human-facing name used in lists and the add-server picker.
    public var displayName: String {
        switch self {
        case .sonarr: "Sonarr"
        case .radarr: "Radarr"
        case .prowlarr: "Prowlarr"
        case .lidarr: "Lidarr"
        case .readarr: "Readarr"
        case .sabnzbd: "SABnzbd"
        case .qbittorrent: "qBittorrent"
        }
    }

    /// Whether this kind is served by the shared Servarr REST engine.
    public var isServarr: Bool {
        switch self {
        case .sonarr, .radarr, .prowlarr, .lidarr, .readarr: true
        case .sabnzbd, .qbittorrent: false
        }
    }

    /// Whether this kind is a download client.
    public var isDownloadClient: Bool { !isServarr }
}
