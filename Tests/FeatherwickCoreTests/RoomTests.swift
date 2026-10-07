import Foundation
import Testing

@testable import FeatherwickCore

struct RoomTests {
    /// A full coop (1 perch), a 1-spot brooder, and a broody hen with 3 fertile eggs.
    func crowdedGame() -> (GameState, SeededRNG, henID: UUID) {
        var r = calmRules()
        r.startPerches = 1
        r.startBrooderSize = 1
        r.broodyChance = [:]
        var (s, rng) = startedGame(sex: .hen, rules: r)
        while s.day < r.adultAge { night(&s, &rng) }
        _ = Engine.apply(.collectEggs, to: &s, using: &rng)
        s.carton.removeAll()
        let henID = s.coop[0].id
        s.coop[0].broodyUntilDay = s.day + r.broodyDays
        let rooster = adult(.wyandotte, .rooster, day: s.day, rules: r, rng: &rng)
        s.carton = (0..<3).map { _ in fertileEgg(mother: s.coop[0], father: rooster, day: s.day, rng: &rng) }
        _ = Engine.apply(.sit(hen: henID, count: 3), to: &s, using: &rng)
        return (s, rng, henID)
    }

    @Test func grownChicksWaitInTheBrooderThenBoardWithTheNeighbour() {
        var (s, rng, _) = crowdedGame()
        var ev: [GameEvent] = []
        for _ in 0..<(s.rules.broodyHatchDays + s.rules.brooderDays) { ev = night(&s, &rng) }
        // The last night: 3 grown chicks, 0 free perches, 1 brooder spot.
        #expect(s.henChicks.isEmpty)
        #expect(s.brooder.count == 1)
        #expect(s.boarding.count == 2)
        #expect(ev.contains { if case .needsHome = $0 { true } else { false } })
        #expect(ev.count(where: { if case .boardingWithNeighbour = $0 { true } else { false } }) == 2)
    }

    @Test func boardingBirdsPauseHatching() {
        var (s, rng, henID) = crowdedGame()
        for _ in 0..<(s.rules.broodyHatchDays + s.rules.brooderDays) { night(&s, &rng) }
        s.incubatorSize = 6
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.rejected(.birdsBoarding)])
        let i = s.coop.firstIndex { $0.id == henID }!
        s.coop[i].broodyUntilDay = s.day + 5
        #expect(Engine.apply(.sit(hen: henID, count: 1), to: &s, using: &rng) == [.rejected(.birdsBoarding)])
    }

    @Test func aFullBrooderBlocksIncubatingAndSitting() {
        var (s, rng, henID) = crowdedGame()
        for _ in 0..<(s.rules.broodyHatchDays + s.rules.brooderDays) { night(&s, &rng) }
        s.boarding.removeAll()  // only the full brooder is in the way now
        #expect(s.brooder.count == s.brooderSize)
        s.incubatorSize = 6
        #expect(Engine.apply(.incubate(count: 1), to: &s, using: &rng) == [.rejected(.brooderFull(room: 0))])
        let i = s.coop.firstIndex { $0.id == henID }!
        s.coop[i].broodyUntilDay = s.day + 5
        #expect(Engine.apply(.sit(hen: henID, count: 1), to: &s, using: &rng) == [.rejected(.brooderFull(room: 0))])
    }

    @Test func rehomingFreesAPerchAndBoardersComeHomeFirst() {
        var (s, rng, henID) = crowdedGame()
        for _ in 0..<(s.rules.broodyHatchDays + s.rules.brooderDays) { night(&s, &rng) }
        let firstBoarder = s.boarding[0].id
        let coins = s.coins
        let ev = Engine.apply(.rehome(henID), to: &s, using: &rng)
        guard case .rehomed(henID, let paid) = ev.first else {
            Issue.record("not rehomed")
            return
        }
        #expect(s.coins == coins + paid)
        #expect(s.rehomed.map(\.id) == [henID])
        let morning = night(&s, &rng)
        #expect(morning.contains(.cameHomeFromBoarding(firstBoarder)))
        #expect(s.coop.map(\.id) == [firstBoarder])
        #expect(s.boarding.count == 1)
    }

    @Test func aBusyMotherCannotBeRehomed() {
        var (s, rng, henID) = crowdedGame()
        #expect(Engine.apply(.rehome(henID), to: &s, using: &rng) == [.rejected(.birdIsBusy)])  // sitting
        for _ in 0..<s.rules.broodyHatchDays { night(&s, &rng) }
        #expect(Engine.apply(.rehome(henID), to: &s, using: &rng) == [.rejected(.birdIsBusy)])  // chicks
    }

    @Test func upgradeCoopAddsPerches() {
        var (s, rng) = startedGame(sex: .hen)
        s.coins = 0
        #expect(Engine.apply(.upgradeCoop, to: &s, using: &rng) == [.rejected(.notEnoughCoins(needed: 30, have: 0))])
        s.coins = 100
        #expect(
            Engine.apply(.upgradeCoop, to: &s, using: &rng) == [
                .coopUpgraded(perches: 5, cost: 30), .slotSpent(.building, left: 3),
            ])
        #expect(s.coins == 70)
        s.perches = s.rules.maxPerches
        #expect(Engine.apply(.upgradeCoop, to: &s, using: &rng) == [.rejected(.coopAtMax)])
    }

    @Test func rarerBirdsAreWorthMore() {
        let r = Rules.standard
        var rng = SeededRNG(seed: 4)
        let plain = Bird(
            id: makeID(using: &rng), name: "a", breed: .orpington,
            genome: Breed.orpington.purebred(.hen), hatchDay: 0, origin: "t")
        #expect(r.rehomeValue(of: plain, onDay: 0) == 2)  // black orpington chick

        let lavenderAraucana = Bird(
            id: makeID(using: &rng), name: "b", breed: .araucana,
            genome: Breed.araucana.purebred(.hen, colour: .lavender), hatchDay: 0, origin: "t",
            revealed: true)
        #expect(r.rehomeValue(of: lavenderAraucana, onDay: r.adultAge) == 6 + 6 + 2)  // adult + lavender + blue eggs

        var oliveGenome = Breed.araucana.purebred(.hen)
        oliveGenome.brownShell = AllelePair(.brown, .noCoating)
        let oliveHen = Bird(
            id: makeID(using: &rng), name: "c", breed: .araucana,
            genome: oliveGenome, hatchDay: 0, origin: "t", revealed: true)
        #expect(r.rehomeValue(of: oliveHen, onDay: r.adultAge) == 6 + 5)
        // Hidden genes never raise the price: not in an unrevealed chick, not in a rooster's egg genes.
        let hiddenLavender = Bird(
            id: makeID(using: &rng), name: "d", breed: .orpington,
            genome: Breed.orpington.purebred(.hen, colour: .lavender), hatchDay: 0, origin: "t")
        #expect(r.rehomeValue(of: hiddenLavender, onDay: 0) == 2)
        var oliveRoosterGenome = Breed.araucana.purebred(.rooster)
        oliveRoosterGenome.brownShell = AllelePair(.brown, .noCoating)
        let oliveRooster = Bird(
            id: makeID(using: &rng), name: "e", breed: .araucana,
            genome: oliveRoosterGenome, hatchDay: 0, origin: "t", revealed: true)
        #expect(r.rehomeValue(of: oliveRooster, onDay: r.adultAge) == 6)
    }
}
