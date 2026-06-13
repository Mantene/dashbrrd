import Foundation

/// Per-instance networking actor. Resolves endpoints against `baseURL`, applies the instance's
/// `Authenticator`, and retries once when the authenticator recovers from an auth/handshake status.
actor APIClient {
    let baseURL: URL
    private let session: URLSession
    private let authenticator: Authenticator

    init(baseURL: URL, session: URLSession, authenticator: Authenticator) {
        self.baseURL = baseURL
        self.session = session
        self.authenticator = authenticator
    }

    /// Send and decode a JSON response.
    func send<T: Decodable>(
        _ endpoint: Endpoint,
        as type: T.Type,
        decoder: JSONDecoder = .serviceDefault
    ) async throws -> T {
        let data = try await sendForData(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Send and return raw bytes (for endpoints with no/irregular body).
    @discardableResult
    func send(_ endpoint: Endpoint) async throws -> Data {
        try await sendForData(endpoint)
    }

    private func sendForData(_ endpoint: Endpoint, isRetry: Bool = false) async throws -> Data {
        var request = try endpoint.makeRequest(baseURL: baseURL)
        try await authenticator.authorize(&request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .serverCertificateUntrusted || error.code == .secureConnectionFailed {
                throw APIError.tls
            }
            throw APIError.connection(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.connection("No HTTP response")
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        // Give the authenticator one chance to recover (cookie/session refresh) and retry.
        if !isRetry, try await authenticator.recover(from: http) {
            return try await sendForData(endpoint, isRetry: true)
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }
        let body = String(data: data, encoding: .utf8)
        throw APIError.server(status: http.statusCode, body: body)
    }
}

// MARK: - Decoding helpers

extension JSONDecoder {
    /// Servarr and friends emit ISO-8601 dates, sometimes with fractional seconds. Be tolerant.
    static var serviceDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: string)
                ?? ISO8601DateFormatter.plain.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date: \(string)"
            )
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
