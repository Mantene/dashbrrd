import Foundation
import SwiftData
import CoreModel
import Networking

/// The seam that joins persisted config (SwiftData) with secrets (Keychain) into the
/// in-memory `ConnectionProfile` the networking layer consumes. Nothing else in the app
/// touches the Keychain or knows how a profile is assembled.
///
/// Phase 0 provides the assembly logic + CRUD shape; the `ModelContext` wiring is driven
/// by the `AppContainer` composition root.
@MainActor
public final class ServerConfigRepository {
    private let context: ModelContext
    private let keychain: KeychainStore

    public init(context: ModelContext, keychain: KeychainStore) {
        self.context = context
        self.keychain = keychain
    }

    // MARK: - Reads

    public func allConfigs() throws -> [ServerConfig] {
        let descriptor = FetchDescriptor<ServerConfigModel>(
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return try context.fetch(descriptor).compactMap { $0.toServerConfig() }
    }

    /// Assembles the runtime `ConnectionProfile` (with secrets) for one instance.
    public func connectionProfile(for config: ServerConfig) throws -> ConnectionProfile {
        var credentials: [ConnectionProfile.Credential] = []

        switch config.kind {
        case .sonarr, .radarr, .prowlarr, .lidarr, .readarr:
            // Servarr: X-Api-Key header.
            if let apiKey = try keychain.get(config.id, slot: .apiKey) {
                credentials.append(.apiKey(apiKey))
            }
        case .sabnzbd:
            // SABnzbd: ?apikey= query parameter.
            if let apiKey = try keychain.get(config.id, slot: .apiKey) {
                credentials.append(.queryParam(name: "apikey", value: apiKey))
            }
        case .qbittorrent:
            // qBittorrent uses a cookie session; on a LAN-bypassed setup no credential is
            // needed. (Login support for authenticated setups is a follow-up.)
            break
        }

        if config.useBasicAuth,
           let password = try keychain.get(config.id, slot: .basicAuthPassword) {
            // Username persistence arrives with the Phase 1 add-server form; placeholder for now.
            credentials.append(.basic(username: config.displayName, password: password))
        }

        return ConnectionProfile(
            instanceID: config.id,
            scheme: config.scheme,
            host: config.host,
            port: config.port,
            basePath: config.basePath,
            trustPolicy: config.trustPolicy,
            credentials: credentials
        )
    }

    // MARK: - Writes

    /// Persists config to SwiftData and the API key (if any) to the Keychain.
    public func save(_ config: ServerConfig, apiKey: String?) throws {
        let model = try ServerConfigModel.make(from: config)
        context.insert(model)
        try context.save()
        if let apiKey {
            try keychain.set(apiKey, for: config.id, slot: .apiKey)
        }
    }

    /// Cascade-deletes the config row and all Keychain secrets for an instance.
    public func delete(_ config: ServerConfig) throws {
        let id = config.id.rawValue
        let descriptor = FetchDescriptor<ServerConfigModel>(
            predicate: #Predicate { $0.id == id }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
        try keychain.deleteAll(for: config.id)
    }
}
