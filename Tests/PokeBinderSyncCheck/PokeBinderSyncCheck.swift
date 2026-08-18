import Foundation
import PokeBinderSync

@main
enum PokeBinderSyncCheck {
    static func main() async {
        runIntervalChecks()
        runSnapshotChecks()
        runReconcilerChecks()
        await runCoordinatorChecks()

        if Check.failures > 0 {
            FileHandle.standardError.write(Data("\(Check.failures) failed\n".utf8))
            exit(1)
        }
        print("All PokeBinderSync checks passed")
    }

    private static func runIntervalChecks() {
        Check.isNil(NotionSyncInterval.manual.resolvedMinutes(customMinutes: 99))
        Check.equal(NotionSyncInterval.oneMinute.resolvedMinutes(customMinutes: 99), Optional(1))
        Check.equal(NotionSyncInterval.threeMinutes.resolvedMinutes(customMinutes: 99), Optional(3))
        Check.equal(NotionSyncInterval.fiveMinutes.resolvedMinutes(customMinutes: 99), Optional(5))
        Check.equal(NotionSyncInterval.eightMinutes.resolvedMinutes(customMinutes: 99), Optional(8))

        Check.equal(NotionSyncInterval.sanitizedCustomMinutes(0), 1)
        Check.equal(NotionSyncInterval.sanitizedCustomMinutes(-4), 1)
        Check.equal(NotionSyncInterval.sanitizedCustomMinutes(7), 7)
        Check.equal(NotionSyncInterval.sanitizedCustomMinutes(10_000), 24 * 60)
        Check.equal(NotionSyncInterval.custom.resolvedMinutes(customMinutes: 0), Optional(1))
        Check.equal(NotionSyncInterval.custom.resolvedMinutes(customMinutes: 12), Optional(12))

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fourMinutesAgo = now.addingTimeInterval(-4 * 60)
        Check.expect(
            !NotionSyncScheduling.isDue(
                lastSyncedAt: fourMinutesAgo,
                interval: .manual,
                customMinutes: 1,
                now: now
            ),
            "manual mode is never due"
        )
        Check.expect(
            NotionSyncScheduling.isDue(
                lastSyncedAt: fourMinutesAgo,
                interval: .threeMinutes,
                customMinutes: 10,
                now: now
            ),
            "3-minute interval is due after 4 minutes"
        )
        Check.expect(
            !NotionSyncScheduling.isDue(
                lastSyncedAt: fourMinutesAgo,
                interval: .fiveMinutes,
                customMinutes: 10,
                now: now
            ),
            "5-minute interval is not due after 4 minutes"
        )
        Check.expect(
            NotionSyncScheduling.isDue(
                lastSyncedAt: nil,
                interval: .oneMinute,
                customMinutes: 10,
                now: now
            ),
            "missing lastSyncedAt is overdue"
        )
        Check.expect(
            NotionSyncScheduling.isDue(
                lastSyncedAt: fourMinutesAgo,
                interval: .custom,
                customMinutes: 3,
                now: now
            ),
            "custom 3-minute interval is due after 4 minutes"
        )
    }

    private static func withTempSnapshot(_ body: () throws -> Void) {
        let previous = OwnershipSnapshot.fileURL
        OwnershipSnapshot.fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pokebinder-snapshot-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: OwnershipSnapshot.fileURL)
            OwnershipSnapshot.fileURL = previous
        }
        do {
            try body()
        } catch {
            Check.expect(false, "snapshot check threw \(error)")
        }
    }

    private static func runSnapshotChecks() {
        withTempSnapshot {
            let legacy = """
            {"ownership":{"25":true,"1":false},"pageIds":{"25":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}
            """.data(using: .utf8)!
            try legacy.write(to: OwnershipSnapshot.fileURL)

            guard let contents = Check.notNil(OwnershipSnapshot.load(), "legacy snapshot should load") else {
                return
            }
            Check.equal(contents.ownership[25], Optional(true))
            Check.equal(contents.ownership[1], Optional(false))
            Check.equal(contents.pageIds[25], Optional("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
            Check.expect(contents.pendingEdits.isEmpty, "legacy snapshot has no pending edits")
            Check.isNil(contents.lastSyncedAt)
        }

        withTempSnapshot {
            OwnershipSnapshot.save(
                ownership: [25: false],
                pageIds: [25: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"]
            )
            OwnershipSnapshot.enqueue(dex: 25, owned: true)
            OwnershipSnapshot.enqueue(dex: 4, owned: true)

            let reloaded = OwnershipSnapshot.load()
            Check.equal(reloaded?.ownership[25], Optional(true))
            Check.equal(reloaded?.ownership[4], Optional(true))
            Check.equal(reloaded?.pendingEdits[25], Optional(true))
            Check.equal(reloaded?.pendingEdits[4], Optional(true))
            Check.equal(reloaded?.pageIds[25], Optional("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
        }

        withTempSnapshot {
            let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
            OwnershipSnapshot.save(
                ownership: [7: true],
                pageIds: [7: "cccccccccccccccccccccccccccccccc"],
                pendingEdits: [7: true, 9: false],
                lastSyncedAt: syncedAt
            )
            guard let contents = Check.notNil(OwnershipSnapshot.load(), "saved snapshot should reload") else {
                return
            }
            Check.equal(contents.pendingEdits[7], Optional(true))
            Check.equal(contents.pendingEdits[9], Optional(false))
            Check.equal(contents.lastSyncedAt?.timeIntervalSince1970, Optional(syncedAt.timeIntervalSince1970))
        }
    }

    private static func runReconcilerChecks() {
        let remote = [1: false, 4: true, 25: false]
        let pending = [25: true, 7: true]
        let merged = OwnershipReconciler.merge(remote: remote, pending: pending)
        Check.equal(merged[1], Optional(false))
        Check.equal(merged[4], Optional(true))
        Check.equal(merged[25], Optional(true))
        Check.equal(merged[7], Optional(true))

        let remaining = OwnershipReconciler.remainingPending(
            from: [1: true, 4: false, 25: true],
            failedDexes: [4]
        )
        Check.equal(remaining, [4: false])
    }

    @MainActor
    private static func runCoordinatorChecks() async {
        let partial = MockRemoteClient()
        partial.remoteOwnership = [1: false, 4: false, 25: false]
        partial.remotePageIds = [1: "p1", 4: "p4", 25: "p25"]
        partial.writeFailures = [4]

        let coordinator = OwnershipSyncCoordinator()
        let partialOutcome = await coordinator.sync(
            client: partial,
            state: OwnershipSyncState(pendingEdits: [1: true, 4: true, 25: true])
        )
        if case .completed(let state, let failures) = partialOutcome {
            Check.equal(state.ownership[1], Optional(true))
            Check.equal(state.ownership[4], Optional(true))
            Check.equal(state.ownership[25], Optional(true))
            Check.equal(state.pendingEdits, [4: true])
            Check.equal(failures[4], Optional("write failed"))
            Check.equal(partial.writes.map(\.0), [1, 4, 25])
            Check.expect(state.lastSyncedAt != nil, "completed sync records lastSyncedAt")
        } else {
            Check.expect(false, "expected completed sync, got \(partialOutcome)")
        }

        let failingFetch = MockRemoteClient()
        failingFetch.fetchError = MockRemoteClient.FixtureError.fetchFailed
        let failedOutcome = await coordinator.sync(
            client: failingFetch,
            state: OwnershipSyncState(pendingEdits: [25: true])
        )
        if case .failed(let message) = failedOutcome {
            Check.equal(message, "fetch failed")
            Check.expect(failingFetch.writes.isEmpty, "failed fetch must not write")
        } else {
            Check.expect(false, "expected failed sync, got \(failedOutcome)")
        }

        let overlapClient = MockRemoteClient()
        overlapClient.remoteOwnership = [25: false]
        overlapClient.remotePageIds = [25: "p25"]
        overlapClient.fetchDelayNanoseconds = 80_000_000
        let overlapCoordinator = OwnershipSyncCoordinator()
        let overlapState = OwnershipSyncState(pendingEdits: [25: true])
        async let first = overlapCoordinator.sync(client: overlapClient, state: overlapState)
        async let second = overlapCoordinator.sync(client: overlapClient, state: overlapState)
        let results = await (first, second)
        let outcomes = [results.0, results.1]
        let skipped = outcomes.filter { if case .skippedAlreadyRunning = $0 { return true }; return false }.count
        let completed = outcomes.filter { if case .completed = $0 { return true }; return false }.count
        Check.equal(skipped, 1, "one overlapping sync should be skipped")
        Check.equal(completed, 1, "one overlapping sync should complete")
        Check.equal(overlapClient.fetchCount, 1, "overlapping syncs share one fetch")
        Check.equal(overlapClient.writes.count, 1)
    }
}
