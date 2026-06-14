import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureQueue

/// Live manual import: enumerates Sonarr/Radarr instances, lists their queue downloads, fetches
/// import candidates, and performs the import.
struct LiveManualImporter: ManualImporting {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    enum ImportError: LocalizedError {
        case instanceUnavailable
        var errorDescription: String? {
            switch self { case .instanceUnavailable: "That server is unavailable." }
        }
    }

    func instances() async -> [ImportTarget] {
        await MainActor.run {
            let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
            let configs = (try? repository.allConfigs()) ?? []
            return configs
                .filter { $0.isEnabled && ($0.kind == .sonarr || $0.kind == .radarr) }
                .map { ImportTarget(id: $0.id, name: $0.displayName, kind: $0.kind) }
        }
    }

    func pendingDownloads(_ target: ImportTarget) async throws -> [QueueItem] {
        let profile = try await requireProfile(target.id)
        return try await ServarrRegistry.queue(kind: target.kind, profile: profile)
    }

    func candidates(_ target: ImportTarget, downloadID: String) async throws -> [ManualImportCandidate] {
        let profile = try await requireProfile(target.id)
        return try await ServarrRegistry.manualImportCandidates(kind: target.kind, profile: profile, downloadID: downloadID)
    }

    func performImport(_ target: ImportTarget, payloads: [Data], mode: String) async throws {
        let profile = try await requireProfile(target.id)
        try await ServarrRegistry.manualImport(kind: target.kind, profile: profile, payloads: payloads, importMode: mode)
    }

    private func requireProfile(_ instanceID: InstanceID) async throws -> ConnectionProfile {
        guard let profile = await profile(for: instanceID) else { throw ImportError.instanceUnavailable }
        return profile
    }

    @MainActor
    private func profile(for instanceID: InstanceID) -> ConnectionProfile? {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        guard let config = (try? repository.allConfigs())?.first(where: { $0.id == instanceID }) else { return nil }
        return try? repository.connectionProfile(for: config)
    }
}
