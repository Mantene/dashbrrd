import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for the unified Calendar feature. Phase 1 replaces the body
/// with a real timeline backed by a degenerate (N=1) `CalendarAggregator`.
public struct CalendarScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Calendar",
            systemImage: NavigationPlaceholder.symbol,
            description: Text("Add a Sonarr or Radarr server to see upcoming releases.")
        )
    }
}

/// Shared tiny helper so feature placeholders stay consistent during scaffolding.
enum NavigationPlaceholder {
    static let symbol = "calendar"
}
