import SwiftUI
import CoreModel
import DesignSystem

/// The unified Calendar. Renders entries grouped by day, surfaces per-instance failures as
/// chips (without blanking the list), and supports pull-to-refresh.
public struct CalendarScreen: View {
    @State private var store: CalendarStore

    public init(store: CalendarStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading calendar…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded:
                content
            }
        }
        .navigationTitle("Calendar")
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    @ViewBuilder
    private var content: some View {
        let groups = store.groupedByDay
        List {
            if !store.failures.isEmpty {
                Section {
                    ForEach(store.failures) { failure in
                        Label("\(failure.displayName): \(failure.message)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }

            if groups.isEmpty {
                ContentUnavailableView(
                    "Nothing Scheduled",
                    systemImage: "calendar",
                    description: Text("No upcoming releases in the next 30 days.")
                )
            } else {
                ForEach(groups, id: \.day) { group in
                    Section(group.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.entries) { entry in
                            CalendarRow(entry: entry)
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: entry.serviceKind.symbolName)
                .foregroundStyle(entry.serviceKind.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.headline)
                if let subtitle = entry.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.airDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if entry.hasFile {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                        .accessibilityLabel("Downloaded")
                }
            }
        }
    }
}
