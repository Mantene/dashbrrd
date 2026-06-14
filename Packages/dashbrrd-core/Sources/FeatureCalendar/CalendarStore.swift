import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for the unified Calendar. Holds a `LoadState` plus any
/// per-instance failures, so the view can show entries and error chips simultaneously.
@MainActor
@Observable
public final class CalendarStore {
    public private(set) var state: LoadState<[CalendarEntry]> = .idle
    public private(set) var failures: [InstanceFailure] = []

    private let loader: any CalendarLoading

    public init(loader: any CalendarLoading) {
        self.loader = loader
    }

    /// Default window: today through 30 days out (the common "what's coming up" view).
    public static func defaultRange(now: Date = Date()) -> DateInterval {
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? now
        return DateInterval(start: start, end: end)
    }

    public func load(range: DateInterval? = nil) async {
        if state.value == nil { state = .loading }
        let result = await loader.loadCalendar(range ?? Self.defaultRange())
        failures = result.failures
        state = .loaded(result.entries)
    }

    /// Entries grouped by calendar day, sorted ascending — ready for a sectioned list.
    public var groupedByDay: [(day: Date, entries: [CalendarEntry])] {
        guard let entries = state.value else { return [] }
        let groups = Dictionary(grouping: entries) {
            Calendar.current.startOfDay(for: $0.airDate)
        }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.airDate < $1.airDate }) }
    }
}
