import Foundation
import Testing

@testable import FeatherwickCore

struct StoryTests {
    /// A started game with one hatched chick on record, a free perch, and no fox.
    static func game() -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: 5)
        var r = Rules.standard
        r.foxChance = 0
        var s = Engine.newGame(rules: r, earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.chicksHatched = 1
        return (s, rng)
    }

    static func night(_ s: inout GameState, _ rng: inout SeededRNG) -> [GameEvent] {
        Engine.apply(.passNight, to: &s, using: &rng)
    }

    static func fertileEggs(_ n: Int, _ s: inout GameState, _ rng: inout SeededRNG) {
        s.coins += n * s.rules.fertileEggPrice
        for _ in 0..<n { _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng) }  // bought eggs come candled
    }

    @Test func theSilkieStoryRunsStartToFinish() {
        var (s, rng) = Self.game()
        #expect(Self.night(&s, &rng).contains(.storyStarted("broodySilkie")))
        #expect(Engine.storyAwaitingDelivery(s) == "broodySilkie")

        // Not enough known-fertile eggs yet.
        #expect(
            Engine.apply(.deliver(story: "broodySilkie"), to: &s, using: &rng)
                == [.rejected(.needFertileEggs(need: 3, have: 0))])
        Self.fertileEggs(3, &s, &rng)
        #expect(
            Engine.apply(.deliver(story: "broodySilkie"), to: &s, using: &rng)
                == [.delivered("broodySilkie"), .storyStep("broodySilkie", step: "sitting")])
        #expect(s.carton.isEmpty)
        #expect(Engine.storyAwaitingDelivery(s) == nil)

        // The shop does not sell Silkies until the gift has come.
        s.coins = 100
        #expect(Engine.apply(.buyBreed(.silkie), to: &s, using: &rng) == [.rejected(.breedNotInShop)])

        var ev: [GameEvent] = []
        for _ in 0..<4 { ev += Self.night(&s, &rng) }
        let gift = ev.compactMap { if case .storyGift(_, let id) = $0 { id } else { nil } }
        #expect(gift.count == 1)
        let silkie = s.bird(gift[0])!
        #expect(silkie.breed == .silkie && silkie.sex == .hen && silkie.revealed && silkie.phenotype.isSilkieFeathered)
        #expect(ev.contains(.shopUnlocked(.silkie)) && ev.contains(.storyFinished("broodySilkie")))

        // Now the shop sells Silkie pullets.
        let bought = Engine.apply(.buyBreed(.silkie), to: &s, using: &rng)
        guard case .boughtBreed(let id, .silkie, let cost)? = bought.first else {
            Issue.record("no purchase: \(bought)")
            return
        }
        #expect(cost == s.rules.rareBreedPulletPrice && s.bird(id)?.breed == .silkie)

        // Rewards are given once: more nights bring nothing new.
        var later: [GameEvent] = []
        for _ in 0..<10 { later += Self.night(&s, &rng) }
        #expect(
            !later.contains { if case .storyGift = $0 { true } else if case .storyStarted = $0 { true } else { false } }
        )
    }

    @Test func theStoryWaitsForTheFirstHatch() {
        var (s, rng) = Self.game()
        s.chicksHatched = 0
        for _ in 0..<5 { #expect(!Self.night(&s, &rng).contains(.storyStarted("broodySilkie"))) }
        #expect(s.stories.isEmpty)
    }

    @Test func theGiftWaitsForAFreePerchAndNeverOverfillsTheCoop() {
        var (s, rng) = Self.game()
        _ = Self.night(&s, &rng)
        Self.fertileEggs(3, &s, &rng)
        _ = Engine.apply(.deliver(story: "broodySilkie"), to: &s, using: &rng)
        // Fill every perch.
        while s.coop.count < s.perches {
            s.coop.append(Engine.youngBird(.rooster, origin: "t", s, &rng))
        }
        var ev: [GameEvent] = []
        for _ in 0..<8 {
            ev += Self.night(&s, &rng)
            #expect(s.coop.count <= s.perches)
        }
        #expect(ev.count(where: { $0 == .storyGiftWaitingForRoom("broodySilkie") }) == 1)  // said once, not nightly
        #expect(!ev.contains { if case .storyGift = $0 { true } else { false } })
        // Make room. Birds boarding with the neighbour come home first, so free perches until the gift fits.
        var arrived = false
        for _ in 0..<5 where !arrived {
            _ = Engine.apply(.rehome(s.coop.last!.id), to: &s, using: &rng)
            arrived = Self.night(&s, &rng).contains { if case .storyGift = $0 { true } else { false } }
            #expect(s.coop.count <= s.perches)
        }
        #expect(arrived)
    }

    @Test func deliveringWithNothingAskedIsRejected() {
        var (s, rng) = Self.game()
        #expect(Engine.apply(.deliver(story: "broodySilkie"), to: &s, using: &rng) == [.rejected(.nothingToDeliver)])
        #expect(Engine.apply(.deliver(story: "nope"), to: &s, using: &rng) == [.rejected(.nothingToDeliver)])
    }

    @Test func storylinesAreWellFormed() {
        let ids = Storylines.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for story in Storylines.all {
            #expect(!story.steps.isEmpty && !story.rewards.isEmpty)
            #expect(story.after.allSatisfy { Storylines.story($0) != nil })
            for reward in story.rewards {
                switch reward {
                case .giftBird(let b, _), .unlockShopBreed(let b): #expect(b.definition.isInGame)
                }
            }
        }
    }

    @Test func storyProgressSurvivesASave() throws {
        var (s, rng) = Self.game()
        _ = Self.night(&s, &rng)
        let loaded = try SaveFormat.decode(SaveFormat.encode(SaveGame(state: s, rng: rng)))
        #expect(loaded.state.stories == s.stories)
    }

    /// A story that asks for known-fertile eggs teaches candling, so the keeper is never stuck.
    @Test func aFertileEggsStepTeachesCandling() {
        var (s, rng) = Self.game()
        s.rules.chicksToLearnCandling = 100  // only the story can teach it here
        #expect(!s.canCandle)
        let ev = Self.night(&s, &rng)
        #expect(ev.contains(.storyStarted("broodySilkie")) && ev.contains(.learnedCandling))
        #expect(s.canCandle)
        #expect(ev.count(where: { $0 == .learnedCandling }) == 1)
        // Taught once: later nights say nothing more.
        #expect(!Self.night(&s, &rng).contains(.learnedCandling))
    }

    /// A save where the step is already waiting but the keeper never learned: the next night teaches it.
    @Test func aWaitingFertileEggsStepTeachesCandlingOnTheNextNight() {
        var (s, rng) = Self.game()
        s.rules.chicksToLearnCandling = 100
        _ = Self.night(&s, &rng)
        s.canCandle = false
        #expect(Engine.storyAwaitingDelivery(s) == "broodySilkie")
        #expect(Self.night(&s, &rng).contains(.learnedCandling))
        #expect(s.canCandle)
    }

    /// A timed step does not teach candling: only a step that needs fertile eggs does.
    @Test func otherStepsDoNotTeachCandling() {
        var (s, rng) = Self.game()
        s.rules.chicksToLearnCandling = 100
        _ = Self.night(&s, &rng)
        Self.fertileEggs(3, &s, &rng)
        _ = Engine.apply(.deliver(story: "broodySilkie"), to: &s, using: &rng)
        s.canCandle = false
        #expect(!Self.night(&s, &rng).contains(.learnedCandling))
        #expect(!s.canCandle)
    }
}
