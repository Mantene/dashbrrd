import Foundation
import CoreModel

/// Translates Sonarr wire DTOs into the app's normalized `CoreModel` types. Keeping this
/// in one place is what lets the UI stay ignorant of Sonarr's schema (and what makes
/// upstream schema drift a single-file change).
enum SonarrMapper {
    /// Maps a calendar episode to a normalized `CalendarEntry`. Returns `nil` for episodes
    /// without an air date (nothing to place on a timeline).
    static func calendarEntry(from dto: SonarrCalendarItemDTO, instanceID: InstanceID) -> CalendarEntry? {
        guard let airDate = dto.airDateUtc else { return nil }
        let code = String(format: "S%02dE%02d", dto.seasonNumber, dto.episodeNumber)
        let showTitle = dto.series?.title ?? "Unknown Series"
        return CalendarEntry(
            id: "\(instanceID.rawValue.uuidString):\(dto.id)",
            instanceID: instanceID,
            serviceKind: .sonarr,
            title: showTitle,
            subtitle: "\(code) · \(dto.title)",
            airDate: airDate,
            hasFile: dto.hasFile
        )
    }
}
