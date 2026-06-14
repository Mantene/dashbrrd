import Foundation
import CoreModel
import Networking

/// Builds a fully-wired `ServarrClient` from a descriptor and a resolved `ConnectionProfile`.
///
/// This is the assembly point that turns config + secrets into a live engine: it derives
/// the API prefix from the descriptor, builds the interceptor chain from the profile's
/// credentials, and constructs the trust-evaluating `HTTPClient`.
public enum ServarrClientFactory {
    public static func make<D: ServarrDescriptor>(
        descriptor: D,
        profile: ConnectionProfile
    ) -> ServarrClient<D> {
        let http = HTTPClient(
            profile: profile,
            apiPrefix: descriptor.apiPrefix,
            interceptors: profile.requestInterceptors()
        )
        return ServarrClient(descriptor: descriptor, instanceID: profile.instanceID, http: http)
    }
}
