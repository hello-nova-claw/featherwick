import Foundation
import Testing
@testable import FeatherwickCore

/// A game that has started with a known starter chick (an Orpington of the given sex).
func startedGame(sex: Sex, rules: Rules = .standard, seed: UInt64 = 1) -> (GameState, SeededRNG) {
    var rng = SeededRNG(seed: seed)
    var s = Engine.newGame(rules: rules, using: &rng)
    let chick = Bird(id: makeID(using: &rng), name: "", breed: .orpington,
                     genome: Breed.orpington.purebred(sex), hatchDay: 0, origin: "Neighbour")
    s.phase = .choosingStarter([chick])
    _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
    return (s, rng)
}

/// Feed (if possible), close the coop if asked, and pass the night. Returns the night's events.
@discardableResult
func night(_ s: inout GameState, _ rng: inout SeededRNG, feed: Bool = true, close: Bool = true) -> [GameEvent] {
    if feed { _ = Engine.apply(.feed, to: &s, using: &rng) }
    if close { _ = Engine.apply(.closeCoop, to: &s, using: &rng) }
    return Engine.apply(.passNight, to: &s, using: &rng)
}

func calmRules() -> Rules {
    var r = Rules.standard
    r.foxChance = 0
    r.layChance = [.spring: 1, .summer: 1, .autumn: 1, .winter: 1]
    return r
}

struct EngineTests {
    // MARK: - Starting

    @Test func newGameOffersOneChickPerStarterBreed() {
        var rng = SeededRNG(seed: 9)
        let s = Engine.newGame(using: &rng)
        guard case .choosingStarter(let chicks) = s.phase else { Issue.record("not choosing"); return }
        #expect(Set(chicks.map(\.breed)) == Set(Breed.starters))
        #expect(chicks.allSatisfy { !$0.revealed && $0.hatchDay == 0 })
        #expect(!chicks.contains { $0.breed == .silkie })
    }

    @Test func commandsWaitForTheStarterChoice() {
        var rng = SeededRNG(seed: 9)
        var s = Engine.newGame(using: &rng)
        #expect(Engine.apply(.feed, to: &s, using: &rng) == [.rejected(.chooseStarterFirst)])
        #expect(Engine.apply(.chooseStarter(index: 5, name: "x"), to: &s, using: &rng) == [.rejected(.noSuchChick)])
        let ev = Engine.apply(.chooseStarter(index: 1, name: "Pip"), to: &s, using: &rng)
        guard case .starterChosen = ev.first else { Issue.record("no starter"); return }
        #expect(s.brooder.count == 1 && s.brooder[0].name == "Pip")
    }

    @Test func starterMovesToCoopAndIsRevealedAtGrowerAge() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        for _ in 0..<(s.rules.growerAge - 1) { night(&s, &rng) }
        #expect(s.brooder.count == 1 && !s.brooder[0].revealed)
        let ev = night(&s, &rng)
        #expect(s.coop.count == 1 && s.coop[0].revealed)
        #expect(ev.contains(.revealed(s.coop[0].id, sex: .hen, breed: .orpington)))
        #expect(s.breedBook.count == 1)
    }

    @Test func roosterStarterGetsOneYoungerGiftHen() {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        var all: [GameEvent] = []
        for _ in 0..<s.rules.growerAge { all += night(&s, &rng) }
        let gifts = all.compactMap { if case .neighbourGaveHen(let id) = $0 { id } else { nil } }
        #expect(gifts.count == 1)
        let hen = s.bird(gifts[0])!
        #expect(hen.sex == .hen && hen.revealed)
        #expect(hen.age(onDay: s.day) == s.rules.giftHenAge)
        for _ in 0..<10 { all += night(&s, &rng) }
        #expect(all.filter { if case .neighbourGaveHen = $0 { true } else { false } }.count == 1)
    }

    @Test func henStarterGetsNoGift() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        for _ in 0..<15 { night(&s, &rng) }
        #expect(!s.giftHenGiven)
        #expect(s.birdsAtHome.count == 1)
    }

    // MARK: - Laying and eggs

    @Test func hensLayOnlyWhenFed() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        while s.day < s.rules.adultAge - 1 { night(&s, &rng) }
        let fed = night(&s, &rng)
        #expect(fed.contains { if case .eggLaid = $0 { true } else { false } })
        let hungry = night(&s, &rng, feed: false)
        #expect(hungry.contains(.noEggsHungry))
        #expect(!hungry.contains { if case .eggLaid = $0 { true } else { false } })
    }

    @Test func cartonHoldsTwelve() {
        var (s, rng) = startedGame(sex: .hen)
        let mother = s.brooder[0].id
        s.nest = (0..<15).map { _ in Egg(id: makeID(using: &rng), layDay: 0, motherID: mother, colour: .brown, speckled: false) }
        #expect(Engine.apply(.collectEggs, to: &s, using: &rng) == [.eggsCollected(count: 12, leftInNest: 3)])
        #expect(Engine.apply(.collectEggs, to: &s, using: &rng) == [.rejected(.cartonFull)])
        let coins = s.coins
        #expect(Engine.apply(.sellEggs, to: &s, using: &rng) == [.eggsSold(count: 12, coins: 12 * s.rules.brownEggPrice, stale: 0)])
        #expect(s.coins == coins + 12 * s.rules.brownEggPrice)
    }

    @Test func eggPricesAndStaleness() {
        let r = Rules.standard
        let id = UUID()
        let olive = Egg(id: id, layDay: 0, motherID: id, colour: .olive, speckled: true, collectedDay: 1)
        #expect(r.price(of: olive, onDay: 9) == r.oliveEggPrice + r.speckleBonus)
        // Freshness counts days in the nest, not days in the carton.
        let staleOlive = Egg(id: id, layDay: 0, motherID: id, colour: .olive, speckled: true, collectedDay: 5)
        #expect(r.price(of: staleOlive, onDay: 5) == (r.oliveEggPrice + r.speckleBonus) / 2)
        let staleCream = Egg(id: id, layDay: 0, motherID: id, colour: .cream, speckled: false, collectedDay: 9)
        #expect(r.price(of: staleCream, onDay: 9) == 1)  // never below 1 coin
    }

    @Test func fullNestBoxesMeanFloorEggs() {
        var r = calmRules()
        r.floorEggBreakChance = 1
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge - 1 { night(&s, &rng) }
        let mother = s.coop[0].id
        s.nest = (0..<s.nestCapacity).map { _ in Egg(id: makeID(using: &rng), layDay: s.day, motherID: mother, colour: .brown, speckled: false) }
        s.rules.broodyChance = [:]
        let ev = night(&s, &rng)
        #expect(ev.contains(.eggBroken(by: mother)))
        #expect(s.nest.count == s.nestCapacity)
    }

    @Test func pileOfEggsCanSetAHenBroody() {
        var r = calmRules()
        r.broodyChance = [.orpington: 1]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge - 1 { night(&s, &rng) }
        let hen = s.coop[0].id
        s.nest = (0..<r.broodyNestEggs).map { _ in Egg(id: makeID(using: &rng), layDay: s.day, motherID: hen, colour: .brown, speckled: false) }
        #expect(night(&s, &rng).contains(.wentBroody(hen)))
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        var laidWhileBroody = false
        var ended = false
        for _ in 0..<r.broodyDays {
            let ev = night(&s, &rng)
            if ev.contains(.broodyEnded(hen)) { ended = true; break }
            if ev.contains(where: { if case .eggLaid = $0 { true } else { false } }) { laidWhileBroody = true }
        }
        #expect(!laidWhileBroody)
        #expect(ended)
    }

    @Test func hensKeepLayingWithEggsInTheNest() {
        var (s, rng) = startedGame(sex: .hen, rules: { var r = calmRules(); r.broodyChance = [:]; return r }())
        while s.day < s.rules.adultAge { night(&s, &rng) }
        for _ in 0..<3 { night(&s, &rng) }
        #expect(s.nest.count == 4)  // one egg a day, nothing collected
    }

    // MARK: - Fox

    @Test func foxScaresABirdThatComesHomeLater() {
        var r = calmRules()
        r.lostDaysMin = 2
        r.lostDaysMax = 2
        var (s, rng) = startedGame(sex: .hen, rules: r)
        for _ in 0..<r.growerAge { night(&s, &rng) }
        #expect(s.coop.count == 1)
        s.rules.foxChance = 1
        let id = s.coop[0].id
        let foxNight = night(&s, &rng, close: false)
        #expect(foxNight.contains(.foxVisited(scared: [id])))
        #expect(s.coop.isEmpty && s.lost.count == 1)
        let returnDay = s.lost[0].returnsOnDay
        #expect(returnDay == s.day + 2)
        night(&s, &rng)
        #expect(s.lost.count == 1)
        let back = night(&s, &rng)
        #expect(s.day == returnDay && back.contains(.birdReturned(id)))
        #expect(s.coop[0].timesScared == 1)
        #expect(s.coop[0].noLayUntilDay == s.day + r.scaredNoLayDays)
    }

    @Test func closedCoopIsSafe() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        for _ in 0..<s.rules.growerAge { night(&s, &rng) }
        s.rules.foxChance = 1
        for _ in 0..<10 { night(&s, &rng, close: true) }
        #expect(s.lost.isEmpty && s.coop.count == 1)
    }

    @Test func lostBirdWaitsForAFreePerch() {
        var r = calmRules()
        r.startPerches = 1
        r.lostDaysMin = 1
        r.lostDaysMax = 1
        var (s, rng) = startedGame(sex: .hen, rules: r)
        for _ in 0..<r.growerAge { night(&s, &rng) }
        s.rules.foxChance = 1
        let id = s.coop[0].id
        night(&s, &rng, close: false)
        s.rules.foxChance = 0
        // The player fills the empty perch with another bird.
        let other = Bird(id: makeID(using: &rng), name: "Other", breed: .araucana,
                         genome: Breed.araucana.purebred(.hen), hatchDay: 0, origin: "Test", revealed: true)
        s.coop.append(other)
        for _ in 0..<5 {
            let ev = night(&s, &rng)
            #expect(ev.contains(.birdWaitingForPerch(id)))
        }
        s.coop.removeAll { $0.id == other.id }
        #expect(night(&s, &rng).contains(.birdReturned(id)))
    }

    @Test func lostTimeDoublesWithEachScareUpToTheCap() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 3)
        for scares in 0...6 {
            for _ in 0..<200 {
                let d = Engine.lostDays(timesScared: scares, rules: r, &rng)
                let low = min(r.lostDaysMin << scares, r.lostDaysCap)
                let high = min(r.lostDaysMax << scares, r.lostDaysCap)
                #expect((low...high).contains(d))
            }
        }
    }

    // MARK: - Saves and determinism

    @Test func saveRoundTrip() throws {
        var (s, rng) = startedGame(sex: .rooster, rules: calmRules())
        for _ in 0..<25 { night(&s, &rng) }
        let data = try JSONEncoder().encode(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(loaded == s)
    }

    @Test func sameSeedSameGame() {
        func play() -> [GameEvent] {
            var rng = SeededRNG(seed: 77)
            var s = Engine.newGame(using: &rng)
            var ev = Engine.apply(.chooseStarter(index: 0, name: "A"), to: &s, using: &rng)
            for i in 0..<40 { ev += night(&s, &rng, close: i % 3 != 0) }
            return ev
        }
        #expect(play() == play())
    }
}
