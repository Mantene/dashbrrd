import Foundation
import CoreModel

// `InstanceFailure` now lives in `CoreModel` (shared by Calendar + Health aggregation).

/// The result of aggregating calendars across every calendar-capable instance: the merged
/// entries plus any per-instance failures (both can be non-empty at once).
public struct CalendarResult: Sendable {
    public var entries: [CalendarEntry]
    public var failures: [InstanceFailure]

    public init(entries: [CalendarEntry], failures: [InstanceFailure]) {
        self.entries = entries
        self.failures = failures
    }
}

/// Loads + merges calendars across instances. Implemented by `AppCore.CalendarAggregator`.
public protocol CalendarLoading: Sendable {
    func loadCalendar(_ range: DateInterval) async -> CalendarResult
}
