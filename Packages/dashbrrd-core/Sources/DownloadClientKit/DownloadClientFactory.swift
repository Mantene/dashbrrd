import Foundation
import CoreModel
import Networking

/// Builds the right `DownloadClient` for a kind from a resolved `ConnectionProfile`.
/// SABnzbd has no API prefix (`/api?mode=…`, apikey via query); qBittorrent uses `api/v2`.
public enum DownloadClientFactory {
    public static let supportedKinds: Set<ServiceKind> = [.sabnzbd, .qbittorrent]

    public static func isSupported(_ kind: ServiceKind) -> Bool {
        supportedKinds.contains(kind)
    }

    public static func make(kind: ServiceKind, instanceID: InstanceID, profile: ConnectionProfile) -> (any DownloadClient)? {
        switch kind {
        case .sabnzbd:
            let http = HTTPClient(profile: profile, apiPrefix: nil, interceptors: profile.requestInterceptors())
            return SABnzbdClient(instanceID: instanceID, http: http)
        case .qbittorrent:
            let http = HTTPClient(profile: profile, apiPrefix: "api/v2", interceptors: profile.requestInterceptors())
            return QBittorrentClient(instanceID: instanceID, http: http)
        default:
            return nil
        }
    }
}
