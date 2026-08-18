import Foundation

/// Last-known ownership, Notion row ids, and any app edits waiting to be written.
public struct OwnershipSyncState: Equatable, Sendable {
    public var ownership: [Int: Bool]
    public var pageIds: [Int: String]
    public var pendingEdits: [Int: Bool]
    public var lastSyncedAt: Date?

    public init(
        ownership: [Int: Bool] = [:],
        pageIds: [Int: String] = [:],
        pendingEdits: [Int: Bool] = [:],
        lastSyncedAt: Date? = nil
    ) {
        self.ownership = ownership
        self.pageIds = pageIds
        self.pendingEdits = pendingEdits
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Pure merge rules for Notion pull + queued local writes.
public enum OwnershipReconciler {
    /// A pending app edit is authoritative for that Pokédex number. Every other
    /// remote value is taken as-is.
    public static func merge(remote: [Int: Bool], pending: [Int: Bool]) -> [Int: Bool] {
        var merged = remote
        for (dex, owned) in pending {
            merged[dex] = owned
        }
        return merged
    }

    /// Successful writes leave the queue; failed writes stay for the next sync.
    public static func remainingPending(
        from pending: [Int: Bool],
        failedDexes: Set<Int>
    ) -> [Int: Bool] {
        pending.filter { failedDexes.contains($0.key) }
    }
}
