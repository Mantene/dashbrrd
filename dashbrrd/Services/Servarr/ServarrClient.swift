import Foundation

/// Endpoints shared by every Servarr app. The media-specific clients (Sonarr/Radarr/...) compose
/// this and add their own entity CRUD.
struct ServarrClient: Sendable {
    let api: APIClient
    let basePath: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.basePath = instance.type.apiBasePath
    }

    private func path(_ suffix: String) -> String { basePath + suffix }

    /// Lightweight call used by "Test Connection".
    @discardableResult
    func systemStatus() async throws -> SystemStatus {
        try await api.send(Endpoint(path: path("/system/status")), as: SystemStatus.self)
    }

    func health() async throws -> [HealthResource] {
        try await api.send(Endpoint(path: path("/health")), as: [HealthResource].self)
    }

    func diskSpace() async throws -> [DiskSpace] {
        try await api.send(Endpoint(path: path("/diskspace")), as: [DiskSpace].self)
    }

    func queue(pageSize: Int = 100) async throws -> [QueueRecord] {
        let endpoint = Endpoint(
            path: path("/queue"),
            query: [
                URLQueryItem(name: "pageSize", value: String(pageSize)),
                URLQueryItem(name: "includeUnknownItems", value: "true"),
            ]
        )
        return try await api.send(endpoint, as: ServarrPage<QueueRecord>.self).records
    }

    func history(pageSize: Int = 50) async throws -> [HistoryRecord] {
        let endpoint = Endpoint(
            path: path("/history"),
            query: [
                URLQueryItem(name: "pageSize", value: String(pageSize)),
                URLQueryItem(name: "sortKey", value: "date"),
                URLQueryItem(name: "sortDirection", value: "descending"),
            ]
        )
        return try await api.send(endpoint, as: ServarrPage<HistoryRecord>.self).records
    }

    func qualityProfiles() async throws -> [QualityProfile] {
        try await api.send(Endpoint(path: path("/qualityprofile")), as: [QualityProfile].self)
    }

    func rootFolders() async throws -> [RootFolder] {
        try await api.send(Endpoint(path: path("/rootfolder")), as: [RootFolder].self)
    }

    func runCommand(_ request: CommandRequest) async throws {
        let endpoint = try Endpoint.json(path("/command"), body: request)
        try await api.send(endpoint)
    }

    func deleteQueueItem(_ id: Int, removeFromClient: Bool = true, blocklist: Bool = false) async throws {
        let endpoint = Endpoint(
            path: path("/queue/\(id)"),
            method: .delete,
            query: [
                URLQueryItem(name: "removeFromClient", value: String(removeFromClient)),
                URLQueryItem(name: "blocklist", value: String(blocklist)),
            ]
        )
        try await api.send(endpoint)
    }
}
