import Foundation
import CoreModel

/// Describes how one Servarr app differs from the shared engine surface.
///
/// Implementing a new *arr means writing a value conforming to this protocol (plus its
/// DTOs and a mapper) in a single folder under `Apps/`. The generic `ServarrClient` is
/// parameterized by a descriptor and needs nothing else to talk to it.
public protocol ServarrDescriptor: Sendable {
    var kind: ServiceKind { get }
    var apiVersion: ServarrAPIVersion { get }
    var capabilities: ServiceCapabilities { get }
}

extension ServarrDescriptor {
    /// URL path prefix derived from the API version (e.g. `"api/v3"`).
    public var apiPrefix: String { apiVersion.pathPrefix }
}
