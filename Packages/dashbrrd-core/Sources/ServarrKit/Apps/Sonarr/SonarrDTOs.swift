import Foundation

// Sonarr's `calendar` returns episode objects with a nested `series`. We decode only the
// fields we render; Codable ignores the rest. `airDateUtc` is ISO-8601 with a `Z` suffix.

struct SonarrCalendarItemDTO: Decodable, Sendable {
    let id: Int
    let seriesId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String          // episode title
    let airDateUtc: Date?
    let hasFile: Bool
    let monitored: Bool
    let overview: String?
    let series: SonarrSeriesDTO?
}

struct SonarrSeriesDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let images: [SonarrImageDTO]?

    /// The remote poster URL, if Sonarr provided one.
    var posterURL: URL? {
        guard let images else { return nil }
        let poster = images.first { $0.coverType == "poster" }
        return (poster?.remoteUrl ?? poster?.url).flatMap(URL.init(string:))
    }
}

struct SonarrImageDTO: Decodable, Sendable {
    let coverType: String
    let url: String?
    let remoteUrl: String?
}
