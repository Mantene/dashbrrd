import SwiftUI

struct ActivityRow: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let progress: Double
    let isPaused: Bool
}

struct ActivityGroup: Identifiable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let rows: [ActivityRow]
}

@MainActor
@Observable
final class ActivityViewModel {
    var state: LoadState<[ActivityGroup]> = .idle

    func load(_ store: ConfigStore) async {
        let servarr = pairs(store, where: { $0.isServarr && $0 != .prowlarr })
        let downloads = pairs(store, where: { $0.isDownloadClient })
        if case .loaded = state {} else { state = .loading }

        var groups = await withTaskGroup(of: ActivityGroup?.self) { group -> [ActivityGroup] in
            for (instance, credential) in servarr {
                group.addTask { await Self.servarrGroup(instance, credential) }
            }
            for (instance, credential) in downloads {
                group.addTask { await Self.downloadGroup(instance, credential) }
            }
            var accumulated: [ActivityGroup] = []
            for await result in group where result != nil { accumulated.append(result!) }
            return accumulated
        }
        groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        state = .loaded(groups)
    }

    private func pairs(
        _ store: ConfigStore, where predicate: (ServiceType) -> Bool
    ) -> [(ServiceInstance, AuthCredential)] {
        store.enabledInstances
            .filter { predicate($0.type) }
            .compactMap { instance in store.credential(for: instance).map { (instance, $0) } }
    }

    nonisolated private static func servarrGroup(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> ActivityGroup? {
        let client = ServarrClient(instance: instance, credential: credential)
        guard let queue = try? await client.queue(), !queue.isEmpty else { return nil }
        let rows = queue.map {
            ActivityRow(
                id: "\(instance.id)-\($0.id)",
                title: $0.title ?? "Item",
                detail: ($0.trackedDownloadState ?? $0.status ?? "").capitalized,
                progress: $0.progressFraction,
                isPaused: false
            )
        }
        return ActivityGroup(id: instance.id.uuidString, name: instance.name,
                             symbol: instance.type.symbolName, rows: rows)
    }

    nonisolated private static func downloadGroup(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> ActivityGroup? {
        guard let client = DownloadClientFactory.make(for: instance, credential: credential),
              let items = try? await client.items(), !items.isEmpty else { return nil }
        let rows = items.map {
            ActivityRow(id: "\(instance.id)-\($0.id)", title: $0.name,
                        detail: $0.state, progress: $0.progress, isPaused: $0.isPaused)
        }
        return ActivityGroup(id: instance.id.uuidString, name: instance.name,
                             symbol: instance.type.symbolName, rows: rows)
    }
}

struct ActivityView: View {
    @Environment(ConfigStore.self) private var configStore
    @State private var model = ActivityViewModel()

    var body: some View {
        NavigationStack {
            AsyncStateView(state: model.state, retry: { Task { await model.load(configStore) } }) { groups in
                if groups.isEmpty {
                    ContentUnavailableView("Nothing Active", systemImage: "moon.zzz",
                                           description: Text("No downloads or queued items right now."))
                } else {
                    List {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.rows) { row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(row.title).font(.subheadline).lineLimit(2)
                                        ProgressView(value: row.progress)
                                            .tint(row.isPaused ? .secondary : .accentColor)
                                        HStack {
                                            Text(row.detail)
                                            Spacer()
                                            Text(Format.percent(row.progress))
                                        }
                                        .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            } header: {
                                Label(group.name, systemImage: group.symbol)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .refreshable { await model.load(configStore) }
            .task { await model.load(configStore) }
        }
    }
}
