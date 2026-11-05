import Foundation
import Testing

@testable import FeatherwickCore
@testable import FeatherwickText

/// The post's note pool: every note has a condition and words, the conditions read only what the keeper
/// can see, the post never repeats a note and changes no seeded game, and no note tells a hidden sex.
struct NotesTests {
    // MARK: - States

    /// A new keeper on the first morning: one chick, sex hidden.
    static func freshGame(seed: UInt64 = 4) -> (GameState, SeededRNG) {
        var rng = SeededRNG(seed: seed)
        var s = Engine.newGame(using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return (s, rng)
    }

    static func bird(_ name: String, _ breed: Breed = .orpington, sex: Sex = .hen, revealed: Bool, id: Int) -> Bird {
        var b = Bird(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!, name: name, breed: breed,
            genome: breed.purebred(sex), hatchDay: 0, origin: Bird.neighbourOrigin, revealed: revealed)
        b.needsName = false
        return b
    }

    static func ribbon(_ cls: ShowClass, placing: Int, name: String = "Clover", day: Int = 28) -> ShowResult {
        ShowResult(
            day: day, showClass: cls, entrantName: name, placing: placing, fieldSize: 6, score: 70, prize: 5,
            birdID: nil, treats: 0, notes: nil, theme: .summerFete, podium: nil)
    }

    /// Changes `s` so that `c` holds. Day, season and show week are settled together, then the rest.
    static func satisfy(_ c: NoteCondition, _ s: inout GameState) {
        let parts: [NoteCondition] = if case .all(let cs) = c { cs } else { [c] }
        let timed = parts.filter {
            switch $0 {
            case .dayAtLeast, .season, .showInWeek: true
            default: false
            }
        }
        if !timed.isEmpty {
            s.introduced.insert(.shows)
            var t = s
            while !timed.allSatisfy({ $0.holds(in: t) }) { t.day += 1 }
            s.day = t.day
        }
        var next = 100
        for part in parts {
            switch part {
            case .always, .dayAtLeast, .season, .showInWeek: break
            case .hasEggs:
                s.layRecords.append(HenLayRecord(henID: UUID(), eggsLaid: 1, firstEggDay: 0, recentLayDays: []))
            case .hasRehomed, .rehomedCount:
                while !part.holds(in: s) {
                    next += 1
                    s.rehomed.append(bird("Rehomed\(next)", revealed: true, id: next))
                }
            case .hasLoan, .loanedBirdHome:
                guard !part.holds(in: s) else { break }
                var b = bird("Goldie", revealed: true, id: 99)
                b.loan = Loan(owner: .hazel, tag: "goldie")
                s.coop.append(b)
            case .eggBookHas(let colour):
                s.eggBook.insert(EggBookEntry(colour: colour, speckled: false))
            case .bandCount:
                while !part.holds(in: s) {
                    next += 1
                    var b = bird("Tame\(next)", revealed: true, id: next)
                    b.tameness = 1
                    s.coop.append(b)
                }
            case .afterStory(let id):
                s.stories[id] = StoryProgress(step: 0, stepStartedDay: 0, rewarded: true)
            case .isOpen(let f):
                s.introduced.insert(f)
            case .chicksHatched(let n):
                s.chicksHatched = max(s.chicksHatched, n)
            case .breedBookCount:
                for (i, breed) in Breed.allCases.enumerated() where !part.holds(in: s) {
                    s.breedBook.insert(BreedBookEntry(bird("Book\(i)", breed, revealed: true, id: 200 + i)))
                }
            case .enteredShow:
                s.showResults.append(ribbon(.pet, placing: 0))
            case .placedAtShow:
                s.showResults.append(ribbon(.breed(.orpington), placing: 2))
            case .placedInClass(let kind):
                let cls: ShowClass =
                    switch kind {
                    case .pet: .pet
                    case .eggs: .eggs(.blue)
                    case .breed: .breed(.wyandotte)
                    }
                s.showResults.append(ribbon(cls, placing: 1))
            case .all(let cs):
                for inner in cs { satisfy(inner, &s) }
            }
        }
    }

    /// The fresh game with the note's condition made true.
    static func stateWhereHolds(_ note: Note) -> GameState {
        var s = freshGame().0
        satisfy(note.condition, &s)
        return s
    }

    // MARK: - The pool

    @Test func everyNoteHasAUniqueIDAndEnoughNotesPerPerson() {
        let ids = Notes.pool.map(\.id)
        #expect(Set(ids).count == ids.count)
        let minimum: [Person: Int] = [.wren: 12, .hazel: 12, .dot: 10, .teddy: 10, .okafor: 8, .bea: 8]
        for (person, n) in minimum {
            #expect(Notes.pool.count(where: { $0.from == person }) >= n, "\(person)")
        }
        #expect(Notes.pool.count >= 60)
        for note in Notes.pool { #expect(Notes.note(note.id) == note) }
    }

    @Test func everyNoteHasWordsWhenItCanComeAndInAFreshGame() {
        let fresh = Self.freshGame().0
        for note in Notes.pool {
            let s = Self.stateWhereHolds(note)
            #expect(note.condition.holds(in: s), "\(note.id)")
            for state in [s, fresh] {
                let words = postNoteText(note.id, state)
                #expect(words?.trimmingCharacters(in: .whitespaces).isEmpty == false, "\(note.id)")
                #expect(eventText(.noteArrived(note.from, note.id), state)?.contains(People.name(note.from)) == true)
            }
        }
        #expect(postNoteText("noSuchNote", fresh) == nil)
    }

    @Test func onlyTeddyUsesExclamationMarks() {
        let fresh = Self.freshGame().0
        for note in Notes.pool where note.from != .teddy {
            for state in [Self.stateWhereHolds(note), fresh] {
                #expect(postNoteText(note.id, state)?.contains("!") == false, "\(note.id)")
            }
        }
    }

    /// Words that name something read it from the state; when the thing is gone, a general line is left.
    @Test func namedNotesNameWhatIsThereAndFallBackWhenItHasGone() throws {
        var s = Self.stateWhereHolds(try #require(Notes.note("bea.settled")))
        #expect(postNoteText("bea.settled", s)?.contains(s.rehomed[0].name) == true)
        s.rehomed = []
        #expect(postNoteText("bea.settled", s)?.isEmpty == false)

        s = Self.stateWhereHolds(try #require(Notes.note("dot.breedClass")))
        #expect(postNoteText("dot.breedClass", s)?.contains("Clover") == true)
        #expect(postNoteText("dot.breedClass", s)?.contains("Wyandotte") == true)

        s = Self.stateWhereHolds(try #require(Notes.note("okafor.window")))
        s.eggBook = [EggBookEntry(colour: .blue, speckled: false), EggBookEntry(colour: .cream, speckled: true)]
        #expect(postNoteText("okafor.window", s)?.contains("cream and blue eggs") == true)
    }

    // MARK: - Conditions

    @Test func theNewConditionsReadOnlyWhatTheKeeperCanSee() {
        var s = Self.freshGame().0
        s.day = 10
        #expect(NoteCondition.dayAtLeast(10).holds(in: s))
        #expect(!NoteCondition.dayAtLeast(11).holds(in: s))

        s.introduced.remove(.birdShop)
        #expect(!NoteCondition.isOpen(.birdShop).holds(in: s))
        s.introduced.insert(.birdShop)
        #expect(NoteCondition.isOpen(.birdShop).holds(in: s))

        #expect(!NoteCondition.chicksHatched(1).holds(in: s))
        s.chicksHatched = 2
        #expect(NoteCondition.chicksHatched(2).holds(in: s) && !NoteCondition.chicksHatched(3).holds(in: s))

        // A look only seen at a show is not a page the keeper owns.
        let wyandotte = Self.bird("Lace", .wyandotte, revealed: true, id: 1)
        s.seenAtShows = [SeenBreedBookEntry(entry: BreedBookEntry(wyandotte), day: 28, theme: .summerFete)]
        #expect(!NoteCondition.breedBookCount(1).holds(in: s))
        s.breedBook.insert(BreedBookEntry(wyandotte))
        #expect(NoteCondition.breedBookCount(1).holds(in: s) && !NoteCondition.breedBookCount(2).holds(in: s))

        #expect(!NoteCondition.rehomedCount(1).holds(in: s))
        s.rehomed = [Self.bird("Moss", revealed: false, id: 2), Self.bird("Fern", revealed: false, id: 3)]
        #expect(NoteCondition.rehomedCount(2).holds(in: s) && !NoteCondition.rehomedCount(3).holds(in: s))

        // Entered but unplaced: entered, no ribbon.
        #expect(!NoteCondition.enteredShow.holds(in: s))
        s.showResults = [Self.ribbon(.pet, placing: 0)]
        #expect(NoteCondition.enteredShow.holds(in: s))
        #expect(!NoteCondition.placedAtShow.holds(in: s))
        #expect(!NoteCondition.placedInClass(.pet).holds(in: s))

        s.showResults.append(Self.ribbon(.eggs(.brown), placing: 3))
        #expect(NoteCondition.placedAtShow.holds(in: s))
        #expect(NoteCondition.placedInClass(.eggs).holds(in: s))
        #expect(!NoteCondition.placedInClass(.pet).holds(in: s))
        #expect(!NoteCondition.placedInClass(.breed).holds(in: s))

        // A loaned bird lost after a fright is still on loan, but not at home.
        var goldie = Self.bird("Goldie", revealed: true, id: 9)
        goldie.loan = Loan(owner: .hazel, tag: "goldie")
        #expect(!NoteCondition.loanedBirdHome.holds(in: s))
        s.lost = [LostBird(bird: goldie, returnsOnDay: s.day + 2)]
        #expect(NoteCondition.hasLoan.holds(in: s))
        #expect(!NoteCondition.loanedBirdHome.holds(in: s))
        #expect(postNoteText("teddy.visitor", s)?.contains("Goldie") == false)
        s.lost = []
        s.coop.append(goldie)
        #expect(NoteCondition.loanedBirdHome.holds(in: s))
        #expect(postNoteText("teddy.visitor", s)?.contains("Goldie") == true)
    }

    /// Teddy's friendliness notes name the tamest bird at home, a loaned bird too, so the bird he names
    /// is as tame as the note says.
    @Test func teddyNamesABirdAsTameAsTheNoteSays() throws {
        var s = Self.freshGame().0
        s.day = 30
        var goldie = Self.bird("Goldie", revealed: true, id: 9)
        goldie.loan = Loan(owner: .hazel, tag: "goldie")
        goldie.tameness = 1
        QuantitativeTrait.calm.setShare(1, in: &goldie.genome)  // all calm genes: score 1, a lap chicken
        try #require(goldie.friendliness == .lapChicken)
        s.coop.append(goldie)
        let handFed = try #require(Notes.note("teddy.handFed"))
        #expect(handFed.condition.holds(in: s))
        #expect(postNoteText("teddy.handFed", s)?.contains("Goldie") == true)
        let lap = try #require(Notes.note("teddy.lap"))
        #expect(lap.condition.holds(in: s))
        #expect(postNoteText("teddy.lap", s)?.contains("Goldie") == true)
    }

    /// Story notes (`StoryReward.note`) and pool notes share `notesSeen`, so no ID may be in both.
    @Test func noStoryNoteSharesAnIDWithThePool() {
        func noteIDs(_ rewards: [StoryReward]) -> [String] {
            rewards.flatMap { r -> [String] in
                switch r {
                case .note(_, let id): [id]
                case .ifChosen(_, _, let inner): noteIDs(inner)
                default: []
                }
            }
        }
        let pool = Set(Notes.pool.map(\.id))
        for story in Storylines.all {
            let ids = noteIDs(story.rewards) + story.steps.flatMap { noteIDs($0.rewards) }
            for id in ids { #expect(!pool.contains(id), "\(story.id): \(id)") }
        }
    }

    /// The first days of a new game stay quiet: no note can come before day 6. This holds for every
    /// starter: an Araucana's mother, Marigold, lays blue from day 4, and Mr Okafor's blue-egg note waits.
    @Test func theFirstDaysAreQuiet() {
        var sawEarlyColour = false
        for seed in UInt64(1)...4 {
            for index in Breed.starters.indices {
                var rng = SeededRNG(seed: seed)
                var s = Engine.newGame(using: &rng)
                _ = Engine.apply(.chooseStarter(index: index, name: "Pip"), to: &s, using: &rng)
                s.rules.noteChance = 1
                while s.day < 6 {
                    for note in Notes.pool {
                        #expect(!note.condition.holds(in: s), "\(note.id) on day \(s.day), seed \(seed)")
                    }
                    for command: Command in [.feed, .collectEggs, .closeCoop] {
                        _ = Engine.apply(command, to: &s, using: &rng)
                    }
                    if s.eggBook.contains(where: { $0.colour != .brown }) { sawEarlyColour = true }
                    Engine.restUntilEvening(&s, using: &rng)
                    let ev = Engine.apply(.passNight, to: &s, using: &rng)
                    if s.day < 6 { #expect(!ev.contains { if case .noteArrived = $0 { true } else { false } }) }
                }
            }
        }
        #expect(sawEarlyColour, "no starter laid a non-brown egg before day 6: the test misses the blue note")
    }

    /// A note whose condition is false never comes, whatever the seed and the day.
    @Test func aNoteNeverComesWhenItsConditionIsFalse() {
        var s = Self.freshGame().0
        s.rules.noteChance = 1
        for note in Notes.pool {
            for day in 0..<6 {
                for seed in UInt64(0)..<40 {
                    s.day = day
                    s.shopSeed = seed
                    #expect(Engine.deliverPost(&s, pool: [note]).isEmpty, "\(note.id)")
                }
            }
            // And where it holds, it comes.
            var yes = Self.stateWhereHolds(note)
            yes.rules.noteChance = 1
            #expect(Engine.deliverPost(&yes, pool: [note]) == [.noteArrived(note.from, note.id)])
        }

        // In a rich state, the post picks only notes that fit, from the whole pool.
        for template in Notes.pool {
            var rich = Self.stateWhereHolds(template)
            rich.rules.noteChance = 1
            for seed in UInt64(0)..<30 {
                rich.notesSeen = []
                rich.shopSeed = seed
                for case .noteArrived(_, let id) in Engine.deliverPost(&rich) {
                    #expect(Notes.note(id)?.condition.holds(in: rich) == true, "\(id) with \(template.id)")
                }
            }
        }
    }

    // MARK: - A played game

    /// A simple keeper's game with a note every morning that one fits. Returns the note IDs and the end.
    static func play(seed: UInt64, days: Int, noteChance: Double) -> (notes: [String], end: GameState, rng: SeededRNG) {
        var rng = SeededRNG(seed: seed)
        var rules = Rules.standard
        rules.noteChance = noteChance
        var s = Engine.newGame(rules: rules, using: &rng)
        var notes: [String] = []
        func run(_ c: Command) {
            for case .noteArrived(_, let id) in Engine.apply(c, to: &s, using: &rng) {
                #expect(postNoteText(id, s)?.isEmpty == false)
                // Only the pool's notes: a village day or a story sends its own notes, by its own rules.
                guard let note = Notes.note(id) else { continue }
                notes.append(id)
                // When it came, it fitted.
                #expect(note.condition.holds(in: s), "\(id)")
            }
        }
        run(.chooseStarter(index: Int(seed % 3), name: "Pip"))
        for day in 0..<days {
            for b in s.unnamedBirds { run(.rename(b.id, name: NameBook.suggestion(for: b, in: s))) }
            run(.feed)
            run(.collectEggs)
            run(.candle)
            for b in s.coop.prefix(3) { run(.pet(b.id)) }
            if s.isOpen(.birdShop), s.hasFreePerch, !s.coop.contains(where: { $0.sex == .rooster }),
                s.coins >= s.rules.cockerelPrice
            {
                run(.buy(.cockerel))
            }
            let fertile = s.carton.count(where: { $0.isCandled && $0.isFertile })
            let room = min(fertile, s.incubatorSize, max(0, s.brooderSize - s.brooder.count))
            if s.hasIncubator, s.incubatorClutch == nil, s.boarding.isEmpty, room > 0 { run(.incubate(count: room)) }
            if s.carton.count > 6 { run(.sellClearEggs) }
            if let story = Engine.storyAwaitingDelivery(s) { run(.deliver(story: story)) }
            if s.coop.count >= s.perches { run(.upgradeCoop) }
            if day % 50 == 49, s.coop.count > 2, let b = s.coop.last(where: { $0.id != s.starterID }) {
                run(.rehome(b.id))
            }
            if let b = s.coop.first(where: { $0.stage(onDay: s.day, rules: s.rules) == .adult }) {
                run(.enterShow(b.id))
            }
            if day % 3 != 0 { run(.closeCoop) }
            while s.isOpen(.daylight), s.slotsLeft > 0 { run(.rest) }
            run(.passNight)
        }
        return (notes, s, rng)
    }

    @Test func thePostNeverRepeatsInALongGameAndIsTheSameForTheSameSeed() {
        let a = Self.play(seed: 7, days: 400, noteChance: 1)
        #expect(Set(a.notes).count == a.notes.count)
        #expect(Set(a.notes) == a.end.notesSeen.filter { Notes.note($0) != nil })
        #expect(a.notes.count >= 30, "\(a.notes.count) notes")
        for person in Person.allCases {
            #expect(a.notes.contains { Notes.note($0)?.from == person }, "\(person)")
        }

        // Same seed, same notes. And the post draws no game randomness: with no post, the game is the same.
        let b = Self.play(seed: 7, days: 400, noteChance: 1)
        #expect(a.notes == b.notes)
        let quiet = Self.play(seed: 7, days: 400, noteChance: 0)
        #expect(quiet.notes.isEmpty)
        #expect(quiet.rng == a.rng)
        #expect(quiet.end.ownedBirds.map(\.id) == a.end.ownedBirds.map(\.id))
        #expect(quiet.end.coins == a.end.coins)
    }

    // MARK: - Rule 8

    /// Every note, in a farm of hidden-sex chicks (some at home, some rehomed): a note that names one of
    /// them says nothing of its sex or breed.
    @Test func noNoteTellsAHiddenSexOrBreed() throws {
        var s = Self.freshGame().0
        s.day = 200
        for f in Feature.allCases { s.introduced.insert(f) }
        let hidden = [
            Self.bird("Moss", .wyandotte, sex: .rooster, revealed: false, id: 1),
            Self.bird("Fern", .araucana, sex: .hen, revealed: false, id: 2),
            Self.bird("Bramble", .silkie, sex: .rooster, revealed: false, id: 3),
        ]
        s.rehomed = hidden
        var tame = Self.bird("Wisp", .australorp, sex: .rooster, revealed: false, id: 4)
        tame.tameness = 1
        s.brooder.append(tame)
        let hiddenBirds = hidden + [tame] + s.birdsAtHome.filter { !$0.revealed }
        let sexed: Set<String> = [
            "she", "he", "her", "him", "his", "hers", "hen", "hens", "rooster", "roosters", "cockerel", "pullet",
            "boy", "girl", "lays", "laid", "crows",
        ]
        var named = 0
        for note in Notes.pool {
            let words = try #require(postNoteText(note.id, s))
            let tokens = Set(words.lowercased().split { !$0.isLetter }.map(String.init))
            for b in hiddenBirds where tokens.contains(b.name.lowercased()) {
                named += 1
                #expect(tokens.isDisjoint(with: sexed), "\(note.id): \(words)")
                #expect(!tokens.contains(b.breed.rawValue.lowercased()), "\(note.id): \(words)")
            }
        }
        #expect(named >= 8)  // Bea's notes and Teddy's name these birds
    }
}

// MARK: - The words, pinned before they move into the String Catalog (#58)

extension NotesTests {
    /// Every pool note, general and named, reads as it did before the catalog.
    @Test func thePoolNotesReadTheSame() {
        let words = Self.poolNoteWords()
        let expected = [
            "Fresh mealworms in at the shop this week. A treat a day makes a tame bird.",
            "Fresh mealworms in at the shop this week. A treat a day makes a tame bird.",
            "Premium feed is back on the shelf. A scoop in the morning lifts the day's laying.",
            "Premium feed is back on the shelf. A scoop in the morning lifts the day's laying.",
            "There's a new bird in the special pen every morning. Come and look, even if you don't buy.",
            "There's a new bird in the special pen every morning. Come and look, even if you don't buy.",
            "The surprise boxes are popular this week. Nobody knows the breed till the lid comes off.",
            "The surprise boxes are popular this week. Nobody knows the breed till the lid comes off.",
            "The big incubator is in at the shop. It holds a good many more eggs than a small one.",
            "The big incubator is in at the shop. It holds a good many more eggs than a small one.",
            "The timber cart came by. If your coop feels tight, I have perches in stock.",
            "The timber cart came by. If your coop feels tight, I have perches in stock.",
            "Rain all week, they say. Chickens don't mind it. They just look cross.",
            "Rain all week, they say. Chickens don't mind it. They just look cross.",
            "Hot days ahead. A dish of water in the shade keeps a flock content.",
            "Hot days ahead. A dish of water in the shade keeps a flock content.",
            "The leaves are coming down. Chickens love to scratch through them for beetles.",
            "The leaves are coming down. Chickens love to scratch through them for beetles.",
            "Frost on the lane this morning. Everyone at the shop is in two jumpers.",
            "Frost on the lane this morning. Everyone at the shop is in two jumpers.",
            "The whole village is talking about the show. Dot has been seen measuring tables.",
            "The whole village is talking about the show. Dot has been seen measuring tables.",
            "Hazel was in for twine. She says your flock is coming on nicely.",
            "Hazel was in for twine. She says your flock is coming on nicely.",
            "Mr Okafor has a new loaf in his window. He says it's the eggs that make it.",
            "Mr Okafor has a new loaf in his window. He says it's the eggs that make it.",
            "I hear your Breed Book has 0 pages now. That's more than mine, and I sell the birds.",
            "I hear your Breed Book has 3 pages now. That's more than mine, and I sell the birds.",
            "A word on the pecking order. Every flock sorts itself out. Give it a few days and all is calm.",
            "A word on the pecking order. Every flock sorts itself out. Give it a few days and all is calm.",
            "Pick them up while they're small, love. A chick learns trust faster than any grown bird.",
            "Pick them up while they're small, love. A chick learns trust faster than any grown bird.",
            "A shut door is a quiet night. An open one is a fed flock in the morning. Your choice, love.",
            "A shut door is a quiet night. An open one is a fed flock in the morning. Your choice, love.",
            "Feathers everywhere? That's the moult. They'll be in new clothes before winter.",
            "Feathers everywhere? That's the moult. They'll be in new clothes before winter.",
            "Hens lay less in the short days. Don't fret. They pick up again in spring.",
            "Hens lay less in the short days. Don't fret. They pick up again in spring.",
            "If a hen sits tight and fluffs up at you, she's broody. She's the best incubator there is.",
            "If a hen sits tight and fluffs up at you, she's broody. She's the best incubator there is.",
            "Every egg hatches if you give it time. I still go soft at the first peep.",
            "Every egg hatches if you give it time. I still go soft at the first peep.",
            "Keep notes on who you pair. A colour can hide for a generation and turn up later.",
            "Keep notes on who you pair. A colour can hide for a generation and turn up later.",
            "A cross can be as fine a bird as any purebred. The pet class takes crosses, and judges them fairly.",
            "A cross can be as fine a bird as any purebred. The pet class takes crosses, and judges them fairly.",
            "I keep thinking about your flock. A lovely mix of looks.",
            "I keep thinking about your black orpington. A lovely look.",
            "Old hens stop laying in time. They still earn their keep: they keep the young ones in line.",
            "Old hens stop laying in time. They still earn their keep: they keep the young ones in line.",
            "Spring again. The best time to set eggs, my mother always said.",
            "Spring again. The best time to set eggs, my mother always said.",
            "A borrowed bird is a guest. Treat a guest well, and the stories go home with them.",
            "A borrowed bird is a guest. Treat a guest well, and the stories go home with them.",
            "Your birds come to the gate when you call. That's patience, that is.",
            "Your birds come to the gate when you call. That's patience, that is.",
            "I noticed your entry at the show. Well kept.",
            "I noticed your Clover at the Summer Fete. Second place. Well earned.",
            "The pet class is a pleasure to judge. Calm birds, kind hands.",
            "Clover stood so calmly on my table. That comes from kind hands.",
            "A good breed bird is bred, not bought. Keep at it.",
            "Your Clover showed good type in the Wyandotte class. That is bred, not bought.",
            "A plate of eggs that match is harder than it looks.",
            "Your plate in the blue eggs class matched well. Harder than it looks.",
            "Thank you for bringing your birds to the show. Every keeper starts somewhere.",
            "Thank you for bringing your birds to the show. Every keeper starts somewhere.",
            "A hint for show week: shut the coop at night. A fox fright still shows on the judging table.",
            "A hint for show week: shut the coop at night. A fox fright still shows on the judging table.",
            "The pet class is half friendliness. A bird that sits still for me scores well.",
            "The pet class is half friendliness. A bird that sits still for me scores well.",
            "The Spring Egg Fair is my favourite for eggs. Three that match, clean and fresh.",
            "The Spring Egg Fair is my favourite for eggs. Three that match, clean and fresh.",
            "At the Summer Fete the pet class is the star. Bring your calmest bird.",
            "At the Summer Fete the pet class is the star. Bring your calmest bird.",
            "The Harvest Show favours the breed classes. Type and colour count most.",
            "The Harvest Show favours the breed classes. Type and colour count most.",
            "The Winter Championship draws the strongest field of the year. Don't let that stop you.",
            "The Winter Championship draws the strongest field of the year. Don't let that stop you.",
            "I hear you have a lap chicken. The pet class judges friendliness. Just saying.",
            "I hear you have a lap chicken. The pet class judges friendliness. Just saying.",
            "I drew your chickens! The one in the middle is Pip. I gave everyone big feet.",
            "I drew your chickens! The one in the middle is Pip. I gave everyone big feet.",
            "Do chickens know which egg is theirs? I think they do. I asked Mum and she doesn't know.",
            "Do chickens know which egg is theirs? I think they do. I asked Mum and she doesn't know.",
            "Pip ate from my hand today! It tickled! Mum says I can come back on Saturday.",
            "Tame101 ate from my hand today! It tickled! Mum says I can come back on Saturday.",
            "Pip sat on my lap for AGES! Best day ever!",
            "Tame101 sat on my lap for AGES! Best day ever!",
            "Your chickens come running when I say hello! I counted!",
            "3 of your chickens came running when I said hello! I counted twice!",
            "Where do chickens sleep? Do they dream? I think they dream about worms.",
            "Where do chickens sleep? Do they dream? I think they dream about worms.",
            "It snowed! Do chickens get cold feet? I drew them a picture of the sun.",
            "It snowed! Do chickens get cold feet? I drew them a picture of the sun.",
            "Can I name a chick one day? I have a list! Number one is Captain Fluff.",
            "Can I name a chick one day? I have a list! Number one is Captain Fluff.",
            "You won a ribbon at the show! I told everyone at school!",
            "You won a ribbon at the show! I told everyone at school!",
            "I found a feather by your gate! I'm keeping it in my best book.",
            "I found a feather by your gate! I'm keeping it in my best book.",
            "Your chickens were rolling in the dirt! I thought they were broken! Gran says it's a bath.",
            "Your chickens were rolling in the dirt! I thought they were broken! Gran says it's a bath.",
            "You had a visitor chicken! Can I say hello next time?",
            "Goldie is visiting! Can I say hello to Goldie? I'll be very quiet!",
            "Word reached the bakery that your flock is laying. Fresh eggs make the best bread.",
            "Word reached the bakery that your flock is laying. Fresh eggs make the best bread.",
            "A blue egg, I hear. There is a space in my window for one, if you ever have a spare.",
            "A blue egg, I hear. There is a space in my window for one, if you ever have a spare.",
            "Olive eggs. My grandmother kept a hen that laid them. You have brought back a memory.",
            "Olive eggs. My grandmother kept a hen that laid them. You have brought back a memory.",
            "A chocolate egg, dark as a crust. I would like to bake with one, one day.",
            "A chocolate egg, dark as a crust. I would like to bake with one, one day.",
            "Green eggs in Featherwick. The children at my counter will not believe me.",
            "Green eggs in Featherwick. The children at my counter will not believe me.",
            "A white egg, plain and clean. Good for meringue, and for painting at Easter.",
            "A white egg, plain and clean. Good for meringue, and for painting at Easter.",
            "Brown eggs, warm as toast. The colour is only on the outside, but I like it all the same.",
            "Brown eggs, warm as toast. The colour is only on the outside, but I like it all the same.",
            "My window has fine eggs this week, thanks to you. There is room for more colours.",
            "My window has fine eggs this week, thanks to you. There is room for more colours.",
            "In winter the eggs come slower and the oven stays on longer. We manage.",
            "In winter the eggs come slower and the oven stays on longer. We manage.",
            "Spring, and every basket is full. I am making custard tarts this week.",
            "Spring, and every basket is full. I am making custard tarts this week.",
            "Your birds have settled in well at their new homes.",
            "Rehomed101 has settled in well. She found the sunny corner on the first day.",
            "One of your birds has a new garden with an apple tree.",
            "Rehomed101 has a new garden with an apple tree. She spends the afternoons under it.",
            "Your birds' new families read to them after school.",
            "Rehomed101's new family has two small girls. They read to her after school.",
            "Your birds have made friends in their new homes.",
            "Rehomed102 has a friend at the new place. The two of them dust-bathe side by side.",
            "I have a photo of your birds on my fridge.",
            "I have a photo of Rehomed101 on my fridge. She looks very pleased in it.",
            "0 of your birds have found new homes now. Every one is loved.",
            "3 of your birds have found new homes now. Every one is loved.",
            "Winter check on your birds: warm coops and deep straw.",
            "Winter check on Rehomed101: a warm coop, deep straw and a family who fusses.",
            "I visited your birds today. They're doing well.",
            "I visited Rehomed102 today. She came straight to the fence to see me.",
            "The rescue is quiet this week. I sit with the old birds and drink my tea.",
            "The rescue is quiet this week. I sit with the old birds and drink my tea.",
            "Cream eggs, the colour of good butter. They sell first in my window, every time.",
            "Cream eggs, the colour of good butter. They sell first in my window, every time.",
            "nil",
            "I noticed your Clover at the Summer Fete. First place. Well earned.",
            "I noticed your Clover at the Summer Fete. Second place. Well earned.",
            "I noticed your Clover at the Summer Fete. Third place. Well earned.",
            "I noticed your plate of blue eggs at the Summer Fete. First place. Well earned.",
            "Your plate in the blue eggs class matched well. Harder than it looks.",
            "I noticed your pip at the county show. Second place. Well earned.",
            "Pip stood so calmly on my table. That comes from kind hands.",
            "My window has fine eggs this week, thanks to you. There is room for more colours.",
            "My window has blue eggs this week, thanks to you. There is room for more colours.",
            "My window has cream and blue eggs this week, thanks to you. There is room for more colours.",
            "My window has cream, brown and blue eggs this week, thanks to you. There is room for more colours.",
            "Hidden0 has settled in well. Hidden0 found the sunny corner on the first day.",
            "Hidden1 has a new garden with an apple tree. Hidden1 spends the afternoons under it.",
            "Hidden2's new family has two small girls. They read to Hidden2 after school.",
            "Hidden3 has a friend at the new place. The two of them dust-bathe side by side.",
            "I have a photo of Hidden4 on my fridge. Hidden4 looks very pleased in it.",
            "8 of your birds have found new homes now. Every one is loved.",
            "Winter check on Hidden6: a warm coop, deep straw and a family who fusses.",
            "I visited Hidden7 today. Hidden7 came straight to the fence to see me.",
            "Roo0 has settled in well. He found the sunny corner on the first day.",
            "Roo2's new family has two small girls. They read to him after school.",
            "I visited Roo7 today. He came straight to the fence to see me.",
        ]
        #expect(words.count == expected.count)
        for (i, (got, want)) in zip(words, expected).enumerated() { #expect(got == want, "line \(i)") }
    }

    /// Every shape of the words: each line the functions can give, with a sample state for each.
    static func poolNoteWords() -> [String] {
        var out: [String] = []
        func add(_ x: String?) { out.append(x ?? "nil") }
        let fresh = NotesTests.freshGame().0
        for note in Notes.pool {
            add(poolNoteText(note.id, fresh))
            add(poolNoteText(note.id, NotesTests.stateWhereHolds(note)))
        }
        add(poolNoteText("nope", fresh))
        // Dot's ribbons: each place, an egg plate, and an older save's show with no theme.
        var s = fresh
        for placing in [1, 2, 3] {
            s.showResults = [NotesTests.ribbon(.breed(.wyandotte), placing: placing)]
            add(poolNoteText("dot.ribbon", s))
        }
        s.showResults = [NotesTests.ribbon(.eggs(.blue), placing: 1)]
        add(poolNoteText("dot.ribbon", s))
        add(poolNoteText("dot.eggClass", s))
        s.showResults = [
            ShowResult(
                day: 28, showClass: .pet, entrantName: "pip", placing: 2, fieldSize: 8, score: 70, prize: 0,
                birdID: nil, treats: 0, notes: nil, theme: nil, podium: nil)
        ]
        add(poolNoteText("dot.ribbon", s))
        add(poolNoteText("dot.petClass", s))
        // Mr Okafor's window: no colours, one, two, three.
        for colours in [[], [EggColour.blue], [.cream, .blue], [.cream, .blue, .brown]] {
            s.eggBook = Set(colours.map { EggBookEntry(colour: $0, speckled: false) })
            add(poolNoteText("okafor.window", s))
        }
        // Bea's notes name a bird whose sex is hidden by name, never by pronoun.
        s.rehomed = (0..<8).map { NotesTests.bird("Hidden\($0)", revealed: false, id: 300 + $0) }
        for id in [
            "bea.settled", "bea.appleTree", "bea.storyTime", "bea.newFriend", "bea.fridge", "bea.thanks",
            "bea.winterCheck", "bea.fence",
        ] { add(poolNoteText(id, s)) }
        s.rehomed = (0..<8).map { NotesTests.bird("Roo\($0)", sex: .rooster, revealed: true, id: 400 + $0) }
        for id in ["bea.settled", "bea.storyTime", "bea.fence"] { add(poolNoteText(id, s)) }
        return out
    }
}

extension NotesTests {
    /// While the tamest bird still waits for a name, Teddy's notes say a general line.
    @Test func teddysNotesNameNoBirdWhileItWaitsForAName() {
        var s = Self.freshGame().0
        var pip = Self.bird("Pip", revealed: true, id: 1)
        pip.needsName = true
        s.coop = [pip]
        s.brooder = []
        s.henChicks = []
        #expect(poolNoteText("teddy.drawing", s) == "I drew your chickens! I gave everyone big feet.")
        #expect(poolNoteText("teddy.handFed", s) == "One of your chickens ate from my hand! It tickled!")
        #expect(poolNoteText("teddy.lap", s) == "A chicken sat on my lap for AGES! Best day ever!")
    }
}
