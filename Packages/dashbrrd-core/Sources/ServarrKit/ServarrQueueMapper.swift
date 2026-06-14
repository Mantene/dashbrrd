import Foundation
import CoreModel

/// Maps Servarr queue record fields into the normalized `QueueState` + parses time-left.
enum ServarrQueueMapper {
    static func state(_ status: String?) -> QueueState {
        switch (status ?? "").lowercased() {
        case "downloading": .downloading
        case "paused": .paused
        case "queued", "delay", "downloadclientunavailable": .queued
        case "completed": .completed
        case "warning", "failed", "error": .error
        default: .unknown
        }
    }

    /// Parses Servarr's "HH:MM:SS" (or "MM:SS") time-left into seconds.
    static func parseTimeLeft(_ value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return seconds > 0 ? seconds : nil
    }
}
