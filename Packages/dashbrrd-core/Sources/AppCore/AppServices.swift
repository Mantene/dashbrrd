import Foundation
import SwiftData
import PersistenceKit
import FeatureSettings
import FeatureCalendar

/// The composed set of live service implementations, built once from infrastructure and
/// handed to `RootView`, which constructs the feature stores from them. This is the bridge
/// between the App's composition root and the feature layer's injected protocols.
@MainActor
public struct AppServices {
    let serverStore: any ServerStoring
    let connectionTester: any ConnectionTesting
    let calendarLoader: any CalendarLoading

    public init(container: ModelContainer, keychain: KeychainStore) {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        self.serverStore = LiveServerStore(repository: repository)
        self.connectionTester = LiveConnectionTester()
        self.calendarLoader = CalendarAggregator(container: container, keychain: keychain)
    }
}

