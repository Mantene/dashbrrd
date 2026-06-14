import SwiftUI
import CoreModel
import DesignSystem

/// Interactive release results for a media item. Each row shows indexer/size/seeders/quality
/// and any rejection reasons; grab is confirmation-gated (it adds a real download).
public struct ReleaseListView: View {
    @State private var store: ReleaseStore
    @State private var confirming: Release?

    public init(store: ReleaseStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle, .loading:
                    ProgressView("Searching indexers…")
                case let .failed(message):
                    ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(message))
                case let .loaded(releases):
                    if releases.isEmpty {
                        ContentUnavailableView("No Releases", systemImage: "magnifyingglass",
                                               description: Text("No results from your indexers."))
                    } else {
                        List(releases) { release in ReleaseRow(release: release, store: store) { confirming = release } }
                    }
                }
            }
            .navigationTitle("Releases")
            .dsInlineNavigationTitle()
            .task { await store.search() }
            .confirmationDialog(
                "Grab this release?",
                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                titleVisibility: .visible
            ) {
                if let release = confirming {
                    Button("Send to download client") {
                        Task { await store.grab(release) }
                        confirming = nil
                    }
                    Button("Cancel", role: .cancel) { confirming = nil }
                }
            } message: {
                Text(confirming?.title ?? "")
            }
            .alert("Grab Failed", isPresented: Binding(
                get: { store.grabError != nil }, set: { if !$0 { store.grabError = nil } }
            )) {
                Button("OK", role: .cancel) { store.grabError = nil }
            } message: { Text(store.grabError ?? "") }
        }
    }
}

private struct ReleaseRow: View {
    let release: Release
    let store: ReleaseStore
    let onGrab: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(release.title).font(.caption).lineLimit(2)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: release.isUsenet ? "newspaper" : "arrow.up.arrow.down")
                    Text(release.indexer)
                    Text("· \(ByteCountFormatter.string(fromByteCount: release.sizeBytes, countStyle: .binary))")
                    if let seeders = release.seeders { Text("· \(seeders) seed") }
                    if let quality = release.quality { Text("· \(quality)") }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if release.rejected, let reason = release.rejections.first {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(.orange).lineLimit(1)
                }
            }
            Spacer()
            grabControl
        }
    }

    @ViewBuilder
    private var grabControl: some View {
        if store.isGrabbed(release) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if store.isGrabbing(release) {
            ProgressView()
        } else {
            Button(action: onGrab) {
                Image(systemName: "arrow.down.circle\(release.downloadAllowed ? ".fill" : "")")
            }
            .buttonStyle(.borderless)
            .tint(release.downloadAllowed ? .accentColor : .secondary)
        }
    }
}
