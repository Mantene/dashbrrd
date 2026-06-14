import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureHistory

/// Loads page `n` of history from every history-capable instance and merges them. Page
/// boundaries are per-instance, so this is an "activity feed" merge (good enough), not a
/// globally-exact pagination. `hasMore` is true if any instance still has more pages.
struct HistoryAggregator: HistoryLoading {
    private let container: ModelContainer
    private let keychain: KeychainStore
    private let pageSize = 50

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    private struct Target: Sendable {
        let config: ServerConfig
        let profile: ConnectionProfile
    }

    private enum Outcome: Sendable {
        case success(records: [HistoryRecord], hasMore: Bool)
        case failure(id: InstanceID, name: String, message: String)
    }

    func loadHistory(page: Int) async -> HistoryResult {
        let targets = await gatherTargets()
        guard !targets.isEmpty else { return HistoryResult(records: [], hasMore: false, failures: []) }

        var records: [HistoryRecord] = []
        var failures: [InstanceFailure] = []
        var anyMore = false

        await withTaskGroup(of: Outcome.self) { group in
            for target in targets {
                group.addTask {
                    do {
                        let pageResult = try await ServarrRegistry.history(
                            kind: target.config.kind,
                            profile: target.profile,
                            request: PagedRequest(page: page, pageSize: pageSize, sortKey: "date", sortDirection: .descending)
                        )
                        return .success(records: pageResult.records, hasMore: pageResult.hasMore)
                    } catch {
                        return .failure(id: target.config.id, name: target.config.displayName, message: Self.describe(error))
                    }
                }
            }
            for await outcome in group {
                switch outcome {
                case let .success(loaded, more):
                    records.append(contentsOf: loaded)
                    anyMore = anyMore || more
                case let .failure(id, name, message):
                    failures.append(InstanceFailure(id: id, displayName: name, message: message))
                }
            }
        }
        return HistoryResult(records: records, hasMore: anyMore, failures: failures)
    }

    @MainActor
    private func gatherTargets() -> [Target] {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        let configs = (try? repository.allConfigs()) ?? []
        return configs
            .filter { $0.isEnabled && ServarrRegistry.capabilities(for: $0.kind).contains(.history) }
            .compactMap { config in
                guard let profile = try? repository.connectionProfile(for: config) else { return nil }
                return Target(config: config, profile: profile)
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
