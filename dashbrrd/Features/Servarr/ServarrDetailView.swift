import SwiftUI

struct ServarrDetailView: View {
    let item: MediaSummary
    let model: ServarrLibraryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var monitored: Bool
    @State private var showDeleteDialog = false
    @State private var busy = false

    init(item: MediaSummary, model: ServarrLibraryViewModel) {
        self.item = item
        self.model = model
        _monitored = State(initialValue: item.monitored)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    PosterImage(url: item.posterURL, width: 110, height: 165)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(.title2.bold())
                        if let year = item.year {
                            Text(String(year)).foregroundStyle(.secondary)
                        }
                        if let status = item.status {
                            Text(status.capitalized).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let size = item.sizeOnDisk, size > 0 {
                            Label(Format.bytes(size), systemImage: "internaldrive")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Toggle("Monitored", isOn: $monitored)
                    .onChange(of: monitored) { _, newValue in
                        Task { busy = true; await model.setMonitored(item, newValue); busy = false }
                    }

                Button {
                    Task { busy = true; await model.search(item); busy = false }
                } label: {
                    Label("Search for Releases", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)

                Button(role: .destructive) {
                    showDeleteDialog = true
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let overview = item.overview, !overview.isEmpty {
                    Text("Overview").font(.headline)
                    Text(overview).font(.body).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if busy { ProgressView().controlSize(.large) } }
        .confirmationDialog("Remove \(item.title)?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Remove and Delete Files", role: .destructive) { remove(deleteFiles: true) }
            Button("Remove, Keep Files") { remove(deleteFiles: false) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func remove(deleteFiles: Bool) {
        Task {
            busy = true
            await model.delete(item, deleteFiles: deleteFiles)
            busy = false
            dismiss()
        }
    }
}
