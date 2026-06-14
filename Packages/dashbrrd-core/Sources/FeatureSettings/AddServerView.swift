import SwiftUI
import CoreModel
import DesignSystem

/// The add-server flow: collect URL/port/base-path/API-key, run a **mandatory** connection
/// test against a cheap identity endpoint, and only enable Save once the server answered.
public struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    let store: SettingsStore

    @State private var draft = ServerDraft(scheme: "http")

    public init(store: SettingsStore) {
        self.store = store
    }

    private var canSave: Bool {
        if case .result(.success) = store.testState { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    Picker("Type", selection: $draft.kind) {
                        ForEach(ServiceKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    TextField("Display name", text: $draft.displayName)
                        .dsTextContentField(autocapitalize: true)
                }

                Section("Connection") {
                    Picker("Scheme", selection: $draft.scheme) {
                        Text("http").tag("http")
                        Text("https").tag("https")
                    }
                    .pickerStyle(.segmented)

                    TextField("Host or IP", text: $draft.host)
                        .dsURLKeyboard()

                    TextField("Port (optional)", value: $draft.port, format: .number.grouping(.never))
                        .dsNumberKeyboard()

                    TextField("Base path (e.g. /sonarr)", text: Binding(
                        get: { draft.basePath ?? "" },
                        set: { draft.basePath = $0.isEmpty ? nil : $0 }
                    ))
                    .dsTextContentField()
                }

                Section("Authentication") {
                    SecureField("API Key", text: $draft.apiKey)
                        .dsTextContentField()
                }

                Section {
                    testRow
                } footer: {
                    if draft.scheme == "http" {
                        Label("This connection is not encrypted.", systemImage: "lock.open")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Add Server")
            .dsInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.save(filledDraft) { dismiss() }
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: draft) { store.resetTest() }
            .onDisappear { store.resetTest() }
        }
    }

    /// Default the display name to the host if the user left it blank.
    private var filledDraft: ServerDraft {
        var d = draft
        if d.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            d.displayName = d.host.isEmpty ? d.kind.displayName : d.host
        }
        return d
    }

    @ViewBuilder
    private var testRow: some View {
        Button {
            Task { await store.runTest(filledDraft) }
        } label: {
            HStack {
                Text("Test Connection")
                Spacer()
                switch store.testState {
                case .idle: EmptyView()
                case .testing: ProgressView()
                case let .result(outcome): outcomeBadge(outcome)
                }
            }
        }
        .disabled(draft.host.isEmpty || draft.apiKey.isEmpty)

        if case let .result(outcome) = store.testState {
            outcomeMessage(outcome)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func outcomeBadge(_ outcome: ConnectionOutcome) -> some View {
        switch outcome {
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func outcomeMessage(_ outcome: ConnectionOutcome) -> some View {
        switch outcome {
        case let .success(version, appName):
            Text("Connected to \(appName) \(version).").foregroundStyle(.green)
        case .unauthorized:
            Text("API key rejected. Double-check the key.").foregroundStyle(.orange)
        case .reachableButNoAPI:
            Text("Reachable, but no \(draft.kind.displayName) API here — check the base path.").foregroundStyle(.orange)
        case let .unreachable(message):
            Text("Couldn't reach the host: \(message)").foregroundStyle(.orange)
        case let .untrustedCertificate(host, fingerprint):
            Text("Untrusted certificate for \(host) (SHA-256 \(fingerprint.prefix(16))…). Cert pinning lands in a later step.").foregroundStyle(.orange)
        case let .failed(message):
            Text(message).foregroundStyle(.orange)
        }
    }
}
