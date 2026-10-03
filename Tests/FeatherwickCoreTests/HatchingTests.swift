import Foundation
import Testing
@testable import FeatherwickCore

func adult(_ breed: Breed, _ sex: Sex, day: Int, rules: Rules, rng: inout SeededRNG) -> Bird {
    Bird(id: makeID(using: &rng), name: "\(breed.rawValue) \(sex.rawValue)", breed: breed,
         genome: breed.purebred(sex), hatchDay: day - rules.adultAge, origin: "Test", revealed: true)
}

func fertileEgg(mother: Bird, father: Bird, day: Int, rng: inout SeededRNG) -> Egg {
    var e = Egg(id: makeID(using: &rng), layDay: day, motherID: mother.id, colour: .blue, speckled: false,
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
        #expect(all.filter { if case .neighbourGaveIncubator = $0 { true } else { false } }.count == 1)
        #expect(s.incubatorSize == r.giftIncubatorSize)

        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        #expect(Engine.apply(.incubate(count: 2), to: &s, using: &rng) == [.rejected(.clutchTooBig(max: 1))])
        let one = Engine.apply(.incubate(count: 1), to: &s, using: &rng)
        #expect(one.contains { if case .eggsSet(1, nil, _) = $0 { true } else { false } })

        // Buying the big incubator upgrades it (not while eggs are inside).
        s.coins = 100
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.rejected(.incubatorBusy)])
        night(&s, &rng)
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.incubatorBought(cost: r.incubatorPrice, size: r.bigIncubatorSize)])
        #expect(Engine.apply(.buyIncubator, to: &s, using: &rng) == [.rejected(.alreadyHaveIncubator)])
    }

    @Test func noRoosterNoFertileEggs() {
        var r = calmRules()
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge + 5 { night(&s, &rng) }
        #expect(!s.nest.isEmpty && s.nest.allSatisfy { !$0.isFertile })
    }

    @Test func incubatorCandlesAndHatchesOvernightIntoTheBrooder() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        let hen = adult(.araucana, .hen, day: 0, rules: s.rules, rng: &rng)
        let rooster = adult(.orpington, .rooster, day: 0, rules: s.rules, rng: &rng)
        s.carton = [fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
                    clearEgg(mother: hen, day: 0, rng: &rng),
                    fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng)]
        #expect(Engine.apply(.incubate(count: 3), to: &s, using: &rng) == [.rejected(.noIncubator)])
        s.coins = 100
        _ = Engine.apply(.buyIncubator, to: &s, using: &rng)
        let ev = Engine.apply(.incubate(count: 3), to: &s, using: &rng)
        #expect(ev.first == .candled(fertile: 2, clear: 1))
        #expect(s.carton.count == 1 && !s.carton[0].isFertile)
        let embryos = s.incubatorClutch!.eggs.map(\.embryo)
        let hatched = night(&s, &rng)
        #expect(hatched.contains { if case .chicksHatched(let ids, nil) = $0 { ids.count == 2 } else { false } })
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
        s.carton = [fertileEgg(mother: hen, father: rooster, day: 0, rng: &rng),
                    clearEgg(mother: hen, day: 0, rng: &rng),
                    clearEgg(mother: hen, day: 0, rng: &rng)]
        #expect(Engine.apply(.candle, to: &s, using: &rng) == [.candled(fertile: 1, clear: 2)])
        #expect(Engine.apply(.candle, to: &s, using: &rng) == [.rejected(.nothingToCandle)])
        let ev = Engine.apply(.sellClearEggs, to: &s, using: &rng)
        guard case .eggsSold(let n, _, _) = ev.first else { Issue.record("not sold"); return }
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
        // Already candled, so no new candling event, just the set.
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.eggsSet(count: 1, hen: nil, hatchDay: s.day + 1)])
        #expect(s.carton == [clear])
    }

    @Test func renameAnyBird() {
        var (s, rng) = startedGame(sex: .hen)
        let id = s.brooder[0].id
        #expect(Engine.apply(.rename(id, name: "Marigold"), to: &s, using: &rng) == [.renamed(id)])
        #expect(s.brooder[0].name == "Marigold")
    }
}
