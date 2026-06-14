import SwiftUI
import CoreModel
import DesignSystem

/// Manual import: pick a Sonarr/Radarr instance, pick a download, review the files Servarr
/// detected, and import the good ones. Re-mapping to a different episode/movie is not yet
/// supported — files Servarr couldn't map are shown with their rejection reasons, disabled.
public struct ManualImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: ManualImportStore

    public init(store: ManualImportStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.targets.isEmpty {
                    ContentUnavailableView("Nothing to Import", systemImage: "square.and.arrow.down",
                                           description: Text("Add a Sonarr or Radarr server first."))
                } else {
                    downloadsList
                }
            }
            .navigationTitle("Manual Import")
            .dsInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if store.targets.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Picker("Instance", selection: $store.selectedTarget) {
                            ForEach(store.targets) { Text($0.name).tag(Optional($0)) }
                        }.pickerStyle(.menu)
                    }
                }
            }
            .navigationDestination(for: QueueItem.self) { download in
                CandidatesView(store: store, download: download)
            }
            .task { await store.loadTargets() }
        }
    }

    @ViewBuilder
    private var downloadsList: some View {
        switch store.downloads {
        case .idle, .loading:
            ProgressView("Loading downloads…")
        case let .failed(message):
            ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
        case let .loaded(items):
            if items.isEmpty {
                ContentUnavailableView("Queue Empty", systemImage: "tray",
                                       description: Text("No active downloads to import on \(store.selectedTarget?.name ?? "this server")."))
            } else {
                List(items) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline).lineLimit(2)
                            Text(item.state.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct CandidatesView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ManualImportStore
    let download: QueueItem

    @State private var state: LoadState<[ManualImportCandidate]> = .loading
    @State private var selected: Set<String> = []
    @State private var mode = "move"
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView("Scanning files…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Scan", systemImage: "exclamationmark.triangle", description: Text(message))
            case let .loaded(candidates):
                content(candidates)
            }
        }
        .navigationTitle("Files")
        .dsInlineNavigationTitle()
        .task {
            state = await store.candidates(for: download)
            if case let .loaded(candidates) = state {
                selected = Set(candidates.filter(\.importable).map(\.id)) // pre-select importable
            }
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }

    @ViewBuilder
    private func content(_ candidates: [ManualImportCandidate]) -> some View {
        if candidates.isEmpty {
            ContentUnavailableView("No Files", systemImage: "doc", description: Text("Nothing to import for this download."))
        } else {
            List {
                Section {
                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate, isSelected: selected.contains(candidate.id)) {
                            guard candidate.importable else { return }
                            if selected.contains(candidate.id) { selected.remove(candidate.id) } else { selected.insert(candidate.id) }
                        }
                    }
                }
                Section {
                    Picker("Mode", selection: $mode) {
                        Text("Move").tag("move")
                        Text("Copy").tag("copy")
                    }.pickerStyle(.segmented)
                } footer: {
                    Text("Move relocates files into your library; Copy leaves the originals in place.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await runImport(candidates) }
                } label: {
                    if importing { ProgressView() } else { Text("Import \(selected.count) file\(selected.count == 1 ? "" : "s")") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty || importing)
                .padding()
            }
        }
    }

    private func runImport(_ candidates: [ManualImportCandidate]) async {
        importing = true
        defer { importing = false }
        let chosen = candidates.filter { selected.contains($0.id) }
        do {
            try await store.performImport(chosen, mode: mode)
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct CandidateRow: View {
    let candidate: ManualImportCandidate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: candidate.importable ? (isSelected ? "checkmark.circle.fill" : "circle") : "exclamationmark.circle")
                    .foregroundStyle(candidate.importable ? (isSelected ? Color.accentColor : .secondary) : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title).font(.subheadline)
                    Text(candidate.fileName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    if let quality = candidate.qualityName { Text(quality).font(.caption2).foregroundStyle(.secondary) }
                    ForEach(candidate.rejections, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.triangle").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!candidate.importable)
    }
}
