import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for the unified Queue (Servarr queues + SAB/qBit, deduped).
public struct QueueScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Queue",
            systemImage: "arrow.down.circle",
            description: Text("Active downloads across your servers will appear here.")
        )
    }
}
