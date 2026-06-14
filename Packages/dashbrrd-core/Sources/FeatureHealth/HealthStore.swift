import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for aggregated health. Sorts checks worst-first so the
/// most urgent issues lead.
@MainActor
@Observable
public final class HealthStore {
    public private(set) var state: LoadState<[HealthCheck]> = .idle
    public private(set) var failures: [InstanceFailure] = []

    private let loader: any HealthLoading

    public init(loader: any HealthLoading) {
        self.loader = loader
    }

    public func load() async {
        if state.value == nil { state = .loading }
        let result = await loader.loadHealth()
        failures = result.failures
        state = .loaded(result.checks.sorted { $0.severity.rank > $1.severity.rank })
    }

    /// Count of checks at warning or error severity (drives the dashboard badge).
    public var problemCount: Int {
        (state.value ?? []).filter { $0.severity == .warning || $0.severity == .error }.count
    }
}

extension HealthCheck.Severity {
    /// Sort weight, worst-first.
    var rank: Int {
        switch self {
        case .error: 3
        case .warning: 2
        case .notice: 1
        case .ok: 0
        }
    }
}
