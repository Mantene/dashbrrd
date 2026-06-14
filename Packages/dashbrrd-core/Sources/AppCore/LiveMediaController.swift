import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureLibrary

/// Dispatches media edit/delete to the owning Servarr instance.
struct LiveMediaController: MediaControlling {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    enum ControlError: LocalizedError {
        case instanceUnavailable
        var errorDescription: String? {
            switch self {
            case .instanceUnavailable: "The server for this item is unavailable."
            }
        }
    }

    func setMonitored(_ item: MediaItem, monitored: Bool) async throws {
        let profile = try await requireProfile(item.instanceID)
        try await ServarrRegistry.setMonitored(kind: item.serviceKind, profile: profile, remoteID: item.remoteID, monitored: monitored)
    }

    func delete(_ item: MediaItem, deleteFiles: Bool) async throws {
        let profile = try await requireProfile(item.instanceID)
        try await ServarrRegistry.deleteMedia(kind: item.serviceKind, profile: profile, remoteID: item.remoteID, deleteFiles: deleteFiles)
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
