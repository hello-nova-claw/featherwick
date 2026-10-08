import Foundation
import Testing

@testable import FeatherwickCore

/// Egg colour from shell genes: blue shell, brown coating, and brown depth (many small genes).
struct EggColourTests {
    static let depth = QuantitativeTrait.brownDepth

    static func hen(blue: Bool, brown: Bool, depth share: Double? = nil) -> Genome {
        var g = Genome(sex: .hen)
        if blue { g.blueShell = AllelePair(.blue, .white) }
        if brown { g.brownShell = AllelePair(.brown, .noCoating) }
        if let share { Self.depth.setShare(share, in: &g) }
        return g
    }

    static func colour(_ g: Genome) -> EggColour? { Phenotype(g).eggColour }

    @Test func theColourRule() {
        for share in [0.0, 0.5, 1.0] {
            #expect(Self.colour(Self.hen(blue: false, brown: false, depth: share)) == (share == 0 ? .white : .cream))
            #expect(Self.colour(Self.hen(blue: true, brown: false, depth: share)) == .blue)
        }
        #expect(Self.colour(Self.hen(blue: false, brown: true, depth: 0.2)) == .brown)
        #expect(Self.colour(Self.hen(blue: false, brown: true, depth: Rules.chocolateShellDepth)) == .brown)
        #expect(Self.colour(Self.hen(blue: false, brown: true, depth: 0.9)) == .chocolate)
        #expect(Self.colour(Self.hen(blue: true, brown: true, depth: 0.2)) == .green)
        #expect(Self.colour(Self.hen(blue: true, brown: true, depth: Rules.oliveShellDepth)) == .olive)
        #expect(Self.colour(Self.hen(blue: true, brown: true, depth: 0.9)) == .olive)
    }

    /// The bare shell is white. With no blue and no brown coating, depth is the faint tint that makes
    /// it cream. Only a shell with (almost) none of it is white.
    @Test func noBlueNoCoatingAndLowDepthIsWhite() {
        let steps = Double(Self.depth.maxScore)
        for plus in 0...Self.depth.maxScore {
            let share = Double(plus) / steps
            let expected: EggColour = share <= Rules.whiteShellDepth ? .white : .cream
            #expect(Self.colour(Self.hen(blue: false, brown: false, depth: share)) == expected)
        }
        #expect(Self.colour(Self.hen(blue: false, brown: false, depth: 0)) == .white)
        #expect(Self.colour(Self.hen(blue: false, brown: false, depth: 0.05)) == .white)
        #expect(Self.colour(Self.hen(blue: false, brown: false, depth: 0.1)) == .cream)
        // Blue and brown shells ignore the white threshold.
        #expect(Self.colour(Self.hen(blue: true, brown: false, depth: 0)) == .blue)
        #expect(Self.colour(Self.hen(blue: false, brown: true, depth: 0)) == .brown)
        #expect(Self.colour(Self.hen(blue: true, brown: true, depth: 0)) == .green)
        // Roosters lay nothing, white or not.
        var rooster = Genome(sex: .rooster)
        Self.depth.setShare(0, in: &rooster)
        #expect(Phenotype(rooster).eggColour == nil)
    }

    /// The threshold sits below every breed in play, so no in-game breed changes colour.
    @Test func whiteChangesNoBreedInPlay() {
        #expect(Breed.silkie.definition.brownDepth > Rules.whiteShellDepth)
        #expect(Breed.silkie.definition.eggColour == .cream)
        #expect(Breed.orpington.definition.eggColour == .brown)
        #expect(Breed.wyandotte.definition.eggColour == .brown)
        #expect(Breed.australorp.definition.eggColour == .brown)
        #expect(Breed.araucana.definition.eggColour == .blue)
        #expect(Breed.marans.definition.eggColour == .chocolate)
        #expect(Phenotype(Genome(sex: .hen)).eggColour == .cream)  // the default (old saves)
        for def in BreedTable.inGame { #expect(def.eggColour != .white, "\(def.id)") }
    }

    /// Real Leghorns lay white eggs. So does a purebred Leghorn, and a Leghorn from outside the flock.
    @Test func aLeghornLaysWhite() throws {
        #expect(Breed.leghorn.definition.eggColour == .white)
        #expect(Self.depth.fraction(Breed.leghorn.purebred(.hen)) <= Rules.whiteShellDepth)
        var rng = SeededRNG(seed: 8)
        for _ in 0..<50 {
            let outside = Bird(
                id: makeID(using: &rng), name: "o", breed: .leghorn, genome: Breed.leghorn.purebred(.hen),
                hatchDay: 0, origin: "Shop"
            ).withFounderQuality()
            #expect(outside.phenotype.eggColour == .white)
            let chick = try Breeding.cross(
                mother: Breed.leghorn.purebred(.hen), father: Breed.leghorn.purebred(.rooster), using: &rng)
            if chick.sex == .hen { #expect(Self.colour(chick) == .white) }
        }
    }

    /// White × cream, like a Leghorn × Silkie cross. The first cross is a pale cream (the tint is
    /// half from each parent). Bred on, the tint sorts out: some daughters lay white, some cream.
    /// Back to a Leghorn, most daughters lay white. As in real flocks, through many small genes.
    @Test func whiteTimesCreamGivesASpreadThroughDepth() throws {
        var rng = SeededRNG(seed: 31)
        let leghornHen = Breed.leghorn.purebred(.hen)
        let leghornRooster = Breed.leghorn.purebred(.rooster)
        let f1 = try (0..<60).map { _ in
            try Breeding.cross(mother: leghornHen, father: Breed.silkie.purebred(.rooster), using: &rng)
        }
        for chick in f1 {
            if chick.sex == .hen { #expect(Self.colour(chick) == .cream) }
            #expect(Self.depth.fraction(chick) == 0.1)  // halfway between 0 and 0.2
        }
        let f1Hens = f1.filter { $0.sex == .hen }
        let f1Roosters = f1.filter { $0.sex == .rooster }
        try #require(!f1Hens.isEmpty && !f1Roosters.isEmpty)

        func whiteShare(_ chicks: [Genome]) -> Double {
            let hens = chicks.filter { $0.sex == .hen }
            return Double(hens.count(where: { Self.colour($0) == .white })) / Double(hens.count)
        }
        // F2: about 5 in 16 white (one "+" or none, out of four that can sort out).
        let f2 = try (0..<2000).map { i in
            try Breeding.cross(
                mother: f1Hens[i % f1Hens.count], father: f1Roosters[i % f1Roosters.count], using: &rng)
        }
        #expect(abs(whiteShare(f2) - 5.0 / 16) < 0.05)
        #expect(Set(f2.compactMap(Self.colour)) == [.white, .cream])
        // Backcross to a Leghorn: about 3 in 4 white.
        let back = try (0..<2000).map { i in
            try Breeding.cross(mother: f1Hens[i % f1Hens.count], father: leghornRooster, using: &rng)
        }
        #expect(abs(whiteShare(back) - 3.0 / 4) < 0.05)
    }

    /// A bird with no depth genes (every bird in an older save) lays what it laid before.
    @Test func averageDepthKeepsTheOldColours() {
        #expect(Self.colour(Self.hen(blue: false, brown: true)) == .brown)
        #expect(Self.colour(Self.hen(blue: true, brown: true)) == .olive)
        var g = Genome(sex: .hen)
        Self.depth.setShare(0.5, in: &g)
        #expect(g == Genome(sex: .hen))  // average depth is exactly the default genes
    }

    @Test func breedsHaveTheirOwnDepth() {
        #expect(Breed.marans.definition.eggColour == .chocolate)
        #expect(Breed.marans.definition.status == .planned)
        #expect(Breed.orpington.definition.eggColour == .brown)
        #expect(Breed.australorp.definition.eggColour == .brown)
        let marans = Self.depth.fraction(Breed.marans.purebred(.hen))
        let orpington = Self.depth.fraction(Breed.orpington.purebred(.hen))
        let araucana = Self.depth.fraction(Breed.araucana.purebred(.hen))
        let silkie = Self.depth.fraction(Breed.silkie.purebred(.hen))
        #expect(marans > Rules.chocolateShellDepth)
        #expect(orpington == 0.5 && Self.depth.fraction(Breed.australorp.purebred(.hen)) == 0.5)
        #expect(araucana < Rules.oliveShellDepth && silkie < Rules.oliveShellDepth)
    }

    /// Birds from outside the flock draw depth from their own ID, with the breed's chance.
    @Test func outsideBirdsDrawDepthByBreed() {
        var rng = SeededRNG(seed: 4)
        func meanDepth(_ breed: Breed) -> Double {
            let scores = (0..<300).map { _ in
                Bird(
                    id: makeID(using: &rng), name: "o", breed: breed, genome: breed.purebred(.hen),
                    hatchDay: 0, origin: "Shop"
                ).withFounderQuality()
            }.map { Self.depth.fraction($0.genome) }
            return scores.reduce(0, +) / Double(scores.count)
        }
        let marans = meanDepth(.marans)
        let orpington = meanDepth(.orpington)
        let araucana = meanDepth(.araucana)
        #expect(marans > orpington && orpington > araucana)
        #expect(abs(orpington - 0.5) < 0.05)
    }

    /// Each parent passes one allele per gene, so depth is half from each parent.
    @Test func depthComesHalfFromEachParent() throws {
        var rng = SeededRNG(seed: 11)
        var mother = Genome(sex: .hen)
        Self.depth.setShare(1, in: &mother)
        var father = Genome(sex: .rooster)
        Self.depth.setShare(0, in: &father)
        for _ in 0..<100 {
            let chick = try Breeding.cross(mother: mother, father: father, using: &rng)
            #expect(Self.depth.score(chick) == Self.depth.maxScore / 2)
        }
        // Mixed parents: the chicks average out between them, and never pass the maximum.
        var high = Genome(sex: .hen)
        Self.depth.setShare(0.9, in: &high)
        var low = Genome(sex: .rooster)
        Self.depth.setShare(0.2, in: &low)
        let chicks = try (0..<2000).map { _ in try Breeding.cross(mother: high, father: low, using: &rng) }
        let mean = chicks.map { Double(Self.depth.score($0)) }.reduce(0, +) / Double(chicks.count)
        let expected = Double(Self.depth.score(high) + Self.depth.score(low)) / 2
        #expect(abs(mean - expected) < 0.2)
        #expect(chicks.allSatisfy { Self.depth.score($0) <= Self.depth.maxScore })
    }

    /// Araucana × Marans: dark olive eggers. Bred on, the line lays olive and green (and blue,
    /// cream, brown and chocolate as the genes sort out), like a real olive-egger flock.
    @Test func araucanaTimesMaransOverGenerationsGivesOliveAndGreen() throws {
        var rng = SeededRNG(seed: 21)
        let f1 = try (0..<40).map { i in
            try Breeding.cross(
                mother: Breed.araucana.purebred(.hen), father: Breed.marans.purebred(.rooster), using: &rng)
        }
        for chick in f1 where chick.sex == .hen { #expect(Self.colour(chick) == .olive) }

        var generation = f1
        var seen: Set<EggColour> = []
        for _ in 0..<3 {
            let hens = generation.filter { $0.sex == .hen }
            let roosters = generation.filter { $0.sex == .rooster }
            try #require(!hens.isEmpty && !roosters.isEmpty)
            generation = try (0..<400).map { _ in
                let m = hens[Int.random(in: 0..<hens.count, using: &rng)]
                let f = roosters[Int.random(in: 0..<roosters.count, using: &rng)]
                return try Breeding.cross(mother: m, father: f, using: &rng)
            }
            for chick in generation { if let c = Self.colour(chick) { seen.insert(c) } }
        }
        #expect(seen.contains(.olive) && seen.contains(.green))
    }

    /// Old saves load: no bird changes its egg colour, and no depth genes appear from nowhere.
    @Test func anOldSaveKeepsItsEggColours() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        let hens = game.state.ownedBirds.filter { $0.sex == .hen }
        #expect(!hens.isEmpty)
        for hen in hens {
            #expect(Self.depth.score(hen.genome) == Self.depth.maxScore / 2)
            #expect([.cream, .brown, .blue, .olive].contains(hen.phenotype.eggColour))
        }
    }

    /// Show egg classes match by colour, so a plate of green eggs is a real plate.
    @Test func aPlateOfGreenEggsIsValid() {
        var rng = SeededRNG(seed: 3)
        let plate = (0..<3).map { _ in ShowTests.egg(.green, rng: &rng) }
        let card = Judge.judgeEggs(plate, state: ShowTests.showDay())
        #expect(card.grade != .disqualified && card.showClass == .eggs(.green))
        let mixed = [
            ShowTests.egg(.green, rng: &rng), ShowTests.egg(.green, rng: &rng), ShowTests.egg(.olive, rng: &rng),
        ]
        #expect(Judge.judgeEggs(mixed, state: ShowTests.showDay()).grade == .disqualified)
    }
}
