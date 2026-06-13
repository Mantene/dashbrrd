import Foundation

/// A finite state for any asynchronously-loaded value.
///
/// Using an enum instead of the classic `(value: T?, isLoading: Bool, error: Error?)`
/// triple makes illegal states unrepresentable (you cannot be `.loaded` *and* `.failed`)
/// and lets feature views switch exhaustively over exactly one case.
public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)

    public var value: Value? {
        if case let .loaded(value) = self { value } else { nil }
    }

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    public var errorMessage: String? {
        if case let .failed(message) = self { message } else { nil }
    }

    /// Maps the loaded value while preserving the surrounding state.
    public func map<T: Sendable>(_ transform: (Value) -> T) -> LoadState<T> {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case let .loaded(value): .loaded(transform(value))
        case let .failed(message): .failed(message: message)
        }
    }
}

extension LoadState: Equatable where Value: Equatable {}
