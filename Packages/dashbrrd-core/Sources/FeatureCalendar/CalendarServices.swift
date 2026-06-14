import Foundation
import CoreModel

/// One instance's failure during a fan-out load — surfaced as a per-instance chip rather
/// than blanking the whole aggregated view. Partial failure is first-class by design.
public struct InstanceFailure: Sendable, Identifiable, Hashable {
    public var id: InstanceID
    public var displayName: String
    public var message: String

    public init(id: InstanceID, displayName: String, message: String) {
        self.id = id
        self.displayName = displayName
        self.message = message
    }
}

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
