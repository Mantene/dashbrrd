import Foundation

/// A file Servarr proposes for manual import, with its detected target + any rejections.
///
/// Carries `rawPayload` (the candidate JSON) so the import command can be built from it,
/// preserving the detected quality/languages/episode mapping without re-modeling the schema.
public struct ManualImportCandidate: Sendable, Hashable, Identifiable {
    public var id: String
    public var instanceID: InstanceID
    public var serviceKind: ServiceKind
    public var fileName: String
    /// Detected target, e.g. "The Show · S04E06" or "A Movie (2024)".
    public var title: String
    public var qualityName: String?
    public var sizeBytes: Int64
    public var rejections: [String]
    /// True when Servarr accepted the mapping (no rejections) and a target was detected.
    public var importable: Bool
    public var rawPayload: Data

    public init(
        id: String,
        instanceID: InstanceID,
        serviceKind: ServiceKind,
        fileName: String,
        title: String,
        qualityName: String? = nil,
        sizeBytes: Int64,
        rejections: [String],
        importable: Bool,
        rawPayload: Data
    ) {
        self.id = id
        self.instanceID = instanceID
        self.serviceKind = serviceKind
        self.fileName = fileName
        self.title = title
        self.qualityName = qualityName
        self.sizeBytes = sizeBytes
        self.rejections = rejections
        self.importable = importable
        self.rawPayload = rawPayload
    }
}
