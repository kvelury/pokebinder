import Foundation

/// The remote half of a sync: pull the full ownership table, then write queued edits.
@MainActor
public protocol OwnershipRemoteClient: AnyObject {
    func fetchAll() async throws -> (ownership: [Int: Bool], pageIds: [Int: String])
    func setOwned(dex: Int, owned: Bool) async throws
}

public enum OwnershipSyncOutcome: Equatable, Sendable {
    case completed(OwnershipSyncState, writeFailures: [Int: String])
    case skippedAlreadyRunning
    case failed(String)
}

/// Serializes two-way syncs so a timer tick and a manual resync cannot overlap.
@MainActor
public final class OwnershipSyncCoordinator {
    public private(set) var isRunning = false

    public init() {}

    public func sync(
        client: any OwnershipRemoteClient,
        state: OwnershipSyncState
    ) async -> OwnershipSyncOutcome {
        if isRunning {
            return .skippedAlreadyRunning
        }
        isRunning = true
        defer { isRunning = false }

        do {
            let (remote, pageIds) = try await client.fetchAll()
            let merged = OwnershipReconciler.merge(remote: remote, pending: state.pendingEdits)
            var remaining = state.pendingEdits
            var failures: [Int: String] = [:]
            for (dex, owned) in remaining.sorted(by: { $0.key < $1.key }) {
                do {
                    try await client.setOwned(dex: dex, owned: owned)
                    remaining.removeValue(forKey: dex)
                } catch {
                    failures[dex] = error.localizedDescription
                }
            }
            remaining = OwnershipReconciler.remainingPending(
                from: remaining,
                failedDexes: Set(failures.keys)
            )
            return .completed(
                OwnershipSyncState(
                    ownership: merged,
                    pageIds: pageIds,
                    pendingEdits: remaining,
                    lastSyncedAt: Date()
                ),
                writeFailures: failures
            )
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
