import Foundation
import CoreModel

/// Sonarr: TV management on Servarr API v3. Supports the full media-manager surface.
///
/// This whole folder (`Apps/Sonarr/`) is the "add an *arr in one folder" unit: a
/// descriptor + DTOs + mapper. The generic `ServarrClient` needs nothing else to serve it.
public struct SonarrDescriptor: ServarrDescriptor {
    public init() {}
    public var kind: ServiceKind { .sonarr }
    public var apiVersion: ServarrAPIVersion { .v3 }
    public var capabilities: ServiceCapabilities { .mediaManager.union(.indexers) }
}
