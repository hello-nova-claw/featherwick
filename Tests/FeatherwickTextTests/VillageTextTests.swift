import FeatherwickText
import Foundation
import Testing

@testable import FeatherwickCore

/// The words for the village's four people: every story step, option and note has its own words (not the
/// fallback), Dot's page has words for every in-game breed, and Bea's postcards name the bird without a
/// hidden sex.
struct VillageTextTests {
    static let arcs = ["dotStandard", "teddyHelps", "okaforWindow", "beaPostcards"]
    static let fallback = "Something is happening in Featherwick. Type: story"

    static func game() -> GameState {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return s
    }

    /// Every note ID a story's rewards can send, conditional ones too.
    static func noteIDs(_ rewards: [StoryReward]) -> [String] {
        rewards.flatMap { reward -> [String] in
            switch reward {
            case .note(_, let id): [id]
            case .ifChosen(_, _, let inner): noteIDs(inner)
            default: []
            }
        }
    }

    @Test func everyStepOfTheFourArcsHasItsOwnWords() throws {
        for id in Self.arcs {
            let story = try #require(Storylines.story(id))
            #expect(storyText(id, step: nil) != Self.fallback, "\(id)")
            for step in story.steps.dropFirst() {
                #expect(storyText(id, step: step.id) != Self.fallback, "\(id).\(step.id)")
            }
        }
        for story in Storylines.all { #expect(storyTitle(story.id) != story.id, "\(story.id)") }
    }

    @Test func everyOptionAndNoteHasWords() throws {
        let s = Self.game()
        for id in Self.arcs {
            let story = try #require(Storylines.story(id))
            for step in story.steps {
                if case .choice(let choice, _) = step.goal {
                    for option in story.options(forChoice: choice) {
                        #expect(choiceText(story: id, option: option) != option, "\(id).\(option)")
                    }
                }
            }
            for note in Self.noteIDs(story.rewards + story.steps.flatMap(\.rewards)) {
                #expect(!(postNoteText(note, s) ?? "").isEmpty, "\(note)")
            }
        }
        // Dot can offer any in-game breed: each has an option, a page and a note.
        for breed in BreedTable.inGame.map(\.id) {
            #expect(choiceText(story: "dotStandard", option: breed.rawValue).contains(breed.definition.displayName))
            #expect(dotStandardText(breed) != nil, "\(breed)")
            #expect(postNoteText(Storylines.dotStandardNote(breed), s) != nil, "\(breed)")
        }
    }

    @Test func dotsLineShowsOnlyForTheChosenBreed() {
        var s = Self.game()
        #expect(dotBookLines(s).isEmpty)
        s.stories["dotStandard"] = StoryProgress(
            step: 3, stepStartedDay: 1, rewarded: true, chosen: [Storylines.dotStandardChoice: "araucana"])
        #expect(s.dotStandardBreed == .araucana)
        #expect(dotBookLines(s).count == 1)
        #expect(dotBookLines(s).first?.contains("Araucana") == true)
        #expect(bookLines(s).last == dotBookLines(s).first)
        #expect(rememberedText("dotStandard", s)?.contains("Araucana") == true)
    }

    @Test func beasPostcardsNameTheRehomedBirdAndNeverAHiddenSex() {
        var s = Self.game()
        let chick = Bird(
            id: UUID(), name: "Biscuit", breed: .orpington, genome: Breed.orpington.purebred(.rooster),
            hatchDay: 0, origin: "Test", revealed: false)
        let hen = Bird(
            id: UUID(), name: "Clover", breed: .orpington, genome: Breed.orpington.purebred(.hen),
            hatchDay: 0, origin: "Test", revealed: true)
        s.rehomed = [chick]
        let first = postNoteText("bea-postcard", s) ?? ""
        #expect(first.contains("Biscuit"))
        let words = Set(first.lowercased().split { !$0.isLetter }.map(String.init))
        #expect(words.isDisjoint(with: ["he", "she", "him", "her", "his", "rooster", "hen", "cockerel", "pullet"]))
        #expect(postNoteText("bea-invite", s)?.contains("Biscuit") == true)

        s.rehomed = [hen, hen, chick]
        #expect(postNoteText("bea-postcard", s)?.contains("Clover") == true)
        // The third postcard names the newest bird, once, with no pronoun: here a chick whose sex is hidden.
        let third = postNoteText("bea-postcard-3", s) ?? ""
        #expect(third.contains("Biscuit is the newest, and settled in at once."))
        #expect(third.components(separatedBy: "Biscuit").count == 2)
        let thirdWords = Set(third.lowercased().split { !$0.isLetter }.map(String.init))
        #expect(thirdWords.isDisjoint(with: ["he", "she", "him", "her", "his"]))
    }

    @Test func theNewEventsAndRefusalsHaveWords() {
        var s = Self.game()
        let id = s.birdsAtHome[0].id
        let named = eventText(.chickNamed(id, by: .teddy), s) ?? ""
        #expect(named.contains("Teddy") && named.contains(s.birdsAtHome[0].name))
        #expect(eventText(.rejected(.needEggs(.brown, need: 6, have: 2)), s)?.contains("6 brown eggs") == true)
        let newColour = eventText(.rejected(.needEggsOfNewColour([.blue, .green], need: 3, have: 1)), s) ?? ""
        #expect(newColour.contains("blue or green"))
        #expect(eventText(.delivered("okaforWindow"), s)?.contains("bakery") == true)
        #expect(eventText(.delivered("broodySilkie"), s)?.contains("fence") == true)
        // Choices remembered in words, once made.
        #expect(rememberedText("teddyHelps", s) == nil)
        s.stories["teddyHelps"] = StoryProgress(stepStartedDay: 1, chosen: ["help": "drawing"])
        #expect(rememberedText("teddyHelps", s) != nil)
        s.stories["okaforWindow"] = StoryProgress(stepStartedDay: 1, chosen: ["window": "wait"])
        #expect(rememberedText("okaforWindow", s) != nil)
    }

    @Test func dotDoesNotAskAVeteranAboutTheirFirstShow() {
        var s = Self.game()
        s.day = 40
        let first = eventText(.storyStarted("dotStandard"), s) ?? ""
        #expect(first.contains("First show?"))
        // One show held before the arc started is enough.
        s.showResults = [
            ShowResult(
                day: 28, showClass: .pet, entrantName: "Pip", placing: 2, fieldSize: 8, score: 70, prize: 0,
                birdID: nil, treats: 0, notes: nil, theme: nil, podium: nil)
        ]
        s.stories["dotStandard"] = StoryProgress(stepStartedDay: 40)
        let late = eventText(.storyStarted("dotStandard"), s) ?? ""
        #expect(!late.contains("First show") && late.contains("Dot"))
        // Her other steps are the same either way.
        #expect(eventText(.storyStep("dotStandard", step: "invite"), s) == storyText("dotStandard", step: "invite"))
    }

    /// Stories run before the night's show. Two entries on the eve of the first show give two results the
    /// same night Dot's arc starts: still a first show.
    @Test func dotGreetsAFirstTimerWithTwoEntriesAsAFirstTimer() throws {
        var rng = SeededRNG(seed: 3)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        s.day = s.nextShowDay - 1
        s.coins += 200
        var hens: [UUID] = []
        for name in ["Clover", "Maple"] {
            let hen = Bird(
                id: UUID(), name: name, breed: .orpington, genome: Breed.orpington.purebred(.hen),
                hatchDay: s.day - 200, origin: "Test", revealed: true)
            s.coop.append(hen)
            hens.append(hen.id)
        }
        for id in hens { _ = Engine.apply(.enterShow(id), to: &s, using: &rng) }
        #expect(s.showEntries.count == 2)
        Engine.restUntilEvening(&s, using: &rng)
        let night = Engine.apply(.passNight, to: &s, using: &rng)
        #expect(night.contains(.storyStarted("dotStandard")))
        #expect(s.showResults.count >= 2)
        let words = eventText(.storyStarted("dotStandard"), s) ?? ""
        #expect(words.contains("First show?"))
    }

    @Test func hazelsStoriesRememberHerMothersLavenderLine() {
        for id in ["broodySilkie", "lacedGift", "heritageBreed"] {
            #expect(storyText(id, step: nil).contains("lavender"), "\(id)")
        }
    }

    @Test func teddysNamesAreNeutral() {
        // A chick's sex is hidden when it hatches, so none of Teddy's names may say hen or rooster.
        let gendered = ["mr", "mrs", "miss", "sir", "lady", "king", "queen", "prince", "princess", "lord"]
        for name in NameBook.teddy {
            let words = name.lowercased().split(separator: " ").map(String.init)
            #expect(words.allSatisfy { !gendered.contains($0) }, "\(name)")
        }
    }
}
