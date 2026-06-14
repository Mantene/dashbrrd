import Foundation
import CoreModel
import PersistenceKit
import FeatureSettings

/// Live `ServerStoring` backed by `PersistenceKit.ServerConfigRepository` (SwiftData config
/// + Keychain secrets). The one place a `ServerDraft` becomes a persisted instance.
@MainActor
final class LiveServerStore: ServerStoring {
    private let repository: ServerConfigRepository

    init(repository: ServerConfigRepository) {
        self.repository = repository
    }

    func load() throws -> [ServerConfig] {
        try repository.allConfigs()
    }

    func add(_ draft: ServerDraft) throws -> ServerConfig {
        let existing = (try? repository.allConfigs()) ?? []
        let config = ServerConfig(
            id: InstanceID(),
            kind: draft.kind,
            displayName: draft.displayName,
            scheme: draft.scheme,
            host: draft.host,
            port: draft.port,
            basePath: draft.basePath,
            useBasicAuth: false,
            trustPolicy: draft.trustPolicy,
            isEnabled: true,
            sortIndex: existing.count
        )
        try repository.save(config, apiKey: draft.apiKey.isEmpty ? nil : draft.apiKey)
        return config
    }

    func delete(_ config: ServerConfig) throws {
        try repository.delete(config)
    }
}

