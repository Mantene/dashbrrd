import Foundation

/// Dispatches a lightweight connectivity probe to the right client for any service type.
/// Used by the instance editor's "Test Connection" button.
enum ConnectionTester {
    static func test(instance: ServiceInstance, credential: AuthCredential) async throws {
        switch instance.type {
        case .sonarr, .radarr, .lidarr, .readarr, .prowlarr:
            _ = try await ServarrClient(instance: instance, credential: credential).systemStatus()
        case .sabnzbd, .nzbget, .qbittorrent, .transmission:
            guard let client = DownloadClientFactory.make(for: instance, credential: credential) else {
                throw APIError.message("Unsupported service type.")
            }
            try await client.testConnection()
        case .bazarr:
            try await BazarrService(instance: instance, credential: credential).testConnection()
        }
    }
}
