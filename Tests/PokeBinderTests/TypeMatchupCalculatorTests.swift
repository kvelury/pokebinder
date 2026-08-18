
import PokeBinderMatchup

func calculatorTests() -> [TestCase] {
    [
        TestCase(name: "charizardCurrentHasFourTimesRockWeaknessAndGroundImmunity") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.fire, .flying],
                relationsByType: currentFireFlying,
                era: .current
            )
            try expectEqual(multiplier(summary.weakTo, .rock), 4)
            try expectEqual(multiplier(summary.weakTo, .water), 2)
            try expectEqual(multiplier(summary.weakTo, .electric), 2)
            try expectEqual(multiplier(summary.immune, .ground), 0)
            try expectEqual(multiplier(summary.resists, .bug), 0.25)
            try expectEqual(multiplier(summary.resists, .grass), 0.25)
            try expectEqual(multiplier(summary.weakTo, .ice), nil)
            try expectEqual(multiplier(summary.resists, .ice), nil)
        },
        TestCase(name: "charizardOffensiveUsesBestSingleTypeNotAProduct") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.fire, .flying],
                relationsByType: currentFireFlying,
                era: .current
            )
            try expectEqual(multiplier(summary.strongAgainst, .steel), 2)
            try expectEqual(multiplier(summary.strongAgainst, .grass), 2)
            try expectEqual(multiplier(summary.ineffectiveAgainst, .rock), 0.5)
            try expectEqual(multiplier(summary.ineffectiveAgainst, .water), nil)
        },
        TestCase(name: "generationIOmitsLaterTypesAndUsesHistoricalFireChart") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.fire, .flying],
                relationsByType: generationIFireFlying,
                era: .generationI
            )
            try expectEqual(multiplier(summary.strongAgainst, .steel), nil)
            try expectEqual(multiplier(summary.resists, .fairy), nil)
            try expectEqual(multiplier(summary.resists, .steel), nil)
            try expectEqual(multiplier(summary.weakTo, .ice), 2)
            try expectEqual(TypeEra.generationI.availableTypes.count, 15)
            try expect(!TypeEra.generationI.availableTypes.contains(.dark))
        },
        TestCase(name: "electricSteelHasFourTimesGroundWeakness") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.electric, .steel],
                relationsByType: currentElectricSteel,
                era: .current
            )
            try expectEqual(multiplier(summary.weakTo, .ground), 4)
            try expectEqual(multiplier(summary.weakTo, .fire), 2)
            try expectEqual(multiplier(summary.immune, .poison), 0)
        },
        TestCase(name: "electricAloneDoesNotStackSteelWeaknesses") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.electric],
                relationsByType: currentElectricSteel,
                era: .generationI
            )
            try expectEqual(multiplier(summary.weakTo, .ground), 2)
            try expectEqual(multiplier(summary.weakTo, .fire), nil)
            try expectEqual(multiplier(summary.immune, .poison), nil)
        },
        TestCase(name: "ghostPoisonCurrentIsStrongAgainstPsychic") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.ghost, .poison],
                relationsByType: currentGhostPoison,
                era: .current
            )
            try expectEqual(multiplier(summary.strongAgainst, .psychic), 2)
            try expectEqual(multiplier(summary.immune, .normal), 0)
            try expectEqual(multiplier(summary.immune, .fighting), 0)
        },
        TestCase(name: "ghostAloneGenerationICannotHitPsychic") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.ghost],
                relationsByType: generationIGhostPoison,
                era: .generationI
            )
            try expectEqual(multiplier(summary.noEffectAgainst, .psychic), 0)
            try expectEqual(multiplier(summary.strongAgainst, .psychic), nil)
        },
        TestCase(name: "ghostPoisonGenerationIHitsPsychicWithPoison") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.ghost, .poison],
                relationsByType: generationIGhostPoison,
                era: .generationI
            )
            try expectEqual(multiplier(summary.noEffectAgainst, .psychic), nil)
            try expectEqual(multiplier(summary.strongAgainst, .psychic), nil)
        },
        TestCase(name: "detailLevelHidesRows") {
            let summary = TypeMatchupSummary(
                strongAgainst: [TypeMatchupEntry(type: .grass, multiplier: 2)],
                weakTo: [TypeMatchupEntry(type: .water, multiplier: 2)],
                resists: [TypeMatchupEntry(type: .fire, multiplier: 0.5)],
                immune: [TypeMatchupEntry(type: .ground, multiplier: 0)],
                ineffectiveAgainst: [TypeMatchupEntry(type: .rock, multiplier: 0.5)],
                noEffectAgainst: [TypeMatchupEntry(type: .normal, multiplier: 0)]
            )
            try expectEqual(summary.rows(for: .simple).map(\.kind), [.strongAgainst, .weakTo])
            try expectEqual(
                summary.rows(for: .advanced).map(\.kind),
                [.strongAgainst, .weakTo, .resists, .immune]
            )
            try expectEqual(summary.rows(for: .full).map(\.kind), TypeMatchupRowKind.allCases)
        },
        TestCase(name: "emptyCategoriesAreOmitted") {
            let summary = TypeMatchupSummary(
                strongAgainst: [],
                weakTo: [TypeMatchupEntry(type: .fighting, multiplier: 2)],
                resists: [],
                immune: [],
                ineffectiveAgainst: [],
                noEffectAgainst: []
            )
            try expectEqual(summary.rows(for: .full).map(\.kind), [.weakTo])
        },
        TestCase(name: "hoverLevelsShowTheSelectedMatchupDetail") {
            let summary = TypeMatchupCalculator.summary(
                pokemonTypes: [.fire, .flying],
                relationsByType: currentFireFlying,
                era: .current
            )
            try expectEqual(
                summary.rows(for: .simple).map(\.kind),
                [.strongAgainst, .weakTo]
            )
            try expectEqual(
                summary.rows(for: .advanced).map(\.kind),
                [.strongAgainst, .weakTo, .resists, .immune]
            )
            try expectEqual(
                summary.rows(for: .full).map(\.kind),
                [.strongAgainst, .weakTo, .resists, .immune, .ineffectiveAgainst]
            )
        },
    ]
}

private func multiplier(_ entries: [TypeMatchupEntry], _ type: PokemonType) -> Double? {
    entries.first { $0.type == type }?.multiplier
}

private let currentFireFlying: [PokemonType: TypeDamageRelations] = [
    .fire: TypeDamageRelations(
        doubleFrom: [.ground, .rock, .water],
        halfFrom: [.bug, .steel, .fire, .grass, .ice, .fairy],
        doubleTo: [.bug, .steel, .grass, .ice],
        halfTo: [.rock, .fire, .water, .dragon]
    ),
    .flying: TypeDamageRelations(
        doubleFrom: [.rock, .electric, .ice],
        halfFrom: [.fighting, .bug, .grass],
        noneFrom: [.ground],
        doubleTo: [.fighting, .bug, .grass],
        halfTo: [.rock, .steel, .electric]
    ),
]

private let generationIFireFlying: [PokemonType: TypeDamageRelations] = [
    .fire: TypeDamageRelations(
        doubleFrom: [.ground, .rock, .water],
        halfFrom: [.bug, .fire, .grass],
        doubleTo: [.bug, .grass, .ice],
        halfTo: [.rock, .fire, .water, .dragon]
    ),
    .flying: TypeDamageRelations(
        doubleFrom: [.rock, .electric, .ice],
        halfFrom: [.fighting, .bug, .grass],
        noneFrom: [.ground],
        doubleTo: [.fighting, .bug, .grass],
        halfTo: [.rock, .electric]
    ),
]

private let currentElectricSteel: [PokemonType: TypeDamageRelations] = [
    .electric: TypeDamageRelations(
        doubleFrom: [.ground],
        halfFrom: [.flying, .steel, .electric],
        doubleTo: [.flying, .water],
        halfTo: [.grass, .electric, .dragon],
        noneTo: [.ground]
    ),
    .steel: TypeDamageRelations(
        doubleFrom: [.fire, .fighting, .ground],
        halfFrom: [
            .normal, .flying, .rock, .bug, .steel, .grass, .psychic, .ice, .dragon, .fairy,
        ],
        noneFrom: [.poison],
        doubleTo: [.rock, .ice, .fairy],
        halfTo: [.steel, .fire, .water, .electric]
    ),
]

private let currentGhostPoison: [PokemonType: TypeDamageRelations] = [
    .ghost: TypeDamageRelations(
        doubleFrom: [.ghost, .dark],
        halfFrom: [.poison, .bug],
        noneFrom: [.normal, .fighting],
        doubleTo: [.ghost, .psychic],
        halfTo: [.dark],
        noneTo: [.normal]
    ),
    .poison: TypeDamageRelations(
        doubleFrom: [.ground, .psychic],
        halfFrom: [.fighting, .poison, .bug, .grass, .fairy],
        doubleTo: [.grass, .fairy],
        halfTo: [.poison, .ground, .rock, .ghost],
        noneTo: [.steel]
    ),
]

private let generationIGhostPoison: [PokemonType: TypeDamageRelations] = [
    .ghost: TypeDamageRelations(
        doubleFrom: [.ghost],
        halfFrom: [.poison, .bug],
        noneFrom: [.normal, .fighting],
        doubleTo: [.ghost],
        noneTo: [.normal, .psychic]
    ),
    .poison: TypeDamageRelations(
        doubleFrom: [.ground, .psychic, .bug],
        halfFrom: [.fighting, .poison, .grass],
        doubleTo: [.grass, .bug],
        halfTo: [.poison, .ground, .rock, .ghost]
    ),
]
