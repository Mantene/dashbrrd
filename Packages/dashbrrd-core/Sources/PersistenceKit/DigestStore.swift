import Foundation
import CoreModel

/// Persists the background-refresh digests. Uses `UserDefaults` (JSON-encoded) rather than
/// SwiftData: digests are tiny, must be readable/writable from a background task with minimal
/// ceremony, and are disposable (a lost digest just re-establishes a baseline).
public struct DigestStore: Sendable {
    // UserDefaults is documented thread-safe but not yet marked Sendable.
    nonisolated(unsafe) private let defaults: UserDefaults
    private let queueKey = "dashbrrd.digest.queue"
    private let healthKey = "dashbrrd.digest.health"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadQueue() -> QueueDigest {
        decode(queueKey) ?? QueueDigest()
    }

    public func loadHealth() -> HealthDigest {
        decode(healthKey) ?? HealthDigest()
    }

    public func save(queue: QueueDigest) {
        encode(queue, key: queueKey)
    }

    public func save(health: HealthDigest) {
        encode(health, key: healthKey)
    }

    private func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
