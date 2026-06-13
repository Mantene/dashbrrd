import Foundation

struct CalendarEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let title: String
    let subtitle: String
    let instanceName: String
    let symbol: String
}

/// Fetches and normalizes calendar entries from Sonarr/Radarr (and compatible apps).
enum CalendarService {
    static func fetch(
        instance: ServiceInstance,
        credential: AuthCredential,
        start: Date,
        end: Date
    ) async throws -> [CalendarEntry] {
        let core = ServarrClient(instance: instance, credential: credential)
        let endpoint = Endpoint(
            path: core.basePath + "/calendar",
            query: [
                URLQueryItem(name: "start", value: ISO8601DateFormatter.plain.string(from: start)),
                URLQueryItem(name: "end", value: ISO8601DateFormatter.plain.string(from: end)),
                URLQueryItem(name: "unmonitored", value: "true"),
                URLQueryItem(name: "includeSeries", value: "true"),
            ]
        )
        let data = try await core.api.send(endpoint)
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { object in
            guard let date = extractDate(object) else { return nil }
            return CalendarEntry(
                date: date,
                title: title(for: object, type: instance.type),
                subtitle: subtitle(for: object, type: instance.type),
                instanceName: instance.name,
                symbol: instance.type.symbolName
            )
        }
    }

    private static func extractDate(_ object: [String: Any]) -> Date? {
        let keys = ["airDateUtc", "digitalRelease", "inCinemas", "physicalRelease", "releaseDate"]
        for key in keys {
            guard let string = object[key] as? String else { continue }
            if let date = ISO8601DateFormatter.withFractional.date(from: string)
                ?? ISO8601DateFormatter.plain.date(from: string)
                ?? dayOnlyFormatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static func title(for object: [String: Any], type: ServiceType) -> String {
        if type == .sonarr, let series = object["series"] as? [String: Any],
           let name = series["title"] as? String {
            return name
        }
        return (object["title"] as? String) ?? "Untitled"
    }

    private static func subtitle(for object: [String: Any], type: ServiceType) -> String {
        if type == .sonarr,
           let season = object["seasonNumber"] as? Int,
           let episode = object["episodeNumber"] as? Int {
            let ep = object["title"] as? String ?? ""
            return String(format: "S%02dE%02d  %@", season, episode, ep)
        }
        if let year = object["year"] as? Int { return String(year) }
        return ""
    }

    private static let dayOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
