import SwiftUI
import Observation
import CoreModel

/// The single source of truth for app navigation, shared by both the compact `TabView`
/// and the regular-width `NavigationSplitView` so state survives rotation / split-resize
/// and deep links (from notifications) land identically in either layout.
@MainActor
@Observable
public final class NavigationModel {
    /// The feature-first top-level sections (service-second is the whole point of aggregation).
    public enum Section: String, CaseIterable, Identifiable, Hashable {
        case dashboard
        case calendar
        case queue
        case library
        case activity
        case settings

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .dashboard: "Dashboard"
            case .calendar: "Calendar"
            case .queue: "Queue"
            case .library: "Library"
            case .activity: "Activity"
            case .settings: "Settings"
            }
        }

        public var symbolName: String {
            switch self {
            case .dashboard: "square.grid.2x2"
            case .calendar: "calendar"
            case .queue: "arrow.down.circle"
            case .library: "rectangle.stack"
            case .activity: "clock.arrow.circlepath"
            case .settings: "gearshape"
            }
        }
    }

    /// The selected top-level section (sidebar selection / selected tab).
    public var selectedSection: Section = .dashboard

    /// Per-section navigation stacks, so each tab/detail column keeps its own history.
    public var paths: [Section: NavigationPath] = [:]

    public init() {}

    public func path(for section: Section) -> NavigationPath {
        paths[section] ?? NavigationPath()
    }

    public func setPath(_ path: NavigationPath, for section: Section) {
        paths[section] = path
    }
}
