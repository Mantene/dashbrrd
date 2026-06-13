import Foundation

/// A fast, network-free `HTTPClientProtocol` for logic tests.
///
/// Routes are matched by `"METHOD path"` (e.g. `"GET system/status"`). Captured
/// fixture JSON is returned verbatim, exercising the real decoder + mappers without a
/// socket. Recorded requests are kept so tests can assert request shaping.
public actor MockHTTPClient: HTTPClientProtocol {
    public enum Response: Sendable {
        case success(Data)
        case failure(APIError)
    }

    private var routes: [String: Response]
    public private(set) var recordedEndpoints: [Endpoint] = []

    public init(routes: [String: Response] = [:]) {
        self.routes = routes
    }

    public func setRoute(_ key: String, _ response: Response) {
        routes[key] = response
    }

    public func data(for endpoint: Endpoint) async throws -> Data {
        recordedEndpoints.append(endpoint)
        let key = "\(endpoint.method.rawValue) \(endpoint.path)"
        guard let response = routes[key] else { throw APIError.notFound }
        switch response {
        case let .success(data): return data
        case let .failure(error): throw error
        }
    }
}
