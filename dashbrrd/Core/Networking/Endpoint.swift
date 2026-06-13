import Foundation

/// A single request, resolved against an `APIClient`'s base URL. Service clients build these.
struct Endpoint: Sendable {
    var path: String                       // appended to baseURL, e.g. "/api/v3/queue"
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var body: Data? = nil
    var headers: [String: String] = [:]

    /// JSON-body convenience.
    static func json(
        _ path: String,
        method: HTTPMethod = .post,
        body: Encodable,
        query: [URLQueryItem] = []
    ) throws -> Endpoint {
        let data = try JSONEncoder().encode(AnyEncodable(body))
        return Endpoint(
            path: path,
            method: method,
            query: query,
            body: data,
            headers: ["Content-Type": "application/json"]
        )
    }

    func makeRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path, isDirectory: false),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }

        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }
}

/// Type-erasing wrapper so `Endpoint.json` can take any `Encodable`.
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeClosure = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}
