import Foundation

// The normalized "lingua franca" domain types. Every service engine maps its own
// wire DTOs *into* these so the UI never sees an upstream schema. Phase 0 seeds the
// handful needed for the first vertical slice (status / health / calendar); later
// phases extend this file (QueueItem, Release, HistoryRecord, MediaItem, …).

/// Result of a Servarr `system/status` call, normalized.
public struct SystemStatus: Sendable, Hashable, Codable {
    public var instanceID: InstanceID
    public var version: String
    public var appName: String

    public init(instanceID: InstanceID, version: String, appName: String) {
        self.instanceID = instanceID
        self.version = version
        self.appName = appName
    }
}

/// A single health check reported by a service.
public struct HealthCheck: Sendable, Hashable, Codable, Identifiable {
    public enum Severity: String, Sendable, Codable, CaseIterable {
        case ok, notice, warning, error
    }

    public var id: String
    public var instanceID: InstanceID
    public var source: String
    public var severity: Severity
    public var message: String
    public var wikiURL: URL?

    public init(
        id: String,
        instanceID: InstanceID,
        source: String,
        severity: Severity,
        message: String,
        wikiURL: URL? = nil
    ) {
        self.id = id
        self.instanceID = instanceID
        self.source = source
        self.severity = severity
        self.message = message
        self.wikiURL = wikiURL
    }
}

/// A normalized calendar entry (an upcoming/aired episode, movie release, etc.).
public struct CalendarEntry: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var title: String
    public var subtitle: String?
    public var airDate: Date
    public var hasFile: Bool

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        title: String,
        subtitle: String? = nil,
        airDate: Date,
        hasFile: Bool = false
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.title = title
        self.subtitle = subtitle
        self.airDate = airDate
        self.hasFile = hasFile
    }
}
