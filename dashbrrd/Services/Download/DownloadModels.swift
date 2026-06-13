import Foundation

/// Unified, display-ready download row used by the Activity UI across all client types.
struct DownloadItem: Identifiable, Sendable, Hashable {
    var id: String
    var name: String
    var progress: Double        // 0...1
    var state: String           // human-readable
    var isPaused: Bool
    var sizeBytes: Int64?
    var downloadRate: Int64?    // bytes/sec
    var etaSeconds: Int?
    var category: String?
}

/// Common surface for every download client so the UI can treat them uniformly.
protocol DownloadClient: Sendable {
    var instance: ServiceInstance { get }
    func testConnection() async throws
    func items() async throws -> [DownloadItem]
    func pause(_ item: DownloadItem) async throws
    func resume(_ item: DownloadItem) async throws
    func delete(_ item: DownloadItem, deleteData: Bool) async throws
}

enum DownloadClientFactory {
    static func make(for instance: ServiceInstance, credential: AuthCredential) -> DownloadClient? {
        switch instance.type {
        case .sabnzbd:     SABnzbdService(instance: instance, credential: credential)
        case .nzbget:      NZBGetService(instance: instance, credential: credential)
        case .qbittorrent: QBittorrentService(instance: instance, credential: credential)
        case .transmission: TransmissionService(instance: instance, credential: credential)
        default: nil
        }
    }
}

// MARK: - Small JSON helpers for clients that return loosely-typed payloads

enum JSONNumber {
    static func int64(_ value: Any?) -> Int64? {
        if let n = value as? NSNumber { return n.int64Value }
        if let s = value as? String { return Int64(s) ?? Double(s).map(Int64.init) }
        return nil
    }
    static func double(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
    static func int(_ value: Any?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }
}

extension String {
    /// Percent-encode for application/x-www-form-urlencoded bodies.
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

func formBody(_ pairs: [(String, String)]) -> Data {
    Data(pairs.map { "\($0.0.formEncoded)=\($0.1.formEncoded)" }.joined(separator: "&").utf8)
}
