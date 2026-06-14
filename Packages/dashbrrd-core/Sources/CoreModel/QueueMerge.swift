import Foundation

extension QueueItem {
    /// Merges queue items from Servarr apps and download clients into one deduped list.
    ///
    /// A download appears in both a Servarr queue *and* its download client (matched by
    /// `downloadID`). We keep the **download-client** copy (live speed/progress) and drop the
    /// Servarr duplicate. Items with an empty `downloadID` (can't be correlated) are always kept.
    /// Result is sorted active-first, then by name.
    public static func merged(_ items: [QueueItem]) -> [QueueItem] {
        var byDownloadID: [String: QueueItem] = [:]
        var uncorrelated: [QueueItem] = []

        for item in items {
            guard !item.downloadID.isEmpty else {
                uncorrelated.append(item)
                continue
            }
            if let existing = byDownloadID[item.downloadID] {
                // Prefer the download-client copy over the Servarr one.
                if !existing.serviceKind.isDownloadClient && item.serviceKind.isDownloadClient {
                    byDownloadID[item.downloadID] = item
                }
            } else {
                byDownloadID[item.downloadID] = item
            }
        }

        return (Array(byDownloadID.values) + uncorrelated).sorted { lhs, rhs in
            if lhs.state.sortOrder != rhs.state.sortOrder {
                return lhs.state.sortOrder < rhs.state.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

extension QueueState {
    /// Active downloads first, then waiting, then done/failed.
    var sortOrder: Int {
        switch self {
        case .downloading: 0
        case .stalled: 1
        case .queued: 2
        case .paused: 3
        case .completed: 4
        case .error: 5
        case .unknown: 6
        }
    }
}
