import SwiftUI

@MainActor
@Observable
final class DownloadQueueViewModel {
    let instance: ServiceInstance
    private let client: DownloadClient?

    var state: LoadState<[DownloadItem]> = .idle
    var actionError: String?

    init(instance: ServiceInstance, credential: AuthCredential?) {
        self.instance = instance
        self.client = credential.flatMap { DownloadClientFactory.make(for: instance, credential: $0) }
    }

    func load() async {
        guard let client else { state = .failed("No credentials saved."); return }
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await client.items()) }
        catch { state = .failed(error.localizedDescription) }
    }

    func toggle(_ item: DownloadItem) async {
        await perform { client in
            if item.isPaused {
                try await client.resume(item)
            } else {
                try await client.pause(item)
            }
        }
    }

    func delete(_ item: DownloadItem, deleteData: Bool) async {
        await perform { try await $0.delete(item, deleteData: deleteData) }
    }

    private func perform(_ work: @escaping (DownloadClient) async throws -> Void) async {
        guard let client else { return }
        do { try await work(client); await load() }
        catch { actionError = error.localizedDescription }
    }
}

struct DownloadQueueView: View {
    let instance: ServiceInstance
    @Environment(ConfigStore.self) private var configStore
    @State private var model: DownloadQueueViewModel?

    var body: some View {
        Group {
            if let model {
                AsyncStateView(state: model.state, retry: { Task { await model.load() } }) { items in
                    if items.isEmpty {
                        ContentUnavailableView("Queue Empty", systemImage: "tray",
                                               description: Text("Nothing is downloading right now."))
                    } else {
                        List(items) { item in
                            DownloadRow(item: item)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task { await model.toggle(item) }
                                    } label: {
                                        Label(item.isPaused ? "Resume" : "Pause",
                                              systemImage: item.isPaused ? "play.fill" : "pause.fill")
                                    }
                                    .tint(item.isPaused ? .green : .orange)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await model.delete(item, deleteData: false) }
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle(instance.name)
                .refreshable { await model.load() }
                .alert("Action failed", isPresented: Binding(
                    get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } }
                )) { Button("OK", role: .cancel) {} } message: { Text(model.actionError ?? "") }
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let vm = DownloadQueueViewModel(
                    instance: instance, credential: configStore.credential(for: instance)
                )
                model = vm
                await vm.load()
            }
        }
    }
}

struct DownloadRow: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.subheadline).lineLimit(2)
            ProgressView(value: item.progress)
                .tint(item.isPaused ? .secondary : .accentColor)
            HStack {
                Text(item.state).foregroundStyle(item.isPaused ? .secondary : .primary)
                Spacer()
                Text(Format.percent(item.progress))
                if !Format.rate(item.downloadRate).isEmpty {
                    Text(Format.rate(item.downloadRate))
                }
                if !Format.eta(item.etaSeconds).isEmpty {
                    Text(Format.eta(item.etaSeconds))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
