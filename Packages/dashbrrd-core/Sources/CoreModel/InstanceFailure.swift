import Foundation

/// One instance's failure during a cross-instance fan-out. Surfaced as a per-instance chip
/// rather than blanking an aggregated view — partial failure is first-class throughout dashbrrd.
public struct InstanceFailure: Sendable, Identifiable, Hashable {
    public var id: InstanceID
    public var displayName: String
    public var message: String

    public init(id: InstanceID, displayName: String, message: String) {
        self.id = id
        self.displayName = displayName
        self.message = message
    }
}
