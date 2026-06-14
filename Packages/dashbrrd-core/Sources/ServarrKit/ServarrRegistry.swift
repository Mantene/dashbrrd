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

    /// A page of history for history-capable kinds; an empty page otherwise.
    public static func history(kind: ServiceKind, profile: ConnectionProfile, request: PagedRequest) async throws -> Page<HistoryRecord> {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).history(request)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).history(request)
        default: Page(page: request.page, pageSize: request.pageSize, totalRecords: 0, records: [])
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

    /// Interactive release search for a media item (Sonarr by seriesId, Radarr by movieId).
    public static func releaseSearch(kind: ServiceKind, profile: ConnectionProfile, remoteID: Int) async throws -> [Release] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).releaseSearch(paramName: "seriesId", mediaID: remoteID)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).releaseSearch(paramName: "movieId", mediaID: remoteID)
        default: []
        }
    }

    /// Grabs a release (sends it to the download client). A real state change.
    public static func grab(kind: ServiceKind, profile: ConnectionProfile, guid: String, indexerID: Int) async throws {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).grab(guid: guid, indexerID: indexerID)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).grab(guid: guid, indexerID: indexerID)
        default: break
        }
    }

    /// Lookup search for new media (Sonarr series / Radarr movie).
    public static func lookup(kind: ServiceKind, profile: ConnectionProfile, term: String) async throws -> [MediaLookupItem] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).lookup(resource: "series", term: term)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).lookup(resource: "movie", term: term)
        default: []
        }
    }

    public static func qualityProfiles(kind: ServiceKind, profile: ConnectionProfile) async throws -> [QualityProfile] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).qualityProfiles()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).qualityProfiles()
        default: []
        }
    }

    public static func rootFolders(kind: ServiceKind, profile: ConnectionProfile) async throws -> [RootFolder] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).rootFolders()
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).rootFolders()
        default: []
        }
    }

    /// Adds new media. A real state change. `extraFields` injects per-app requirements.
    public static func addMedia(
        kind: ServiceKind,
        profile: ConnectionProfile,
        payload: Data,
        qualityProfileID: Int,
        rootFolderPath: String,
        monitored: Bool,
        searchOnAdd: Bool
    ) async throws {
        switch kind {
        case .sonarr:
            try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).addMedia(
                resource: "series", payload: payload, qualityProfileID: qualityProfileID,
                rootFolderPath: rootFolderPath, monitored: monitored, searchOnAdd: searchOnAdd,
                searchOptionKey: "searchForMissingEpisodes"
            )
        case .radarr:
            try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).addMedia(
                resource: "movie", payload: payload, qualityProfileID: qualityProfileID,
                rootFolderPath: rootFolderPath, monitored: monitored, searchOnAdd: searchOnAdd,
                searchOptionKey: "searchForMovie", extraFields: ["minimumAvailability": "released"]
            )
        default:
            break
        }
    }

    /// Manual-import candidates for a download (Sonarr/Radarr).
    public static func manualImportCandidates(kind: ServiceKind, profile: ConnectionProfile, downloadID: String) async throws -> [ManualImportCandidate] {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).manualImportCandidates(downloadID: downloadID)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).manualImportCandidates(downloadID: downloadID)
        default: []
        }
    }

    /// Performs a manual import of the given candidate payloads. A real state change.
    public static func manualImport(kind: ServiceKind, profile: ConnectionProfile, payloads: [Data], importMode: String) async throws {
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).manualImport(payloads: payloads, importMode: importMode)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).manualImport(payloads: payloads, importMode: importMode)
        default: break
        }
    }

    /// The REST resource name for a kind's media records ("series" / "movie").
    static func mediaResource(for kind: ServiceKind) -> String? {
        switch kind {
        case .sonarr: "series"
        case .radarr: "movie"
        default: nil
        }
    }

    public static func setMonitored(kind: ServiceKind, profile: ConnectionProfile, remoteID: Int, monitored: Bool) async throws {
        guard let resource = mediaResource(for: kind) else { return }
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).setMonitored(resource: resource, id: remoteID, monitored: monitored)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).setMonitored(resource: resource, id: remoteID, monitored: monitored)
        default: break
        }
    }

    public static func deleteMedia(kind: ServiceKind, profile: ConnectionProfile, remoteID: Int, deleteFiles: Bool) async throws {
        guard let resource = mediaResource(for: kind) else { return }
        switch kind {
        case .sonarr: try await ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: profile).deleteMedia(resource: resource, id: remoteID, deleteFiles: deleteFiles)
        case .radarr: try await ServarrClientFactory.make(descriptor: RadarrDescriptor(), profile: profile).deleteMedia(resource: resource, id: remoteID, deleteFiles: deleteFiles)
        default: break
        }
    }
}
