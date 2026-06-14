import Foundation
import SwiftData
import CoreModel
import Networking
import DownloadClientKit
import PersistenceKit
import FeatureQueue

/// Dispatches queue actions to the correct download client. Only download-client items are
/// controllable here (Servarr-side queue items are read-only in the unified view).
struct LiveQueueController: QueueControlling {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    enum ControlError: LocalizedError {
        case notControllable
        case clientUnavailable

        var errorDescription: String? {
            switch self {
            case .notControllable: "This item can't be controlled from here."
            case .clientUnavailable: "The download client is unavailable."
            }
        }
    }

    private func client(for item: QueueItem) async throws -> any DownloadClient {
        guard item.serviceKind.isDownloadClient else { throw ControlError.notControllable }
        let profile = try await profile(for: item.instanceID)
        guard let profile,
              let client = DownloadClientFactory.make(kind: item.serviceKind, instanceID: item.instanceID, profile: profile) else {
            throw ControlError.clientUnavailable
        }
        return client
    }

    @MainActor
    private func profile(for instanceID: InstanceID) -> ConnectionProfile? {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        guard let config = (try? repository.allConfigs())?.first(where: { $0.id == instanceID }) else { return nil }
        return try? repository.connectionProfile(for: config)
    }

    func pause(_ item: QueueItem) async throws {
        try await client(for: item).pause(item.downloadID)
    }

    func resume(_ item: QueueItem) async throws {
        try await client(for: item).resume(item.downloadID)
    }

    func remove(_ item: QueueItem, deleteData: Bool) async throws {
        try await client(for: item).remove(item.downloadID, deleteData: deleteData)
    }
}
