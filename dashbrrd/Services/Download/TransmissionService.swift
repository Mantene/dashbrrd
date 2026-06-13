import Foundation

/// Transmission RPC. The X-Transmission-Session-Id 409 handshake is handled by
/// `TransmissionAuthenticator`.
struct TransmissionService: DownloadClient {
    let instance: ServiceInstance
    private let api: APIClient
    private let base: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.instance = instance
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.base = instance.type.apiBasePath  // "/transmission/rpc"
    }

    private func rpc(method: String, arguments: [String: Any]) async throws -> [String: Any] {
        let payload: [String: Any] = ["method": method, "arguments": arguments]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let endpoint = Endpoint(
            path: base, method: .post, body: body,
            headers: ["Content-Type": "application/json"]
        )
        let data = try await api.send(endpoint)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.message("Unexpected Transmission response.")
        }
        if let result = root["result"] as? String, result != "success" {
            throw APIError.message("Transmission: \(result)")
        }
        return root["arguments"] as? [String: Any] ?? [:]
    }

    func testConnection() async throws {
        _ = try await rpc(method: "session-get", arguments: [:])
    }

    func items() async throws -> [DownloadItem] {
        let fields = ["id", "name", "percentDone", "status", "totalSize", "rateDownload", "eta"]
        let args = try await rpc(method: "torrent-get", arguments: ["fields": fields])
        guard let torrents = args["torrents"] as? [[String: Any]] else { return [] }
        return torrents.map { t in
            let statusCode = JSONNumber.int(t["status"]) ?? 0
            return DownloadItem(
                id: String(JSONNumber.int(t["id"]) ?? 0),
                name: (t["name"] as? String) ?? "Unknown",
                progress: JSONNumber.double(t["percentDone"]) ?? 0,
                state: Self.statusName(statusCode),
                isPaused: statusCode == 0,
                sizeBytes: JSONNumber.int64(t["totalSize"]),
                downloadRate: JSONNumber.int64(t["rateDownload"]),
                etaSeconds: JSONNumber.int(t["eta"]),
                category: nil
            )
        }
    }

    func pause(_ item: DownloadItem) async throws {
        _ = try await rpc(method: "torrent-stop", arguments: ["ids": [Int(item.id) ?? -1]])
    }

    func resume(_ item: DownloadItem) async throws {
        _ = try await rpc(method: "torrent-start", arguments: ["ids": [Int(item.id) ?? -1]])
    }

    func delete(_ item: DownloadItem, deleteData: Bool) async throws {
        _ = try await rpc(
            method: "torrent-remove",
            arguments: ["ids": [Int(item.id) ?? -1], "delete-local-data": deleteData]
        )
    }

    private static func statusName(_ code: Int) -> String {
        switch code {
        case 0: "Stopped"
        case 1: "Queued (check)"
        case 2: "Checking"
        case 3: "Queued"
        case 4: "Downloading"
        case 5: "Queued (seed)"
        case 6: "Seeding"
        default: "Unknown"
        }
    }
}
