import Foundation

extension ConnectionProfile {
    /// Builds the ordered interceptor chain implied by this profile's credentials.
    ///
    /// Header-based auth (API key, Basic) becomes interceptors; `queryParam` credentials
    /// are handled by `URLBuilder` (appended to the URL) and so are intentionally skipped here.
    public func requestInterceptors() -> [RequestInterceptor] {
        credentials.compactMap { credential in
            switch credential {
            case let .apiKey(key):
                return APIKeyInterceptor(apiKey: key)
            case let .basic(username, password):
                return BasicAuthInterceptor(username: username, password: password)
            case .queryParam:
                return nil
            }
        }
    }
}
