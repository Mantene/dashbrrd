import Foundation

struct ProwlarrIndexer: Decodable, Identifiable, Sendable {
    var id: Int
    var name: String?
    var enable: Bool?
    var `protocol`: String?
    var priority: Int?
}

struct ProwlarrSearchResult: Decodable, Identifiable, Sendable {
    var guid: String?
    var title: String?
    var indexer: String?
    var size: Int64?
    var seeders: Int?
    var leechers: Int?
    var `protocol`: String?

    var id: String { guid ?? UUID().uuidString }
}

/// Prowlarr manages indexers rather than a media library, so it has its own thin client.
struct ProwlarrService: Sendable {
    let core: ServarrClient

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.core = ServarrClient(instance: instance, credential: credential)
    }

    func indexers() async throws -> [ProwlarrIndexer] {
        try await core.api.send(
            Endpoint(path: core.basePath + "/indexer"), as: [ProwlarrIndexer].self
        )
    }

    func search(_ query: String) async throws -> [ProwlarrSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let endpoint = Endpoint(
            path: core.basePath + "/search",
            query: [URLQueryItem(name: "query", value: trimmed)]
        )
        return try await core.api.send(endpoint, as: [ProwlarrSearchResult].self)
    }

    func systemStatus() async throws -> SystemStatus { try await core.systemStatus() }
    func health() async throws -> [HealthResource] { try await core.health() }
}
