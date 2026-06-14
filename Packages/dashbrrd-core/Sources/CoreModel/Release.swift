import Foundation

/// A normalized indexer release from an interactive search, ready to grab/send-to-client.
public struct Release: Sendable, Hashable, Identifiable {
    public var id: String            // the release guid (unique per indexer result)
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var guid: String
    public var indexerID: Int
    public var title: String
    public var indexer: String
    /// Usenet vs torrent (drives the icon and whether seeders are meaningful).
    public var isUsenet: Bool
    public var sizeBytes: Int64
    public var seeders: Int?
    public var ageDays: Int
    public var quality: String?
    /// Servarr pre-judged this release as rejected (with human-readable reasons).
    public var rejected: Bool
    public var rejections: [String]
    /// Whether Servarr will actually allow grabbing this.
    public var downloadAllowed: Bool

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        guid: String,
        indexerID: Int,
        title: String,
        indexer: String,
        isUsenet: Bool,
        sizeBytes: Int64,
        seeders: Int? = nil,
        ageDays: Int,
        quality: String? = nil,
        rejected: Bool,
        rejections: [String],
        downloadAllowed: Bool
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.guid = guid
        self.indexerID = indexerID
        self.title = title
        self.indexer = indexer
        self.isUsenet = isUsenet
        self.sizeBytes = sizeBytes
        self.seeders = seeders
        self.ageDays = ageDays
        self.quality = quality
        self.rejected = rejected
        self.rejections = rejections
        self.downloadAllowed = downloadAllowed
    }
}
