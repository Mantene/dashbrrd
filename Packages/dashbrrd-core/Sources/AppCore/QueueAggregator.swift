import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import DownloadClientKit
import PersistenceKit
import FeatureQueue

/// Fans out across every queue-capable Servarr instance AND every download client, returning
/// the union (the store dedups via `QueueItem.merged`). First-class partial failure.
struct QueueAggregator: QueueLoading {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    private struct Target: Sendable {
        let config: ServerConfig
        let profile: ConnectionProfile
        let isDownloadClient: Bool
    }

    private enum Outcome: Sendable {
        case success([QueueItem])
        case failure(id: InstanceID, name: String, message: String)
    }

    func loadQueue() async -> QueueResult {
        let targets = await gatherTargets()
        guard !targets.isEmpty else { return QueueResult(items: [], failures: []) }

        var items: [QueueItem] = []
        var failures: [InstanceFailure] = []

        await withTaskGroup(of: Outcome.self) { group in
            for target in targets {
                group.addTask {
                    do {
                        let loaded: [QueueItem]
                        if target.isDownloadClient {
                            loaded = try await DownloadClientFactory
                                .make(kind: target.config.kind, instanceID: target.config.id, profile: target.profile)?
                                .queue() ?? []
                        } else {
                            loaded = try await ServarrRegistry.queue(kind: target.config.kind, profile: target.profile)
                        }
                        return .success(loaded)
                    } catch {
                        return .failure(id: target.config.id, name: target.config.displayName, message: Self.describe(error))
                    }
                }
            }
            for await outcome in group {
                switch outcome {
                case let .success(loaded): items.append(contentsOf: loaded)
                case let .failure(id, name, message): failures.append(InstanceFailure(id: id, displayName: name, message: message))
                }
            }
        }
        return QueueResult(items: items, failures: failures)
    }

    @MainActor
    private func gatherTargets() -> [Target] {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        let configs = (try? repository.allConfigs()) ?? []
        return configs.compactMap { config -> Target? in
            guard config.isEnabled else { return nil }
            let isClient = DownloadClientFactory.isSupported(config.kind)
            let isQueueServarr = ServarrRegistry.capabilities(for: config.kind).contains(.queue)
            guard isClient || isQueueServarr else { return nil }
            guard let profile = try? repository.connectionProfile(for: config) else { return nil }
            return Target(config: config, profile: profile, isDownloadClient: isClient)
        }
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
