import Foundation

/// A normalized library item — a Sonarr series or a Radarr movie — flattened to what the
/// shared poster-grid UI needs. App-specific differences (episode counts vs file presence)
/// are folded into `subtitle` by each mapper so the grid stays service-agnostic.
public struct MediaItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    /// The upstream record id (Sonarr series id / Radarr movie id) for edit/delete calls.
    public var remoteID: Int
    public var title: String
    public var year: Int?
    public var posterURL: URL?
    public var monitored: Bool
    public var overview: String?
    /// Service-specific one-liner, e.g. "Continuing · 24/30" (Sonarr) or "Downloaded" (Radarr).
    public var subtitle: String?

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        remoteID: Int,
        title: String,
        year: Int? = nil,
        posterURL: URL? = nil,
        monitored: Bool = true,
        overview: String? = nil,
        subtitle: String? = nil
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.remoteID = remoteID
        self.title = title
        self.year = year
        self.posterURL = posterURL
        self.monitored = monitored
        self.overview = overview
        self.subtitle = subtitle
    }

    /// Title with year suffix when known, for display.
    public var displayTitle: String {
        year.map { "\(title) (\($0))" } ?? title
    }
}
