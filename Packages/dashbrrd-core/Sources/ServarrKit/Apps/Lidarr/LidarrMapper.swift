import Foundation
import CoreModel

/// Maps Lidarr's music DTOs into the shared `CoreModel` types — albums become calendar
/// entries (artist as title, album as subtitle), artists become library items.
enum LidarrMapper {
    static func calendarEntry(from dto: LidarrCalendarAlbumDTO, instanceID: InstanceID) -> CalendarEntry? {
        guard let date = dto.releaseDate else { return nil }
        return CalendarEntry(
            id: "\(instanceID.rawValue.uuidString):\(dto.id)",
            instanceID: instanceID,
            serviceKind: .lidarr,
            title: dto.artist?.artistName ?? "Unknown Artist",
            subtitle: dto.title,
            airDate: date,
            hasFile: false
        )
    }

    static func mediaItem(from dto: LidarrArtistListItemDTO, instanceID: InstanceID) -> MediaItem {
        var parts: [String] = []
        if let albums = dto.statistics?.albumCount { parts.append("\(albums) album\(albums == 1 ? "" : "s")") }
        if let stats = dto.statistics, let total = stats.trackCount {
            parts.append("\(stats.trackFileCount ?? 0)/\(total) tracks")
        }
        return MediaItem(
            id: "\(instanceID.rawValue.uuidString):\(dto.id)",
            instanceID: instanceID,
            serviceKind: .lidarr,
            remoteID: dto.id,
            title: dto.artistName,
            year: nil,
            posterURL: dto.images?.posterURL,
            monitored: dto.monitored,
            overview: dto.overview,
            subtitle: parts.isEmpty ? nil : parts.joined(separator: " · ")
        )
    }
}
