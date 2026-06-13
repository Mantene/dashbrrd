import Foundation

/// A unified, display-ready media item used by the generic Servarr library UI. It carries the raw
/// lookup/library JSON (`rawAddPayload`) so add/update can round-trip every server field without
/// modelling each app's full schema.
struct MediaSummary: Identifiable, Sendable, Hashable {
    var id: Int                 // service entity id; 0 for a lookup result not yet in the library
    var title: String
    var year: Int?
    var overview: String?
    var posterURL: URL?
    var status: String?
    var monitored: Bool
    var isInLibrary: Bool
    var sizeOnDisk: Int64?
    var externalKey: String?    // tvdbId/tmdbId/etc, used to identify lookup results
    var rawAddPayload: Data?    // original JSON object for this item

    /// A stable identity even for lookup results (which may share id == 0).
    var stableID: String { id != 0 ? "id:\(id)" : "ext:\(externalKey ?? title)" }

    func rawObject() -> [String: Any]? {
        guard let rawAddPayload else { return nil }
        return try? JSONSerialization.jsonObject(with: rawAddPayload) as? [String: Any]
    }
}

/// Per-app configuration that specializes the generic Servarr library behaviour.
struct ServarrEntity: Sendable {
    var path: String            // "/series"
    var lookupPath: String      // "/series/lookup"
    var titleKey: String        // "title" / "artistName" / "authorName"
    var externalIdKey: String   // "tvdbId" / "tmdbId" / "foreignArtistId" / "foreignAuthorId"
    var searchCommand: String   // "SeriesSearch"
    var searchAddOptionKey: String?  // addOptions key controlling the immediate search
    var extraAddDefaults: [String: Int]  // e.g. metadataProfileId for music/books

    static func forType(_ type: ServiceType) -> ServarrEntity {
        switch type {
        case .sonarr:
            ServarrEntity(path: "/series", lookupPath: "/series/lookup", titleKey: "title",
                          externalIdKey: "tvdbId", searchCommand: "SeriesSearch",
                          searchAddOptionKey: "searchForMissingEpisodes", extraAddDefaults: [:])
        case .radarr:
            ServarrEntity(path: "/movie", lookupPath: "/movie/lookup", titleKey: "title",
                          externalIdKey: "tmdbId", searchCommand: "MoviesSearch",
                          searchAddOptionKey: "searchForMovie", extraAddDefaults: [:])
        case .lidarr:
            ServarrEntity(path: "/artist", lookupPath: "/artist/lookup", titleKey: "artistName",
                          externalIdKey: "foreignArtistId", searchCommand: "ArtistSearch",
                          searchAddOptionKey: "searchForMissingAlbums",
                          extraAddDefaults: ["metadataProfileId": 1])
        case .readarr:
            ServarrEntity(path: "/author", lookupPath: "/author/lookup", titleKey: "authorName",
                          externalIdKey: "foreignAuthorId", searchCommand: "AuthorSearch",
                          searchAddOptionKey: "searchForMissingBooks",
                          extraAddDefaults: ["metadataProfileId": 1])
        default:
            // Prowlarr has no library; callers should not reach here.
            ServarrEntity(path: "", lookupPath: "", titleKey: "title", externalIdKey: "id",
                          searchCommand: "", searchAddOptionKey: nil, extraAddDefaults: [:])
        }
    }
}

extension MediaSummary {
    /// Parse a Servarr list/lookup response into summaries.
    static func parseList(_ data: Data, entity: ServarrEntity, isLibrary: Bool) -> [MediaSummary] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.map { object in
            let id = object["id"] as? Int ?? 0
            let title = (object[entity.titleKey] as? String)
                ?? (object["title"] as? String) ?? "Untitled"
            let externalRaw = object[entity.externalIdKey]
            let externalKey = externalRaw.map { String(describing: $0) }
            let statistics = object["statistics"] as? [String: Any]
            let sizeNumber = (statistics?["sizeOnDisk"] as? NSNumber)
                ?? (object["sizeOnDisk"] as? NSNumber)
            return MediaSummary(
                id: id,
                title: title,
                year: object["year"] as? Int,
                overview: object["overview"] as? String,
                posterURL: posterURL(from: object["images"]),
                status: object["status"] as? String,
                monitored: object["monitored"] as? Bool ?? false,
                isInLibrary: isLibrary || id != 0,
                sizeOnDisk: sizeNumber?.int64Value,
                externalKey: externalKey,
                rawAddPayload: try? JSONSerialization.data(withJSONObject: object)
            )
        }
    }

    private static func posterURL(from images: Any?) -> URL? {
        guard let images = images as? [[String: Any]] else { return nil }
        let poster = images.first { ($0["coverType"] as? String) == "poster" } ?? images.first
        let string = (poster?["remoteUrl"] as? String) ?? (poster?["url"] as? String)
        return string.flatMap(URL.init(string:))
    }
}
