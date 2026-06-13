import Foundation

/// SABnzbd talks JSON over a single /api endpoint switched by `mode`. The API key is appended by
/// `QueryKeyAuthenticator`.
struct SABnzbdService: DownloadClient {
    let instance: ServiceInstance
    private let api: APIClient
    private let base: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.instance = instance
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.base = instance.type.apiBasePath  // "/api"
    }

    private func mode(_ items: [URLQueryItem]) -> Endpoint {
        Endpoint(path: base, query: items + [URLQueryItem(name: "output", value: "json")])
    }

    func testConnection() async throws {
        let data = try await api.send(mode([URLQueryItem(name: "mode", value: "version")]))
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw APIError.message("SABnzbd did not return a valid response.")
        }
    }

    func items() async throws -> [DownloadItem] {
        let data = try await api.send(mode([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "limit", value: "200"),
        ]))
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let queue = root["queue"] as? [String: Any],
            let slots = queue["slots"] as? [[String: Any]]
        else { return [] }

        return slots.map { slot in
            let status = (slot["status"] as? String) ?? "Queued"
            let mb = JSONNumber.double(slot["mb"]) ?? 0
            let percentage = JSONNumber.double(slot["percentage"]) ?? 0
            return DownloadItem(
                id: (slot["nzo_id"] as? String) ?? UUID().uuidString,
                name: (slot["filename"] as? String) ?? "Unknown",
                progress: percentage / 100.0,
                state: status,
                isPaused: status.caseInsensitiveCompare("Paused") == .orderedSame,
                sizeBytes: Int64(mb * 1_048_576),
                downloadRate: nil,
                etaSeconds: nil,
                category: slot["cat"] as? String
            )
        }
    }

    func pause(_ item: DownloadItem) async throws {
        try await api.send(mode([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "pause"),
            URLQueryItem(name: "value", value: item.id),
        ]))
    }

    func resume(_ item: DownloadItem) async throws {
        try await api.send(mode([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "resume"),
            URLQueryItem(name: "value", value: item.id),
        ]))
    }

    func delete(_ item: DownloadItem, deleteData: Bool) async throws {
        try await api.send(mode([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "delete"),
            URLQueryItem(name: "value", value: item.id),
            URLQueryItem(name: "del_files", value: deleteData ? "1" : "0"),
        ]))
    }
}
