import SwiftUI
import CoreModel
import DesignSystem

/// Phase 0 placeholder root for Settings (add/manage servers, connection test, cert pin).
/// Phase 1 fills in the add-server flow — the first feature to write real config + secrets.
public struct SettingsScreen: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "gearshape",
            description: Text("Add and manage your *arr and download-client servers.")
        )
    }
}
