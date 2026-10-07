import Foundation
import Testing

@testable import FeatherwickCore

func adult(_ breed: Breed, _ sex: Sex, day: Int, rules: Rules, rng: inout SeededRNG) -> Bird {
    Bird(
        id: makeID(using: &rng), name: "\(breed.rawValue) \(sex.rawValue)", breed: breed,
        genome: breed.purebred(sex), hatchDay: day - rules.adultAge, origin: "Test", revealed: true)
}

func fertileEgg(mother: Bird, father: Bird, day: Int, rng: inout SeededRNG) -> Egg {
    var e = Egg(
        id: makeID(using: &rng), layDay: day, motherID: mother.id, colour: .blue, speckled: false,
        collectedDay: day, motherBreed: mother.breed)
    e.fatherID = father.id
    e.embryo = try! Breeding.cross(mother: mother.genome, father: father.genome, using: &rng)
    return e
}

func clearEgg(mother: Bird, day: Int, rng: inout SeededRNG) -> Egg {
    Egg(id: makeID(using: &rng), layDay: day, motherID: mother.id, colour: .blue, speckled: false, collectedDay: day)
}

struct HatchingTests {
    @Test func roosterInTheCoopMakesFertileEggs() {
        var r = calmRules()
        r.fertileChance = 1
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge - 1 { night(&s, &rng) }
        let rooster = adult(.araucana, .rooster, day: s.day, rules: r, rng: &rng)
        s.coop.append(rooster)
        night(&s, &rng)
        #expect(s.nest.count == 1)
        #expect(s.nest[0].isFertile && s.nest[0].fatherID == rooster.id)
        #expect(s.nest[0].motherBreed == .orpington)
    }

    @Test func firstFertileEggBringsTheNeighboursOneEggIncubatorOnce() {
        var r = calmRules()
        r.fertileChance = 1
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge - 1 { night(&s, &rng) }
        #expect(!s.hasIncubator)
        s.coop.append(adult(.araucana, .rooster, day: s.day, rules: r, rng: &rng))
        var all: [GameEvent] = []
        for _ in 0..<3 { all += night(&s, &rng) }
        #expect(all.count(where: { if case .neighbourGaveIncubator = $0 { true } else { false } }) == 1)
        #expect(all.contains(.neighbourGaveIncubator(size: r.giftIncubatorSize, ownRooster: true)))
        #expect(s.incubatorSize == r.giftIncubatorSize)

        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        #expect(Engine.apply(.incubate(count: 2), to: &s, using: &rng) == [.rejected(.clutchTooBig(max: 1))])
        let one = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        #expect(one.contains { if case .eggsSet(1, nil, _) = $0 { true } else { false } })

        // Buying the big incubator upgrades it (not while eggs are inside).
        s.coins = 100
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.rejected(.incubatorBusy)])
        night(&s, &rng)
        #expect(
            Engine.apply(.buyIncubator, to: &s, using: &rng) == [
                .incubatorBought(cost: r.incubatorPrice, size: r.bigIncubatorSize), .slotSpent(.village, left: 2),
            ])
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.rejected(.alreadyHaveIncubator)])
    }

    /// A keeper who buys a fertile egg and has no incubator gets the neighbour's old one at once (once).
    @Test func aBoughtFertileEggBringsTheNeighboursIncubator() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        let price = s.rules.fertileEggPrice
        let gift = GameEvent.neighbourGaveIncubator(size: s.rules.giftIncubatorSize, ownRooster: false)
        #expect(
            Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [
                .boughtEgg(cost: price), gift, .slotSpent(.village, left: 2),
            ])
        #expect(s.incubatorSize == s.rules.giftIncubatorSize && s.incubatorGiftGiven)
        // Once: a second egg brings nothing more, and nor do the nights.
        #expect(Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [.boughtEgg(cost: price)])
        let set = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        #expect(set.contains { if case .eggsSet(1, nil, _) = $0 { true } else { false } })
        let ev = night(&s, &rng)
        #expect(!ev.contains { if case .neighbourGaveIncubator = $0 { true } else { false } })
        #expect(ev.contains { if case .chicksHatched(let ids, nil) = $0 { ids.count == 1 } else { false } })
    }

    /// With the standard rules, an egg in the gift incubator hatches on the third night.
    @Test func theGiftIncubatorHatchesInThreeNights() {
        var rng = SeededRNG(seed: 2)
        var r = Rules.standard
        r.foxChance = 0
        var s = Engine.newGame(rules: r, earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        #expect(r.incubatorHatchDays == 3)
        s.coins = 100
        _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
        #expect(s.hasIncubator)
        let set = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        #expect(set.contains(.eggsSet(count: 1, hen: nil, hatchDay: s.day + 3)))
        func hatched(_ ev: [GameEvent]) -> Bool { ev.contains { if case .chicksHatched = $0 { true } else { false } } }
        #expect(!hatched(night(&s, &rng)))
        #expect(!hatched(night(&s, &rng)))
        #expect(hatched(night(&s, &rng)))
    }

    /// A save from before the gift came with bought eggs: a fertile egg waits in the carton and there is
    /// no incubator. The neighbour brings hers the next night.
    @Test func aFertileEggWaitingInTheCartonBringsTheIncubatorNextNight() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        var egg = fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)
        egg.candled = true
        s.carton = [egg]
        let ev = night(&s, &rng)
        #expect(ev.filter { if case .neighbourGaveIncubator = $0 { true } else { false } }.count == 1)
        #expect(ev.contains(.neighbourGaveIncubator(size: s.rules.giftIncubatorSize, ownRooster: false)))
        #expect(s.incubatorSize == s.rules.giftIncubatorSize)
        #expect(!night(&s, &rng).contains { if case .neighbourGaveIncubator = $0 { true } else { false } })
    }

    /// A keeper who already has an incubator gets no gift for a bought egg.
    @Test func noGiftIncubatorWhenTheKeeperHasOne() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 100
        s.incubatorSize = s.rules.bigIncubatorSize
        #expect(
            Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) == [
                .boughtEgg(cost: s.rules.fertileEggPrice), .slotSpent(.village, left: 2),
            ])
        #expect(s.incubatorSize == s.rules.bigIncubatorSize)
    }

    @Test func noRoosterNoFertileEggs() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge + 5 { night(&s, &rng) }
        #expect(!s.nest.isEmpty && s.nest.allSatisfy { !$0.isFertile })
    }

    /// Setting never candles: the clear egg goes in too, and comes back known clear on hatch day.
    @Test func incubatorHatchesFertileEggsIntoTheBrooderAndReturnsTheClearOne() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        s.carton = [
            fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
            clearEgg(mother: hen, day: 0, rng: &rng),
            fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
        ]
        #expect(Engine.apply(.incubate(count: 3), to: &s, using: &rng) == [.rejected(.noIncubator)])
        s.coins = 100
        _ = Engine.apply(.buyIncubator, to: &s, using: &rng)
        let clearID = s.carton[1].id
        let ev = Engine.apply(.incubate(count: 3), to: &s, using: &rng)
        #expect(ev == [.eggsSet(count: 3, hen: nil, hatchDay: s.day + s.rules.incubatorHatchDays)])
        #expect(s.carton.isEmpty && s.incubatorClutch?.eggs.count == 3)
        let embryos = s.incubatorClutch!.eggs.map(\.embryo)
        let hatched = night(&s, &rng)
        #expect(hatched.contains { if case .chicksHatched(let ids, .none) = $0 { ids.count == 2 } else { false } })
        #expect(hatched.contains(.eggsDidNotHatch(count: 1, hen: nil)))
        #expect(s.carton.map { $0.id } == [clearID] && s.carton[0].isCandled)
        let chicks = s.brooder.filter { $0.origin == "Henhaven" }
        #expect(chicks.count == 2)
        #expect(chicks.map(\.genome) == embryos.compactMap { $0 })
        #expect(chicks.allSatisfy { $0.motherID == hen.id && $0.fatherID == rooster.id && $0.breed == .araucana })
        #expect(s.incubatorClutch == nil)
    }

    @Test func incubatorNeedsBrooderRoom() {
        var r = calmRules()
        r.startBrooderSize = 2
        var (s, rng) = startedGame(sex: .hen, rules: r)  // starter takes one brooder spot
        let hen = adult(.araucana, .hen, day: 0, rules: r, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: r, rng: &rng)
        s.carton = (0..<3).map { _ in fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng) }
        s.incubatorSize = 6
        #expect(Engine.apply(.incubate(count: 3), to: &s, using: &rng) == [.rejected(.brooderFull(room: 1))])
        #expect(s.carton.count == 3)
    }

    @Test func onlyABroodyHenWillSit() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge { night(&s, &rng) }
        let henID = s.coop[0].id
        let rooster = adult(.orpington, .rooster, day: s.day, rules: r, rng: &rng)
        s.carton = [fertileEgg(mother: s.coop[0], father: rooster, day: s.day, rng: &rng)]
        #expect(Engine.apply(.sit(hen: henID, count: 1), to: &s, using: &rng) == [.rejected(.notBroody)])
    }

    @Test func broodyHenHatchesInThreeDaysAndRaisesHerChicks() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge { night(&s, &rng) }
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        s.carton.removeAll()
        let henID = s.coop[0].id
        s.coop[0].broodyUntilDay = s.day + r.broodyDays
        let rooster = adult(.wyandotte, .rooster, day: s.day, rules: r, rng: &rng)
        s.carton = (0..<2).map { _ in fertileEgg(mother: s.coop[0], father: rooster, day: s.day, rng: &rng) }
        let set = Engine.apply(.sit(hen: henID, count: 2), to: &s, using: &rng)
        #expect(set.contains(.eggsSet(count: 2, hen: henID, hatchDay: s.day + r.broodyHatchDays)))

        var all: [GameEvent] = []
        for _ in 0..<r.broodyHatchDays { all += night(&s, &rng) }
        #expect(all.contains { if case .chicksHatched(let ids, henID) = $0 { ids.count == 2 } else { false } })
        #expect(!all.contains { if case .eggLaid = $0 { true } else { false } })  // sitting hens don't lay
        #expect(s.henChicks.count == 2 && s.brooder.isEmpty)

        // Mother and chicks are safe from the fox while she mothers.
        s.rules.foxChance = 1
        night(&s, &rng, close: false)
        #expect(s.lost.isEmpty)
        s.rules.foxChance = 0

        // After the brooder period the chicks move to the coop and the hen is herself again.
        var later: [GameEvent] = []
        for _ in 0..<r.brooderDays { later += night(&s, &rng) }
        #expect(s.henChicks.isEmpty && s.coop.count == 3)
        #expect(later.contains(.broodyEnded(henID)))
    }

    @Test func candleThenSellOnlyClearEggs() {
        var (s, rng) = startedGame(sex: .hen)
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        s.carton = [
            fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
            clearEgg(mother: hen, day: 0, rng: &rng),
            clearEgg(mother: hen, day: 0, rng: &rng),
        ]
        #expect(
            Engine.apply(.candle, to: &s, using: &rng) == [
                .candled(fertile: 1, clear: 2), .slotSpent(.candling, left: 2),
            ])
        #expect(Engine.apply(.candle, to: &s, using: &rng) == [.rejected(.nothingToCandle)])
        let ev = Engine.apply(.sellClearEggs, to: &s, using: &rng)
        guard case .eggsSold(let n, _, _) = ev.first else {
            Issue.record("not sold")
            return
        }
        #expect(n == 2)
        #expect(s.carton.count == 1 && s.carton[0].isFertile)
    }

    @Test func knownFertileEggsAreSetFirstAndKnownClearAreSkipped() {
        var (s, rng) = startedGame(sex: .hen)
        s.incubatorSize = 6
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        var clear = clearEgg(mother: hen, day: 0, rng: &rng)
        clear.candled = true
        var fertile = fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)
        fertile.candled = true
        s.carton = [clear, fertile]
        // Only 1 usable egg: the known-clear one is not offered.
        #expect(Engine.apply(.incubate(count: 2), to: &s, using: &rng) == [.rejected(.notEnoughEggsInCarton(have: 1))])
        // Setting never candles, so the only event is the set.
        #expect(
            Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [
                .eggsSet(count: 1, hen: nil, hatchDay: s.day + 1)
            ])
        #expect(s.carton == [clear])
    }

    @Test func renameAnyBird() {
        var (s, rng) = startedGame(sex: .hen)
        let id = s.brooder[0].id
        #expect(Engine.apply(.rename(id, name: "Marigold"), to: &s, using: &rng) == [.renamed(id)])
        #expect(s.brooder[0].name == "Marigold")
    }
}

struct FosterHenTests {
    /// Real broody hens sit on any hen's eggs. The chicks keep their real mother for the family tree,
    /// and the hen raising them is the one who is busy (and can't be rehomed).
    @Test func aBroodyHenCanRaiseAnotherHensChicks() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = adultHenGame(r)
        let foster = s.coop[0].id
        s.coop[0].broodyUntilDay = s.day + 5
        let layer = plainBird(.araucana, hatchDay: s.day - r.adultAge, rng: &rng)
        let rooster = plainBird(.orpington, .rooster, hatchDay: s.day - r.adultAge, rng: &rng)
        s.coop += [layer, rooster]
        s.carton = [fertileEgg(mother: layer, father: rooster, day: s.day, rng: &rng)]
        _ = Engine.apply(.sit(hen: foster, count: 1), to: &s, using: &rng)
        for _ in 0..<r.broodyHatchDays { night(&s, &rng) }
        #expect(s.henChicks.count == 1)
        #expect(s.henChicks[0].motherID == layer.id)
        #expect(s.henChicks[0].raisedBy == foster)
        #expect(Engine.apply(.rehome(foster), to: &s, using: &rng) == [.rejected(.birdIsBusy)])
        #expect(
            Engine.apply(.rehome(layer.id), to: &s, using: &rng) == [
                .rehomed(layer.id, coins: 8), .slotSpent(.neighbour, left: 2),
            ])
    }
}

/// A new keeper can't candle. Set eggs are a guess; clear ones come back. The first hatch teaches candling.
/// Even after the lesson, setting never candles: an unchecked clear egg still sits the full time.
struct LearningToCandleTests {
    /// A new keeper (no candling) with a 6-egg incubator and room in the brooder, and 1 fertile + 2 clear eggs.
    static func newKeeper() -> (GameState, SeededRNG) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        s.canCandle = false
        s.rules.incubatorHatchDays = Rules.standard.incubatorHatchDays
        s.incubatorSize = 6
        s.brooderSize = 6
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        s.carton = [
            fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
            clearEgg(mother: hen, day: 0, rng: &rng),
            clearEgg(mother: hen, day: 0, rng: &rng),
        ]
        return (s, rng)
    }

    @Test func aNewGameCannotCandle() {
        var rng = SeededRNG(seed: 3)
        #expect(!Engine.newGame(using: &rng).canCandle)
        var (s, rng2) = Self.newKeeper()
        let before = s
        #expect(Engine.apply(.candle, to: &s, using: &rng2) == [.rejected(.cannotCandleYet)])
        #expect(Engine.apply(.candleEgg(s.carton[0].id), to: &s, using: &rng2) == [.rejected(.cannotCandleYet)])
        #expect(s == before)
    }

    @Test func clearEggsAreSetThenComeBackAndTheFirstHatchTeachesCandling() {
        var (s, rng) = Self.newKeeper()
        let clearIDs = Set(s.carton.filter { !$0.isFertile }.map(\.id))
        let hatchDay = s.day + s.rules.incubatorHatchDays
        let set = Engine.apply(.incubate(count: 3), to: &s, using: &rng)
        #expect(set == [.eggsSet(count: 3, hen: nil, hatchDay: hatchDay)])
        #expect(s.carton.isEmpty && s.incubatorClutch?.eggs.count == 3)
        var all: [GameEvent] = []
        while s.day < hatchDay - 1 { all += night(&s, &rng) }
        #expect(s.incubatorClutch != nil && !s.canCandle)  // still warming
        all += night(&s, &rng)
        #expect(all.contains(.eggsDidNotHatch(count: 2, hen: nil)))
        #expect(all.contains(.learnedCandling))
        #expect(all.contains { if case .chicksHatched(let ids, .none) = $0 { ids.count == 1 } else { false } })
        #expect(s.canCandle && s.incubatorClutch == nil)
        // The clear eggs are back in the carton, now known to be clear.
        let back = s.carton.filter { clearIDs.contains($0.id) }
        #expect(back.count == 2 && back.allSatisfy { $0.isCandled && !$0.isFertile })
    }

    /// A keeper who can candle but sets an unchecked clear egg waits out the full hatch time,
    /// then finds it didn't hatch. The fertile egg set with it hatches as usual.
    @Test func anUncheckedClearEggSitsTheFullTimeThenComesBackKnownClear() {
        var (s, rng) = Self.newKeeper()
        s.canCandle = true
        let fertile = s.carton[0].id
        let clear = s.carton[1].id
        let hatchDay = s.day + s.rules.incubatorHatchDays
        let set = Engine.apply(.incubateEggs([fertile, clear]), to: &s, using: &rng)
        #expect(set == [.eggsSet(count: 2, hen: nil, hatchDay: hatchDay)])
        #expect(s.carton.count == 1 && !s.carton.contains { $0.id == clear })
        var early: [GameEvent] = []
        while s.day < hatchDay - 1 { early += night(&s, &rng) }
        // Still warming: the clear egg keeps its place in the incubator until hatch day.
        #expect(s.incubatorClutch?.eggs.count == 2)
        #expect(!early.contains { if case .eggsDidNotHatch = $0 { true } else { false } })
        let last = night(&s, &rng)
        #expect(last.contains(.eggsDidNotHatch(count: 1, hen: nil)))
        #expect(last.contains { if case .chicksHatched(let ids, .none) = $0 { ids.count == 1 } else { false } })
        #expect(s.incubatorClutch == nil)
        #expect(s.carton.contains { $0.id == clear && $0.isCandled && !$0.isFertile })
        #expect(s.brooder.contains { $0.origin == "Henhaven" })
    }

    @Test func aFullCartonSendsUnhatchedEggsToTheNest() {
        var (s, rng) = Self.newKeeper()
        let clear = s.carton.first { !$0.isFertile }!
        _ = Engine.apply(.incubateEggs([clear.id]), to: &s, using: &rng)
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        while s.carton.count < s.cartonCapacity { s.carton.append(clearEgg(mother: hen, day: 0, rng: &rng)) }
        for _ in 0..<s.rules.incubatorHatchDays { night(&s, &rng) }
        #expect(s.nest.contains { $0.id == clear.id && $0.isCandled })
        #expect(!s.canCandle)  // nothing hatched, so no lesson yet
    }

    @Test func candlingOneEggAtATime() {
        var (s, rng) = Self.newKeeper()
        s.canCandle = true
        let fertile = s.carton[0].id
        let clear = s.carton[1].id
        #expect(
            Engine.apply(.candleEgg(fertile), to: &s, using: &rng) == [
                .candled(fertile: 1, clear: 0), .slotSpent(.candling, left: 2),
            ])
        #expect(Engine.apply(.candleEgg(clear), to: &s, using: &rng) == [.candled(fertile: 0, clear: 1)])
        #expect(Engine.apply(.candleEgg(clear), to: &s, using: &rng) == [.rejected(.alreadyCandled)])
        #expect(Engine.apply(.candleEgg(UUID()), to: &s, using: &rng) == [.rejected(.noSuchEgg)])
        #expect(s.carton.filter(\.isCandled).count == 2)
    }
}
