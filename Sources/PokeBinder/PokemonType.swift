import SwiftUI

/// The type rules shown in the binder. Generation I predates Steel and Fairy,
/// so a handful of the original 151 have different historical assignments.
enum TypeEra: String, CaseIterable, Identifiable {
    case current
    case generationI

    var id: Self { self }

    var title: String {
        switch self {
        case .current: "Current"
        case .generationI: "Gen I"
        }
    }
}

enum PokemonType: String, CaseIterable, Identifiable {
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

    var id: Self { self }
    var title: String { rawValue.capitalized }

    /// Colors from duiker101/pokemon-type-svg-icons.
    var color: Color {
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
