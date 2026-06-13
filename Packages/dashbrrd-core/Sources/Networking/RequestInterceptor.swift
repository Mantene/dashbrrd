import Foundation

/// Adapts an outgoing `URLRequest` — the seam through which all auth is injected.
///
/// Living in the transport layer (not per-engine) means SABnzbd, qBittorrent, and every
/// Servarr app reuse the exact same auth primitives; an instance just gets a different
/// ordered list of interceptors built from its `ConnectionProfile.credentials`.
public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

/// Servarr authentication via the `X-Api-Key` header.
public struct APIKeyInterceptor: RequestInterceptor {
    public let apiKey: String
    public init(apiKey: String) { self.apiKey = apiKey }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        return request
    }
}

/// HTTP Basic Auth, typically for a reverse proxy in front of the service.
public struct BasicAuthInterceptor: RequestInterceptor {
    public let username: String
    public let password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let raw = "\(username):\(password)"
        if let token = raw.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

/// qBittorrent-style cookie session: a captured `SID` cookie is replayed on each request.
/// Phase 0 skeleton — the login round-trip that mints the `SID` lands in `DownloadClientKit`.
public actor CookieSessionInterceptor: RequestInterceptor {
    private var sessionCookie: String?

    public init(sessionCookie: String? = nil) {
        self.sessionCookie = sessionCookie
    }

    public func update(sessionCookie: String?) {
        self.sessionCookie = sessionCookie
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let sessionCookie {
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        }
        return request
    }
}
