import Foundation

// Lidarr wire shapes. Calendar returns albums (with nested artist); library is artists. We
// decode only what we render; Codable ignores the rest. `releaseDate` is ISO-8601.

struct LidarrImageDTO: Decodable, Sendable {
    let coverType: String
    let url: String?
    let remoteUrl: String?
}

extension Array where Element == LidarrImageDTO {
    var posterURL: URL? {
        let poster = first { $0.coverType == "poster" } ?? first { $0.coverType == "cover" }
        return (poster?.remoteUrl ?? poster?.url).flatMap(URL.init(string:))
    }
}

struct LidarrCalendarAlbumDTO: Decodable, Sendable {
    let id: Int
    let title: String          // album title
    let releaseDate: Date?
    let monitored: Bool
    let artist: LidarrArtistRefDTO?
    let images: [LidarrImageDTO]?

    struct LidarrArtistRefDTO: Decodable, Sendable {
        let artistName: String?
    }
}

struct LidarrArtistListItemDTO: Decodable, Sendable {
    let id: Int
    let artistName: String
    let monitored: Bool
    let overview: String?
    let statistics: Statistics?
    let images: [LidarrImageDTO]?

    struct Statistics: Decodable, Sendable {
        let albumCount: Int?
        let trackCount: Int?
        let trackFileCount: Int?
    }
}
