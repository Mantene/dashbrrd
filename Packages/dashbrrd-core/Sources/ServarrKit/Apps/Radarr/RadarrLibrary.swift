import Foundation
import CoreModel
import Networking

/// Radarr `movie` list → normalized `MediaItem`s, available only on a Radarr-specialized client.

struct RadarrMovieListItemDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let year: Int?
    let monitored: Bool
    let hasFile: Bool
    let images: [RadarrImageDTO]?

    var posterURL: URL? {
        guard let images else { return nil }
        let poster = images.first { $0.coverType == "poster" }
        return (poster?.remoteUrl ?? poster?.url).flatMap(URL.init(string:))
    }

    func toMediaItem(instanceID: InstanceID) -> MediaItem {
        MediaItem(
            id: "\(instanceID.rawValue.uuidString):\(id)",
            instanceID: instanceID,
            serviceKind: .radarr,
            title: title,
            year: year,
            posterURL: posterURL,
            monitored: monitored,
            subtitle: hasFile ? "Downloaded" : "Missing"
        )
    }
}

extension ServarrClient where Descriptor == RadarrDescriptor {
    public func library() async throws -> [MediaItem] {
        let dtos = try await httpClient.send(Endpoint(path: "movie"), as: [RadarrMovieListItemDTO].self)
        return dtos
            .map { $0.toMediaItem(instanceID: instanceID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
