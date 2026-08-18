import Foundation
import PokeBinderSync

@MainActor
final class MockRemoteClient: OwnershipRemoteClient {
    enum FixtureError: LocalizedError {
        case fetchFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .fetchFailed: "fetch failed"
            case .writeFailed: "write failed"
            }
        }
    }

    var fetchCount = 0
    var fetchDelayNanoseconds: UInt64 = 0
    var remoteOwnership: [Int: Bool] = [:]
    var remotePageIds: [Int: String] = [:]
    var writeFailures: Set<Int> = []
    var writes: [(Int, Bool)] = []
    var fetchError: Error?

    func fetchAll() async throws -> (ownership: [Int: Bool], pageIds: [Int: String]) {
        fetchCount += 1
        if fetchDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }
        if let fetchError { throw fetchError }
        return (remoteOwnership, remotePageIds)
    }

    func setOwned(dex: Int, owned: Bool) async throws {
        writes.append((dex, owned))
        if writeFailures.contains(dex) {
            throw FixtureError.writeFailed
        }
    }
}
