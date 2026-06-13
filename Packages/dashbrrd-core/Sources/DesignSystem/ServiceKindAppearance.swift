import SwiftUI
import CoreModel

/// Maps each `ServiceKind` to its brand-ish accent color and SF Symbol, so aggregated
/// views (one calendar, one queue) can color/badge entries by their source service.
extension ServiceKind {
    public var accentColor: Color {
        switch self {
        case .sonarr: .blue
        case .radarr: .yellow
        case .prowlarr: .orange
        case .lidarr: .green
        case .readarr: .red
        case .sabnzbd: .teal
        case .qbittorrent: .indigo
        }
    }

    public var symbolName: String {
        switch self {
        case .sonarr: "tv"
        case .radarr: "film"
        case .prowlarr: "magnifyingglass"
        case .lidarr: "music.note"
        case .readarr: "book"
        case .sabnzbd: "arrow.down.circle"
        case .qbittorrent: "arrow.down.app"
        }
    }
}
