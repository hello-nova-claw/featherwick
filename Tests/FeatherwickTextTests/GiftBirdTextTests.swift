import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// The neighbour's gift bird (#130). `Engine.neighbourGiftIfNeeded` gives her to a keeper whose
/// starter turns out to be a rooster, `giftHenAge` (3) days old. That is under `growerAge` (7), so
/// she is still a chick when the keeper meets her, and the words must say so.
struct GiftBirdTextTests {
    /// The gift bird in the brooder, as the engine leaves her: `giftHenAge` days old, and revealed,
    /// because Hazel tells the keeper her breed and sex.
    static func gameWithGiftBird(hazelAway: Bool) -> (GameState, Bird) {
        var rng = SeededRNG(seed: 1)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        s.day = s.rules.growerAge
        let gift = Bird(
            id: UUID(), name: "Clover", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: s.day - s.rules.giftHenAge, origin: Bird.neighbourOrigin, revealed: true)
        s.brooder.append(gift)
        // Hazel is at her sister's while Marigold stays: step 1 of her story, not yet rewarded.
        if hazelAway { s.stories[Storylines.marigold] = StoryProgress(step: 1, stepStartedDay: s.day) }
        return (s, gift)
    }

    /// Both branches call her a chick. While Marigold stays, Hazel is away and writes a note;
    /// otherwise she leans over the fence.
    @Test(arguments: [false, true])
    func theGiftBirdIsAChickAndIsNotCalledAHen(hazelAway: Bool) throws {
        let (s, gift) = Self.gameWithGiftBird(hazelAway: hazelAway)
        // The premise of the test: she is under `growerAge`, so `kindWord` says "chick".
        #expect(gift.stage(onDay: s.day, rules: s.rules) == .chick)
        #expect(s.hazelAway == hazelAway)
        #expect(kindWord(gift, s) == "chick")

        let words = try #require(eventText(.neighbourGaveHen(gift.id), s))
        if hazelAway {
            #expect(words.hasPrefix("A chick arrives from Hazel's sister's"))
        } else {
            #expect(words.contains("She gives you a chick:"))
        }
        #expect(!words.contains("young hen"))
        // Her sex is told, not leaked: Hazel names it, so "she" is right (rule 8).
        #expect(words.contains("She"))
    }

    /// The noun comes from her age, not from a fixed word: a grown gift bird reads as a hen. So the
    /// line stays right if `giftHenAge` ever rises above `growerAge`.
    @Test func theWordsFollowHerAge() throws {
        var (s, gift) = Self.gameWithGiftBird(hazelAway: false)
        s.brooder = []
        s.day = s.rules.adultAge
        let grown = Bird(
            id: gift.id, name: gift.name, breed: gift.breed, genome: gift.genome,
            hatchDay: 0, origin: Bird.neighbourOrigin, revealed: true)
        s.coop.append(grown)
        #expect(grown.stage(onDay: s.day, rules: s.rules) == .adult)
        #expect(kindWord(grown, s) == "hen")
        let words = try #require(eventText(.neighbourGaveHen(grown.id), s))
        #expect(words.contains("She gives you a hen:"))
    }
}
