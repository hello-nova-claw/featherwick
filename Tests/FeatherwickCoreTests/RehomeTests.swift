import Foundation
import Testing

@testable import FeatherwickCore

/// A fine bird is worth much more to rehome than a plain one: type, egg shape and ribbons count.
struct RehomeQualityTests {
    /// The best possible show type and egg shape.
    static func fine(_ genome: Genome) -> Genome {
        var g = genome
        for trait in [QuantitativeTrait.showType, .eggShape] {
            for locus in trait.loci { g.setAlleles([QuantitativeTrait.plus, QuantitativeTrait.plus], at: locus) }
        }
        return g
    }

    static func bird(_ genome: Genome, revealed: Bool = true, rng: inout SeededRNG) -> Bird {
        Bird(
            id: makeID(using: &rng), name: "Fine", breed: .orpington, genome: genome, hatchDay: 0, origin: "t",
            revealed: revealed)
    }

    @Test func aTopPurebredWithRibbonsIsWorthSeveralPlainBirds() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 8)
        let plain = Self.bird(Breed.orpington.purebred(.hen), rng: &rng)
        let top = Self.bird(Self.fine(Breed.orpington.purebred(.hen)), rng: &rng)
        #expect(r.rehomeValue(of: plain, onDay: r.adultAge, ribbons: 0) == 6)  // average quality: no bonus
        // (type 16 + egg shape 6 + 3 ribbons × 6) × 1.5 for a standard purebred, plus the adult base of 6.
        #expect(r.rehomeValue(of: top, onDay: r.adultAge, ribbons: 3) == 6 + 60)
        // Without ribbons, type and egg shape alone still lift the price.
        #expect(r.rehomeValue(of: top, onDay: r.adultAge) == 6 + 33)
    }

    @Test func eggShapeCountsOnlyForALayingHen() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 8)
        let rooster = Self.bird(Self.fine(Breed.orpington.purebred(.rooster)), rng: &rng)
        #expect(r.rehomeValue(of: rooster, onDay: r.adultAge) == 6 + 24)  // type 16 × 1.5
        let hen = Self.bird(Self.fine(Breed.orpington.purebred(.hen)), rng: &rng)
        #expect(r.rehomeValue(of: hen, onDay: r.growerAge) == 4 + 24)  // a pullet: not laying yet
        #expect(r.rehomeValue(of: hen, onDay: r.retirementAgeDays) == 6 + 24)  // retired: not laying
    }

    @Test func crossesAndOffColoursGetNoPurebredBonus() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 8)
        var cross = Self.bird(Self.fine(Breed.orpington.purebred(.hen)), rng: &rng)
        cross.purebredFlag = false
        #expect(r.rehomeValue(of: cross, onDay: r.adultAge, ribbons: 3) == 6 + 40)
        // Splash is not a standard Orpington colour: the rare-colour bonus, but no purebred bonus.
        let splash = Self.bird(Self.fine(Breed.orpington.purebred(.hen, variety: ShopSpecial.splash)), rng: &rng)
        #expect(splash.phenotype.colour == .splash)
        #expect(r.rehomeValue(of: splash, onDay: r.adultAge) == 6 + 22 + r.rareSplash)
    }

    @Test func hiddenQualityAndExtraRibbonsAddNothing() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 8)
        let chick = Self.bird(Self.fine(Breed.orpington.purebred(.hen)), revealed: false, rng: &rng)
        #expect(r.rehomeValue(of: chick, onDay: 0, ribbons: 2) == 2)
        let top = Self.bird(Self.fine(Breed.orpington.purebred(.hen)), rng: &rng)
        #expect(
            r.rehomeValue(of: top, onDay: r.adultAge, ribbons: 50)
                == r.rehomeValue(of: top, onDay: r.adultAge, ribbons: r.rehomeMaxRibbons))
    }

    /// Ribbons are 1st to 3rd places in bird classes, matched by the bird's name.
    @Test func theGameCountsABirdsRibbons() throws {
        var (s, rng) = startedGame(sex: .hen)
        s.brooder[0].revealed = true
        let pip = s.brooder[0]
        let json = """
            [
              {"day": 28, "showClass": {"breed": {"_0": "orpington"}}, "entrantName": "Pip", "placing": 1,
               "fieldSize": 6, "score": 80, "prize": 20},
              {"day": 56, "showClass": {"pet": {}}, "entrantName": "Pip", "placing": 3,
               "fieldSize": 6, "score": 70, "prize": 5},
              {"day": 84, "showClass": {"pet": {}}, "entrantName": "Pip", "placing": 4,
               "fieldSize": 6, "score": 60, "prize": 0},
              {"day": 84, "showClass": {"eggs": {"_0": "brown"}}, "entrantName": "Pip", "placing": 1,
               "fieldSize": 6, "score": 90, "prize": 20},
              {"day": 84, "showClass": {"pet": {}}, "entrantName": "Someone else", "placing": 1,
               "fieldSize": 6, "score": 90, "prize": 20}
            ]
            """
        s.showResults = try JSONDecoder().decode([ShowResult].self, from: Data(json.utf8))
        #expect(s.ribbons(for: pip) == 2)
        #expect(s.rehomeValue(of: pip) == 2 + 18)  // a chick: 2, plus 2 ribbons × 6 × 1.5
        // Rehoming pays the price with ribbons.
        s.coop.append(plainBird(rng: &rng))  // so Pip is not the last bird
        #expect(
            Engine.apply(.rehome(pip.id), to: &s, using: &rng) == [
                .rehomed(pip.id, coins: 20), .slotSpent(.neighbour, left: 2),
            ])
    }
}
