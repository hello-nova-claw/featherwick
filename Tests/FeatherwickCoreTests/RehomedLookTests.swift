import Foundation
import Testing

@testable import FeatherwickCore

/// A rehomed bird keeps the look the keeper last saw (`Bird.lastSeenLook`), never more.
struct RehomedLookTests {
    /// A grown hen boarding with the neighbour, from a save made before looks were frozen.
    static func oldSaveBoarder() -> (GameState, SeededRNG, Bird) {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        let hen = Bird(
            id: makeID(using: &rng), name: "Wren", breed: .araucana, genome: Breed.araucana.purebred(.hen),
            hatchDay: s.day - s.rules.adultAge, origin: Bird.shopOrigin, revealed: true)
        s.boarding.append(hen)
        return (s, rng, hen)
    }

    /// The keeper rehomes it: the day it left is not known, so only its down is frozen, never its eggs.
    @Test func anOldSaveBoarderRehomedFreezesOnlyItsDown() {
        var (s, rng, hen) = Self.oldSaveBoarder()
        #expect(hen.lastSeenLook == nil && hen.phenotype.eggColour != nil)
        let ev = Engine.apply(.rehome(hen.id), to: &s, using: &rng)
        #expect(ev.contains { if case .rehomed = $0 { true } else { false } })
        let frozen = s.rehomed.first { $0.id == hen.id }?.lastSeenLook
        #expect(frozen == SeenLook(hen.phenotype, level: .down))
        #expect(frozen?.eggColour == nil)
    }

    /// The neighbour finds it a home in the night: the same.
    @Test func anOldSaveBoarderSentOnByTheNeighbourFreezesOnlyItsDown() {
        var (s, rng, hen) = Self.oldSaveBoarder()
        s.boarding[0].waitingSinceDay = s.day - s.rules.homeWaitNights
        s.perches = s.coop.count  // no perch comes free, so she does not come home
        for _ in 0..<3 where !s.rehomed.contains(where: { $0.id == hen.id }) { night(&s, &rng) }
        let frozen = s.rehomed.first { $0.id == hen.id }?.lastSeenLook
        #expect(frozen == SeenLook(hen.phenotype, level: .down))
    }

    /// A hen rehomed from the coop was in front of the keeper: her eggs are part of the look.
    @Test func aCoopHenRehomedFreezesHerLayingLook() {
        var (s, rng, hen) = Self.oldSaveBoarder()
        s.boarding.removeAll()
        s.coop.append(hen)
        _ = Engine.apply(.rehome(hen.id), to: &s, using: &rng)
        let frozen = s.rehomed.first { $0.id == hen.id }?.lastSeenLook
        #expect(frozen?.level == .laying)
        #expect(frozen?.eggColour == hen.phenotype.eggColour)
    }
}
