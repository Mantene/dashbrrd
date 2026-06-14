import SwiftUI
import Observation
import CoreModel
import DesignSystem
import FeatureCalendar
import FeatureHealth

/// Cross-service overview store: pulls a health summary and the next few calendar items in
/// parallel. Lives in AppCore because it composes multiple features (the plan's rule:
/// cross-feature coordination lives only in AppCore).
@MainActor
@Observable
public final class DashboardStore {
    public private(set) var upcoming: [CalendarEntry] = []
    public private(set) var problems: [HealthCheck] = []
    public private(set) var isLoading = false

    private let calendarLoader: any CalendarLoading
    private let healthLoader: any HealthLoading

    init(calendarLoader: any CalendarLoading, healthLoader: any HealthLoading) {
        self.calendarLoader = calendarLoader
        self.healthLoader = healthLoader
    }

    public func load() async {
        isLoading = true
        async let calendar = calendarLoader.loadCalendar(CalendarStore.defaultRange())
        async let health = healthLoader.loadHealth()
        let (cal, hea) = await (calendar, health)
        upcoming = Array(cal.entries.prefix(5))
        problems = hea.checks.filter { $0.severity == .warning || $0.severity == .error }
        isLoading = false
    }
}

/// The at-a-glance overview: health summary (with a link to the full Health view) and the
/// next handful of calendar items across all services.
struct DashboardScreen: View {
    @State private var store: DashboardStore
    let healthStore: HealthStore

    init(store: DashboardStore, healthStore: HealthStore) {
        _store = State(initialValue: store)
        self.healthStore = healthStore
    }

    var body: some View {
        List {
            Section("Health") {
                NavigationLink {
                    HealthScreen(store: healthStore)
                } label: {
                    Label {
                        Text(store.problems.isEmpty ? "All clear" : "\(store.problems.count) issue\(store.problems.count == 1 ? "" : "s")")
                    } icon: {
                        Image(systemName: store.problems.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(store.problems.isEmpty ? .green : .orange)
                    }
                }
            }

            Section("Upcoming") {
                if store.upcoming.isEmpty {
                    Text(store.isLoading ? "Loading…" : "Nothing scheduled soon.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.upcoming) { entry in
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: entry.serviceKind.symbolName)
                                .foregroundStyle(entry.serviceKind.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title).font(.subheadline)
                                if let subtitle = entry.subtitle {
                                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(entry.airDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
        .task { await store.load() }
        .refreshable { await store.load() }
    }
}
