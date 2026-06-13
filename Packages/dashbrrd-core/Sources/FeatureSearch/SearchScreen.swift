import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for interactive release search → grab/send-to-client.
public struct SearchScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Find releases and send them to a download client.")
        )
    }
}
