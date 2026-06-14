import Foundation
import CoreModel
import Networking

// qBittorrent (torrent). API under `api/v2`. On a LAN with "bypass authentication for
// whitelisted subnets" no login is needed; for authenticated setups a cookie-session login
// (api/v2/auth/login → SID) would run first — URLSession persists the cookie automatically.
// qBittorrent 5.x renamed pause/resume to stop/start.

struct QBTorrentDTO: Decodable, Sendable {
    let hash: String
    let name: String
    let progress: Double
    let size: Int64
    let amount_left: Int64
    let dlspeed: Int64
    let eta: Int?
    let state: String
    let category: String?
}

enum QBittorrentMapper {
    static func item(from dto: QBTorrentDTO, instanceID: InstanceID) -> QueueItem {
        QueueItem(
            id: "\(instanceID.rawValue.uuidString):\(dto.hash)",
            instanceID: instanceID,
            serviceKind: .qbittorrent,
            name: dto.name,
            state: mapState(dto.state),
            progress: max(0, min(1, dto.progress)),
            sizeBytes: dto.size,
            sizeLeftBytes: dto.amount_left,
            speedBytesPerSec: dto.dlspeed,
            etaSeconds: normalizeETA(dto.eta),
            category: dto.category.flatMap { $0.isEmpty ? nil : $0 },
            downloadID: dto.hash
        )
    }

    static func mapState(_ state: String) -> QueueState {
        switch state {
        case "downloading", "forcedDL", "metaDL", "checkingDL", "checkingUP", "moving", "allocating":
            .downloading
        case "stalledDL":
            .stalled
        case "pausedDL", "stoppedDL", "pausedUP", "stoppedUP":
            .paused
        case "queuedDL", "queuedUP":
            .queued
        case "uploading", "forcedUP", "stalledUP":
            .completed // download finished; seeding
        case "error", "missingFiles":
            .error
        default:
            .unknown
        }
    }

    /// qBittorrent uses 8640000 (100 days) as a sentinel for "infinite/unknown" ETA.
    static func normalizeETA(_ eta: Int?) -> Int? {
        guard let eta, eta > 0, eta < 8_640_000 else { return nil }
        return eta
    }
}

public actor QBittorrentClient: DownloadClient {
    public let instanceID: InstanceID
    public nonisolated var kind: ServiceKind { .qbittorrent }
    private let http: HTTPClientProtocol

    public init(instanceID: InstanceID, http: HTTPClientProtocol) {
        self.instanceID = instanceID
        self.http = http
    }

    public func version() async throws -> String {
        let data = try await http.data(for: Endpoint(path: "app/version"))
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func queue() async throws -> [QueueItem] {
        let dtos = try await http.send(Endpoint(path: "torrents/info"), as: [QBTorrentDTO].self)
        return dtos.map { QBittorrentMapper.item(from: $0, instanceID: instanceID) }
    }

    private func action(_ path: String, body: String) async throws {
        _ = try await http.data(for: Endpoint(
            method: .post,
            path: path,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(body.utf8)
        ))
    }

    public func pause(_ downloadID: String) async throws {
        try await action("torrents/stop", body: "hashes=\(downloadID)")
    }

    public func resume(_ downloadID: String) async throws {
        try await action("torrents/start", body: "hashes=\(downloadID)")
    }

    public func remove(_ downloadID: String, deleteData: Bool) async throws {
        try await action("torrents/delete", body: "hashes=\(downloadID)&deleteFiles=\(deleteData ? "true" : "false")")
    }
}
