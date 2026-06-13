import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        InstancesListView()
                    } label: {
                        Label("Services", systemImage: "server.rack")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Self.appVersion)
                    Link(destination: URL(string: "https://github.com/Mantene/dashbrrd")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct InstancesListView: View {
    @Environment(ConfigStore.self) private var configStore
    @State private var editing: ServiceInstance?
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(configStore.instances) { instance in
                Button {
                    editing = instance
                } label: {
                    HStack {
                        Label(instance.name, systemImage: instance.type.symbolName)
                        Spacer()
                        Text(instance.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !instance.isEnabled {
                            Image(systemName: "pause.circle").foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                offsets.map { configStore.instances[$0] }.forEach(configStore.delete)
            }
            .onMove { configStore.move(fromOffsets: $0, toOffset: $1) }
        }
        .navigationTitle("Services")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .overlay {
            if configStore.instances.isEmpty {
                ContentUnavailableView(
                    "No Services", systemImage: "server.rack",
                    description: Text("Tap + to connect Sonarr, Radarr, a download client, and more.")
                )
            }
        }
        .sheet(isPresented: $isAdding) {
            InstanceEditView(existing: nil)
        }
        .sheet(item: $editing) { instance in
            InstanceEditView(existing: instance)
        }
    }
}
