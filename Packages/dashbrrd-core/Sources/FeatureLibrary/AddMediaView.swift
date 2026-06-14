import SwiftUI
import CoreModel
import DesignSystem

/// Add new media: pick a Sonarr/Radarr instance, search, then choose quality profile + root
/// folder and add. Adding is an explicit per-result action.
public struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: AddMediaStore
    @State private var optionsFor: MediaLookupItem?

    public init(store: AddMediaStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.targets.isEmpty {
                    ContentUnavailableView("No Sonarr or Radarr", systemImage: "plus.circle",
                                           description: Text("Add a Sonarr or Radarr server in Settings first."))
                } else {
                    results
                }
            }
            .navigationTitle("Add Media")
            .dsInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if store.targets.count > 1 {
                    ToolbarItem(placement: .principal) { targetPicker }
                }
            }
            .searchable(text: $store.term, prompt: "Search to add…")
            .onSubmit(of: .search) { Task { await store.search() } }
            .task { await store.loadTargets() }
            .sheet(item: $optionsFor) { item in
                AddOptionsSheet(store: store, item: item)
            }
            .alert("Add Failed", isPresented: Binding(
                get: { store.addError != nil }, set: { if !$0 { store.addError = nil } }
            )) { Button("OK", role: .cancel) { store.addError = nil } } message: { Text(store.addError ?? "") }
        }
    }

    private var targetPicker: some View {
        Picker("Instance", selection: $store.selectedTarget) {
            ForEach(store.targets) { target in
                Text(target.name).tag(Optional(target))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: store.selectedTarget) { Task { await store.search() } }
    }

    @ViewBuilder
    private var results: some View {
        switch store.results {
        case .idle:
            ContentUnavailableView("Search to Add", systemImage: "magnifyingglass",
                                   description: Text("Find a series or movie to add to \(store.selectedTarget?.name ?? "your server")."))
        case .loading:
            ProgressView("Searching…")
        case let .failed(message):
            ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(message))
        case let .loaded(items):
            if items.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Nothing matched “\(store.term)”."))
            } else {
                List(items) { item in AddResultRow(item: item, store: store) { optionsFor = item } }
            }
        }
    }
}

private struct AddResultRow: View {
    let item: MediaLookupItem
    let store: AddMediaStore
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: item.serviceKind.symbolName).foregroundStyle(item.serviceKind.accentColor)
            }
            .frame(width: 44, height: 66).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle).font(.subheadline).lineLimit(2)
                if let overview = item.overview { Text(overview).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            if store.isAdded(item) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if store.isAdding(item) {
                ProgressView()
            } else {
                Button(action: onAdd) { Image(systemName: "plus.circle.fill") }.buttonStyle(.borderless)
            }
        }
    }
}

/// Quality profile + root folder + monitor/search choices for adding one item.
private struct AddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: AddMediaStore
    let item: MediaLookupItem

    @State private var qualityProfileID: Int?
    @State private var rootFolderPath: String?
    @State private var monitored = true
    @State private var searchOnAdd = true

    var body: some View {
        NavigationStack {
            Form {
                if let options = store.options {
                    Picker("Quality Profile", selection: $qualityProfileID) {
                        ForEach(options.qualityProfiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    Picker("Root Folder", selection: $rootFolderPath) {
                        ForEach(options.rootFolders) { folder in
                            Text(folder.path).tag(Optional(folder.path))
                        }
                    }
                    Toggle("Monitored", isOn: $monitored)
                    Toggle("Search on add", isOn: $searchOnAdd)
                } else if let error = store.optionsError {
                    Text(error).foregroundStyle(.orange)
                } else {
                    ProgressView("Loading options…")
                }
            }
            .navigationTitle(item.title)
            .dsInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let qp = qualityProfileID, let root = rootFolderPath else { return }
                        Task { await store.add(item, qualityProfileID: qp, rootFolderPath: root, monitored: monitored, searchOnAdd: searchOnAdd); dismiss() }
                    }
                    .disabled(qualityProfileID == nil || rootFolderPath == nil)
                }
            }
            .task {
                await store.ensureOptions()
                qualityProfileID = qualityProfileID ?? store.options?.qualityProfiles.first?.id
                rootFolderPath = rootFolderPath ?? store.options?.rootFolders.first?.path
            }
        }
    }
}
