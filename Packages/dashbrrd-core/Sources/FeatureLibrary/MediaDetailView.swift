import SwiftUI
import CoreModel
import DesignSystem

/// Read + manage a single library item: poster, overview, monitor toggle, and a
/// confirmation-gated delete (with an explicit "also delete files" choice).
public struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    let store: LibraryStore

    @State private var confirmingDelete = false

    public init(item: MediaItem, store: LibraryStore) {
        self.item = item
        self.store = store
    }

    /// The live copy from the store (so the toggle reflects optimistic updates).
    private var current: MediaItem { store.currentItem(item.id) ?? item }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        PosterCard(item: current)
                            .frame(width: 100)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(current.displayTitle).font(.headline)
                            Label(current.serviceKind.displayName, systemImage: current.serviceKind.symbolName)
                                .font(.caption).foregroundStyle(current.serviceKind.accentColor)
                            if let subtitle = current.subtitle {
                                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let overview = current.overview, !overview.isEmpty {
                    Section("Overview") { Text(overview).font(.callout) }
                }

                Section {
                    Toggle("Monitored", isOn: Binding(
                        get: { current.monitored },
                        set: { newValue in Task { await store.setMonitored(current, monitored: newValue) } }
                    ))
                }

                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete from \(current.serviceKind.displayName)", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(current.title)
            .dsInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete \(current.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Remove from library", role: .destructive) {
                    Task { await store.delete(current, deleteFiles: false); dismiss() }
                }
                Button("Remove and delete files", role: .destructive) {
                    Task { await store.delete(current, deleteFiles: true); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("“Remove and delete files” permanently deletes the media files on the server.")
            }
        }
    }
}
