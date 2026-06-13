import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            ServicesView()
                .tabItem { Label("Services", systemImage: "rectangle.stack") }

            ActivityView()
                .tabItem { Label("Activity", systemImage: "arrow.up.arrow.down") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// Services browser. On iPad this renders as a sidebar + detail split; on iPhone the split view
/// collapses to a navigation stack automatically.
struct ServicesView: View {
    @Environment(ConfigStore.self) private var configStore
    @State private var selection: ServiceInstance?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if configStore.instances.isEmpty {
                    ContentUnavailableView(
                        "No Services",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Add a service from the Settings tab to get started.")
                    )
                } else {
                    ForEach(ServiceCategory.allCases) { category in
                        let items = configStore.instances.filter { category.contains($0.type) }
                        if !items.isEmpty {
                            Section(category.title) {
                                ForEach(items) { instance in
                                    NavigationLink(value: instance) {
                                        Label(instance.name, systemImage: instance.type.symbolName)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Services")
        } detail: {
            NavigationStack {
                if let selection {
                    ServiceHomeView(instance: selection)
                        .id(selection.id)
                } else {
                    ContentUnavailableView(
                        "Select a Service", systemImage: "hand.point.up.left",
                        description: Text("Choose a service to manage it.")
                    )
                }
            }
        }
    }
}

/// Routes an instance to the right management surface.
struct ServiceHomeView: View {
    let instance: ServiceInstance

    var body: some View {
        switch instance.type {
        case .sonarr, .radarr, .lidarr, .readarr:
            ServarrLibraryView(instance: instance)
        case .prowlarr:
            ProwlarrView(instance: instance)
        case .sabnzbd, .nzbget, .qbittorrent, .transmission:
            DownloadQueueView(instance: instance)
        case .bazarr:
            BazarrView(instance: instance)
        }
    }
}

enum ServiceCategory: String, CaseIterable, Identifiable {
    case media, indexers, downloads, subtitles
    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: "Media Libraries"
        case .indexers: "Indexers"
        case .downloads: "Download Clients"
        case .subtitles: "Subtitles"
        }
    }

    func contains(_ type: ServiceType) -> Bool {
        switch self {
        case .media: type == .sonarr || type == .radarr || type == .lidarr || type == .readarr
        case .indexers: type == .prowlarr
        case .downloads: type.isDownloadClient
        case .subtitles: type == .bazarr
        }
    }
}
