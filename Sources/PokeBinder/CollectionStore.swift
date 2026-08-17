import Foundation
import PokeBinderSync
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

    /// Persist a single change. For the local backend this writes immediately.
    /// For Notion it queues the edit; `CollectionStore` flushes the queue on sync.
    /// Throwing here makes `CollectionStore` revert the optimistic local flip.
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
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingEditCount = 0
    @Published var errorMessage: String?

    private(set) var backend: OwnershipBackend
    private let syncCoordinator = OwnershipSyncCoordinator()

    /// The default backend is built in the body rather than as a default argument:
    /// default-argument expressions are evaluated in a nonisolated context, which
    /// cannot call a `@MainActor` initializer.
    init(backend: OwnershipBackend? = nil) {
        self.backend = backend ?? LocalOwnershipBackend()
    }

    var ownedCount: Int { owned.count }
    var totalCount: Int { Pokedex.count }
    var backendName: String { backend.displayName }
    var isSyncing: Bool { isLoading }

    func isOwned(_ dex: Int) -> Bool { owned.contains(dex) }

    /// Swap the source of truth at runtime — how part 3 connects Notion without a relaunch.
    func use(_ newBackend: OwnershipBackend) async {
        backend = newBackend
        await load()
    }

    func load() async {
        paintNotionCacheIfNeeded()
        await performSync()
    }

    /// Manual and scheduled refresh share this path: pull Notion, overlay queued
    /// local edits, push the queue, persist the merge.
    func resync() async {
        guard backend is NotionOwnershipBackend else { return }
        await performSync()
    }

    func syncIfDue(
        interval: NotionSyncInterval,
        customMinutes: Int,
        now: Date = Date()
    ) async {
        guard backend is NotionOwnershipBackend else { return }
        guard NotionSyncScheduling.isDue(
            lastSyncedAt: lastSyncedAt,
            interval: interval,
            customMinutes: customMinutes,
            now: now
        ) else { return }
        await performSync()
    }

    /// Optimistic: flip locally first so the UI never waits on the network, then
    /// persist. Notion-backed edits are queued until the next sync. On failure
    /// put the old value back and report why.
    func setOwned(_ dex: Int, _ value: Bool) async {
        let previous = owned
        if value { owned.insert(dex) } else { owned.remove(dex) }
        do {
            try await backend.setOwned(dex: dex, owned: value)
            refreshPendingMetadata()
            errorMessage = nil
        } catch {
            owned = previous
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ dex: Int) async {
        await setOwned(dex, !isOwned(dex))
    }

    private func paintNotionCacheIfNeeded() {
        guard let notion = backend as? NotionOwnershipBackend else { return }
        if let cached = notion.cachedOwnership() {
            owned = Set(cached.filter(\.value).map(\.key))
        }
        refreshPendingMetadata()
    }

    private func refreshPendingMetadata() {
        guard let notion = backend as? NotionOwnershipBackend else {
            pendingEditCount = 0
            return
        }
        let state = notion.currentState()
        pendingEditCount = state.pendingEdits.count
        if lastSyncedAt == nil {
            lastSyncedAt = state.lastSyncedAt
        }
    }

    private func performSync() async {
        guard let notion = backend as? NotionOwnershipBackend else {
            await loadLocal()
            return
        }

        if !isLoading {
            isLoading = true
        }
        let outcome = await syncCoordinator.sync(client: notion.remoteClient, state: notion.currentState())
        switch outcome {
        case .skippedAlreadyRunning:
            return
        case .failed(let message):
            errorMessage = message
            isLoading = false
        case .completed(let state, let writeFailures):
            notion.persist(state)
            owned = Set(state.ownership.filter(\.value).map(\.key))
            lastSyncedAt = state.lastSyncedAt
            pendingEditCount = state.pendingEdits.count
            errorMessage = writeFailures.sorted(by: { $0.key < $1.key }).first?.value
            isLoading = false
        }
    }

    private func loadLocal() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ownership = try await backend.loadOwnership()
            owned = Set(ownership.filter(\.value).map(\.key))
            pendingEditCount = 0
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
