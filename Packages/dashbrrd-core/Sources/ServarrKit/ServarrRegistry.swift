import Foundation
import CoreModel
import Networking

/// The one place that maps a runtime `ServiceKind` to a concrete descriptor and dispatches
/// operations. Because `calendar()` lives on descriptor-constrained extensions, a runtime
/// switch is unavoidable somewhere — confining it here keeps AppCore aggregators and the
/// connection tester free of per-app branching. Adding an *arr = one new case here + its folder.
public enum ServarrRegistry {
    /// Servarr kinds dashbrrd can currently talk to.
    public static let supportedKinds: Set<ServiceKind> = [.sonarr, .radarr, .prowlarr]

    public static func isSupported(_ kind: ServiceKind) -> Bool {
        supportedKinds.contains(kind)
    }

    /// Capability set for a kind (so UI can gate without instantiating a client).
    public static func capabilities(for kind: ServiceKind) -> ServiceCapabilities {
        switch kind {
        case .sonarr: SonarrDescriptor().capabilities
        case .radarr: RadarrDescriptor().capabilities
        case .prowlarr: ProwlarrDescriptor().capabilities
        default: []
        }
    }

    /// Cheap identity probe (Test Connection / version) for any supported kind.
    public static func systemStatus(kind: ServiceKind, profile: ConnectionProfile) async throws -> SystemStatus {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).systemStatus()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).systemStatus()
        case .prowlarr: try await ServarrClientFactory.make(descriptor: ProwlarrDescriptor(), profile: profile).systemStatus()
        default: throw APIError.notFound
        }
    }

    /// Health checks for any supported kind (shared shape across the family).
    public static func health(kind: ServiceKind, profile: ConnectionProfile) async throws -> [HealthCheck] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).health()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).health()
        case .prowlarr: try await ServarrClientFactory.make(descriptor: ProwlarrDescriptor(), profile: profile).health()
        default: throw APIError.notFound
        }
    }

    /// Calendar for calendar-capable kinds; returns `[]` for kinds without one (e.g. Prowlarr).
    public static func calendar(kind: ServiceKind, profile: ConnectionProfile, range: DateInterval) async throws -> [CalendarEntry] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).calendar(range)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).calendar(range)
        default: []
        }
    }

    /// Servarr-side queue for queue-capable kinds; `[]` otherwise (e.g. Prowlarr).
    public static func queue(kind: ServiceKind, profile: ConnectionProfile) async throws -> [QueueItem] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).queue()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).queue()
        default: []
        }
    }

    /// Library (series/movies) for library-capable kinds; `[]` otherwise.
    public static func library(kind: ServiceKind, profile: ConnectionProfile) async throws -> [MediaItem] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).library()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).library()
        default: []
        }
    }
}
