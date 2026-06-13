import Foundation

/// The kind of credential a service needs from the user.
enum CredentialKind: String, Codable, Sendable {
    case apiKey
    case usernamePassword
}

/// How requests to a service are authenticated. Drives `APIClientFactory`.
enum AuthScheme: Sendable {
    case apiKeyHeader(field: String)   // Servarr (X-Api-Key) / Bazarr (X-API-KEY)
    case apiKeyQuery(field: String)    // SABnzbd (?apikey=)
    case basic                         // NZBGet
    case qbittorrentCookie             // login -> SID cookie
    case transmissionSession           // X-Transmission-Session-Id handshake
}

/// Every service dashbrrd can talk to. Each case carries its connection conventions.
enum ServiceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case sonarr, radarr, lidarr, readarr, prowlarr
    case sabnzbd, nzbget, qbittorrent, transmission
    case bazarr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sonarr: "Sonarr"
        case .radarr: "Radarr"
        case .lidarr: "Lidarr"
        case .readarr: "Readarr"
        case .prowlarr: "Prowlarr"
        case .sabnzbd: "SABnzbd"
        case .nzbget: "NZBGet"
        case .qbittorrent: "qBittorrent"
        case .transmission: "Transmission"
        case .bazarr: "Bazarr"
        }
    }

    var subtitle: String {
        switch self {
        case .sonarr: "TV Shows"
        case .radarr: "Movies"
        case .lidarr: "Music"
        case .readarr: "Books"
        case .prowlarr: "Indexers"
        case .sabnzbd, .nzbget: "Usenet downloader"
        case .qbittorrent, .transmission: "Torrent client"
        case .bazarr: "Subtitles"
        }
    }

    var symbolName: String {
        switch self {
        case .sonarr: "tv"
        case .radarr: "film"
        case .lidarr: "music.note"
        case .readarr: "book"
        case .prowlarr: "magnifyingglass"
        case .sabnzbd, .nzbget: "arrow.down.circle"
        case .qbittorrent, .transmission: "arrow.up.arrow.down.circle"
        case .bazarr: "captions.bubble"
        }
    }

    var defaultPort: Int {
        switch self {
        case .sonarr: 8989
        case .radarr: 7878
        case .lidarr: 8686
        case .readarr: 8787
        case .prowlarr: 9696
        case .sabnzbd: 8080
        case .nzbget: 6789
        case .qbittorrent: 8080
        case .transmission: 9091
        case .bazarr: 6767
        }
    }

    /// Path prefix appended to the instance base URL before endpoint paths.
    var apiBasePath: String {
        switch self {
        case .sonarr, .radarr: "/api/v3"
        case .lidarr, .readarr, .prowlarr: "/api/v1"
        case .bazarr: "/api"
        case .sabnzbd: "/api"
        case .nzbget: "/jsonrpc"
        case .qbittorrent: "/api/v2"
        case .transmission: "/transmission/rpc"
        }
    }

    var credentialKind: CredentialKind {
        switch self {
        case .nzbget, .qbittorrent, .transmission: .usernamePassword
        default: .apiKey
        }
    }

    var authScheme: AuthScheme {
        switch self {
        case .sonarr, .radarr, .lidarr, .readarr, .prowlarr:
            .apiKeyHeader(field: "X-Api-Key")
        case .bazarr:
            .apiKeyHeader(field: "X-API-KEY")
        case .sabnzbd:
            .apiKeyQuery(field: "apikey")
        case .nzbget:
            .basic
        case .qbittorrent:
            .qbittorrentCookie
        case .transmission:
            .transmissionSession
        }
    }

    /// True for the five apps that share the Servarr API surface.
    var isServarr: Bool {
        switch self {
        case .sonarr, .radarr, .lidarr, .readarr, .prowlarr: true
        default: false
        }
    }

    var isDownloadClient: Bool {
        switch self {
        case .sabnzbd, .nzbget, .qbittorrent, .transmission: true
        default: false
        }
    }
}
