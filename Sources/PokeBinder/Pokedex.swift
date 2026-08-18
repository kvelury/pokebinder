import Foundation

/// The static half of the binder.
///
/// Names, numbers, page and slot are facts that never change and never need the
/// network, so they are bundled. This is what lets the app open to a full binder
/// before any Notion connection exists — Notion supplies *only* the `Owned` bit.
///
/// The derivation below was checked against the live Notion database during
/// planning: its stored `Page` and `Absolute Position` agree with these formulas
/// for all 151 rows (0 mismatches), so the app never has to trust Notion for layout.
enum Pokedex {
    static let slotsPerPage = 8
    static let slotsPerSide = 4
    static let count = 151

    /// 19 — ceil(151 / 8). Page 19 is deliberately short: see `dexNumber(page:side:slot:)`.
    static let pageCount = (count + slotsPerPage - 1) / slotsPerPage

    // MARK: - Derivation

    /// 1...19
    static func page(for dex: Int) -> Int { (dex - 1) / slotsPerPage + 1 }

    /// 1...8, the spec's "Absolute Position".
    static func absolutePosition(for dex: Int) -> Int { (dex - 1) % slotsPerPage + 1 }

    /// Positions 1–4 are the left page of the open spread, 5–8 the right.
    static func side(for dex: Int) -> BinderSide {
        absolutePosition(for: dex) <= slotsPerSide ? .left : .right
    }

    /// 1...4, laid out as a 2x2 grid on that side.
    static func slot(for dex: Int) -> Int {
        let position = absolutePosition(for: dex)
        return position <= slotsPerSide ? position : position - slotsPerSide
    }

    /// The inverse: which Pokémon lives in this pocket, if any.
    ///
    /// Returns nil for page 19 / right side / slot 4 — #152 does not exist, so the
    /// last pocket of the binder is permanently empty. Callers must render an empty
    /// sleeve rather than treating this as an error.
    static func dexNumber(page: Int, side: BinderSide, slot: Int) -> Int? {
        guard (1...pageCount).contains(page), (1...slotsPerSide).contains(slot) else { return nil }
        let position = side == .left ? slot : slot + slotsPerSide
        let dex = (page - 1) * slotsPerPage + position
        return dex <= count ? dex : nil
    }

    static func name(for dex: Int) -> String {
        guard (1...count).contains(dex) else { return "—" }
        return names[dex - 1]
    }

    /// Zero-padded to three digits, the way a binder label reads.
    static func formattedNumber(_ dex: Int) -> String {
        String(format: "%03d", dex)
    }

    static func types(for dex: Int, era: TypeEra) -> [PokemonType] {
        PokemonTypeCatalog.types(for: dex, era: era)
    }

    static func matchupSummary(for dex: Int, era: TypeEra) async throws -> TypeMatchupSummary {
        try await TypeMatchupStore.shared.summary(types: types(for: dex, era: era), era: era)
    }

    static func artworkURL(for dex: Int) -> URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(dex).png")!
    }

    // MARK: - Names
    //
    // Spellings verified against the live Notion database so the join on name never
    // drifts: Nidoran♀/♂ use the real gender signs, Farfetch'd a straight apostrophe,
    // Mr. Mime a period and a space. (The app joins on number, not name, but these
    // are what the user sees and what Notion holds.)
    static let names: [String] = [
        "Bulbasaur", "Ivysaur", "Venusaur", "Charmander", "Charmeleon",
        "Charizard", "Squirtle", "Wartortle", "Blastoise", "Caterpie",
        "Metapod", "Butterfree", "Weedle", "Kakuna", "Beedrill",
        "Pidgey", "Pidgeotto", "Pidgeot", "Rattata", "Raticate",
        "Spearow", "Fearow", "Ekans", "Arbok", "Pikachu",
        "Raichu", "Sandshrew", "Sandslash", "Nidoran♀", "Nidorina",
        "Nidoqueen", "Nidoran♂", "Nidorino", "Nidoking", "Clefairy",
        "Clefable", "Vulpix", "Ninetales", "Jigglypuff", "Wigglytuff",
        "Zubat", "Golbat", "Oddish", "Gloom", "Vileplume",
        "Paras", "Parasect", "Venonat", "Venomoth", "Diglett",
        "Dugtrio", "Meowth", "Persian", "Psyduck", "Golduck",
        "Mankey", "Primeape", "Growlithe", "Arcanine", "Poliwag",
        "Poliwhirl", "Poliwrath", "Abra", "Kadabra", "Alakazam",
        "Machop", "Machoke", "Machamp", "Bellsprout", "Weepinbell",
        "Victreebel", "Tentacool", "Tentacruel", "Geodude", "Graveler",
        "Golem", "Ponyta", "Rapidash", "Slowpoke", "Slowbro",
        "Magnemite", "Magneton", "Farfetch'd", "Doduo", "Dodrio",
        "Seel", "Dewgong", "Grimer", "Muk", "Shellder",
        "Cloyster", "Gastly", "Haunter", "Gengar", "Onix",
        "Drowzee", "Hypno", "Krabby", "Kingler", "Voltorb",
        "Electrode", "Exeggcute", "Exeggutor", "Cubone", "Marowak",
        "Hitmonlee", "Hitmonchan", "Lickitung", "Koffing", "Weezing",
        "Rhyhorn", "Rhydon", "Chansey", "Tangela", "Kangaskhan",
        "Horsea", "Seadra", "Goldeen", "Seaking", "Staryu",
        "Starmie", "Mr. Mime", "Scyther", "Jynx", "Electabuzz",
        "Magmar", "Pinsir", "Tauros", "Magikarp", "Gyarados",
        "Lapras", "Ditto", "Eevee", "Vaporeon", "Jolteon",
        "Flareon", "Porygon", "Omanyte", "Omastar", "Kabuto",
        "Kabutops", "Aerodactyl", "Snorlax", "Articuno", "Zapdos",
        "Moltres", "Dratini", "Dragonair", "Dragonite", "Mewtwo",
        "Mew",
    ]
}
