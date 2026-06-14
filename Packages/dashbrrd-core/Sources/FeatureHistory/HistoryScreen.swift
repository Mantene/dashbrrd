import SwiftUI
import CoreModel
import DesignSystem

/// Activity feed: merged history across services, newest first, with load-more paging.
public struct HistoryScreen: View {
    @State private var store: HistoryStore

    public init(store: HistoryStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading activity…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case let .loaded(records):
                content(records)
            }
        }
        .navigationTitle("Activity")
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    @ViewBuilder
    private func content(_ records: [HistoryRecord]) -> some View {
        if records.isEmpty && store.failures.isEmpty {
            ContentUnavailableView("No Activity", systemImage: "clock.arrow.circlepath",
                                   description: Text("Grabs, imports, and failures will show here."))
        } else {
            List {
                ForEach(store.failures) { failure in
                    Label("\(failure.displayName): \(failure.message)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.footnote)
                }
                ForEach(records) { record in
                    HistoryRow(record: record)
                }
                if store.hasMore {
                    HStack {
                        Spacer()
                        if store.isLoadingMore { ProgressView() } else { Text("Load more…").foregroundStyle(.tint) }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await store.loadMore() } }
                    .task { await store.loadMore() } // auto-load when it scrolls into view
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let record: HistoryRecord

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: record.eventType.symbolName)
                .foregroundStyle(record.eventType.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).font(.subheadline).lineLimit(2)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: record.serviceKind.symbolName)
                        .foregroundStyle(record.serviceKind.accentColor)
                    Text(record.eventType.label)
                    if let quality = record.quality { Text("· \(quality)") }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.date.formatted(.relative(presentation: .numeric)))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

extension HistoryRecord.EventType {
    var label: String {
        switch self {
        case .grabbed: "Grabbed"
        case .imported: "Imported"
        case .failed: "Failed"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .ignored: "Ignored"
        case .unknown: "Event"
        }
    }

    var symbolName: String {
        switch self {
        case .grabbed: "arrow.down.circle"
        case .imported: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .deleted: "trash"
        case .renamed: "pencil"
        case .ignored: "minus.circle"
        case .unknown: "circle"
        }
    }

    var tint: Color {
        switch self {
        case .grabbed: .blue
        case .imported: .green
        case .failed: .red
        case .deleted: .secondary
        case .renamed: .orange
        case .ignored: .secondary
        case .unknown: .secondary
        }
    }
}
