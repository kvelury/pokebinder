import Foundation
import PokeBinderMatchup

func decodingTests() -> [TestCase] {
    [
        TestCase(name: "decodesCurrentAndGenerationIFireRelations") {
            let record = try JSONDecoder().decode(TypeAPIRecord.self, from: Data(fireFixture.utf8))
            let current = record.relations(in: .current)
            try expectEqual(current.doubleFrom, [.ground, .rock, .water])
            try expect(current.halfFrom.contains(.steel))
            try expect(current.halfFrom.contains(.fairy))
            try expect(current.halfFrom.contains(.ice))
            try expect(current.doubleTo.contains(.steel))

            let generationI = record.relations(in: .generationI)
            try expectEqual(generationI.doubleFrom, [.ground, .rock, .water])
            try expectEqual(generationI.halfFrom, [.bug, .fire, .grass])
            try expectEqual(generationI.doubleTo, [.bug, .grass, .ice])
            try expect(!generationI.halfFrom.contains(.steel))
            try expect(!generationI.doubleTo.contains(.steel))
        },
        TestCase(name: "selectsGenerationISnapshotWhenLaterPastEntriesExist") {
            let record = try JSONDecoder().decode(TypeAPIRecord.self, from: Data(ghostFixture.utf8))
            let generationI = record.relations(in: .generationI)
            try expect(generationI.noneTo.contains(.psychic))
            try expect(!generationI.doubleTo.contains(.psychic))

            let current = record.relations(in: .current)
            try expect(current.doubleTo.contains(.psychic))
            try expect(!current.noneTo.contains(.psychic))
        },
        TestCase(name: "missingPastRelationsDefaultsToEmpty") {
            let json = """
            {
              "name": "normal",
              "damage_relations": {
                "double_damage_from": [{"name":"fighting"}],
                "double_damage_to": [],
                "half_damage_from": [],
                "half_damage_to": [{"name":"rock"},{"name":"steel"}],
                "no_damage_from": [{"name":"ghost"}],
                "no_damage_to": [{"name":"ghost"}]
              }
            }
            """
            let record = try JSONDecoder().decode(TypeAPIRecord.self, from: Data(json.utf8))
            try expect(record.pastDamageRelations.isEmpty)
            try expectEqual(record.relations(in: .generationI).noneFrom, [.ghost])
        },
    ]
}

func storeTests() -> [TestCase] {
    [
        TestCase(name: "persistsToDiskAndSkipsASecondNetworkFetch") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let client = CountingClient(data: Data(fireFixture.utf8))
            let first = TypeMatchupStore(client: client, directory: directory)
            _ = try await first.record(for: .fire)
            try expectEqual(client.calls, 1)

            let second = TypeMatchupStore(client: client, directory: directory)
            let record = try await second.record(for: .fire)
            try expectEqual(record.name, "fire")
            try expectEqual(client.calls, 1)
        },
        TestCase(name: "deduplicatesConcurrentFetches") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let client = CountingClient(data: Data(fireFixture.utf8), delayNanoseconds: 40_000_000)
            let store = TypeMatchupStore(client: client, directory: directory)

            async let first = store.record(for: .fire)
            async let second = store.record(for: .fire)
            _ = try await (first, second)
            try expectEqual(client.calls, 1)
        },
        TestCase(name: "invalidCacheIsDeletedAndRefetched") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let stale = directory.appendingPathComponent("fire.json")
            try Data("not-json".utf8).write(to: stale)

            let client = CountingClient(data: Data(fireFixture.utf8))
            let store = TypeMatchupStore(client: client, directory: directory)
            let record = try await store.record(for: .fire)
            try expectEqual(record.name, "fire")
            try expectEqual(client.calls, 1)
            let cached = try String(contentsOf: stale, encoding: .utf8)
            try expect(cached.contains("\"name\":\"fire\""))
        },
        TestCase(name: "catalogVersionIsPositive") {
            try expect(TypeMatchupStore.catalogVersion >= 1)
        },
        TestCase(name: "summaryUsesCachedTypeRecords") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let client = CountingClient(data: Data(fireFixture.utf8))
            let store = TypeMatchupStore(client: client, directory: directory)
            let summary = try await store.summary(types: [.fire], era: .current)
            try expectEqual(summary.weakTo.map(\.type), [.ground, .rock, .water])
            try expect(summary.strongAgainst.contains { $0.type == .steel && $0.multiplier == 2 })
            try expectEqual(client.calls, 1)
        },
    ]
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PokeBinderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private final class CountingClient: TypeAPIClient, @unchecked Sendable {
    let data: Data
    let delayNanoseconds: UInt64
    private let counter = Counter()

    var calls: Int { counter.value }

    init(data: Data, delayNanoseconds: UInt64 = 0) {
        self.data = data
        self.delayNanoseconds = delayNanoseconds
    }

    func data(for type: PokemonType) async throws -> Data {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        counter.increment()
        return data
    }
}

private final class Counter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PokeBinderTests.CountingClient")
    private var count = 0

    var value: Int { queue.sync { count } }

    func increment() {
        queue.sync { count += 1 }
    }
}

private let fireFixture = """
{
  "name": "fire",
  "damage_relations": {
    "double_damage_from": [{"name":"ground"},{"name":"rock"},{"name":"water"}],
    "double_damage_to": [{"name":"bug"},{"name":"steel"},{"name":"grass"},{"name":"ice"}],
    "half_damage_from": [{"name":"bug"},{"name":"steel"},{"name":"fire"},{"name":"grass"},{"name":"ice"},{"name":"fairy"}],
    "half_damage_to": [{"name":"rock"},{"name":"fire"},{"name":"water"},{"name":"dragon"}],
    "no_damage_from": [],
    "no_damage_to": []
  },
  "past_damage_relations": [
    {
      "damage_relations": {
        "double_damage_from": [{"name":"ground"},{"name":"rock"},{"name":"water"}],
        "double_damage_to": [{"name":"bug"},{"name":"grass"},{"name":"ice"}],
        "half_damage_from": [{"name":"bug"},{"name":"fire"},{"name":"grass"}],
        "half_damage_to": [{"name":"rock"},{"name":"fire"},{"name":"water"},{"name":"dragon"}],
        "no_damage_from": [],
        "no_damage_to": []
      },
      "generation": {"name":"generation-i"}
    }
  ]
}
"""

private let ghostFixture = """
{
  "name": "ghost",
  "damage_relations": {
    "double_damage_from": [{"name":"ghost"},{"name":"dark"}],
    "double_damage_to": [{"name":"ghost"},{"name":"psychic"}],
    "half_damage_from": [{"name":"poison"},{"name":"bug"}],
    "half_damage_to": [{"name":"dark"}],
    "no_damage_from": [{"name":"normal"},{"name":"fighting"}],
    "no_damage_to": [{"name":"normal"}]
  },
  "past_damage_relations": [
    {
      "damage_relations": {
        "double_damage_from": [{"name":"ghost"}],
        "double_damage_to": [{"name":"ghost"}],
        "half_damage_from": [{"name":"poison"},{"name":"bug"}],
        "half_damage_to": [],
        "no_damage_from": [{"name":"normal"},{"name":"fighting"}],
        "no_damage_to": [{"name":"normal"},{"name":"psychic"}]
      },
      "generation": {"name":"generation-i"}
    },
    {
      "damage_relations": {
        "double_damage_from": [{"name":"ghost"},{"name":"dark"}],
        "double_damage_to": [{"name":"ghost"},{"name":"psychic"}],
        "half_damage_from": [{"name":"poison"},{"name":"bug"}],
        "half_damage_to": [{"name":"dark"},{"name":"steel"}],
        "no_damage_from": [{"name":"normal"},{"name":"fighting"}],
        "no_damage_to": [{"name":"normal"}]
      },
      "generation": {"name":"generation-v"}
    }
  ]
}
"""
