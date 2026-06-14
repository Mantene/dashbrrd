import Foundation
import CoreModel
import Networking

/// Radarr-specific calendar, available only when the client is specialized to Radarr —
/// the same constrained-extension pattern as Sonarr, with movie semantics.
extension ServarrClient where Descriptor == RadarrDescriptor {
    public func calendar(_ range: DateInterval) async throws -> [CalendarEntry] {
        let formatter = ISO8601DateFormatter()
        let endpoint = Endpoint(
            path: "calendar",
            query: [
                URLQueryItem(name: "start", value: formatter.string(from: range.start)),
                URLQueryItem(name: "end", value: formatter.string(from: range.end)),
                URLQueryItem(name: "unmonitored", value: "false"),
            ]
        )
        let dtos = try await httpClient.send(endpoint, as: [RadarrCalendarItemDTO].self)
        return dtos
            .compactMap { RadarrMapper.calendarEntry(from: $0, instanceID: instanceID) }
            .sorted { $0.airDate < $1.airDate }
    }
}
