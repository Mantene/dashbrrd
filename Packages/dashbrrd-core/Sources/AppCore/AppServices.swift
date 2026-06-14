import Foundation
import SwiftData
import PersistenceKit
import FeatureSettings
import FeatureCalendar
import FeatureHealth
import FeatureLibrary
import FeatureQueue
import FeatureHistory

/// The composed set of live service implementations, built once from infrastructure and
/// handed to `RootView`, which constructs the feature stores from them. This is the bridge
/// between the App's composition root and the feature layer's injected protocols.
@MainActor
public struct AppServices {
    let serverStore: any ServerStoring
    let connectionTester: any ConnectionTesting
    let calendarLoader: any CalendarLoading
    let healthLoader: any HealthLoading
    let libraryLoader: any LibraryLoading
    let mediaController: any MediaControlling
    let releaseSearcher: any ReleaseSearching
    let releaseGrabber: any ReleaseGrabbing
    let mediaAdder: any MediaAdding
    let queueLoader: any QueueLoading
    let queueController: any QueueControlling
    let manualImporter: any ManualImporting
    let historyLoader: any HistoryLoading

    public init(container: ModelContainer, keychain: KeychainStore) {
        let repository = ServerConfigRepository(context: container.mainContext, keychain: keychain)
        self.serverStore = LiveServerStore(repository: repository)
        self.connectionTester = LiveConnectionTester()
        self.calendarLoader = CalendarAggregator(container: container, keychain: keychain)
        self.healthLoader = HealthAggregator(container: container, keychain: keychain)
        self.libraryLoader = LibraryAggregator(container: container, keychain: keychain)
        self.mediaController = LiveMediaController(container: container, keychain: keychain)
        let releaseController = LiveReleaseController(container: container, keychain: keychain)
        self.releaseSearcher = releaseController
        self.releaseGrabber = releaseController
        self.mediaAdder = LiveMediaAdder(container: container, keychain: keychain)
        self.queueLoader = QueueAggregator(container: container, keychain: keychain)
        self.queueController = LiveQueueController(container: container, keychain: keychain)
        self.manualImporter = LiveManualImporter(container: container, keychain: keychain)
        self.historyLoader = HistoryAggregator(container: container, keychain: keychain)
    }
}

