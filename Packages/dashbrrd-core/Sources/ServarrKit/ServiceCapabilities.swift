import Foundation

/// The set of feature surfaces a given service supports.
///
/// Generic feature UI consults this to gray out unsupported actions — e.g. Prowlarr
/// exposes indexers + health but has no calendar or library, so its descriptor simply
/// omits those flags and the aggregated Calendar skips it.
public struct ServiceCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let systemStatus  = ServiceCapabilities(rawValue: 1 << 0)
    public static let health        = ServiceCapabilities(rawValue: 1 << 1)
    public static let calendar      = ServiceCapabilities(rawValue: 1 << 2)
    public static let queue         = ServiceCapabilities(rawValue: 1 << 3)
    public static let library       = ServiceCapabilities(rawValue: 1 << 4)
    public static let releaseSearch = ServiceCapabilities(rawValue: 1 << 5)
    public static let manualImport  = ServiceCapabilities(rawValue: 1 << 6)
    public static let history       = ServiceCapabilities(rawValue: 1 << 7)
    public static let indexers      = ServiceCapabilities(rawValue: 1 << 8)

    /// Convenience: everything a typical media-managing *arr (Sonarr/Radarr) supports.
    public static let mediaManager: ServiceCapabilities = [
        .systemStatus, .health, .calendar, .queue, .library,
        .releaseSearch, .manualImport, .history,
    ]
}
