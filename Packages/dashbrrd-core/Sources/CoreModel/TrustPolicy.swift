import Foundation

/// How TLS server trust is evaluated for a given instance.
///
/// Self-hosted *arr stacks routinely use self-signed certificates. Rather than a
/// blanket "allow insecure" switch, dashbrrd defaults to **pinning** the exact leaf
/// certificate the user first connected to — strong protection against MITM while
/// still working without a public CA.
///
/// This is a pure value type so `ServerConfig` (in `CoreModel`) can store it without
/// depending on `Networking`, where the actual `TrustEvaluator` lives.
public enum TrustPolicy: Sendable, Hashable, Codable {
    /// Standard system trust evaluation (valid CA chain required).
    case system

    /// Pin a specific leaf certificate by its SHA-256 fingerprint (lowercase hex,
    /// colon-free). Captured on first connect, shown to the user, then trusted.
    case pinnedSelfSigned(sha256: String)

    /// Accept any server certificate. Explicitly insecure escape hatch — the UI must
    /// surface a persistent warning when this is active.
    case allowSelfSigned
}
