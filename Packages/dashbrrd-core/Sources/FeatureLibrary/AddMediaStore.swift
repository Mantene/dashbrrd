import Foundation
import SwiftUI
import Observation
import CoreModel

/// `@MainActor @Observable` store for the add-new-media flow: pick an instance, search, choose
/// options, add.
@MainActor
@Observable
public final class AddMediaStore {
    public private(set) var targets: [AddTarget] = []
    public var selectedTarget: AddTarget?

    public var term: String = ""
    public private(set) var results: LoadState<[MediaLookupItem]> = .idle

    public private(set) var options: AddOptions?
    public private(set) var optionsError: String?

    public private(set) var addingID: String?
    public private(set) var addedIDs: Set<String> = []
    public var addError: String?

    private let adder: any MediaAdding

    public init(adder: any MediaAdding) {
        self.adder = adder
    }

    public func loadTargets() async {
        targets = await adder.addableInstances()
        if selectedTarget == nil { selectedTarget = targets.first }
    }

    public func search() async {
        guard let target = selectedTarget, term.trimmingCharacters(in: .whitespaces).count >= 2 else {
            results = .idle
            return
        }
        results = .loading
        do {
            results = .loaded(try await adder.lookup(target, term: term))
        } catch {
            results = .failed(message: error.localizedDescription)
        }
    }

    /// Loads quality profiles + root folders for the selected target (lazily, before adding).
    public func ensureOptions() async {
        guard let target = selectedTarget else { return }
        do {
            options = try await adder.options(target)
            optionsError = nil
        } catch {
            optionsError = error.localizedDescription
        }
    }

    public func add(_ item: MediaLookupItem, qualityProfileID: Int, rootFolderPath: String, monitored: Bool, searchOnAdd: Bool) async {
        guard let target = selectedTarget else { return }
        addingID = item.id
        defer { addingID = nil }
        do {
            try await adder.add(item, to: target, qualityProfileID: qualityProfileID, rootFolderPath: rootFolderPath, monitored: monitored, searchOnAdd: searchOnAdd)
            addedIDs.insert(item.id)
        } catch {
            addError = "Couldn't add \(item.title): \(error.localizedDescription)"
        }
    }

    public func isAdding(_ item: MediaLookupItem) -> Bool { addingID == item.id }
    public func isAdded(_ item: MediaLookupItem) -> Bool { addedIDs.contains(item.id) || item.alreadyInLibrary }
}
