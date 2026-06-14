import Foundation
import CoreModel

/// Lidarr: music (artists/albums) on Servarr API **v1**. The extensibility proof — this folder
/// + a handful of `.lidarr` cases in `ServarrRegistry` is all it takes; shared system/health/
/// queue/history come for free.
public struct LidarrDescriptor: ServarrDescriptor {
    public init() {}
    public var kind: ServiceKind { .lidarr }
    public var apiVersion: ServarrAPIVersion { .v1 }
    public var capabilities: ServiceCapabilities {
        [.systemStatus, .health, .calendar, .queue, .library, .history, .indexers]
    }
}
