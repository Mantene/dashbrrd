import Foundation
import CoreModel
import Networking

/// Sonarr-specific calendar, exposed only when the client is specialized to Sonarr.
///
/// A constrained extension is the idiomatic way to attach app-specific endpoints to the
/// generic engine without polluting it: `ServarrClient<RadarrDescriptor>` simply won't
/// have this method, and the compiler enforces that.
extension ServarrClient where Descriptor == SonarrDescriptor {
    public func calendar(_ range: DateInterval) async throws -> [CalendarEntry] {
        let formatter = ISO8601DateFormatter()
        let endpoint = Endpoint(
            path: "calendar",
            query: [
                URLQueryItem(name: "start", value: formatter.string(from: range.start)),
                URLQueryItem(name: "end", value: formatter.string(from: range.end)),
                URLQueryItem(name: "includeSeries", value: "true"),
            ]
        )
        let dtos = try await httpClient.send(endpoint, as: [SonarrCalendarItemDTO].self)
        return dtos
            .compactMap { SonarrMapper.calendarEntry(from: $0, instanceID: instanceID) }
            .sorted { $0.airDate < $1.airDate }
    }
}
