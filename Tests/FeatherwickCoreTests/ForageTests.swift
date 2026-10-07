import Foundation
import Testing

@testable import FeatherwickCore

/// Foraging (the fox risk/reward) and the two new storylines, including the Australorp unlock.
struct ForageTests {
    /// A started game with no fox, so leaving the door open is safe to test the forage upside alone.
    static func game(foxChance: Double = 0) -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: 11)
        var r = Rules.standard
        r.foxChance = foxChance
        var s = Engine.newGame(rules: r, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return (s, rng)
    }

    static func night(_ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        Engine.apply(.passNight, to: &s, using: &rng)
    }

    /// Puts a single adult laying hen in the coop (no chicks, no brooder), so laying can be observed.
    /// Lay chance is pinned to 1 so "did she lay?" is about feeding/foraging, not a dice roll.
    static func layingHen(_ s: inout GameState, _ rng: inout SeededRNG) {
        var hen = Engine.youngBird(.hen, origin: "test", s, &rng)  // a grower, hatchDay = day - growerAge
        hen.noLayUntilDay = 0
        s.coop = [hen]
        s.brooder = []
        s.henChicks = []
        s.day += s.rules.adultAge + 5  // age her well past point of lay
        s.rules.layChance = [.spring: 1, .summer: 1, .autumn: 1, .winter: 1]
        #expect(hen.stage(onDay: s.day, rules: s.rules) == .adult)
    }

    // MARK: - Forage mechanic

    @Test func leavingTheDoorOpenMakesBirdsForageAndFeedsThemFree() {
        var (s, rng) = Self.game()
        // A coop bird so there is something to forage (the starter is a brooder chick).
        s.coop = [Engine.youngBird(.hen, origin: "test", s, &rng)]
        s.coopDoorOpen = true
        s.fedToday = false
        let ev = Self.night(&s, &rng)
        #expect(ev.contains { if case .birdsForaged(let c) = $0 { c == 1 } else { false } })
        // After the night the flock foraged, so no feeding was needed for that night's lay.
        #expect(s.foragedToday)
    }

    @Test func aClosedCoopDoesNotForage() {
        var (s, rng) = Self.game()
        s.coop = [Engine.youngBird(.hen, origin: "test", s, &rng)]
        _ = Engine.apply(.closeCoop, to: &s, using: &rng)
        let ev = Self.night(&s, &rng)
        #expect(!ev.contains { if case .birdsForaged = $0 { true } else { false } })
        #expect(!s.foragedToday)
    }

    @Test func foragingLetsUnfedHensLayAndClosedUnfedHensDoNot() {
        // Same seed and flock, two worlds: door open (forage) vs closed (hungry).
        func run(doorOpen: Bool) -> Bool {
            var (s, rng) = Self.game()
            Self.layingHen(&s, &rng)
            s.fedToday = false
            s.coopDoorOpen = doorOpen
            let ev = Self.night(&s, &rng)
            return ev.contains { if case .eggLaid = $0 { true } else { false } }
        }
        #expect(run(doorOpen: true))  // foraged overnight → counts as fed → she lays
        #expect(!run(doorOpen: false))  // shut in and unfed → no eggs
    }

    @Test func foragingLiftsShowCondition() {
        var (s, rng) = Self.game()
        Self.layingHen(&s, &rng)
        let bird = s.coop[0]
        s.foragedToday = false
        let plain = Judge.condition(of: bird, in: s).value
        s.foragedToday = true
        let (foraged, notes) = Judge.condition(of: bird, in: s)
        #expect(foraged > plain)
        #expect(foraged <= 1)
        #expect(notes.contains(.foraged))
    }

    @Test func foragingAddsNoNightRandomnessWhenTheFlockIsEmptyOfForagers() {
        // A door-open night with only brooder chicks (no coop foragers) must not forage.
        var (s, rng) = Self.game()
        s.coopDoorOpen = true
        #expect(s.coop.isEmpty)
        let ev = Self.night(&s, &rng)
        #expect(!ev.contains { if case .birdsForaged = $0 { true } else { false } })
        #expect(!s.foragedToday)
    }

    // MARK: - New storylines

    /// Drives a game far enough to finish broodySilkie, then lacedGift, then heritageBreed.
    @Test func theNewStorylinesRunAfterTheSilkieOneAndUnlockAustralorp() {
        var rng = SeededRNG(seed: 7)
        var r = Rules.standard
        r.foxChance = 0
        var s = Engine.newGame(rules: r, earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.coins = 500

        func deliver(_ id: String, _ n: Int) {
            // Buy candled-fertile eggs from the shop, then hand them over.
            for _ in 0..<n { _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) }
            let r = Engine.apply(.deliver(story: id), to: &s, using: &rng)
            #expect(r.contains(.delivered(id)))
        }
        func nights(_ k: Int) -> [GameEvent] {
            var ev: [GameEvent] = []
            for _ in 0..<k { ev += Engine.apply(.passNight, to: &s, using: &rng) }
            return ev
        }

        // broodySilkie first (its reward gates lacedGift).
        s.chicksHatched = 1
        _ = nights(1)
        deliver("broodySilkie", 3)
        _ = nights(5)
        #expect(s.stories["broodySilkie"]?.rewarded == true)

        // lacedGift: triggers at 4 chicks, waits 3 days, gifts a Wyandotte hen. Make room first.
        s.chicksHatched = 4
        while s.coop.count >= s.perches { _ = Engine.apply(.upgradeCoop, to: &s, using: &rng) }
        let lacedEvents = nights(6)
        #expect(lacedEvents.contains(.storyStarted("lacedGift")))
        #expect(s.stories["lacedGift"]?.rewarded == true)
        let gotWyandotte = lacedEvents.contains {
            if case .storyGift("lacedGift", let id) = $0 { s.bird(id)?.breed == .wyandotte } else { false }
        }
        #expect(gotWyandotte)

        // heritageBreed: triggers at 8 chicks, deliver 4 fertile eggs, wait 4 days, gifts an Australorp
        // hen and unlocks the breed at the shop.
        s.chicksHatched = 8
        while s.coop.count >= s.perches { _ = Engine.apply(.upgradeCoop, to: &s, using: &rng) }
        _ = nights(1)
        #expect(s.stories["heritageBreed"] != nil)
        deliver("heritageBreed", 4)
        let settle = nights(6)
        #expect(settle.contains(.shopUnlocked(.australorp)))
        #expect(s.stories["heritageBreed"]?.rewarded == true)
        let gotAustralorp = settle.contains {
            if case .storyGift("heritageBreed", let id) = $0 { s.bird(id)?.breed == .australorp } else { false }
        }
        #expect(gotAustralorp)

        // A surprise pullet may now be an Australorp. Buy until one comes, then judge her.
        #expect(s.surpriseBreeds.contains(.australorp))
        var australorp: Bird?
        for _ in 0..<40 where australorp == nil {
            s.coins = 1000
            if s.coop.count >= s.perches { s.perches += 1 }
            let bought = Engine.apply(.buy(.pullet), to: &s, using: &rng)
            if case .boughtBird(let id, _, _)? = bought.first, s.bird(id)?.breed == .australorp {
                australorp = s.bird(id)
            }
        }
        guard let bird = australorp else {
            Issue.record("no Australorp in 40 surprise pullets")
            return
        }
        #expect(bird.breed == .australorp && bird.isPurebred && bird.phenotype.eggColour == .brown)
        // A purebred adult Australorp enters its own breed class without being disqualified.
        var judgeState = s
        judgeState.day = bird.hatchDay + s.rules.adultAge + 1  // old enough to show
        let card = Judge.judge(bird, in: .breed(.australorp), state: judgeState)
        #expect(card.grade != .disqualified, "australorp breed card: \(card.notes)")
    }

    @Test func australorpIsNowInGameButNotAStarter() {
        #expect(Breed.australorp.definition.isInGame)
        #expect(!Breed.australorp.definition.isStarter)
        #expect(!Breed.starters.contains(.australorp))
        // Still a planned breed remaining (plymouth rock), so the "planned" machinery stays exercised.
        #expect(BreedTable.all.contains { !$0.isInGame })
    }
}
