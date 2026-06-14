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

    /// Toggles the `monitored` flag on a media record. Servarr requires the *full* object on
    /// PUT, so we GET it, flip one field via JSONSerialization (avoids modeling the whole
    /// schema), and PUT it back. `resource` is "series" (Sonarr) or "movie" (Radarr).
    public func setMonitored(resource: String, id: Int, monitored: Bool) async throws {
        let data = try await http.data(for: Endpoint(path: "\(resource)/\(id)"))
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding("Expected a JSON object for \(resource)/\(id)", raw: String(data: data, encoding: .utf8))
        }
        object["monitored"] = monitored
        let body = try JSONSerialization.data(withJSONObject: object)
        _ = try await http.data(for: Endpoint(method: .put, path: "\(resource)/\(id)", body: body))
    }

    /// Interactive release search for a media item. `paramName` is "seriesId" (Sonarr) or
    /// "movieId" (Radarr). Read-only — queries the configured indexers.
    public func releaseSearch(paramName: String, mediaID: Int) async throws -> [Release] {
        let dtos = try await http.send(
            Endpoint(path: "release", query: [URLQueryItem(name: paramName, value: "\(mediaID)")]),
            as: [ServarrReleaseDTO].self
        )
        return dtos.map { dto in
            Release(
                id: dto.guid,
                instanceID: instanceID,
                serviceKind: descriptor.kind,
                guid: dto.guid,
                indexerID: dto.indexerId ?? 0,
                title: dto.title,
                indexer: dto.indexer ?? "Unknown",
                isUsenet: (dto.proto ?? "").lowercased() == "usenet",
                sizeBytes: dto.size ?? 0,
                seeders: dto.seeders,
                ageDays: dto.age ?? 0,
                quality: dto.quality?.quality?.name,
                rejected: dto.rejected ?? false,
                rejections: dto.rejections ?? [],
                downloadAllowed: dto.downloadAllowed ?? true
            )
        }
    }

    /// Lookup search for new media (`resource` is "series"/"movie" → hits `{resource}/lookup`).
    /// Keeps each result's raw JSON so `addMedia` can POST it back with the chosen fields.
    public func lookup(resource: String, term: String) async throws -> [MediaLookupItem] {
        let data = try await http.data(for: Endpoint(path: "\(resource)/lookup", query: [URLQueryItem(name: "term", value: term)]))
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.decoding("Expected an array for \(resource)/lookup", raw: String(data: data, encoding: .utf8))
        }
        return array.map { dict in
            let payload = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
            let remoteID = dict["id"] as? Int ?? 0
            let title = dict["title"] as? String ?? "Unknown"
            let year = dict["year"] as? Int
            let externalID = dict["tvdbId"] as? Int ?? dict["tmdbId"] as? Int ?? 0
            return MediaLookupItem(
                id: "\(descriptor.kind.rawValue):\(externalID):\(title):\(year ?? 0)",
                instanceID: instanceID,
                serviceKind: descriptor.kind,
                title: title,
                year: year,
                posterURL: Self.posterURL(fromImages: dict["images"]),
                overview: dict["overview"] as? String,
                alreadyInLibrary: remoteID > 0,
                rawPayload: payload
            )
        }
    }

    public func qualityProfiles() async throws -> [QualityProfile] {
        try await http.send(Endpoint(path: "qualityprofile"), as: [ServarrQualityProfileDTO].self)
            .map { QualityProfile(id: $0.id, name: $0.name) }
    }

    public func rootFolders() async throws -> [RootFolder] {
        try await http.send(Endpoint(path: "rootfolder"), as: [ServarrRootFolderDTO].self)
            .map { RootFolder(path: $0.path, freeSpaceBytes: $0.freeSpace) }
    }

    /// Adds new media by re-POSTing the lookup payload with the user's chosen fields injected.
    /// `searchOptionKey` is "searchForMissingEpisodes" (Sonarr) or "searchForMovie" (Radarr);
    /// `extraFields` carries app-specific requirements (e.g. Radarr's minimumAvailability).
    public func addMedia(
        resource: String,
        payload: Data,
        qualityProfileID: Int,
        rootFolderPath: String,
        monitored: Bool,
        searchOnAdd: Bool,
        searchOptionKey: String,
        extraFields: [String: Sendable] = [:]
    ) async throws {
        guard var dict = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw APIError.decoding("Add payload is not a JSON object", raw: nil)
        }
        dict["qualityProfileId"] = qualityProfileID
        dict["rootFolderPath"] = rootFolderPath
        dict["monitored"] = monitored
        dict["addOptions"] = [searchOptionKey: searchOnAdd]
        for (key, value) in extraFields { dict[key] = value }
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await http.data(for: Endpoint(method: .post, path: resource, body: body))
    }

    /// Extracts the poster `remoteUrl` (preferred) or `url` from a Servarr images array.
    static func posterURL(fromImages images: Any?) -> URL? {
        guard let images = images as? [[String: Any]] else { return nil }
        let poster = images.first { ($0["coverType"] as? String) == "poster" }
        let urlString = (poster?["remoteUrl"] as? String) ?? (poster?["url"] as? String)
        return urlString.flatMap(URL.init(string:))
    }

    /// Manual-import candidates for a download (files Servarr didn't auto-import). Keeps each
    /// candidate's raw JSON so the import command preserves the detected episode/quality mapping.
    public func manualImportCandidates(downloadID: String) async throws -> [ManualImportCandidate] {
        let data = try await http.data(for: Endpoint(path: "manualimport", query: [
            URLQueryItem(name: "downloadId", value: downloadID),
            URLQueryItem(name: "filterExistingFiles", value: "true"),
        ]))
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.decoding("Expected an array for manualimport", raw: String(data: data, encoding: .utf8))
        }
        return array.map { dict in
            let payload = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
            let candidateID = dict["id"] as? Int ?? 0
            let fileName = (dict["name"] as? String) ?? (dict["relativePath"] as? String) ?? "File"
            let size = (dict["size"] as? NSNumber)?.int64Value ?? 0
            let rejections = Self.rejectionReasons(dict["rejections"])
            let quality = ((dict["quality"] as? [String: Any])?["quality"] as? [String: Any])?["name"] as? String

            var title = "Unrecognized file"
            var hasTarget = false
            if let series = dict["series"] as? [String: Any] {
                let showTitle = series["title"] as? String ?? "Series"
                let episodes = (dict["episodes"] as? [[String: Any]]) ?? []
                let code = (dict["seasonNumber"] as? Int).map { String(format: "S%02d", $0) } ?? ""
                let eps = episodes.compactMap { $0["episodeNumber"] as? Int }.map { String(format: "E%02d", $0) }.joined()
                title = eps.isEmpty ? showTitle : "\(showTitle) · \(code)\(eps)"
                hasTarget = (series["id"] as? Int ?? 0) > 0 && !episodes.isEmpty
            } else if let movie = dict["movie"] as? [String: Any] {
                let movieTitle = movie["title"] as? String ?? "Movie"
                title = (movie["year"] as? Int).map { "\(movieTitle) (\($0))" } ?? movieTitle
                hasTarget = (movie["id"] as? Int ?? 0) > 0
            }

            return ManualImportCandidate(
                id: "\(instanceID.rawValue.uuidString):\(candidateID)",
                instanceID: instanceID,
                serviceKind: descriptor.kind,
                fileName: fileName,
                title: title,
                qualityName: quality,
                sizeBytes: size,
                rejections: rejections,
                importable: rejections.isEmpty && hasTarget,
                rawPayload: payload
            )
        }
    }

    /// Imports the chosen candidates by POSTing a ManualImport command built from their payloads.
    /// `importMode` is "move" or "copy".
    public func manualImport(payloads: [Data], importMode: String) async throws {
        let isMovie = descriptor.kind == .radarr
        var files: [[String: Any]] = []
        for payload in payloads {
            guard let dict = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else { continue }
            var entry: [String: Any] = [:]
            for key in ["path", "quality", "languages", "releaseGroup", "downloadId", "indexerFlags"] {
                if let value = dict[key] { entry[key] = value }
            }
            if isMovie {
                if let movie = dict["movie"] as? [String: Any], let id = movie["id"] { entry["movieId"] = id }
            } else {
                if let series = dict["series"] as? [String: Any], let id = series["id"] { entry["seriesId"] = id }
                entry["episodeIds"] = ((dict["episodes"] as? [[String: Any]]) ?? []).compactMap { $0["id"] }
            }
            files.append(entry)
        }
        let command: [String: Any] = ["name": "ManualImport", "importMode": importMode, "files": files]
        let body = try JSONSerialization.data(withJSONObject: command)
        _ = try await http.data(for: Endpoint(method: .post, path: "command", body: body))
    }

    /// Servarr rejections come as objects ({reason,type}) or sometimes plain strings.
    static func rejectionReasons(_ raw: Any?) -> [String] {
        if let objects = raw as? [[String: Any]] {
            return objects.compactMap { $0["reason"] as? String }
        }
        if let strings = raw as? [String] {
            return strings
        }
        return []
    }

    /// Grabs a release → Servarr sends it to the appropriate download client. A real state change.
    public func grab(guid: String, indexerID: Int) async throws {
        let body = try JSONEncoder().encode(ServarrGrabRequest(guid: guid, indexerId: indexerID))
        _ = try await http.data(for: Endpoint(method: .post, path: "release", body: body))
    }

    /// Deletes a media record, optionally removing files from disk.
    public func deleteMedia(resource: String, id: Int, deleteFiles: Bool) async throws {
        _ = try await http.data(for: Endpoint(
            method: .delete,
            path: "\(resource)/\(id)",
            query: [URLQueryItem(name: "deleteFiles", value: deleteFiles ? "true" : "false")]
        ))
    }

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

    /// A page of activity/history (shared shape across Sonarr/Radarr), newest first.
    public func history(_ request: PagedRequest) async throws -> Page<HistoryRecord> {
        let dto = try await http.send(
            Endpoint(path: "history", query: [
                URLQueryItem(name: "page", value: "\(request.page)"),
                URLQueryItem(name: "pageSize", value: "\(request.pageSize)"),
                URLQueryItem(name: "sortKey", value: request.sortKey ?? "date"),
                URLQueryItem(name: "sortDirection", value: (request.sortDirection ?? .descending).rawValue),
            ]),
            as: ServarrHistoryResponseDTO.self
        )
        let records = dto.records.map { record in
            HistoryRecord(
                id: "\(instanceID.rawValue.uuidString):\(record.id)",
                instanceID: instanceID,
                serviceKind: descriptor.kind,
                eventType: HistoryRecord.EventType(servarrEventType: record.eventType),
                title: record.sourceTitle ?? "Unknown",
                date: record.date,
                quality: record.qualityName
            )
        }
        return Page(page: dto.page, pageSize: dto.pageSize, totalRecords: dto.totalRecords, records: records)
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
