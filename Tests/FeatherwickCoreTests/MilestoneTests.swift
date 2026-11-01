import Foundation
import Testing

@testable import FeatherwickCore

/// The goal ladder: milestones are awarded once, recorded in the save, and never punish.
struct MilestoneTests {
    @Test func theLadderHasUniqueIds() {
        #expect(Set(Milestones.all.map(\.id)).count == Milestones.all.count)
    }

    @Test func nothingIsAwardedBeforeTheFirstNight() {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        #expect(s.milestonesReached.isEmpty)  // the ladder only ticks at night
        #expect(!Milestones.all.contains { $0.id == "firstEgg" && $0.isReached(s) })
        #expect(!Milestones.all.contains { $0.id == "firstHatch" && $0.isReached(s) })
    }

    @Test func aMilestoneIsAwardedOnceAndRecorded() {
        var (s, _) = startedGame(sex: .hen)
        s.chicksHatched = 1  // satisfy "first hatch"
        let first = Engine.advanceMilestones(&s)
        #expect(first.contains(.milestoneReached("firstHatch")))
        #expect(s.milestonesReached.contains("firstHatch"))
        let again = Engine.advanceMilestones(&s)  // same state, nothing new
        #expect(!again.contains(.milestoneReached("firstHatch")))
    }

    @Test func milestonesAccumulateThroughPlayWithoutRepeating() {
        var (s, rng) = startedGame(sex: .hen)
        var reached: [String] = []
        for _ in 0..<120 {
            for e in night(&s, &rng) {
                if case .milestoneReached(let id) = e { reached.append(id) }
            }
        }
        #expect(Set(reached).count == reached.count)  // no milestone is ever awarded twice
        #expect(Set(reached) == s.milestonesReached)  // what was announced is what was recorded
        #expect(reached.contains("firstEgg"))  // a laying hen gets there in time
        #expect(reached.allSatisfy { id in Milestones.all.contains { $0.id == id } })
    }

    @Test func chocolateAndGreenEggsAreMilestones() {
        var (s, _) = startedGame(sex: .hen)
        s.eggBook.insert(EggBookEntry(colour: .green, speckled: false))
        s.eggBook.insert(EggBookEntry(colour: .chocolate, speckled: false))
        let events = Engine.advanceMilestones(&s)
        #expect(events.contains(.milestoneReached("greenEgg")))
        #expect(events.contains(.milestoneReached("chocolateEgg")))
    }

    @Test func aWhiteEggIsAMilestone() {
        var (s, _) = startedGame(sex: .hen)
        #expect(!Engine.advanceMilestones(&s).contains(.milestoneReached("whiteEgg")))
        s.eggBook.insert(EggBookEntry(colour: .white, speckled: false))
        #expect(Engine.advanceMilestones(&s).contains(.milestoneReached("whiteEgg")))
        #expect(Milestones.all.last?.id == "whiteEgg")  // appended: the ladder order of saves stays
    }

    // MARK: - Every rung can be climbed

    /// The least state that reaches each milestone. A new milestone needs a line here.
    static func reach(_ id: String, _ s: inout GameState, _ rng: inout SeededRNG) {
        func egg(_ colour: EggColour, speckled: Bool = false) {
            s.eggBook.insert(EggBookEntry(colour: colour, speckled: speckled))
        }
        func tameHen() {
            var hen = plainBird(.orpington, .hen, hatchDay: s.day - s.rules.adultAge, rng: &rng)
            hen.tameness = 1
            s.coop.append(hen)
        }
        func placed(_ placing: Int) {
            s.showResults.append(
                ShowResult(
                    day: s.day, showClass: .pet, entrantName: "Pip", placing: placing, fieldSize: 6, score: 70,
                    prize: 0, birdID: nil, treats: 0, notes: nil, theme: nil, podium: nil))
        }
        switch id {
        case "firstEgg": egg(.cream)
        case "firstHatch": s.chicksHatched = 1
        case "firstFriend", "lapChicken": tameHen()
        case "growingFlock":
            for _ in 0..<8 { s.coop.append(plainBird(rng: &rng)) }
        case "blueEgg": egg(.blue)
        case "oliveEgg": egg(.olive)
        case "speckledEgg": egg(.brown, speckled: true)
        case "colourCollector":
            for breed in [Breed.orpington, .wyandotte, .araucana, .silkie] {
                for variety in [ColourVariety.black, .buff] {
                    let b = Bird(
                        id: makeID(using: &rng), name: "Book", breed: breed,
                        genome: breed.purebred(.hen, variety: variety),
                        hatchDay: 0, origin: "Test", revealed: true)
                    s.breedBook.insert(BreedBookEntry(b))
                }
            }
        case "showRibbon": placed(3)
        case "blueRibbon": placed(1)
        case "storyteller":
            s.stories[Storylines.all[0].id] = StoryProgress(stepStartedDay: 0, rewarded: true)
        case "elderHen":
            s.coop.append(plainBird(.orpington, .hen, hatchDay: s.day - s.rules.elderHenAgeDays, rng: &rng))
        case "chocolateEgg": egg(.chocolate)
        case "greenEgg": egg(.green)
        case "henOrRoo": s.sexGuessesRight = 1
        case "whiteEgg": egg(.white)
        default: Issue.record("\(id) has no way to reach it in this test")
        }
    }

    /// Cozy rule 6: every rung can be climbed. Each milestone fires from the least state that reaches
    /// it. One no breed in the game can make yet still fires, but it is marked unavailable.
    @Test(arguments: Milestones.all.map(\.id))
    func everyMilestoneCanBeReached(_ id: String) throws {
        var (s, rng) = startedGame(sex: .hen)
        let m = try #require(Milestones.all.first { $0.id == id })
        #expect(!m.isReached(s), "\(id) is reached in a new game")
        Self.reach(id, &s, &rng)
        #expect(Engine.advanceMilestones(&s).contains(.milestoneReached(id)))
    }

    /// Chocolate and white eggs wait for a breed that lays them (Marans, Leghorn). Until one is in the
    /// game they are marked unavailable, so the journal gives no hint to chase. Every other rung is open.
    @Test func onlyEggsNoBreedInTheGameLaysAreUnavailable() {
        let unavailable = Milestones.all.filter { !$0.isAvailable }.map(\.id)
        #expect(unavailable == ["chocolateEgg", "whiteEgg"])
        #expect(!BreedTable.canLay(.chocolate) && !BreedTable.canLay(.white))
        #expect(EggColour.allCases.filter { !BreedTable.canLay($0) } == [.chocolate, .white])
    }

    /// The speckled egg is reached for real: two outside Orpingtons that carry speckle, bred together.
    @Test func speckledEggsComeFromTwoCarriersBredTogether() throws {
        var (s, rng) = startedGame(sex: .hen)
        let speckle = try #require(Loci.definition(Speckle.locus))
        func carrier(_ sex: Sex) -> Bird {
            while true {
                let b = Engine.youngBird(sex, origin: Bird.shopOrigin, s, &rng, breed: .orpington)
                if b.genome.alleles(at: speckle) == [Speckle.plain.rawValue, Speckle.speckled.rawValue]
                    || b.genome.alleles(at: speckle) == [Speckle.speckled.rawValue, Speckle.plain.rawValue]
                {
                    return b
                }
            }
        }
        let mother = carrier(.hen)
        let father = carrier(.rooster)
        #expect(!mother.phenotype.eggIsSpeckled)  // a carrier lays plain eggs: the gene is hidden
        var daughter: Genome?
        for _ in 0..<200 {
            let g = try Breeding.cross(mother: mother.genome, father: father.genome, using: &rng)
            if g.sex == .hen, g.speckle.isHomozygous(for: .speckled) {
                daughter = g
                break
            }
        }
        let g = try #require(daughter)
        var hen = Bird(
            id: makeID(using: &rng), name: "Freckles", breed: .orpington, genome: g,
            hatchDay: s.day - s.rules.adultAge, origin: Bird.homeOrigin, revealed: true)
        hen.motherID = mother.id
        let laid = Breeding.layEgg(mother: hen, father: nil, day: s.day, using: &rng)
        #expect(laid.speckled)
        s.eggBook.insert(EggBookEntry(colour: laid.colour, speckled: laid.speckled))
        #expect(Engine.advanceMilestones(&s).contains(.milestoneReached("speckledEgg")))
    }

    /// Speckle runs in Orpington and Wyandotte lines from outside the flock: about 4 in 10 carry one copy
    /// unseen, and about 1 in 11 has two and lays speckled eggs. Other breeds never carry it.
    @Test func speckleRunsInSomeBreedsFromOutside() {
        let game = startedGame(sex: .hen)
        let s = game.0
        var rng = game.1
        let speckle = Loci.definition(Speckle.locus)!
        for breed in Breed.allCases {
            var one = 0
            var two = 0
            let n = 2_000
            for _ in 0..<n {
                let b = Engine.youngBird(.hen, origin: Bird.shopOrigin, s, &rng, breed: breed)
                switch b.genome.alleles(at: speckle).count(where: { $0 == Speckle.speckled.rawValue }) {
                case 1: one += 1
                case 2: two += 1
                default: break
                }
            }
            let share = breed.definition.carriedShare
            if breed.definition.carried.isEmpty {
                #expect(one == 0 && two == 0, "\(breed)")
            } else {
                // Hardy-Weinberg: 2pq carry one copy, q squared carry two.
                #expect(abs(Double(one) / Double(n) - 2 * share * (1 - share)) < 0.04, "\(breed)")
                #expect(abs(Double(two) / Double(n) - share * share) < 0.03, "\(breed)")
            }
        }
    }

    /// The elder-hen rung needs a hen kept `elderHenAgeDays`, well before retirement and within two
    /// in-game years. One day short is not enough.
    @Test func theGrandOldLadyIsAHenKeptTwoYears() {
        var (s, rng) = startedGame(sex: .hen)
        let r = s.rules
        #expect(r.elderHenAgeDays < r.retirementAgeDays)
        #expect(r.elderHenAgeDays <= 8 * r.daysPerSeason)
        s.coop.append(plainBird(.orpington, .hen, hatchDay: s.day - (r.elderHenAgeDays - 1), rng: &rng))
        s.coop.append(plainBird(.orpington, .rooster, hatchDay: s.day - 2 * r.elderHenAgeDays, rng: &rng))
        #expect(!Engine.advanceMilestones(&s).contains(.milestoneReached("elderHen")))  // roosters do not count
        s.day += 1
        #expect(Engine.advanceMilestones(&s).contains(.milestoneReached("elderHen")))
    }
}
