import Foundation

/// Normalized state of a download across SABnzbd (usenet) and qBittorrent (torrent).
public enum QueueState: String, Sendable, Hashable {
    case downloading
    case paused
    case queued
    case completed
    case stalled
    case error
    case unknown
}

/// A normalized item in a download client's queue, flattened to what the unified Queue UI
/// needs. Each client's mapper folds its own status vocabulary into `QueueState`.
public struct QueueItem: Sendable, Hashable, Identifiable {
    public var id: String                 // "instanceID:downloadId"
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind   // .sabnzbd / .qbittorrent (the client it came from)
    public var name: String
    public var state: QueueState
    /// 0.0 ... 1.0
    public var progress: Double
    public var sizeBytes: Int64
    public var sizeLeftBytes: Int64
    public var speedBytesPerSec: Int64
    public var etaSeconds: Int?
    public var category: String?
    /// The client's native id (qBit hash / SAB nzo_id) — used to dedup against Servarr queues.
    public var downloadID: String

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        name: String,
        state: QueueState,
        progress: Double,
        sizeBytes: Int64,
        sizeLeftBytes: Int64,
        speedBytesPerSec: Int64,
        etaSeconds: Int? = nil,
        category: String? = nil,
        downloadID: String
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.name = name
        self.state = state
        self.progress = progress
        self.sizeBytes = sizeBytes
        self.sizeLeftBytes = sizeLeftBytes
        self.speedBytesPerSec = speedBytesPerSec
        self.etaSeconds = etaSeconds
        self.category = category
        self.downloadID = downloadID
    }

    public var isPaused: Bool { state == .paused }
}
