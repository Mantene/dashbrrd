import Foundation

/// Per-instance authentication strategy. Implementations may cache session tokens/cookies and
/// refresh them in `recover` when the server rejects a request.
protocol Authenticator: AnyObject, Sendable {
    /// Attach credentials to an outgoing request. May perform a login round-trip if needed.
    func authorize(_ request: inout URLRequest) async throws

    /// Called when a response status suggests an auth/handshake problem (401/403/409).
    /// Return `true` if state was refreshed and the request should be retried once.
    func recover(from response: HTTPURLResponse) async throws -> Bool
}

extension Authenticator {
    func recover(from response: HTTPURLResponse) async throws -> Bool { false }
}

// MARK: - API key in a header (Servarr, Bazarr)

final class HeaderKeyAuthenticator: Authenticator {
    private let field: String
    private let key: String
    init(field: String, key: String) { self.field = field; self.key = key }

    func authorize(_ request: inout URLRequest) async throws {
        request.setValue(key, forHTTPHeaderField: field)
    }
}

// MARK: - API key as a query item (SABnzbd)

final class QueryKeyAuthenticator: Authenticator {
    private let field: String
    private let key: String
    init(field: String, key: String) { self.field = field; self.key = key }

    func authorize(_ request: inout URLRequest) async throws {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: field, value: key))
        components.queryItems = items
        request.url = components.url
    }
}

// MARK: - HTTP Basic (NZBGet)

final class BasicAuthenticator: Authenticator {
    private let value: String
    init(username: String, password: String) {
        let raw = "\(username):\(password)"
        value = "Basic " + Data(raw.utf8).base64EncodedString()
    }

    func authorize(_ request: inout URLRequest) async throws {
        request.setValue(value, forHTTPHeaderField: "Authorization")
    }
}

// MARK: - qBittorrent cookie session

/// Logs in via /api/v2/auth/login, caches the SID cookie, and re-logs in on a 403.
final class QBittorrentAuthenticator: Authenticator, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let username: String
    private let password: String
    private let lock = NSLock()
    private var sid: String?

    init(baseURL: URL, session: URLSession, username: String, password: String) {
        self.baseURL = baseURL
        self.session = session
        self.username = username
        self.password = password
    }

    func authorize(_ request: inout URLRequest) async throws {
        let current = lock.withLock { sid }
        let token = try await current ?? login()
        request.setValue("SID=\(token)", forHTTPHeaderField: "Cookie")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
    }

    func recover(from response: HTTPURLResponse) async throws -> Bool {
        guard response.statusCode == 403 else { return false }
        lock.withLock { sid = nil }
        _ = try await login()
        return true
    }

    @discardableResult
    private func login() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v2/auth/login"))
        request.httpMethod = "POST"
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = "username=\(username.urlFormEncoded)&password=\(password.urlFormEncoded)"
        request.httpBody = Data(form.utf8)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.unauthorized
        }
        // SID arrives in Set-Cookie.
        let setCookie = http.value(forHTTPHeaderField: "Set-Cookie") ?? ""
        guard let token = Self.extractSID(from: setCookie) else { throw APIError.unauthorized }
        lock.withLock { sid = token }
        return token
    }

    private static func extractSID(from setCookie: String) -> String? {
        for part in setCookie.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SID=") { return String(trimmed.dropFirst(4)) }
        }
        return nil
    }
}

// MARK: - Transmission session-id handshake

/// Sends optional Basic auth and the X-Transmission-Session-Id header, learning the id from the
/// 409 response Transmission returns on the first call.
final class TransmissionAuthenticator: Authenticator, @unchecked Sendable {
    private let basic: String?
    private let lock = NSLock()
    private var sessionID: String?

    init(username: String?, password: String?) {
        if let username, let password, !(username.isEmpty && password.isEmpty) {
            basic = "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        } else {
            basic = nil
        }
    }

    func authorize(_ request: inout URLRequest) async throws {
        if let basic { request.setValue(basic, forHTTPHeaderField: "Authorization") }
        if let id = lock.withLock({ sessionID }) {
            request.setValue(id, forHTTPHeaderField: "X-Transmission-Session-Id")
        }
    }

    func recover(from response: HTTPURLResponse) async throws -> Bool {
        guard response.statusCode == 409,
              let id = response.value(forHTTPHeaderField: "X-Transmission-Session-Id")
        else { return false }
        lock.withLock { sessionID = id }
        return true
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}
