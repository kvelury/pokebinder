import Foundation

package enum TypeMatchupError: Error, LocalizedError, Equatable {
    case unavailable
    case decoding

    package var errorDescription: String? {
        switch self {
        case .unavailable: "Couldn't load type matchups."
        case .decoding: "Couldn't read type matchups."
        }
    }
}

package protocol TypeAPIClient: Sendable {
    func data(for type: PokemonType) async throws -> Data
}

struct PokeAPITypeClient: TypeAPIClient {
    func data(for type: PokemonType) async throws -> Data {
        let url = URL(string: "https://pokeapi.co/api/v2/type/\(type.rawValue)")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else {
                throw TypeMatchupError.unavailable
            }
            return data
        } catch let error as TypeMatchupError {
            throw error
        } catch {
            throw TypeMatchupError.unavailable
        }
    }
}

/// The subset of `/api/v2/type/{name}` we persist. Extra API fields are ignored
/// so a future decoder change can still read an older cached payload.
package struct TypeAPIRecord: Codable, Equatable {
    package let name: String
    let damageRelations: TypeAPIDamageRelations
    package let pastDamageRelations: [TypeAPIPastDamageRelations]

    enum CodingKeys: String, CodingKey {
        case name
        case damageRelations = "damage_relations"
        case pastDamageRelations = "past_damage_relations"
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        damageRelations = try container.decode(TypeAPIDamageRelations.self, forKey: .damageRelations)
        pastDamageRelations = try container.decodeIfPresent(
            [TypeAPIPastDamageRelations].self,
            forKey: .pastDamageRelations
        ) ?? []
    }

    package func relations(in era: TypeEra) -> TypeDamageRelations {
        TypeMatchupEraRelations.relations(
            current: damageRelations.model,
            past: pastDamageRelations.map { ($0.generation.name, $0.damageRelations.model) },
            era: era
        )
    }
}

package struct TypeAPIPastDamageRelations: Codable, Equatable {
    let damageRelations: TypeAPIDamageRelations
    let generation: TypeAPIName

    enum CodingKeys: String, CodingKey {
        case damageRelations = "damage_relations"
        case generation
    }
}

struct TypeAPIDamageRelations: Codable, Equatable {
    let doubleDamageFrom: [TypeAPIName]
    let doubleDamageTo: [TypeAPIName]
    let halfDamageFrom: [TypeAPIName]
    let halfDamageTo: [TypeAPIName]
    let noDamageFrom: [TypeAPIName]
    let noDamageTo: [TypeAPIName]

    enum CodingKeys: String, CodingKey {
        case doubleDamageFrom = "double_damage_from"
        case doubleDamageTo = "double_damage_to"
        case halfDamageFrom = "half_damage_from"
        case halfDamageTo = "half_damage_to"
        case noDamageFrom = "no_damage_from"
        case noDamageTo = "no_damage_to"
    }

    var model: TypeDamageRelations {
        TypeDamageRelations(
            doubleFrom: Self.types(doubleDamageFrom),
            halfFrom: Self.types(halfDamageFrom),
            noneFrom: Self.types(noDamageFrom),
            doubleTo: Self.types(doubleDamageTo),
            halfTo: Self.types(halfDamageTo),
            noneTo: Self.types(noDamageTo)
        )
    }

    private static func types(_ names: [TypeAPIName]) -> Set<PokemonType> {
        Set(names.compactMap { PokemonType(rawValue: $0.name) })
    }
}

struct TypeAPIName: Codable, Equatable {
    let name: String
}

/// Persistent type-chart catalog. Pokémon openings never hit the network once
/// a type is on disk; a versioned folder lets a later app release drop stale
/// snapshots when a new generation or type is added.
package actor TypeMatchupStore {
    package static let catalogVersion = 1
    package static let shared = TypeMatchupStore()

    private let client: TypeAPIClient
    private let directory: URL
    private var memory: [PokemonType: TypeAPIRecord] = [:]
    private var inFlight: [PokemonType: Task<TypeAPIRecord, Error>] = [:]

    package init(client: TypeAPIClient = PokeAPITypeClient(), directory: URL? = nil) {
        self.client = client
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent(
                "PokeBinder/type-matchups/v\(Self.catalogVersion)",
                isDirectory: true
            )
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    package func warmup() async {
        await withTaskGroup(of: Void.self) { group in
            for type in PokemonType.allCases {
                group.addTask {
                    _ = try? await self.record(for: type)
                }
            }
        }
    }

    package func record(for type: PokemonType) async throws -> TypeAPIRecord {
        if let cached = memory[type] { return cached }
        if let existing = inFlight[type] {
            return try await existing.value
        }

        let task = Task<TypeAPIRecord, Error> { [directory, client] in
            let file = directory.appendingPathComponent("\(type.rawValue).json")
            if let cached = try? Data(contentsOf: file), !cached.isEmpty,
               let record = try? JSONDecoder().decode(TypeAPIRecord.self, from: cached) {
                return record
            }
            if FileManager.default.fileExists(atPath: file.path) {
                try? FileManager.default.removeItem(at: file)
            }
            let data = try await client.data(for: type)
            let record: TypeAPIRecord
            do {
                record = try JSONDecoder().decode(TypeAPIRecord.self, from: data)
            } catch {
                throw TypeMatchupError.decoding
            }
            try? data.write(to: file, options: .atomic)
            return record
        }

        inFlight[type] = task
        do {
            let result = try await task.value
            memory[type] = result
            inFlight[type] = nil
            return result
        } catch {
            inFlight[type] = nil
            throw error
        }
    }

    package func summary(types: [PokemonType], era: TypeEra) async throws -> TypeMatchupSummary {
        var relationsByType: [PokemonType: TypeDamageRelations] = [:]
        try await withThrowingTaskGroup(of: (PokemonType, TypeAPIRecord).self) { group in
            for type in Set(types) {
                group.addTask {
                    (type, try await self.record(for: type))
                }
            }
            for try await (type, record) in group {
                relationsByType[type] = record.relations(in: era)
            }
        }
        return TypeMatchupCalculator.summary(
            pokemonTypes: types,
            relationsByType: relationsByType,
            era: era
        )
    }
}
