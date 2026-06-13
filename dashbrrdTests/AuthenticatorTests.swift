import XCTest
@testable import dashbrrd

final class AuthenticatorTests: XCTestCase {
    func testHeaderKey() async throws {
        var request = URLRequest(url: URL(string: "http://x")!)
        try await HeaderKeyAuthenticator(field: "X-Api-Key", key: "abc123").authorize(&request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "abc123")
    }

    func testQueryKeyAppends() async throws {
        var request = URLRequest(url: URL(string: "http://x/api?mode=queue")!)
        try await QueryKeyAuthenticator(field: "apikey", key: "KEY").authorize(&request)
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertTrue(url.contains("apikey=KEY"))
        XCTAssertTrue(url.contains("mode=queue"))
    }

    func testBasicAuth() async throws {
        var request = URLRequest(url: URL(string: "http://x")!)
        try await BasicAuthenticator(username: "user", password: "pass").authorize(&request)
        let expected = "Basic " + Data("user:pass".utf8).base64EncodedString()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), expected)
    }

    func testTransmissionSessionHandshake() async throws {
        let auth = TransmissionAuthenticator(username: nil, password: nil)
        let response = HTTPURLResponse(
            url: URL(string: "http://x")!, statusCode: 409, httpVersion: nil,
            headerFields: ["X-Transmission-Session-Id": "SID-XYZ"]
        )!
        let recovered = try await auth.recover(from: response)
        XCTAssertTrue(recovered)

        var request = URLRequest(url: URL(string: "http://x")!)
        try await auth.authorize(&request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Transmission-Session-Id"), "SID-XYZ")
    }

    func testTransmissionIgnoresNon409() async throws {
        let auth = TransmissionAuthenticator(username: nil, password: nil)
        let response = HTTPURLResponse(
            url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        let recovered = try await auth.recover(from: response)
        XCTAssertFalse(recovered)
    }
}
