import SwiftUI
import AppCore

/// The app's root view. Thin by design: it hands off to `AppCore.RootView`, which picks
/// the adaptive container (tabs vs split) and owns the shared `NavigationModel`.
struct RootScene: View {
    var body: some View {
        RootView()
    }
}
