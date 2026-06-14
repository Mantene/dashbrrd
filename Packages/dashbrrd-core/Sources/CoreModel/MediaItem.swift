import Foundation

/// A normalized library item — a Sonarr series or a Radarr movie — flattened to what the
/// shared poster-grid UI needs. App-specific differences (episode counts vs file presence)
/// are folded into `subtitle` by each mapper so the grid stays service-agnostic.
public struct MediaItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var title: String
    public var year: Int?
    public var posterURL: URL?
    public var monitored: Bool
    /// Service-specific one-liner, e.g. "Continuing · 24/30" (Sonarr) or "Downloaded" (Radarr).
    public var subtitle: String?

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        title: String,
        year: Int? = nil,
        posterURL: URL? = nil,
        monitored: Bool = true,
        subtitle: String? = nil
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.title = title
        self.year = year
        self.posterURL = posterURL
        self.monitored = monitored
        self.subtitle = subtitle
    }

    /// Title with year suffix when known, for display.
    public var displayTitle: String {
        year.map { "\(title) (\($0))" } ?? title
    }
}
