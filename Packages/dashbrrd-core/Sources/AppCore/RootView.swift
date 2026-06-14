import SwiftUI
import CoreModel
import DesignSystem
import FeatureCalendar
import FeatureQueue
import FeatureLibrary
import FeatureSearch
import FeatureHistory
import FeatureHealth
import FeatureSettings

/// The adaptive root. Chooses a `TabView` (compact / iPhone) or `NavigationSplitView`
/// (regular / iPad) by horizontal size class, but both drive the *same* `NavigationModel`
/// so selection and per-section paths survive rotation and split-resize.
public struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var navigation = NavigationModel()
    @State private var settingsStore: SettingsStore
    @State private var calendarStore: CalendarStore
    @State private var healthStore: HealthStore
    @State private var dashboardStore: DashboardStore
    @State private var libraryStore: LibraryStore
    @State private var queueStore: QueueStore
    @State private var historyStore: HistoryStore

    public init(services: AppServices) {
        _settingsStore = State(initialValue: SettingsStore(
            store: services.serverStore,
            tester: services.connectionTester,
            refresher: services.refreshCoordinator
        ))
        _calendarStore = State(initialValue: CalendarStore(loader: services.calendarLoader))
        _healthStore = State(initialValue: HealthStore(loader: services.healthLoader))
        _dashboardStore = State(initialValue: DashboardStore(
            calendarLoader: services.calendarLoader,
            healthLoader: services.healthLoader
        ))
        _libraryStore = State(initialValue: LibraryStore(
            loader: services.libraryLoader,
            controller: services.mediaController,
            releaseSearcher: services.releaseSearcher,
            releaseGrabber: services.releaseGrabber,
            adder: services.mediaAdder
        ))
        _queueStore = State(initialValue: QueueStore(
            loader: services.queueLoader,
            controller: services.queueController,
            manualImporter: services.manualImporter
        ))
        _historyStore = State(initialValue: HistoryStore(loader: services.historyLoader))
    }

    public var body: some View {
        #if os(iOS)
        if sizeClass == .compact {
            compactTabs
        } else {
            splitLayout
        }
        #else
        splitLayout
        #endif
    }

    // MARK: - Compact (iPhone)

    private var compactTabs: some View {
        TabView(selection: $navigation.selectedSection) {
            ForEach(NavigationModel.Section.allCases) { section in
                NavigationStack {
                    screen(for: section)
                        .navigationTitle(section.title)
                }
                .tabItem { Label(section.title, systemImage: section.symbolName) }
                .tag(section)
            }
        }
    }

    // MARK: - Regular (iPad / macOS)

    private var splitLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(NavigationModel.Section.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .navigationTitle("dashbrrd")
        } detail: {
            NavigationStack {
                screen(for: navigation.selectedSection)
                    .navigationTitle(navigation.selectedSection.title)
            }
        }
    }

    /// iOS single-selection `List` requires an optional binding; bridge it to the
    /// non-optional `NavigationModel.selectedSection`, ignoring deselection-to-nil.
    private var sidebarSelection: Binding<NavigationModel.Section?> {
        Binding(
            get: { navigation.selectedSection },
            set: { if let newValue = $0 { navigation.selectedSection = newValue } }
        )
    }

    // MARK: - Section → feature screen

    @ViewBuilder
    private func screen(for section: NavigationModel.Section) -> some View {
        switch section {
        case .dashboard: DashboardScreen(store: dashboardStore, healthStore: healthStore)
        case .calendar: CalendarScreen(store: calendarStore)
        case .queue: QueueScreen(store: queueStore)
        case .library: LibraryScreen(store: libraryStore)
        case .activity: HistoryScreen(store: historyStore)
        case .settings: SettingsScreen(store: settingsStore)
        }
    }
}
