import Foundation

// MARK: - Shared Servarr DTOs (Sonarr / Radarr / Lidarr / Readarr / Prowlarr)

struct SystemStatus: Decodable, Sendable {
    var version: String?
    var appName: String?
    var instanceName: String?
    var osName: String?
    var isProduction: Bool?
}

struct HealthResource: Decodable, Identifiable, Sendable {
    var source: String?
    var type: String?       // "ok", "notice", "warning", "error"
    var message: String?
    var wikiUrl: String?

    var id: String { "\(source ?? "")|\(message ?? "")" }
}

struct DiskSpace: Decodable, Identifiable, Sendable {
    var path: String?
    var label: String?
    var freeSpace: Int64?
    var totalSpace: Int64?

    var id: String { path ?? UUID().uuidString }
    var usedFraction: Double {
        guard let total = totalSpace, total > 0, let free = freeSpace else { return 0 }
        return Double(total - free) / Double(total)
    }
}

/// Servarr list endpoints that paginate wrap records like this.
struct ServarrPage<Record: Decodable & Sendable>: Decodable, Sendable {
    var page: Int?
    var pageSize: Int?
    var totalRecords: Int?
    var records: [Record]
}

struct QueueRecord: Decodable, Identifiable, Sendable {
    var id: Int
    var title: String?
    var status: String?
    var trackedDownloadState: String?
    var trackedDownloadStatus: String?
    var size: Double?
    var sizeleft: Double?
    var timeleft: String?
    var downloadId: String?
    var indexer: String?
    var errorMessage: String?

    var progressFraction: Double {
        guard let size, size > 0, let sizeleft else { return 0 }
        return max(0, min(1, (size - sizeleft) / size))
    }
}

struct HistoryRecord: Decodable, Identifiable, Sendable {
    var id: Int
    var eventType: String?
    var sourceTitle: String?
    var date: Date?
}

struct QualityProfile: Decodable, Identifiable, Hashable, Sendable {
    var id: Int
    var name: String
}

struct RootFolder: Decodable, Identifiable, Hashable, Sendable {
    var id: Int
    var path: String
    var freeSpace: Int64?
}

struct MediaImage: Codable, Hashable, Sendable {
    var coverType: String?
    var remoteUrl: String?
    var url: String?

    var bestURL: URL? {
        if let remoteUrl, let u = URL(string: remoteUrl) { return u }
        if let url, let u = URL(string: url) { return u }
        return nil
    }
}

/// POST /command body. Only the fields relevant to a given command need to be set.
struct CommandRequest: Encodable, Sendable {
    var name: String
    var seriesId: Int?
    var movieId: Int?
    var artistId: Int?
    var authorId: Int?
    var episodeIds: [Int]?

    init(
        name: String,
        seriesId: Int? = nil,
        movieId: Int? = nil,
        artistId: Int? = nil,
        authorId: Int? = nil,
        episodeIds: [Int]? = nil
    ) {
        self.name = name
        self.seriesId = seriesId
        self.movieId = movieId
        self.artistId = artistId
        self.authorId = authorId
        self.episodeIds = episodeIds
    }
}

struct CommandResource: Decodable, Identifiable, Sendable {
    var id: Int
    var name: String?
    var status: String?
}

/// Options sent when adding new media so the *arr app searches immediately.
struct AddOptions: Codable, Sendable {
    var searchForMissingEpisodes: Bool?
    var searchForMovie: Bool?
    var monitor: String?
}
