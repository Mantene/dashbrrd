import SwiftUI

@MainActor
@Observable
final class CalendarViewModel {
    var state: LoadState<[(day: Date, entries: [CalendarEntry])]> = .idle

    func load(_ store: ConfigStore) async {
        let pairs = store.enabledInstances
            .filter { $0.type == .sonarr || $0.type == .radarr }
            .compactMap { instance in store.credential(for: instance).map { (instance, $0) } }

        if case .loaded = state {} else { state = .loading }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()

        let all = await withTaskGroup(of: [CalendarEntry].self) { group -> [CalendarEntry] in
            for (instance, credential) in pairs {
                group.addTask {
                    (try? await CalendarService.fetch(
                        instance: instance, credential: credential, start: start, end: end
                    )) ?? []
                }
            }
            var entries: [CalendarEntry] = []
            for await result in group { entries.append(contentsOf: result) }
            return entries
        }

        let grouped = Dictionary(grouping: all) {
            Calendar.current.startOfDay(for: $0.date)
        }
        let sorted = grouped
            .map { (day: $0.key, entries: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day < $1.day }
        state = .loaded(sorted)
    }
}

struct CalendarView: View {
    @Environment(ConfigStore.self) private var configStore
    @State private var model = CalendarViewModel()

    var body: some View {
        NavigationStack {
            AsyncStateView(state: model.state, retry: { Task { await model.load(configStore) } }) { days in
                if days.isEmpty {
                    ContentUnavailableView("Nothing Scheduled", systemImage: "calendar",
                                           description: Text("Add Sonarr or Radarr to see upcoming releases."))
                } else {
                    List {
                        ForEach(days, id: \.day) { day in
                            Section(day.day.formatted(date: .complete, time: .omitted)) {
                                ForEach(day.entries) { entry in
                                    HStack(spacing: 12) {
                                        Image(systemName: entry.symbol).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.title).font(.subheadline)
                                            if !entry.subtitle.isEmpty {
                                                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .refreshable { await model.load(configStore) }
            .task { await model.load(configStore) }
        }
    }
}
