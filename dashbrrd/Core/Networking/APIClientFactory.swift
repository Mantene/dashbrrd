import Foundation

/// Builds a configured `APIClient` for an instance: a URLSession honoring the TLS policy, plus the
/// correct `Authenticator` for the service's auth scheme.
enum APIClientFactory {
    static func make(for instance: ServiceInstance, credential: AuthCredential) -> APIClient {
        let session = SessionProvider.session(allowInsecureTLS: instance.allowInsecureTLS)
        let authenticator = makeAuthenticator(
            for: instance, credential: credential, session: session
        )
        return APIClient(baseURL: instance.baseURL, session: session, authenticator: authenticator)
    }

    private static func makeAuthenticator(
        for instance: ServiceInstance,
        credential: AuthCredential,
        session: URLSession
    ) -> Authenticator {
        switch instance.type.authScheme {
        case let .apiKeyHeader(field):
            return HeaderKeyAuthenticator(field: field, key: credential.apiKey ?? "")
        case let .apiKeyQuery(field):
            return QueryKeyAuthenticator(field: field, key: credential.apiKey ?? "")
        case .basic:
            return BasicAuthenticator(
                username: credential.username ?? "", password: credential.password ?? ""
            )
        case .qbittorrentCookie:
            return QBittorrentAuthenticator(
                baseURL: instance.baseURL,
                session: session,
                username: credential.username ?? "",
                password: credential.password ?? ""
            )
        case .transmissionSession:
            return TransmissionAuthenticator(
                username: credential.username, password: credential.password
            )
        }
    }
}

/// Vends URLSessions. When insecure TLS is allowed, attaches a delegate that accepts the server
/// trust. The session retains the delegate for its lifetime; instances are long-lived per app run.
enum SessionProvider {
    static func session(allowInsecureTLS: Bool) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = true
        guard allowInsecureTLS else {
            return URLSession(configuration: config)
        }
        return URLSession(
            configuration: config, delegate: InsecureTLSDelegate(), delegateQueue: nil
        )
    }
}

final class InsecureTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
