import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for paged History / Activity.
public struct HistoryScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Activity",
            systemImage: "clock.arrow.circlepath",
            description: Text("Grab, import, and failure history across your servers.")
        )
    }
}
