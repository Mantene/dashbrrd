import Foundation

/// A candidate from a Servarr "lookup" search (a series/movie not necessarily in the library).
///
/// Carries `rawPayload` — the exact lookup JSON object — so the add call can POST it back with
/// the user's chosen fields injected, without modeling Servarr's enormous add schema.
public struct MediaLookupItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var title: String
    public var year: Int?
    public var posterURL: URL?
    public var overview: String?
    /// True if this title is already managed by the target instance.
    public var alreadyInLibrary: Bool
    /// The raw lookup object (JSON), re-POSTed with add fields injected.
    public var rawPayload: Data

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        title: String,
        year: Int? = nil,
        posterURL: URL? = nil,
        overview: String? = nil,
        alreadyInLibrary: Bool,
        rawPayload: Data
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.title = title
        self.year = year
        self.posterURL = posterURL
        self.overview = overview
        self.alreadyInLibrary = alreadyInLibrary
        self.rawPayload = rawPayload
    }

    public var displayTitle: String { year.map { "\(title) (\($0))" } ?? title }
}

/// A Servarr quality profile (id + name) for the add flow.
public struct QualityProfile: Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

/// A Servarr root folder (where media lives on the server).
public struct RootFolder: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public var path: String
    public var freeSpaceBytes: Int64?
    public init(path: String, freeSpaceBytes: Int64? = nil) {
        self.path = path
        self.freeSpaceBytes = freeSpaceBytes
    }
}
