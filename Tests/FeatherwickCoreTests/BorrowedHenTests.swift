import Foundation
import Testing

@testable import FeatherwickCore

/// The borrowed hen: Marigold, the starter's mother, on loan from Hazel from day 3, and the day-10 choice.
struct BorrowedHenTests {
    static let tag = Storylines.marigold

    /// A new keeper's game (the early game on), with no fox, every hen laying, and no jobs or goals.
    /// `starterSex` swaps the chosen starter's sex and keeps everything else, for the rule-8 test.
    static func newKeeper(seed: UInt64 = 1, index: Int = 0, starterSex: Sex? = nil) -> (GameState, SeededRNG) {
        var rules = calmRules()
        rules.jobsPerDay = 0
        rules.seasonGoals = false
        rules.noteChance = 0
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(rules: rules, using: &rng)
        if let sex = starterSex, case .choosingStarter(var chicks) = s.phase {
            let z = chicks[index].genome.zAlleles(Barring.self)[0]
            chicks[index].genome.sexChromosomes = sex == .hen ? .hen(z: z) : .rooster(z: AllelePair(z, z))
            s.phase = .choosingStarter(chicks)
        }
        _ = Engine.apply(.chooseStarter(index: index, name: "Basil"), to: &s, using: &rng)
        return (s, rng)
    }

    /// Feeds, shuts the coop and sleeps until the morning of `day`. Returns every event on the way.
    @discardableResult
    static func play(until day: Int, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        var ev: [GameEvent] = []
        while s.day < day {
            for c in [Command.feed, .closeCoop] { ev += Engine.apply(c, to: &s, using: &rng) }
            ev += sleepTonight(&s, &rng)
        }
        return ev
    }

    static func marigold(_ s: GameState) -> Bird? { s.loanedBird(tag: tag) }

    // MARK: - She comes, and lays

    @Test func hazelAsksOnDay2AndMarigoldComesOnDay3() throws {
        var (s, rng) = Self.newKeeper()
        let day2 = Self.play(until: 2, &s, &rng)
        #expect(day2.contains(.storyStarted(Self.tag)))
        #expect(Self.marigold(s) == nil)

        let day3 = Self.play(until: 3, &s, &rng)
        let hen = try #require(Self.marigold(s))
        #expect(day3.contains(.loanArrived(hen.id, from: .hazel)))
        #expect(day3.contains(.storyStep(Self.tag, step: "staying")))
        #expect(day3.contains(.introduced(.coopDoor)))
        #expect(hen.name == "Marigold" && hen.sex == .hen && hen.revealed && hen.origin == Bird.neighbourOrigin)
        #expect(hen.stage(onDay: s.day, rules: s.rules) == .adult)
        #expect(hen.breed == s.starterBreed && hen.isPurebred)
        #expect(s.coop.contains { $0.id == hen.id })
        #expect(s.perchesUsed == 0)  // she brings her own box
        #expect(s.hazelAway && s.marigoldCame)
    }

    @Test func marigoldLaysFromDay4AndTheLayingLessonComesWithHer() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 3, &s, &rng)
        let hen = try #require(Self.marigold(s))
        let day4 = Self.play(until: 4, &s, &rng)
        #expect(day4.contains { if case .eggLaid(_, by: hen.id) = $0 { true } else { false } })
        #expect(day4.contains(.introduced(.laying)))
        #expect(s.nest.contains { $0.motherID == hen.id })
        // Her eggs are the keeper's: collect and sell them.
        #expect(Engine.apply(.collectEggs, to: &s, using: &rng).first == .eggsCollected(count: 1, leftInNest: 0))
        #expect(
            Engine.apply(.sellEggs, to: &s, using: &rng).contains { if case .eggsSold = $0 { true } else { false } })
    }

    @Test func theNewTimelineHasALessonADay() {
        let r = Rules.standard
        let days = Feature.allCases.filter { $0 != .shows }.map { r.introductionDay(of: $0) }
        #expect(days == [1, 2, 3, 4, 5, 8, 9, 10, 14, 29, 35])
        // The cases are in timeline order.
        #expect(
            Feature.allCases.map { r.introductionDay(of: $0) }
                == Feature.allCases.map { r.introductionDay(of: $0) }.sorted())
    }

    // MARK: - She is the starter's mother

    @Test(arguments: [UInt64(1), 2, 3, 7, 42])
    func theStartersMotherIsMarigold(seed: UInt64) throws {
        for index in 0..<3 {
            var (s, rng) = Self.newKeeper(seed: seed, index: index)
            Self.play(until: 3, &s, &rng)
            let hen = try #require(Self.marigold(s))
            let starter = try #require(s.starterID.flatMap { s.bird($0) })
            #expect(starter.motherID == hen.id)
            let mate = try #require(starter.fatherID.flatMap { s.pedigree[$0] })
            #expect(mate.sex == .rooster && mate.breed == starter.breed && mate.look == nil)
            // She holds one of the starter's alleles at every gene: she could be its mother.
            for locus in Loci.all {
                let hers = hen.genome.alleles(at: locus)
                let its = starter.genome.alleles(at: locus)
                #expect(!Set(hers).isDisjoint(with: its), "\(locus.id)")
            }
            // Knowledge reads her as the mother, and nothing it works out contradicts.
            let visible = try #require(Visible.all(in: s).first { $0.id == starter.id })
            #expect(visible.motherID == hen.id)
            let k = Knowledge.of(s)
            #expect(k.contradictions == 0)
            #expect(k.bird(hen.id) != nil && k.bird(mate.id) != nil)
            // And still none once the starter has grown and shows its breed and sex.
            Self.play(until: 12, &s, &rng)
            #expect(Knowledge.of(s).contradictions == 0)
        }
    }

    @Test func knowledgeUsesHerAsEvidence() throws {
        // A black chick and a blue mother: the chick got her black allele, so its blue is not from her.
        var rng = SeededRNG(seed: 4)
        let chick = Breed.orpington.purebred(.rooster, colour: .black)
        var blue: Genome?
        for _ in 0..<50 where blue == nil {
            if let g = Breed.orpington.motherGenome(of: chick, using: &rng), Phenotype(g).colour == .blue { blue = g }
        }
        let mother = try #require(blue)
        #expect(mother.blue.count(of: .notBlue) == 1)  // she carries the chick's black allele
        // A buff chick's mother is buff: none of the breed's other colours carries buff.
        let buff = Breed.orpington.purebred(.hen, colour: .buff)
        for _ in 0..<20 {
            let g = try #require(Breed.orpington.motherGenome(of: buff, using: &rng))
            #expect(Phenotype(g).colour == .buff)
        }
    }

    /// Rule 8. Marigold's look, and everything the keeper can work out, is the same for a hen starter and
    /// a rooster starter with the same look, until the sex shows. Barring is the trap: it is on the Z.
    @Test(arguments: [UInt64(1), 2, 3, 7, 42, 100])
    func marigoldNeverTellsTheStartersSex(seed: UInt64) throws {
        for index in 0..<3 {
            for barred in [false, true] {
                var (hen, rngH) = Self.newKeeper(seed: seed, index: index, starterSex: .hen)
                var (roo, rngR) = Self.newKeeper(seed: seed, index: index, starterSex: .rooster)
                let z: Barring = barred ? .barred : .plain
                for i in hen.brooder.indices { hen.brooder[i].genome.sexChromosomes = .hen(z: z) }
                for i in roo.brooder.indices { roo.brooder[i].genome.sexChromosomes = .rooster(z: .homozygous(z)) }
                let starter = try #require(hen.starterID)
                for day in [3, 4, 6] {
                    let evH = Self.play(until: day, &hen, &rngH)
                    let evR = Self.play(until: day, &roo, &rngR)
                    #expect(evH == evR, "day \(day)")
                    let mH = try #require(Self.marigold(hen))
                    let mR = try #require(Self.marigold(roo))
                    #expect(mH.genome == mR.genome)
                    #expect(mH.genome.zAlleles(Barring.self) == [z])  // her barring is the starter's
                    #expect(Visible.all(in: hen) == Visible.all(in: roo))
                    #expect(Knowledge.of(hen) == Knowledge.of(roo))
                    #expect(Planner.carrierNotes(for: starter, in: hen) == Planner.carrierNotes(for: starter, in: roo))
                    #expect(Planner.carrierNotes(for: mH.id, in: hen) == Planner.carrierNotes(for: mR.id, in: roo))
                }
            }
        }
    }

    // MARK: - The day-10 choice

    @Test func onDay10HazelAsksAndTheChoiceWaits() throws {
        var (s, rng) = Self.newKeeper()
        let ev = Self.play(until: 10, &s, &rng)
        #expect(ev.contains(.storyStep(Self.tag, step: "decide")))
        #expect(s.pendingChoices.map(\.choice) == [Self.tag])
        #expect(s.pendingChoices.first?.options == ["return", "keep"])
        #expect(!s.hazelAway)
        // Nothing is lost by waiting: she stays, and the choice stays.
        Self.play(until: 20, &s, &rng)
        #expect(Self.marigold(s) != nil && s.pendingChoices.count == 1)
    }

    @Test func sendingHerHomeGivesACandledFertileEggOfTheStartersBreed() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 10, &s, &rng)
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        _ = Engine.apply(.sellEggs, to: &s, using: &rng)
        let hen = try #require(Self.marigold(s))
        let breed = s.starterBreed
        let slots = s.slotsLeft
        let ev = Engine.apply(.choose(story: Self.tag, option: "return"), to: &s, using: &rng)
        #expect(ev.first == .chose(Self.tag, "return"))
        #expect(ev.contains(.loanReturned(hen.id, to: .hazel)))
        #expect(ev.contains(.storyGiftEgg(Self.tag, breed)))
        #expect(ev.contains(.storyFinished(Self.tag)))
        // The first fertile egg brings Hazel's small incubator.
        #expect(ev.contains(.neighbourGaveIncubator(size: s.rules.giftIncubatorSize, ownRooster: false)))
        #expect(s.slotsLeft == slots)  // a word over the fence: no daylight
        let egg = try #require(s.carton.last)
        #expect(egg.isCandled && egg.isFertile && egg.motherBreed == breed && egg.fatherBreed == breed)
        #expect(Self.marigold(s) == nil && s.bird(hen.id) == nil && s.debts.isEmpty)
        // She keeps her place in the starter's family tree, with the look the keeper saw.
        #expect(s.pedigree[hen.id]?.look != nil)
        #expect(s.starterID.flatMap { s.bird($0) }?.motherID == hen.id)
        #expect(s.chosen(Self.tag, in: Self.tag) == "return")
    }

    @Test func keepingHerMakesADebtAndSheStays() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 10, &s, &rng)
        let hen = try #require(Self.marigold(s))
        let ev = Engine.apply(.choose(story: Self.tag, option: "keep"), to: &s, using: &rng)
        #expect(ev.contains(.loanKept(hen.id, from: .hazel)))
        #expect(ev.contains(.debtOwed(Self.tag, to: .hazel, coins: s.rules.marigoldPrice)))
        #expect(!ev.contains { if case .storyGiftEgg = $0 { true } else { false } })
        let mine = try #require(s.bird(hen.id))
        #expect(mine.loan == nil && s.coop.contains { $0.id == hen.id })
        #expect(s.debts == [Debt(id: Self.tag, to: .hazel, coins: 40, mentionedDay: s.day)])
        #expect(s.stories[Self.tag]?.rewarded == true)
        // Paid when the keeper can.
        s.coins = 100
        #expect(Engine.apply(.payDebt(Self.tag), to: &s, using: &rng) == [.debtPaid(Self.tag, to: .hazel, coins: 40)])
    }

    @Test func keepingHerWaitsForAFreePerch() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 10, &s, &rng)
        let hen = try #require(Self.marigold(s))
        s.perches = s.perchesUsed  // every perch taken by the keeper's own birds
        let chose = Engine.apply(.choose(story: Self.tag, option: "keep"), to: &s, using: &rng)
        // The choice is made and kept; the keeping waits for a perch, and she stays on loan meanwhile.
        #expect(chose.contains(.chose(Self.tag, "keep")))
        #expect(chose.contains(.storyGiftWaitingForRoom(Self.tag)))
        #expect(s.chosen(Self.tag, in: Self.tag) == "keep" && s.pendingChoices.isEmpty)
        #expect(Self.marigold(s) != nil && s.debts.isEmpty)
        // Room for the grown chicks waiting in the brooder (they move in first) and one more for her.
        s.perches = s.perchesUsed + s.brooder.count + 1
        let night = Self.play(until: s.day + 1, &s, &rng)
        #expect(night.contains(.loanKept(hen.id, from: .hazel)))
        #expect(night.contains(.debtOwed(Self.tag, to: .hazel, coins: 40)))
        #expect(s.perchesUsed == s.perches)
    }

    @Test func aFullCartonHoldsUpOnlyTheEgg() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 10, &s, &rng)
        let hen = try #require(Self.marigold(s))
        let filler = try #require(s.nest.first ?? s.carton.first)
        s.carton = Array(repeating: filler, count: s.cartonCapacity)
        let ev = Engine.apply(.choose(story: Self.tag, option: "return"), to: &s, using: &rng)
        #expect(ev.contains(.loanReturned(hen.id, to: .hazel)))
        #expect(ev.contains(.storyGiftWaitingForRoom(Self.tag)))
        #expect(s.stories[Self.tag]?.rewarded == false)
        s.carton.removeAll()
        let night = Self.play(until: 11, &s, &rng)
        #expect(night.contains(.storyGiftEgg(Self.tag, s.starterBreed)))
        #expect(s.stories[Self.tag]?.rewarded == true)
    }

    // MARK: - Tuning

    /// Rule 3: her day, her stay, her age and her price come from the game's own rules.
    @Test func theGamesRulesTuneHerStory() throws {
        var rules = calmRules()
        rules.jobsPerDay = 0
        rules.seasonGoals = false
        rules.featureDays[.coopDoor] = 5
        rules.marigoldStayDays = 3
        rules.marigoldAgeDays = 200
        rules.marigoldPrice = 25
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(rules: rules, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        Self.play(until: 4, &s, &rng)
        #expect(Self.marigold(s) == nil)
        let day5 = Self.play(until: 5, &s, &rng)
        let hen = try #require(Self.marigold(s))
        #expect(day5.contains(.loanArrived(hen.id, from: .hazel)) && day5.contains(.introduced(.coopDoor)))
        #expect(hen.age(onDay: s.day) == 200)
        #expect(s.hazelHomeDay == 8)
        Self.play(until: 7, &s, &rng)
        #expect(s.pendingChoices.isEmpty)
        Self.play(until: 8, &s, &rng)
        #expect(s.pendingChoices.map(\.choice) == [Self.tag])
        let ev = Engine.apply(.choose(story: Self.tag, option: "keep"), to: &s, using: &rng)
        #expect(ev.contains(.debtOwed(Self.tag, to: .hazel, coins: 25)))
    }

    /// Hazel's egg is of Marigold's breed, even when the starter has gone (traded away).
    @Test func theGiftEggIsMarigoldsBreedEvenWithoutTheStarter() throws {
        for index in 0..<3 {
            var (s, rng) = Self.newKeeper(index: index)
            Self.play(until: 10, &s, &rng)
            let hen = try #require(Self.marigold(s))
            s.starterID = nil  // as after a trade
            _ = Engine.apply(.choose(story: Self.tag, option: "return"), to: &s, using: &rng)
            let egg = try #require(s.carton.last)
            #expect(egg.motherBreed == hen.breed && s.lentBreeds[Self.tag] == hen.breed)
        }
    }

    // MARK: - The fox

    @Test func aScaredMarigoldComesHomeAndStillGoesHomeToHazel() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 3, &s, &rng)
        let hen = try #require(Self.marigold(s))
        s.rules.foxChance = 1
        s.rules.fleeChance = 1
        _ = Engine.apply(.feed, to: &s, using: &rng)
        let night = sleepTonight(&s, &rng)  // the door is left open
        #expect(night.contains(.foxVisited(scared: [hen.id])))
        #expect(s.lost.contains { $0.bird.id == hen.id })
        #expect(Self.marigold(s) != nil)  // still on loan while away
        s.rules.foxChance = 0
        let back = Self.play(until: s.lost.first!.returnsOnDay, &s, &rng)
        #expect(back.contains(.birdReturned(hen.id)))
        #expect(s.coop.contains { $0.id == hen.id && $0.loan?.tag == Self.tag })

        // Scared again on day 10: sending her home works while she is away too.
        Self.play(until: 10, &s, &rng)
        let i = try #require(s.coop.firstIndex { $0.id == hen.id })
        let away = s.coop.remove(at: i)
        s.lost.append(LostBird(bird: away, returnsOnDay: s.day + 3))
        let ev = Engine.apply(.choose(story: Self.tag, option: "return"), to: &s, using: &rng)
        #expect(ev.contains(.loanReturned(hen.id, to: .hazel)))
        #expect(s.lost.isEmpty && s.bird(hen.id) == nil)
    }

    // MARK: - Jobs

    @Test func aCuddleJobNamingMarigoldIsDoneOnceSheHasGone() throws {
        var (s, rng) = Self.newKeeper()
        Self.play(until: 10, &s, &rng)
        let hen = try #require(Self.marigold(s))
        #expect(Engine.namedBirdsCuddled([hen.id], s) == 0)
        _ = Engine.apply(.choose(story: Self.tag, option: "return"), to: &s, using: &rng)
        #expect(Engine.namedBirdsCuddled([hen.id], s) == 1)
    }

    @Test func jobsCanNameMarigold() throws {
        var rules = Rules.standard
        rules.foxChance = 0
        var rng = SeededRNG(seed: 5)
        var s = Engine.newGame(rules: rules, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Basil"), to: &s, using: &rng)
        var named = false
        while s.day < 10 {
            Self.play(until: s.day + 1, &s, &rng)
            guard let hen = Self.marigold(s) else { continue }
            named = named || s.todaysJobs.contains { $0.birdID == hen.id || $0.birdIDs?.contains(hen.id) == true }
        }
        #expect(named)
    }

    // MARK: - The sim

    @Test func theSimSendsHerHome() {
        let s = Simulation.play(seed: 1, days: 15)
        #expect(s.chosen(Self.tag, in: Self.tag) == "return")
        #expect(s.loanedBird(tag: Self.tag) == nil && s.debts.isEmpty)
    }

    // MARK: - Old saves

    @Test func anOldSaveGetsNoRetroactiveLoan() throws {
        var game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(!game.state.earlyGameStories)
        #expect(game.state.stories[Self.tag] == nil)
        for _ in 0..<12 {
            _ = Engine.apply(.feed, to: &game.state, using: &game.rng)
            _ = Engine.apply(.closeCoop, to: &game.state, using: &game.rng)
            _ = sleepTonight(&game.state, &game.rng)
        }
        #expect(game.state.stories[Self.tag] == nil)
        #expect(game.state.loanedBirds.isEmpty && game.state.debts.isEmpty && game.state.pendingChoices.isEmpty)
    }

    @Test func aSaveFromBeforeThisVersionGetsNoLoanEither() throws {
        let (s, rng) = Self.newKeeper()
        #expect(s.earlyGameStories)
        let data = try SaveFormat.encode(SaveGame(state: s, rng: rng))
        var root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var state = try #require(root["state"] as? [String: Any])
        state["earlyGameStories"] = nil
        root["state"] = state
        var game = try SaveFormat.decode(JSONSerialization.data(withJSONObject: root))
        #expect(!game.state.earlyGameStories)
        Self.play(until: 11, &game.state, &game.rng)
        #expect(game.state.stories[Self.tag] == nil && game.state.loanedBirds.isEmpty)
        // A game without the early game has no Marigold.
        var t = startedGame(sex: .hen).0
        var trng = SeededRNG(seed: 2)
        Self.play(until: 11, &t, &trng)
        #expect(t.stories[Self.tag] == nil)
    }
}
