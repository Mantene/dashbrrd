import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureHealth

/// Fans out `health` across every enabled, health-capable instance and merges the results,
/// with first-class partial failure (an unreachable server becomes a chip, not a blank view).
struct HealthAggregator: HealthLoading {
    private let container: ModelContainer
    private let keychain: KeychainStore

    init(container: ModelContainer, keychain: KeychainStore) {
        self.container = container
        self.keychain = keychain
    }

    private struct Target: Sendable {
        let config: ServerConfig
        let profile: ConnectionProfile
    }

    private enum Outcome: Sendable {
        case success([HealthCheck])
        case failure(id: InstanceID, name: String, message: String)
    }

    func loadHealth() async -> HealthResult {
        let targets = await gatherTargets()
        guard !targets.isEmpty else { return HealthResult(checks: [], failures: []) }

        var checks: [HealthCheck] = []
        var failures: [InstanceFailure] = []

        await withTaskGroup(of: Outcome.self) { group in
            for target in targets {
                group.addTask {
                    do {
                        let result = try await ServarrRegistry.health(kind: target.config.kind, profile: target.profile)
                        return .success(result)
                    } catch {
                        return .failure(id: target.config.id, name: target.config.displayName, message: Self.describe(error))
                    }
                }
            }
            for await outcome in group {
                switch outcome {
                case let .success(loaded): checks.append(contentsOf: loaded)
                case let .failure(id, name, message): failures.append(InstanceFailure(id: id, displayName: name, message: message))
                }
            }
        }
        return HealthResult(checks: checks, failures: failures)
    }

    @MainActor
    private func gatherTargets() -> [Target] {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        let configs = (try? repository.allConfigs()) ?? []
        return configs
            .filter { $0.isEnabled && ServarrRegistry.capabilities(for: $0.kind).contains(.health) }
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
