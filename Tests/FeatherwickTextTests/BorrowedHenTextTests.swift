import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// The borrowed hen's words: every step, option and reply has words, and none tells the starter's sex.
struct BorrowedHenTextTests {
    static let tag = Storylines.marigold

    /// A new keeper's game, played with the coop shut, to the morning of `day`. Returns the events.
    static func play(until day: Int, seed: UInt64 = 1, index: Int = 0) -> (GameState, SeededRNG, [GameEvent]) {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        var ev = Engine.apply(.chooseStarter(index: index, name: "Basil"), to: &s, using: &rng)
        while s.day < day {
            for c in [Command.feed, .closeCoop] { ev += Engine.apply(c, to: &s, using: &rng) }
            while s.isOpen(.daylight), s.slotsLeft > 0 { ev += Engine.apply(.rest, to: &s, using: &rng) }
            ev += Engine.apply(.passNight, to: &s, using: &rng)
        }
        return (s, rng, ev)
    }

    @Test func everyStepOptionAndReplyHasWords() {
        let story = Storylines.borrowedHen
        let fallback = storyText("nope", step: nil)
        #expect(storyText(story.id, step: nil) != fallback)
        for step in story.steps.dropFirst() { #expect(storyText(story.id, step: step.id) != fallback, "\(step.id)") }
        for option in story.options(forChoice: Self.tag) {
            #expect(choiceText(story: story.id, option: option) != option)
            #expect(choiceButtonText(story: story.id, option: option).first?.isUppercase == true)
            #expect(choiceReplyText(story: story.id, option: option) != nil)
        }
        #expect(
            choiceReplyText(story: story.id, option: "keep")?.contains("Pay me when you can. She likes you.") == true)
        #expect(eventText(.storyGiftWaitingForRoom(Self.tag), GameState.blank)?.contains("carton") == true)
    }

    /// Rule 8: before the starter's sex shows (day 7), no line from the story or the lessons says it.
    @Test(arguments: [UInt64(1), 2, 3])
    func noLineTellsTheStartersSex(seed: UInt64) {
        for index in 0..<3 {
            let (s, _, ev) = Self.play(until: 6, seed: seed, index: index)
            let words = ev.compactMap { eventText($0, s) }.joined(separator: " ").lowercased()
            #expect(words.contains("marigold"))
            for sexed in [" he ", " his ", " him ", " pullet", " cockerel", " rooster", " son", " daughter"] {
                #expect(!words.contains(sexed), "\(sexed)")
            }
        }
    }

    @Test func theLessonsAreAboutMarigold() throws {
        let (s3, _, ev3) = Self.play(until: 3)
        let door = try #require(ev3.contains(.introduced(.coopDoor)) ? introducedText(.coopDoor, s3) : nil)
        #expect(door.contains("Marigold"))
        #expect(ev3.contains(.storyStep(Self.tag, step: "staying")))
        #expect(storyText(Self.tag, step: "staying").contains("Her eggs are yours. Shut the door at night."))
        let (s4, _, _) = Self.play(until: 4)
        #expect(introducedText(.laying, s4)?.contains("Marigold") == true)
    }

    @Test func theBreedBookLineSaysMarigoldsChickOnlyWhenSheCame() throws {
        let (s, _, ev) = Self.play(until: 8)
        #expect(ev.contains(.introduced(.breedBook)))
        #expect(introducedText(.breedBook, s)?.contains("Marigold's chick, of course.") == true)
        // A game without her (an old save, or one with the early game skipped) has the plain line.
        var other = s
        other.stories[Self.tag] = nil
        #expect(introducedText(.breedBook, other)?.contains("Marigold") == false)
    }

    @Test func theBirdCardSaysWhoseSheIs() throws {
        let (s, _, _) = Self.play(until: 4)
        let hen = try #require(s.loanedBird(tag: Self.tag))
        #expect(loanLineText(hen, s) == "Hazel's hen, staying a week")
        let starter = try #require(s.starterID.flatMap { s.bird($0) })
        #expect(loanLineText(starter, s) == nil)
        var (t, trng, _) = Self.play(until: 10)
        let asked = try #require(t.loanedBird(tag: Self.tag))
        #expect(loanLineText(asked, t)?.contains("keep her") == true)
        let chose = Engine.apply(.choose(story: Self.tag, option: "keep"), to: &t, using: &trng)
        let words = chose.compactMap { eventText($0, t) }.joined(separator: " ")
        #expect(words.contains("You've decided: keep Marigold"))
        #expect(words.contains("You owe Hazel 40 coins"))
    }
}

extension GameState {
    /// A state for words that need no flock.
    fileprivate static var blank: GameState {
        var rng = SeededRNG(seed: 1)
        return Engine.newGame(using: &rng)
    }
}
