import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

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

// MARK: - The words, pinned before they move into the String Catalog (#58)

extension VillageTextTests {
    /// Every shape of the words in VillageText and VillagePeopleText reads as it did before the catalog.
    @Test func theVillageWordsReadTheSame() {
        let words = Self.villageWords()
        let expected = [
            "Hazel",
            "Hazel has kept hens over the back fence for forty years, and she has a story for every breed.",
            "the neighbour: genetics and the breeding pen",
            "Wren",
            "Wren took over her gran's feed shop, Speckle & Down. She knows all the village news.",
            "Speckle & Down: the shop and the news",
            "Dot",
            "Dot judges the county show. She has a sharp eye and a soft spot for a well-kept bird.",
            "the judge: shows",
            "Teddy",
            "Teddy lives down the lane. He isn't allowed a chicken, so he visits yours.",
            "the kid down the lane: friendly birds",
            "Mr Okafor",
            "Mr Okafor bakes the village bread and fills his window with eggs of every colour.",
            "the baker: egg colours",
            "Bea",
            "Bea runs the hen rescue on the hill. Every bird she takes in finds a good garden.",
            "the rescue: rehoming",
            "The broody Silkie",
            "nil",
            "nil",
            "nil",
            "nil",
            "A laced gift",
            "nil",
            "nil",
            "nil",
            "A heritage breed",
            "nil",
            "nil",
            "nil",
            "nil",
            "The standard",
            "At the entry desk, a woman with reading glasses on a chain watches you fill in your form. \"First show? I'm Dot. I judge. Don't let that frighten you.\"",
            "nil",
            "Dot stops you in the lane. \"Come by on a quiet afternoon and I'll show you the standard. It's the book we judges score by. Every breed has its own page.\"",
            "Dot opens a fat old book with a cracked spine. \"Which page shall we read first? One of your own breeds, I think.\"",
            "nil",
            "Teddy helps out",
            "A boy with muddy knees hangs over your gate. \"Is that your chicken? Can I meet it? I'm Teddy. I live down the lane.\"",
            "nil",
            "Teddy is back at the gate. \"Mum says I'm not allowed a chicken. Not even a small one. So I'm going to visit yours instead.\"",
            "Teddy has his wellies on today. \"Can I help? I could name your next chick. I'm good at names. Or we could have a drawing day, and I'll draw all of them.\"",
            "let Teddy name your next chick",
            "Let Teddy name your next chick",
            "Let Teddy name your next chick.",
            "nil",
            "You've decided: let Teddy name your next chick.",
            "have a drawing day with Teddy",
            "Have a drawing day with Teddy",
            "Have a drawing day with Teddy.",
            "nil",
            "You've decided: have a drawing day with Teddy.",
            "Teddy runs home happy. \"Pick them up lots,\" he calls back. \"Then one of them will be a lap chicken. I'll know when it happens.\"",
            "nil",
            "The bakery window",
            "Mr Okafor from the bakery stops at your gate, flour on his sleeves. \"Those brown eggs of yours! I've a basket in my shop window that wants filling.\"",
            "nil",
            "Mr Okafor is back. \"Six brown eggs would fill the basket now. But a colour nobody has seen in my window yet... I'd wait for that. It's your choice, and there's no hurry.\"",
            "take him six brown eggs now",
            "Take him six brown eggs now",
            "Take him six brown eggs now.",
            "nil",
            "You've decided: take him six brown eggs now.",
            "wait, and take him three eggs of a new colour",
            "Wait, and take him three eggs of a new colour",
            "Wait, and take him three eggs of a new colour.",
            "nil",
            "You've decided: wait, and take him three eggs of a new colour.",
            "Mr Okafor clears a space in his window. \"Bring them down to the bakery when they're ready.\"",
            "Mr Okafor sets your eggs in his window one by one, and steps back to look.",
            "People stop at the bakery window to look at your eggs. Mr Okafor says it's good for trade.",
            "nil",
            "Postcards from the rescue",
            "News travels in Featherwick. Bea, who runs the hen rescue on the hill, has heard about the bird that went to a new home from Henhaven.",
            "nil",
            "You pin Bea's postcard up by the coop door.",
            "Bea's invitation goes on the shelf by the door. The rescue is open whenever you like.",
            "nil",
            "The borrowed hen",
            "nil",
            "nil",
            "nil",
            "nil",
            "send Marigold home, with an egg for you",
            "Send Marigold home",
            "Send Marigold home, with an egg for you.",
            "Hazel tucks Marigold under her arm. \"Thank you, love. She's had a lovely holiday. Here's an egg from my flock, same breed as your chick, already candled.\"",
            "You've decided: send Marigold home, with an egg for you. Hazel tucks Marigold under her arm. \"Thank you, love. She's had a lovely holiday. Here's an egg from my flock, same breed as your chick, already candled.\"",
            "keep Marigold, and pay Hazel for her when you can",
            "Keep Marigold",
            "Keep Marigold, and pay Hazel for her when you can.",
            "Hazel smiles. \"Pay me when you can. She likes you.\"",
            "You've decided: keep Marigold, and pay Hazel for her when you can. Hazel smiles. \"Pay me when you can. She likes you.\"",
            "nil",
            "unknown",
            "opt",
            "Hazel asks you to choose. Type: choose marigold return, or choose marigold keep",
            "Teddy asks you to choose. Type: choose teddyHelps name",
            "Dot asks you to choose. Type: choose x a, or choose x b, or choose x c",
            "Fluff all over, like a powder puff. A round crest, a walnut comb, feathered feet and five toes. Dark skin and face, and turquoise earlobes.",
            "Here is the Silkie page, with my pencil notes in the margin. \"Fluff all over, like a powder puff. A round crest, a walnut comb, feathered feet and five toes. Dark skin and face, and turquoise earlobes.\" (Dot's notes are in your Breed Book now, on the Silkie page.)",
            "A big, soft, deep bird, low to the ground. A short back and a smooth curve from neck to tail. Plenty of loose feather, and a neat single comb that stands up straight.",
            "Here is the Orpington page, with my pencil notes in the margin. \"A big, soft, deep bird, low to the ground. A short back and a smooth curve from neck to tail. Plenty of loose feather, and a neat single comb that stands up straight.\" (Dot's notes are in your Breed Book now, on the Orpington page.)",
            "Curves everywhere: a round body, a short back and a full breast. A rose comb, low and tight. On a laced bird, a clean, even edge on every feather.",
            "Here is the Wyandotte page, with my pencil notes in the margin. \"Curves everywhere: a round body, a short back and a full breast. A rose comb, low and tight. On a laced bird, a clean, even edge on every feather.\" (Dot's notes are in your Breed Book now, on the Wyandotte page.)",
            "A neat crest that never hides the eyes, and a small pea comb. A lively, upright bird, with the tail carried well. And the eggs must be blue.",
            "Here is the Araucana page, with my pencil notes in the margin. \"A neat crest that never hides the eyes, and a small pea comb. A lively, upright bird, with the tail carried well. And the eggs must be blue.\" (Dot's notes are in your Breed Book now, on the Araucana page.)",
            "Upright and busy, with a deep body and a bright red single comb. Dark eyes. In the right light, the black feathers shine beetle-green.",
            "Here is the Australorp page, with my pencil notes in the margin. \"Upright and busy, with a deep body and a bright red single comb. Dark eyes. In the right light, the black feathers shine beetle-green.\" (Dot's notes are in your Breed Book now, on the Australorp page.)",
            "Hazel, 1 coin",
            "Mr Okafor, 40 coins",
            "No hurry and no interest. Pay when you can.",
            "the Hatch-along",
            "The village hatches eggs together.",
            "The Hatch-along is in 3 days. The village hatches eggs together.",
            "Today is the Hatch-along. The village hatches eggs together.",
            "the Longest Day",
            "The longest day of the year.",
            "The Longest Day is in 3 days. The longest day of the year.",
            "Today is the Longest Day. The longest day of the year.",
            "Moult Week",
            "The flock drops its old feathers and grows new ones.",
            "Moult Week is in 3 days. The flock drops its old feathers and grows new ones.",
            "Today is Moult Week. The flock drops its old feathers and grows new ones.",
            "Midwinter Lights",
            "Lanterns in every window of the village.",
            "Midwinter Lights is in 3 days. Lanterns in every window of the village.",
            "Today is Midwinter Lights. Lanterns in every window of the village.",
            "Hazel's house is quiet. She's at her sister's, and home tomorrow.",
            "Hazel's pullet, staying until tomorrow",
            "Hazel's house is quiet. She's at her sister's, and home on day 8.",
            "Hazel's chick, staying 5 more days",
            "Hazel's house is quiet. She's at her sister's, and home tomorrow.",
            "Hazel's pullet, staying until tomorrow",
            "“She's yours as soon as there's a perch for her. Make room when you can, love.”",
            "Yours once there's a perch for her",
            "“Let her finish what she's busy with. I'll fetch her when she's free.”",
            "Hazel's chick, going home once she's free",
            "nil",
            "Hazel's chick. Hazel is home: keep her, or send her home?",
            "nil",
            "Bea's chick, staying until tomorrow",
            "Bea's chick, staying 4 more days",
            "Bea's chick, on loan",
            "Mr Okafor's chick, on loan",
            "nil",
            "You're given 1 coin.",
            "You're given 12 coins.",
            "You're given 1 mealworm. You have 0 treats.",
            "You're given 5 mealworms. You have 0 treats.",
            "A Silkie egg goes into your carton, already candled.",
            "Goldie comes to stay. She belongs to Bea, and comes with a box of her own.",
            "Pebble comes to stay. Pebble belongs to Mr Okafor, and comes with a box of her own.",
            "Rusty comes to stay. He belongs to Wren, and comes with a box of his own.",
            "a bird comes to stay. She belongs to Hazel, and comes with a box of her own.",
            "Goldie goes home to Bea.",
            "Goldie is yours now. Bea is glad she's staying.",
            "Pebble is yours now. Mr Okafor is glad Pebble's staying.",
            "a bird is yours now. Hazel is glad she's staying.",
            "You owe Hazel 40 coins. Pay when you can: there's no hurry.",
            "Hazel waves over the fence. \"No rush on those coins, mind. Whenever suits.\"",
            "You pay Hazel 40 coins. \"Thank you, love.\"",
            "A note from Teddy: A drawing in crayon of every bird in your flock, with the names spelled Teddy's own way. You pin it to the coop door.",
            "nil",
            "A drawing in crayon of every bird in your flock, with the names spelled Teddy's own way. You pin it to the coop door.",
            "\"That one's a lap chicken, you know,\" Teddy says, pointing into the yard. He looks very proud.",
            "Your eggs sit in the middle of my window, and people come in just to ask about them. Since you waited, I've put a card by them with Henhaven's name on it.",
            "There's talk of a market board by the bakery, where keepers can say what they have. I've put your name down first, if you'll have it.",
            "Dear keeper, I've been to see your bird, who went to a new home from Henhaven. Happy as anything, with a favourite corner of the run, and the children say good morning every day. Love, Bea.",
            "Come up to the rescue one afternoon and see your bird for yourself. I'll put the kettle on. No need to write first. Love, Bea.",
            "Three of your birds have new homes in Featherwick now. The newest one settled in at once. You raise them kind, keeper. Love, Bea.",
            "nil",
            "\"That one's a lap chicken, you know,\" Teddy says, pointing at Toffee. He looks very proud.",
            "\"That one's a lap chicken, you know,\" Teddy says, pointing at Toffee. He looks very proud. He still talks about naming your chick.",
            "\"That one's a lap chicken, you know,\" Teddy says, pointing into the yard. He looks very proud. He still talks about naming your chick.",
            "Dear keeper, I've been to see Moss, who went to a new home from Henhaven. Happy as anything, with a favourite corner of the run, and the children say good morning every day. Love, Bea.",
            "Come up to the rescue one afternoon and see Moss for yourself. I'll put the kettle on. No need to write first. Love, Bea.",
            "Three of your birds have new homes in Featherwick now. Fern is the newest, and settled in at once. You raise them kind, keeper. Love, Bea.",
            "Teddy is at the gate the minute he hears. \"That one's called Pip!\" (You can rename Pip any time.)",
            "nil",
            "You carry the eggs down to the bakery, carefully.",
            "That needs 6 brown eggs in your carton. You have 2. Collect more first.",
            "That needs 3 eggs of one new colour in your carton: blue. You have 0 of the colour you have most of. No hurry: Mr Okafor will wait.",
            "That needs 3 eggs of one new colour in your carton: blue or green. You have 1 of the colour you have most of. No hurry: Mr Okafor will wait.",
            "That needs 3 eggs of one new colour in your carton: blue, green or olive. You have 2 of the colour you have most of. No hurry: Mr Okafor will wait.",
            "nil",
            "At the entry desk, a woman with reading glasses on a chain looks up from her list. \"I've seen your birds at a show or two. I'm Dot. I judge. We should talk properly some time.\"",
            "",
            "blue",
            "blue or green",
            "blue, green or olive",
            "Dot showed you the Araucana standard.",
            "What Dot looks for in the Araucana: A neat crest that never hides the eyes, and a small pea comb. A lively, upright bird, with the tail carried well. And the eggs must be blue.",
            "You let Teddy name a chick.",
            "Teddy's drawing is on the coop door.",
            "Your brown eggs filled his window.",
            "You waited, and took him eggs of a new colour.",
            "People",
            "People",
            "Finished",
            "Under way",
            "Hand over the eggs",
            "What Dot looks for",
            "Mr Okafor asks you to choose:",
            "Hazel, the neighbour: genetics and the breeding pen. Hazel has kept hens over the back fence for forty years, and she has a story for every breed.",
            "Wren, Speckle & Down: the shop and the news. Wren took over her gran's feed shop, Speckle & Down. She knows all the village news.",
            "Teddy, the kid down the lane: friendly birds. Teddy lives down the lane. He isn't allowed a chicken, so he visits yours.",
            "  • teddyHelps",
            "Mr Okafor, the baker: egg colours. Mr Okafor bakes the village bread and fills his window with eggs of every colour.",
            "  ✓ okaforWindow",
            "Bea, the rescue: rehoming. Bea runs the hen rescue on the hill. Every bird she takes in finds a good garden.",
            "Teddy asks you to choose: name (let Teddy name your next chick), drawing (have a drawing day with Teddy). Type: choose teddyHelps <option>",
            "You owe Hazel 40 coins. No hurry. To pay: pay marigold",
            "Goldie is on loan from Bea.",
            "Pebble is on loan from Mr Okafor.",
            "Rusty is on loan from Wren.",
            "The Hatch-along, in 8 days (day 9). The village hatches eggs together.",
            "The Longest Day, in 40 days (day 41). The longest day of the year.",
            "Moult Week, in 55 days (day 56). The flock drops its old feathers and grows new ones.",
            "Midwinter Lights, in 96 days (day 97). Lanterns in every window of the village.",
            "The Hatch-along, in 120 days (day 121). The village hatches eggs together.",
            "The Longest Day, in 152 days (day 153). The longest day of the year.",
            "The Hatch-along, today. The village hatches eggs together.",
            "The Longest Day, in 32 days (day 41). The longest day of the year.",
            "The Hatch-along, tomorrow. The village hatches eggs together.",
            "The Longest Day, today. The longest day of the year.",
            "Moult Week, in 15 days (day 56). The flock drops its old feathers and grows new ones.",
            "The Longest Day, tomorrow. The longest day of the year.",
            "Moult Week, today. The flock drops its old feathers and grows new ones.",
            "Midwinter Lights, in 41 days (day 97). Lanterns in every window of the village.",
            "Moult Week, tomorrow. The flock drops its old feathers and grows new ones.",
            "Midwinter Lights, today. Lanterns in every window of the village.",
            "The Hatch-along, in 24 days (day 121). The village hatches eggs together.",
            "Midwinter Lights, tomorrow. Lanterns in every window of the village.",
        ]
        #expect(words.count == expected.count)
        for (i, (got, want)) in zip(words, expected).enumerated() { #expect(got == want, "line \(i)") }
    }

    /// Every shape of the words: each line the functions can give, with a sample state for each.
    static func villageWords() -> [String] {
        var out: [String] = []
        func add(_ x: String?) { out.append(x ?? "nil") }
        let s = game()
        for p in Person.allCases { out += [People.name(p), People.about(p), People.role(p)] }
        for story in Storylines.all {
            add(storyTitle(story.id))
            add(peopleStoryText(story.id, step: nil))
            for step in story.steps {
                add(peopleStoryText(story.id, step: step.id))
                if case .choice(let choice, _) = step.goal {
                    for option in story.options(forChoice: choice) {
                        add(choiceText(story: story.id, option: option))
                        add(choiceButtonText(story: story.id, option: option))
                        add(choiceDetailText(story: story.id, option: option))
                        add(choiceReplyText(story: story.id, option: option))
                        add(villageEventText(.chose(story.id, option), s))
                    }
                }
            }
            add(rememberedText(story.id, s))
        }
        add(storyTitle("unknown"))
        add(choiceText(story: "unknown", option: "opt"))
        add(
            choiceHintText(
                PendingChoice(story: "marigold", person: .hazel, choice: "marigold", options: ["return", "keep"])))
        add(choiceHintText(PendingChoice(story: "teddyHelps", person: .teddy, choice: "help", options: ["name"])))
        add(choiceHintText(PendingChoice(story: "x", person: .dot, choice: "c", options: ["a", "b", "c"])))
        for breed in BreedTable.inGame.map(\.id) {
            add(dotStandardText(breed))
            add(peopleNoteText("standard-\(breed.rawValue)", s))
        }
        add(debtLineText(Debt(id: "d1", to: .hazel, coins: 1, mentionedDay: 1)))
        add(debtLineText(Debt(id: "d2", to: .okafor, coins: 40, mentionedDay: 1)))
        add(debtsNoteText)
        for v in VillageDay.allCases {
            add(villageDayName(v))
            add(villageDayAbout(v))
            add(villageEventText(.villageDayComing(v, inDays: 3), s))
            add(villageEventText(.villageDay(v), s))
        }
        // Hazel away, Marigold staying.
        var marigold = NotesTests.bird("Marigold", revealed: true, id: 50)
        marigold.loan = Loan(owner: .hazel, tag: Storylines.marigold)
        var away = s
        away.coop.append(marigold)
        away.stories[Storylines.marigold] = StoryProgress(step: 1, stepStartedDay: away.day)
        let home = away.hazelHomeDay ?? 0
        for day in [home - 1, home - 5, home] {
            away.day = day
            add(hazelFenceText(away))
            add(loanLineText(marigold, away))
        }
        for chosen in ["keep", "return", ""] {
            var back = s
            back.coop.append(marigold)
            back.stories[Storylines.marigold] = StoryProgress(
                step: 2, stepStartedDay: 1, chosen: chosen.isEmpty ? [:] : [Storylines.marigold: chosen])
            add(hazelFenceText(back))
            add(loanLineText(marigold, back))
        }
        add(hazelFenceText(s))
        var goldie = NotesTests.bird("Goldie", revealed: true, id: 51)
        goldie.loan = Loan(owner: .bea, tag: "goldie", returnDay: s.day + 1)
        add(loanLineText(goldie, s))
        goldie.loan = Loan(owner: .bea, tag: "goldie", returnDay: s.day + 4)
        add(loanLineText(goldie, s))
        goldie.loan = Loan(owner: .bea, tag: "goldie")
        add(loanLineText(goldie, s))
        var hidden = NotesTests.bird("Pebble", sex: .rooster, revealed: false, id: 52)
        hidden.loan = Loan(owner: .okafor, tag: "pebble")
        add(loanLineText(hidden, s))
        add(loanLineText(s.birdsAtHome[0], s))
        // Events.
        var withLoans = s
        withLoans.coop += [goldie, hidden]
        var roo = NotesTests.bird("Rusty", sex: .rooster, revealed: true, id: 53)
        roo.loan = Loan(owner: .wren, tag: "rusty")
        withLoans.coop.append(roo)
        let events: [GameEvent] = [
            .storyCoins("x", 1), .storyCoins("x", 12), .storyTreats("x", 1), .storyTreats("x", 5),
            .storyGiftEgg("x", .silkie),
            .loanArrived(goldie.id, from: .bea), .loanArrived(hidden.id, from: .okafor),
            .loanArrived(roo.id, from: .wren), .loanArrived(UUID(), from: .hazel),
            .loanReturned(goldie.id, to: .bea), .loanKept(goldie.id, from: .bea), .loanKept(hidden.id, from: .okafor),
            .loanKept(UUID(), from: .hazel),
            .debtOwed("d", to: .hazel, coins: 40), .debtReminder("d", to: .hazel),
            .debtPaid("d", to: .hazel, coins: 40),
            .noteArrived(.teddy, "teddy-drawing"), .noteArrived(.teddy, "nope"),
        ]
        for e in events { add(villageEventText(e, withLoans)) }
        // Notes from the four people.
        for id in [
            "teddy-drawing", "teddy-lapChicken", "okafor-window", "okafor-marketBoard", "bea-postcard",
            "bea-invite", "bea-postcard-3", "nope",
        ] { add(peopleNoteText(id, s)) }
        var lap = s
        var tame = NotesTests.bird("Toffee", revealed: true, id: 54)
        tame.tameness = 1
        QuantitativeTrait.calm.setShare(1, in: &tame.genome)
        lap.coop.append(tame)
        add(peopleNoteText("teddy-lapChicken", lap))
        lap.stories["teddyHelps"] = StoryProgress(stepStartedDay: 1, chosen: ["help": "name"])
        add(peopleNoteText("teddy-lapChicken", lap))
        lap.coop.removeLast()
        add(peopleNoteText("teddy-lapChicken", lap))
        var bea = s
        bea.rehomed = [
            NotesTests.bird("Moss", revealed: true, id: 55), NotesTests.bird("Fern", revealed: false, id: 56),
        ]
        for id in ["bea-postcard", "bea-invite", "bea-postcard-3"] { add(peopleNoteText(id, bea)) }
        // People events.
        let pip = s.birdsAtHome[0].id
        let peopleEvents: [GameEvent] = [
            .chickNamed(pip, by: .teddy), .storyStarted("dotStandard"), .delivered("okaforWindow"),
            .rejected(.needEggs(.brown, need: 6, have: 2)),
            .rejected(.needEggsOfNewColour([.blue], need: 3, have: 0)),
            .rejected(.needEggsOfNewColour([.blue, .green], need: 3, have: 1)),
            .rejected(.needEggsOfNewColour([.blue, .green, .olive], need: 3, have: 2)),
            .delivered("broodySilkie"),
        ]
        for e in peopleEvents { add(peopleEventText(e, s)) }
        var vet = s
        vet.day = 40
        vet.showResults = [NotesTests.ribbon(.pet, placing: 2)]
        vet.stories["dotStandard"] = StoryProgress(stepStartedDay: 40)
        add(peopleEventText(.storyStarted("dotStandard"), vet))
        out += [
            anyOfList([]), anyOfList(["blue"]), anyOfList(["blue", "green"]), anyOfList(["blue", "green", "olive"]),
        ]
        // Choices remembered.
        var made = s
        made.stories["dotStandard"] = StoryProgress(
            step: 3, stepStartedDay: 1, rewarded: true, chosen: [Storylines.dotStandardChoice: "araucana"])
        add(rememberedText("dotStandard", made))
        out += dotBookLines(made)
        for (story, choice, option) in [
            ("teddyHelps", "help", "name"), ("teddyHelps", "help", "drawing"), ("okaforWindow", "window", "now"),
            ("okaforWindow", "window", "wait"),
        ] {
            made.stories[story] = StoryProgress(stepStartedDay: 1, chosen: [choice: option])
            add(rememberedText(story, made))
        }
        out += [
            PeopleWords.tab, PeopleWords.title, PeopleWords.finished, PeopleWords.underWay, PeopleWords.handOver,
            PeopleWords.dotHeading, PeopleWords.asks(.okafor),
        ]
        // The people page and the calendar.
        var met = withLoans
        met.debts = [Debt(id: "marigold", to: .hazel, coins: 40, mentionedDay: 1)]
        met.stories["teddyHelps"] = StoryProgress(step: 2, stepStartedDay: 1)
        met.stories["okaforWindow"] = StoryProgress(step: 1, stepStartedDay: 1, rewarded: true)
        out += peopleLines(met)
        out += calendarLines(s, count: 6)
        for v in s.upcomingVillageDays(4) {
            var t = s
            t.day = v.date
            out += calendarLines(t, count: 2)
            t.day = v.date - 1
            out += calendarLines(t, count: 1)
        }
        return out
    }
}

extension VillageTextTests {
    /// A breed not in the game has no page in Dot's standard, and other events have no village words.
    @Test func otherBreedsAndEventsHaveNoVillageWords() {
        #expect(!BreedTable.inGame.contains { $0.id == .plymouthRock })
        #expect(dotStandardText(.plymouthRock) == nil)
        #expect(villageEventText(.delivered("okaforWindow"), Self.game()) == nil)
    }
}
