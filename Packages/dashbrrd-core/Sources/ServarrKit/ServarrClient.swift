import Foundation
import CoreModel
import Networking

/// The generic Servarr engine: one actor that serves every *arr by being parameterized
/// over a `ServarrDescriptor` and driven by an injected `HTTPClientProtocol`.
///
/// Shared endpoints (`system/status`, `health`) live here; app-specific surfaces
/// (calendar/library) are attached via constrained extensions under `Apps/<Name>/`.
public actor ServarrClient<Descriptor: ServarrDescriptor> {
    public let descriptor: Descriptor
    public let instanceID: InstanceID
    let http: HTTPClientProtocol

    public init(descriptor: Descriptor, instanceID: InstanceID, http: HTTPClientProtocol) {
        self.descriptor = descriptor
        self.instanceID = instanceID
        self.http = http
    }

    public var capabilities: ServiceCapabilities { descriptor.capabilities }

    /// Exposed to constrained extensions (e.g. Sonarr calendar) that build app-specific endpoints.
    var httpClient: HTTPClientProtocol { http }

    /// Cheap identity probe used by Test Connection and to read the running version.
    public func systemStatus() async throws -> SystemStatus {
        let dto = try await http.send(Endpoint(path: "system/status"), as: ServarrSystemStatusDTO.self)
        return SystemStatus(
            instanceID: instanceID,
            version: dto.version,
            appName: dto.appName ?? dto.instanceName ?? descriptor.kind.displayName
        )
    }

    /// The Servarr-side download queue (shared shape across Sonarr/Radarr). `downloadID`
    /// carries the client's id so the unified Queue can dedup against SAB/qBit.
    public func queue() async throws -> [QueueItem] {
        let dto = try await http.send(
            Endpoint(path: "queue", query: [URLQueryItem(name: "pageSize", value: "200")]),
            as: ServarrQueueResponseDTO.self
        )
        return dto.records.map { record in
            let size = Int64(record.size ?? 0)
            let left = Int64(record.sizeleft ?? 0)
            let progress = size > 0 ? Double(size - left) / Double(size) : 0
            return QueueItem(
                id: "\(instanceID.rawValue.uuidString):q:\(record.id)",
                instanceID: instanceID,
                serviceKind: descriptor.kind,
                name: record.title ?? "Unknown",
                state: ServarrQueueMapper.state(record.status),
                progress: max(0, min(1, progress)),
                sizeBytes: size,
                sizeLeftBytes: left,
                speedBytesPerSec: 0,
                etaSeconds: ServarrQueueMapper.parseTimeLeft(record.timeleft),
                category: nil,
                downloadID: record.downloadId ?? ""
            )
        }
    }

    /// All health checks the service currently reports (shared shape across every *arr).
    public func health() async throws -> [HealthCheck] {
        let dtos = try await http.send(Endpoint(path: "health"), as: [ServarrHealthDTO].self)
        return dtos.map { dto in
            HealthCheck(
                id: "\(instanceID.rawValue.uuidString):\(dto.source)",
                instanceID: instanceID,
                source: dto.source,
                severity: HealthCheck.Severity(servarrType: dto.type),
                message: dto.message,
                wikiURL: dto.wikiUrl.flatMap(URL.init(string:))
            )
        }
    }
}
