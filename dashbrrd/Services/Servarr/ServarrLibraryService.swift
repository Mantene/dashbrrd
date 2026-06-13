import Foundation

/// Full-management library client shared by Sonarr, Radarr, Lidarr and Readarr. Specialized by
/// `ServarrEntity`; uses JSON pass-through so add/update preserve all server fields.
struct ServarrLibraryService: Sendable {
    let core: ServarrClient
    let entity: ServarrEntity
    let type: ServiceType

    init(instance: ServiceInstance, credential: AuthCredential) {
        self.core = ServarrClient(instance: instance, credential: credential)
        self.entity = ServarrEntity.forType(instance.type)
        self.type = instance.type
    }

    private var entityBase: String { core.basePath + entity.path }

    // MARK: Reads

    func library() async throws -> [MediaSummary] {
        let data = try await core.api.send(Endpoint(path: entityBase))
        return MediaSummary.parseList(data, entity: entity, isLibrary: true)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func lookup(_ term: String) async throws -> [MediaSummary] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let endpoint = Endpoint(
            path: core.basePath + entity.lookupPath,
            query: [URLQueryItem(name: "term", value: trimmed)]
        )
        let data = try await core.api.send(endpoint)
        return MediaSummary.parseList(data, entity: entity, isLibrary: false)
    }

    func qualityProfiles() async throws -> [QualityProfile] { try await core.qualityProfiles() }
    func rootFolders() async throws -> [RootFolder] { try await core.rootFolders() }

    // MARK: Writes (full management)

    func add(
        _ item: MediaSummary,
        qualityProfileId: Int,
        rootFolderPath: String,
        monitored: Bool,
        searchNow: Bool
    ) async throws {
        guard var object = item.rawObject() else { throw APIError.message("Missing item data to add.") }
        object["qualityProfileId"] = qualityProfileId
        object["rootFolderPath"] = rootFolderPath
        object["monitored"] = monitored
        var addOptions: [String: Any] = ["monitor": "all"]
        if let key = entity.searchAddOptionKey { addOptions[key] = searchNow }
        object["addOptions"] = addOptions
        for (key, value) in entity.extraAddDefaults where object[key] == nil {
            object[key] = value
        }
        let body = try JSONSerialization.data(withJSONObject: object)
        let endpoint = Endpoint(
            path: entityBase, method: .post, body: body,
            headers: ["Content-Type": "application/json"]
        )
        try await core.api.send(endpoint)
    }

    func setMonitored(_ item: MediaSummary, monitored: Bool) async throws {
        // Fetch the current object, flip the flag, PUT it back so we don't drop fields.
        let data = try await core.api.send(Endpoint(path: "\(entityBase)/\(item.id)"))
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.message("Unexpected item payload.")
        }
        object["monitored"] = monitored
        let body = try JSONSerialization.data(withJSONObject: object)
        let endpoint = Endpoint(
            path: "\(entityBase)/\(item.id)", method: .put, body: body,
            headers: ["Content-Type": "application/json"]
        )
        try await core.api.send(endpoint)
    }

    func delete(_ item: MediaSummary, deleteFiles: Bool) async throws {
        let endpoint = Endpoint(
            path: "\(entityBase)/\(item.id)",
            method: .delete,
            query: [
                URLQueryItem(name: "deleteFiles", value: String(deleteFiles)),
                URLQueryItem(name: "addImportListExclusion", value: "false"),
            ]
        )
        try await core.api.send(endpoint)
    }

    func search(_ item: MediaSummary) async throws {
        try await core.runCommand(searchCommand(for: item.id))
    }

    private func searchCommand(for entityID: Int) -> CommandRequest {
        switch type {
        case .sonarr:  CommandRequest(name: entity.searchCommand, seriesId: entityID)
        case .radarr:  CommandRequest(name: entity.searchCommand, movieId: entityID)
        case .lidarr:  CommandRequest(name: entity.searchCommand, artistId: entityID)
        case .readarr: CommandRequest(name: entity.searchCommand, authorId: entityID)
        default:       CommandRequest(name: entity.searchCommand)
        }
    }
}
