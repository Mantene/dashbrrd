import Foundation
import CoreModel
import Networking

// SABnzbd (usenet). Auth is a `?apikey=` query param (carried on the ConnectionProfile as a
// `.queryParam` credential, appended by URLBuilder). All calls hit `/api?mode=…`.

struct SABQueueResponseDTO: Decodable, Sendable {
    let queue: SABQueueDTO
}

struct SABQueueDTO: Decodable, Sendable {
    let slots: [SABSlotDTO]
}

struct SABSlotDTO: Decodable, Sendable {
    let nzo_id: String
    let filename: String
    let status: String
    let mb: String?
    let mbleft: String?
    let percentage: String?
    let timeleft: String?
    let cat: String?
}

struct SABVersionDTO: Decodable, Sendable {
    let version: String
}

/// Pure mapping from SAB wire shape → normalized `QueueItem`s (tested directly on fixtures,
/// since every SAB call shares the `/api` path and can't be route-mocked by path alone).
enum SABnzbdMapper {
    static func items(from dto: SABQueueResponseDTO, instanceID: InstanceID) -> [QueueItem] {
        dto.queue.slots.map { slot in
            let mb = Double(slot.mb ?? "") ?? 0
            let mbLeft = Double(slot.mbleft ?? "") ?? 0
            let pct = (Double(slot.percentage ?? "") ?? 0) / 100.0
            return QueueItem(
                id: "\(instanceID.rawValue.uuidString):\(slot.nzo_id)",
                instanceID: instanceID,
                serviceKind: .sabnzbd,
                name: slot.filename,
                state: mapState(slot.status),
                progress: max(0, min(1, pct)),
                sizeBytes: Int64(mb * 1_000_000),
                sizeLeftBytes: Int64(mbLeft * 1_000_000),
                speedBytesPerSec: 0, // SAB reports a global speed, not per-slot
                etaSeconds: parseTimeLeft(slot.timeleft),
                category: slot.cat.flatMap { $0.isEmpty ? nil : $0 },
                downloadID: slot.nzo_id
            )
        }
    }

    static func mapState(_ status: String) -> QueueState {
        switch status.lowercased() {
        case "downloading", "grabbing", "fetching", "checking", "extracting", "verifying", "repairing", "moving": .downloading
        case "paused": .paused
        case "queued": .queued
        case "completed": .completed
        case "failed": .error
        default: .unknown
        }
    }

    /// Parses SAB's "H:MM:SS" (or "MM:SS") time-left into seconds.
    static func parseTimeLeft(_ value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return seconds > 0 ? seconds : nil
    }
}

public actor SABnzbdClient: DownloadClient {
    public let instanceID: InstanceID
    public nonisolated var kind: ServiceKind { .sabnzbd }
    private let http: HTTPClientProtocol

    public init(instanceID: InstanceID, http: HTTPClientProtocol) {
        self.instanceID = instanceID
        self.http = http
    }

    private func apiEndpoint(_ items: [URLQueryItem]) -> Endpoint {
        Endpoint(path: "api", query: items + [URLQueryItem(name: "output", value: "json")])
    }

    public func version() async throws -> String {
        let dto = try await http.send(apiEndpoint([URLQueryItem(name: "mode", value: "version")]), as: SABVersionDTO.self)
        return dto.version
    }

    public func queue() async throws -> [QueueItem] {
        let dto = try await http.send(apiEndpoint([URLQueryItem(name: "mode", value: "queue")]), as: SABQueueResponseDTO.self)
        return SABnzbdMapper.items(from: dto, instanceID: instanceID)
    }

    public func pause(_ downloadID: String) async throws {
        _ = try await http.data(for: apiEndpoint([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "pause"),
            URLQueryItem(name: "value", value: downloadID),
        ]))
    }

    public func resume(_ downloadID: String) async throws {
        _ = try await http.data(for: apiEndpoint([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "resume"),
            URLQueryItem(name: "value", value: downloadID),
        ]))
    }

    public func remove(_ downloadID: String, deleteData: Bool) async throws {
        _ = try await http.data(for: apiEndpoint([
            URLQueryItem(name: "mode", value: "queue"),
            URLQueryItem(name: "name", value: "delete"),
            URLQueryItem(name: "value", value: downloadID),
            URLQueryItem(name: "del_files", value: deleteData ? "1" : "0"),
        ]))
    }
}
