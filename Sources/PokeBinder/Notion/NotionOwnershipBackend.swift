import Foundation

/// The only integration point between Notion and the binder: a conformance of
/// `OwnershipBackend`. Views never see this type; they keep talking to
/// `CollectionStore`, which already does the optimistic flip + revert-on-error.
@MainActor
final class NotionOwnershipBackend: OwnershipBackend {
    private let manager: NotionManager

    init(manager: NotionManager) {
        self.manager = manager
    }

    var displayName: String { manager.workspaceDisplayName }

    func cachedOwnership() -> [Int: Bool]? {
        OwnershipSnapshot.load()?.ownership
    }

    func loadOwnership() async throws -> [Int: Bool] {
        let (ownership, pageIds) = try await manager.fetchAll()
        OwnershipSnapshot.save(ownership: ownership, pageIds: pageIds)
        return ownership
    }

    func setOwned(dex: Int, owned: Bool) async throws {
        try await manager.setOwned(dex: dex, owned: owned)
        OwnershipSnapshot.update(dex: dex, owned: owned)
    }
}
