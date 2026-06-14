import SwiftUI
import SwiftData
import AppCore

/// `@main` entry point and composition wiring. Owns the `AppContainer` for the app's
/// lifetime, registers the background-refresh task at launch (required before launch
/// completes), schedules it when backgrounded, and reconciles fully when foregrounded.
@main
struct DashbrrdApp: App {
    @State private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppContainer()
        _container = State(initialValue: container)
        // BGTaskScheduler requires handlers be registered before the app finishes launching.
        container.services.refreshCoordinator.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootScene(services: container.services)
                .environment(container)
                .task {
                    await container.services.refreshCoordinator.requestNotificationAuthorization()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        container.services.refreshCoordinator.scheduleNext()
                    case .active:
                        Task { await container.services.refreshCoordinator.refreshNow() }
                    default:
                        break
                    }
                }
        }
        .modelContainer(container.modelContainer)
    }
}
