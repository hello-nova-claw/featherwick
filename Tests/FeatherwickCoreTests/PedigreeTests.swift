import Foundation
import Testing

@testable import FeatherwickCore

struct PedigreeTests {
    /// Builds family trees by hand. Birds go in the rehomed list, which keeps them on record.
    struct Family {
        var s = GameState(rules: .standard, phase: .playing)
        var rng = SeededRNG(seed: 1)

        @discardableResult
        mutating func bird(_ sex: Sex, day: Int, mother: Bird? = nil, father: Bird? = nil, name: String = "b") -> Bird {
            let b = Bird(
                id: makeID(using: &rng), name: name, breed: .orpington, genome: Breed.orpington.purebred(sex),
                hatchDay: day, motherID: mother?.id, fatherID: father?.id, origin: "t", revealed: true)
            s.rehomed.append(b)
            return b
        }

        func k(_ a: Bird, _ b: Bird) -> Double { Pedigree.kinship(a.id, b.id, in: s) }
    }

    @Test func classicKinshipValues() {
        var f = Family()
        let gm = f.bird(.hen, day: 0)
        let gf = f.bird(.rooster, day: 0)
        let mum = f.bird(.hen, day: 30, mother: gm, father: gf)
        let dad = f.bird(.rooster, day: 30, mother: gm, father: gf)  // mum's full brother
        let stranger = f.bird(.rooster, day: 30)
        let halfBro = f.bird(.rooster, day: 31, mother: gm, father: stranger)  // mum's half brother
        let kid = f.bird(.hen, day: 60, mother: mum, father: stranger)
        let cousin = f.bird(
            .rooster, day: 60, mother: f.bird(.hen, day: 30, mother: gm, father: gf), father: f.bird(.rooster, day: 0))

        #expect(f.k(mum, mum) == 0.5)
        #expect(f.k(mum, dad) == 0.25)  // full siblings
        #expect(f.k(mum, kid) == 0.25)  // parent and chick
        #expect(f.k(mum, halfBro) == 0.125)  // half siblings
        #expect(f.k(kid, cousin) == 0.0625)  // first cousins
        #expect(f.k(gm, gf) == 0)  // unrelated founders
        #expect(Pedigree.kinship(mum.id, UUID(), in: f.s) == 0)  // unknown bird
        #expect(Relatedness(kinship: f.k(mum, dad)) == .close)
        #expect(Relatedness(kinship: f.k(kid, cousin)) == .cousins)
    }

    @Test func brotherSisterMatingClimbsTheTextbookSeries() {
        var f = Family()
        var hen = f.bird(.hen, day: 0)
        var rooster = f.bird(.rooster, day: 0)
        var series: [Double] = []
        for gen in 1...4 {
            let h = f.bird(.hen, day: gen * 30, mother: hen, father: rooster)
            let r = f.bird(.rooster, day: gen * 30, mother: hen, father: rooster)
            hen = h
            rooster = r
            series.append(f.k(hen, rooster))
        }
        // Inbreeding of each generation's chicks: 0.25, 0.375, 0.5, 0.59375.
        #expect(series == [0.25, 0.375, 0.5, 0.59375])
    }

    @Test func deepPedigreesStayFast() {
        var f = Family()
        var hen = f.bird(.hen, day: 0)
        var rooster = f.bird(.rooster, day: 0)
        for gen in 1...200 {
            let h = f.bird(.hen, day: gen, mother: hen, father: rooster)
            rooster = f.bird(.rooster, day: gen, mother: hen, father: rooster)
            hen = h
        }
        let k = f.k(hen, rooster)
        #expect(k > 0.9 && k < 1)
    }

    @Test func treesAndOffspring() {
        var f = Family()
        let gm = f.bird(.hen, day: 0, name: "Gran")
        let gf = f.bird(.rooster, day: 0, name: "Grandad")
        let mum = f.bird(.hen, day: 30, mother: gm, father: gf, name: "Mum")
        let kid = f.bird(.hen, day: 60, mother: mum, name: "Kid")
        let tree = Pedigree.tree(of: kid.id, generations: 3, in: f.s)!
        #expect(tree.record.name == "Kid")
        #expect(tree.mother?.tree.record.name == "Mum")
        #expect(tree.father == nil)
        #expect(tree.mother?.tree.mother?.tree.record.name == "Gran")
        #expect(tree.mother?.tree.mother?.tree.mother == nil)  // cut at 3 generations
        #expect(Pedigree.offspring(of: gm.id, in: f.s).map(\.name) == ["Mum"])
        #expect(Pedigree.offspring(of: mum.id, in: f.s).map(\.name) == ["Kid"])
    }

    // MARK: - In the game

    @Test func hatchedChicksRecordTheirInbreeding() {
        var f = Family()
        var r = Rules.standard
        r.foxChance = 0
        f.s.rules = r
        f.s.day = 100
        let gm = f.bird(.hen, day: 0)
        let gf = f.bird(.rooster, day: 0)
        let sis = f.bird(.hen, day: 30, mother: gm, father: gf)
        let bro = f.bird(.rooster, day: 30, mother: gm, father: gf)
        let stranger = f.bird(.rooster, day: 30)
        let inbredEgg = Breeding.layEgg(mother: sis, father: bro, day: f.s.day, using: &f.rng)
        let outcrossEgg = Breeding.layEgg(mother: sis, father: stranger, day: f.s.day, using: &f.rng)
        f.s.clutches = [Clutch(henID: nil, eggs: [inbredEgg, outcrossEgg], hatchDay: f.s.day)]
        f.s.brooderSize = 4
        _ = Engine.hatchDue(&f.s, &f.rng)
        #expect(f.s.brooder.map(\.inbreeding) == [0.25, 0])
        #expect(Pedigree.inbreeding(of: f.s.brooder[0].id, in: f.s) == 0.25)
    }

    @Test func aBoughtEggKeepsItsParentsOnRecord() {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.coins = 100
        _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
        let egg = s.carton[0]
        #expect(Pedigree.record(egg.motherID, in: s)?.origin == "Local flock")
        #expect(Pedigree.record(egg.fatherID, in: s)?.sex == .rooster)
        // Old saves without the pedigree field still load (missing field = empty).
        #expect(throws: Never.self) { try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng))) }
    }

    @Test func inbredBirdsLackVigourAndLayLess() {
        var rng = SeededRNG(seed: 4)
        var s = GameState(rules: .standard, phase: .playing)
        s.day = 25
        s.fedToday = true
        var hen = Bird(
            id: makeID(using: &rng), name: "h", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "t", revealed: true)
        #expect(Judge.condition(of: hen, in: s).notes == [.inFineCondition])
        hen.inbreeding = 0.25
        let (value, notes) = Judge.condition(of: hen, in: s)
        #expect(value == 0.75 && notes == [.lacksVigour])
        hen.inbreeding = 0.03  // distant: no visible effect
        #expect(Judge.condition(of: hen, in: s).notes == [.inFineCondition])

        // Laying: a hen with inbreeding 0.5 lays about half as often (capped loss).
        var r = Rules.standard
        r.layChance = [.spring: 1, .summer: 1, .autumn: 1, .winter: 1]
        r.broodyChance = [:]
        var laid = 0
        for i in 0..<2000 {
            var g = GameState(rules: r, phase: .playing)
            g.day = 40
            g.fedToday = true
            var h = Bird(
                id: makeID(using: &rng), name: "h", breed: .orpington, genome: Breed.orpington.purebred(.hen),
                hatchDay: 0, origin: "t", revealed: true)
            h.inbreeding = 0.9
            g.coop = [h]
            _ = Engine.lay(&g, &rng)
            laid += g.nest.count
            _ = i
        }
        #expect(abs(Double(laid) / 2000 - 0.5) < 0.04)
    }

    @Test func randomGamesNeverBreakTheTree() {
        for seed in UInt64(1)...15 {
            var rng = SeededRNG(seed: seed)
            var pick = SeededRNG(seed: seed &* 13)
            var s = Engine.newGame(using: &rng)
            _ = Engine.apply(.chooseStarter(index: Int(seed % 3), name: "S"), to: &s, using: &rng)
            for _ in 0..<1500 { _ = Engine.apply(InvariantTests.randomCommand(s, &pick), to: &s, using: &rng) }
            for b in s.ownedBirds + s.rehomed {
                let f = Pedigree.inbreeding(of: b.id, in: s)
                #expect((0...1).contains(f))
                if let stored = b.inbreeding { #expect(abs(stored - f) < 1e-9) }
                // Every chick's parents are on record.
                if b.motherID != nil { #expect(Pedigree.record(b.motherID, in: s) != nil, "seed \(seed): lost mother") }
            }
        }
    }
}
