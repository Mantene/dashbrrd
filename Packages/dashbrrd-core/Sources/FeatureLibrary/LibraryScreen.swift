import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for the per-service Library browse (shared poster grids).
public struct LibraryScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Library",
            systemImage: "rectangle.stack",
            description: Text("Browse the media managed by each connected server.")
        )
    }
}
