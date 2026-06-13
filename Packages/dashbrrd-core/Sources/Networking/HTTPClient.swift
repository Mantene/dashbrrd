import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The test seam for all network I/O. Engines depend on this protocol, never on the
/// concrete `URLSession`-backed actor, so logic tests inject `MockHTTPClient`.
public protocol HTTPClientProtocol: Sendable {
    /// Sends an endpoint and returns the raw response body, throwing typed `APIError`.
    func data(for endpoint: Endpoint) async throws -> Data

    /// Sends an endpoint and decodes the JSON body into `T`.
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

extension HTTPClientProtocol {
    public func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await data(for: endpoint)
        do {
            return try JSONDecoder.servarr.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8)
            throw APIError.decoding(String(describing: error), raw: raw)
        }
    }
}

/// Concrete `URLSession`-backed client. One instance per `ConnectionProfile`; holds an
/// ordered interceptor chain and an optional API prefix (e.g. `api/v3`).
public actor HTTPClient: HTTPClientProtocol {
    private let profile: ConnectionProfile
    private let apiPrefix: String?
    private let interceptors: [RequestInterceptor]
    private let session: URLSession

    public init(
        profile: ConnectionProfile,
        apiPrefix: String? = nil,
        interceptors: [RequestInterceptor] = [],
        session: URLSession? = nil
    ) {
        self.profile = profile
        self.apiPrefix = apiPrefix
        self.interceptors = interceptors
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 30
            config.waitsForConnectivity = false
            #if os(iOS)
            let delegate = TrustEvaluator(policy: profile.trustPolicy)
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            #else
            self.session = URLSession(configuration: config)
            #endif
        }
    }

    public func data(for endpoint: Endpoint) async throws -> Data {
        let url = try URLBuilder.makeURL(profile: profile, apiPrefix: apiPrefix, endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if endpoint.body != nil, request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for interceptor in interceptors {
            request = try await interceptor.adapt(request)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("Non-HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.from(status: http.statusCode, body: String(data: data, encoding: .utf8))
            }
            return data
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.clientCancelled
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}

extension JSONDecoder {
    /// Shared decoder configured for Servarr's ISO-8601 timestamps.
    public static var servarr: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
