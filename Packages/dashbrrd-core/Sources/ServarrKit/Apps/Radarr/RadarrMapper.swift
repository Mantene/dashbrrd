import Foundation
import CoreModel

/// Translates Radarr movie DTOs into normalized `CoreModel.CalendarEntry`, absorbing the
/// movie-vs-episode difference so the unified Calendar UI stays service-agnostic.
enum RadarrMapper {
    static func calendarEntry(from dto: RadarrCalendarItemDTO, instanceID: InstanceID) -> CalendarEntry? {
        guard let date = dto.releaseDate else { return nil }
        let yearSuffix = dto.year.map { " (\($0))" } ?? ""
        return CalendarEntry(
            id: "\(instanceID.rawValue.uuidString):\(dto.id)",
            instanceID: instanceID,
            serviceKind: .radarr,
            title: dto.title + yearSuffix,
            subtitle: dto.releaseLabel,
            airDate: date,
            hasFile: dto.hasFile
        )
    }
}
