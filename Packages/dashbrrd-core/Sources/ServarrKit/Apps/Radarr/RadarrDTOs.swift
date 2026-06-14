import Foundation

/// Radarr's `calendar` returns movie objects (no nested series). Release timing is spread
/// across cinema/physical/digital dates; the mapper picks the most relevant one. We decode
/// only the fields we render; Codable ignores the rest.
struct RadarrCalendarItemDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let year: Int?
    let hasFile: Bool
    let monitored: Bool
    let overview: String?
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?
    let images: [RadarrImageDTO]?

    /// The date to place on the unified timeline: prefer digital, then physical, then cinema.
    var releaseDate: Date? {
        digitalRelease ?? physicalRelease ?? inCinemas
    }

    /// Which release the chosen date represents (for the entry subtitle).
    var releaseLabel: String {
        if digitalRelease != nil { return "Digital release" }
        if physicalRelease != nil { return "Physical release" }
        if inCinemas != nil { return "In cinemas" }
        return "Released"
    }

    var posterURL: URL? {
        guard let images else { return nil }
        let poster = images.first { $0.coverType == "poster" }
        return (poster?.remoteUrl ?? poster?.url).flatMap(URL.init(string:))
    }
}

struct RadarrImageDTO: Decodable, Sendable {
    let coverType: String
    let url: String?
    let remoteUrl: String?
}
