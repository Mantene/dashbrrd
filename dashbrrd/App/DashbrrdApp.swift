import SwiftUI

@main
struct DashbrrdApp: App {
    @State private var configStore = ConfigStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(configStore)
        }
    }
}
