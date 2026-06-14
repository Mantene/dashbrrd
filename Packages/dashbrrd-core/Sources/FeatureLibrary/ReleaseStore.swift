import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for an interactive release search of one media item.
@MainActor
@Observable
public final class ReleaseStore {
    public let item: MediaItem
    public private(set) var state: LoadState<[Release]> = .idle
    /// guids currently being grabbed (for per-row spinners).
    public private(set) var grabbing: Set<String> = []
    /// guids successfully grabbed this session (for a checkmark).
    public private(set) var grabbed: Set<String> = []
    public var grabError: String?

    private let searcher: any ReleaseSearching
    private let grabber: any ReleaseGrabbing

    public init(item: MediaItem, searcher: any ReleaseSearching, grabber: any ReleaseGrabbing) {
        self.item = item
        self.searcher = searcher
        self.grabber = grabber
    }

    public func search() async {
        state = .loading
        do {
            let releases = try await searcher.search(item)
            // Approved + allowed first, then by seeders/size desc-ish via title stability.
            state = .loaded(releases.sorted { lhs, rhs in
                if lhs.downloadAllowed != rhs.downloadAllowed { return lhs.downloadAllowed }
                if lhs.rejected != rhs.rejected { return !lhs.rejected }
                return (lhs.seeders ?? 0) > (rhs.seeders ?? 0)
            })
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func grab(_ release: Release) async {
        grabbing.insert(release.guid)
        defer { grabbing.remove(release.guid) }
        do {
            try await grabber.grab(release)
            grabbed.insert(release.guid)
        } catch {
            grabError = "Couldn't grab \(release.title): \(error.localizedDescription)"
        }
    }

    public func isGrabbing(_ release: Release) -> Bool { grabbing.contains(release.guid) }
    public func isGrabbed(_ release: Release) -> Bool { grabbed.contains(release.guid) }
}
