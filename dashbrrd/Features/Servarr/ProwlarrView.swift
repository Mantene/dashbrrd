import SwiftUI

struct ProwlarrView: View {
    let instance: ServiceInstance
    @Environment(ConfigStore.self) private var configStore

    @State private var service: ProwlarrService?
    @State private var indexers: LoadState<[ProwlarrIndexer]> = .idle
    @State private var term = ""
    @State private var results: [ProwlarrSearchResult] = []
    @State private var searching = false

    var body: some View {
        AsyncStateView(state: indexers, retry: { Task { await loadIndexers() } }) { list in
            List {
                if !results.isEmpty || searching {
                    Section("Search Results") {
                        if searching { ProgressView() }
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title ?? "Untitled").font(.subheadline).lineLimit(2)
                                HStack(spacing: 10) {
                                    if let indexer = result.indexer { Text(indexer) }
                                    Text(Format.bytes(result.size))
                                    if let seeders = result.seeders { Text("S:\(seeders)") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Indexers (\(list.count))") {
                    ForEach(list) { indexer in
                        HStack {
                            Image(systemName: (indexer.enable ?? false) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle((indexer.enable ?? false) ? .green : .secondary)
                            Text(indexer.name ?? "Indexer \(indexer.id)")
                            Spacer()
                            if let proto = indexer.protocol {
                                Text(proto).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(instance.name)
        .searchable(text: $term, prompt: "Search indexers")
        .onSubmit(of: .search, runSearch)
        .task {
            if service == nil {
                service = configStore.credential(for: instance).map {
                    ProwlarrService(instance: instance, credential: $0)
                }
            }
            await loadIndexers()
        }
    }

    private func loadIndexers() async {
        guard let service else { indexers = .failed("No credentials saved."); return }
        indexers = .loading
        do { indexers = .loaded(try await service.indexers()) }
        catch { indexers = .failed(error.localizedDescription) }
    }

    private func runSearch() {
        guard let service else { return }
        searching = true
        Task {
            results = (try? await service.search(term)) ?? []
            searching = false
        }
    }
}

struct BazarrView: View {
    let instance: ServiceInstance
    @Environment(ConfigStore.self) private var configStore

    @State private var state: LoadState<(episodes: Int, movies: Int)> = .idle

    var body: some View {
        AsyncStateView(state: state, retry: { Task { await load() } }) { counts in
            List {
                Section("Wanted Subtitles") {
                    LabeledContent("Episodes", value: String(counts.episodes))
                    LabeledContent("Movies", value: String(counts.movies))
                }
            }
        }
        .navigationTitle(instance.name)
        .task { await load() }
    }

    private func load() async {
        guard let credential = configStore.credential(for: instance) else {
            state = .failed("No credentials saved."); return
        }
        state = .loading
        do {
            let counts = try await BazarrService(instance: instance, credential: credential).wantedCounts()
            state = .loaded(counts)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
