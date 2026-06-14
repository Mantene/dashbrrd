import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store backing the Settings feature. Holds the list of configured
/// servers and the transient state of the add-server flow. Depends only on injected protocols
/// so it fakes cleanly in previews/tests.
@MainActor
@Observable
public final class SettingsStore {
    public private(set) var servers: [ServerConfig] = []
    public private(set) var loadError: String?

    /// Live state of an in-progress connection test in the add-server sheet.
    public enum TestState: Equatable {
        case idle
        case testing
        case result(ConnectionOutcome)
    }
    public var testState: TestState = .idle

    private let store: any ServerStoring
    private let tester: any ConnectionTesting

    public init(store: any ServerStoring, tester: any ConnectionTesting) {
        self.store = store
        self.tester = tester
    }

    public func refresh() {
        do {
            servers = try store.load()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    public func runTest(_ draft: ServerDraft) async {
        testState = .testing
        let outcome = await tester.test(draft)
        testState = .result(outcome)
    }

    /// Persists the draft. Returns `true` on success so the caller can dismiss the sheet.
    public func save(_ draft: ServerDraft) -> Bool {
        do {
            _ = try store.add(draft)
            refresh()
            return true
        } catch {
            testState = .result(.failed(message: error.localizedDescription))
            return false
        }
    }

    public func delete(_ config: ServerConfig) {
        do {
            try store.delete(config)
            refresh()
        } catch {
            loadError = error.localizedDescription
        }
    }

    public func resetTest() {
        testState = .idle
    }
}
