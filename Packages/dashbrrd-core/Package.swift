// swift-tools-version: 6.0
import PackageDescription

// dashbrrd-core — the entire logic + UI surface of dashbrrd, as a local SPM package.
// The App/ target (built via the generated .xcodeproj) is a thin shell that depends on
// these products. Package boundaries ENFORCE the acyclic dependency graph:
//
//   App → AppCore → Features/* → DesignSystem
//                       │
//                       └─ ServarrKit / DownloadClientKit / PersistenceKit → Networking → CoreModel
//
// Dual-platform: iOS 18 is the ship target; macOS 15 exists only so the logic layers
// build + `swift test` on a Mac without booting a simulator. iOS-only runtime APIs are
// guarded with `#if os(iOS)`.

let strictConcurrency: [SwiftSetting] = [
    // tools 6.0 already defaults to Swift 6 language mode (full strict concurrency);
    // this is here as a belt-and-suspenders marker for future tool bumps.
    .swiftLanguageMode(.v6)
]

let package = Package(
    name: "dashbrrd-core",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CoreModel", targets: ["CoreModel"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "ServarrKit", targets: ["ServarrKit"]),
        .library(name: "DownloadClientKit", targets: ["DownloadClientKit"]),
        .library(name: "PersistenceKit", targets: ["PersistenceKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "FeatureCalendar", targets: ["FeatureCalendar"]),
        .library(name: "FeatureQueue", targets: ["FeatureQueue"]),
        .library(name: "FeatureLibrary", targets: ["FeatureLibrary"]),
        .library(name: "FeatureSearch", targets: ["FeatureSearch"]),
        .library(name: "FeatureHistory", targets: ["FeatureHistory"]),
        .library(name: "FeatureHealth", targets: ["FeatureHealth"]),
        .library(name: "FeatureSettings", targets: ["FeatureSettings"]),
    ],
    targets: [
        // MARK: - Foundation layers
        .target(
            name: "CoreModel",
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "Networking",
            dependencies: ["CoreModel"],
            swiftSettings: strictConcurrency
        ),

        // MARK: - Service engines (no SwiftUI / SwiftData)
        .target(
            name: "ServarrKit",
            dependencies: ["Networking", "CoreModel"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "DownloadClientKit",
            dependencies: ["Networking", "CoreModel"],
            swiftSettings: strictConcurrency
        ),

        // MARK: - Persistence (SwiftData + Keychain)
        .target(
            name: "PersistenceKit",
            dependencies: ["Networking", "CoreModel"],
            swiftSettings: strictConcurrency
        ),

        // MARK: - UI foundation
        .target(
            name: "DesignSystem",
            dependencies: ["CoreModel"],
            swiftSettings: strictConcurrency
        ),

        // MARK: - Feature modules (never depend on each other)
        .target(
            name: "FeatureCalendar",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureQueue",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "DownloadClientKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureLibrary",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureSearch",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "DownloadClientKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureHistory",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureHealth",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FeatureSettings",
            dependencies: ["DesignSystem", "CoreModel", "ServarrKit", "DownloadClientKit", "PersistenceKit"],
            swiftSettings: strictConcurrency
        ),

        // MARK: - Composition layer
        .target(
            name: "AppCore",
            dependencies: [
                "CoreModel", "Networking", "DesignSystem",
                "ServarrKit", "DownloadClientKit", "PersistenceKit",
                "FeatureCalendar", "FeatureQueue", "FeatureLibrary",
                "FeatureSearch", "FeatureHistory", "FeatureHealth", "FeatureSettings",
            ],
            swiftSettings: strictConcurrency
        ),

        // MARK: - Test targets
        .testTarget(
            name: "CoreModelTests",
            dependencies: ["CoreModel"],
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking", "CoreModel"],
            swiftSettings: strictConcurrency
        ),
    ]
)
