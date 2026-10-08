import Foundation
import Testing

@testable import FeatherwickCore

/// The inheritance page: rules the keeper learns by setting eggs from a penned pair.
@Suite struct InheritanceTests {
    static let shop = "Speckle & Down"

    /// Two blue Orpingtons from the shop in the pen, the planner known, and an incubator.
    static func bluePair() -> (GameState, SeededRNG, hen: Bird, rooster: Bird) {
        var (s, rng) = startedGame(sex: .hen)
        let hen = PlannerTests.add(
            Breed.orpington.purebred(.hen, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        let rooster = PlannerTests.add(
            Breed.orpington.purebred(.rooster, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        s.plannerKnown = true
        s.pen = [hen.id, rooster.id]
        s.incubatorSize = s.rules.bigIncubatorSize
        s.brooderSize = 20
        return (s, rng, hen, rooster)
    }

    static let blueRule = InheritanceRule.colours(
        .blue, .blue, [ColourShare(.black, 1), ColourShare(.blue, 2), ColourShare(.splash, 1)], denominator: 4)

    /// Puts an egg from `mother` in the carton and sets it in the incubator.
    @discardableResult
    static func setEgg(from mother: Bird, father: Bird, _ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        let egg = fertileEgg(mother: mother, father: father, day: s.day, rng: &rng)
        s.carton.append(egg)
        return Engine.apply(.incubateEggs([egg.id]), to: &s, using: &rng)
    }

    @Test func aRuleAppearsOnlyAfterEggsAreSet() {
        var (s, rng, hen, rooster) = Self.bluePair()
        // The forecast pins the shares, but seeing it is not trying it.
        guard case .forecast = Planner.panel(in: s) else {
            Issue.record("no forecast")
            return
        }
        _ = Engine.apply(.openPlanner, to: &s, using: &rng)
        #expect(Inheritance.known(in: s).isEmpty)
        let events = Self.setEgg(from: hen, father: rooster, &s, &rng)
        #expect(events.contains { if case .eggsSet = $0 { true } else { false } })
        #expect(Inheritance.known(in: s) == [Self.blueRule])
    }

    @Test func theSameRuleIsNotRepeated() {
        var (s, rng, hen, rooster) = Self.bluePair()
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        // A second blue pair teaches the same thing.
        let hen2 = PlannerTests.add(
            Breed.orpington.purebred(.hen, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        s.pen.append(hen2.id)
        Self.setEgg(from: hen2, father: rooster, &s, &rng)
        #expect(Inheritance.known(in: s) == [Self.blueRule])
    }

    @Test func rulesKeepTheOrderFirstSeen() {
        var (s, rng, hen, rooster) = Self.bluePair()
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        // A barred hen with a plain rooster: a barring share and a sex-link.
        s.pen = []
        let barred = PlannerTests.add(
            Breed.orpington.purebred(.hen, variety: .barred), .orpington, origin: Self.shop, &s, &rng)
        let plain = PlannerTests.add(Breed.orpington.purebred(.rooster), .orpington, origin: Self.shop, &s, &rng)
        s.pen = [barred.id, plain.id]
        Self.setEgg(from: barred, father: plain, &s, &rng)
        let rules = Inheritance.known(in: s)
        #expect(rules.first == Self.blueRule)
        #expect(rules.contains(.sexLink(barredAre: .rooster)))
        #expect(rules.contains(.trait(.barred, hen: true, rooster: false, numerator: 1, denominator: 2)))
        #expect(rules.contains(.colours(.black, .black, [ColourShare(.black, 1)], denominator: 1)))
        #expect(Set(rules).count == rules.count)
    }

    @Test func eggsFromOutsideThePenTeachNothing() {
        var (s, rng, hen, rooster) = Self.bluePair()
        // A coop hen's egg: not the pen's pair.
        let coopHen = PlannerTests.add(
            Breed.orpington.purebred(.hen, variety: .blue), .orpington, origin: Self.shop, &s, &rng)
        Self.setEgg(from: coopHen, father: rooster, &s, &rng)
        #expect(Inheritance.known(in: s).isEmpty)
        // A penned hen with no rooster in the pen.
        s.pen = [hen.id]
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        #expect(Inheritance.known(in: s).isEmpty)
        // A cockerel in the pen fathers nothing yet.
        let cockerel = PlannerTests.add(
            Breed.orpington.purebred(.rooster, variety: .blue), .orpington, origin: Self.shop, &s, &rng,
            age: s.rules.growerAge)
        s.coop[s.coop.firstIndex { $0.id == cockerel.id }!].revealed = true
        s.pen = [hen.id, cockerel.id]
        #expect(s.penRoosterGrownDay != nil)
        Self.setEgg(from: hen, father: cockerel, &s, &rng)
        #expect(Inheritance.known(in: s).isEmpty)
        // Before the keeper has met the planner.
        s.pen = [hen.id, rooster.id]
        s.plannerKnown = false
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        #expect(Inheritance.known(in: s).isEmpty)
    }

    @Test func eggsUnderABroodyHenCountToo() {
        var (s, rng, hen, rooster) = Self.bluePair()
        let i = s.coop.firstIndex { $0.id == hen.id }!
        s.coop[i].broodyUntilDay = s.day + 5
        let egg = fertileEgg(mother: hen, father: rooster, day: s.day, rng: &rng)
        s.carton.append(egg)
        _ = Engine.apply(.sitEggs(hen: hen.id, eggs: [egg.id]), to: &s, using: &rng)
        #expect(s.clutch(under: hen.id) != nil)
        #expect(Inheritance.known(in: s) == [Self.blueRule])
    }

    // MARK: - Rule 8

    /// The page's rules for every pair a keeper could pen, built from the pen's forecast.
    static func pageForAllPairs(_ s: GameState) -> [[InheritanceRule]] {
        var out: [[InheritanceRule]] = []
        for (hen, rooster) in PlannerTests.coopPairs(s).sorted(by: {
            ($0.hen.id.uuidString, $0.rooster.id.uuidString) < ($1.hen.id.uuidString, $1.rooster.id.uuidString)
        }) {
            var t = s
            t.plannerKnown = true
            t.pen = [hen.id, rooster.id]
            out.append(Inheritance.rules(forHen: hen.id, in: t))
        }
        return out
    }

    /// Every genome swapped for a look-alike (`KnowledgeTests.swapAll`): the same page.
    @Test func lookAlikesGiveTheSamePage() {
        var pairs = 0
        var rules = 0
        for seed in UInt64(1)...20 {
            var s = Simulation.play(seed: seed, days: KnowledgeTests.blindDays)
            let before = Self.pageForAllPairs(s)
            var rng = SeededRNG(seed: seed ^ 0x5357_4150)
            _ = KnowledgeTests.swapAll(&s, &rng)
            let after = Self.pageForAllPairs(s)
            #expect(before == after, "seed \(seed)")
            pairs += before.count
            rules += before.reduce(0) { $0 + $1.count }
        }
        #expect(pairs > 0)
        #expect(rules > 0)
    }

    /// The page from a played game with eggs set from the pen, then the same game with every genome
    /// swapped: setting the same eggs again gives the same page.
    @Test func settingEggsFromLookAlikesGivesTheSamePage() {
        let (base, baseRNG, hen, rooster) = Self.bluePair()
        func page(swapped: Bool) -> [InheritanceRule] {
            var s = base
            var rng = baseRNG
            if swapped {
                var swap = SeededRNG(seed: 99)
                _ = KnowledgeTests.swapAll(&s, &swap)
            }
            let mother = s.coop.first { $0.id == hen.id }!
            let father = s.coop.first { $0.id == rooster.id }!
            Self.setEgg(from: mother, father: father, &s, &rng)
            return Inheritance.known(in: s)
        }
        #expect(page(swapped: false) == page(swapped: true))
    }

    // MARK: - Saves

    @Test func oldSaveLoadsWithAnEmptyPage() throws {
        let game = try SaveFormat.decode(SaveFormatTests.fixture("save-v0"))
        #expect(game.state.seenRules.isEmpty)
        #expect(Inheritance.known(in: game.state).isEmpty)
    }

    @Test func thePageSurvivesASave() throws {
        var (s, rng, hen, rooster) = Self.bluePair()
        Self.setEgg(from: hen, father: rooster, &s, &rng)
        let data = try SaveFormat.encode(SaveGame(state: s, rng: rng))
        #expect(try SaveFormat.decode(data).state.seenRules == [Self.blueRule])
    }
}
