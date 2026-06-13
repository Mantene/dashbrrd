import Foundation
import SwiftUI
import SwiftData
import Observation
import CoreModel
import PersistenceKit

/// The composition root. The single place that constructs concrete infrastructure
/// (the persistent SwiftData container, the Keychain store) and exposes protocol- or
/// value-typed seams to the rest of the app. Everything below stays injectable.
@MainActor
@Observable
public final class AppContainer {
    public let modelContainer: ModelContainer
    public let keychain: KeychainStore

    public init() {
        do {
            let schema = Schema([ServerConfigModel.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failure here means the on-disk store is corrupt/incompatible. Because the
            // cache is disposable and config is re-enterable, a real build would rebuild
            // from scratch; during scaffolding we fail loudly.
            fatalError("Failed to construct ModelContainer: \(error)")
        }
        self.keychain = KeychainStore(service: "com.dashbrrd.secrets")
    }

    /// Builds the config↔Keychain repository bound to the main-context.
    public func makeServerConfigRepository() -> ServerConfigRepository {
        ServerConfigRepository(context: modelContainer.mainContext, keychain: keychain)
    }
}
