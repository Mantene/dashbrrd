import SwiftUI
import AppCore

/// The app's root view. Thin by design: it hands off to `AppCore.RootView`, which picks
/// the adaptive container (tabs vs split) and owns the shared `NavigationModel` and stores.
struct RootScene: View {
    let services: AppServices

    var body: some View {
        RootView(services: services)
    }
}
