import Foundation

/// NZBGet exposes a JSON-RPC endpoint guarded by HTTP Basic auth (`BasicAuthenticator`).
struct NZBGetService: DownloadClient {
    let instance: ServiceInstance
    private let api: APIClient
    private let base: String

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.instance = instance
        self.api = APIClientFactory.make(for: instance, credential: credential)
        self.base = instance.type.apiBasePath  // "/jsonrpc"
    }

    @discardableResult
    private func call(_ method: String, params: [Any] = []) async throws -> Any? {
        let payload: [String: Any] = ["method": method, "params": params, "id": 1]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let endpoint = Endpoint(
            path: base, method: .post, body: body,
            headers: ["Content-Type": "application/json"]
        )
        let data = try await api.send(endpoint)
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return root?["result"]
    }

    func testConnection() async throws {
        _ = try await call("version")
    }

    func items() async throws -> [DownloadItem] {
        guard let groups = try await call("listgroups", params: [0]) as? [[String: Any]] else {
            return []
        }
        return groups.map { g in
            let status = (g["Status"] as? String) ?? "QUEUED"
            let fileSizeMB = JSONNumber.double(g["FileSizeMB"]) ?? 0
            let remainingMB = JSONNumber.double(g["RemainingSizeMB"]) ?? 0
            let progress = fileSizeMB > 0 ? (fileSizeMB - remainingMB) / fileSizeMB : 0
            return DownloadItem(
                id: String(JSONNumber.int(g["NZBID"]) ?? 0),
                name: (g["NZBName"] as? String) ?? "Unknown",
                progress: max(0, min(1, progress)),
                state: status.capitalized,
                isPaused: status.uppercased().contains("PAUSED"),
                sizeBytes: Int64(fileSizeMB * 1_048_576),
                downloadRate: JSONNumber.int64(g["DownloadRate"]),
                etaSeconds: nil,
                category: g["Category"] as? String
            )
        }
    }

    private func editQueue(_ command: String, id: String) async throws {
        let nzbID = Int(id) ?? -1
        // editqueue(Command, Offset, EditText, IDs)
        _ = try await call("editqueue", params: [command, 0, "", [nzbID]])
    }

    func pause(_ item: DownloadItem) async throws { try await editQueue("GroupPause", id: item.id) }
    func resume(_ item: DownloadItem) async throws { try await editQueue("GroupResume", id: item.id) }
    func delete(_ item: DownloadItem, deleteData: Bool) async throws {
        try await editQueue(deleteData ? "GroupFinalDelete" : "GroupDelete", id: item.id)
    }
}
