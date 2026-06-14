import Foundation
import CoreModel

// Wire shapes shared by *every* Servarr app. `system/status` and `health` are identical
// across Sonarr/Radarr/Prowlarr/etc., so they live in the generic engine; only app-specific
// surfaces (calendar/library) get per-app DTOs under `Apps/<Name>/`.
//
// Swift's `Codable` ignores unknown keys, so these intentionally declare only the fields we
// map — the dozens of other keys Sonarr returns are simply skipped.

struct ServarrSystemStatusDTO: Decodable, Sendable {
    let version: String
    let appName: String?
    let instanceName: String?
}

struct ServarrHealthDTO: Decodable, Sendable {
    let source: String
    let type: String       // "ok" | "notice" | "warning" | "error"
    let message: String
    let wikiUrl: String?
}

extension HealthCheck.Severity {
    /// Maps Servarr's `type` string to our severity, defaulting unknown values to `.notice`.
    init(servarrType: String) {
        self = HealthCheck.Severity(rawValue: servarrType.lowercased()) ?? .notice
    }
}

// Shared `queue` shape (Sonarr/Radarr v3). Each record mirrors a download the client is
// handling, with the `downloadId` used to dedup against the actual download-client queue.
struct ServarrQueueResponseDTO: Decodable, Sendable {
    let records: [ServarrQueueRecordDTO]
}

struct ServarrQueueRecordDTO: Decodable, Sendable {
    let id: Int
    let title: String?
    let status: String?
    let size: Double?
    let sizeleft: Double?
    let timeleft: String?
    let downloadId: String?
}

// Shared `history` shape (Sonarr/Radarr v3): a paged list of events.
struct ServarrHistoryResponseDTO: Decodable, Sendable {
    let page: Int
    let pageSize: Int
    let totalRecords: Int
    let records: [ServarrHistoryRecordDTO]
}

struct ServarrHistoryRecordDTO: Decodable, Sendable {
    let id: Int
    let eventType: String
    let sourceTitle: String?
    let date: Date
    let quality: QualityWrapperDTO?

    struct QualityWrapperDTO: Decodable, Sendable {
        let quality: QualityNameDTO?
        struct QualityNameDTO: Decodable, Sendable { let name: String? }
    }

    var qualityName: String? { quality?.quality?.name }
}

// Shared interactive-search `release` shape (Sonarr/Radarr v3).
struct ServarrReleaseDTO: Decodable, Sendable {
    let guid: String
    let title: String
    let indexer: String?
    let indexerId: Int?
    let proto: String?
    let size: Int64?
    let seeders: Int?
    let age: Int?
    let quality: ServarrHistoryRecordDTO.QualityWrapperDTO?
    let rejected: Bool?
    let rejections: [String]?
    let downloadAllowed: Bool?

    enum CodingKeys: String, CodingKey {
        case guid, title, indexer, indexerId
        case proto = "protocol"
        case size, seeders, age, quality, rejected, rejections, downloadAllowed
    }
}

/// Body for POST `release` (grab → send to download client).
struct ServarrGrabRequest: Encodable, Sendable {
    let guid: String
    let indexerId: Int
}
