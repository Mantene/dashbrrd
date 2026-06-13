import Foundation
import CoreModel
import Networking

/// The generic Servarr engine: one actor that serves every *arr by being parameterized
/// over a `ServarrDescriptor` and driven by an injected `HTTPClientProtocol`.
///
/// Phase 0 wires the structure and the cheapest identity endpoint (`system/status`,
/// used by the connection test). Subsequent phases fill in calendar/queue/library/etc.,
/// each mapping wire DTOs into `CoreModel` value types.
public actor ServarrClient<Descriptor: ServarrDescriptor> {
    public let descriptor: Descriptor
    public let instanceID: InstanceID
    private let http: HTTPClientProtocol

    public init(descriptor: Descriptor, instanceID: InstanceID, http: HTTPClientProtocol) {
        self.descriptor = descriptor
        self.instanceID = instanceID
        self.http = http
    }

    public var capabilities: ServiceCapabilities { descriptor.capabilities }

    /// Cheap identity probe used by Test Connection and to read the running version.
    public func systemStatus() async throws -> SystemStatus {
        let dto = try await http.send(Endpoint(path: "system/status"), as: SystemStatusDTO.self)
        return SystemStatus(
            instanceID: instanceID,
            version: dto.version,
            appName: dto.appName ?? descriptor.kind.displayName
        )
    }
}

/// Minimal wire shape for `system/status`. Real per-app DTOs live under `Apps/<Name>/`
/// from Phase 1 onward; this shared subset is enough for the identity probe.
struct SystemStatusDTO: Decodable, Sendable {
    let version: String
    let appName: String?
}
