import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case connection(String)
    case tls
    case server(status: Int, body: String?)
    case decoding(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The service URL is invalid."
        case .unauthorized:
            return "Authentication failed. Check the API key or username/password."
        case let .connection(detail):
            return "Could not connect: \(detail)"
        case .tls:
            return "TLS error. If this server uses a self-signed certificate, enable \"Allow insecure TLS\"."
        case let .server(status, body):
            if let body, !body.isEmpty {
                return "Server returned \(status): \(body)"
            }
            return "Server returned status \(status)."
        case let .decoding(detail):
            return "Unexpected response from server: \(detail)"
        case let .message(text):
            return text
        }
    }
}
