import Foundation

/// Assembles an absolute request URL from a `ConnectionProfile`, an optional API
/// prefix (e.g. `"api/v3"`), and an `Endpoint`.
///
/// This is the single place where reverse-proxy base paths, custom ports, and query
/// items are joined — the classic "works on localhost, 404s behind nginx" bug lives
/// and dies here, which is why it is pure, static, and exhaustively unit-tested.
public enum URLBuilder {

    public static func makeURL(
        profile: ConnectionProfile,
        apiPrefix: String? = nil,
        endpoint: Endpoint
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = profile.scheme
        components.host = profile.host
        components.port = profile.port

        // Join basePath + apiPrefix + endpoint.path into one normalized, single-slashed path.
        let joined = joinPaths([profile.basePath, apiPrefix, endpoint.path])
        components.percentEncodedPath = joined

        // Merge endpoint query + any query-param credentials.
        var query = endpoint.query
        for credential in profile.credentials {
            if case let .queryParam(name, value) = credential {
                query.append(URLQueryItem(name: name, value: value))
            }
        }
        if !query.isEmpty {
            components.queryItems = query
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    /// Joins path fragments with exactly one `/` between them and a single leading `/`,
    /// tolerating fragments that arrive with or without their own slashes (and `nil`/empty).
    static func joinPaths(_ fragments: [String?]) -> String {
        let cleaned = fragments
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return "/" }
        return "/" + cleaned.joined(separator: "/")
    }
}
