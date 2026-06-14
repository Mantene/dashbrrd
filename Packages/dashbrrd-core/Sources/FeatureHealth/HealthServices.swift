import Foundation
import CoreModel

/// Aggregated health across every reachable instance, plus per-instance failures.
public struct HealthResult: Sendable {
    public var checks: [HealthCheck]
    public var failures: [InstanceFailure]

    public init(checks: [HealthCheck], failures: [InstanceFailure]) {
        self.checks = checks
        self.failures = failures
    }
}

/// Loads + merges health across instances. Implemented by `AppCore.HealthAggregator`.
public protocol HealthLoading: Sendable {
    func loadHealth() async -> HealthResult
}
