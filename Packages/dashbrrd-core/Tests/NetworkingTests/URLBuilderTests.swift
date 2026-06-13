import Testing
import Foundation
import CoreModel
@testable import Networking

@Suite("URLBuilder — the reverse-proxy / port / query bug magnet")
struct URLBuilderTests {

    private func profile(
        scheme: String = "https",
        host: String = "media.lan",
        port: Int? = nil,
        basePath: String? = nil,
        credentials: [ConnectionProfile.Credential] = []
    ) -> ConnectionProfile {
        ConnectionProfile(
            instanceID: InstanceID(),
            scheme: scheme,
            host: host,
            port: port,
            basePath: basePath,
            credentials: credentials
        )
    }

    @Test("plain host + api prefix + path")
    func simple() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(),
            apiPrefix: "api/v3",
            endpoint: Endpoint(path: "system/status")
        )
        #expect(url.absoluteString == "https://media.lan/api/v3/system/status")
    }

    @Test("custom port is preserved")
    func customPort() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(port: 8989),
            apiPrefix: "api/v3",
            endpoint: Endpoint(path: "health")
        )
        #expect(url.absoluteString == "https://media.lan:8989/api/v3/health")
    }

    @Test("reverse-proxy base path is joined with exactly one slash, regardless of input slashes")
    func reverseProxyBasePath() throws {
        for basePath in ["/sonarr", "sonarr", "/sonarr/"] {
            let url = try URLBuilder.makeURL(
                profile: profile(basePath: basePath),
                apiPrefix: "api/v3",
                endpoint: Endpoint(path: "/system/status")
            )
            #expect(url.absoluteString == "https://media.lan/sonarr/api/v3/system/status")
        }
    }

    @Test("nil/empty base path mounts at root")
    func emptyBasePath() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(basePath: ""),
            apiPrefix: "api/v1",
            endpoint: Endpoint(path: "system/status")
        )
        #expect(url.absoluteString == "https://media.lan/api/v1/system/status")
    }

    @Test("endpoint query items are encoded")
    func queryItems() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(),
            apiPrefix: "api/v3",
            endpoint: Endpoint(path: "calendar", query: [
                URLQueryItem(name: "start", value: "2026-06-13"),
                URLQueryItem(name: "unmonitored", value: "false"),
            ])
        )
        #expect(url.absoluteString == "https://media.lan/api/v3/calendar?start=2026-06-13&unmonitored=false")
    }

    @Test("queryParam credentials are appended to the URL")
    func queryParamCredential() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(credentials: [.queryParam(name: "apikey", value: "SECRET")]),
            apiPrefix: nil,
            endpoint: Endpoint(path: "api", query: [URLQueryItem(name: "mode", value: "version")])
        )
        #expect(url.absoluteString == "https://media.lan/api?mode=version&apikey=SECRET")
    }

    @Test("plain http scheme is honored (LAN servers)")
    func httpScheme() throws {
        let url = try URLBuilder.makeURL(
            profile: profile(scheme: "http", port: 8080),
            apiPrefix: "api/v3",
            endpoint: Endpoint(path: "system/status")
        )
        #expect(url.absoluteString == "http://media.lan:8080/api/v3/system/status")
    }
}

@Suite("APIError status mapping")
struct APIErrorTests {
    @Test("status codes map to specific cases")
    func statusMapping() {
        #expect(APIError.from(status: 401, body: nil) == .unauthorized)
        #expect(APIError.from(status: 403, body: nil) == .forbidden)
        #expect(APIError.from(status: 404, body: nil) == .notFound)
        #expect(APIError.from(status: 500, body: "oops") == .server(status: 500, body: "oops"))
    }
}
