import Foundation
import CoreModel
import Networking

/// Lidarr-specific calendar (albums) and library (artists), available only on a Lidarr client.
extension ServarrClient where Descriptor == LidarrDescriptor {
    public func calendar(_ range: DateInterval) async throws -> [CalendarEntry] {
        let formatter = ISO8601DateFormatter()
        let endpoint = Endpoint(path: "calendar", query: [
            URLQueryItem(name: "start", value: formatter.string(from: range.start)),
            URLQueryItem(name: "end", value: formatter.string(from: range.end)),
            URLQueryItem(name: "includeArtist", value: "true"),
        ])
        let dtos = try await httpClient.send(endpoint, as: [LidarrCalendarAlbumDTO].self)
        return dtos
            .compactMap { LidarrMapper.calendarEntry(from: $0, instanceID: instanceID) }
            .sorted { $0.airDate < $1.airDate }
    }

    public func library() async throws -> [MediaItem] {
        let dtos = try await httpClient.send(Endpoint(path: "artist"), as: [LidarrArtistListItemDTO].self)
        return dtos
            .map { LidarrMapper.mediaItem(from: $0, instanceID: instanceID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
