import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureLibrary

/// Live add-new-media: enumerates Sonarr/Radarr instances, runs lookup, fetches options, adds.
struct LiveMediaAdder: MediaAdding {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    enum AddError: LocalizedError {
        case instanceUnavailable
        var errorDescription: String? {
            switch self { case .instanceUnavailable: "That server is unavailable." }
        }
    }

    func addableInstances() async -> [AddTarget] {
        await MainActor.run {
            let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
            let configs = (try? repository.allConfigs()) ?? []
            return configs
                .filter { $0.isEnabled && ($0.kind == .sonarr || $0.kind == .radarr) }
                .map { AddTarget(id: $0.id, name: $0.displayName, kind: $0.kind) }
        }
    }

    func lookup(_ target: AddTarget, term: String) async throws -> [MediaLookupItem] {
        let profile = try await requireProfile(target.id)
        return try await ServarrRegistry.lookup(kind: target.kind, profile: profile, term: term)
    }

    func options(_ target: AddTarget) async throws -> AddOptions {
        let profile = try await requireProfile(target.id)
        async let profiles = ServarrRegistry.qualityProfiles(kind: target.kind, profile: profile)
        async let folders = ServarrRegistry.rootFolders(kind: target.kind, profile: profile)
        return AddOptions(qualityProfiles: try await profiles, rootFolders: try await folders)
    }

    func add(_ item: MediaLookupItem, to target: AddTarget, qualityProfileID: Int, rootFolderPath: String, monitored: Bool, searchOnAdd: Bool) async throws {
        let profile = try await requireProfile(target.id)
        try await ServarrRegistry.addMedia(
            kind: target.kind, profile: profile, payload: item.rawPayload,
            qualityProfileID: qualityProfileID, rootFolderPath: rootFolderPath,
            monitored: monitored, searchOnAdd: searchOnAdd
        )
    }

    private func requireProfile(_ instanceID: InstanceID) async throws -> ConnectionProfile {
        guard let profile = await profile(for: instanceID) else { throw AddError.instanceUnavailable }
        return profile
    }

    @MainActor
    private func profile(for instanceID: InstanceID) -> ConnectionProfile? {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        guard let config = (try? repository.allConfigs())?.first(where: { $0.id == instanceID }) else { return nil }
        return try? repository.connectionProfile(for: config)
    }
}
