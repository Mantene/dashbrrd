import SwiftUI

/// Add or edit a service connection, with a live "Test Connection" probe.
struct InstanceEditView: View {
    @Environment(ConfigStore.self) private var configStore
    @Environment(\.dismiss) private var dismiss

    let existing: ServiceInstance?

    @State private var type: ServiceType
    @State private var name: String
    @State private var scheme: String
    @State private var host: String
    @State private var port: String
    @State private var urlBase: String
    @State private var allowInsecureTLS: Bool
    @State private var isEnabled: Bool

    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var testState: TestState = .idle

    private var isNew: Bool { existing == nil }

    init(existing: ServiceInstance?) {
        self.existing = existing
        let base = existing ?? ServiceInstance.makeDefault(type: .sonarr)
        _type = State(initialValue: base.type)
        _name = State(initialValue: base.name)
        _scheme = State(initialValue: base.scheme)
        _host = State(initialValue: base.host)
        _port = State(initialValue: String(base.port))
        _urlBase = State(initialValue: base.urlBase)
        _allowInsecureTLS = State(initialValue: base.allowInsecureTLS)
        _isEnabled = State(initialValue: base.isEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    Picker("Type", selection: $type) {
                        ForEach(ServiceType.allCases) { t in
                            Label(t.displayName, systemImage: t.symbolName).tag(t)
                        }
                    }
                    .disabled(!isNew)
                    .onChange(of: type) { _, newValue in applyTypeDefaults(newValue) }

                    TextField("Display name", text: $name)
                }

                Section("Connection") {
                    Picker("Scheme", selection: $scheme) {
                        Text("http").tag("http")
                        Text("https").tag("https")
                    }
                    .pickerStyle(.segmented)
                    TextField("Host or IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("URL base (optional)", text: $urlBase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if scheme == "https" {
                        Toggle("Allow insecure TLS", isOn: $allowInsecureTLS)
                    }
                }

                Section("Authentication") {
                    if type.credentialKind == .apiKey {
                        SecureField("API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section {
                    Button(action: runTest) {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            testStatusView
                        }
                    }
                    .disabled(testState == .testing || !isValid)
                    if case let .failure(message) = testState {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isNew ? "Add Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .onAppear(perform: loadExistingCredential)
        }
    }

    @ViewBuilder private var testStatusView: some View {
        switch testState {
        case .idle: EmptyView()
        case .testing: ProgressView()
        case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - Derived

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(port) != nil
    }

    private func makeInstance() -> ServiceInstance {
        ServiceInstance(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            scheme: scheme,
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? type.defaultPort,
            urlBase: urlBase,
            allowInsecureTLS: allowInsecureTLS,
            isEnabled: isEnabled
        )
    }

    private func makeCredential() -> AuthCredential {
        switch type.credentialKind {
        case .apiKey: .apiKey(apiKey)
        case .usernamePassword: .usernamePassword(username: username, password: password)
        }
    }

    // MARK: - Actions

    private func applyTypeDefaults(_ newValue: ServiceType) {
        if name.isEmpty || ServiceType.allCases.contains(where: { $0.displayName == name }) {
            name = newValue.displayName
        }
        if Int(port) == nil || ServiceType.allCases.contains(where: { $0.defaultPort == Int(port) }) {
            port = String(newValue.defaultPort)
        }
        testState = .idle
    }

    private func loadExistingCredential() {
        guard let existing, let credential = configStore.credential(for: existing) else { return }
        switch credential {
        case let .apiKey(key): apiKey = key
        case let .usernamePassword(user, pass): username = user; password = pass
        }
    }

    private func runTest() {
        testState = .testing
        let instance = makeInstance()
        let credential = makeCredential()
        Task {
            do {
                try await ConnectionTester.test(instance: instance, credential: credential)
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }

    private func save() {
        do {
            try configStore.upsert(makeInstance(), credential: makeCredential())
            dismiss()
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }

    enum TestState: Equatable {
        case idle, testing, success
        case failure(String)
    }
}
