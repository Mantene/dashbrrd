import SwiftUI

@MainActor
@Observable
final class ServarrLibraryViewModel {
    let instance: ServiceInstance
    private let service: ServarrLibraryService?

    var state: LoadState<[MediaSummary]> = .idle
    var profiles: [QualityProfile] = []
    var rootFolders: [RootFolder] = []
    var actionError: String?

    init(instance: ServiceInstance, credential: AuthCredential?) {
        self.instance = instance
        self.service = credential.map { ServarrLibraryService(instance: instance, credential: $0) }
    }

    private func requireService() throws -> ServarrLibraryService {
        guard let service else { throw APIError.message("No credentials saved for \(instance.name).") }
        return service
    }

    func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let items = try await requireService().library()
            state = .loaded(items)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func ensureMetadata() async {
        guard profiles.isEmpty || rootFolders.isEmpty, let service else { return }
        async let p = service.qualityProfiles()
        async let r = service.rootFolders()
        profiles = (try? await p) ?? []
        rootFolders = (try? await r) ?? []
    }

    func setMonitored(_ item: MediaSummary, _ monitored: Bool) async {
        await perform { try await self.requireService().setMonitored(item, monitored: monitored) }
    }

    func delete(_ item: MediaSummary, deleteFiles: Bool) async {
        await perform { try await self.requireService().delete(item, deleteFiles: deleteFiles) }
    }

    func search(_ item: MediaSummary) async {
        await perform { try await self.requireService().search(item) }
    }

    func lookup(_ term: String) async throws -> [MediaSummary] {
        try await requireService().lookup(term)
    }

    func add(
        _ item: MediaSummary,
        qualityProfileId: Int,
        rootFolderPath: String,
        monitored: Bool,
        searchNow: Bool
    ) async throws {
        try await requireService().add(
            item, qualityProfileId: qualityProfileId,
            rootFolderPath: rootFolderPath, monitored: monitored, searchNow: searchNow
        )
    }

    /// Run a mutating action, surface any error, then refresh the library.
    private func perform(_ work: @escaping () async throws -> Void) async {
        do {
            try await work()
            await load()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
