import Foundation

/// qBittorrent WebUI API v2. Login/cookie handling lives in `QBittorrentAuthenticator`.
/// Uses the 4.x verb names (pause/resume) which remain widely supported.
struct QBittorrentService: DownloadClient {
    let instance: ServiceInstance
    private let api: APIClient
    private let base: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.instance = instance
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.base = instance.type.apiBasePath  // "/api/v2"
    }

    func testConnection() async throws {
        _ = try await api.send(Endpoint(path: base + "/app/version"))
    }

    func items() async throws -> [DownloadItem] {
        let data = try await api.send(Endpoint(path: base + "/torrents/info"))
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.map { t in
            let state = (t["state"] as? String) ?? "unknown"
            let isPaused = state.lowercased().contains("paused") || state.lowercased().hasPrefix("stopped")
            return DownloadItem(
                id: (t["hash"] as? String) ?? UUID().uuidString,
                name: (t["name"] as? String) ?? "Unknown",
                progress: JSONNumber.double(t["progress"]) ?? 0,
                state: state,
                isPaused: isPaused,
                sizeBytes: JSONNumber.int64(t["size"]),
                downloadRate: JSONNumber.int64(t["dlspeed"]),
                etaSeconds: JSONNumber.int(t["eta"]),
                category: t["category"] as? String
            )
        }
    }

    private func post(_ path: String, _ pairs: [(String, String)]) -> Endpoint {
        Endpoint(
            path: base + path, method: .post, body: formBody(pairs),
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
    }

    func pause(_ item: DownloadItem) async throws {
        try await api.send(post("/torrents/pause", [("hashes", item.id)]))
    }

    func resume(_ item: DownloadItem) async throws {
        try await api.send(post("/torrents/resume", [("hashes", item.id)]))
    }

    func delete(_ item: DownloadItem, deleteData: Bool) async throws {
        try await api.send(post("/torrents/delete", [
            ("hashes", item.id), ("deleteFiles", deleteData ? "true" : "false"),
        ]))
    }
}
