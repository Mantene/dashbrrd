import SwiftUI
import SwiftData
import AppCore

/// `@main` entry point and composition wiring. Owns the `AppContainer` for the app's
/// lifetime and injects its persistent `ModelContainer` into the SwiftUI environment so
/// feature views can `@Query` config and the background task can write the cache.
@main
struct DashbrrdApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootScene()
                .environment(container)
        }
        .modelContainer(container.modelContainer)
    }
}
