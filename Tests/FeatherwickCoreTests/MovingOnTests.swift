import Foundation
import Testing

@testable import FeatherwickCore

/// Birds never wait forever: a grown bird with no perch is rehomed by the neighbour after
/// `homeWaitNights`, and a bird left unnamed takes its suggested name after `autoNameNights`.
struct MovingOnTests {
    /// The night the hen's chicks grow up: 1 waits in the brooder, 2 board with the neighbour.
    func chicksWithNoPerch() -> (GameState, SeededRNG) {
        var (s, rng, _) = RoomTests().crowdedGame()
        for _ in 0..<(s.rules.broodyHatchDays + s.rules.brooderDays) { night(&s, &rng) }
        return (s, rng)
    }

    @Test func waitingBirdsAreRehomedAfterTheirLastNight() {
        var (s, rng) = chicksWithNoPerch()
        let waiting = s.birdsWaitingForPerch.map(\.id)
        #expect(waiting.count == 3)
        #expect(waiting.allSatisfy { s.nightsUntilRehomed($0) == s.rules.homeWaitNights })
        let coins = s.coins
        for _ in 1..<s.rules.homeWaitNights {
            let ev = night(&s, &rng)
            #expect(!ev.contains { if case .rehomedByNeighbour = $0 { true } else { false } })
        }
        #expect(waiting.allSatisfy { s.nightsUntilRehomed($0) == 1 })
        let ev = night(&s, &rng)
        #expect(ev.count(where: { if case .rehomedByNeighbour = $0 { true } else { false } }) == 3)
        #expect(s.boarding.isEmpty)
        #expect(s.brooder.isEmpty)
        #expect(s.birdsWaitingForPerch.isEmpty)
        #expect(Set(s.rehomed.map(\.id)).isSuperset(of: waiting))
        #expect(s.coins > coins)
        // Nothing is boarding now, so hatching can start again.
        s.incubatorSize = 6
        #expect(Engine.incubatorBlocker(s) != .birdsBoarding)
    }

    @Test func aBirdThatFindsAPerchInTimeStays() {
        var (s, rng) = chicksWithNoPerch()
        s.perches += 3
        let ev = night(&s, &rng)
        #expect(ev.count(where: { if case .cameHomeFromBoarding = $0 { true } else { false } }) == 2)
        #expect(ev.count(where: { if case .movedToCoop = $0 { true } else { false } }) == 1)
        #expect(s.coop.allSatisfy { $0.waitingSinceDay == nil })
        for _ in 0..<(s.rules.homeWaitNights + 1) { night(&s, &rng) }
        #expect(s.coop.count == 4)
        #expect(s.rehomed.isEmpty)
    }

    @Test func theStarterIsNeverSentAway() {
        var r = calmRules()
        r.startPerches = 0
        var (s, rng) = startedGame(sex: .hen, rules: r)
        let starter = s.starterID!
        for _ in 0..<(r.brooderDays + r.homeWaitNights + 3) { night(&s, &rng) }
        #expect(s.brooder.contains { $0.id == starter })
        #expect(s.nightsUntilRehomed(starter) == nil)
        #expect(!s.rehomed.contains { $0.id == starter })
    }

    @Test func anUnnamedBirdTakesItsSuggestedName() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        var chick = plainBird(hatchDay: s.day, rng: &rng)
        chick.revealed = false
        chick.needsName = true
        s.brooder.append(chick)
        for _ in 0..<s.rules.autoNameNights {
            let ev = night(&s, &rng)
            #expect(!ev.contains(.namedForYou(chick.id)))
        }
        let ev = night(&s, &rng)
        #expect(ev.contains(.namedForYou(chick.id)))
        let named = s.bird(chick.id)!
        #expect(named.needsName == nil)
        #expect(named.unnamedSinceDay == nil)
        // Still a secret: an unrevealed chick gets a neutral name.
        #expect(NameBook.neutral.contains(named.name))
        #expect(s.unnamedBirds.isEmpty)
    }

    @Test func namingABirdStopsTheCountdown() {
        var (s, rng) = startedGame(sex: .hen, rules: calmRules())
        var chick = plainBird(hatchDay: s.day, rng: &rng)
        chick.needsName = true
        s.brooder.append(chick)
        night(&s, &rng)
        _ = Engine.apply(.rename(chick.id, name: "Clementine"), to: &s, using: &rng)
        var events: [GameEvent] = []
        for _ in 0...s.rules.autoNameNights { events += night(&s, &rng) }
        #expect(!events.contains(.namedForYou(chick.id)))
        #expect(s.bird(chick.id)?.name == "Clementine")
    }
}
