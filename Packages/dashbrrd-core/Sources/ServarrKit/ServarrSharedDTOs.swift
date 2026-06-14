import Foundation
import CoreModel

// Wire shapes shared by *every* Servarr app. `system/status` and `health` are identical
// across Sonarr/Radarr/Prowlarr/etc., so they live in the generic engine; only app-specific
// surfaces (calendar/library) get per-app DTOs under `Apps/<Name>/`.
//
// Swift's `Codable` ignores unknown keys, so these intentionally declare only the fields we
// map — the dozens of other keys Sonarr returns are simply skipped.

struct ServarrSystemStatusDTO: Decodable, Sendable {
    let version: String
    let appName: String?
    let instanceName: String?
}

struct ServarrHealthDTO: Decodable, Sendable {
    let source: String
    let type: String       // "ok" | "notice" | "warning" | "error"
    let message: String
    let wikiUrl: String?
}

extension HealthCheck.Severity {
    /// Maps Servarr's `type` string to our severity, defaulting unknown values to `.notice`.
    init(servarrType: String) {
        self = HealthCheck.Severity(rawValue: servarrType.lowercased()) ?? .notice
    }
}
