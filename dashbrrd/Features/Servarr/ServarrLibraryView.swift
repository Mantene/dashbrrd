import SwiftUI

struct ServarrLibraryView: View {
    let instance: ServiceInstance
    @Environment(ConfigStore.self) private var configStore

    @State private var model: ServarrLibraryViewModel?
    @State private var search = ""
    @State private var isAdding = false

    var body: some View {
        Group {
            if let model {
                AsyncStateView(state: model.state, retry: { Task { await model.load() } }) { items in
                    libraryList(items, model: model)
                }
                .navigationTitle(instance.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isAdding = true } label: { Image(systemName: "plus") }
                    }
                }
                .searchable(text: $search, prompt: "Filter library")
                .refreshable { await model.load() }
                .sheet(isPresented: $isAdding) {
                    ServarrAddSearchView(model: model)
                }
                .alert("Action failed", isPresented: Binding(
                    get: { model.actionError != nil },
                    set: { if !$0 { model.actionError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.actionError ?? "")
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let vm = ServarrLibraryViewModel(
                    instance: instance, credential: configStore.credential(for: instance)
                )
                model = vm
                await vm.load()
                await vm.ensureMetadata()
            }
        }
    }

    @ViewBuilder
    private func libraryList(_ items: [MediaSummary], model: ServarrLibraryViewModel) -> some View {
        let filtered = search.isEmpty
            ? items
            : items.filter { $0.title.localizedCaseInsensitiveContains(search) }

        if filtered.isEmpty {
            ContentUnavailableView(
                "Empty Library", systemImage: instance.type.symbolName,
                description: Text("Tap + to add your first title.")
            )
        } else {
            List(filtered, id: \.stableID) { item in
                NavigationLink {
                    ServarrDetailView(item: item, model: model)
                } label: {
                    MediaRow(item: item)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct MediaRow: View {
    let item: MediaSummary

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: item.posterURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(2)
                if let year = item.year {
                    Text(String(year)).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: item.monitored ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(item.monitored ? Color.accentColor : .secondary)
                    if let size = item.sizeOnDisk, size > 0 {
                        Text(Format.bytes(size)).font(.caption).foregroundStyle(.secondary)
                    }
                    if let status = item.status {
                        Text(status.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
