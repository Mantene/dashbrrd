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

    public init() {}

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
        case .dashboard: DashboardScreen()
        case .calendar: CalendarScreen()
        case .queue: QueueScreen()
        case .library: LibraryScreen()
        case .activity: HistoryScreen()
        case .settings: SettingsScreen()
        }
    }
}

/// Minimal Phase 0 dashboard placeholder (the real aggregated overview comes in Phase 2).
struct DashboardScreen: View {
    var body: some View {
        ContentUnavailableView(
            "Dashboard",
            systemImage: "square.grid.2x2",
            description: Text("An at-a-glance overview of all your servers will live here.")
        )
    }
}
