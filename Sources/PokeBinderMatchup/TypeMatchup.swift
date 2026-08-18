import Foundation

/// One attacking or defending type after dual-type factors have been combined.
package struct TypeMatchupEntry: Equatable, Identifiable {
    package let type: PokemonType
    package let multiplier: Double

    package var id: PokemonType { type }

    package var label: String { TypeMatchupFormatting.label(multiplier) }

    package init(type: PokemonType, multiplier: Double) {
        self.type = type
        self.multiplier = multiplier
    }

    package var accessibilityLabel: String {
        "\(type.title), \(TypeMatchupFormatting.spoken(multiplier))"
    }
}

package enum TypeMatchupRowKind: String, CaseIterable, Identifiable {
    case strongAgainst
    case weakTo
    case resists
    case immune
    case ineffectiveAgainst
    case noEffectAgainst

    package var id: Self { self }

    package var title: String {
        switch self {
        case .strongAgainst: "Strong against"
        case .weakTo: "Weak to"
        case .resists: "Resists"
        case .immune: "Immune"
        case .ineffectiveAgainst: "Ineffective against"
        case .noEffectAgainst: "No effect against"
        }
    }

    package func isVisible(at level: MatchupDetailLevel) -> Bool {
        switch level {
        case .simple:
            return self == .strongAgainst || self == .weakTo
        case .advanced:
            return self != .ineffectiveAgainst && self != .noEffectAgainst
        case .full:
            return true
        }
    }
}

package struct TypeMatchupRow: Equatable, Identifiable {
    package let kind: TypeMatchupRowKind
    package let entries: [TypeMatchupEntry]

    package var id: TypeMatchupRowKind { kind }
}

/// Defensive rows multiply both of a Pokémon's types. Offensive rows take the
/// best single-type attack — a move only has one type, so Fire/Flying is not 4×
/// against Bug.
package struct TypeMatchupSummary: Equatable {
    package var strongAgainst: [TypeMatchupEntry]
    package var weakTo: [TypeMatchupEntry]
    package var resists: [TypeMatchupEntry]
    package var immune: [TypeMatchupEntry]
    package var ineffectiveAgainst: [TypeMatchupEntry]
    package var noEffectAgainst: [TypeMatchupEntry]

    package init(
        strongAgainst: [TypeMatchupEntry],
        weakTo: [TypeMatchupEntry],
        resists: [TypeMatchupEntry],
        immune: [TypeMatchupEntry],
        ineffectiveAgainst: [TypeMatchupEntry],
        noEffectAgainst: [TypeMatchupEntry]
    ) {
        self.strongAgainst = strongAgainst
        self.weakTo = weakTo
        self.resists = resists
        self.immune = immune
        self.ineffectiveAgainst = ineffectiveAgainst
        self.noEffectAgainst = noEffectAgainst
    }

    package func entries(for kind: TypeMatchupRowKind) -> [TypeMatchupEntry] {
        switch kind {
        case .strongAgainst: strongAgainst
        case .weakTo: weakTo
        case .resists: resists
        case .immune: immune
        case .ineffectiveAgainst: ineffectiveAgainst
        case .noEffectAgainst: noEffectAgainst
        }
    }

    package func rows(for level: MatchupDetailLevel) -> [TypeMatchupRow] {
        TypeMatchupRowKind.allCases.compactMap { kind in
            guard kind.isVisible(at: level) else { return nil }
            let entries = entries(for: kind)
            guard !entries.isEmpty else { return nil }
            return TypeMatchupRow(kind: kind, entries: entries)
        }
    }
}

/// Incoming/outgoing multipliers for one elemental type in one era.
package struct TypeDamageRelations: Equatable {
    package var doubleFrom: Set<PokemonType> = []
    package var halfFrom: Set<PokemonType> = []
    package var noneFrom: Set<PokemonType> = []
    package var doubleTo: Set<PokemonType> = []
    package var halfTo: Set<PokemonType> = []
    package var noneTo: Set<PokemonType> = []

    package init(
        doubleFrom: Set<PokemonType> = [],
        halfFrom: Set<PokemonType> = [],
        noneFrom: Set<PokemonType> = [],
        doubleTo: Set<PokemonType> = [],
        halfTo: Set<PokemonType> = [],
        noneTo: Set<PokemonType> = []
    ) {
        self.doubleFrom = doubleFrom
        self.halfFrom = halfFrom
        self.noneFrom = noneFrom
        self.doubleTo = doubleTo
        self.halfTo = halfTo
        self.noneTo = noneTo
    }

    func incomingMultiplier(from attacker: PokemonType) -> Double {
        if noneFrom.contains(attacker) { return 0 }
        if doubleFrom.contains(attacker) { return 2 }
        if halfFrom.contains(attacker) { return 0.5 }
        return 1
    }

    func outgoingMultiplier(to defender: PokemonType) -> Double {
        if noneTo.contains(defender) { return 0 }
        if doubleTo.contains(defender) { return 2 }
        if halfTo.contains(defender) { return 0.5 }
        return 1
    }
}

package enum TypeMatchupCalculator {
    package static func defensiveMultiplier(
        attacking: PokemonType,
        defending: [PokemonType],
        relationsByType: [PokemonType: TypeDamageRelations]
    ) -> Double {
        defending.reduce(1) { product, type in
            product * (relationsByType[type]?.incomingMultiplier(from: attacking) ?? 1)
        }
    }

    package static func offensiveMultiplier(
        attacking: [PokemonType],
        defending: PokemonType,
        relationsByType: [PokemonType: TypeDamageRelations]
    ) -> Double {
        attacking
            .map { relationsByType[$0]?.outgoingMultiplier(to: defending) ?? 1 }
            .max() ?? 1
    }

    package static func summary(
        pokemonTypes: [PokemonType],
        relationsByType: [PokemonType: TypeDamageRelations],
        era: TypeEra
    ) -> TypeMatchupSummary {
        var strongAgainst: [TypeMatchupEntry] = []
        var weakTo: [TypeMatchupEntry] = []
        var resists: [TypeMatchupEntry] = []
        var immune: [TypeMatchupEntry] = []
        var ineffectiveAgainst: [TypeMatchupEntry] = []
        var noEffectAgainst: [TypeMatchupEntry] = []

        for type in era.availableTypes {
            let defense = defensiveMultiplier(
                attacking: type,
                defending: pokemonTypes,
                relationsByType: relationsByType
            )
            switch defense {
            case ..<0:
                break
            case 0:
                immune.append(TypeMatchupEntry(type: type, multiplier: defense))
            case ..<1:
                resists.append(TypeMatchupEntry(type: type, multiplier: defense))
            case 1:
                break
            default:
                weakTo.append(TypeMatchupEntry(type: type, multiplier: defense))
            }

            let offense = offensiveMultiplier(
                attacking: pokemonTypes,
                defending: type,
                relationsByType: relationsByType
            )
            switch offense {
            case ..<0:
                break
            case 0:
                noEffectAgainst.append(TypeMatchupEntry(type: type, multiplier: offense))
            case ..<1:
                ineffectiveAgainst.append(TypeMatchupEntry(type: type, multiplier: offense))
            case 1:
                break
            default:
                strongAgainst.append(TypeMatchupEntry(type: type, multiplier: offense))
            }
        }

        return TypeMatchupSummary(
            strongAgainst: Self.sorted(strongAgainst, higherFirst: true),
            weakTo: Self.sorted(weakTo, higherFirst: true),
            resists: Self.sorted(resists, higherFirst: false),
            immune: Self.sorted(immune, higherFirst: true),
            ineffectiveAgainst: Self.sorted(ineffectiveAgainst, higherFirst: false),
            noEffectAgainst: Self.sorted(noEffectAgainst, higherFirst: true)
        )
    }

    private static func sorted(
        _ entries: [TypeMatchupEntry],
        higherFirst: Bool
    ) -> [TypeMatchupEntry] {
        entries.sorted { lhs, rhs in
            if lhs.multiplier != rhs.multiplier {
                return higherFirst
                    ? lhs.multiplier > rhs.multiplier
                    : lhs.multiplier < rhs.multiplier
            }
            return lhs.type.title < rhs.type.title
        }
    }
}

enum TypeMatchupFormatting {
    static func label(_ value: Double) -> String {
        if value == 0 { return "0×" }
        if abs(value - 4) < 0.01 { return "4×" }
        if abs(value - 2) < 0.01 { return "2×" }
        if abs(value - 0.5) < 0.01 { return "½×" }
        if abs(value - 0.25) < 0.01 { return "¼×" }
        return String(format: "%.2g×", value)
    }

    static func spoken(_ value: Double) -> String {
        if value == 0 { return "no effect" }
        if abs(value - 4) < 0.01 { return "4 times" }
        if abs(value - 2) < 0.01 { return "2 times" }
        if abs(value - 0.5) < 0.01 { return "half" }
        if abs(value - 0.25) < 0.01 { return "quarter" }
        return String(format: "%.2g times", value)
    }
}

/// Walks PokéAPI's `past_damage_relations` snapshots. Each snapshot is the chart
/// that was still in force at the end of that generation; the first snapshot
/// whose generation is at least the requested era is the one that era used.
enum TypeMatchupEraRelations {
    static func relations(
        current: TypeDamageRelations,
        past: [(generation: String, relations: TypeDamageRelations)],
        era: TypeEra
    ) -> TypeDamageRelations {
        guard era != .current else { return current }
        let snapshots = past.compactMap { entry -> (Int, TypeDamageRelations)? in
            guard let index = PokeAPIGeneration.index(named: entry.generation) else { return nil }
            return (index, entry.relations)
        }
        .sorted { $0.0 < $1.0 }

        if let match = snapshots.first(where: { $0.0 >= era.generationIndex }) {
            return match.1
        }
        return current
    }
}

enum PokeAPIGeneration {
    private static let roman: [String: Int] = [
        "i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5,
        "vi": 6, "vii": 7, "viii": 8, "ix": 9,
    ]

    static func index(named raw: String) -> Int? {
        let name = raw.lowercased()
        let prefix = "generation-"
        guard name.hasPrefix(prefix) else { return nil }
        return roman[String(name.dropFirst(prefix.count))]
    }
}
