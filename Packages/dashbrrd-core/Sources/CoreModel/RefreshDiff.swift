import Foundation

/// Pure diff engine: compares a persisted digest against a fresh fetch and returns the
/// notifications worth surfacing plus the new digest to persist. No I/O, no platform APIs —
/// fully unit-testable. An empty prior digest establishes a baseline (no notifications).
public enum RefreshDiff {

    public static func queue(previous: QueueDigest, current: [QueueItem]) -> (notifications: [RefreshNotification], digest: QueueDigest) {
        var newStates: [String: String] = [:]
        var notes: [RefreshNotification] = []
        let baseline = previous.states.isEmpty

        for item in current {
            newStates[item.id] = item.state.rawValue
            guard !baseline else { continue }
            let prev = previous.states[item.id]
            let thread = item.instanceID.rawValue.uuidString
            switch item.state {
            case .completed where prev != nil && prev != QueueState.completed.rawValue:
                notes.append(RefreshNotification(id: "q-done-\(item.id)", title: "Download complete", body: item.name, threadID: thread))
            case .error where prev != QueueState.error.rawValue:
                notes.append(RefreshNotification(id: "q-fail-\(item.id)", title: "Download failed", body: item.name, threadID: thread))
            default:
                break
            }
        }
        return (notes, QueueDigest(states: newStates))
    }

    public static func health(previous: HealthDigest, current: [HealthCheck]) -> (notifications: [RefreshNotification], digest: HealthDigest) {
        var newSeverities: [String: String] = [:]
        var notes: [RefreshNotification] = []
        let baseline = previous.severities.isEmpty

        for check in current {
            newSeverities[check.id] = check.severity.rawValue
            guard !baseline, check.severity == .warning || check.severity == .error else { continue }
            let prev = previous.severities[check.id]
            let wasProblem = prev == HealthCheck.Severity.warning.rawValue || prev == HealthCheck.Severity.error.rawValue
            if !wasProblem {
                notes.append(RefreshNotification(
                    id: "h-\(check.id)",
                    title: check.severity == .error ? "Health error" : "Health warning",
                    body: check.message,
                    threadID: check.instanceID.rawValue.uuidString
                ))
            }
        }
        return (notes, HealthDigest(severities: newSeverities))
    }
}
