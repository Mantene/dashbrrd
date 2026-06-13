import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A `URLProtocol` that intercepts requests in-process so tests can exercise the *real*
/// `URLSession` → `URLBuilder` → interceptor → response-parsing path without a network.
///
/// Install by setting `config.protocolClasses = [StubURLProtocol.self]` and assigning a
/// `requestHandler`. Used for trust/`URLBuilder` integration tests that `MockHTTPClient`
/// (which bypasses `URLSession` entirely) cannot cover.
public final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Set before the request runs. Returns the response + body, or throws to simulate failure.
    nonisolated(unsafe) public static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    public override class func canInit(with request: URLRequest) -> Bool { true }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    public override func stopLoading() {}
}
