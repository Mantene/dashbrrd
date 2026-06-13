import XCTest
@testable import dashbrrd

final class EndpointTests: XCTestCase {
    func testBuildsURLWithQueryAndMethod() throws {
        let base = URL(string: "http://nas:8989")!
        let endpoint = Endpoint(
            path: "/api/v3/queue",
            method: .delete,
            query: [URLQueryItem(name: "pageSize", value: "100")]
        )
        let request = try endpoint.makeRequest(baseURL: base)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.absoluteString, "http://nas:8989/api/v3/queue?pageSize=100")
    }

    func testJSONBodySetsContentType() throws {
        struct Body: Encodable { let name: String }
        let endpoint = try Endpoint.json("/api/v3/command", body: Body(name: "RssSync"))
        let request = try endpoint.makeRequest(baseURL: URL(string: "http://nas:8989")!)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    func testServiceTypeApiBasePaths() {
        XCTAssertEqual(ServiceType.sonarr.apiBasePath, "/api/v3")
        XCTAssertEqual(ServiceType.lidarr.apiBasePath, "/api/v1")
        XCTAssertEqual(ServiceType.qbittorrent.apiBasePath, "/api/v2")
        XCTAssertEqual(ServiceType.transmission.apiBasePath, "/transmission/rpc")
    }

    func testInstanceBaseURLWithUrlBase() {
        let instance = ServiceInstance(
            name: "S", type: .sonarr, scheme: "https", host: "host", port: 443, urlBase: "sonarr"
        )
        XCTAssertEqual(instance.baseURL.absoluteString, "https://host:443/sonarr")
    }
}
