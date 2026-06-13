import Foundation

/// The secret material for an instance. Serialized to JSON and stored in the Keychain.
enum AuthCredential: Codable, Equatable, Sendable {
    case apiKey(String)
    case usernamePassword(username: String, password: String)

    var apiKey: String? {
        if case let .apiKey(key) = self { return key }
        return nil
    }

    var username: String? {
        if case let .usernamePassword(user, _) = self { return user }
        return nil
    }

    var password: String? {
        if case let .usernamePassword(_, pass) = self { return pass }
        return nil
    }

    /// An empty credential of the right shape for a given service type.
    static func empty(for kind: CredentialKind) -> AuthCredential {
        switch kind {
        case .apiKey: .apiKey("")
        case .usernamePassword: .usernamePassword(username: "", password: "")
        }
    }
}
