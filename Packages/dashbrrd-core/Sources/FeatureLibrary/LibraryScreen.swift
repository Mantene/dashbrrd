import SwiftUI
import CoreModel
import DesignSystem

/// The Library: one selected instance at a time (picked from a menu), with a title filter —
/// large libraries are too unwieldy merged onto a single page.
public struct LibraryScreen: View {
    @State private var store: LibraryStore
    @State private var selected: MediaItem?
    @State private var addingMedia = false

    public init(store: LibraryStore) {
        _store = State(initialValue: store)
    }

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: DS.Spacing.md)]

    public var body: some View {
        Group {
            if store.instances.isEmpty {
                ContentUnavailableView("No Library", systemImage: "rectangle.stack",
                                       description: Text("Add a Sonarr or Radarr server to browse its library."))
            } else {
                content
            }
        }
        .navigationTitle(store.selected?.name ?? "Library")
        .toolbar {
            if store.instances.count > 1 {
                ToolbarItem(placement: .principal) { libraryPicker }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { addingMedia = true } label: { Label("Add Media", systemImage: "plus") }
            }
        }
        .searchable(text: $store.filterText, prompt: "Filter this library")
        .task { await store.loadInstances() }
        .sheet(item: $selected) { item in MediaDetailView(item: item, store: store) }
        .sheet(isPresented: $addingMedia) { AddMediaView(store: store.makeAddStore()) }
        .alert("Action Failed", isPresented: Binding(
            get: { store.actionError != nil }, set: { if !$0 { store.actionError = nil } }
        )) { Button("OK", role: .cancel) { store.actionError = nil } } message: { Text(store.actionError ?? "") }
    }

    private var libraryPicker: some View {
        Menu {
            Picker("Library", selection: $store.selected) {
                ForEach(store.instances) { instance in
                    Label(instance.name, systemImage: instance.kind.symbolName).tag(Optional(instance))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.selected?.name ?? "Library").font(.headline)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView("Loading library…")
        case let .failed(message):
            ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
        case .loaded:
            grid
        }
    }

    @ViewBuilder
    private var grid: some View {
        let items = store.visibleItems
        if items.isEmpty {
            if store.filterText.isEmpty {
                ContentUnavailableView("Empty Library", systemImage: "rectangle.stack",
                                       description: Text(store.failures.first.map { "\($0.displayName): \($0.message)" } ?? "Nothing here yet."))
            } else {
                ContentUnavailableView.search(text: store.filterText)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                    ForEach(items) { item in
                        Button { selected = item } label: { PosterCard(item: item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .overlay(alignment: .bottom) { countBadge(showing: items.count) }
        }
    }

    @ViewBuilder
    private func countBadge(showing: Int) -> some View {
        let total = store.totalCount
        let text = showing == total ? "\(total) items" : "\(showing) of \(total)"
        Text(text)
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, DS.Spacing.sm)
    }
}
