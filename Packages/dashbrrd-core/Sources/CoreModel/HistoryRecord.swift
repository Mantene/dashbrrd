import Foundation

/// A normalized activity/history event (grab, import, failure, deletion …) across services.
public struct HistoryRecord: Sendable, Hashable, Identifiable {
    public enum EventType: String, Sendable, Hashable {
        case grabbed
        case imported
        case failed
        case deleted
        case renamed
        case ignored
        case unknown
    }

    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var eventType: EventType
    public var title: String          // sourceTitle
    public var date: Date
    public var quality: String?

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        eventType: EventType,
        title: String,
        date: Date,
        quality: String? = nil
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.eventType = eventType
        self.title = title
        self.date = date
        self.quality = quality
    }
}

extension HistoryRecord.EventType {
    /// Maps Servarr's `eventType` strings (Sonarr + Radarr variants) to our normalized set.
    public init(servarrEventType raw: String) {
        switch raw {
        case "grabbed": self = .grabbed
        case "downloadFolderImported", "movieFolderImported": self = .imported
        case "downloadFailed": self = .failed
        case "episodeFileDeleted", "movieFileDeleted": self = .deleted
        case "episodeFileRenamed", "movieFileRenamed", "renamed": self = .renamed
        case "downloadIgnored": self = .ignored
        default: self = .unknown
        }
    }
}
