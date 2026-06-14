import SwiftUI
import CoreModel
import DesignSystem

/// The unified Queue: merged Servarr + download-client items with progress, speed, and ETA.
/// Download-client items get inline pause/resume/remove (optimistic); Servarr items are read-only.
public struct QueueScreen: View {
    @State private var store: QueueStore
    @State private var manualImporting = false

    public init(store: QueueStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading queue…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded:
                content
            }
        }
        .navigationTitle("Queue")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { manualImporting = true } label: { Label("Manual Import", systemImage: "square.and.arrow.down") }
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(isPresented: $manualImporting) {
            ManualImportView(store: store.makeManualImportStore())
        }
        .alert("Action Failed", isPresented: Binding(
            get: { store.actionError != nil },
            set: { if !$0 { store.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { store.actionError = nil }
        } message: {
            Text(store.actionError ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        let items = store.state.value ?? []
        if items.isEmpty && store.failures.isEmpty {
            ContentUnavailableView(
                "Queue Empty",
                systemImage: "tray",
                description: Text("Nothing is downloading right now.")
            )
        } else {
            List {
                ForEach(store.failures) { failure in
                    Label("\(failure.displayName): \(failure.message)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.footnote)
                }
                ForEach(items) { item in
                    QueueRow(item: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if store.canControl(item) {
                                Button(role: .destructive) {
                                    Task { await store.remove(item, deleteData: false) }
                                } label: { Label("Remove", systemImage: "trash") }

                                if item.isPaused {
                                    Button { Task { await store.resume(item) } }
                                        label: { Label("Resume", systemImage: "play.fill") }
                                        .tint(.green)
                                } else {
                                    Button { Task { await store.pause(item) } }
                                        label: { Label("Pause", systemImage: "pause.fill") }
                                        .tint(.orange)
                                }
                            }
                        }
                }
            }
        }
    }
}

private struct QueueRow: View {
    let item: QueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: item.serviceKind.symbolName)
                    .foregroundStyle(item.serviceKind.accentColor)
                Text(item.name).font(.subheadline).lineLimit(1)
                Spacer()
                Text(item.state.label).font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: item.progress)
                .tint(item.isPaused ? .orange : item.serviceKind.accentColor)
            HStack {
                Text("\(Int(item.progress * 100))%")
                if item.speedBytesPerSec > 0 {
                    Text("· \(byteRate(item.speedBytesPerSec))")
                }
                Spacer()
                if let eta = item.etaSeconds {
                    Text(etaText(eta))
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func byteRate(_ bytesPerSec: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytesPerSec, countStyle: .binary) + "/s"
    }

    private func etaText(_ seconds: Int) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute, .second]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f.string(from: TimeInterval(seconds)) ?? "—"
    }
}

extension QueueState {
    var label: String {
        switch self {
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .queued: "Queued"
        case .completed: "Seeding"
        case .stalled: "Stalled"
        case .error: "Error"
        case .unknown: "—"
        }
    }
}
