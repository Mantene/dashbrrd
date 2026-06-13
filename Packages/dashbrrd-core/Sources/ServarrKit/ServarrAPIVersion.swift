import Foundation

/// The Servarr API major version a given app speaks.
///
/// Sonarr/Radarr are on v3; Prowlarr is on v1. The descriptor surfaces this so the
/// engine can build the correct `api/v3` vs `api/v1` URL prefix from one code path.
public enum ServarrAPIVersion: String, Sendable, Hashable {
    case v1
    case v3

    /// The URL path prefix, e.g. `"api/v3"`.
    public var pathPrefix: String { "api/\(rawValue)" }
}
