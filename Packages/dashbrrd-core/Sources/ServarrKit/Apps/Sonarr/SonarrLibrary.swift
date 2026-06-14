import Foundation
import CoreModel
import Networking

/// Sonarr `series` list → normalized `MediaItem`s. Available only on a Sonarr-specialized
/// client (constrained extension), same as calendar.

struct SonarrSeriesListItemDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let year: Int?
    let monitored: Bool
    let status: String?
    let statistics: Statistics?
    let images: [SonarrImageDTO]?

    struct Statistics: Decodable, Sendable {
        let episodeCount: Int?
        let episodeFileCount: Int?
    }

    var posterURL: URL? {
        guard let images else { return nil }
        let poster = images.first { $0.coverType == "poster" }
        return (poster?.remoteUrl ?? poster?.url).flatMap(URL.init(string:))
    }

    func toMediaItem(instanceID: InstanceID) -> MediaItem {
        var parts: [String] = []
        if let status, !status.isEmpty { parts.append(status.capitalized) }
        if let stats = statistics, let total = stats.episodeCount {
            parts.append("\(stats.episodeFileCount ?? 0)/\(total)")
        }
        return MediaItem(
            id: "\(instanceID.rawValue.uuidString):\(id)",
            instanceID: instanceID,
            serviceKind: .sonarr,
            title: title,
            year: year,
            posterURL: posterURL,
            monitored: monitored,
            subtitle: parts.isEmpty ? nil : parts.joined(separator: " · ")
        )
    }
}

extension ServarrClient where Descriptor == SonarrDescriptor {
    public func library() async throws -> [MediaItem] {
        let dtos = try await httpClient.send(Endpoint(path: "series"), as: [SonarrSeriesListItemDTO].self)
        return dtos
            .map { $0.toMediaItem(instanceID: instanceID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
