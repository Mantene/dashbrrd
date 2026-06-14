import SwiftUI
import CoreModel
import DesignSystem

/// The Library: read-only poster grids grouped per service (a movies+episodes wall is noise),
/// reusing the shared `PosterCard`. Per-instance failures surface as chips.
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
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading library…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded:
                content
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingMedia = true } label: { Label("Add Media", systemImage: "plus") }
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(item: $selected) { item in
            MediaDetailView(item: item, store: store)
        }
        .sheet(isPresented: $addingMedia) {
            AddMediaView(store: store.makeAddStore())
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
        let groups = store.groupedByService
        if groups.isEmpty && store.failures.isEmpty {
            ContentUnavailableView(
                "Empty Library",
                systemImage: "rectangle.stack",
                description: Text("Add a Sonarr or Radarr server to browse its library.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(store.failures) { failure in
                        Label("\(failure.displayName): \(failure.message)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.footnote)
                            .padding(.horizontal, DS.Spacing.md)
                    }

                    ForEach(groups, id: \.kind) { group in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Label(group.kind.displayName, systemImage: group.kind.symbolName)
                                    .font(.headline)
                                    .foregroundStyle(group.kind.accentColor)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, DS.Spacing.md)

                            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                                ForEach(group.items) { item in
                                    Button { selected = item } label: {
                                        PosterCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
        }
    }
}
