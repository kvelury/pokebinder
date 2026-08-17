import Foundation

/// Static type metadata keeps the binder complete and responsive without a network
/// request. Current assignments are from PokeAPI; the overrides are the seven
/// Pokémon whose typing was changed after the original games.
enum PokemonTypeCatalog {
    static func types(for dex: Int, era: TypeEra) -> [PokemonType] {
        guard current.indices.contains(dex - 1) else { return [] }
        if era == .generationI, let historical = generationIOverrides[dex] {
            return historical
        }
        return current[dex - 1]
    }

    private static let generationIOverrides: [Int: [PokemonType]] = [
        35: [.normal],
        36: [.normal],
        39: [.normal],
        40: [.normal],
        81: [.electric],
        82: [.electric],
        122: [.psychic],
    ]

    static let current: [[PokemonType]] = [
        [.grass, .poison], // 001 Bulbasaur
        [.grass, .poison], // 002 Ivysaur
        [.grass, .poison], // 003 Venusaur
        [.fire], // 004 Charmander
        [.fire], // 005 Charmeleon
        [.fire, .flying], // 006 Charizard
        [.water], // 007 Squirtle
        [.water], // 008 Wartortle
        [.water], // 009 Blastoise
        [.bug], // 010 Caterpie
        [.bug], // 011 Metapod
        [.bug, .flying], // 012 Butterfree
        [.bug, .poison], // 013 Weedle
        [.bug, .poison], // 014 Kakuna
        [.bug, .poison], // 015 Beedrill
        [.normal, .flying], // 016 Pidgey
        [.normal, .flying], // 017 Pidgeotto
        [.normal, .flying], // 018 Pidgeot
        [.normal], // 019 Rattata
        [.normal], // 020 Raticate
        [.normal, .flying], // 021 Spearow
        [.normal, .flying], // 022 Fearow
        [.poison], // 023 Ekans
        [.poison], // 024 Arbok
        [.electric], // 025 Pikachu
        [.electric], // 026 Raichu
        [.ground], // 027 Sandshrew
        [.ground], // 028 Sandslash
        [.poison], // 029 Nidoran♀
        [.poison], // 030 Nidorina
        [.poison, .ground], // 031 Nidoqueen
        [.poison], // 032 Nidoran♂
        [.poison], // 033 Nidorino
        [.poison, .ground], // 034 Nidoking
        [.fairy], // 035 Clefairy
        [.fairy], // 036 Clefable
        [.fire], // 037 Vulpix
        [.fire], // 038 Ninetales
        [.normal, .fairy], // 039 Jigglypuff
        [.normal, .fairy], // 040 Wigglytuff
        [.poison, .flying], // 041 Zubat
        [.poison, .flying], // 042 Golbat
        [.grass, .poison], // 043 Oddish
        [.grass, .poison], // 044 Gloom
        [.grass, .poison], // 045 Vileplume
        [.bug, .grass], // 046 Paras
        [.bug, .grass], // 047 Parasect
        [.bug, .poison], // 048 Venonat
        [.bug, .poison], // 049 Venomoth
        [.ground], // 050 Diglett
        [.ground], // 051 Dugtrio
        [.normal], // 052 Meowth
        [.normal], // 053 Persian
        [.water], // 054 Psyduck
        [.water], // 055 Golduck
        [.fighting], // 056 Mankey
        [.fighting], // 057 Primeape
        [.fire], // 058 Growlithe
        [.fire], // 059 Arcanine
        [.water], // 060 Poliwag
        [.water], // 061 Poliwhirl
        [.water, .fighting], // 062 Poliwrath
        [.psychic], // 063 Abra
        [.psychic], // 064 Kadabra
        [.psychic], // 065 Alakazam
        [.fighting], // 066 Machop
        [.fighting], // 067 Machoke
        [.fighting], // 068 Machamp
        [.grass, .poison], // 069 Bellsprout
        [.grass, .poison], // 070 Weepinbell
        [.grass, .poison], // 071 Victreebel
        [.water, .poison], // 072 Tentacool
        [.water, .poison], // 073 Tentacruel
        [.rock, .ground], // 074 Geodude
        [.rock, .ground], // 075 Graveler
        [.rock, .ground], // 076 Golem
        [.fire], // 077 Ponyta
        [.fire], // 078 Rapidash
        [.water, .psychic], // 079 Slowpoke
        [.water, .psychic], // 080 Slowbro
        [.electric, .steel], // 081 Magnemite
        [.electric, .steel], // 082 Magneton
        [.normal, .flying], // 083 Farfetch'd
        [.normal, .flying], // 084 Doduo
        [.normal, .flying], // 085 Dodrio
        [.water], // 086 Seel
        [.water, .ice], // 087 Dewgong
        [.poison], // 088 Grimer
        [.poison], // 089 Muk
        [.water], // 090 Shellder
        [.water, .ice], // 091 Cloyster
        [.ghost, .poison], // 092 Gastly
        [.ghost, .poison], // 093 Haunter
        [.ghost, .poison], // 094 Gengar
        [.rock, .ground], // 095 Onix
        [.psychic], // 096 Drowzee
        [.psychic], // 097 Hypno
        [.water], // 098 Krabby
        [.water], // 099 Kingler
        [.electric], // 100 Voltorb
        [.electric], // 101 Electrode
        [.grass, .psychic], // 102 Exeggcute
        [.grass, .psychic], // 103 Exeggutor
        [.ground], // 104 Cubone
        [.ground], // 105 Marowak
        [.fighting], // 106 Hitmonlee
        [.fighting], // 107 Hitmonchan
        [.normal], // 108 Lickitung
        [.poison], // 109 Koffing
        [.poison], // 110 Weezing
        [.ground, .rock], // 111 Rhyhorn
        [.ground, .rock], // 112 Rhydon
        [.normal], // 113 Chansey
        [.grass], // 114 Tangela
        [.normal], // 115 Kangaskhan
        [.water], // 116 Horsea
        [.water], // 117 Seadra
        [.water], // 118 Goldeen
        [.water], // 119 Seaking
        [.water], // 120 Staryu
        [.water, .psychic], // 121 Starmie
        [.psychic, .fairy], // 122 Mr. Mime
        [.bug, .flying], // 123 Scyther
        [.ice, .psychic], // 124 Jynx
        [.electric], // 125 Electabuzz
        [.fire], // 126 Magmar
        [.bug], // 127 Pinsir
        [.normal], // 128 Tauros
        [.water], // 129 Magikarp
        [.water, .flying], // 130 Gyarados
        [.water, .ice], // 131 Lapras
        [.normal], // 132 Ditto
        [.normal], // 133 Eevee
        [.water], // 134 Vaporeon
        [.electric], // 135 Jolteon
        [.fire], // 136 Flareon
        [.normal], // 137 Porygon
        [.rock, .water], // 138 Omanyte
        [.rock, .water], // 139 Omastar
        [.rock, .water], // 140 Kabuto
        [.rock, .water], // 141 Kabutops
        [.rock, .flying], // 142 Aerodactyl
        [.normal], // 143 Snorlax
        [.ice, .flying], // 144 Articuno
        [.electric, .flying], // 145 Zapdos
        [.fire, .flying], // 146 Moltres
        [.dragon], // 147 Dratini
        [.dragon], // 148 Dragonair
        [.dragon, .flying], // 149 Dragonite
        [.psychic], // 150 Mewtwo
        [.psychic], // 151 Mew
    ]
}
