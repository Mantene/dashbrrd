import Foundation

/// A configured connection to one service. Secrets are NOT stored here — they live in the Keychain
/// keyed by `id`. This struct is persisted as plain JSON by `ConfigStore`.
struct ServiceInstance: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var type: ServiceType
    var scheme: String          // "http" or "https"
    var host: String
    var port: Int
    var urlBase: String         // optional reverse-proxy prefix, e.g. "/sonarr". May be empty.
    var allowInsecureTLS: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: ServiceType,
        scheme: String = "http",
        host: String,
        port: Int,
        urlBase: String = "",
        allowInsecureTLS: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.scheme = scheme
        self.host = host
        self.port = port
        self.urlBase = urlBase
        self.allowInsecureTLS = allowInsecureTLS
        self.isEnabled = isEnabled
    }

    /// scheme://host:port/urlBase  (no trailing slash, no api path).
    var baseURL: URL {
        var trimmed = urlBase.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !trimmed.hasPrefix("/") { trimmed = "/" + trimmed }
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        let string = "\(scheme)://\(host):\(port)\(trimmed)"
        // Fall back to a sentinel that will surface as a connection error rather than crash.
        return URL(string: string) ?? URL(string: "http://invalid.invalid")!
    }

    static func makeDefault(type: ServiceType) -> ServiceInstance {
        ServiceInstance(name: type.displayName, type: type, host: "", port: type.defaultPort)
    }
}
