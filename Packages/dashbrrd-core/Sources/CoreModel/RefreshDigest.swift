import Foundation

/// Persisted snapshot of the last-seen queue state (item id → state raw value). Compared
/// against a fresh fetch to detect completions/failures. Tiny + Codable so it survives in
/// lightweight storage and is cheap to write from a background task.
public struct QueueDigest: Codable, Sendable, Equatable {
    public var states: [String: String]
    public init(states: [String: String] = [:]) { self.states = states }
}

/// Persisted snapshot of the last-seen health (check id → severity raw value).
public struct HealthDigest: Codable, Sendable, Equatable {
    public var severities: [String: String]
    public init(severities: [String: String] = [:]) { self.severities = severities }
}

/// A notification the diff engine wants surfaced. `threadID` groups by instance.
public struct RefreshNotification: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var body: String
    public var threadID: String

    public init(id: String, title: String, body: String, threadID: String) {
        self.id = id
        self.title = title
        self.body = body
        self.threadID = threadID
    }
}
