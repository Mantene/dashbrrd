import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureLibrary

/// Lists library-capable instances and loads ONE at a time (large libraries make a merged
/// page unwieldy). Per-instance load keeps the UI snappy and memory bounded.
struct LibraryAggregator: LibraryLoading {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    func instances() async -> [LibraryInstance] {
        await MainActor.run {
            let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
            let configs = (try? repository.allConfigs()) ?? []
            return configs
                .filter { $0.isEnabled && ServarrRegistry.capabilities(for: $0.kind).contains(.library) }
                .map { LibraryInstance(id: $0.id, name: $0.displayName, kind: $0.kind) }
        }
    }

    func loadLibrary(_ instance: LibraryInstance) async -> LibraryResult {
        guard let profile = await profile(for: instance.id) else {
            return LibraryResult(items: [], failures: [
                InstanceFailure(id: instance.id, displayName: instance.name, message: "Unavailable")
            ])
        }
        do {
            let items = try await ServarrRegistry.library(kind: instance.kind, profile: profile)
            return LibraryResult(items: items, failures: [])
        } catch {
            return LibraryResult(items: [], failures: [
                InstanceFailure(id: instance.id, displayName: instance.name, message: Self.describe(error))
            ])
        }
    }

    @MainActor
    private func profile(for instanceID: InstanceID) -> ConnectionProfile? {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        guard let config = (try? repository.allConfigs())?.first(where: { $0.id == instanceID }) else { return nil }
        return try? repository.connectionProfile(for: config)
    }

    private static func describe(_ error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        switch apiError {
        case .unauthorized: return "API key rejected"
        case .untrustedCertificate: return "Untrusted certificate"
        case let .transport(message): return message
        case let .server(status, _): return "Server error \(status)"
        default: return "Request failed"
        }
    }
}
