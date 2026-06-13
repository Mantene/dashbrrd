import Foundation

/// The single typed error surface for all network operations.
///
/// Cases are deliberately specific so the connection-test UX can pivot precisely:
/// `unauthorized` → "API key rejected", `notFound` → "reachable but no API here —
/// check base path", `untrustedCertificate` → pin-cert sheet. `decoding` keeps the raw
/// body so version-skew against a user's *arr build stays diagnosable.
public enum APIError: Error, Sendable, Equatable {
    /// Could not reach the host (DNS/connection/timeout). Carries a human message.
    case transport(String)
    /// TLS trust failed; carries the leaf fingerprint so the UI can offer to pin it.
    case untrustedCertificate(fingerprint: String)
    case unauthorized
    case forbidden
    case notFound
    /// Non-2xx response with a status code and (possibly truncated) body.
    case server(status: Int, body: String?)
    /// Decoding failed; `raw` is the undecoded body for diagnostics.
    case decoding(String, raw: String?)
    /// The request was cancelled by the caller.
    case clientCancelled
    /// The `URLBuilder` could not assemble a valid URL from the profile + endpoint.
    case invalidURL
}

extension APIError {
    /// Maps a non-2xx HTTP status to the most specific case.
    public static func from(status: Int, body: String?) -> APIError {
        switch status {
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        default: .server(status: status, body: body)
        }
    }
}
