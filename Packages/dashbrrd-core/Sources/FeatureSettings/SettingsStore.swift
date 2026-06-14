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

    /// Transient status line for the Background Refresh section.
    public var refreshStatus: String?
    public private(set) var isRefreshing = false

    private let store: any ServerStoring
    private let tester: any ConnectionTesting
    private let refresher: any BackgroundRefreshing

    public init(store: any ServerStoring, tester: any ConnectionTesting, refresher: any BackgroundRefreshing) {
        self.store = store
        self.tester = tester
        self.refresher = refresher
    }

    public func refreshNow() async {
        isRefreshing = true
        let count = await refresher.refreshNow()
        isRefreshing = false
        refreshStatus = count == 0 ? "Up to date — no new updates." : "Surfaced \(count) update\(count == 1 ? "" : "s")."
    }

    public func enableNotifications() async {
        await refresher.requestNotifications()
        refreshStatus = "Notification permission requested."
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
