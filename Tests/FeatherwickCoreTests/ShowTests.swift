import Foundation
import Testing
@testable import FeatherwickCore

struct ShowTests {
    /// Spring, fed, adult-age day: a bird in this state is in fine condition.
    static func showDay(day: Int = 25) -> GameState {
        var s = GameState(rules: .standard, phase: .playing)
        s.day = day
        s.fedToday = true
        return s
    }

    static func bird(_ breed: Breed, _ sex: Sex = .hen, variety: ColourVariety? = nil, typePlus: Int? = nil,
                     pure: Bool = true, age: Int = 30, s: GameState = showDay(), rng: inout SeededRNG) -> Bird {
        var g = breed.purebred(sex, variety: variety)
        if let typePlus { setType(&g, plus: typePlus) }
        var b = Bird(id: makeID(using: &rng), name: "b", breed: breed, genome: g, hatchDay: s.day - age,
                     origin: "t", revealed: true)
        b.purebredFlag = pure
        return b
    }

    /// Sets exactly `plus` "+" alleles across the show-type genes.
    static func setType(_ g: inout Genome, plus: Int) {
        var left = plus
        for locus in QuantitativeTrait.showType.loci {
            let a = left > 0 ? "+" : "-"; left -= left > 0 ? 1 : 0
            let b = left > 0 ? "+" : "-"; left -= left > 0 ? 1 : 0
            g.setAlleles([a, b], at: locus)
        }
    }

    // MARK: - Standards come from the breed table

    @Test func standardsListTheBreedsOwnColours() {
        let orp = ShowStandard(.orpington).colours.map(\.colourName)
        #expect(orp == ["black", "blue", "buff", "lavender"])
        let wy = ShowStandard(.wyandotte).colours.map(\.colourName)
        #expect(wy.contains("gold laced") && !wy.contains("buff"))
        #expect(ShowStandard(.plymouthRock).colours.map(\.colourName) == ["barred black", "buff"])
    }

    @Test func everyStandardAcceptsEveryVarietyOfItsBreed() {
        for def in BreedTable.all {
            let standard = ShowStandard(def.id)
            for variety in def.varieties {
                for sex in Sex.allCases {
                    #expect(standard.accepts(Appearance(Phenotype(def.id.purebred(sex, variety: variety)))),
                            "\(def.id) \(variety.id) \(sex)")
                }
            }
        }
    }

    // MARK: - Breed classes

    @Test func aSplashOrpingtonIsNotAStandardColour() {
        var rng = SeededRNG(seed: 1)
        var b = Self.bird(.orpington, rng: &rng)
        var g = b.genome
        g.blue = .homozygous(.blue)
        b = Bird(id: b.id, name: "s", breed: .orpington, genome: g, hatchDay: b.hatchDay, origin: "t", revealed: true)
        let card = Judge.judge(b, in: .breed(.orpington), state: Self.showDay())
        #expect(card.grade == .disqualified && card.notes == [.notAStandardColour("splash")])
    }

    @Test func entryRules() {
        var rng = SeededRNG(seed: 2)
        let s = Self.showDay()
        #expect(Judge.judge(Self.bird(.orpington, age: 5, rng: &rng), in: .breed(.orpington), state: s).notes == [.tooYoung])
        #expect(Judge.judge(Self.bird(.orpington, pure: false, rng: &rng), in: .breed(.orpington), state: s).notes == [.notPurebred])
        #expect(Judge.judge(Self.bird(.orpington, rng: &rng), in: .breed(.silkie), state: s).notes == [.wrongBreedClass])
        #expect(Judge.judge(Self.bird(.orpington, rng: &rng), in: .eggs(.brown), state: s).grade == .disqualified)
    }

    @Test func typeIsWorthHalfThePoints() {
        var rng = SeededRNG(seed: 3)
        let s = Self.showDay()
        let best = Judge.judge(Self.bird(.wyandotte, variety: .buff, typePlus: 20, rng: &rng), in: .breed(.wyandotte), state: s)
        let worst = Judge.judge(Self.bird(.wyandotte, variety: .buff, typePlus: 0, rng: &rng), in: .breed(.wyandotte), state: s)
        #expect(best.score == 100 && best.grade == .excellent)
        #expect(worst.score == 50)
        #expect(best.notes.contains(.type(.excellent)) && worst.notes.contains(.type(.poor)))
        #expect(best.notes.contains(.standardColour("gold laced")))
    }

    @Test func conditionComesFromCare() {
        var rng = SeededRNG(seed: 4)
        var s = Self.showDay()
        var b = Self.bird(.araucana, typePlus: 20, s: s, rng: &rng)
        #expect(Judge.condition(of: b, in: s).value == 1)
        s.fedToday = false
        b.noLayUntilDay = s.day + 2
        b.broodyUntilDay = s.day + 3
        s.day = s.rules.daysPerSeason * 2 + 1  // autumn: moulting
        b = Bird(id: b.id, name: b.name, breed: b.breed, genome: b.genome, hatchDay: s.day - 40, origin: "t",
                 revealed: true, noLayUntilDay: s.day + 2)
        b.broodyUntilDay = s.day + 3
        let (value, notes) = Judge.condition(of: b, in: s)
        #expect(value == 0)
        #expect(Set(notes) == [.moulting, .stressed, .broody, .hungry])
    }

    // MARK: - Show type is inherited

    @Test func typeIsInheritedAndCanNeverPassTheMaximum() throws {
        var rng = SeededRNG(seed: 5)
        func meanChild(_ m: Int, _ f: Int) throws -> Double {
            var mg = Breed.orpington.purebred(.hen), fg = Breed.orpington.purebred(.rooster)
            Self.setType(&mg, plus: m)
            Self.setType(&fg, plus: f)
            var total = 0
            for _ in 0..<2000 {
                let c = try Breeding.cross(mother: mg, father: fg, using: &rng)
                let score = QuantitativeTrait.showType.score(c)
                #expect((0...20).contains(score))
                total += score
            }
            return Double(total) / 2000
        }
        // The chick average sits midway between the parents.
        #expect(abs(try meanChild(20, 20) - 20) < 0.01)   // two perfect parents breed true
        #expect(abs(try meanChild(16, 8) - 12) < 0.5)
        #expect(abs(try meanChild(0, 0)) < 0.01)
    }

    @Test func selectiveBreedingImprovesTypeOverGenerations() throws {
        var rng = SeededRNG(seed: 6)
        var hens = (0..<20).map { _ in Self.founderGenome(.hen, &rng) }
        var roosters = (0..<20).map { _ in Self.founderGenome(.rooster, &rng) }
        let start = Self.mean(hens + roosters)
        for _ in 0..<6 {
            let pickH = hens.sorted { QuantitativeTrait.showType.score($0) > QuantitativeTrait.showType.score($1) }.prefix(5)
            let pickR = roosters.sorted { QuantitativeTrait.showType.score($0) > QuantitativeTrait.showType.score($1) }.prefix(2)
            var chicks: [Genome] = []
            for _ in 0..<80 {
                chicks.append(try Breeding.cross(mother: pickH.randomElement(using: &rng)!, father: pickR.randomElement(using: &rng)!, using: &rng))
            }
            hens = chicks.filter { $0.sex == .hen }
            roosters = chicks.filter { $0.sex == .rooster }
        }
        #expect(Self.mean(hens + roosters) > start + 3)
        #expect((hens + roosters).allSatisfy { QuantitativeTrait.showType.score($0) <= 20 })
    }

    static func founderGenome(_ sex: Sex, _ rng: inout SeededRNG) -> Genome {
        var g = Breed.orpington.purebred(sex)
        QuantitativeTrait.showType.randomise(&g, using: &rng)
        return g
    }

    static func mean(_ gs: [Genome]) -> Double {
        Double(gs.map(QuantitativeTrait.showType.score).reduce(0, +)) / Double(gs.count)
    }

    @Test func aBirdWithNoTypeGenesIsExactlyAverage() {
        // Birds from saves made before show type existed.
        for trait in QuantitativeTrait.all {
            #expect(trait.score(Genome(sex: .hen)) * 2 == trait.maxScore)
        }
    }

    @Test func neighbourAndShopBirdsVaryInTypeButAreFixedByTheirID() {
        var scores: Set<Int> = []
        for seed in UInt64(1)...60 {
            var rng = SeededRNG(seed: seed)
            guard case .choosingStarter(let chicks) = Engine.newGame(using: &rng).phase else { continue }
            for c in chicks {
                scores.insert(QuantitativeTrait.showType.score(c.genome))
                #expect(c.withFounderQuality().genome == c.genome)  // same ID, same genes
            }
        }
        #expect(scores.count >= 6)
    }

    // MARK: - Pet class

    @Test func thePetClassTakesCrossesButNotChicks() {
        var rng = SeededRNG(seed: 7)
        let s = Self.showDay()
        let cross = Self.bird(.orpington, pure: false, rng: &rng)
        // Fine condition (50) + friendliness 0.4 × 0.5 calm + 0.6 × 0.3 tameness = 0.38 (19).
        let card = Judge.judge(cross, in: .pet, state: s)
        #expect(card.score == 69 && card.notes.first == .friendliness(.skittish))
        #expect(Judge.judge(Self.bird(.orpington, age: 2, rng: &rng), in: .pet, state: s).notes == [.tooYoung])
    }

    // MARK: - Egg classes

    static func egg(_ colour: EggColour = .brown, speckled: Bool = false, shape: Int? = 12, shell: Double? = 1,
                    layDay: Int = 25, rng: inout SeededRNG) -> Egg {
        var e = Egg(id: makeID(using: &rng), layDay: layDay, motherID: UUID(), colour: colour, speckled: speckled)
        e.collectedDay = layDay
        e.shape = shape
        e.shell = shell
        return e
    }

    @Test func aPerfectPlateScoresFullMarks() {
        var rng = SeededRNG(seed: 8)
        let plate = (0..<3).map { _ in Self.egg(rng: &rng) }
        let card = Judge.judgeEggs(plate, state: Self.showDay())
        #expect(card.score == 100 && card.showClass == .eggs(.brown))
    }

    @Test func plateRules() {
        var rng = SeededRNG(seed: 9)
        let s = Self.showDay()
        #expect(Judge.judgeEggs([Self.egg(rng: &rng)], state: s).notes == [.plateNeeds(3)])
        #expect(Judge.judgeEggs([], state: s).grade == .disqualified)
        let mixed = [Self.egg(rng: &rng), Self.egg(rng: &rng), Self.egg(.blue, rng: &rng)]
        #expect(Judge.judgeEggs(mixed, state: s).notes == [.notMatched])
        let speckleMix = [Self.egg(rng: &rng), Self.egg(rng: &rng), Self.egg(speckled: true, rng: &rng)]
        #expect(Judge.judgeEggs(speckleMix, state: s).notes == [.notMatched])
    }

    @Test func staleEggsAndPoorShellsLosePoints() {
        var rng = SeededRNG(seed: 10)
        let s = Self.showDay()
        var old = Self.egg(layDay: 20, rng: &rng)
        old.collectedDay = 25  // sat in the nest too long
        let plate = [old, Self.egg(shell: 0.5, rng: &rng), Self.egg(rng: &rng)]
        let card = Judge.judgeEggs(plate, state: s)
        #expect(card.score < 100 && card.notes.contains(.staleEggs(1)))
    }

    @Test func oldEggsWithoutShowDataCountAsAverage() {
        var rng = SeededRNG(seed: 11)
        let plate = (0..<3).map { _ in Self.egg(shape: nil, shell: nil, rng: &rng) }
        let card = Judge.judgeEggs(plate, state: Self.showDay())
        #expect(card.score == 30 + 15 + 15 + 20)
    }

    @Test func aHensEggsAllHaveHerShape() {
        var rng = SeededRNG(seed: 12)
        let hen = Self.bird(.orpington, rng: &rng).withFounderQuality()
        let shapes = Set((0..<10).map { _ in Breeding.layEgg(mother: hen, father: nil, day: 30, using: &rng).shape })
        #expect(shapes == [QuantitativeTrait.eggShape.score(hen.genome)])
    }

    @Test func shellsAreThinnerInSummerAndWithAge() {
        var rng = SeededRNG(seed: 13)
        var s = Self.showDay()
        let young = Self.bird(.orpington, age: 30, s: s, rng: &rng)
        #expect(Judge.shellQuality(of: young, in: s) == 1)
        s.day = s.rules.daysPerSeason + 1  // summer
        let summer = Self.bird(.orpington, age: 30, s: s, rng: &rng)
        #expect(Judge.shellQuality(of: summer, in: s) < 1)
        let veryOld = Self.bird(.orpington, age: 10_000, s: s, rng: &rng)
        #expect(Judge.shellQuality(of: veryOld, in: s) == 0.1)
    }

    @Test func bestPlatesPickMatchingEggsBestFirst() {
        var rng = SeededRNG(seed: 14)
        let carton = [Self.egg(shape: 2, rng: &rng)] + (0..<3).map { _ in Self.egg(rng: &rng) }
            + (0..<3).map { _ in Self.egg(.blue, shape: 4, rng: &rng) } + [Self.egg(.olive, rng: &rng)]
        let plates = Judge.bestPlates(from: carton, state: Self.showDay())
        #expect(plates.map(\.card.showClass) == [.eggs(.brown), .eggs(.blue)])
        #expect(plates[0].eggs.allSatisfy { $0.shape == 12 })
    }

    // MARK: - Saves

    @Test func aSaveMissingNewRulesAndFieldsStillLoads() throws {
        var json = try #require(JSONSerialization.jsonObject(with: SaveFormat.encode(SaveFormatTests.busyGame())) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        var rules = try #require(state["rules"] as? [String: Any])
        rules["foxChance"] = nil
        state["rules"] = rules
        state["coins"] = nil
        json["state"] = state
        let game = try SaveFormat.decode(JSONSerialization.data(withJSONObject: json))
        #expect(game.state.rules.foxChance == Rules.standard.foxChance)
        #expect(game.state.coins == Rules.standard.startCoins)
    }

    @Test func scoresStayInRangeForEveryBirdInARandomGame() {
        for seed in UInt64(1)...20 {
            var rng = SeededRNG(seed: seed), pick = SeededRNG(seed: seed &* 31)
            var s = Engine.newGame(using: &rng)
            _ = Engine.apply(.chooseStarter(index: 0, name: "S"), to: &s, using: &rng)
            for _ in 0..<600 { _ = Engine.apply(InvariantTests.randomCommand(s, &pick), to: &s, using: &rng) }
            for b in s.birdsAtHome {
                for cls in [ShowClass.breed(b.breed), .pet] {
                    let card = Judge.judge(b, in: cls, state: s)
                    #expect((0...100).contains(card.score))
                    #expect((card.grade == .disqualified) == (card.score == 0 && card.notes.count == 1))
                }
            }
            for plate in Judge.bestPlates(from: s.carton, state: s) { #expect((0...100).contains(plate.card.score)) }
        }
    }
}
