import Foundation
import CryptoKit
import CoreModel

/// `URLSessionDelegate` that enforces a `TrustPolicy` during the TLS handshake.
///
/// For `.pinnedSelfSigned`, it computes the SHA-256 of the leaf certificate and compares
/// it to the stored fingerprint. For `.allowSelfSigned`, it accepts any server trust.
/// `.system` falls through to default evaluation. The fingerprint helper is also used by
/// the connection-test flow to show the user a cert to pin.
public final class TrustEvaluator: NSObject, URLSessionDelegate, Sendable {
    private let policy: TrustPolicy

    public init(policy: TrustPolicy) {
        self.policy = policy
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        switch policy {
        case .system:
            completionHandler(.performDefaultHandling, nil)

        case .allowSelfSigned:
            completionHandler(.useCredential, URLCredential(trust: serverTrust))

        case let .pinnedSelfSigned(expected):
            if let fingerprint = Self.leafFingerprint(of: serverTrust),
               fingerprint.caseInsensitiveCompare(expected) == .orderedSame {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }

    /// SHA-256 fingerprint (lowercase hex, no separators) of the leaf certificate.
    public static func leafFingerprint(of trust: SecTrust) -> String? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return nil
        }
        let der = SecCertificateCopyData(leaf) as Data
        let digest = SHA256.hash(data: der)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
