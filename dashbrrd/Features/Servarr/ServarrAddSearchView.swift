import SwiftUI

/// Lookup-and-add flow: search the *arr metadata provider, then add a result with a chosen
/// quality profile and root folder.
struct ServarrAddSearchView: View {
    let model: ServarrLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var results: [MediaSummary] = []
    @State private var searching = false
    @State private var error: String?
    @State private var adding: MediaSummary?

    var body: some View {
        NavigationStack {
            Group {
                if searching {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else if results.isEmpty {
                    ContentUnavailableView("Search to Add", systemImage: "magnifyingglass",
                                           description: Text("Find a title to add to \(model.instance.name)."))
                } else {
                    List(results, id: \.stableID) { item in
                        Button { adding = item } label: {
                            HStack {
                                MediaRow(item: item)
                                if item.isInLibrary {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                        .tint(.primary)
                        .disabled(item.isInLibrary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $term, prompt: "Search by title")
            .onSubmit(of: .search, runSearch)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { await model.ensureMetadata() }
            .sheet(item: $adding) { item in
                AddOptionsSheet(item: item, model: model) { dismiss() }
            }
        }
    }

    private func runSearch() {
        let query = term
        searching = true
        error = nil
        Task {
            do {
                results = try await model.lookup(query)
            } catch {
                self.error = error.localizedDescription
            }
            searching = false
        }
    }
}

private struct AddOptionsSheet: View {
    let item: MediaSummary
    let model: ServarrLibraryViewModel
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var profileId: Int?
    @State private var rootFolderPath: String?
    @State private var monitored = true
    @State private var searchNow = true
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { MediaRow(item: item) }

                Section("Options") {
                    Picker("Quality Profile", selection: $profileId) {
                        ForEach(model.profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    Picker("Root Folder", selection: $rootFolderPath) {
                        ForEach(model.rootFolders) { folder in
                            Text(folder.path).tag(Optional(folder.path))
                        }
                    }
                    Toggle("Monitored", isOn: $monitored)
                    Toggle("Search on add", isOn: $searchNow)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Add Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(busy || profileId == nil || rootFolderPath == nil)
                }
            }
            .overlay { if busy { ProgressView().controlSize(.large) } }
            .onAppear {
                profileId = profileId ?? model.profiles.first?.id
                rootFolderPath = rootFolderPath ?? model.rootFolders.first?.path
            }
        }
    }

    private func add() {
        guard let profileId, let rootFolderPath else { return }
        busy = true
        error = nil
        Task {
            do {
                try await model.add(
                    item, qualityProfileId: profileId, rootFolderPath: rootFolderPath,
                    monitored: monitored, searchNow: searchNow
                )
                await model.load()
                busy = false
                dismiss()
                onAdded()
            } catch {
                self.error = error.localizedDescription
                busy = false
            }
        }
    }
}
