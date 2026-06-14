import Foundation
import SwiftUI
import SwiftData
import Observation
import CoreModel
import PersistenceKit
import AppCore

/// The composition root. The single place that constructs concrete infrastructure
/// (the persistent SwiftData container, the Keychain store) and exposes protocol- or
/// value-typed seams to the rest of the app. Everything below stays injectable.
@MainActor
@Observable
public final class AppContainer {
    public let modelContainer: ModelContainer
    public let keychain: KeychainStore
    public let services: AppServices

    public init() {
        // Bump the shared URL cache so AsyncImage poster loads (URLSession.shared) are cached
        // across scrolls and launches instead of refetching.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1_024 * 1_024, diskCapacity: 512 * 1_024 * 1_024)

        let container: ModelContainer
        do {
            let schema = Schema([ServerConfigModel.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failure here means the on-disk store is corrupt/incompatible. Because the
            // cache is disposable and config is re-enterable, a real build would rebuild
            // from scratch; during scaffolding we fail loudly.
            fatalError("Failed to construct ModelContainer: \(error)")
        }
        let keychain = KeychainStore(service: "com.dashbrrd.secrets")
        self.modelContainer = container
        self.keychain = keychain
        self.services = AppServices(container: container, keychain: keychain)
    }
}
