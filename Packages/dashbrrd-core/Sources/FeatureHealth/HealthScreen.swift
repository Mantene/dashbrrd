import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for the aggregated Health view.
public struct HealthScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Health",
            systemImage: "cross.case",
            description: Text("Health checks reported by each connected server.")
        )
    }
}
