import SwiftUI

/// The type rules shown in the binder. Generation I predates Steel and Fairy,
/// so a handful of the original 151 have different historical assignments.
package enum TypeEra: String, CaseIterable, Identifiable {
    case current
    case generationI

    package var id: Self { self }

    package var title: String {
        switch self {
        case .current: "Current"
        case .generationI: "Gen I"
        }
    }

    /// PokéAPI generation key used to pick `past_damage_relations`. `nil` means
    /// the live `damage_relations` chart.
    package var pokeAPIGeneration: String? {
        switch self {
        case .current: nil
        case .generationI: "generation-i"
        }
    }

    /// Numeric generation for walking historical charts. Current is unbounded
    /// so any leftover past snapshot is ignored in favour of live relations.
    package var generationIndex: Int {
        switch self {
        case .generationI: 1
        case .current: Int.max
        }
    }

    package var availableTypes: [PokemonType] {
        PokemonType.allCases.filter { $0.introducedInGeneration <= generationIndex }
    }
}

/// How much of the matchup table the hover card shows.
package enum MatchupDetailLevel: String, CaseIterable, Identifiable {
    case simple
    case advanced
    case full

    package var id: Self { self }

    package var title: String {
        switch self {
        case .simple: "Simple"
        case .advanced: "Advanced"
        case .full: "Full"
        }
    }
}

package enum PokemonType: String, CaseIterable, Identifiable {
    case bug
    case dark
    case dragon
    case electric
    case fairy
    case fighting
    case fire
    case flying
    case ghost
    case grass
    case ground
    case ice
    case normal
    case poison
    case psychic
    case rock
    case steel
    case water

    package var id: Self { self }
    package var title: String { rawValue.capitalized }

    /// Dark and Steel arrive in Gen II; Fairy in Gen VI. Used to hide types that
    /// did not exist in the selected era rather than showing them as neutral.
    var introducedInGeneration: Int {
        switch self {
        case .dark, .steel: 2
        case .fairy: 6
        default: 1
        }
    }

    /// Colors from duiker101/pokemon-type-svg-icons.
    package var color: Color {
        let hex: UInt32 = switch self {
        case .bug: 0x92BC2C
        case .dark: 0x595761
        case .dragon: 0x0C69C8
        case .electric: 0xF2D94E
        case .fairy: 0xEE90E6
        case .fighting: 0xD3425F
        case .fire: 0xFBA54C
        case .flying: 0xA1BBEC
        case .ghost: 0x5F6DBC
        case .grass: 0x5FBD58
        case .ground: 0xDA7C4D
        case .ice: 0x75D0C1
        case .normal: 0xA0A29F
        case .poison: 0xB763CF
        case .psychic: 0xFA8581
        case .rock: 0xC9BB8A
        case .steel: 0x5695A3
        case .water: 0x539DDF
        }
        return Color(nsColor: NSColor(hex: hex))
    }
}
