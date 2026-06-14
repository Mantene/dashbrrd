import Foundation
import SwiftData
import CoreModel
import Networking
import ServarrKit
import PersistenceKit
import FeatureCalendar

/// Loads + merges calendars across every enabled, calendar-capable instance. Today only
/// Sonarr qualifies (N=1), but the fan-out + partial-failure structure is already the
/// multi-instance shape Phase 2 needs — one dead server yields a failure chip, not a blank view.
struct CalendarAggregator: CalendarLoading {
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
        case success([CalendarEntry])
        case failure(id: InstanceID, name: String, message: String)
    }

    func loadCalendar(_ range: DateInterval) async -> CalendarResult {
        let targets = await gatherTargets()
        guard !targets.isEmpty else { return CalendarResult(entries: [], failures: []) }

        var entries: [CalendarEntry] = []
        var failures: [InstanceFailure] = []

        await withTaskGroup(of: Outcome.self) { group in
            for target in targets {
                group.addTask {
                    let client = ServarrClientFactory.make(descriptor: SonarrDescriptor(), profile: target.profile)
                    do {
                        return .success(try await client.calendar(range))
                    } catch {
                        return .failure(
                            id: target.config.id,
                            name: target.config.displayName,
                            message: Self.describe(error)
                        )
                    }
                }
            }
            for await outcome in group {
                switch outcome {
                case let .success(loaded):
                    entries.append(contentsOf: loaded)
                case let .failure(id, name, message):
                    failures.append(InstanceFailure(id: id, displayName: name, message: message))
                }
            }
        }

        entries.sort { $0.airDate < $1.airDate }
        return CalendarResult(entries: entries, failures: failures)
    }

    /// Resolve config + secrets on the main actor (SwiftData + Keychain), then hand
    /// `Sendable` snapshots to the concurrent network fan-out.
    @MainActor
    private func gatherTargets() -> [Target] {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        let configs = (try? repository.allConfigs()) ?? []
        return configs
            .filter { $0.isEnabled && $0.kind == .sonarr }
            .compactMap { config in
                guard let profile = try? repository.connectionProfile(for: config) else { return nil }
                return Target(config: config, profile: profile)
            }
    }

    private static func describe(_ error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        switch apiError {
        case .unauthorized: return "API key rejected"
        case .notFound: return "Calendar endpoint not found"
        case .untrustedCertificate: return "Untrusted certificate"
        case let .transport(message): return message
        case let .server(status, _): return "Server error \(status)"
        case .decoding: return "Unexpected response format"
        default: return "Request failed"
        }
    }
}
