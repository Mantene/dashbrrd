import Foundation
import CoreModel

/// Radarr: movie management on Servarr API v3. Same generic engine as Sonarr — the only
/// new code for this service is this folder (descriptor + DTOs + mapper + calendar ext).
public struct RadarrDescriptor: ServarrDescriptor {
    public init() {}
    public var kind: ServiceKind { .radarr }
    public var apiVersion: ServarrAPIVersion { .v3 }
    public var capabilities: ServiceCapabilities { .mediaManager.union(.indexers) }
}
