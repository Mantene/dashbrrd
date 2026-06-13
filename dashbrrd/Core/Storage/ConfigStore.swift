import Foundation
import Observation

/// Source of truth for configured instances. Persists non-secret config as JSON in
/// Application Support; delegates secret storage to `KeychainStore`.
@Observable
final class ConfigStore {
    private(set) var instances: [ServiceInstance] = []

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let fileURL: URL

    init(keychain: KeychainStore = KeychainStore(), fileURL: URL? = nil) {
        self.keychain = keychain
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    // MARK: - Queries

    var enabledInstances: [ServiceInstance] { instances.filter(\.isEnabled) }

    func instances(ofKind predicate: (ServiceType) -> Bool) -> [ServiceInstance] {
        instances.filter { predicate($0.type) }
    }

    func credential(for instance: ServiceInstance) -> AuthCredential? {
        keychain.load(for: instance.id)
    }

    // MARK: - Mutations

    func upsert(_ instance: ServiceInstance, credential: AuthCredential?) throws {
        if let credential { try keychain.save(credential, for: instance.id) }
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = instance
        } else {
            instances.append(instance)
        }
        persist()
    }

    func delete(_ instance: ServiceInstance) {
        instances.removeAll { $0.id == instance.id }
        keychain.delete(for: instance.id)
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        instances.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([ServiceInstance].self, from: data) {
            instances = decoded
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(instances)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal: in-memory state remains correct for this session.
            print("ConfigStore persist failed: \(error)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("dashbrrd/instances.json")
    }
}
