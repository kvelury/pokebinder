import Foundation
import SwiftUI

/// Where ownership comes from and goes to.
///
/// **This is the seam between part 1 and part 3.** Part 1 ships `LocalOwnershipBackend`
/// so the binder is fully usable with no network. Part 3 adds a Notion-backed
/// conformance and hands it to `CollectionStore.use(_:)` — no view code changes,
/// because no view knows where ownership lives.
@MainActor
protocol OwnershipBackend: AnyObject {
    /// Shown in Settings, e.g. "On this Mac" or a Notion workspace name.
    var displayName: String { get }

    /// Full state of the collection, keyed by Pokédex number.
    func loadOwnership() async throws -> [Int: Bool]

    /// Persist a single change. Throwing here makes `CollectionStore` revert the
    /// optimistic local flip and surface the error.
    func setOwned(dex: Int, owned: Bool) async throws
}

/// Part 1's backend: ownership lives on this Mac only.
@MainActor
final class LocalOwnershipBackend: OwnershipBackend {
    private let defaultsKey = "localOwnedDexNumbers"

    var displayName: String { "On this Mac" }

    func loadOwnership() async throws -> [Int: Bool] {
        let stored = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        let ownedSet = Set(stored)
        return Dictionary(uniqueKeysWithValues: (1...Pokedex.count).map { ($0, ownedSet.contains($0)) })
    }

    func setOwned(dex: Int, owned: Bool) async throws {
        var stored = Set(UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? [])
        if owned { stored.insert(dex) } else { stored.remove(dex) }
        UserDefaults.standard.set(Array(stored).sorted(), forKey: defaultsKey)
    }
}

/// The collection as the UI sees it. Views only ever talk to this.
@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var owned: Set<Int> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private(set) var backend: OwnershipBackend

    /// The default backend is built in the body rather than as a default argument:
    /// default-argument expressions are evaluated in a nonisolated context, which
    /// cannot call a `@MainActor` initializer.
    init(backend: OwnershipBackend? = nil) {
        self.backend = backend ?? LocalOwnershipBackend()
    }

    var ownedCount: Int { owned.count }
    var totalCount: Int { Pokedex.count }
    var backendName: String { backend.displayName }

    func isOwned(_ dex: Int) -> Bool { owned.contains(dex) }

    /// Swap the source of truth at runtime — how part 3 connects Notion without a relaunch.
    func use(_ newBackend: OwnershipBackend) async {
        backend = newBackend
        await load()
    }

    func load() async {
        // Paint the snapshot immediately so a relaunch with a stored token
        // doesn't wait on the network. `NotionOwnershipBackend` is the only
        // backend that has one; the protocol itself is unchanged.
        if let notion = backend as? NotionOwnershipBackend, let cached = notion.cachedOwnership() {
            owned = Set(cached.filter(\.value).map(\.key))
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let ownership = try await backend.loadOwnership()
            owned = Set(ownership.filter(\.value).map(\.key))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Optimistic: flip locally first so the UI never waits on the network, then
    /// persist. On failure put the old value back and report why.
    func setOwned(_ dex: Int, _ value: Bool) async {
        let previous = owned
        if value { owned.insert(dex) } else { owned.remove(dex) }
        do {
            try await backend.setOwned(dex: dex, owned: value)
            errorMessage = nil
        } catch {
            owned = previous
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ dex: Int) async {
        await setOwned(dex, !isOwned(dex))
    }
}
