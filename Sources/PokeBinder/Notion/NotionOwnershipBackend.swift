import Foundation
import PokeBinderSync

/// The only integration point between Notion and the binder: a conformance of
/// `OwnershipBackend`. Views never see this type; they keep talking to
/// `CollectionStore`. Toggles enqueue a durable local edit; `resync` pulls
/// Notion and flushes the queue.
@MainActor
final class NotionOwnershipBackend: OwnershipBackend {
    private let manager: NotionManager

    init(manager: NotionManager) {
        self.manager = manager
    }

    var displayName: String { manager.workspaceDisplayName }

    var remoteClient: any OwnershipRemoteClient { manager }

    func currentState() -> OwnershipSyncState {
        OwnershipSnapshot.load()?.syncState ?? OwnershipSyncState()
    }

    func cachedOwnership() -> [Int: Bool]? {
        guard let contents = OwnershipSnapshot.load() else { return nil }
        let merged = OwnershipReconciler.merge(
            remote: contents.ownership,
            pending: contents.pendingEdits
        )
        guard !merged.isEmpty || !contents.pageIds.isEmpty || !contents.pendingEdits.isEmpty else {
            return nil
        }
        return merged
    }

    func persist(_ state: OwnershipSyncState) {
        OwnershipSnapshot.save(state)
    }

    func loadOwnership() async throws -> [Int: Bool] {
        let (ownership, pageIds) = try await manager.fetchAll()
        let existing = OwnershipSnapshot.load()
        let pending = existing?.pendingEdits ?? [:]
        let lastSyncedAt = existing?.lastSyncedAt
        let merged = OwnershipReconciler.merge(remote: ownership, pending: pending)
        OwnershipSnapshot.save(
            ownership: merged,
            pageIds: pageIds,
            pendingEdits: pending,
            lastSyncedAt: lastSyncedAt
        )
        return merged
    }

    func setOwned(dex: Int, owned: Bool) async throws {
        OwnershipSnapshot.enqueue(dex: dex, owned: owned)
    }
}
