import SwiftUI

struct DashStat: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: String
}

struct InstanceSummary: Identifiable, Sendable {
    let instance: ServiceInstance
    var id: UUID { instance.id }
    let reachable: Bool
    let headline: String
    let stats: [DashStat]
}

@MainActor
@Observable
final class DashboardViewModel {
    var state: LoadState<[InstanceSummary]> = .idle

    func load(_ store: ConfigStore) async {
        let pairs = store.enabledInstances
            .compactMap { instance in store.credential(for: instance).map { (instance, $0) } }
        if case .loaded = state {} else { state = .loading }

        var summaries = await withTaskGroup(of: InstanceSummary.self) { group -> [InstanceSummary] in
            for (instance, credential) in pairs {
                group.addTask { await Self.summary(instance, credential) }
            }
            var acc: [InstanceSummary] = []
            for await result in group { acc.append(result) }
            return acc
        }
        summaries.sort { $0.instance.name.localizedCaseInsensitiveCompare($1.instance.name) == .orderedAscending }
        state = .loaded(summaries)
    }

    nonisolated private static func summary(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> InstanceSummary {
        switch instance.type {
        case .sonarr, .radarr, .lidarr, .readarr:
            return await servarr(instance, credential)
        case .prowlarr:
            return await prowlarr(instance, credential)
        case .sabnzbd, .nzbget, .qbittorrent, .transmission:
            return await download(instance, credential)
        case .bazarr:
            return await bazarr(instance, credential)
        }
    }

    nonisolated private static func servarr(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> InstanceSummary {
        let client = ServarrClient(instance: instance, credential: credential)
        guard let status = try? await client.systemStatus() else {
            return unreachable(instance)
        }
        let queue = (try? await client.queue())?.count ?? 0
        let health = (try? await client.health())?.filter {
            ($0.type == "warning" || $0.type == "error")
        }.count ?? 0
        return InstanceSummary(
            instance: instance, reachable: true,
            headline: status.version.map { "v\($0)" } ?? "Connected",
            stats: [DashStat(label: "Queue", value: String(queue)),
                    DashStat(label: "Warnings", value: String(health))]
        )
    }

    nonisolated private static func prowlarr(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> InstanceSummary {
        let service = ProwlarrService(instance: instance, credential: credential)
        guard let status = try? await service.systemStatus() else { return unreachable(instance) }
        let indexers = (try? await service.indexers())?.count ?? 0
        return InstanceSummary(
            instance: instance, reachable: true,
            headline: status.version.map { "v\($0)" } ?? "Connected",
            stats: [DashStat(label: "Indexers", value: String(indexers))]
        )
    }

    nonisolated private static func download(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> InstanceSummary {
        guard let client = DownloadClientFactory.make(for: instance, credential: credential),
              let items = try? await client.items() else { return unreachable(instance) }
        let active = items.filter { !$0.isPaused && $0.progress < 1 }.count
        let rate = items.compactMap(\.downloadRate).reduce(0, +)
        return InstanceSummary(
            instance: instance, reachable: true,
            headline: rate > 0 ? Format.rate(rate) : "Idle",
            stats: [DashStat(label: "Active", value: String(active)),
                    DashStat(label: "Total", value: String(items.count))]
        )
    }

    nonisolated private static func bazarr(
        _ instance: ServiceInstance, _ credential: AuthCredential
    ) async -> InstanceSummary {
        let service = BazarrService(instance: instance, credential: credential)
        guard let counts = try? await service.wantedCounts() else { return unreachable(instance) }
        return InstanceSummary(
            instance: instance, reachable: true, headline: "Connected",
            stats: [DashStat(label: "Wanted Eps", value: String(counts.episodes)),
                    DashStat(label: "Wanted Films", value: String(counts.movies))]
        )
    }

    nonisolated private static func unreachable(_ instance: ServiceInstance) -> InstanceSummary {
        InstanceSummary(instance: instance, reachable: false, headline: "Unreachable", stats: [])
    }
}

struct DashboardView: View {
    @Environment(ConfigStore.self) private var configStore
    @State private var model = DashboardViewModel()

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            AsyncStateView(state: model.state, retry: { Task { await model.load(configStore) } }) { summaries in
                if summaries.isEmpty {
                    ContentUnavailableView("No Services", systemImage: "square.grid.2x2",
                                           description: Text("Add a service in Settings to see it here."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(summaries) { summary in
                                DashboardCard(summary: summary)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await model.load(configStore) }
            .task { await model.load(configStore) }
        }
    }
}

struct DashboardCard: View {
    let summary: InstanceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: summary.instance.type.symbolName)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Circle()
                    .fill(summary.reachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            Text(summary.instance.name).font(.headline).lineLimit(1)
            Text(summary.headline).font(.caption).foregroundStyle(.secondary)

            if !summary.stats.isEmpty {
                Divider()
                ForEach(summary.stats) { stat in
                    HStack {
                        Text(stat.label).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(stat.value).font(.caption.bold())
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
