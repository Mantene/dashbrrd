import Foundation
import SwiftData

/// An in-memory SwiftData stack shared by SwiftUI previews and unit tests.
///
/// Lives in `PersistenceKit` (not `DesignSystem`) because it must reference the `@Model`
/// types; `DesignSystem` stays a pure UI leaf. Tests use this for upsert/cascade
/// assertions; previews use it so feature views render without a real server.
public enum PreviewContainer {
    /// A fresh, isolated, in-memory container holding all dashbrrd models.
    public static func make() throws -> ModelContainer {
        let schema = Schema([ServerConfigModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
