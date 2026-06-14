import Foundation
import CoreModel

/// Prowlarr: indexer manager on Servarr API **v1**. Deliberately advertises only
/// `systemStatus`, `health`, and `indexers` — no calendar or library. The aggregators and
/// generic feature UI consult these capabilities and simply skip Prowlarr for calendar views,
/// which is the capability-gating the architecture promises (no per-app `if kind ==` checks).
public struct ProwlarrDescriptor: ServarrDescriptor {
    public init() {}
    public var kind: ServiceKind { .prowlarr }
    public var apiVersion: ServarrAPIVersion { .v1 }
    public var capabilities: ServiceCapabilities { [.systemStatus, .health, .indexers] }
}
