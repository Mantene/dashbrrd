import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureLibrary

/// Interactive release search (read-only) + grab (sends to download client) against the
/// owning Servarr instance.
struct LiveReleaseController: ReleaseSearching, ReleaseGrabbing {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    enum ControlError: LocalizedError {
        case instanceUnavailable
        var errorDescription: String? {
            switch self { case .instanceUnavailable: "The server for this item is unavailable." }
        }
    }

    func search(_ item: MediaItem) async throws -> [Release] {
        let profile = try await requireProfile(item.instanceID)
        return try await ServarrRegistry.releaseSearch(kind: item.serviceKind, profile: profile, remoteID: item.remoteID)
    }

    func grab(_ release: Release) async throws {
        let profile = try await requireProfile(release.instanceID)
        try await ServarrRegistry.grab(kind: release.serviceKind, profile: profile, guid: release.guid, indexerID: release.indexerID)
    }

    private func requireProfile(_ instanceID: InstanceID) async throws -> ConnectionProfile {
        guard let profile = await profile(for: instanceID) else { throw ControlError.instanceUnavailable }
        return profile
    }

    @MainActor
    private func profile(for instanceID: InstanceID) -> ConnectionProfile? {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        guard let config = (try? repository.allConfigs())?.first(where: { $0.id == instanceID }) else { return nil }
        return try? repository.connectionProfile(for: config)
    }
}
