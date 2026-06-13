import Foundation

/// Bazarr manages subtitles. v1 surfaces a connection probe and "wanted" subtitle counts for the
/// dashboard; deeper management can follow against the same client.
struct BazarrService: Sendable {
    let instance: ServiceInstance
    private let api: APIClient
    private let base: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.instance = instance
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.base = instance.type.apiBasePath  // "/api"
    }

    func testConnection() async throws {
        let data = try await api.send(Endpoint(path: base + "/system/status"))
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw APIError.message("Bazarr did not return a valid response.")
        }
    }

    /// Returns (wantedEpisodes, wantedMovies). Bazarr paginates with a `total` field.
    func wantedCounts() async throws -> (episodes: Int, movies: Int) {
        async let episodes = total(path: base + "/episodes/wanted")
        async let movies = total(path: base + "/movies/wanted")
        return try await (episodes, movies)
    }

    private func total(path: String) async throws -> Int {
        let endpoint = Endpoint(path: path, query: [
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "length", value: "1"),
        ])
        let data = try await api.send(endpoint)
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return JSONNumber.int(root?["total"]) ?? (root?["data"] as? [Any])?.count ?? 0
    }
}
