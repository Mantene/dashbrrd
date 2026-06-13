import Foundation

public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A transport-agnostic description of a single request.
///
/// `path` is relative to the service's API prefix (e.g. `"system/status"`); the
/// `URLBuilder` joins scheme/host/port/basePath/apiPrefix/path. Keeping `Endpoint`
/// free of any absolute URL is what lets one engine serve many differently-mounted
/// servers behind reverse proxies.
public struct Endpoint: Sendable, Hashable {
    public var method: HTTPMethod
    public var path: String
    public var query: [URLQueryItem]
    public var headers: [String: String]
    public var body: Data?

    public init(
        method: HTTPMethod = .get,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }
}
