import SwiftUI
import CoreModel
import DesignSystem

/// Settings root: lists configured servers and hosts the add-server flow. The store is
/// injected by `AppCore` so this view stays previewable with a fake.
public struct SettingsScreen: View {
    @Bindable var store: SettingsStore
    @State private var showingAdd = false

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        List {
            if store.servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a Sonarr server to get started.")
                )
            } else {
                Section("Servers") {
                    ForEach(store.servers) { server in
                        ServerRow(server: server)
                    }
                    .onDelete { indexSet in
                        for index in indexSet { store.delete(store.servers[index]) }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.resetTest()
                    showingAdd = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddServerView(store: store)
        }
        .onAppear { store.refresh() }
    }
}

private struct ServerRow: View {
    let server: ServerConfig

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: server.kind.symbolName)
                .foregroundStyle(server.kind.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName).font(.headline)
                Text(urlSummary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if server.isPlaintext {
                Image(systemName: "lock.open").foregroundStyle(.orange)
                    .accessibilityLabel("Not encrypted")
            }
        }
    }

    private var urlSummary: String {
        var s = "\(server.scheme)://\(server.host)"
        if let port = server.port { s += ":\(port)" }
        if let basePath = server.basePath, !basePath.isEmpty { s += basePath }
        return s
    }
}
