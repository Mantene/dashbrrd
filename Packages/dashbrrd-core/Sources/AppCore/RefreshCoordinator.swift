import Foundation
import CoreModel
import PersistenceKit
import FeatureQueue
import FeatureHealth
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Coordinates background refresh: fetch a small, high-signal set (queue + health), diff against
/// the persisted digests, surface only transitions as grouped local notifications, and persist
/// the new digests. BG is best-effort surfacing — never a source of truth; the foreground always
/// reconciles fully.
public struct RefreshCoordinator: Sendable {
    public static let taskIdentifier = "com.dashbrrd.refresh"

    private let queueLoader: any QueueLoading
    private let healthLoader: any HealthLoading
    private let digestStore: DigestStore

    public init(queueLoader: any QueueLoading, healthLoader: any HealthLoading, digestStore: DigestStore) {
        self.queueLoader = queueLoader
        self.healthLoader = healthLoader
        self.digestStore = digestStore
    }

    /// The core work, platform-agnostic: fetch → diff → notify → persist. Safe to call from a
    /// background task, on foreground, or from a manual "Refresh now".
    @discardableResult
    public func refreshNow() async -> Int {
        let queue = await queueLoader.loadQueue()
        let (queueNotes, queueDigest) = RefreshDiff.queue(previous: digestStore.loadQueue(), current: queue.items)
        digestStore.save(queue: queueDigest)

        let health = await healthLoader.loadHealth()
        let (healthNotes, healthDigest) = RefreshDiff.health(previous: digestStore.loadHealth(), current: health.checks)
        digestStore.save(health: healthDigest)

        let notes = queueNotes + healthNotes
        await post(notes)
        return notes.count
    }

    // MARK: - Notifications (iOS)

    public func requestNotificationAuthorization() async {
        #if canImport(UserNotifications)
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        #endif
    }

    private func post(_ notes: [RefreshNotification]) async {
        #if canImport(UserNotifications)
        guard !notes.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        // Coalesce: cap the burst so a big diff can't spam; summarize the remainder.
        let cap = 8
        for note in notes.prefix(cap) {
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = note.body
            content.threadIdentifier = note.threadID
            content.sound = .default
            let request = UNNotificationRequest(identifier: note.id, content: content, trigger: nil)
            try? await center.add(request)
        }
        if notes.count > cap {
            let content = UNMutableNotificationContent()
            content.title = "dashbrrd"
            content.body = "+\(notes.count - cap) more updates"
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "summary-\(notes.count)", content: content, trigger: nil))
        }
        #endif
    }

    // MARK: - Background task scheduling (iOS)

    #if os(iOS)
    /// Register at launch (before the app finishes launching). The handler reschedules first,
    /// then runs the refresh with an expiration guard.
    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            self.handle(refreshTask)
        }
    }

    /// Ask iOS to run us again no sooner than ~15 min (opportunistic — real cadence varies).
    public func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleNext() // always reschedule first
        // BGAppRefreshTask isn't Sendable, but it's only ever used on the handler's thread.
        nonisolated(unsafe) let task = task
        let work = Task {
            await refreshNow()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
    #endif
}
