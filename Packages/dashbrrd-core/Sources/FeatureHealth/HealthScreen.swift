import SwiftUI
import CoreModel
import DesignSystem

/// Aggregated Health view: per-instance failures as chips, then health checks worst-first.
public struct HealthScreen: View {
    @State private var store: HealthStore

    public init(store: HealthStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Checking health…")
            case let .failed(message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case let .loaded(checks):
                content(checks)
            }
        }
        .navigationTitle("Health")
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    @ViewBuilder
    private func content(_ checks: [HealthCheck]) -> some View {
        if checks.isEmpty && store.failures.isEmpty {
            ContentUnavailableView(
                "All Clear",
                systemImage: "checkmark.seal",
                description: Text("No health issues reported across your servers.")
            )
        } else {
            List {
                if !store.failures.isEmpty {
                    Section("Unreachable") {
                        ForEach(store.failures) { failure in
                            Label("\(failure.displayName): \(failure.message)", systemImage: "wifi.exclamationmark")
                                .foregroundStyle(.orange).font(.footnote)
                        }
                    }
                }
                if !checks.isEmpty {
                    Section("Checks") {
                        ForEach(checks) { check in
                            HealthRow(check: check)
                        }
                    }
                }
            }
        }
    }
}

struct HealthRow: View {
    let check: HealthCheck

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: check.severity.symbolName)
                .foregroundStyle(check.severity.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.message).font(.subheadline)
                Text(check.source).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension HealthCheck.Severity {
    public var symbolName: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .notice: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .ok: .green
        case .notice: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}
